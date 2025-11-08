#!/usr/bin/env python3
"""
Gradio web application for semantic search over Bahá'í Writings.
"""

import os
import gradio as gr
from pinecone import Pinecone
from openai import OpenAI
from dotenv import load_dotenv
from typing import List, Dict, Any, Optional

# Load environment variables
load_dotenv()

class BahaiSemanticSearch:
    def __init__(self, openai_api_key: str, pinecone_api_key: str):
        """Initialize the semantic search engine."""
        self.openai_client = OpenAI(api_key=openai_api_key)
        self.pc = Pinecone(api_key=pinecone_api_key)
        self.index_name = "bahai-writings"
        
        try:
            self.index = self.pc.Index(self.index_name)
        except Exception as e:
            raise RuntimeError(f"Failed to connect to Pinecone index: {e}. Please run the ingestion script first: `python ingest.py`")

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
            raise RuntimeError(f"Error generating query embedding: {e}")

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
            raise RuntimeError(f"Error processing journal entry: {e}")

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
            raise RuntimeError(f"Search error: {e}")

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

def format_results_html(results: List[Dict[str, Any]], search_engine: BahaiSemanticSearch) -> str:
    """Format search results as HTML for Gradio display."""
    if not results:
        return "<div style='padding: 20px; text-align: center; color: #856404; background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px;'>⚠️ No results found. Try a different search query.</div>"

    html = f"<div style='margin-top: 20px;'><h3>Search Results ({len(results)} found)</h3>"

    for i, result in enumerate(results, 1):
        library_url = search_engine.get_bahai_library_url(result['source_file'])

        html += f"""
        <details style='margin-bottom: 15px; border: 1px solid #ddd; border-radius: 5px; padding: 10px; background-color: #f9f9f9;'>
            <summary style='cursor: pointer; font-weight: bold; padding: 5px;'>
                Result {i} - {result['source_file']} (Para {int(result['paragraph_id'])})
            </summary>
            <div style='margin-top: 10px; padding: 10px; background-color: white; border-radius: 3px;'>
                <p style='line-height: 1.6;'>{result['text']}</p>
                <div style='margin-top: 10px; padding-top: 10px; border-top: 1px solid #eee; display: flex; justify-content: space-between; align-items: center;'>
                    <span style='color: #666; font-size: 0.9em;'>📄 Source: {result['source_file']}</span>
                    <span style='color: #666; font-size: 0.9em;'>📍 Paragraph: {int(result['paragraph_id'])}</span>
                    <a href='{library_url}' target='_blank' style='background-color: #4c8a64; color: white; padding: 5px 15px; border-radius: 3px; text-decoration: none; font-size: 0.9em;'>📖 Library</a>
                </div>
            </div>
        </details>
        """

    html += "</div>"
    return html

def perform_search(
    query: str,
    search_mode: str,
    selected_authors: List[str],
    n_results: float,
    search_engine: BahaiSemanticSearch
) -> str:
    """Perform search and return formatted HTML results."""
    if not query or not query.strip():
        return "<div style='padding: 20px; text-align: center; color: #856404;'>Please enter a query to search.</div>"

    try:
        # Handle author filter
        if not selected_authors or "All Authors" in selected_authors:
            author_filter = None
        else:
            author_filter = selected_authors

        # Convert n_results to int
        n_results_int = int(n_results)

        # Process based on search mode
        if search_mode == "📝 Journal Entry":
            processed_query = search_engine.process_journal_entry(query)
            if processed_query:
                results = search_engine.search(processed_query, n_results_int, author_filter)
            else:
                return "<div style='padding: 20px; text-align: center; color: #721c24; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 5px;'>Failed to process journal entry. Please try again.</div>"
        else:  # Find a Quote mode
            results = search_engine.search(query, n_results_int, author_filter)

        return format_results_html(results, search_engine)

    except Exception as e:
        return f"<div style='padding: 20px; text-align: center; color: #721c24; background-color: #f8d7da; border: 1px solid #f5c6cb; border-radius: 5px;'>❌ Error: {str(e)}</div>"

def create_gradio_interface() -> gr.Blocks:
    """Create and return the Gradio interface."""
    # Check for API keys
    openai_api_key = os.environ.get("OPENAI_API_KEY")
    pinecone_api_key = os.environ.get("PINECONE_API_KEY")

    if not openai_api_key:
        raise ValueError("⚠️ OPENAI_API_KEY environment variable is required")
    if not pinecone_api_key:
        raise ValueError("⚠️ PINECONE_API_KEY environment variable is required")

    # Initialize search engine
    try:
        search_engine = BahaiSemanticSearch(openai_api_key, pinecone_api_key)
    except Exception as e:
        raise RuntimeError(f"Failed to initialize search engine: {e}")

    # Custom CSS for theme matching Streamlit colors
    custom_css = """
    .gradio-container {
        background-color: #ece6c2 !important;
    }
    .block {
        background-color: #efe8e2 !important;
    }
    button.primary {
        background-color: #4c8a64 !important;
    }
    """

    # Author options
    author_options = [
        "All Authors",
        "Bahá'u'lláh",
        "'Abdu'l-Bahá",
        "The Báb",
        "Shoghi Effendi",
        "Universal House of Justice",
        "Compilations"
    ]

    with gr.Blocks(css=custom_css, title="Insight") as app:
        gr.Markdown("# 📚 Insight")
        gr.Markdown("Search through the Bahá'í Writings using semantic similarity")

        with gr.Row():
            with gr.Column(scale=3):
                # Search mode selection
                gr.Markdown("### Search Mode")
                search_mode = gr.Radio(
                    choices=["🔍 Find a Quote", "📝 Journal Entry"],
                    value="🔍 Find a Quote",
                    label="",
                    container=False
                )

                # Mode description
                mode_info = gr.Markdown(
                    "🔍 **Find a Quote Mode**: Search directly for relevant passages"
                )

                # Update mode description when mode changes
                def update_mode_info(mode):
                    if mode == "🔍 Find a Quote":
                        return "🔍 **Find a Quote Mode**: Search directly for relevant passages"
                    else:
                        return "📝 **Journal Entry Mode**: Share your thoughts and get guidance from the Writings"

                search_mode.change(
                    fn=update_mode_info,
                    inputs=[search_mode],
                    outputs=[mode_info]
                )

                # Query input
                gr.Markdown("### Your Input")
                query = gr.Textbox(
                    label="Enter your query:",
                    placeholder="e.g., spiritual development, unity of mankind, prayer...",
                    lines=4
                )

                # Update placeholder based on mode
                def update_placeholder(mode):
                    if mode == "🔍 Find a Quote":
                        return gr.update(placeholder="e.g., spiritual development, unity of mankind, prayer...")
                    else:
                        return gr.update(placeholder="e.g., I'm struggling with patience today, or I feel grateful for...")

                search_mode.change(
                    fn=update_placeholder,
                    inputs=[search_mode],
                    outputs=[query]
                )

                # Search button
                search_button = gr.Button("🔍 Search", variant="primary", size="lg")

                # Results display
                results_display = gr.HTML(label="Results")

            with gr.Column(scale=1):
                gr.Markdown("### Search Options")

                # Author filter
                author_filter = gr.CheckboxGroup(
                    choices=author_options,
                    value=["All Authors"],
                    label="Filter by Author:"
                )

                # Number of results
                n_results = gr.Slider(
                    minimum=1,
                    maximum=20,
                    value=10,
                    step=1,
                    label="Number of results:"
                )

        # Search functionality
        search_button.click(
            fn=lambda q, m, a, n: perform_search(q, m, a, n, search_engine),
            inputs=[query, search_mode, author_filter, n_results],
            outputs=[results_display]
        )

        # Also trigger search on Enter key in query box
        query.submit(
            fn=lambda q, m, a, n: perform_search(q, m, a, n, search_engine),
            inputs=[query, search_mode, author_filter, n_results],
            outputs=[results_display]
        )

    return app

def main():
    """Main application entry point."""
    app = create_gradio_interface()
    app.launch()
    

if __name__ == "__main__":
    main()