# :page_with_curl: How to work with the ontology

> [!NOTE]
> This GitHub repository is used as a proof-of-concept. It does not contain any official information from the Federal Office for Agriculture.

## Visual ontology exploration

In order to visually explore the ontologies, you can use WebVOWL. The following links will open the current drafts for ontologies:

- [**A plant protection ontology for Swiss agriculture.**](https://service.tib.eu/webvowl/#iri=https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/ontology/plant-protection-ontology.ttl)
- [**An ontology to model IT systems relevant for the Swiss agri-food sector.**](https://service.tib.eu/webvowl/#iri=https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/ontology/system-map-ontology.ttl)
- [**Fully connected ontology with instance count.**](https://service.tib.eu/webvowl/#iri=https://raw.githubusercontent.com/blw-ofag-ufag/ontology/refs/heads/main/graph/plant-protection.ttl)

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
