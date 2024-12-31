# add libraries to search path
library(rdflib)
library(jsonld)

# --------------------------------------------------------------------------------------------------------
# EXAMPLE 1 : READ THE ONTOLOGY FILE DIRECTLY ------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------

# set path to RDF file
RDF = rdf_parse("graph/plant-protection.ttl")

# define SPARQL query
SPARQL = '
PREFIX : <https://agriculture.ld.admin.ch/foag/plant-protection#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?productName ?code ?nonProfessional
WHERE {
  ?product a :Product .
  ?product rdfs:label ?productName .
  ?product :hasFederalAdmissionNumber ?code .
  ?product :isNonProfessionallyAllowed ?nonProfessional .
}
LIMIT 15
'

# run SPARQL query
rdf_query(RDF, SPARQL)

# --------------------------------------------------------------------------------------------------------
# EXAMPLE 2 : READ THE DATA FILE -------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------

# define SPARQL query
SPARQL = '
PREFIX : <https://agriculture.ld.admin.ch/foag/plant-protection#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?company (COUNT(DISTINCT ?product) AS ?productCount)
WHERE {
  ?product a :Product .
  ?product :hasPermissionHolder ?company .
}
GROUP BY ?company
ORDER BY DESC(?productCount)
'

# run SPARQL query
rdf_query(RDF, SPARQL) |> print(n = 20)

# --------------------------------------------------------------------------------------------------------
# EXAMPLE 3 : SAME AND SIMILAR PRODUCTS ------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------

# define SPARQL query
SPARQL = '
PREFIX : <https://agriculture.ld.admin.ch/foag/plant-protection#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?cropName ?parentCropName
WHERE {
  ?crop a :CropGroup .
  ?crop rdfs:label ?cropName .
  FILTER(LANG(?cropName)="de")
  ?crop :hasParentCropGroup ?parentCrop .
  ?parentCrop rdfs:label ?parentCropName .
  FILTER(LANG(?parentCropName)="de")
}
'

# run SPARQL query
rdf_query(RDF, SPARQL)
