import requests
import os
import pandas as pd

def query_wikidata_eppo_code(taxon_id):
    """
    Query Wikidata to check if the given taxon ID has an EPPO code.

    Parameters:
        taxon_id (str): Wikidata ID of the taxon (e.g., "Q293311").

    Returns:
        dict: EPPO code if available, otherwise None.
    """
    # SPARQL query to check for EPPO code
    sparql_query = f"""
    SELECT ?eppo_code WHERE {{
      wd:{taxon_id} wdt:P3031 ?eppo_code.
    }}
    """

    # Endpoint URL for Wikidata SPARQL API
    endpoint_url = "https://query.wikidata.org/sparql"

    # Perform the query
    response = requests.get(
        endpoint_url,
        params={"query": sparql_query, "format": "json"},
        headers={"User-Agent": "PythonWikidataQuery/1.0 (your-email@example.com)"}
    )

    # Check if the request was successful
    if response.status_code != 200:
        raise Exception(f"Failed to fetch data: HTTP {response.status_code} - {response.text}")

    # Parse the JSON response
    data = response.json()
    results = data.get("results", {}).get("bindings", [])

    # Extract and return EPPO code if available
    if results:
        return {"eppo_code": results[0]["eppo_code"]["value"]}
    else:
        return {"eppo_code": None}

if __name__ == "__main__":
    # Check if the file exists
    file_path = 'mapping-tables/wikidata-mapping-biological-taxa.csv'
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"File not found: {file_path}")

    # Load the CSV file
    data = pd.read_csv(file_path)

    # Handle cases where 'Wikidata_IRI' might be missing or NaN
    if 'Wikidata_IRI' not in data.columns:
        raise ValueError("The input file must contain a 'Wikidata_IRI' column.")

    # Query for each taxon in the file
    for index, row in data.iterrows():
        wikidata_iri = row.get("Wikidata_IRI")
        if pd.isna(wikidata_iri) or wikidata_iri == "":
            continue  # Skip missing or empty IRIs

        taxon_id = str(wikidata_iri).split("/")[-1]
        try:
            result = query_wikidata_eppo_code(taxon_id)
            if result["eppo_code"] is None:
                print(f"Missing EPPO code for taxon: {wikidata_iri}")
        except Exception as e:
            print(f"Error querying taxon {taxon_id}: {e}")
