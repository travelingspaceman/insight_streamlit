import Foundation
import SwiftData

/// The main search engine that combines embedding generation with vector search
@MainActor
public final class SemanticSearchEngine: ObservableObject {
    private let embeddingService: EmbeddingService
    private let vectorStore: VectorStore

    @Published public private(set) var isReady = false
    @Published public private(set) var isSearching = false
    @Published public private(set) var error: Error?

    public init(vectorStore: VectorStore) {
        self.embeddingService = EmbeddingService()
        self.vectorStore = vectorStore
    }

    /// Prepare the search engine for use
    /// This loads the embedding model and ensures the vector store is ready
    public func prepare() async {
        do {
            try await embeddingService.prepare()
            isReady = await embeddingService.ready
        } catch {
            self.error = error
            isReady = false
        }
    }

    /// Perform a semantic search for the given query
    /// - Parameters:
    ///   - query: The search query text
    ///   - limit: Maximum number of results to return (default: 10)
    ///   - authorFilter: Optional set of authors to filter by
    /// - Returns: Array of search results with similarity scores
    public func search(
        query: String,
        limit: Int = 10,
        authorFilter: Set<Author>? = nil
    ) async throws -> [ParagraphResult] {
        guard isReady else {
            throw EmbeddingError.modelNotReady
        }

        isSearching = true
        defer { isSearching = false }

        // Generate embedding for the query
        let queryEmbedding = try await embeddingService.generateQueryEmbedding(for: query)

        // Search the vector store
        let results = try vectorStore.search(
            queryVector: queryEmbedding,
            limit: limit,
            authorFilter: authorFilter
        )

        // Convert to ParagraphResult
        return results.map { vector, score in
            ParagraphResult(
                id: vector.documentId,
                text: vector.text,
                sourceFile: vector.sourceFile,
                paragraphId: vector.paragraphId,
                author: vector.author,
                score: score
            )
        }
    }

    /// Get statistics about the search index
    public func stats() throws -> VectorStoreStats {
        try vectorStore.stats()
    }

    /// Clear all indexed data
    public func clearIndex() throws {
        try vectorStore.deleteAll()
    }
}

// MARK: - Document Ingestion

extension SemanticSearchEngine {
    /// Ingest a document into the search index
    /// - Parameters:
    ///   - paragraphs: Array of paragraph texts to index
    ///   - sourceFile: The source filename
    ///   - author: The author category
    ///   - progressHandler: Optional callback for progress updates
    public func ingestDocument(
        paragraphs: [String],
        sourceFile: String,
        author: Author,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async throws {
        guard isReady else {
            throw EmbeddingError.modelNotReady
        }

        // Combine short paragraphs (minimum 100 words like the Python version)
        let combinedParagraphs = combineParagraphs(paragraphs, minimumWords: 100)

        for (index, paragraph) in combinedParagraphs.enumerated() {
            let documentId = "\(sourceFile)_para_\(paragraph.startIndex)"

            // Skip if already indexed
            if try vectorStore.exists(documentId: documentId) {
                progressHandler?(index + 1, combinedParagraphs.count)
                continue
            }

            // Generate embedding
            let embedding = try await embeddingService.generateEmbedding(for: paragraph.text)

            // Create vector entity
            let vector = EmbeddingVector(
                documentId: documentId,
                embedding: embedding,
                text: paragraph.text,
                sourceFile: sourceFile,
                paragraphId: paragraph.startIndex,
                author: author
            )

            // Insert into vector store
            _ = try vectorStore.insert(vector)

            progressHandler?(index + 1, combinedParagraphs.count)
        }
    }

    /// Combine short paragraphs to meet minimum word threshold
    private func combineParagraphs(
        _ paragraphs: [String],
        minimumWords: Int
    ) -> [(text: String, startIndex: Int)] {
        var result: [(text: String, startIndex: Int)] = []
        var currentText = ""
        var currentStartIndex = 0

        for (index, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if currentText.isEmpty {
                currentText = trimmed
                currentStartIndex = index
            } else {
                currentText += "\n\n" + trimmed
            }

            let wordCount = currentText.split(separator: " ").count
            if wordCount >= minimumWords {
                result.append((text: currentText, startIndex: currentStartIndex))
                currentText = ""
            }
        }

        // Add any remaining text
        if !currentText.isEmpty {
            result.append((text: currentText, startIndex: currentStartIndex))
        }

        return result
    }
}
