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
wikidata_mapping_countries = read.csv("mapping-tables/wikidata-mapping-countries.csv", row.names = 1)
wikidata_mapping_cities = read.csv("mapping-tables/wikidata-mapping-countries.csv", row.names = 1)
UID_mapping_companies = read.csv("mapping-tables/UID-mapping-companies.csv", row.names = 1)

# Extract all city elements
cities = xml_find_all(xml_data, "//MetaData[@name='City']/Detail") %>%
  detail_to_df() %>%
  as.data.frame() %>%
  subset(subset = lang=="de", select = c(1,3))
rownames(cities) = cities$ID

# ------------------------------------------------------------------
# DEFINE GENERAL FUNCTIONS
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

# DOMAINS
# 1: Products
# 2: Companies

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
  
  # define basic product information
  sprintf("%s a :Product ;\n", IRI("1", products[i,"hasFederalAdmissionNumber"])) |> cat()
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
  sprintf("    :hasPermissionHolder %s .\n", IRI("2", products[i,"hasPermissionHolder"])) |> cat()
  cat("\n")
}

sink()

# ------------------------------------------------------------------
# WRITE COMPANY (PERMISSION HOLDER) INFORMATION
# ------------------------------------------------------------------

# extract company elements from XML file
company_xml <- xml_find_all(xml_data, "//PermissionHolder")

# create company table
companies <- nodeset_to_dataframe(company_xml)
companies$hasUID <- UID_mapping_companies[companies$primaryKey,"UID"]
companies$locatedInCity <- cities[xml_attr(xml_find_all(company_xml, "City"), "primaryKey"),"name"]
companies$locatedInCountry <- wikidata_mapping_countries[xml_attr(xml_find_all(company_xml, "Country"), "primaryKey"),]

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
companies <- companies[,c("primaryKey","Name","hasUID","hasPhoneNumber","hasFaxNumber","hasEmailAddress","PostOfficeBox","AdditionalInformation","Street","locatedInCity","locatedInCountry")]
colnames(companies) <- c("IRI","label","hasUID","hasPhoneNumber","hasFaxNumber","hasEmailAddress","PostOfficeBox","AdditionalInformation","hasStreet","locatedInCity","locatedInCountry")

# write.csv(data.frame(companies[companies$locatedInCountry=="Q39",c(1,2,10)], UID = NA), "mapping-tables/UID-companies.csv", row.names = FALSE)

# open file
sink("data/companies.ttl")

cat("
@prefix : <https://agriculture.ld.admin.ch/foag/plant-protection#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix wd: <http://www.wikidata.org/entity/> .

")

# loop over every company
for (i in 1:nrow(companies)) {
  sprintf("%s a :Company ;\n", IRI("2", companies[i,"IRI"])) |> cat()
  sprintf("    rdfs:label %s ;\n", literal(companies[i,"label"])) |> cat()
  for (x in c("hasUID","hasPhoneNumber","hasFaxNumber","hasEmailAddress","PostOfficeBox","AdditionalInformation","hasStreet","locatedInCity")) {
    if(!is.na(companies[i,x])) sprintf("    :%s %s ;\n", x, literal(companies[i,x])) |> cat()
  }
  for (x in na.omit(products[products$hasPermissionHolder==companies[i,"IRI"],"hasFederalAdmissionNumber"])) {
    sprintf("    :holdsPermissionToSell %s ;\n", IRI("1", x)) |> cat()
  }
  sprintf("    :locatedInCountry wd:%s .\n", companies[i,"locatedInCountry"]) |> cat()
  cat("\n")
}

sink()
