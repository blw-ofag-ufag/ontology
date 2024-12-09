# add libraries to search path
library(rdflib)
library(jsonld)

# EXAMPLE 1 : READ THE ONTOLOGY FILE DIRECTLY ----------------------------------------------------------

# set path to RDF file
RDF = rdf_parse("ontology/test.ttl")

# define SPARQL query
SPARQL = '
PREFIX : <https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/plant-protection.ttl#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?productName ?code ?companyName ?substanceName ?parallel ?nonProfessional
WHERE {
  ?product a :Product .
  ?product rdfs:label ?productName .
  ?product :hasFederalRegistrationCode ?code .
  OPTIONAL {
    ?company :holdsPermissionToSell ?product .
    ?company rdfs:label ?companyName .
  }
  OPTIONAL { 
    ?product :contains ?substance .
    ?substance rdfs:label ?substanceName .
  }
  OPTIONAL { ?product :isParallelImport ?parallel . }
  OPTIONAL { ?product :isNonprofessionallyAllowed ?nonProfessional . }
}
LIMIT 10
'

# run SPARQL query
rdf_query(RDF, SPARQL)

# EXAMPLE 2 : READ THE DATA FILE -------------------------------------------------------------------------

# set path to RDF file
RDF = rdf_parse("ontology/data.ttl")

# define SPARQL query
SPARQL = '
PREFIX : <https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/plant-protection.ttl#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?companyName (COUNT(DISTINCT ?product) AS ?productCount)
WHERE {
  ?product a :Product .
  ?product :hasPermissionHolder ?company .
  ?company rdfs:label ?companyName .
}
GROUP BY ?company
ORDER BY DESC(?productCount)  # Optional, orders by the number of products in descending order
'

# run SPARQL query
rdf_query(RDF, SPARQL)



