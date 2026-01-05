import SwiftUI
import SwiftData

/// Main entry point for the Insight app
@main
public struct InsightApp: App {
    @State private var vectorStore: VectorStore?
    @State private var searchEngine: SemanticSearchEngine?
    @State private var initError: Error?

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
                    LoadingView()
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
            let store = try VectorStore()
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

            Text("Initializing...")
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
