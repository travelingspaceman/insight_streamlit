#!/usr/bin/env python3
"""
Document ingestion script for Bahá'í Writings semantic search.
Processes .docx files, chunks by paragraphs, and stores embeddings in ChromaDB.
"""

import os
import logging
from pathlib import Path
from typing import List, Dict, Any
import chromadb
from chromadb.config import Settings
from docx import Document
from openai import OpenAI
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BahaiWritingsIngestor:
    def __init__(self, openai_api_key: str, chroma_db_path: str = "./chroma_db"):
        """Initialize the ingestion pipeline."""
        self.client = OpenAI(api_key=openai_api_key)
        self.chroma_client = chromadb.PersistentClient(path=chroma_db_path)
        self.collection_name = "bahai_writings"
        
        # Create or get collection
        try:
            self.collection = self.chroma_client.get_collection(self.collection_name)
            logger.info(f"Using existing collection: {self.collection_name}")
        except:
            self.collection = self.chroma_client.create_collection(
                name=self.collection_name,
                metadata={"description": "Bahá'í Writings semantic search collection"}
            )
            logger.info(f"Created new collection: {self.collection_name}")

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
            response = self.client.embeddings.create(
                model="text-embedding-3-large",
                input=text,
                encoding_format="float"
            )
            return response.data[0].embedding
        except Exception as e:
            logger.error(f"Error generating embedding: {e}")
            raise

    def ingest_paragraphs(self, paragraphs: List[Dict[str, Any]]):
        """Generate embeddings and store paragraphs in ChromaDB."""
        logger.info(f"Generating embeddings for {len(paragraphs)} paragraphs...")
        
        documents = []
        embeddings = []
        metadatas = []
        ids = []
        
        for paragraph in paragraphs:
            try:
                # Generate embedding
                embedding = self.generate_embedding(paragraph["text"])
                
                documents.append(paragraph["text"])
                embeddings.append(embedding)
                metadatas.append({
                    "source_file": paragraph["source_file"],
                    "paragraph_id": paragraph["paragraph_id"]
                })
                ids.append(paragraph["document_id"])
                
                logger.info(f"Processed paragraph {paragraph['paragraph_id']}")
                
            except Exception as e:
                logger.error(f"Error processing paragraph {paragraph['paragraph_id']}: {e}")
                continue
        
        # Add to ChromaDB collection
        if documents:
            self.collection.add(
                documents=documents,
                embeddings=embeddings,
                metadatas=metadatas,
                ids=ids
            )
            logger.info(f"Successfully ingested {len(documents)} paragraphs into ChromaDB")

    def ingest_document(self, file_path: str):
        """Complete ingestion pipeline for a single document."""
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"Document not found: {file_path}")
        
        # Extract paragraphs
        paragraphs = self.extract_paragraphs_from_docx(file_path)
        
        # Ingest into ChromaDB
        self.ingest_paragraphs(paragraphs)
        
        logger.info(f"Completed ingestion of {file_path}")

    def get_collection_stats(self):
        """Get statistics about the collection."""
        count = self.collection.count()
        logger.info(f"Collection '{self.collection_name}' contains {count} documents")
        return count

def main():
    """Main ingestion function."""
    # Check for required environment variables
    openai_api_key = os.getenv("OPENAI_API_KEY")
    if not openai_api_key:
        raise ValueError("OPENAI_API_KEY environment variable is required")
    
    chroma_db_path = os.getenv("CHROMA_DB_PATH", "./chroma_db")
    
    # Initialize ingestor
    ingestor = BahaiWritingsIngestor(openai_api_key, chroma_db_path)
    
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
    ingestor.get_collection_stats()

if __name__ == "__main__":
    main()