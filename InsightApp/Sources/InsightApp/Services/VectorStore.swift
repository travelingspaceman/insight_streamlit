import Foundation
import SwiftData

/// Manages the SwiftData vector database for storing and searching embeddings
@MainActor
public final class VectorStore: Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// Initialize the vector store
    public init() throws {
        let schema = Schema([EmbeddingVector.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .none
        )
        self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        self.modelContext = ModelContext(modelContainer)
    }

    /// Insert a new embedding vector
    @discardableResult
    public func insert(_ vector: EmbeddingVector) throws -> EmbeddingVector {
        modelContext.insert(vector)
        try modelContext.save()
        return vector
    }

    /// Insert multiple embedding vectors in a batch
    @discardableResult
    public func insertBatch(_ vectors: [EmbeddingVector]) throws -> [EmbeddingVector] {
        for vector in vectors {
            modelContext.insert(vector)
        }
        try modelContext.save()
        return vectors
    }

    /// Search for similar vectors using cosine similarity
    /// - Parameters:
    ///   - queryVector: The embedding vector to search for
    ///   - limit: Maximum number of results to return
    ///   - authorFilter: Optional filter for specific authors
    /// - Returns: Array of tuples containing the vector and its similarity score
    public func search(
        queryVector: [Float],
        limit: Int = 10,
        authorFilter: Set<Author>? = nil
    ) throws -> [(EmbeddingVector, Float)] {
        // Fetch all vectors (or filtered by author)
        let descriptor = FetchDescriptor<EmbeddingVector>()

        let allVectors = try modelContext.fetch(descriptor)

        // Filter by author if specified
        let filteredVectors: [EmbeddingVector]
        if let authorFilter, !authorFilter.isEmpty {
            filteredVectors = allVectors.filter { authorFilter.contains($0.author) }
        } else {
            filteredVectors = allVectors
        }

        // Calculate similarity scores and sort
        var results: [(EmbeddingVector, Float)] = filteredVectors.map { vector in
            (vector, vector.cosineSimilarity(with: queryVector))
        }

        // Sort by similarity (highest first) and take top 'limit'
        results.sort { $0.1 > $1.1 }
        return Array(results.prefix(limit))
    }

    /// Get all vectors for a specific author
    public func vectors(for author: Author) throws -> [EmbeddingVector] {
        let descriptor = FetchDescriptor<EmbeddingVector>(
            predicate: #Predicate { $0.authorRaw == author.rawValue }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get a vector by its document ID
    public func vector(documentId: String) throws -> EmbeddingVector? {
        var descriptor = FetchDescriptor<EmbeddingVector>(
            predicate: #Predicate { $0.documentId == documentId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Check if a document ID already exists
    public func exists(documentId: String) throws -> Bool {
        try vector(documentId: documentId) != nil
    }

    /// Get the total count of vectors in the store
    public func count() throws -> Int {
        let descriptor = FetchDescriptor<EmbeddingVector>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Delete all vectors from the store
    public func deleteAll() throws {
        try modelContext.delete(model: EmbeddingVector.self)
        try modelContext.save()
    }

    /// Delete vectors for a specific source file
    public func delete(sourceFile: String) throws {
        let descriptor = FetchDescriptor<EmbeddingVector>(
            predicate: #Predicate { $0.sourceFile == sourceFile }
        )
        let vectors = try modelContext.fetch(descriptor)
        for vector in vectors {
            modelContext.delete(vector)
        }
        try modelContext.save()
    }

    /// Get statistics about the vector store
    public func stats() throws -> VectorStoreStats {
        let total = try count()
        var authorCounts: [Author: Int] = [:]

        for author in Author.allCases {
            let descriptor = FetchDescriptor<EmbeddingVector>(
                predicate: #Predicate { $0.authorRaw == author.rawValue }
            )
            authorCounts[author] = try modelContext.fetchCount(descriptor)
        }

        return VectorStoreStats(
            totalVectors: total,
            vectorsByAuthor: authorCounts
        )
    }
}

/// Statistics about the vector store
public struct VectorStoreStats: Sendable {
    public let totalVectors: Int
    public let vectorsByAuthor: [Author: Int]
}

// MARK: - Bundle Import

/// Data structure for importing pre-computed embeddings from JSON
private struct ImportedParagraph: Codable {
    let documentId: String
    let text: String
    let sourceFile: String
    let paragraphId: Int
    let author: String
    let embedding: String  // Base64-encoded Float array

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case text
        case sourceFile = "source_file"
        case paragraphId = "paragraph_id"
        case author
        case embedding
    }
}

extension VectorStore {
    /// Import pre-computed embeddings from a JSON file in the app bundle
    /// - Parameter filename: Name of the JSON file (without extension)
    /// - Returns: Number of vectors imported
    @discardableResult
    public func importFromBundle(filename: String = "embeddings") async throws -> Int {
        // Check if already populated
        let existingCount = try count()
        if existingCount > 0 {
            print("Database already contains \(existingCount) vectors, skipping import")
            return 0
        }

        // Find the JSON file in the bundle
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw ImportError.fileNotFound(filename)
        }

        print("Importing embeddings from \(url.lastPathComponent)...")

        // Load and parse JSON
        let data = try Data(contentsOf: url)
        let paragraphs = try JSONDecoder().decode([ImportedParagraph].self, from: data)

        print("Loaded \(paragraphs.count) paragraphs from JSON")

        // Convert to EmbeddingVector objects
        var imported = 0
        let batchSize = 100

        for batchStart in stride(from: 0, to: paragraphs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, paragraphs.count)
            let batch = paragraphs[batchStart..<batchEnd]

            var vectors: [EmbeddingVector] = []
            for paragraph in batch {
                guard let embeddingData = Data(base64Encoded: paragraph.embedding) else {
                    print("Warning: Invalid base64 for \(paragraph.documentId)")
                    continue
                }

                let embedding = embeddingData.withUnsafeBytes { buffer in
                    Array(buffer.bindMemory(to: Float.self))
                }

                let author = Author(rawValue: paragraph.author) ?? .other

                let vector = EmbeddingVector(
                    documentId: paragraph.documentId,
                    embedding: embedding,
                    text: paragraph.text,
                    sourceFile: paragraph.sourceFile,
                    paragraphId: paragraph.paragraphId,
                    author: author
                )
                vectors.append(vector)
            }

            try insertBatch(vectors)
            imported += vectors.count

            print("Imported \(imported)/\(paragraphs.count) vectors...")
        }

        print("Import complete: \(imported) vectors")
        return imported
    }
}

/// Errors that can occur during import
public enum ImportError: Error, LocalizedError {
    case fileNotFound(String)
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Could not find \(filename).json in app bundle"
        case .invalidData:
            return "Invalid data format in import file"
        }
    }
}
