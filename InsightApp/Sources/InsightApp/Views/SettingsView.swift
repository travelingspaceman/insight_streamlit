import SwiftUI

/// Settings and statistics view
public struct SettingsView: View {
    @State private var stats: VectorStoreStats?

    // Embedding sandbox state
    @State private var text1 = ""
    @State private var text2 = ""
    @State private var similarityResult: SimilarityResult?
    @State private var isCalculating = false
    @State private var calculationError: String?

    private let searchEngine: SemanticSearchEngine
    private let embeddingService = EmbeddingService()

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Embedding Sandbox
                Section("Embedding Sandbox") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text 1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $text1)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text 2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $text2)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Button {
                        Task {
                            await calculateSimilarity()
                        }
                    } label: {
                        HStack {
                            if isCalculating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(isCalculating ? "Calculating..." : "Calculate Similarity")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(text1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              text2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              isCalculating)

                    if let result = similarityResult {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Similarity Score") {
                                Text(String(format: "%.4f", result.score))
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(result.score > 0.7 ? .green : (result.score > 0.4 ? .orange : .red))
                            }
                            LabeledContent("Embedding Dimension", value: "\(result.dimension)")
                        }
                    }

                    if let error = calculationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Index statistics
                Section("Index Statistics") {
                    if let stats {
                        LabeledContent("Total Paragraphs", value: "\(stats.totalVectors)")

                        ForEach(Author.allCases.filter { stats.vectorsByAuthor[$0, default: 0] > 0 }) { author in
                            LabeledContent(author.displayName, value: "\(stats.vectorsByAuthor[author, default: 0])")
                        }
                    } else {
                        HStack {
                            Text("Loading statistics...")
                            Spacer()
                            ProgressView()
                        }
                    }
                }

                // About section
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")

                    Link(destination: URL(string: "https://www.bahai.org/library")!) {
                        Label("Bahá'í Reference Library", systemImage: "safari")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .task {
                await loadStats()
                await prepareEmbedding()
            }
        }
    }

    @MainActor
    private func loadStats() async {
        do {
            stats = try searchEngine.stats()
        } catch {
            // Stats loading failed silently
        }
    }

    @MainActor
    private func prepareEmbedding() async {
        do {
            try await embeddingService.prepare()
        } catch {
            calculationError = "Failed to load embedding model: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func calculateSimilarity() async {
        isCalculating = true
        calculationError = nil
        similarityResult = nil

        do {
            let embedding1 = try await embeddingService.generateEmbedding(for: text1.trimmingCharacters(in: .whitespacesAndNewlines))
            let embedding2 = try await embeddingService.generateEmbedding(for: text2.trimmingCharacters(in: .whitespacesAndNewlines))

            let score = EmbeddingService.cosineSimilarity(embedding1, embedding2)
            similarityResult = SimilarityResult(score: score, dimension: embedding1.count)
        } catch {
            calculationError = error.localizedDescription
        }

        isCalculating = false
    }
}

private struct SimilarityResult {
    let score: Float
    let dimension: Int
}

#Preview {
    SettingsView(searchEngine: PreviewSearchEngine.shared)
}

// Preview helper
private enum PreviewSearchEngine {
    @MainActor
    static var shared: SemanticSearchEngine {
        let vectorStore = try! VectorStore()
        return SemanticSearchEngine(vectorStore: vectorStore)
    }
}
