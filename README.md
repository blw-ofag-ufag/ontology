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

- [**What is an ontology and how can it help us?**](https://blw-ofag-ufag.github.io/ontology/presentation) An internal presentation to give some motivation to work on this project, first held on 12 December 2024.
- [**Clustering the many SRPPP obligations.**](https://blw-ofag-ufag.github.io/ontology/embeddings) A brief documentation of how the clustering of the Swiss registry of plant protection products (SRPPP) was performed using A.I.
- [**Class overview:**](https://blw-ofag-ufag.github.io/ontology/class-table) Just an interactive table that fetches all class names and descriptions from LINDAS and counts the respective instances per class.
- [**A crop table with alternative names:**](https://blw-ofag-ufag.github.io/ontology/crop-table) Alternative names are important for good user experiences in complex systems, because different people use differnt names for the same thing.