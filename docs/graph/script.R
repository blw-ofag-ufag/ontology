library(visNetwork)
library(htmlwidgets)

triples <- unique(read.csv("instances.csv"))
nodes <- data.frame(
  id = unique(c(triples$Subject, triples$Object)),  # Unique subjects and objects
  label = unique(c(triples$Subject, triples$Object)),  # Labels for nodes
  group = ifelse(unique(c(triples$Subject, triples$Object)) %in% triples$Subject, "Subject", "Object"),  # Grouping
  title = unique(c(triples$Subject, triples$Object))
)
nodes$color = c("#fe8","#2af")[as.factor(nodes$group)]
edges <- data.frame(from = triples$Subject, to = triples$Object, title = triples$Predicate, arrows = "to", label = rep(NA, nrow(triples)))
network <- visNetwork(
  nodes, edges,
  height = "900px",
  width = "100%",
  background = "rgba(0, 0, 0, 0)"
) %>% 
  visOptions(highlightNearest = TRUE) %>%
  visLayout(randomSeed = 123)
saveWidget(network, file = "instances.html", selfcontained = TRUE)

triples <- read.csv("ontology.csv")
nodes <- data.frame(
  id = unique(c(triples$Subject, triples$Object)),  # Unique subjects and objects
  label = unique(c(triples$Subject, triples$Object)),  # Labels for nodes
  group = ifelse(unique(c(triples$Subject, triples$Object)) %in% triples$Subject, "Subject", "Object"),  # Grouping
  title = unique(c(triples$Subject, triples$Object))
)
nodes$color = c("#fe8","#2af")[as.factor(nodes$group)]
edges <- data.frame(from = triples$Subject, to = triples$Object, arrows = "to", label = "beinhaltet")
network <- visNetwork(
  nodes, edges,
  height = "900px",
  width = "100%",
  background = "rgba(0, 0, 0, 0)"
) %>% 
  visOptions(highlightNearest = TRUE) %>%
  visLayout(randomSeed = 1234)
saveWidget(network, file = "ontology.html", selfcontained = TRUE)

