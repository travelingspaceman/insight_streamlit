import SwiftUI

/// Main tab view containing Search and Settings tabs
public struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var isReady = false
    @State private var loadingError: Error?

    private let searchEngine: SemanticSearchEngine

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
    }

    public var body: some View {
        Group {
            if isReady {
                TabView(selection: $selectedTab) {
                    ContentView(searchEngine: searchEngine)
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .tag(0)

                    SettingsView(searchEngine: searchEngine)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(1)
                }
                .tint(Color("AccentColor", bundle: .module))
            } else if let error = loadingError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    Text("Failed to Initialize")
                        .font(.headline)

                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Retry") {
                        Task {
                            await initialize()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)

                    Text("Preparing Insight...")
                        .font(.headline)

                    Text("Loading embedding model")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await initialize()
        }
    }

    @MainActor
    private func initialize() async {
        loadingError = nil
        await searchEngine.prepare()

        if searchEngine.isReady {
            withAnimation {
                isReady = true
            }
        } else if let error = searchEngine.error {
            loadingError = error
        }
    }
}

#Preview {
    MainTabView(searchEngine: PreviewSearchEngine.shared)
}

// Preview helper
private enum PreviewSearchEngine {
    @MainActor
    static var shared: SemanticSearchEngine {
        let vectorStore = try! VectorStore()
        return SemanticSearchEngine(vectorStore: vectorStore)
    }
}
