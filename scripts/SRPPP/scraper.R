# ------------------------------------------------------------------
# ADD LIBRARIES TO SEARCH PATH
# ------------------------------------------------------------------

library(httr)
library(xml2)
library(rdflib)
library(dplyr)
library(srppp)
library(tidyr)
library(purrr)
library(jsonlite)

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

# Fuction to `cat` a triple (or return it...)
triple <- function(subject, predicate, object, return = FALSE) {
  x = sprintf("%s %s %s .\n", subject, predicate, object)
  if(return) return(x) else cat(x)
}

# DOMAINS
# 1: Product
# 2: Company
# 3: Address (of a company)
# 4: Hazard statement
# 5: Crop
# 6: Pest

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

# ------------------------------------------------------------------
# WRITE PRODUCT INFORMATION
# ------------------------------------------------------------------

# pre-process product tables
swiss_products = SRPPP$products[,c("pNbr", "wNbr", "name", "exhaustionDeadline", "soldoutDeadline", "permission_holder")]
colnames(swiss_products) = c("pNbr", "hasFederalAdmissionNumber", "label", "hasExhaustionDeadline", "hasSoldoutDeadline", "hasPermissionHolder")
swiss_products$hasFederalAdmissionNumber = paste0("W-", swiss_products$hasFederalAdmissionNumber)
swiss_products$hasCountryOfOrigin = "https://ld.admin.ch/country/CHE"
swiss_products$hasForeignAdmissionNumber = NA
swiss_products$isParallelImport = FALSE

# pre-process parallel imports tables
parallel_imports = SRPPP$parallel_imports[,c("pNbr", "id", "name", "exhaustionDeadline", "soldoutDeadline", "permission_holder", "producingCountryPrimaryKey", "admissionnumber")]
colnames(parallel_imports) = colnames(swiss_products)
parallel_imports$hasCountryOfOrigin = lindas_country[as.character(parallel_imports$hasCountryOfOrigin),]
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

")

# write triples
for (i in 1:nrow(products)) {
  
  # save categories as one string
  c <- srppp_product_categories[as.character(unlist(SRPPP$categories[SRPPP$categories$pNbr==products[i,"pNbr"],2])),2] |>
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
  
  sprintf("    :hasCountryOfOrigin %s ;\n", URL(products[i,"hasCountryOfOrigin"])) |> cat()
  
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
cities <- map_df(xml_find_all(xml_data, ".//MetaData[@name='City']/Detail"), function(detail) {
  city_id <- xml_attr(detail, "primaryKey")
  german_desc <- xml_find_first(detail, ".//Description[@language='de']")
  german_name <- if (!is.na(german_desc)) xml_attr(german_desc, "value") else NA_character_
  code_node <- if (!is.na(german_desc)) xml_find_first(german_desc, "./Code") else NA
  postal_code <- if (!is.na(code_node)) xml_attr(code_node, "value") else NA_character_
  tibble(id = city_id, addressLocality = german_name, postalCode = postal_code)
})
cities = data.frame(cities[,-1], row.names = cities$id)

# extract company elements from XML file
company_xml <- xml_find_all(xml_data, "//PermissionHolder")

# create company table
companies <- nodeset_to_dataframe(company_xml)
companies$hasUID <- zefix_company[companies$primaryKey,"UID"]
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
@prefix schema: <https://schema.org/> .
@prefix zefix: <https://register.ld.admin.ch/zefix/company/> .

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
    
  }
  else {
    EHRAID = gsub("https://register.ld.admin.ch/zefix/company/","",companies[i,"zefixIRI"])
    x = paste("zefix", EHRAID, sep=":")
    sprintf("%s schema:addressCountry %s .\n", x, URL(companies[i,"addressCountry"])) |> cat()
    for (p in na.omit(products[products$hasPermissionHolder==companies[i,"IRI"],"hasFederalAdmissionNumber"])) {
      sprintf("%s :holdsPermissionToSell %s .\n", x, IRI("1", p)) |> cat()
    }
  }
  cat("\n")
}

sink()


# ------------------------------------------------------------------
# Write data about hazard codes (Code R)
# ------------------------------------------------------------------

sink("data/hazard-statements.ttl")

cat("
@prefix : <https://agriculture.ld.admin.ch/foag/plant-protection#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

")

CodeR = unique(SRPPP$CodeR[,-1])
for (i in 1:nrow(CodeR)) {
  sprintf("%s a :HazardStatement, :CodeR ;\n", IRI("4", CodeR[i,1])) |> cat()
  if(!is.na(CodeR[i,2])) sprintf("  :hasHazardStatementCode %s ;\n", literal(CodeR[i,2], datatype = "string")) |> cat()
  sprintf("  rdfs:label %s ,\n", literal(CodeR[i,3], lang = "de")) |> cat()
  #sprintf("    %s ,\n", literal(CodeR[i,4], lang = "fr")) |> cat()
  #sprintf("    %s ,\n", literal(CodeR[i,5], lang = "it")) |> cat()
  sprintf("    %s ;\n", literal(CodeR[i,6], lang = "en")) |> cat()
  
  J = products[products$pNbr %in% unlist(SRPPP$CodeR[SRPPP$CodeR$desc_pk==as.numeric(CodeR[i,1]),"pNbr"]),"hasFederalAdmissionNumber"]
  for (j in J) {
    sprintf("  :appliesToProduct %s ;\n", IRI("1",j)) |> cat()
  }
  
  cat(".\n")
}

CodeS = unique(SRPPP$CodeS[,-1])
for (i in 1:nrow(CodeS)) {
  sprintf("%s a :HazardStatement, :CodeS ;\n", IRI("4", CodeS[i,1])) |> cat()
  if(!is.na(CodeS[i,2]) & !grepl("^\\s*$", CodeS[i,2])) sprintf("  :hasHazardStatementCode %s ;\n", literal(CodeS[i,2], datatype = "string")) |> cat()
  sprintf("  rdfs:label %s ;\n", literal(CodeS[i,3], lang = "de")) |> cat()
  #sprintf("  rdfs:label %s ;\n", literal(CodeS[i,4], lang = "fr")) |> cat()
  #sprintf("  rdfs:label %s ;\n", literal(CodeS[i,5], lang = "it")) |> cat()
  if(!is.na(CodeS[i,6]) & !CodeS[i,6]=="") sprintf("  rdfs:label %s ;\n", literal(CodeS[i,6], lang = "en")) |> cat()
  
  J = products[products$pNbr %in% unlist(SRPPP$CodeS[SRPPP$CodeS$desc_pk==as.numeric(CodeS[i,1]),"pNbr"]),"hasFederalAdmissionNumber"]
  for (j in J) {
    sprintf("  :appliesToProduct %s ;\n", IRI("1",j)) |> cat()
  }
  
  cat(".\n")
}

sink()

# ------------------------------------------------------------------
# Write data about crops
# ------------------------------------------------------------------

# Find all Detail nodes within the Culture MetaData
crops_xml <- xml_find_all(xml_data, ".//MetaData[@name='Culture']/Detail")

# Read JSON file about crops
crops <- jsonlite::read_json("mapping-tables/crops.json")
crops <- lapply(crops, function(x) {
  for (i in c("wikidata-iri", "srppp-parent-id")) x[[i]] <- unlist(x[[i]])
  x$label <- lapply(x$label, unlist)
  return(x)
})

# See if any crops are *not* in JSON file (if FALSE, add the crop with additional info)
all(xml_attr(crops_xml, "primaryKey") %in% unlist(lapply(crops, function(x) x[["srppp-id"]])))

# Write Turtle file
sink("data/crops.ttl")
cat("
@prefix : <https://agriculture.ld.admin.ch/foag/plant-protection#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix wd: <https://www.wikidata.org/wiki/> .

")
for (x in crops) {
  iri = IRI("5", x[["srppp-id"]])
  triple(iri, "a", ":CropGroup")
  for (i in c("de", "en")) triple(iri,"rdfs:label",literal(x[["label"]][[i]][1],lang=i))
  for (i in c("de", "en")) triple(iri,"rdfs:comment",literal(x[["comment"]][[i]][1],lang=i))
  if(!is.null(x[["srppp-parent-id"]])) for(i in x[["srppp-parent-id"]]) {
    triple(iri,":hasParentCropGroup",IRI("5", i))
    triple(IRI("5", i),":hasChildCropGroup",iri)
  }
  if(!is.null(x[["wikidata-iri"]])) for(i in x[["wikidata-iri"]]) triple(iri,":cropIsRelatedToBiologicalTaxon",paste0("wd:",i))
}
sink()

# ------------------------------------------------------------------
# Write data about pests
# ------------------------------------------------------------------

# Read JSON file with data
stressors = jsonlite::read_json("mapping-tables/crop-stressors.json", simplifyVector = FALSE)

# Convert nested arrays to vectors
stressors <- lapply(stressors, function(x) {
  for (i in c("wikidata-iri", "identical")) x[[i]] <- unlist(x[[i]])
  x$labels <- lapply(x$labels, unlist)
  return(x)
})

# Quality check 1: Is there a pest missing in the JSON file?
pests = xml_find_all(xml_data, ".//MetaData[@name='Pest']/Detail")
a = pests |> xml_attr("primaryKey")
b = sapply(stressors, function(x) x["srppp-id"]) |> unlist() |> unname() |> as.character()
if(all(a%in%b)) cat("Congrats, the JSON is (still) complete!") else cat("The JSON is missing a few items:\n\n", as.character(pests[which(!a%in%b)]))

# Quality check 2: Is every item with a latin name also biotic?
for (i in 1:length(stressors)) {
  if(stressors[[i]][["srppp-id"]] %in% c(10743,10968,11191,11131,11103,11014,12434)) next # skip these, they are exceptions...
  a <- length(stressors[[i]][["labels"]][["la"]])>0
  b <- stressors[[i]][["type"]]=="biotic"
  if(a&!b | !a&b) cat("\nID =",stressors[[i]][["srppp-id"]])
}

# Write Turtle file
sink("data/crop-stressors.ttl")

cat("
@prefix : <https://agriculture.ld.admin.ch/foag/plant-protection#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix wd: <https://www.wikidata.org/wiki/> .

")

# Write RDF data
for (i in 1:length(stressors)) {
  
  iri = IRI("6", stressors[[i]]["srppp-id"])
  de = unlist(stressors[[i]]$labels$de)
  en = unlist(stressors[[i]]$labels$en)
  taxa = unlist(stressors[[i]]["wikidata-iri"])
  type = stressors[[i]][["type"]]
  
  sprintf("%s a :CropStressor ;\n", iri) |> cat()
  if(is.null(type)) cat("")
  else if(type=="biotic") sprintf("  a :BioticStressor ;\n") |> cat()
  else if(type=="abiotic") sprintf("  a :AbioticStressor ;\n") |> cat()
  if(length(de)>0) sprintf("  rdfs:label %s ;\n", literal(de[[1]], lang = "de")) |> cat()
  if(length(en)>0) sprintf("  rdfs:label %s ;\n", literal(en[[1]], lang = "en")) |> cat()
  if(length(taxa)>0) {
    for (taxon in taxa) {
      sprintf("  :bioticStressorIsDefinedByBiologicalTaxon wd:%s ;\n", taxon) |> cat()
    }
  }
  cat(".\n\n")
}

sink()