# Insight iOS App

A native iOS app for semantic search over Bahá'í religious writings, converted from the original Streamlit web application.

## Features

- **Semantic Search**: Find relevant passages using natural language queries
- **Journal Entry Mode**: Personal reflection mode for finding guidance
- **Author Filtering**: Filter results by specific authors (Bahá'u'lláh, 'Abdu'l-Bahá, The Báb, etc.)
- **On-Device Processing**: Uses Apple's NLContextualEmbedding for privacy-preserving, offline-capable search
- **Document Import**: Import .txt and .docx files to expand the search corpus

## Technology Stack

- **Swift 6** with strict concurrency checking
- **SwiftUI** for the user interface
- **SwiftData** for metadata persistence
- **ObjectBox** for vector database with HNSW indexing
- **NLContextualEmbedding** for on-device text embeddings (iOS 18+)

## Requirements

- iOS 18.0+ / macOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## Project Structure

```
InsightApp/
├── Package.swift                    # Swift Package Manager manifest
├── Sources/InsightApp/
│   ├── Models/
│   │   ├── Author.swift            # Author enumeration with mappings
│   │   ├── Paragraph.swift         # SwiftData model for paragraphs
│   │   └── EmbeddingVector.swift   # ObjectBox entity for vectors
│   ├── Services/
│   │   ├── EmbeddingService.swift      # NLContextualEmbedding wrapper
│   │   ├── VectorStore.swift           # ObjectBox database manager
│   │   ├── SemanticSearchEngine.swift  # Main search engine
│   │   └── DocumentIngestionService.swift # Document import
│   ├── ViewModels/
│   │   └── SearchViewModel.swift   # Observable view model
│   ├── Views/
│   │   ├── ContentView.swift       # Main search view
│   │   ├── FilterView.swift        # Author/result filters
│   │   ├── SettingsView.swift      # Settings and import
│   │   └── MainTabView.swift       # Tab container
│   ├── Extensions/
│   │   └── BahaiLibraryURLMapper.swift # URL mappings
│   ├── Resources/
│   │   └── Assets.xcassets/        # App colors and assets
│   ├── InsightApp.swift            # App entry point
│   └── Exports.swift               # Public API exports
└── Tests/                          # Unit tests
```

## Building

1. Open the package in Xcode:
   ```bash
   cd InsightApp
   open Package.swift
   ```

2. Select your target device (iOS 18+ simulator or device)

3. Build and run (⌘R)

## Key Differences from Streamlit Version

| Feature | Streamlit | iOS |
|---------|-----------|-----|
| Embeddings | OpenAI text-embedding-3-large (cloud) | NLContextualEmbedding (on-device) |
| Vector DB | Pinecone (cloud) | ObjectBox (local) |
| AI Responses | GPT-4o-mini for journal mode | Direct semantic search |
| Data Storage | Cloud-based | On-device with SwiftData |

## Architecture

### Embedding Generation
The app uses Apple's `NLContextualEmbedding` framework introduced in iOS 18, which provides on-device contextual embeddings for English text. This ensures:
- Privacy: No text leaves the device
- Offline capability: Search works without internet
- Low latency: No network round-trips

### Vector Search
ObjectBox provides efficient HNSW (Hierarchical Navigable Small World) vector indexing for fast approximate nearest neighbor search, enabling quick semantic search even with large corpora.

### Data Flow
```
User Query → EmbeddingService → VectorStore.search() → ParagraphResult[]
                   ↓
         NLContextualEmbedding
                   ↓
         [Float] embedding vector
                   ↓
         ObjectBox HNSW query
                   ↓
         Ranked results by cosine similarity
```

## Document Ingestion

Documents can be imported via the Settings tab:

1. Tap "Import Document"
2. Select a .txt or .docx file
3. The app extracts paragraphs, generates embeddings, and indexes them
4. Progress is shown during ingestion

Paragraphs shorter than 100 words are automatically combined for better semantic representation.

## License

This project is for educational and personal use with Bahá'í sacred writings.
