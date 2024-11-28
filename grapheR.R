library(visNetwork)
triples <- read.csv("presentation/SOP.csv")
nodes <- data.frame(
  id = unique(c(triples$Subject, triples$Object)),
  label = unique(c(triples$Subject, triples$Object)),
  group = ifelse(unique(c(triples$Subject, triples$Object)) %in% triples$Subject, "Subject", "Object")
)
edges <- data.frame(
  from = triples$Subject,
  to = triples$Object,
  label = triples$Predicate
)
visNetwork(nodes, edges) %>%
  visEdges(arrows = "to") %>%
  visOptions(highlightNearest = TRUE, nodesIdSelection = FALSE, collapse = TRUE) %>%
  visLayout(randomSeed = 42)
