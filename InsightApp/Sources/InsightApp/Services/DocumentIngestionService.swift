import Foundation
import UniformTypeIdentifiers

/// Errors during document ingestion
public enum IngestionError: Error, LocalizedError {
    case unsupportedFormat
    case parsingFailed(String)
    case emptyDocument
    case alreadyIngested

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This document format is not supported. Please use .txt or .docx files."
        case .parsingFailed(let message):
            return "Failed to parse document: \(message)"
        case .emptyDocument:
            return "The document contains no text content."
        case .alreadyIngested:
            return "This document has already been indexed."
        }
    }
}

/// Progress information for document ingestion
public struct IngestionProgress: Sendable {
    public let current: Int
    public let total: Int
    public let stage: Stage

    public enum Stage: String, Sendable {
        case parsing = "Parsing document..."
        case embedding = "Generating embeddings..."
        case indexing = "Indexing vectors..."
        case complete = "Complete"
    }

    public var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

/// Service for ingesting documents into the search index
public actor DocumentIngestionService {
    private let searchEngine: SemanticSearchEngine

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
    }

    /// Ingest a document from a URL
    /// - Parameters:
    ///   - url: URL to the document file
    ///   - progressHandler: Optional callback for progress updates
    /// - Returns: Number of paragraphs indexed
    public func ingestDocument(
        from url: URL,
        progressHandler: ((IngestionProgress) -> Void)? = nil
    ) async throws -> Int {
        let filename = url.lastPathComponent
        let author = Author.from(filename: filename)

        // Report parsing stage
        progressHandler?(IngestionProgress(current: 0, total: 1, stage: .parsing))

        // Parse the document based on type
        let paragraphs: [String]
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "txt":
            paragraphs = try await parseTextFile(url: url)
        case "docx":
            paragraphs = try await parseDocxFile(url: url)
        default:
            throw IngestionError.unsupportedFormat
        }

        guard !paragraphs.isEmpty else {
            throw IngestionError.emptyDocument
        }

        // Ingest into search engine
        var ingested = 0
        try await searchEngine.ingestDocument(
            paragraphs: paragraphs,
            sourceFile: filename,
            author: author
        ) { current, total in
            ingested = current
            let stage: IngestionProgress.Stage = current < total ? .embedding : .indexing
            progressHandler?(IngestionProgress(current: current, total: total, stage: stage))
        }

        progressHandler?(IngestionProgress(current: ingested, total: ingested, stage: .complete))

        return ingested
    }

    /// Parse a plain text file into paragraphs
    private func parseTextFile(url: URL) async throws -> [String] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw IngestionError.parsingFailed("Could not decode text as UTF-8")
        }

        return splitIntoParagraphs(text)
    }

    /// Parse a DOCX file into paragraphs
    /// Note: Full DOCX parsing requires additional libraries
    /// This is a simplified implementation that extracts text from the XML
    private func parseDocxFile(url: URL) async throws -> [String] {
        // DOCX files are ZIP archives containing XML
        // The main document is usually at word/document.xml

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        do {
            // Create temp directory
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Unzip the docx file
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", url.path, "-d", tempDir.path]
            try process.run()
            process.waitUntilExit()

            // Read the document.xml file
            let documentXML = tempDir.appendingPathComponent("word/document.xml")
            let xmlData = try Data(contentsOf: documentXML)

            // Parse XML to extract text
            return try extractTextFromDocumentXML(xmlData)
        } catch {
            // Fallback: try to read as plain text (in case of mislabeled file)
            return try await parseTextFile(url: url)
        }
    }

    /// Extract text paragraphs from DOCX document.xml
    private func extractTextFromDocumentXML(_ data: Data) throws -> [String] {
        let parser = DocxXMLParser(data: data)
        return try parser.parse()
    }

    /// Split text into paragraphs
    private func splitIntoParagraphs(_ text: String) -> [String] {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Simple DOCX XML Parser

private class DocxXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var paragraphs: [String] = []
    private var currentParagraphText = ""
    private var isInsideText = false

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw IngestionError.parsingFailed(parser.parserError?.localizedDescription ?? "Unknown XML error")
        }
        return paragraphs.filter { !$0.isEmpty }
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // w:t is the text element in DOCX
        if elementName == "w:t" {
            isInsideText = true
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "w:t" {
            isInsideText = false
        } else if elementName == "w:p" {
            // End of paragraph
            let trimmed = currentParagraphText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                paragraphs.append(trimmed)
            }
            currentParagraphText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideText {
            currentParagraphText += string
        }
    }
}
