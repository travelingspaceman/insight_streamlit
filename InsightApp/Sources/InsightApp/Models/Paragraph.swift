import Foundation
import SwiftData

/// Represents a paragraph from the Bahá'í writings
@Model
public final class Paragraph {
    /// Unique identifier for this paragraph
    @Attribute(.unique)
    public var documentId: String

    /// The full text content of the paragraph
    public var text: String

    /// The source filename (e.g., "gleanings-writings-bahaullah.docx")
    public var sourceFile: String

    /// The original paragraph number in the document
    public var paragraphId: Int

    /// The author category
    public var authorRaw: String

    /// The embedding vector ID in ObjectBox (if embedded)
    public var vectorId: UInt64?

    /// Computed property for author enum
    public var author: Author {
        get { Author(rawValue: authorRaw) ?? .other }
        set { authorRaw = newValue.rawValue }
    }

    public init(
        documentId: String,
        text: String,
        sourceFile: String,
        paragraphId: Int,
        author: Author,
        vectorId: UInt64? = nil
    ) {
        self.documentId = documentId
        self.text = text
        self.sourceFile = sourceFile
        self.paragraphId = paragraphId
        self.authorRaw = author.rawValue
        self.vectorId = vectorId
    }
}

/// Lightweight struct for search results without SwiftData dependency
public struct ParagraphResult: Identifiable, Sendable {
    public let id: String
    public let text: String
    public let sourceFile: String
    public let paragraphId: Int
    public let author: Author
    public let score: Float

    public init(
        id: String,
        text: String,
        sourceFile: String,
        paragraphId: Int,
        author: Author,
        score: Float
    ) {
        self.id = id
        self.text = text
        self.sourceFile = sourceFile
        self.paragraphId = paragraphId
        self.author = author
        self.score = score
    }

    /// URL to the official Bahá'í library for this source
    public var libraryURL: URL? {
        BahaiLibraryURLMapper.url(for: sourceFile)
    }
}
