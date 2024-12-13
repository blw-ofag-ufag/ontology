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
# 3: Cities
# 4: Countries

# ------------------------------------------------------------------
# WRITE PRODUCT INFORMATION
# ------------------------------------------------------------------

# open file
sink("ontology/products.ttl", append = TRUE)

# pre-process product tables
products = as.data.frame(SRPPP$products)
products = products[order(products$pNbr),]
products[products==""] <- NA

# write triples
for (i in 1:nrow(products)) {
  sprintf("\n:1-W-%s a :Product ;", products[i,"wNbr"]) |> cat()
  sprintf("\n    rdfs:label \"%s\"^^xsd:string ;", products[i,"name"]) |> cat()
  sprintf("\n    :hasFederalAdmissionNumber \"W-%s\"^^xsd:string ;", products[i,"wNbr"]) |> cat()
  if(!is.na(products[i,"exhaustionDeadline"])) sprintf("\n    :hasExhaustionDeadline \"%s\"^^xsd:date ;", products[i,"exhaustionDeadline"]) |> cat()
  if(!is.na(products[i,"soldoutDeadline"])) sprintf("\n    :hasSoldoutDeadline \"%s\"^^xsd:date ;", products[i,"soldoutDeadline"]) |> cat()
  if(i>1) if(products[i,1]==products[i-1,1]) sprintf("\n    :isSameProductAs :1-W-%s ;", products[i-1,"wNbr"]) |> cat()
  if(sum(products[,"pNbr"]==products[i,"pNbr"])>1) {
    for (j in which(products[,"pNbr"]==products[i,"pNbr"])) {
      if(i != j) sprintf("\n    :isSameProductAs :1-W-%s ;", products[j,"wNbr"]) |> cat()
    }
  }
  cat(sprintf("\n    :isNonProfessionallyAllowed %s ;", tolower(as.character(products[i,"pNbr"] %in% SRPPP$CodeS[SRPPP$CodeS$desc_pk==13876,"pNbr"]))))
  cat("\n    :isParallelImport false ;")
  sprintf("\n    :hasPermissionHolder :2-%s .", products[i,"permission_holder"]) |> cat()
}

sink()

# pre-process parallel import tables
products = as.data.frame(SRPPP$parallel_imports)
products = products[order(products$pNbr),]
products[products==""] <- NA

# write triples
for (i in 1:nrow(products)) {
  sprintf("\n:1-%s a :Product ;", products[i,"id"]) |> cat()
  sprintf("\n    rdfs:label \"%s\"^^xsd:string ;", products[i,"name"]) |> cat()
  sprintf("\n    :hasFederalAdmissionNumber \"W-%s\"^^xsd:string ;", products[i,"wNbr"]) |> cat()
  if(!is.na(products[i,"exhaustionDeadline"])) sprintf("\n    :hasExhaustionDeadline \"%s\"^^xsd:date ;", products[i,"exhaustionDeadline"]) |> cat()
  if(!is.na(products[i,"soldoutDeadline"])) sprintf("\n    :hasSoldoutDeadline \"%s\"^^xsd:date ;", products[i,"soldoutDeadline"]) |> cat()
  if(i>1) if(products[i,1]==products[i-1,1]) sprintf("\n    :isSameProductAs :1-W-%s ;", products[i-1,"wNbr"]) |> cat()
  if(sum(products[,"pNbr"]==products[i,"pNbr"])>1) {
    for (j in which(products[,"pNbr"]==products[i,"pNbr"])) {
      if(i != j) sprintf("\n    :isSameProductAs :1-W-%s ;", products[j,"wNbr"]) |> cat()
    }
  }
  cat(sprintf("\n    :isNonProfessionallyAllowed %s ;", tolower(as.character(products[i,"pNbr"] %in% SRPPP$CodeS[SRPPP$CodeS$desc_pk==13876,"pNbr"]))))
  cat("\n    :isParallelImport false ;")
  sprintf("\n    :hasPermissionHolder :2-%s .", products[i,"permission_holder"]) |> cat()
}

# ------------------------------------------------------------------
# WRITE COMPANY (PERMISSION HOLDER) INFORMATION
# ------------------------------------------------------------------

# Extract company elements
company <- xml_find_all(xml_data, "//PermissionHolder")
COMPANY <- nodeset_to_dataframe(company)

# Extract attributes that weren't written to the table
city_ids <- xml_attr(xml_find_all(company, "City"), "primaryKey")
country_ids <- xml_attr(xml_find_all(company, "Country"), "primaryKey")

# Format phone and fax according to RFC3966 and extract email addresses that were typed into phone or fax field...
email_regex <- "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
email_from_phone <- ifelse(grepl(email_regex, COMPANY$Phone), tolower(COMPANY$Phone), NA)
email_from_fax <- ifelse(grepl(email_regex, COMPANY$Fax), tolower(COMPANY$Fax), NA)
phones <- COMPANY$Phone |> dialr::phone("CH") |> format(format = "RFC3966", clean = FALSE)
faxes <- COMPANY$Fax |> dialr::phone("CH") |> format(format = "RFC3966", clean = FALSE)

# Combine everything into RDF triples
company_rdf <- paste0(
  sprintf("%s a :Company ;\n", IRI("2", COMPANY$primaryKey)),
  sprintf("    rdfs:label \"%s\"^^xsd:string ;\n", COMPANY$Name),
  ifelse(nchar(COMPANY$AdditionalInformation) > 0, sprintf("    rdfs:comment \"%s\"^^xsd:string ;\n", COMPANY$AdditionalInformation), ""),
  ifelse(nchar(COMPANY$Street) > 0, sprintf("    :hasStreet \"%s\"^^xsd:string ;\n", COMPANY$Street), ""),
  ifelse(nchar(COMPANY$PostOfficeBox) > 0, sprintf("    :hasPostOfficeBox \"%s\"^^xsd:string ;\n", COMPANY$PostOfficeBox), ""),
  ifelse(!is.na(city_ids), sprintf("    :locatedInCity %s ;\n", IRI("3", city_ids)), ""),
  ifelse(!is.na(country_ids), sprintf("    :locatedInCountry %s ;\n", IRI("4", country_ids)), ""),
  ifelse(!is.na(phones), sprintf("    :hasPhone \"%s\"^^xsd:string ;\n", phones), ""),
  ifelse(!is.na(faxes), sprintf("    :hasFax \"%s\"^^xsd:string ;\n", faxes), ""),
  ".\n"
)

# Collapse all triples into one string, remove unnecessary lines
company_rdf <- gsub(";\n\\.", ".", paste(company_rdf, collapse = ""))

# open file
sink("ontology/data.ttl", append = TRUE)

cat(gsub(";\n\\.", ".", paste(company_rdf, collapse = "")))

# add all the products a company sells
for (i in 1:nrow(products)) {
  sprintf("%s :holdsPermissionToSell %s .\n", IRI("2", products[i,"permission_holder"]), IRI("1-W", products[i,"wNbr"])) |> cat()
}

sink()

# ------------------------------------------------------------------
# WRITE COUNTRY INFORMATION
# ------------------------------------------------------------------

# Open file
sink("ontology/data.ttl", append = TRUE)

# Extract all city elements
df = xml_find_all(xml_data, "//MetaData[@name='City']/Detail") %>%
  detail_to_df() %>%
  pivot_wider(names_from = lang, values_from = name) %>%
  as.data.frame()
rdf = paste0(
  sprintf("%s a :City ;\n", IRI("3",df[,1])),
  ifelse(df[,"de"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"de"],lang="de")), ""),
  ifelse(df[,"fr"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"fr"],lang="fr")), ""),
  ifelse(df[,"it"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"it"],lang="it")), ""),
  ifelse(df[,"en"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"en"],lang="en")), ""),
  ".\n"
)
cat(gsub(";\n\\.", ".", paste(rdf, collapse = "")))

# Extract all country elements
df = xml_find_all(xml_data, "//MetaData[@name='Country']/Detail") %>%
  detail_to_df() %>%
  pivot_wider(names_from = lang, values_from = name) %>%
  as.data.frame()
rdf = paste0(
  sprintf("%s a :Country ;\n", IRI("4",df[,1])),
  ifelse(df[,"de"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"de"],lang="de")), ""),
  ifelse(df[,"fr"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"fr"],lang="fr")), ""),
  ifelse(df[,"it"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"it"],lang="it")), ""),
  ifelse(df[,"en"]!="", sprintf("    rdfs:label %s ;\n", literal(df[,"en"],lang="en")), ""),
  ".\n"
)
cat(gsub(";\n\\.", ".", paste(rdf, collapse = "")))

# close file
sink()

