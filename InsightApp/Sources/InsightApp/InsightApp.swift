import SwiftUI
import SwiftData

/// Main entry point for the Insight app
@main
public struct InsightApp: App {
    @State private var vectorStore: VectorStore?
    @State private var searchEngine: SemanticSearchEngine?
    @State private var initError: Error?
    @State private var loadingStatus: String = "Initializing..."

    public init() {}

    public var body: some Scene {
        WindowGroup {
            Group {
                if let searchEngine {
                    MainTabView(searchEngine: searchEngine)
                } else if let error = initError {
                    ErrorView(error: error) {
                        Task {
                            await initialize()
                        }
                    }
                } else {
                    LoadingView(status: loadingStatus)
                        .task {
                            await initialize()
                        }
                }
            }
        }
        .modelContainer(for: Paragraph.self)
    }

    @MainActor
    private func initialize() async {
        do {
            loadingStatus = "Opening database..."
            let store = try VectorStore()

            // Import from bundle if database is empty
            let count = try store.count()
            if count == 0 {
                loadingStatus = "Importing writings database..."
                do {
                    let imported = try await store.importFromBundle()
                    print("Imported \(imported) vectors from bundle")
                } catch ImportError.fileNotFound {
                    // No bundled data - that's okay, database is just empty
                    print("No bundled embeddings.json found, starting with empty database")
                }
            }

            loadingStatus = "Loading search engine..."
            let engine = SemanticSearchEngine(vectorStore: store)
            self.vectorStore = store
            self.searchEngine = engine
        } catch {
            self.initError = error
        }
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var status: String = "Initializing..."

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Insight")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView()
                .controlSize(.large)

            Text(status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Initialization Failed")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
    }
}
