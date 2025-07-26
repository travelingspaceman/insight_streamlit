#!/usr/bin/env python3
"""
Streamlit web application for semantic search over Bahá'í Writings.
"""

# import os
import streamlit as st
from pinecone import Pinecone
from openai import OpenAI
# from dotenv import load_dotenv
from typing import List, Dict, Any, Optional

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

    def process_journal_entry(self, journal_entry: str) -> str:
        """Process journal entry through GPT-4o-mini and return response for search."""
        prompt = "Here is a journal entry. Provide a compassionate and uplifting response to the user based on the Teachings of the Baha'i Faith. In your response, restate what the user is saying to you."
        
        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": journal_entry}
                ],
                max_tokens=500,
                temperature=0.7
            )
            return response.choices[0].message.content.strip() if response.choices[0].message.content else ""
        except Exception as e:
            st.error(f"Error processing journal entry: {e}")
            return ""

    def search(self, query: str, n_results: int = 10, author_filter: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """Perform semantic search and return results."""
        if not query.strip():
            return []
        
        # Generate query embedding
        query_embedding = self.generate_query_embedding(query)
        if not query_embedding:
            return []
        
        try:
            # Prepare filter for Pinecone query
            pinecone_filter = None
            if author_filter:
                pinecone_filter = {"author": {"$in": author_filter}}
            
            # Search in Pinecone
            results = self.index.query(
                vector=query_embedding,
                top_k=n_results,
                include_metadata=True,
                filter=pinecone_filter
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

    def get_bahai_library_url(self, source_file: str) -> str:
        """Convert source filename to Bahá'í library URL."""
        base_url = "https://www.bahai.org/library/authoritative-texts"
        
        # Remove .docx extension and convert to lowercase
        filename = source_file.replace('.docx', '').lower()
        
        # Mapping of filenames to library URLs
        url_mappings = {
            # Bahá'u'lláh
            'kitab-i-iqan': f"{base_url}/bahaullah/kitab-i-iqan/",
            'hidden-words': f"{base_url}/bahaullah/hidden-words/",
            'gleanings-writings-bahaullah': f"{base_url}/bahaullah/gleanings-writings-bahaullah/",
            'kitab-i-aqdas-2': f"{base_url}/bahaullah/kitab-i-aqdas/",
            'epistle-son-wolf': f"{base_url}/bahaullah/epistle-son-wolf/",
            'gems-divine-mysteries': f"{base_url}/bahaullah/gems-divine-mysteries/",
            'summons-lord-hosts': f"{base_url}/bahaullah/summons-lord-hosts/",
            'tablets-bahaullah': f"{base_url}/bahaullah/tablets-bahaullah/",
            'tabernacle-unity': f"{base_url}/bahaullah/tabernacle-unity/",
            
            # 'Abdu'l-Bahá
            'some-answered-questions': f"{base_url}/abdul-baha/some-answered-questions/",
            'paris-talks': f"{base_url}/abdul-baha/paris-talks/",
            'promulgation-universal-peace': f"{base_url}/abdul-baha/promulgation-universal-peace/",
            'memorials-faithful': f"{base_url}/abdul-baha/memorials-faithful/",
            'selections-writings-abdul-baha': f"{base_url}/abdul-baha/selections-writings-abdul-baha/",
            'secret-divine-civilization': f"{base_url}/abdul-baha/secret-divine-civilization/",
            'travelers-narrative': f"{base_url}/abdul-baha/travelers-narrative/",
            'will-testament-abdul-baha': f"{base_url}/abdul-baha/will-testament-abdul-baha/",
            'tablets-divine-plan': f"{base_url}/abdul-baha/tablets-divine-plan/",
            'tablet-auguste-forel': f"{base_url}/abdul-baha/tablet-auguste-forel/",
            
            # The Báb
            'selections-writings-bab': f"{base_url}/the-bab/selections-writings-bab/",
            
            # Shoghi Effendi
            'advent-divine-justice': f"{base_url}/shoghi-effendi/advent-divine-justice/",
            'god-passes-by': f"{base_url}/shoghi-effendi/god-passes-by/",
            'promised-day-come': f"{base_url}/shoghi-effendi/promised-day-come/",
            'world-order-bahaullah': f"{base_url}/shoghi-effendi/world-order-bahaullah/",
            
            # Compilations and other works
            'prayers-meditations': f"{base_url}/bahaullah/prayers-meditations/",
            'days-remembrance': f"{base_url}/compilations/days-remembrance/",
            'light-of-the-world': f"{base_url}/compilations/light-of-the-world/",
            'turning-point': f"{base_url}/compilations/turning-point/",
        }
        
        # Return specific URL if mapping exists, otherwise return main library page
        return url_mappings.get(filename, "https://www.bahai.org/library/")

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
    if "error" in stats:
        st.sidebar.error(f"Index error: {stats['error']}")
    
    # Search options in sidebar
    st.sidebar.markdown("### Search Options")
    
    # Author filter
    author_options = [
        "All Authors",
        "Bahá'u'lláh", 
        "'Abdu'l-Bahá", 
        "The Báb", 
        "Shoghi Effendi", 
        "Universal House of Justice", 
        "Compilations"
    ]
    selected_authors = st.sidebar.multiselect(
        "Filter by Author:",
        author_options,
        default=["All Authors"]
    )
    
    n_results = st.sidebar.slider("Number of results:", 1, 20, 10)
    
    # Handle "All Authors" selection
    if "All Authors" in selected_authors:
        author_filter = None
    else:
        author_filter = selected_authors if selected_authors else None
    
    # Search mode selection using buttons with proper state handling
    st.markdown("### Search Mode")
    
    # Initialize with default if not set
    if 'search_mode' not in st.session_state:
        st.session_state.search_mode = 'quote'
    
    col1, col2 = st.columns(2)
    with col1:
        if st.button(
            "🔍 Find a Quote", 
            use_container_width=True,
            type="primary" if st.session_state.search_mode == 'quote' else "secondary",
            key="quote_button"
        ):
            st.session_state.search_mode = 'quote'
            st.rerun()
    
    with col2:
        if st.button(
            "📝 Journal Entry", 
            use_container_width=True,
            type="primary" if st.session_state.search_mode == 'journal' else "secondary",
            key="journal_button"
        ):
            st.session_state.search_mode = 'journal'
            st.rerun()
    
    search_mode = st.session_state.search_mode
    
    # Display current mode
    if search_mode == 'quote':
        st.info("🔍 **Find a Quote Mode**: Search directly for relevant passages")
        placeholder_text = "e.g., spiritual development, unity of mankind, prayer..."
    else:
        st.info("📝 **Journal Entry Mode**: Share your thoughts and get guidance from the Writings")
        placeholder_text = "e.g., I'm struggling with patience today, or I feel grateful for..."
    
    # Search interface
    st.markdown("### Your Input")
    query = st.text_area(
        "Enter your query:",
        placeholder=placeholder_text,
        height=100
    )
    
    # Search button
    search_clicked = st.button("🔍 Search", type="primary", use_container_width=True)

    # Perform search
    if query or search_clicked:
        if search_mode == 'journal':
            with st.spinner("Processing your journal entry..."):
                processed_query = search_engine.process_journal_entry(query)
            
            if processed_query:
                # st.markdown("### AI Response to Your Entry")
                # st.markdown(f"*{processed_query}*")
                # st.markdown("### Related Passages")
                
                with st.spinner("Finding related passages..."):
                    results = search_engine.search(processed_query, n_results, author_filter)
            else:
                results = []
        else:
            with st.spinner("Searching..."):
                results = search_engine.search(query, n_results, author_filter)
        
        if results:
            st.markdown(f"### Search Results ({len(results)} found)")
            
            for i, result in enumerate(results, 1):
                with st.expander(f"Result {i} - {result['source_file']} (Para {result['paragraph_id']})"):
                    st.markdown(result['text'])
                    
                    # Show metadata and library link
                    col1, col2, col3 = st.columns([2, 2, 1])
                    with col1:
                        st.caption(f"📄 Source: {result['source_file']}")
                    with col2:
                        st.caption(f"📍 Paragraph: {int(result['paragraph_id'])}")
                    with col3:
                        library_url = search_engine.get_bahai_library_url(result['source_file'])
                        st.link_button("📖 Library", library_url, use_container_width=True)
                    
        else:
            st.warning("No results found. Try a different search query.")
    

if __name__ == "__main__":
    main()