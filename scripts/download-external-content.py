import requests
import os
import rdflib
from xml.etree import ElementTree as ET

# SPARQL query
query = """
PREFIX wd: <http://www.wikidata.org/entity/>
PREFIX wdt: <http://www.wikidata.org/prop/direct/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?country ?iso_alpha2 ?iso_alpha3 ?label_en ?label_de ?label_fr ?label_it
WHERE {
  ?country wdt:P31 wd:Q6256 .
  FILTER NOT EXISTS { ?country wdt:P576 ?dissolutionDate }
  OPTIONAL { ?country wdt:P297 ?iso_alpha2 }
  OPTIONAL { ?country wdt:P298 ?iso_alpha3 }
  OPTIONAL { ?country rdfs:label ?label_en FILTER (lang(?label_en) = "en") }
  OPTIONAL { ?country rdfs:label ?label_de FILTER (lang(?label_de) = "de") }
  OPTIONAL { ?country rdfs:label ?label_fr FILTER (lang(?label_fr) = "fr") }
  OPTIONAL { ?country rdfs:label ?label_it FILTER (lang(?label_it) = "it") }
}
ORDER BY ?country
"""

# URL encode the query
url = "https://query.wikidata.org/sparql"
headers = {"Accept": "application/sparql-results+xml"}  # Request XML format
response = requests.get(url, headers=headers, params={"query": query})

# Ensure the directory exists
filename_xml = "ontology/countries.xml"
os.makedirs(os.path.dirname(filename_xml), exist_ok=True)

# Save raw results to XML file
with open(filename_xml, "wb") as file:
    file.write(response.content)

print(f"Query results saved as {filename_xml}")

# Parse and convert XML to Turtle format manually
def xml_to_ttl(input_file, output_file):
    graph = rdflib.Graph()

    # Parse the XML using ElementTree
    tree = ET.parse(input_file)
    root = tree.getroot()
    sparql_ns = "{http://www.w3.org/2005/sparql-results#}"

    for result in root.findall(f"{sparql_ns}results/{sparql_ns}result"):
        
        country = None
        iso_alpha2 = None
        iso_alpha3 = None
        labels = {}

        for binding in result.findall(f"{sparql_ns}binding"):
            name = binding.attrib['name']
            if name == "country":
                country = binding.find(f"{sparql_ns}uri").text
            elif name in ["iso_alpha2", "iso_alpha3"]:
                value = binding.find(f"{sparql_ns}literal").text
                if name == "iso_alpha2":
                    iso_alpha2 = value
                elif name == "iso_alpha3":
                    iso_alpha3 = value
            elif name.startswith("label_"):
                lang = name.split("_")[1]
                value = binding.find(f"{sparql_ns}literal").text
                labels[lang] = value

        # Add triples to the graph
        if country:
            country_prefix = rdflib.Namespace("http://www.wikidata.org/entity/")
            country_uri = country_prefix[country.split('/')[-1]]
            graph.add((country_uri, rdflib.RDF.type, rdflib.URIRef("http://www.wikidata.org/entity/Q6256")))  # Define country as a wd:Q6256
            if iso_alpha2:
                graph.add((country_uri, rdflib.URIRef("http://www.wikidata.org/prop/direct/P297"), rdflib.Literal(iso_alpha2)))
            if iso_alpha3:
                graph.add((country_uri, rdflib.URIRef("http://www.wikidata.org/prop/direct/P298"), rdflib.Literal(iso_alpha3)))
            for lang, label in labels.items():
                graph.add((country_uri, rdflib.RDFS.label, rdflib.Literal(label, lang=lang)))

    graph.bind("wd", "http://www.wikidata.org/entity/")
    graph.bind("wdt", "http://www.wikidata.org/prop/direct/")
    graph.serialize(destination = output_file, format="turtle")
    
    print(f"Converted results saved as {output_file}")

# Convert the XML to TTL
filename_ttl = "ontology/countries.ttl"
xml_to_ttl(filename_xml, filename_ttl)

# Delete the XML file
os.remove(filename_xml)
print(f"Deleted temporary file: {filename_xml}")

