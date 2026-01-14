#!/usr/bin/env python3
"""
Convert paraphrase-MiniLM-L6-v2 to Core ML format for iOS.

Usage:
    pip install transformers coremltools torch
    python convert_to_coreml.py

Output:
    - InsightApp/Resources/MiniLM.mlpackage (Core ML model)
    - InsightApp/Resources/vocab.txt (tokenizer vocabulary)
"""

import torch
import coremltools as ct
from transformers import AutoTokenizer, AutoModel
import numpy as np
import shutil
from pathlib import Path

MODEL_NAME = "sentence-transformers/paraphrase-MiniLM-L6-v2"
OUTPUT_DIR = Path("InsightApp/Sources/InsightApp/Resources")


def mean_pooling(model_output, attention_mask):
    """Mean pooling - take attention mask into account for averaging."""
    token_embeddings = model_output[0]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)


class SentenceTransformerWrapper(torch.nn.Module):
    """Wrapper that includes mean pooling and normalization."""

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        embeddings = mean_pooling(outputs, attention_mask)
        # L2 normalize
        embeddings = torch.nn.functional.normalize(embeddings, p=2, dim=1)
        return embeddings


def convert_model():
    print(f"Loading model: {MODEL_NAME}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModel.from_pretrained(MODEL_NAME)

    # Set model to evaluation mode
    model.train(False)

    # Wrap with mean pooling
    wrapped_model = SentenceTransformerWrapper(model)
    wrapped_model.train(False)

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Save vocabulary
    vocab_path = OUTPUT_DIR / "vocab.txt"
    vocab = tokenizer.get_vocab()
    sorted_vocab = sorted(vocab.items(), key=lambda x: x[1])
    with open(vocab_path, 'w', encoding='utf-8') as f:
        for token, _ in sorted_vocab:
            f.write(token + '\n')
    print(f"Saved vocabulary ({len(vocab)} tokens) to {vocab_path}")

    # Example input for tracing
    max_length = 128  # Max sequence length
    example_text = "This is an example sentence for tracing."
    inputs = tokenizer(
        example_text,
        padding='max_length',
        max_length=max_length,
        truncation=True,
        return_tensors='pt'
    )

    print(f"Tracing model with max_length={max_length}...")

    # Trace the model
    with torch.no_grad():
        traced_model = torch.jit.trace(
            wrapped_model,
            (inputs['input_ids'], inputs['attention_mask'])
        )

    # Convert to Core ML
    print("Converting to Core ML...")

    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, max_length), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, max_length), dtype=np.int32),
        ],
        outputs=[
            ct.TensorType(name="embeddings", dtype=np.float32),
        ],
        minimum_deployment_target=ct.target.iOS16,
        compute_precision=ct.precision.FLOAT32,
    )

    # Add metadata
    mlmodel.author = "Sentence Transformers"
    mlmodel.short_description = "paraphrase-MiniLM-L6-v2 sentence embedding model"
    mlmodel.version = "1.0"

    # Save the model
    model_path = OUTPUT_DIR / "MiniLM.mlpackage"
    if model_path.exists():
        shutil.rmtree(model_path)
    mlmodel.save(str(model_path))

    print(f"Saved Core ML model to {model_path}")

    # Print model info
    print("\nModel Info:")
    print(f"  Input: input_ids (1, {max_length}) int32")
    print(f"  Input: attention_mask (1, {max_length}) int32")
    print(f"  Output: embeddings (1, 384) float32")

    # Verify the conversion
    print("\nVerifying conversion...")

    # Test with original model
    with torch.no_grad():
        original_embedding = wrapped_model(inputs['input_ids'], inputs['attention_mask'])

    # Test with Core ML model
    coreml_input = {
        'input_ids': inputs['input_ids'].numpy().astype(np.int32),
        'attention_mask': inputs['attention_mask'].numpy().astype(np.int32),
    }
    coreml_output = mlmodel.predict(coreml_input)
    coreml_embedding = coreml_output['embeddings']

    # Compare
    original_np = original_embedding.numpy().flatten()
    coreml_np = coreml_embedding.flatten()

    cosine_sim = np.dot(original_np, coreml_np) / (np.linalg.norm(original_np) * np.linalg.norm(coreml_np))
    max_diff = np.max(np.abs(original_np - coreml_np))

    print(f"  Cosine similarity: {cosine_sim:.6f}")
    print(f"  Max absolute diff: {max_diff:.6f}")

    if cosine_sim > 0.999:
        print("  Conversion successful!")
    else:
        print("  Warning: Conversion may have precision issues")

    return model_path, vocab_path


if __name__ == "__main__":
    convert_model()
