#!/usr/bin/env python3
"""
Document ingestion script for Bahá'í Writings semantic search.
Processes .docx files, chunks by paragraphs, and stores embeddings in Pinecone.
"""

import os
import logging
from pathlib import Path
from typing import List, Dict, Any
from pinecone import Pinecone, ServerlessSpec
from docx import Document
from openai import OpenAI
from dotenv import load_dotenv
import streamlit as st 

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BahaiWritingsIngestor:
    def __init__(self, openai_api_key: str, pinecone_api_key: str):
        """Initialize the ingestion pipeline."""
        self.openai_client = OpenAI(api_key=openai_api_key)
        self.pc = Pinecone(api_key=pinecone_api_key)
        self.index_name = "bahai-writings"
        self.dimension = 3072  # Dimension for text-embedding-3-large
        
        # Create or get index
        try:
            # Check if index exists
            if self.index_name not in [index.name for index in self.pc.list_indexes()]:
                logger.info(f"Creating new index: {self.index_name}")
                self.pc.create_index(
                    name=self.index_name,
                    dimension=self.dimension,
                    metric="cosine",
                    spec=ServerlessSpec(
                        cloud="aws",
                        region="us-east-1"
                    )
                )
            else:
                logger.info(f"Using existing index: {self.index_name}")
            
            self.index = self.pc.Index(self.index_name)
        except Exception as e:
            logger.error(f"Error initializing Pinecone index: {e}")
            raise

    def extract_paragraphs_from_docx(self, file_path: str) -> List[Dict[str, Any]]:
        """Extract paragraphs from a .docx file."""
        logger.info(f"Processing document: {file_path}")
        
        doc = Document(file_path)
        paragraphs = []
        
        for i, paragraph in enumerate(doc.paragraphs):
            text = paragraph.text.strip()
            if text and len(text) > 20:  # Filter out very short paragraphs
                paragraphs.append({
                    "text": text,
                    "paragraph_id": i,
                    "source_file": Path(file_path).name,
                    "document_id": f"{Path(file_path).stem}_para_{i}"
                })
        
        logger.info(f"Extracted {len(paragraphs)} paragraphs")
        return paragraphs

    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for text using OpenAI's text-embedding-3-large model."""
        try:
            response = self.openai_client.embeddings.create(
                model="text-embedding-3-large",
                input=text,
                encoding_format="float"
            )
            return response.data[0].embedding
        except Exception as e:
            logger.error(f"Error generating embedding: {e}")
            raise

    def ingest_paragraphs(self, paragraphs: List[Dict[str, Any]]):
        """Generate embeddings and store paragraphs in Pinecone."""
        logger.info(f"Generating embeddings for {len(paragraphs)} paragraphs...")
        
        vectors = []
        
        for paragraph in paragraphs:
            try:
                # Generate embedding
                embedding = self.generate_embedding(paragraph["text"])
                
                # Create vector for Pinecone
                vector = {
                    "id": paragraph["document_id"],
                    "values": embedding,
                    "metadata": {
                        "text": paragraph["text"],
                        "source_file": paragraph["source_file"],
                        "paragraph_id": paragraph["paragraph_id"]
                    }
                }
                vectors.append(vector)
                
                logger.info(f"Processed paragraph {paragraph['paragraph_id']}")
                
            except Exception as e:
                logger.error(f"Error processing paragraph {paragraph['paragraph_id']}: {e}")
                continue
        
        # Upsert to Pinecone index
        if vectors:
            # Pinecone has a limit on batch size, so we'll process in chunks
            batch_size = 100
            for i in range(0, len(vectors), batch_size):
                batch = vectors[i:i + batch_size]
                self.index.upsert(vectors=batch)
                logger.info(f"Upserted batch {i//batch_size + 1} of {(len(vectors) + batch_size - 1)//batch_size}")
            
            logger.info(f"Successfully ingested {len(vectors)} paragraphs into Pinecone")

    def ingest_document(self, file_path: str):
        """Complete ingestion pipeline for a single document."""
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"Document not found: {file_path}")
        
        # Extract paragraphs
        paragraphs = self.extract_paragraphs_from_docx(file_path)
        
        # Ingest into ChromaDB
        self.ingest_paragraphs(paragraphs)
        
        logger.info(f"Completed ingestion of {file_path}")

    def get_index_stats(self):
        """Get statistics about the index."""
        stats = self.index.describe_index_stats()
        count = stats['total_vector_count']
        logger.info(f"Index '{self.index_name}' contains {count} vectors")
        return count

def main():
    """Main ingestion function."""
    # Check for required environment variables
    openai_api_key = st.secrets["OPENAI_API_KEY"]
    pinecone_api_key = st.secrets["PINECONE_API_KEY"]
    
    if not openai_api_key:
        raise ValueError("OPENAI_API_KEY is required in streamlit secrets")
    if not pinecone_api_key:
        raise ValueError("PINECONE_API_KEY is required in streamlit secrets")
    
    # Initialize ingestor
    ingestor = BahaiWritingsIngestor(openai_api_key, pinecone_api_key)
    
    # Find and process .docx files in current directory
    docx_files = list(Path(".").glob("*.docx"))
    
    if not docx_files:
        logger.warning("No .docx files found in current directory")
        return
    
    for docx_file in docx_files:
        try:
            ingestor.ingest_document(str(docx_file))
        except Exception as e:
            logger.error(f"Failed to ingest {docx_file}: {e}")
    
    # Print final statistics
    ingestor.get_index_stats()

if __name__ == "__main__":
    main()