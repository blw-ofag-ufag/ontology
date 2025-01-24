from owlready2 import *

# Load ontology
onto = get_ontology("ontology/system-map-ontology.ttl").load()

# Load instances
with open("data/system-map.ttl", "r") as f:
    data = f.read()
onto.load(fileobj=data, format="turtle")

# Perform reasoning
sync_reasoner()

# Save the inferred triples
onto.save(file="graph/system-map-inferred.ttl", format="turtle")
