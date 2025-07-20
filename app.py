#!/usr/bin/env python3
"""
Streamlit web application for semantic search over Bahá'í Writings.
"""

import os
import streamlit as st
import chromadb
from openai import OpenAI
from dotenv import load_dotenv
from typing import List, Dict, Any, Tuple

# Load environment variables
load_dotenv()

class BahaiSemanticSearch:
    def __init__(self, openai_api_key: str, chroma_db_path: str = "./chroma_db"):
        """Initialize the semantic search engine."""
        self.client = OpenAI(api_key=openai_api_key)
        self.chroma_client = chromadb.PersistentClient(path=chroma_db_path)
        self.collection_name = "bahai_writings"
        
        try:
            self.collection = self.chroma_client.get_collection(self.collection_name)
        except Exception as e:
            st.error(f"Failed to connect to ChromaDB collection: {e}")
            st.error("Please run the ingestion script first: `python ingest.py`")
            st.stop()

    def generate_query_embedding(self, query: str) -> List[float]:
        """Generate embedding for search query."""
        try:
            response = self.client.embeddings.create(
                model="text-embedding-3-large",
                input=query,
                encoding_format="float"
            )
            return response.data[0].embedding
        except Exception as e:
            st.error(f"Error generating query embedding: {e}")
            return []

    def search(self, query: str, n_results: int = 10) -> List[Dict[str, Any]]:
        """Perform semantic search and return results."""
        if not query.strip():
            return []
        
        # Generate query embedding
        query_embedding = self.generate_query_embedding(query)
        if not query_embedding:
            return []
        
        try:
            # Search in ChromaDB
            results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=n_results
            )
            
            # Format results
            formatted_results = []
            for i in range(len(results['ids'][0])):
                formatted_results.append({
                    'text': results['documents'][0][i],
                    'source_file': results['metadatas'][0][i]['source_file'],
                    'paragraph_id': results['metadatas'][0][i]['paragraph_id'],
                    'distance': results['distances'][0][i] if 'distances' in results else None
                })
            
            return formatted_results
            
        except Exception as e:
            st.error(f"Search error: {e}")
            return []

    def get_collection_stats(self) -> Dict[str, Any]:
        """Get collection statistics."""
        try:
            count = self.collection.count()
            return {"total_documents": count}
        except Exception as e:
            return {"error": str(e)}

def main():
    """Main Streamlit application."""
    st.set_page_config(
        page_title="Bahá'í Writings Semantic Search",
        page_icon="📚",
        layout="wide"
    )
    
    st.title("📚 Bahá'í Writings Semantic Search")
    st.markdown("Search through the Bahá'í Writings using semantic similarity")
    
    # Check for API key
    openai_api_key = st.secrets["OPENAI_API_KEY"]
    if not openai_api_key:
        st.error("⚠️ OPENAI_API_KEY environment variable is required")
        st.markdown("Please set your OpenAI API key in a `.env` file:")
        st.code("OPENAI_API_KEY=your_api_key_here")
        st.stop()
    
    # Initialize search engine
    @st.cache_resource
    def get_search_engine():
        chroma_db_path = os.getenv("CHROMA_DB_PATH", "./chroma_db")
        return BahaiSemanticSearch(openai_api_key, chroma_db_path)
    
    try:
        search_engine = get_search_engine()
    except Exception as e:
        st.error(f"Failed to initialize search engine: {e}")
        st.stop()
    
    # Display collection statistics
    stats = search_engine.get_collection_stats()
    if "error" not in stats:
        st.sidebar.info(f"📊 Total documents: {stats['total_documents']}")
    else:
        st.sidebar.error(f"Database error: {stats['error']}")
    
    # Search interface
    st.markdown("### Search Query")
    query = st.text_input(
        "Enter your search query:",
        placeholder="e.g., spiritual development, unity of mankind, prayer..."
    )
    
    # Search options
    col1, col2 = st.columns([1, 3])
    with col1:
        n_results = st.slider("Number of results:", 1, 20, 10)
    
    # Perform search
    if query:
        with st.spinner("Searching..."):
            results = search_engine.search(query, n_results)
        
        if results:
            st.markdown(f"### Search Results ({len(results)} found)")
            
            for i, result in enumerate(results, 1):
                with st.expander(f"Result {i} - {result['source_file']} (Para {result['paragraph_id']})"):
                    st.markdown(result['text'])
                    
                    # Show metadata
                    col1, col2 = st.columns(2)
                    with col1:
                        st.caption(f"📄 Source: {result['source_file']}")
                    with col2:
                        st.caption(f"📍 Paragraph: {result['paragraph_id']}")
                    
                    if result['distance'] is not None:
                        similarity_score = 1 - result['distance']
                        st.caption(f"🎯 Relevance: {similarity_score:.3f}")
        else:
            st.warning("No results found. Try a different search query.")
    
    # Instructions
    st.markdown("---")
    st.markdown("### How to use")
    st.markdown("""
    1. **First time setup**: Run `python ingest.py` to process and index the documents
    2. **Search**: Enter keywords, phrases, or concepts in the search box
    3. **Semantic matching**: The search finds conceptually similar passages, not just exact keyword matches
    4. **Results**: Click on results to expand and read the full text
    """)
    
    # Footer
    st.markdown("---")
    st.markdown("*Powered by OpenAI embeddings and ChromaDB*")

if __name__ == "__main__":
    main()