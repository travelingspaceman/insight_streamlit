# Bahá'í Writings Semantic Search

A Streamlit application that performs semantic search over Bahá'í Writings using OpenAI's text-embedding-3-large model and ChromaDB for vector storage.

## Features

- **Semantic Search**: Find passages based on meaning and context, not just keywords
- **Document Processing**: Automatically processes .docx files and chunks by paragraphs
- **Web Interface**: Clean, intuitive Streamlit interface
- **Relevance Ranking**: Results ranked by semantic similarity

## Setup

### 1. Install Dependencies

```bash
# Install uv if you haven't already
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync
```

### 2. Configure Environment

```bash
# Copy the environment template
cp .env.template .env

# Edit .env and add your OpenAI API key
OPENAI_API_KEY=your_openai_api_key_here
```

### 3. Ingest Documents

Process the Bahá'í writings documents:

```bash
uv run python ingest.py
```

This will:
- Find all .docx files in the current directory
- Extract and chunk text by paragraphs
- Generate embeddings using OpenAI
- Store everything in ChromaDB

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
├── .env.template           # Environment variables template
├── ingest.py              # Document processing and ingestion script
├── app.py                 # Streamlit web application
├── gleanings-writings-bahaullah.docx  # Source document
└── chroma_db/             # ChromaDB storage (created after ingestion)
```

## Dependencies

- **streamlit**: Web interface framework
- **openai**: API client for embeddings
- **chromadb**: Vector database for similarity search
- **python-docx**: Document processing
- **python-dotenv**: Environment variable management

## How It Works

1. **Ingestion**: Documents are processed paragraph by paragraph
2. **Embedding**: Each paragraph is converted to a vector using OpenAI's embedding model
3. **Storage**: Vectors and metadata are stored in ChromaDB
4. **Search**: User queries are embedded and matched against stored vectors
5. **Ranking**: Results are ranked by cosine similarity

## Notes

- The application uses OpenAI's `text-embedding-3-large` model for high-quality embeddings
- ChromaDB provides efficient vector similarity search
- Semantic search finds conceptually related content beyond keyword matching