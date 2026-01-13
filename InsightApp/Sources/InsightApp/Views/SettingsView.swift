import SwiftUI

/// Settings and statistics view
public struct SettingsView: View {
    @State private var stats: VectorStoreStats?

    private let searchEngine: SemanticSearchEngine

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
    }

    public var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle("Settings")
            .task {
                await loadStats()
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
