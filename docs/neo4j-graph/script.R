library(visNetwork)
library(htmlwidgets)  # Needed for saveWidget()

# Read your data
triples <- unique(read.csv("SOP.csv"))

# Create nodes and edges data frames
nodes <- data.frame(
  id = unique(c(triples$Subject, triples$Object)),  # Unique subjects and objects
  #label = rep(NA, 16),
  label = unique(c(triples$Subject, triples$Object)),  # Labels for nodes
  group = ifelse(unique(c(triples$Subject, triples$Object)) %in% triples$Subject, "Subject", "Object"),  # Grouping
  title = unique(c(triples$Subject, triples$Object))
)
nodes$color = c("#fe8","#2af")[as.factor(nodes$group)]

edges <- data.frame(from = triples$Subject, to = triples$Object, title = triples$Predicate, arrows = "to", label = rep(NA, 36))

# Create the network graph
network <- visNetwork(
  nodes, edges,
  height = "900px",
  width = "100%",
  background = "rgba(0, 0, 0, 0)"
) %>% 
  visOptions(highlightNearest = TRUE) %>%
  visLayout(randomSeed = 123)

# Save the network graph to an HTML file
saveWidget(network, file = "index.html", selfcontained = TRUE)
