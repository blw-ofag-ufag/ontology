import rdflib
from owlrl import DeductiveClosure, OWLRL_Semantics

# 1) Create an rdflib graph
g = rdflib.Graph()

# 2) Parse ontology and data
g.parse("ontology/system-map-ontology.ttl", format="turtle")
g.parse("data/system-map.ttl", format="turtle")

# 3) Perform inference (OWL 2 RL via owlrl)
DeductiveClosure(OWLRL_Semantics).expand(g)

# 4) Clean up the graph
for s, p, o in list(g):
    # Remove triples where the subject is a literal
    if isinstance(s, rdflib.Literal):
        g.remove((s, p, o))
    # Remove unnecessary `owl:sameAs` triples where subject == object
    elif p == rdflib.OWL.sameAs and s == o:
        g.remove((s, p, o))

# 5) Save the cleaned graph
g.serialize(destination="graph/system-map-inferred.ttl", format="turtle")
print("Filtered inferred graph saved to graph/system-map-inferred.ttl.")
