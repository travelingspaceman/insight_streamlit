import Foundation
import ObjectBox

// objectbox: entity
/// ObjectBox entity for storing embedding vectors with HNSW vector search support
public class EmbeddingVector: Identifiable, @unchecked Sendable {
    /// ObjectBox-managed unique identifier
    public var id: Id = 0

    /// Reference to the paragraph's documentId in SwiftData
    public var documentId: String = ""

    /// The embedding vector for HNSW similarity search
    /// NLContextualEmbedding produces variable-dimension vectors based on the script
    // objectbox: hnswIndex: dimensions=512, neighborsPerNode=30, indexingSearchCount=100
    public var embedding: HnswVector<Float32> = HnswVector()

    /// The paragraph text (stored for quick access during search)
    public var text: String = ""

    /// Source file name
    public var sourceFile: String = ""

    /// Paragraph ID in original document
    public var paragraphId: Int = 0

    /// Author category raw value for filtering
    public var authorRaw: String = ""

    public init() {}

    public init(
        documentId: String,
        embedding: [Float],
        text: String,
        sourceFile: String,
        paragraphId: Int,
        author: Author
    ) {
        self.documentId = documentId
        self.embedding = HnswVector(embedding)
        self.text = text
        self.sourceFile = sourceFile
        self.paragraphId = paragraphId
        self.authorRaw = author.rawValue
    }

    public var author: Author {
        Author(rawValue: authorRaw) ?? .other
    }
}
