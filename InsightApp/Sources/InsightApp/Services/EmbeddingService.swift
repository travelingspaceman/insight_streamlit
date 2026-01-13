import Foundation
import NaturalLanguage
import Accelerate

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
            // Request asset download and wait for it
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<NLContextualEmbedding.AssetsResult, Never>) in
                contextualEmbedding.requestAssets { result, _ in
                    continuation.resume(returning: result)
                }
            }

            switch result {
            case .available:
                try contextualEmbedding.load()
                self.embedding = contextualEmbedding
                self.isReady = true
            case .notAvailable:
                throw EmbeddingError.embeddingNotAvailable
            case .error:
                throw EmbeddingError.assetLoadFailed
            @unknown default:
                throw EmbeddingError.assetLoadFailed
            }
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

    /// Generate an embedding for the given text using mean pooling
    /// - Parameter text: The text to generate an embedding for
    /// - Returns: Array of floating point values representing the embedding
    public func generateEmbedding(for text: String) throws -> [Float] {
        guard isReady, let embedding else {
            throw EmbeddingError.modelNotReady
        }

        // Generate the embedding result for the full text
        let embeddingResult: NLContextualEmbeddingResult
        do {
            embeddingResult = try embedding.embeddingResult(for: text, language: .english)
        } catch {
            throw EmbeddingError.embeddingGenerationFailed("Could not generate embedding result: \(error.localizedDescription)")
        }

        // Collect all token vectors for mean pooling
        var tokenVectors: [[Float]] = []
        let dim = embedding.dimension

        embeddingResult.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            // Convert vector to Float array
            var floatVector = [Float](repeating: 0, count: dim)
            for i in 0..<dim {
                floatVector[i] = Float(vector[i])
            }
            tokenVectors.append(floatVector)
            return true // Continue enumeration
        }

        guard !tokenVectors.isEmpty else {
            throw EmbeddingError.embeddingGenerationFailed("No token vectors generated")
        }

        // Mean pooling: average all token vectors
        return meanPool(tokenVectors, dimension: dim)
    }

    /// Compute mean pooling of token vectors using Accelerate
    private func meanPool(_ vectors: [[Float]], dimension: Int) -> [Float] {
        var result = [Float](repeating: 0, count: dimension)
        let count = Float(vectors.count)

        for vector in vectors {
            vDSP_vadd(result, 1, vector, 1, &result, 1, vDSP_Length(dimension))
        }

        var scale = 1.0 / count
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(dimension))

        return result
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
