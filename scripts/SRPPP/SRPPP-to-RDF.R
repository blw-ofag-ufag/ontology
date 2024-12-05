library(srppp)
library(rdflib)

# download current SRPPP register
current_register <- srppp_dm()
dm_draw(current_register)

# tabellen
# current_register$products
# unique(current_register$categories[,-1])
# unique(current_register$formulation_codes[,-1])
# unique(current_register$danger_symbols[,-1])
# unique(current_register$CodeS[,-1])
# unique(current_register$CodeR[,-1])
# unique(current_register$CodeS[,-1])
# unique(current_register$signal_words[,-1])
# current_register$parallel_imports
# 
# current_register$substances
# current_register$ingredients
# current_register$uses
# unique(current_register$application_comments[,-c(1,2)])
# unique(current_register$culture_forms[,-c(1,2)])
# unique(current_register$cultures[,-c(1,2)])
# unique(current_register$pests[,-c(1,2)])
# unique(current_register$obligations[,-c(1,2)])
# 
# # comments (in German)
# S = current_register$CodeS$CodeS_de |> unique()
# R = current_register$CodeR$CodeR_de |> unique()
# current_register$application_comments$application_comment_de |> unique()
# current_register$obligations$code |> unique()
# 
# # extract obligations
# x = current_register$obligations$obligation_de |>
#   table() |>
#   sort(decreasing = T)
# y = names(x)
# obligations = data.frame(id = 1:length(y), obligation = y, count = as.integer(x))
# write.csv(obligations, "obligations.csv", row.names = FALSE)

# current_register$products
# current_register$ingredients
# current_register$formulation_codes
# current_register$substances

# current_register$uses |> View()
# current_register$uses$units_de |> unique()
# current_register$cultures$culture_de |> unique()
# current_register$culture_forms

sink("ontology/data.ttl")

# Define prefixes
cat("@prefix : <https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/plant-protection.ttl#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix dc: <http://purl.org/dc/terms/> .
@prefix wd: <http://www.wikidata.org/entity/> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n")

# pre-process tables
products = as.data.frame(current_register$products)
products = products[order(products$pNbr),]
products[products==""] <- NA
categories = as.data.frame(current_register$categories)

# function to assign classes given an ID
f = function(id, categories) {
  categories[categories[,"pNbr"]==id,"desc_pk"]
}
f(38, categories)

# write triples
for (i in 1:nrow(products)) {
  sprintf("\n:1-W-%s a :Product ;", products[i,"wNbr"]) |> cat()
  sprintf("\n    rdfs:label \"%s\"^^xsd:string ;", products[i,"name"]) |> cat()
  sprintf("\n    :hasFederalRegistrationCode \"W-%s\"^^xsd:string ;", products[i,"wNbr"]) |> cat()
  if(!is.na(products[i,"exhaustionDeadline"])) sprintf("\n    :hasExhaustionDeadline \"%s\"^^xsd:date ;", products[i,"exhaustionDeadline"]) |> cat()
  if(!is.na(products[i,"soldoutDeadline"])) sprintf("\n    :hasSoldoutDeadline \"%s\"^^xsd:date ;", products[i,"soldoutDeadline"]) |> cat()
  if(i>1) if(products[i,1]==products[i-1,1]) sprintf("\n    :isSameProductAs :1-W-%s ;", products[i-1,"wNbr"]) |> cat()
  if(sum(products[,"pNbr"]==products[i,"pNbr"])>1) {
    for (j in which(products[,"pNbr"]==products[i,"pNbr"])) {
      if(i != j) sprintf("\n    :isSameProductAs :1-W-%s ;", products[j,"wNbr"]) |> cat()
    }
  }
  sprintf("\n    :hasPermissionHolder :2-%s .", products[i,"permission_holder"]) |> cat()
}

sink()

