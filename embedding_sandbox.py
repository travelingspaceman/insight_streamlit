#!/usr/bin/env python3
"""
Embedding Sandbox - Test different embedding models and compare similarity scores.
Usage: python embedding_sandbox.py
"""

from sentence_transformers import SentenceTransformer
import numpy as np

def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Calculate cosine similarity between two vectors."""
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

def main():
    # Model options to try:
    # - "all-MiniLM-L6-v2" (22MB, 384 dim, fast, good quality)
    # - "all-mpnet-base-v2" (420MB, 768 dim, best quality)
    # - "paraphrase-MiniLM-L6-v2" (22MB, 384 dim, good for paraphrase)
    # - "multi-qa-MiniLM-L6-cos-v1" (22MB, 384 dim, optimized for Q&A)

    model_name = "all-MiniLM-L6-v2"
    print(f"Loading model: {model_name}")
    model = SentenceTransformer(model_name)
    print(f"Model loaded. Embedding dimension: {model.get_sentence_embedding_dimension()}")
    print("-" * 60)

    while True:
        print("\nEnter two texts to compare (or 'q' to quit, 'm' to change model):")

        text1 = input("Text 1: ").strip()
        if text1.lower() == 'q':
            break
        if text1.lower() == 'm':
            model_name = input("Model name: ").strip()
            print(f"Loading model: {model_name}")
            model = SentenceTransformer(model_name)
            print(f"Model loaded. Embedding dimension: {model.get_sentence_embedding_dimension()}")
            continue

        text2 = input("Text 2: ").strip()
        if text2.lower() == 'q':
            break

        # Generate embeddings
        emb1 = model.encode(text1)
        emb2 = model.encode(text2)

        # Calculate similarity
        similarity = cosine_similarity(emb1, emb2)

        print(f"\nSimilarity: {similarity:.4f}")
        print(f"Dimension: {len(emb1)}")

if __name__ == "__main__":
    main()
