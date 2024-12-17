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
SELECT ?productName ?code ?companyName ?UID ?nonProfessional ?parallel ?countryOfOrigin
WHERE {
  ?product a :Product .
  ?product rdfs:label ?productName .
  ?product :hasFederalAdmissionNumber ?code .
  ?company :holdsPermissionToSell ?product .
  ?company rdfs:label ?companyName .
  OPTIONAL {
    ?company :hasUID ?UID .
  }
  ?product :isParallelImport ?parallel .
  ?product :isNonProfessionallyAllowed ?nonProfessional .
  ?product :hasCountryOfOrigin ?country .
  ?country rdfs:label ?countryOfOrigin
  FILTER(LANG(?countryOfOrigin)="en")
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
SELECT ?companyName ?countryName (COUNT(DISTINCT ?product) AS ?productCount)
WHERE {
  ?product a :Product .
  ?product :hasPermissionHolder ?company .
  ?company rdfs:label ?companyName .
  ?company :locatedInCountry ?country .
  ?country rdfs:label ?countryName .
  FILTER(LANG(?countryName)="en")
}
GROUP BY ?companyName
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
SELECT ?sameProductName ?federalAdmissionNumber ?countryOfOrigin ?companyName ?UID
WHERE {
  ?sameProduct :isSameProductAs :1-W-5218 .
  ?sameProduct rdfs:label ?sameProductName .
  ?sameProduct :hasFederalAdmissionNumber ?federalAdmissionNumber .
  ?sameProduct :hasPermissionHolder ?company .
  ?company rdfs:label ?companyName .
  OPTIONAL {
    ?sameProduct :hasCountryOfOrigin ?country .
    ?country rdfs:label ?countryOfOrigin .
    FILTER(LANG(?countryOfOrigin)="en")
  }
  OPTIONAL {
    ?company :hasUID ?UID .
  }
}
'

# run SPARQL query
rdf_query(RDF, SPARQL)
