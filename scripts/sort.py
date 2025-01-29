from rdflib import Graph
from otsrdflib import OrderedTurtleSerializer

def sort_and_overwrite_turtle(file_path):
    # Load the graph from the Turtle file
    graph = Graph()
    graph.parse(file_path, format="turtle")

    # Serialize the graph with ordered subjects and overwrite the original file
    with open(file_path, 'wb') as f:
        serializer = OrderedTurtleSerializer(graph)
        serializer.serialize(f)

    print(f"File '{file_path}' has been sorted and overwritten.")

if __name__ == "__main__":
    file_list = ["ontology/system-map-ontology.ttl", "ontology/plant-protection-ontology.ttl"]
    for file_path in file_list:
        sort_and_overwrite_turtle(file_path)
