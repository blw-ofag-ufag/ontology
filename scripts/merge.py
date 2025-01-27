from rdflib import Graph
import os

def merge_ttl_files(file_list, output_file):
    merged_graph = Graph()
    for file_path in file_list:
        if file_path.endswith(".ttl"):
            print(f"Processing file: {file_path}")
            graph = Graph()
            graph.parse(file_path, format="turtle")
            
            # Overwrite the original file with the reformatted content
            graph.serialize(destination=file_path, format="turtle")
            print(f"Reformatted file: {file_path}")
            
            # Merge into the main graph
            merged_graph += graph
    
    # Serialize the merged graph
    print(f"Writing merged graph to: {output_file}")
    merged_graph.serialize(destination=output_file, format="turtle")

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
        "data/environmental"
    ]
    output_file = "graph/plant-protection.ttl"
    merge_ttl_files(file_list, output_file)
