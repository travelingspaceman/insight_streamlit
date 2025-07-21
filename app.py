#!/usr/bin/env python3
"""
Streamlit web application for semantic search over Bahá'í Writings.
"""

# import os
import streamlit as st
from pinecone import Pinecone
from openai import OpenAI
# from dotenv import load_dotenv
from typing import List, Dict, Any

# Load environment variables
# load_dotenv()

class BahaiSemanticSearch:
    def __init__(self, openai_api_key: str, pinecone_api_key: str):
        """Initialize the semantic search engine."""
        self.openai_client = OpenAI(api_key=openai_api_key)
        self.pc = Pinecone(api_key=pinecone_api_key)
        self.index_name = "bahai-writings"
        
        try:
            self.index = self.pc.Index(self.index_name)
        except Exception as e:
            st.error(f"Failed to connect to Pinecone index: {e}")
            st.error("Please run the ingestion script first: `streamlit run ingest.py`")
            st.stop()

    def generate_query_embedding(self, query: str) -> List[float]:
        """Generate embedding for search query."""
        try:
            response = self.openai_client.embeddings.create(
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
            # Search in Pinecone
            results = self.index.query(
                vector=query_embedding,
                top_k=n_results,
                include_metadata=True
            )
            
            # Format results
            formatted_results = []
            for match in results['matches']:
                formatted_results.append({
                    'text': match['metadata']['text'],
                    'source_file': match['metadata']['source_file'],
                    'paragraph_id': match['metadata']['paragraph_id'],
                    'score': match['score']
                })
            
            return formatted_results
            
        except Exception as e:
            st.error(f"Search error: {e}")
            return []

    def get_index_stats(self) -> Dict[str, Any]:
        """Get index statistics."""
        try:
            stats = self.index.describe_index_stats()
            return {"total_vectors": stats['total_vector_count']}
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
    
    # Check for API keys
    openai_api_key = st.secrets["OPENAI_API_KEY"]
    pinecone_api_key = st.secrets["PINECONE_API_KEY"]
    
    if not openai_api_key:
        st.error("⚠️ OPENAI_API_KEY is required in streamlit secrets")
        st.stop()
    if not pinecone_api_key:
        st.error("⚠️ PINECONE_API_KEY is required in streamlit secrets")
        st.stop()
    
    # Initialize search engine
    @st.cache_resource
    def get_search_engine():
        return BahaiSemanticSearch(openai_api_key, pinecone_api_key)
    
    try:
        search_engine = get_search_engine()
    except Exception as e:
        st.error(f"Failed to initialize search engine: {e}")
        st.stop()
    
    # Display index statistics
    stats = search_engine.get_index_stats()
    if "error" not in stats:
        st.sidebar.info(f"📊 Total vectors: {stats['total_vectors']}")
    else:
        st.sidebar.error(f"Index error: {stats['error']}")
    
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
                    
                    if result['score'] is not None:
                        st.caption(f"🎯 Relevance: {result['score']:.3f}")
        else:
            st.warning("No results found. Try a different search query.")
    

if __name__ == "__main__":
    main()