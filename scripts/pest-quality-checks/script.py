import json
import os
from openai import OpenAI

def refine_stressor(item, instructions, client):
    """
    Sends one JSON element to the OpenAI model for cleaning/refinement
    and returns the refined JSON element.
    """
    # Prepare the prompt messages:
    messages = [
        {
            "role": "system",
            "content": instructions.strip()
        },
        {
            "role": "user",
            "content": (
                "Here is a JSON structure about a *thing* in the Swiss plant protection product registry:\n\n"
                f"{json.dumps([item], ensure_ascii=False, indent=2)}\n\n"
                "Please respond only with the completed JSON structure."
            )
        }
    ]
    
    # Call the OpenAI model with the new interface:
    response = client.chat.completions.create(
        model="gpt-4o",           # The model name (replace with your model)
        messages=messages,
        temperature=0.8       # Use a low temperature for deterministic output
    )
    
    # Extract the content from the completion:
    raw_response = response.choices[0].message.content
    
    # Attempt to parse JSON. Fallback to returning the original item if it fails.
    try:
        refined_data = json.loads(raw_response)
    except json.JSONDecodeError:
        # If JSON parsing fails, return the original item
        return [item]
    
    # The model's response structure is presumably a list with a single dict:
    return refined_data

def main():
    # 1) Read instructions from prompt.md
    with open("prompt.md", "r", encoding="utf-8") as f:
        instructions = f.read()
    
    # 2) Read the original data
    with open("crop-stressors.json", "r", encoding="utf-8") as infile:
        original_data = json.load(infile)  # This should be a list of items
    
    # 3) Instantiate the OpenAI client. 
    #    By default, OpenAI() looks for an environment variable OPENAI_API_KEY.
    #    Or you can specify it directly here:
    client = OpenAI(
        api_key=os.environ.get("OPENAI_API_KEY", "YOUR-API-KEY")
    )
    
    refined_results = []
    
    # 4) Process each item one by one
    for idx, item in enumerate(original_data, start=1):
        print(f"Processing item {idx}/{len(original_data)} (srppp-id: {item.get('srppp-id')})")
        refined_list = refine_stressor(item, instructions, client)
        refined_results.extend(refined_list)
    
    # 5) Write the refined data to a new file
    with open("crop-stressors-refined.json", "w", encoding="utf-8") as outfile:
        json.dump(refined_results, outfile, indent=2, ensure_ascii=False)
    
    print("Refinement completed. Results are stored in 'crop-stressors-refined.json'.")

if __name__ == "__main__":
    main()
