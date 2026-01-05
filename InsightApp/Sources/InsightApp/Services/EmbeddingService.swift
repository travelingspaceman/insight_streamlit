import Foundation
import NaturalLanguage

/// Errors that can occur during embedding generation
public enum EmbeddingError: Error, LocalizedError {
    case embeddingNotAvailable
    case embeddingGenerationFailed(String)
    case assetLoadFailed
    case modelNotReady

    public var errorDescription: String? {
        switch self {
        case .embeddingNotAvailable:
            return "NLContextualEmbedding is not available on this device"
        case .embeddingGenerationFailed(let message):
            return "Failed to generate embedding: \(message)"
        case .assetLoadFailed:
            return "Failed to load embedding model assets"
        case .modelNotReady:
            return "Embedding model is not ready yet"
        }
    }
}

/// Service for generating text embeddings using Apple's NLContextualEmbedding
/// Runs entirely on-device for privacy and offline capability
public actor EmbeddingService {
    private var embedding: NLContextualEmbedding?
    private var isReady = false

    /// Shared instance for convenience
    public static let shared = EmbeddingService()

    public init() {}

    /// Prepare the embedding model for use
    /// Call this before generating embeddings to ensure the model is loaded
    public func prepare() async throws {
        // Check if contextual embedding is available for English
        guard let contextualEmbedding = NLContextualEmbedding(language: .english) else {
            throw EmbeddingError.embeddingNotAvailable
        }

        // Request assets if needed
        if contextualEmbedding.hasAvailableAssets {
            // Load the model
            try contextualEmbedding.load()
            self.embedding = contextualEmbedding
            self.isReady = true
        } else {
            // Request asset download
            NLContextualEmbedding.requestAssets(for: .english) { [weak self] result, error in
                guard let self else { return }
                Task {
                    await self.handleAssetRequest(embedding: contextualEmbedding, result: result, error: error)
                }
            }
        }
    }

    private func handleAssetRequest(
        embedding: NLContextualEmbedding,
        result: NLContextualEmbedding.AssetsResult,
        error: Error?
    ) {
        guard error == nil, result == .available else {
            return
        }

        do {
            try embedding.load()
            self.embedding = embedding
            self.isReady = true
        } catch {
            // Asset loading failed, will retry on next prepare()
        }
    }

    /// Check if the embedding service is ready to generate embeddings
    public var ready: Bool {
        isReady
    }

    /// Get the dimension of the embedding vectors
    public var dimension: Int {
        embedding?.dimension ?? 512
    }

    /// Generate an embedding for the given text
    /// - Parameter text: The text to generate an embedding for
    /// - Returns: Array of floating point values representing the embedding
    public func generateEmbedding(for text: String) throws -> [Float] {
        guard isReady, let embedding else {
            throw EmbeddingError.modelNotReady
        }

        // Generate the embedding result for the full text
        guard let embeddingResult = embedding.embeddingResult(for: text, language: .english) else {
            throw EmbeddingError.embeddingGenerationFailed("Could not generate embedding result")
        }

        // Get the vector for the full text range
        let range = text.startIndex..<text.endIndex
        guard let vector = embeddingResult.vector(for: range) else {
            throw EmbeddingError.embeddingGenerationFailed("Could not extract vector for text range")
        }

        // Convert to Float array
        return (0..<embedding.dimension).map { Float(vector[$0]) }
    }

    /// Generate embeddings for multiple texts
    /// - Parameter texts: Array of texts to generate embeddings for
    /// - Returns: Array of embedding vectors
    public func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        var embeddings: [[Float]] = []
        embeddings.reserveCapacity(texts.count)

        for text in texts {
            let embedding = try generateEmbedding(for: text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    /// Generate an embedding for a query (optimized for search)
    /// This uses the same embedding method but can be extended for query-specific processing
    public func generateQueryEmbedding(for query: String) throws -> [Float] {
        try generateEmbedding(for: query)
    }
}

// MARK: - Cosine Similarity

extension EmbeddingService {
    /// Calculate cosine similarity between two vectors
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
