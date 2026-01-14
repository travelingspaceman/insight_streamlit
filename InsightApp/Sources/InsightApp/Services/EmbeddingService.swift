import Foundation
import CoreML
import Accelerate

/// Errors that can occur during embedding generation
public enum EmbeddingError: Error, LocalizedError {
    case modelNotFound
    case modelLoadFailed(String)
    case tokenizationFailed(String)
    case inferenceFailed(String)
    case modelNotReady

    public var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "MiniLM.mlmodelc not found in app bundle"
        case .modelLoadFailed(let message):
            return "Failed to load embedding model: \(message)"
        case .tokenizationFailed(let message):
            return "Failed to tokenize text: \(message)"
        case .inferenceFailed(let message):
            return "Failed to generate embedding: \(message)"
        case .modelNotReady:
            return "Embedding model is not ready yet"
        }
    }
}

/// Service for generating text embeddings using Core ML MiniLM model
/// Runs entirely on-device for privacy and offline capability
public actor EmbeddingService {
    private var model: MLModel?
    private var tokenizer: BertTokenizer?
    private var isReady = false

    /// Embedding dimension (paraphrase-MiniLM-L6-v2 uses 384)
    public static let embeddingDimension = 384

    /// Max sequence length
    public static let maxSequenceLength = 128

    /// Shared instance for convenience
    public static let shared = EmbeddingService()

    public init() {}

    /// Prepare the embedding model for use
    /// Call this before generating embeddings to ensure the model is loaded
    public func prepare() async throws {
        // Load tokenizer
        do {
            tokenizer = try BertTokenizer(maxLength: Self.maxSequenceLength)
        } catch {
            throw EmbeddingError.tokenizationFailed(error.localizedDescription)
        }

        // Load Core ML model
        guard let modelURL = Bundle.main.url(forResource: "MiniLM", withExtension: "mlmodelc") else {
            throw EmbeddingError.modelNotFound
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            model = try MLModel(contentsOf: modelURL, configuration: config)
            isReady = true
        } catch {
            throw EmbeddingError.modelLoadFailed(error.localizedDescription)
        }
    }

    /// Check if the embedding service is ready to generate embeddings
    public var ready: Bool {
        isReady
    }

    /// Get the dimension of the embedding vectors
    public var dimension: Int {
        Self.embeddingDimension
    }

    /// Generate an embedding for the given text
    /// - Parameter text: The text to generate an embedding for
    /// - Returns: Array of floating point values representing the embedding (384 dimensions)
    public func generateEmbedding(for text: String) throws -> [Float] {
        guard isReady, let model = model, let tokenizer = tokenizer else {
            throw EmbeddingError.modelNotReady
        }

        // Tokenize the input
        let (inputIds, attentionMask) = tokenizer.encode(text)

        // Create MLMultiArray inputs
        guard let inputIdsArray = try? MLMultiArray(shape: [1, NSNumber(value: Self.maxSequenceLength)], dataType: .int32),
              let attentionMaskArray = try? MLMultiArray(shape: [1, NSNumber(value: Self.maxSequenceLength)], dataType: .int32) else {
            throw EmbeddingError.inferenceFailed("Failed to create input arrays")
        }

        // Fill the arrays
        for i in 0..<Self.maxSequenceLength {
            inputIdsArray[i] = NSNumber(value: inputIds[i])
            attentionMaskArray[i] = NSNumber(value: attentionMask[i])
        }

        // Create feature provider
        let inputFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIdsArray),
            "attention_mask": MLFeatureValue(multiArray: attentionMaskArray)
        ])

        // Run inference
        let output: MLFeatureProvider
        do {
            output = try model.prediction(from: inputFeatures)
        } catch {
            throw EmbeddingError.inferenceFailed(error.localizedDescription)
        }

        // Extract embeddings
        guard let embeddingsFeature = output.featureValue(for: "embeddings"),
              let embeddingsArray = embeddingsFeature.multiArrayValue else {
            throw EmbeddingError.inferenceFailed("Could not extract embeddings from model output")
        }

        // Convert to Float array
        var embedding = [Float](repeating: 0, count: Self.embeddingDimension)
        for i in 0..<Self.embeddingDimension {
            embedding[i] = embeddingsArray[i].floatValue
        }

        return embedding
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

    /// Generate an embedding for a query (same as regular embedding for this model)
    public func generateQueryEmbedding(for query: String) throws -> [Float] {
        try generateEmbedding(for: query)
    }
}

// MARK: - Cosine Similarity

extension EmbeddingService {
    /// Calculate cosine similarity between two vectors using Accelerate
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
