import pandas as pd
from openai import OpenAI
import csv

# Initialize OpenAI client
client = OpenAI()

# Read the existing CSV
df = pd.read_csv('/home/damian.oswald@blw.admin.ch/ontology/SRPPP/obligations.csv')

# List to store the results
results = []

# Iterate over each row in the DataFrame
for index, row in df.iterrows():
    id = row['id']
    obligation = row['obligation']
    
    # Get the embedding for the obligation text
    response = client.embeddings.create(
        input=obligation,
        model="text-embedding-3-large",
        dimensions=100
    )
    embedding = response.data[0].embedding
    
    # Append the results
    results.append({
        'id': id,
        'obligation': obligation,
        'embedding': embedding
    })

    print(id)

# Create a data frame from the results
df_results = pd.DataFrame(results)

# Expand the embedding list into separate columns
embedding_df = pd.DataFrame(df_results['embedding'].tolist())

# Concatenate the id, obligations, and embedding columns
final_df = pd.concat([df_results[['id', 'obligation']], embedding_df], axis=1)

# Write the final DataFrame to embeddings.csv
final_df.to_csv(
    '/home/damian.oswald@blw.admin.ch/ontology/SRPPP/embeddings-100.csv',
    index=False,
    quoting=csv.QUOTE_ALL
)
