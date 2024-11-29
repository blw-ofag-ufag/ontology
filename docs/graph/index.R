# load libraries
library(visNetwork)
library(htmlwidgets)
library(tibble)

# define what *things* exist (nodes)
nodes <- tribble(
  ~id,  ~label,
  1,    "Piretro Verde",
  2,    "Coral Extra",
  3,    "Lumino",
  4,    "Divo",
  5,    "Pyrethrine",
  6,    "Difenoconazol",
  7,    "Fludioxonil",
  8,    "Fungizid",
  9,    "Saatbeizmittel",
  10,   "Insektizid",
  11,   "Pflanzenschutzmittel",
  12,   "Wirkstoff",
)
nodes$physics = FALSE
nodes$color = "#89b"
nodes$font.color = "#fff"

# define relationships (edges)
edges <- tribble(
  ~from,    ~label,           ~to,   ~dashes,
  1,        "beinhaltet",     5,     FALSE,
  1,        "ist ein",        10,    TRUE,
  2,        "beinhaltet",     6,     FALSE,
  2,        "beinhaltet",     7,     FALSE,
  2,        "ist ein",        9,     TRUE,
  3,        "beinhaltet",     6,     FALSE,
  3,        "ist ein",        8,     TRUE,
  4,        "beinhaltet",     6,     FALSE,
  4,        "ist ein",        8,     TRUE,
  8,        "ist ein",        11,    TRUE,
  9,        "ist ein",        11,    TRUE,
  10,       "ist ein",        11,    TRUE,
  11,       "beinhaltet",     12,    FALSE,
  7,        "ist ein",        12,    TRUE,
  6,        "ist ein",        12,    TRUE,
  5,        "ist ein",        11,    TRUE,
)
edges$arrows = "to"
edges$color = "#bcd"

# Create the network visualization
network <- visNetwork(nodes,
                      edges,
                      height = "900px",
                      width = "100%",
                      background = "rgba(0, 0, 0, 0)") %>%
  visNodes(shape = "box") %>%
  visInteraction(dragNodes = TRUE) %>%
  visLayout(randomSeed = 8) %>%
  visOptions(
    highlightNearest = list(
      enabled = TRUE,
      degree = 1,
      hover = TRUE,
      hideColor = "rgba(200,200,200,0.2)"
    )
  )

# Display the network
saveWidget(network, file = "index.html", selfcontained = TRUE)





