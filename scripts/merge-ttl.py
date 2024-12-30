from rdflib import Graph
import os

def merge_ttl_files(file_list, output_file):
    merged_graph = Graph()
    for file_path in file_list:
        if file_path.endswith(".ttl"):
            print(f"Reading file: {file_path}")
            merged_graph.parse(file_path, format="turtle")
    print(f"Writing merged graph to: {output_file}")
    merged_graph.serialize(destination=output_file, format="turtle")

if __name__ == "__main__":
    file_list = [
        "ontology/plant-protection-ontology.ttl",
        "data/products.ttl",
        "data/companies.ttl",
        "data/hazard-statements.ttl",
        "data/crops.ttl",
        "data/crop-stressors.ttl"
    ]
    output_file = "graph/plant-protection.ttl"
    merge_ttl_files(file_list, output_file)
