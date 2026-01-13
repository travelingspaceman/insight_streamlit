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

}
