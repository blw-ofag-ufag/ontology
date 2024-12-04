library(srppp)
library(rdflib)

# download current SRPPP register
current_register <- srppp_dm()
dm_draw(current_register)

# tabellen
current_register$products
unique(current_register$categories[,-1])
unique(current_register$formulation_codes[,-1])
unique(current_register$danger_symbols[,-1])
unique(current_register$CodeS[,-1])
unique(current_register$CodeR[,-1])
unique(current_register$CodeS[,-1])
unique(current_register$signal_words[,-1])
current_register$parallel_imports

current_register$substances
current_register$ingredients
current_register$uses
unique(current_register$application_comments[,-c(1,2)])
unique(current_register$culture_forms[,-c(1,2)])
unique(current_register$cultures[,-c(1,2)])
unique(current_register$pests[,-c(1,2)])
unique(current_register$obligations[,-c(1,2)])

# comments (in German)
S = current_register$CodeS$CodeS_de |> unique()
R = current_register$CodeR$CodeR_de |> unique()
current_register$application_comments$application_comment_de |> unique()
current_register$obligations$code |> unique()

# extract obligations
x = current_register$obligations$obligation_de |>
  table() |>
  sort(decreasing = T)
y = names(x)
obligations = data.frame(id = 1:length(y), obligation = y, count = as.integer(x))
write.csv(obligations, "obligations.csv", row.names = FALSE)

# current_register$products
# current_register$ingredients
# current_register$formulation_codes
# current_register$substances

# current_register$uses |> View()
# current_register$uses$units_de |> unique()
# current_register$cultures$culture_de |> unique()
# current_register$culture_forms

# Define prefixes

# Products
X = as.data.frame(current_register$products)
X = X[order(X$pNbr),]
X[X==""] <- NA
for (i in 1:nrow(X)) {
  sprintf("\n:<Products/%s> a :Product ;", X[i,"wNbr"]) |> cat()
  sprintf("\n    rdfs:label \"%s\" ;", X[i,"name"]) |> cat()
  sprintf("\n    :hasFederalRegistrationCode \"%s\" ;", X[i,"wNbr"]) |> cat()
  if(!is.na(X[i,"exhaustionDeadline"])) sprintf("\n    :hasExhaustionDeadline \"%s\" ;", X[i,"exhaustionDeadline"]) |> cat()
  if(!is.na(X[i,"soldoutDeadline"])) sprintf("\n    :hasExhaustionDeadline \"%s\" ;", X[i,"soldoutDeadline"]) |> cat()
  sprintf("\n    :hasPermissionHolder \"%s\" .", X[i,"wNbr"]) |> cat()
}
