# load libraries
library(visNetwork)
library(htmlwidgets)
library(tibble)

# define what *things* exist (nodes)
nodes <- tribble(
  ~id,  ~label,                ~x,   ~y,
  1,    "Piretro Verde",       0,    600,
  2,    "Coral Extra",         1100, 900,
  3,    "Lumino",              900,  600,
  4,    "Divo",                600,  350,
  5,    "Pyrethrine",          300,  200,
  6,    "Difenoconazol",       1100, 450,
  7,    "Fludioxonil",         1400, 350,
  8,    "Fungizid",            550,  550,
  9,    "Saatbeizmittel",      600,  900,
  10,   "Insektizid",          150,  900,
  11,   "Pflanzenschutzmittel",300,  700,
  12,   "Wirkstoff",           600,  150
)
nodes$physics = FALSE
nodes$color = "#444"
nodes$font.color = "#fff"
nodes$font.size = 30

# define relationships (edges)
edges <- tribble(
  ~from,    ~label,           ~to,   ~dashes,
  1,        "beinhaltet",     5,     FALSE,
  1,        "ist ein",        10,    TRUE,
  2,        "beinhaltet",     6,     FALSE,
  2,        "beinhaltet",     7,     FALSE,
  2,        "ist ein",        9,     TRUE,
  2,        "ist ein",        8,     TRUE,
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
  5,        "ist ein",        12,    TRUE,
)
edges$arrows = "to"
edges$color = "#bbb"
edges$font.color = "#888"
edges$font.size = 24

# Create the network visualization
network <- visNetwork(nodes,
                      edges,
                      height = "950px",
                      width = "100%") %>%
  visNodes(shape = "box") %>%
  visInteraction(dragNodes = TRUE) %>%
  visLayout(randomSeed = 8) %>%
  visOptions(
    highlightNearest = list(
      enabled = TRUE,
      degree = 1,
      hover = TRUE,
      hideColor = "rgba(240,240,240,256)"
    )
  )

# Write a HTML file displaying the network
saveWidget(network, file = "index.html", selfcontained = TRUE)





