import csv
import requests
import pandas as pd
from SPARQLWrapper import SPARQLWrapper, JSON

# Filepath for the input CSV file
input_file = '/UID-mapping-companies.csv'
output_file = '/mnt/data/UID-mapping-companies-extended.csv'

# Endpoint for the LINDAS SPARQL service
sparql_endpoint = "https://lindas.admin.ch/query"

# Function to fetch the company IRI for a given UID
def fetch_company_iri(uid):
    query = f"""
    PREFIX schema: <http://schema.org/>
    SELECT ?company WHERE {{
      ?company a <https://schema.ld.admin.ch/ZefixOrganisation> .
      ?company schema:identifier ?id .
      ?id schema:name "CompanyUID" .
      ?id schema:value ?dbValue .
      FILTER(REPLACE("{uid}", "[^0-9A-Z]", "") = ?dbValue)
    }}
    """

    sparql = SPARQLWrapper(sparql_endpoint)
    sparql.setQuery(query)
    sparql.setReturnFormat(JSON)

    try:
        response = sparql.query().convert()
        results = response.get("results", {}).get("bindings", [])
        if results:
            return results[0]["company"]["value"]
        return None
    except Exception as e:
        print(f"Error fetching data for UID {uid}: {e}")
        return None

# Read the input CSV
input_data = pd.read_csv(input_file)

# Add a new column for IRI
input_data["IRI"] = input_data["UID"].apply(lambda uid: fetch_company_iri(uid))

# Save the extended data to a new CSV
input_data.to_csv(output_file, index=False)

print(f"Extended CSV has been saved to {output_file}")
