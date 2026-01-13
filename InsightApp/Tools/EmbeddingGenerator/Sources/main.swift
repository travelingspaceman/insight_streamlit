import Foundation
@preconcurrency import NaturalLanguage
import Accelerate

// MARK: - Data Models

struct InputParagraph: Codable {
    let documentId: String
    let text: String
    let sourceFile: String
    let paragraphId: Int
    let author: String

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case text
        case sourceFile = "source_file"
        case paragraphId = "paragraph_id"
        case author
    }
}

struct OutputParagraph: Codable {
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

// MARK: - Embedding Generator

class EmbeddingGenerator {
    private var contextualEmbedding: NLContextualEmbedding?

    func prepare() throws {
        print("Loading NLContextualEmbedding model...")

        guard let embedding = NLContextualEmbedding(language: .english) else {
            throw NSError(domain: "EmbeddingGenerator", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "NLContextualEmbedding not available for English"])
        }

        // Check if assets are available
        if embedding.hasAvailableAssets {
            try embedding.load()
            self.contextualEmbedding = embedding
            print("Model loaded successfully. Dimension: \(embedding.dimension)")
        } else {
            print("Requesting model assets download...")

            let semaphore = DispatchSemaphore(value: 0)
            var downloadError: Error?

            embedding.requestAssets { result, error in
                if let error = error {
                    downloadError = error
                } else if result == .available {
                    do {
                        try embedding.load()
                    } catch {
                        downloadError = error
                    }
                } else {
                    downloadError = NSError(domain: "EmbeddingGenerator", code: 2,
                                            userInfo: [NSLocalizedDescriptionKey: "Model assets not available"])
                }
                semaphore.signal()
            }

            semaphore.wait()

            if let error = downloadError {
                throw error
            }

            self.contextualEmbedding = embedding
            print("Model loaded successfully. Dimension: \(embedding.dimension)")
        }
    }

    func generateEmbedding(for text: String) throws -> [Float] {
        guard let embedding = contextualEmbedding else {
            throw NSError(domain: "EmbeddingGenerator", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }

        let result = try embedding.embeddingResult(for: text, language: .english)

        // Collect token vectors for mean pooling
        var tokenVectors: [[Float]] = []
        let dim = embedding.dimension

        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            var floatVector = [Float](repeating: 0, count: dim)
            for i in 0..<dim {
                floatVector[i] = Float(vector[i])
            }
            tokenVectors.append(floatVector)
            return true
        }

        guard !tokenVectors.isEmpty else {
            throw NSError(domain: "EmbeddingGenerator", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "No token vectors generated"])
        }

        // Mean pooling
        return meanPool(tokenVectors, dimension: dim)
    }

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
}

// MARK: - Helpers

func floatArrayToBase64(_ array: [Float]) -> String {
    let data = array.withUnsafeBufferPointer { Data(buffer: $0) }
    return data.base64EncodedString()
}

// MARK: - Main

func main() async throws {
    let arguments = CommandLine.arguments

    guard arguments.count >= 3 else {
        print("Usage: EmbeddingGenerator <input.json> <output.json>")
        print("")
        print("Generates embeddings for paragraphs using Apple's NLContextualEmbedding.")
        print("")
        print("Arguments:")
        print("  input.json   - JSON file containing paragraphs (from Python ingest.py --export-json)")
        print("  output.json  - Output JSON file with embeddings added")
        exit(1)
    }

    let inputPath = arguments[1]
    let outputPath = arguments[2]

    // Read input file
    print("Reading input file: \(inputPath)")
    let inputURL = URL(fileURLWithPath: inputPath)
    let inputData = try Data(contentsOf: inputURL)
    let paragraphs = try JSONDecoder().decode([InputParagraph].self, from: inputData)
    print("Loaded \(paragraphs.count) paragraphs")

    // Initialize embedding generator
    let generator = EmbeddingGenerator()
    try generator.prepare()

    // Process paragraphs
    var outputParagraphs: [OutputParagraph] = []
    let startTime = Date()

    for (index, paragraph) in paragraphs.enumerated() {
        do {
            let embedding = try generator.generateEmbedding(for: paragraph.text)
            let embeddingBase64 = floatArrayToBase64(embedding)

            let output = OutputParagraph(
                documentId: paragraph.documentId,
                text: paragraph.text,
                sourceFile: paragraph.sourceFile,
                paragraphId: paragraph.paragraphId,
                author: paragraph.author,
                embedding: embeddingBase64
            )
            outputParagraphs.append(output)

            // Progress update every 100 paragraphs
            if (index + 1) % 100 == 0 || index == paragraphs.count - 1 {
                let elapsed = Date().timeIntervalSince(startTime)
                let rate = Double(index + 1) / elapsed
                let remaining = Double(paragraphs.count - index - 1) / rate
                print("Progress: \(index + 1)/\(paragraphs.count) (\(String(format: "%.1f", rate)) para/sec, ~\(String(format: "%.0f", remaining))s remaining)")
            }
        } catch {
            print("Warning: Failed to generate embedding for '\(paragraph.documentId)': \(error.localizedDescription)")
            // Skip this paragraph but continue processing
        }
    }

    // Write output file
    print("Writing output file: \(outputPath)")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let outputData = try encoder.encode(outputParagraphs)
    try outputData.write(to: URL(fileURLWithPath: outputPath))

    let totalTime = Date().timeIntervalSince(startTime)
    print("Done! Processed \(outputParagraphs.count) paragraphs in \(String(format: "%.1f", totalTime)) seconds")
}

// Run
try await main()
