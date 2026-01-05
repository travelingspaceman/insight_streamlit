import SwiftUI

/// Main content view for the Insight app
public struct ContentView: View {
    @State private var viewModel: SearchViewModel
    @State private var showFilters = false

    private let searchEngine: SemanticSearchEngine

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
        self._viewModel = State(initialValue: SearchViewModel(searchEngine: searchEngine))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search mode picker
                searchModePicker

                // Search input area
                searchInputArea

                // Results list
                resultsList
            }
            .navigationTitle("Insight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(viewModel.selectedAuthors.isEmpty ? .none : .fill)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Subviews

    private var searchModePicker: some View {
        Picker("Search Mode", selection: $viewModel.searchMode) {
            ForEach(SearchMode.allCases) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }

    private var searchInputArea: some View {
        VStack(spacing: 12) {
            TextField(viewModel.searchMode.placeholder, text: $viewModel.searchText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await viewModel.search()
                    }
                }

            Button {
                Task {
                    await viewModel.search()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text("Search")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color("AccentColor", bundle: .module))
            .disabled(viewModel.isSearchDisabled)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var resultsList: some View {
        Group {
            if viewModel.results.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label("No Results", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Enter a search query to find relevant passages from the Bahá'í writings.")
                }
            } else {
                List(viewModel.results) { result in
                    SearchResultRow(result: result)
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: ParagraphResult

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main text content
            Text(result.text)
                .font(.body)
                .lineLimit(isExpanded ? nil : 4)

            // Metadata
            HStack {
                Label(result.author.displayName, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(String(format: "%.1f%%", result.score * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Source info
            HStack {
                Text(BahaiLibraryURLMapper.displayTitle(for: result.sourceFile))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("¶\(result.paragraphId)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if let url = result.libraryURL {
                    Link(destination: url) {
                        Label("Read Online", systemImage: "safari")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
        }
    }
}

#Preview {
    ContentView(searchEngine: PreviewSearchEngine.shared)
}

// Preview helper
private enum PreviewSearchEngine {
    @MainActor
    static var shared: SemanticSearchEngine {
        let vectorStore = try! VectorStore()
        return SemanticSearchEngine(vectorStore: vectorStore)
    }
}
