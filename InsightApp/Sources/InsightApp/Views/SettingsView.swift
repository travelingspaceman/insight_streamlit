import SwiftUI
import UniformTypeIdentifiers

/// Settings and document management view
public struct SettingsView: View {
    @State private var showDocumentPicker = false
    @State private var isIngesting = false
    @State private var ingestionProgress: IngestionProgress?
    @State private var stats: VectorStoreStats?
    @State private var showClearConfirmation = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    private let searchEngine: SemanticSearchEngine
    private let ingestionService: DocumentIngestionService

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
        self.ingestionService = DocumentIngestionService(searchEngine: searchEngine)
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

                // Document import
                Section("Import Documents") {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Import Document", systemImage: "doc.badge.plus")
                    }
                    .disabled(isIngesting)

                    if isIngesting, let progress = ingestionProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(progress.stage.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ProgressView(value: progress.percentage)

                            Text("\(progress.current) of \(progress.total)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Data management
                Section("Data Management") {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                    .disabled(isIngesting)
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
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.plainText, UTType(filenameExtension: "docx")!],
                allowsMultipleSelection: false
            ) { result in
                handleDocumentImport(result)
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all indexed documents. This action cannot be undone.")
            }
            .alert("Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .task {
                await loadStats()
            }
        }
    }

    // MARK: - Actions

    private func handleDocumentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                await ingestDocument(from: url)
            }

        case .failure(let error):
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    @MainActor
    private func ingestDocument(from url: URL) async {
        isIngesting = true
        defer { isIngesting = false }

        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "Could not access the selected file."
            showAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let count = try await ingestionService.ingestDocument(from: url) { progress in
                Task { @MainActor in
                    ingestionProgress = progress
                }
            }

            alertMessage = "Successfully indexed \(count) paragraphs."
            showAlert = true

            // Reload stats
            await loadStats()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }

        ingestionProgress = nil
    }

    @MainActor
    private func clearAllData() {
        do {
            try searchEngine.clearIndex()
            alertMessage = "All data has been cleared."
            showAlert = true
            stats = nil
            Task {
                await loadStats()
            }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
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
