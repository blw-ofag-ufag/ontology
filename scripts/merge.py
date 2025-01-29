from rdflib import Graph
from otsrdflib import OrderedTurtleSerializer
import os

def sort_and_overwrite_turtle(graph, file_path):
    """Sorts the RDF graph and overwrites the given Turtle file."""
    with open(file_path, 'wb') as f:
        serializer = OrderedTurtleSerializer(graph)
        serializer.serialize(f)

    print(f"File '{file_path}' has been sorted and overwritten.")

def merge_and_sort_ttl_files(file_list, output_file):
    """Merges Turtle files, sorts them, and writes the sorted graph back to disk."""
    merged_graph = Graph()

    for file_path in file_list:
        if file_path.endswith(".ttl"):
            print(f"Processing file: {file_path}")
            graph = Graph()
            graph.parse(file_path, format="turtle")

            # Sort and overwrite the original file
            sort_and_overwrite_turtle(graph, file_path)

            # Merge into the main graph
            merged_graph += graph
    
    # Sort and serialize the merged graph
    print(f"Writing sorted merged graph to: {output_file}")
    sort_and_overwrite_turtle(merged_graph, output_file)

if __name__ == "__main__":
    file_list = [
        "ontology/system-map-ontology.ttl",
        "ontology/plant-protection-ontology.ttl",
        "data/system-map.ttl",
        "data/products.ttl",
        "data/companies.ttl",
        "data/hazard-statements.ttl",
        "data/crops.ttl",
        "data/crop-stressors.ttl",
        "data/environmental.ttl"
    ]
    output_file = "graph/plant-protection.ttl"
    
    merge_and_sort_ttl_files(file_list, output_file)
