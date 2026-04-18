import json
import os
import csv
import random

def extract_condition(question):
    """Simple heuristic to extract the medical focus from the question"""
    # Remove common phrases
    q = question.lower().replace("what is", "").replace("what are symptoms of", "").replace("?", "").strip()
    return q.capitalize()

def generate_clinical_thought(instruction, response):
    """Synthesizes clinical reasoning to train the model's thinking layer"""
    condition = extract_condition(instruction)
    
    thinking_templates = [
        f"The user is asking about {condition}. I need to clarify clinical manifestations and secondary symptoms to differentiate from similar pathologies. I will also evaluate if a vertical flowchart for diagnostic triage is appropriate.",
        f"Evaluating {condition} as the primary query. I must check for emergency red flags (red-dot symptoms) and then provide a structured answer. A linear diagnostic path (Mermaid) helps visualize the next clinical steps.",
        f"Inquiry received for {condition}. I will weigh differential diagnoses, assess risk factors, and then generate a report including a vertical clinical pathway for clear decision making."
    ]
    return random.choice(thinking_templates)

def load_medquad_data(file_path):
    """Loads and transforms medquad.csv into reasoning-based training data"""
    data = []
    print(f"Reading {file_path}...")
    
    with open(file_path, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            instruction = row['Question']
            base_response = row['Answer']
            
            # Injecting clinical structure
            thought = generate_clinical_thought(instruction, base_response)
            
            # Simple prompt for Mermaid mastery: If it's a symptoms question, 
            # we encourage the model to suggest a chart.
            if row['qtype'] == 'symptoms':
                mermaid_appendix = f"\n\n### Clinical Pathway\n```mermaid\nflowchart TD\nS1[Assess Primary Symptoms] --> S2[Check for Frequency] --> S3[Evaluate Secondary Signs]\n```"
                final_response = f"## Assessment: {extract_condition(instruction)}\n\n{base_response}{mermaid_appendix}"
            else:
                final_response = f"## Information: {extract_condition(instruction)}\n\n{base_response}"

            data.append({
                "instruction": instruction,
                "thought": thought,
                "response": final_response
            })
    return data

def format_gemma_chat(row):
    """Formats row into Gemma 4's specific chat template"""
    return {
        "text": f"<|turn|>user\n{row['instruction']}<turn|>\n<|turn|>model\n<|channel>thought\n{row['thought']}<channel|>\n{row['response']}<turn|>"
    }

def save_dataset(data, folder="carenest_combined_data"):
    if not os.path.exists(folder):
        os.makedirs(folder)
    
    # Shuffle for better training distribution
    random.shuffle(data)
    
    # MLX usually looks for train.jsonl and valid.jsonl
    split = int(len(data) * 0.9)
    train_data = [format_gemma_chat(r) for r in data[:split]]
    valid_data = [format_gemma_chat(r) for r in data[split:]]

    with open(f"{folder}/train.jsonl", "w") as f:
        for entry in train_data:
            f.write(json.dumps(entry) + "\n")
            
    with open(f"{folder}/valid.jsonl", "w") as f:
        for entry in valid_data:
            f.write(json.dumps(entry) + "\n")
            
    print(f"Success! {len(data)} samples processed.")
    print(f"Dataset saved to {folder}/")

if __name__ == "__main__":
    csv_path = "medquad.csv"
    if os.path.exists(csv_path):
        data = load_medquad_data(csv_path)
        save_dataset(data)
    else:
        print(f"Error: {csv_path} not found in the current directory.")