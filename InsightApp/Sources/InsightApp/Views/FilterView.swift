import SwiftUI

/// View for configuring search filters
public struct FilterView: View {
    @Bindable var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SearchViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Author filter section
                Section {
                    ForEach(Author.allCases) { author in
                        Toggle(author.displayName, isOn: authorBinding(for: author))
                    }
                } header: {
                    HStack {
                        Text("Filter by Author")
                        Spacer()
                        Button("All") {
                            viewModel.selectAllAuthors()
                        }
                        .font(.caption)
                        Text("/")
                            .foregroundStyle(.secondary)
                        Button("None") {
                            viewModel.deselectAllAuthors()
                        }
                        .font(.caption)
                    }
                } footer: {
                    Text("When no authors are selected, all authors are included in search results.")
                }

                // Result count section
                Section("Number of Results") {
                    Stepper(
                        "\(viewModel.resultCount) results",
                        value: $viewModel.resultCount,
                        in: 1...20
                    )

                    Slider(
                        value: resultCountBinding,
                        in: 1...20,
                        step: 1
                    ) {
                        Text("Results")
                    } minimumValueLabel: {
                        Text("1")
                    } maximumValueLabel: {
                        Text("20")
                    }
                }

                // Reset section
                Section {
                    Button("Reset All Filters", role: .destructive) {
                        viewModel.resetFilters()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func authorBinding(for author: Author) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedAuthors.contains(author) },
            set: { isSelected in
                if isSelected {
                    viewModel.selectedAuthors.insert(author)
                } else {
                    viewModel.selectedAuthors.remove(author)
                }
            }
        )
    }

    private var resultCountBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.resultCount) },
            set: { viewModel.resultCount = Int($0) }
        )
    }
}

#Preview {
    FilterView(viewModel: SearchViewModel(searchEngine: PreviewSearchEngine.shared))
}

// Preview helper
private enum PreviewSearchEngine {
    @MainActor
    static var shared: SemanticSearchEngine {
        let vectorStore = try! VectorStore()
        return SemanticSearchEngine(vectorStore: vectorStore)
    }
}
