// Public exports for the InsightApp module
// This file makes the main types available when importing the module

@_exported import struct Foundation.URL
@_exported import struct Foundation.Data

// Re-export key types for consumers of this package
public typealias InsightSearchEngine = SemanticSearchEngine
public typealias InsightVectorStore = VectorStore
public typealias InsightEmbeddingService = EmbeddingService
