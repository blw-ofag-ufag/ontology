library(srppp)
library(DiagrammeR)

current_register <- srppp_dm()
dm_draw(current_register)

current_register$CodeS

# comments (in German)
S = current_register$CodeS$CodeS_de |> unique()
R = current_register$CodeR$CodeR_de |> unique()
current_register$application_comments$application_comment_de |> unique()
current_register$obligations$code |> unique()

sink("obligations.txt")
x = current_register$obligations$obligation_de |>
  table() |>
  sort(decreasing = T)
y = names(x)
cat("AUFLAGEN PSMV\n\n")
for (i in 1:length(x)) cat(sprintf("%s: %s (%s)\n", i, y[i], x[i]))
sink()


current_register$products
current_register$ingredients
current_register$formulation_codes
current_register$substances

current_register$uses |> View()
current_register$uses$units_de |> unique()
current_register$cultures$culture_de |> unique()
current_register$culture_forms



# Code S to RDF
X = as.data.frame(unique(current_register$CodeS[,3:6]))
for (i in 1:nrow(X)) {
  cat(sprintf("\n:hazardLabelS%s a :hazardLabel ; \n\trdfs:label \"%s\"@de , \n\t\t\"%s\"@fr , \n\t\t\"%s\"@it", i, X[i,2], X[i,3], X[i,4]))
  if(is.na(X[i,1]) | grepl("^\\s*$", X[i,1])) cat(".") else cat(sprintf(" ;\n\t:hasGHScode \"%s\" .", X[i,1]))
}


