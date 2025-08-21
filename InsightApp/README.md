# Insight iOS App

A native iOS application for semantic search through the Bahá'í Writings, ported from the original Streamlit web application.

## Features

- **Native iOS Interface**: Built with SwiftUI for optimal performance and user experience
- **Semantic Search**: Find passages based on meaning and context using OpenAI embeddings
- **Two Search Modes**:
  - 🔍 **Find a Quote**: Direct search for relevant passages
  - 📝 **Journal Entry**: Share thoughts and get guidance from the Writings
- **Author Filtering**: Filter results by specific authors (Bahá'u'lláh, 'Abdu'l-Bahá, etc.)
- **Detailed Results**: Expandable result details with source information
- **Bahá'í Library Integration**: Direct links to official online library
- **Share Functionality**: Share passages with proper attribution

## Requirements

- iOS 17.0+
- Xcode 15.0+
- OpenAI API key
- Pinecone API key with indexed Bahá'í Writings

## Setup

### 1. API Keys

You need to configure your API keys in the app. Update the following files:

**SearchView.swift** (lines 8-9):
```swift
@StateObject private var openAIService = OpenAIService(apiKey: "your_openai_api_key_here")
@StateObject private var pineconeService = PineconeService(apiKey: "your_pinecone_api_key_here")
```

### 2. Pinecone Configuration

If your Pinecone environment is different from the default `us-east-1-aws`, update the PineconeService initialization:

```swift
@StateObject private var pineconeService = PineconeService(
    apiKey: "your_pinecone_api_key_here", 
    environment: "your-environment"
)
```

### 3. Data Preparation

Make sure you have run the ingestion script from the original Streamlit app to populate your Pinecone index with the Bahá'í Writings data:

```bash
uv run streamlit run ingest.py
```

## Architecture

The app follows a clean SwiftUI architecture:

```
InsightApp/
├── Models/
│   └── SearchResult.swift          # Data models
├── Services/
│   ├── OpenAIService.swift         # OpenAI API integration
│   └── PineconeService.swift       # Pinecone vector search
├── Views/
│   ├── SearchView.swift            # Main search interface
│   └── ResultDetailView.swift      # Result details and sharing
├── ContentView.swift               # Root view
└── InsightAppApp.swift            # App entry point
```

## Key Components

### SearchView
- Main search interface with mode toggle
- Real-time search with loading states
- Author filtering and result count customization
- Error handling with user-friendly messages

### ResultDetailView
- Full text display with copy support
- Source metadata (author, file, paragraph)
- Relevance scoring
- Share functionality
- Bahá'í Library deep linking

### API Services
- **OpenAIService**: Handles embedding generation and journal entry processing
- **PineconeService**: Manages vector search and index statistics

## Usage

1. **Choose Search Mode**: Toggle between "Find a Quote" and "Journal Entry"
2. **Enter Query**: Type your search text or journal entry
3. **Filter (Optional)**: Use the Filters button to select specific authors
4. **Search**: Tap the search button to find relevant passages
5. **Explore Results**: Tap any result for full details, sharing, and library links

## Building and Running

1. Open `InsightApp.xcodeproj` in Xcode
2. Update the API keys in `SearchView.swift`
3. Build and run on iOS Simulator or device

## Future Enhancements

- Offline caching with Core Data
- Search history and favorites
- Dark mode support
- iPad-optimized layout
- Push notifications for daily passages
- Voice search integration

## Dependencies

The app uses only native iOS frameworks:
- SwiftUI for the user interface
- Foundation for networking and data handling
- SafariServices for web view integration

No external dependencies are required, making the app lightweight and maintainable.