# :page_with_curl: How to work with the ontology

> [!NOTE]
> This GitHub repository is used as a proof-of-concept. It does not contain any official information from the Federal Office for Agriculture.

## Visual ontology exploration

To (visually) inspect the example ontology, open [this link](https://service.tib.eu/webvowl/#iri=https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/graph/plant-protection.ttl) to open it using WebVOWL. The service fetches the ontology directly from this repository (i.e., from the `plant-protection.ttl` file).


## Repository structure

This repository is structured as follows:

1. `/ontology` contains turtle files of specific OWL ontologies.
2. `/data` contains turtle files with the actual data (following the aforementioned ontologies).
3. `/shapes` contains SHACL shapes for the graph.
4. `/graph` contains the entire graph, i.e. the merged ontologies, shapes and data files.
5. `/scripts` contains scripts.

# 🌐 Demonstration sites

- <https://blw-ofag-ufag.github.io/ontology/presentation>
- <https://blw-ofag-ufag.github.io/ontology/embeddings>
- <https://blw-ofag-ufag.github.io/ontology/class-table>
- <https://blw-ofag-ufag.github.io/ontology/crop-table>