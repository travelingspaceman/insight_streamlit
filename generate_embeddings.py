#!/usr/bin/env python3
"""
Generate embeddings for all paragraphs using paraphrase-MiniLM-L6-v2.

Usage:
    python generate_embeddings.py paragraphs.json embeddings.json

This reads paragraphs from the input JSON and generates embeddings using
the same model that will be used in the iOS app (paraphrase-MiniLM-L6-v2).
"""

import json
import base64
import struct
import sys
from pathlib import Path
from sentence_transformers import SentenceTransformer
import numpy as np
from tqdm import tqdm

MODEL_NAME = "sentence-transformers/paraphrase-MiniLM-L6-v2"


def float_array_to_base64(arr: np.ndarray) -> str:
    """Convert numpy float32 array to base64 string."""
    # Ensure float32
    arr = arr.astype(np.float32)
    # Pack as bytes
    packed = struct.pack(f'{len(arr)}f', *arr)
    return base64.b64encode(packed).decode('utf-8')


def main():
    if len(sys.argv) != 3:
        print("Usage: python generate_embeddings.py <input.json> <output.json>")
        print("\nExample:")
        print("  python generate_embeddings.py paragraphs.json embeddings.json")
        sys.exit(1)

    input_file = Path(sys.argv[1])
    output_file = Path(sys.argv[2])

    if not input_file.exists():
        print(f"Error: Input file not found: {input_file}")
        sys.exit(1)

    # Load paragraphs
    print(f"Loading paragraphs from {input_file}...")
    with open(input_file, 'r', encoding='utf-8') as f:
        paragraphs = json.load(f)

    print(f"Loaded {len(paragraphs)} paragraphs")

    # Load model
    print(f"Loading model: {MODEL_NAME}")
    model = SentenceTransformer(MODEL_NAME)
    print(f"Model loaded. Embedding dimension: {model.get_sentence_embedding_dimension()}")

    # Generate embeddings
    print("Generating embeddings...")
    output_data = []

    # Process in batches for efficiency
    batch_size = 32
    texts = [p['text'] for p in paragraphs]

    for i in tqdm(range(0, len(texts), batch_size), desc="Embedding"):
        batch_texts = texts[i:i + batch_size]
        batch_embeddings = model.encode(batch_texts, normalize_embeddings=True)

        for j, embedding in enumerate(batch_embeddings):
            para_idx = i + j
            para = paragraphs[para_idx]

            output_data.append({
                'document_id': para['document_id'],
                'text': para['text'],
                'source_file': para['source_file'],
                'paragraph_id': para['paragraph_id'],
                'author': para['author'],
                'embedding': float_array_to_base64(embedding)
            })

    # Save output
    print(f"Saving embeddings to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False)

    print(f"Done! Generated {len(output_data)} embeddings ({model.get_sentence_embedding_dimension()} dimensions each)")

    # Print file size
    size_mb = output_file.stat().st_size / (1024 * 1024)
    print(f"Output file size: {size_mb:.2f} MB")


if __name__ == "__main__":
    main()
