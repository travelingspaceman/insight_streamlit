import Foundation
import ObjectBox

/// Manages the ObjectBox vector database for storing and searching embeddings
@MainActor
public final class VectorStore: Sendable {
    private let store: Store
    private let box: Box<EmbeddingVector>

    /// Initialize the vector store with a directory for the database
    public init(directory: URL? = nil) throws {
        let dbDirectory: URL
        if let directory {
            dbDirectory = directory
        } else {
            dbDirectory = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("InsightApp", isDirectory: true)
                .appendingPathComponent("VectorDB", isDirectory: true)
        }

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: dbDirectory,
            withIntermediateDirectories: true
        )

        // Initialize ObjectBox store
        self.store = try Store(directoryPath: dbDirectory.path)
        self.box = store.box(for: EmbeddingVector.self)
    }

    /// Insert a new embedding vector
    public func insert(_ vector: EmbeddingVector) throws -> Id {
        try box.put(vector)
    }

    /// Insert multiple embedding vectors in a batch
    public func insertBatch(_ vectors: [EmbeddingVector]) throws -> [Id] {
        try box.put(vectors)
    }

    /// Search for similar vectors using HNSW nearest neighbor search
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
        // Build the nearest neighbor query
        var query = try box.query {
            EmbeddingVector.embedding.nearestNeighbors(
                queryVector: queryVector,
                maxCount: UInt32(limit * 2) // Fetch extra for filtering
            )
        }

        // Execute query and get results with scores
        let results = try query.findWithScores()

        // Filter by author if specified
        let filtered: [(EmbeddingVector, Double)]
        if let authorFilter, !authorFilter.isEmpty {
            filtered = results.filter { vector, _ in
                authorFilter.contains(vector.author)
            }
        } else {
            filtered = results
        }

        // Return top 'limit' results, converting score to Float
        return Array(filtered.prefix(limit)).map { ($0.0, Float($0.1)) }
    }

    /// Get all vectors for a specific author
    public func vectors(for author: Author) throws -> [EmbeddingVector] {
        let query = try box.query {
            EmbeddingVector.authorRaw == author.rawValue
        }
        return try query.find()
    }

    /// Get a vector by its document ID
    public func vector(documentId: String) throws -> EmbeddingVector? {
        let query = try box.query {
            EmbeddingVector.documentId == documentId
        }
        return try query.findFirst()
    }

    /// Check if a document ID already exists
    public func exists(documentId: String) throws -> Bool {
        try vector(documentId: documentId) != nil
    }

    /// Get the total count of vectors in the store
    public func count() throws -> Int {
        Int(try box.count())
    }

    /// Delete all vectors from the store
    public func deleteAll() throws {
        try box.removeAll()
    }

    /// Delete vectors for a specific source file
    public func delete(sourceFile: String) throws {
        let query = try box.query {
            EmbeddingVector.sourceFile == sourceFile
        }
        try query.remove()
    }

    /// Get statistics about the vector store
    public func stats() throws -> VectorStoreStats {
        let total = try count()
        var authorCounts: [Author: Int] = [:]

        for author in Author.allCases {
            let query = try box.query {
                EmbeddingVector.authorRaw == author.rawValue
            }
            authorCounts[author] = Int(try query.count())
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
