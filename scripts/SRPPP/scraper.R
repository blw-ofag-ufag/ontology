# ------------------------------------------------------------------
# ADD LIBRARIES TO SEARCH PATH
# ------------------------------------------------------------------

library(httr)
library(xml2)
library(rdflib)
library(dplyr)
library(srppp)
library(tidyr)

# ------------------------------------------------------------------
# DEFINE HELPER FUNCTIONS
# ------------------------------------------------------------------

# Function to extract attributes and create a data frame
nodeset_to_dataframe <- function(nodeset) {
  data <- lapply(nodeset, function(node) {
    attrs <- as.list(xml_attrs(node))
    children <- xml_children(node)
    children_data <- sapply(children, function(child) xml_text(child))
    names(children_data) <- xml_name(children)
    c(attrs, children_data)
  })
  df <- bind_rows(data)
  return(df)
}

# Function to extract data from each Detail node
detail_to_df <- function(x) {
  y <- lapply(x, function(detail) {
    primaryKey <- xml_attr(detail, "primaryKey")
    
    descriptions <- xml_find_all(detail, ".//Description")
    data <- lapply(descriptions, function(description) {
      language <- xml_attr(description, "language")
      city_name <- xml_attr(description, "value")
      data.frame(
        ID = primaryKey,
        lang = language,
        name = city_name,
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, data)
  })
  do.call(rbind, y)
}

# Function to construct IRI
IRI <- function(domain, id, prefix = "") {
  paste0(prefix, ":", domain, "-", id)
}

# Function to construct a literal
literal <- function(x, datatype = NULL, lang = NULL) {
  d = if(!is.null(datatype)) paste0("^^xsd:", datatype) else ""
  l = if(!is.null(lang)) paste0("@", lang) else ""
  sprintf("\"%s\"%s%s", x, d, l)
}

# Function to mark up url
URL <- function(x) sprintf("<%s>", x)

# DOMAINS
# 1: Product
# 2: Company
# 3: Address

# ------------------------------------------------------------------
# DOWNLOAD THE SWISS PLANT PROTECTION REGISTRY AS AN XML FILE
# ------------------------------------------------------------------

# Download registry using `srppp` package
SRPPP <- srppp_dm()

# Download and unzip the file
zip_url <- "https://www.blv.admin.ch/dam/blv/de/dokumente/zulassung-pflanzenschutzmittel/pflanzenschutzmittelverzeichnis/daten-pflanzenschutzmittelverzeichnis.zip.download.zip/Daten%20Pflanzenschutzmittelverzeichnis.zip"
temp_zip <- tempfile(fileext = ".zip")
unzip_dir <- tempdir()
download.file(zip_url, temp_zip, mode = "wb")
unzip(temp_zip, exdir = unzip_dir)

# Read the XML file
xml_file_path <- file.path(unzip_dir, "PublicationData.xml")
xml_data <- read_xml(xml_file_path)

# Read mapping tables
lindas_country = read.csv("mapping-tables/lindas-country.csv", row.names = 1)
zefix_company = read.csv("mapping-tables/zefix-company.csv", row.names = 1)
srppp_product_categories = read.csv("mapping-tables/srppp-product-categories.csv", row.names = 1)
wikidata_taxon = read.csv("mapping-tables/wikidata-taxon.csv")

# Extract all city elements
cities = xml_find_all(xml_data, "//MetaData[@name='City']/Detail") %>%
  detail_to_df() %>%
  as.data.frame() %>%
  subset(subset = lang=="de", select = c(1,3))
rownames(cities) = cities$ID

library(xml2)
library(dplyr)
library(purrr)

# Assuming xml_data is already loaded, for example:
# xml_data <- read_xml("path_to_your_file.xml")

# Find all Detail nodes within the City MetaData
details <- xml_find_all(xml_data, ".//MetaData[@name='City']/Detail")

# ------------------------------------------------------------------
# WRITE PRODUCT INFORMATION
# ------------------------------------------------------------------

# pre-process product tables
swiss_products = SRPPP$products[,c("pNbr", "wNbr", "name", "exhaustionDeadline", "soldoutDeadline", "permission_holder")]
colnames(swiss_products) = c("pNbr", "hasFederalAdmissionNumber", "label", "hasExhaustionDeadline", "hasSoldoutDeadline", "hasPermissionHolder")
swiss_products$hasFederalAdmissionNumber = paste0("W-", swiss_products$hasFederalAdmissionNumber)
swiss_products$hasCountryOfOrigin = "wd:Q39"
swiss_products$hasForeignAdmissionNumber = NA
swiss_products$isParallelImport = FALSE

# pre-process parallel imports tables
parallel_imports = SRPPP$parallel_imports[,c("pNbr", "id", "name", "exhaustionDeadline", "soldoutDeadline", "permission_holder", "producingCountryPrimaryKey", "admissionnumber")]
colnames(parallel_imports) = colnames(swiss_products)
parallel_imports$hasCountryOfOrigin = paste0("wd:", wikidata_mapping_countries[as.character(parallel_imports$hasCountryOfOrigin),])
parallel_imports$isParallelImport = TRUE

# merge the two tables
products = rbind(swiss_products, parallel_imports)
products = as.data.frame(products)
products[products==""] <- NA

# tag the products that are allowed non-professionally (runn `unique(SRPPP$CodeS[SRPPP$CodeS$desc_pk==13876,]` to check code ID)
products$isNonProfessionallyAllowed = products[,"pNbr"] %in% unlist(SRPPP$CodeS[SRPPP$CodeS$desc_pk==13876,"pNbr"])

# sort by product ID (this is important for the "sameProductAs" search)
products = products[order(products$pNbr),]

# open file
sink("data/products.ttl")

cat("
@prefix : <https://agriculture.ld.admin.ch/foag/plant-protection#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix wd: <http://www.wikidata.org/entity/> .

")

# write triples
for (i in 1:nrow(products)) {
  
  # save categories as one string
  c <- product_categories[as.character(unlist(SRPPP$categories[SRPPP$categories$pNbr==products[i,"pNbr"],2])),2] |>
    strsplit(", ") |> unlist() |> unique() |> paste(collapse = ", ")
  
  # define basic product information
  sprintf("%s a :Product, %s ;\n", IRI("1", products[i,"hasFederalAdmissionNumber"]), c) |> cat()
  sprintf("    :hasFederalAdmissionNumber %s ;\n", literal(products[i,"hasFederalAdmissionNumber"], datatype = "string")) |> cat()
  if(products[i,"isParallelImport"]) {
    sprintf("    a :ParallelImport ;\n") |> cat()
    if(!is.na(products[i,"hasForeignAdmissionNumber"])) sprintf("    :hasForeignAdmissionNumber %s ;\n", literal(products[i,"hasForeignAdmissionNumber"], datatype = "string")) |> cat()
  }
  sprintf("    rdfs:label %s ;\n", literal(products[i,"label"])) |> cat()
  sprintf("    :isParallelImport %s ;\n", tolower(products[i,"isParallelImport"])) |> cat()
  sprintf("    :isNonProfessionallyAllowed %s ;\n", tolower(products[i,"isNonProfessionallyAllowed"])) |> cat()
  
  # some products have defined deadlines
  if(!is.na(products[i,"hasExhaustionDeadline"])) {
    sprintf("    :hasExhaustionDeadline %s ;\n", literal(products[i,"exhaustionDeadline"], datatype = "date")) |> cat()
  }
  if(!is.na(products[i,"hasSoldoutDeadline"])) {
    sprintf("    :hasSoldoutDeadline %s ;\n", literal(products[i,"hasSoldoutDeadline"], datatype = "date")) |> cat()
  }
  
  # find the chemically identical products
  if(sum(products[,"pNbr"]==products[i,"pNbr"])>1) {
    for (j in which(products[,"pNbr"]==products[i,"pNbr"])) {
      if(i != j) {
        sprintf("    :isSameProductAs %s ;\n", IRI("1", products[j,"hasFederalAdmissionNumber"])) |> cat()
      }
    }
  }
  
  sprintf("    :hasCountryOfOrigin %s ;\n", products[i,"hasCountryOfOrigin"]) |> cat()
  
  # reuse existing company from lindas zefix, if possible
  zefix_iri = zefix_company[as.character(products[i,"hasPermissionHolder"]),"IRI"]
  x = ifelse(!is.na(zefix_iri), sprintf("<%s>",zefix_iri), IRI("2", products[i,"hasPermissionHolder"]))
  sprintf("    :hasPermissionHolder %s .\n", x) |> cat()
  cat("\n")
}

sink()

# ------------------------------------------------------------------
# WRITE COMPANY (PERMISSION HOLDER) INFORMATION
# ------------------------------------------------------------------

# first, create city table
details <- xml_find_all(xml_data, ".//MetaData[@name='City']/Detail")
city <- map_df(details, function(detail) {
  city_id <- xml_attr(detail, "primaryKey")
  german_desc <- xml_find_first(detail, ".//Description[@language='de']")
  german_name <- if (!is.na(german_desc)) xml_attr(german_desc, "value") else NA_character_
  code_node <- if (!is.na(german_desc)) xml_find_first(german_desc, "./Code") else NA
  postal_code <- if (!is.na(code_node)) xml_attr(code_node, "value") else NA_character_
  tibble(id = city_id, addressLocality = german_name, postalCode = postal_code)
})
cities = data.frame(city[,-1], row.names = city$id)

# extract company elements from XML file
company_xml <- xml_find_all(xml_data, "//PermissionHolder")

# create company table
companies <- nodeset_to_dataframe(company_xml)
companies$hasUID <- UID_mapping_companies[companies$primaryKey,"UID"]
companies$city_id	 <- xml_attr(xml_find_all(company_xml, "City"), "primaryKey")
companies$addressLocality	 <- cities[companies$city_id,"addressLocality"]
companies$postalCode	 <- cities[companies$city_id,"postalCode"]
companies$locatedInCountry <- lindas_country[xml_attr(xml_find_all(company_xml, "Country"), "primaryKey"),]

# Format phone and fax according to RFC3966 and extract email addresses that were typed into phone or fax field...
email_regex <- "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
email_from_phone <- ifelse(grepl(email_regex, companies$Phone), tolower(companies$Phone), NA)
email_from_fax <- ifelse(grepl(email_regex, companies$Fax), tolower(companies$Fax), NA)
companies$hasEmailAddress <- ifelse(is.na(email_from_phone), email_from_fax, email_from_phone)
companies$hasPhoneNumber <- companies$Phone |> dialr::phone("CH") |> format(format = "RFC3966", clean = FALSE)
companies$hasFaxNumber <- companies$Fax |> dialr::phone("CH") |> format(format = "RFC3966", clean = FALSE)

# rearrange and rename
companies <- as.data.frame(companies)
companies[companies==""] <- NA
companies <- companies[,c("primaryKey","Name","hasUID","hasPhoneNumber","hasFaxNumber","hasEmailAddress","PostOfficeBox","Street","postalCode","addressLocality","locatedInCountry")]
colnames(companies) <- c("IRI","label","hasUID","telephone","faxNumber","email","postOfficeBoxNumber","streetAddress","postalCode","addressLocality","addressCountry")

# match zefix IRI
companies$zefixIRI <- zefix_company[companies[,"IRI"],"IRI"]

# open file
sink("data/companies.ttl")

cat("
@prefix : <https://agriculture.ld.admin.ch/foag/plant-protection#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix wd: <http://www.wikidata.org/entity/> .
@prefix schema: <https://schema.org>

")

# loop over every company
for (i in 1:nrow(companies)) {
  
  # we can re-use zefix companies, but only for the registered ones...
  if(is.na(companies[i,"zefixIRI"])) {
    
    # define a new company IRI
    x = IRI("2", companies[i,"IRI"])
    
    # set company (legal) name and contact info
    sprintf("%s a schema:Organization .\n", x) |> cat()
    sprintf("%s schema:name %s .\n", x, literal(companies[i,"label"])) |> cat()
    sprintf("%s schema:legalName %s .\n", x, literal(companies[i,"label"])) |> cat()
    for (property in c("email","telephone","faxNumber")) {
      if(!is.na(companies[i,property])) sprintf("%s :%s %s .\n", x, property, literal(companies[i,property])) |> cat()
    }
    
    # construct address IRI
    a = IRI("3", companies[i,"IRI"])
    sprintf("%s schema:address %s .\n", x, a) |> cat()
    sprintf("%s a schema:PostalAddress .\n", a) |> cat()
    for (property in c("postOfficeBoxNumber","streetAddress","postalCode","addressLocality")) {
      if(!is.na(companies[i,property])) sprintf("%s :%s %s .\n", a, property, literal(companies[i,property])) |> cat()
    }
    sprintf("%s schema:addressCountry %s .\n", a, URL(companies[i,"addressCountry"])) |> cat()
    for (p in na.omit(products[products$hasPermissionHolder==companies[i,"IRI"],"hasFederalAdmissionNumber"])) {
      sprintf("%s :holdsPermissionToSell %s .\n", x, IRI("1", p)) |> cat()
    }
    
  } else {
    x = URL(paste(companies[i,"zefixIRI"],"address",sep="/"))
    sprintf("%s schema:addressCountry %s .\n", x, URL(companies[i,"addressCountry"])) |> cat()
    for (p in na.omit(products[products$hasPermissionHolder==companies[i,"IRI"],"hasFederalAdmissionNumber"])) {
      sprintf("%s :holdsPermissionToSell %s .\n", x, IRI("1", p)) |> cat()
    }
  }
}

sink()


# ------------------------------------------------------------------
# Write data about biological taxa
# ------------------------------------------------------------------

