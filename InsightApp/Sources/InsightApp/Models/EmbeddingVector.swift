import Foundation
import SwiftData

/// SwiftData model for storing embedding vectors with similarity search support
@Model
public final class EmbeddingVector {
    /// Unique document identifier
    @Attribute(.unique) public var documentId: String

    /// The embedding vector stored as Data for efficiency
    public var embeddingData: Data

    /// The paragraph text (stored for quick access during search)
    public var text: String

    /// Source file name
    public var sourceFile: String

    /// Paragraph ID in original document
    public var paragraphId: Int

    /// Author category raw value for filtering
    public var authorRaw: String

    public init(
        documentId: String,
        embedding: [Float],
        text: String,
        sourceFile: String,
        paragraphId: Int,
        author: Author
    ) {
        self.documentId = documentId
        self.embeddingData = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
        self.text = text
        self.sourceFile = sourceFile
        self.paragraphId = paragraphId
        self.authorRaw = author.rawValue
    }

    /// Get the embedding as a Float array
    public var embedding: [Float] {
        embeddingData.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    /// Get the author enum value
    public var author: Author {
        Author(rawValue: authorRaw) ?? .other
    }

    /// Calculate cosine similarity with another vector
    public func cosineSimilarity(with queryVector: [Float]) -> Float {
        let vec = embedding
        guard vec.count == queryVector.count else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<vec.count {
            dotProduct += vec[i] * queryVector[i]
            normA += vec[i] * vec[i]
            normB += queryVector[i] * queryVector[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }
}
