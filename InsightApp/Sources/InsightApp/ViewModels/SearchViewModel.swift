import Foundation
import SwiftUI
import Observation

/// Search mode matching the original Streamlit app
public enum SearchMode: String, CaseIterable, Identifiable, Sendable {
    case quote = "Find a Quote"
    case journal = "Journal Entry"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .quote: return "magnifyingglass"
        case .journal: return "note.text"
        }
    }

    public var placeholder: String {
        switch self {
        case .quote:
            return "e.g., spiritual development, unity of mankind, prayer..."
        case .journal:
            return "e.g., I'm struggling with patience today, or I feel grateful for..."
        }
    }
}

/// Observable view model for the search interface
@MainActor
@Observable
public final class SearchViewModel {
    // MARK: - Published Properties

    public var searchText: String = ""
    public var searchMode: SearchMode = .quote
    public var selectedAuthors: Set<Author> = []
    public var resultCount: Int = 10
    public var results: [ParagraphResult] = []
    public var isLoading: Bool = false
    public var errorMessage: String?
    public var showError: Bool = false

    // MARK: - Private Properties

    private let searchEngine: SemanticSearchEngine

    // MARK: - Computed Properties

    public var isSearchDisabled: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }

    public var authorFilter: Set<Author>? {
        selectedAuthors.isEmpty ? nil : selectedAuthors
    }

    // MARK: - Initialization

    public init(searchEngine: SemanticSearchEngine) {
        self.searchEngine = searchEngine
    }

    // MARK: - Actions

    /// Perform a search with the current query and filters
    public func search() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil
        results = []

        do {
            let query: String
            switch searchMode {
            case .quote:
                query = searchText
            case .journal:
                // For journal mode, we use the text directly
                // In the original app, GPT-4o-mini was used to process the entry
                // For the iOS app, we search directly with the journal text
                query = searchText
            }

            results = try await searchEngine.search(
                query: query,
                limit: resultCount,
                authorFilter: authorFilter
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    /// Clear the current search
    public func clearSearch() {
        searchText = ""
        results = []
        errorMessage = nil
    }

    /// Reset all filters to defaults
    public func resetFilters() {
        selectedAuthors = []
        resultCount = 10
    }

    /// Toggle selection of an author
    public func toggleAuthor(_ author: Author) {
        if selectedAuthors.contains(author) {
            selectedAuthors.remove(author)
        } else {
            selectedAuthors.insert(author)
        }
    }

    /// Select all authors
    public func selectAllAuthors() {
        selectedAuthors = Set(Author.allCases)
    }

    /// Deselect all authors (show all)
    public func deselectAllAuthors() {
        selectedAuthors = []
    }
}
