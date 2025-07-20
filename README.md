# Bahá'í Writings Semantic Search

A Streamlit application that performs semantic search over Bahá'í Writings using OpenAI's text-embedding-3-large model and Pinecone for vector storage.

## Features

- **Semantic Search**: Find passages based on meaning and context, not just keywords
- **Document Processing**: Automatically processes .docx files and chunks by paragraphs  
- **Web Interface**: Clean, intuitive Streamlit interface
- **Relevance Ranking**: Results ranked by semantic similarity
- **Cloud Vector Storage**: Uses Pinecone for scalable, managed vector search

## Setup

### 1. Install Dependencies

```bash
# Install uv if you haven't already
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync
```

### 2. Configure API Keys

Add your API keys to `.streamlit/secrets.toml`:

```toml
OPENAI_API_KEY = "your_openai_api_key_here"
PINECONE_API_KEY = "your_pinecone_api_key_here"
```

### 3. Ingest Documents

Process the Bahá'í writings documents:

```bash
uv run streamlit run ingest.py
```

This will:
- Find all .docx files in the current directory
- Extract and chunk text by paragraphs
- Generate embeddings using OpenAI
- Store everything in Pinecone

### 4. Run the Application

```bash
uv run streamlit run app.py
```

The application will be available at `http://localhost:8501`

## Usage

1. Open the web interface
2. Enter your search query (concepts, themes, or specific topics)
3. Browse the semantically similar results
4. Click on results to read the full text

## Project Structure

```
├── pyproject.toml          # uv configuration and dependencies
├── .streamlit/
│   └── secrets.toml       # API keys configuration
├── ingest.py              # Document processing and ingestion script
├── app.py                 # Streamlit web application
└── gleanings-writings-bahaullah.docx  # Source document
```

## Dependencies

- **streamlit**: Web interface framework
- **openai**: API client for embeddings
- **pinecone**: Cloud vector database for similarity search
- **python-docx**: Document processing
- **python-dotenv**: Environment variable management

## How It Works

1. **Ingestion**: Documents are processed paragraph by paragraph
2. **Embedding**: Each paragraph is converted to a vector using OpenAI's embedding model
3. **Storage**: Vectors and metadata are stored in Pinecone
4. **Search**: User queries are embedded and matched against stored vectors
5. **Ranking**: Results are ranked by cosine similarity

## Notes

- The application uses OpenAI's `text-embedding-3-large` model for high-quality embeddings
- Pinecone provides scalable, managed vector similarity search
- Semantic search finds conceptually related content beyond keyword matching
- Pinecone automatically handles index creation and management