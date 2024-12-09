# Load required libraries
library(httr)
library(xml2)

# ------------------------------------------------------------------
# DOWNLOAD THE SWISS PLANT PROTECTION REGISTRY AS AN XML FIL
# ------------------------------------------------------------------

# Download and unzip the file
zip_url <- "https://www.blv.admin.ch/dam/blv/de/dokumente/zulassung-pflanzenschutzmittel/pflanzenschutzmittelverzeichnis/daten-pflanzenschutzmittelverzeichnis.zip.download.zip/Daten%20Pflanzenschutzmittelverzeichnis.zip"
temp_zip <- tempfile(fileext = ".zip")
unzip_dir <- tempdir()
download.file(zip_url, temp_zip, mode = "wb")
unzip(temp_zip, exdir = unzip_dir)

# Read the XML file
xml_file_path <- file.path(unzip_dir, "PublicationData.xml")
xml_data <- read_xml(xml_file_path)

# Print XML structure
print(xml_data)

# ------------------------------------------------------------------
# DEFINE GENERAL FUNCTIONS
# ------------------------------------------------------------------

# Function to construct IRIs
construct_iri <- function(prefix, id) {
  if (is.na(id)) return(NA)
  paste0(prefix, "-", id)
}

# ------------------------------------------------------------------
# WRITE COMPANY (PERMISSION HOLDER) INFORMATION
# ------------------------------------------------------------------

# Extract company elements
company <- xml_find_all(xml_data, "//PermissionHolder")

# Extract attributes and elements as vectors
ids <- xml_attr(company, "primaryKey")
names <- xml_text(xml_find_all(company, "Name"))
additional_infos <- xml_text(xml_find_all(company, "AdditionalInformation"))
streets <- xml_text(xml_find_all(company, "Street"))
po_boxes <- xml_text(xml_find_all(company, "PostOfficeBox"))
city_ids <- xml_attr(xml_find_all(company, "City"), "primaryKey")
country_ids <- xml_attr(xml_find_all(company, "Country"), "primaryKey")
phones <- xml_text(xml_find_all(company, "Phone"))

x = phone(phones, "CH")
format(x, format = "RFC3966", clean = FALSE)

faxes <- xml_text(xml_find_all(company, "Fax"))

# Construct IRIs
company_iris <- construct_iri("2", ids)
city_iris <- construct_iri("3", city_ids)
country_iris <- construct_iri("4", country_ids)

# Combine everything into RDF triples
rdf_content <- paste0(
  sprintf(":%s a :Company ;\n", construct_iri("2", ids)),
  sprintf("    rdfs:label \"%s\" ;\n", names),
  ifelse(nchar(additional_infos) > 0, sprintf("    rdfs:comment \"%s\" ;\n", additional_infos), ""),
  ifelse(nchar(streets) > 0, sprintf("    :hasStreet \"%s\" ;\n", streets), ""),
  ifelse(nchar(po_boxes) > 0, sprintf("    :hasPostOfficeBox \"%s\" ;\n", po_boxes), ""),
  ifelse(!is.na(city_iris), sprintf("    :locatedInCity :%s ;\n", construct_iri("3", city_ids)), ""),
  ifelse(!is.na(country_iris), sprintf("    :locatedInCountry :%s ;\n", construct_iri("4", country_ids)), ""),
  ifelse(nchar(phones) > 0, sprintf("    :hasPhone \"%s\" ;\n", phones), ""),
  ifelse(nchar(faxes) > 0, sprintf("    :hasFax \"%s\" ;\n", faxes), ""),
  ".\n\n"
)

# Collapse all triples into one string
rdf_content <- paste(rdf_content, collapse = "")

# Output RDF content using cat
sink("companies.ttl")
cat(rdf_content)
sink()
