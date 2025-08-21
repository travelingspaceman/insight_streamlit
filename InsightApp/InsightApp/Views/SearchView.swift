import SwiftUI

struct SearchView: View {
    @StateObject private var openAIService = OpenAIService(apiKey: "your_openai_api_key_here")
    @StateObject private var pineconeService = PineconeService(apiKey: "your_pinecone_api_key_here")
    
    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedMode: SearchMode = .quote
    @State private var selectedAuthors: [Author] = [.all]
    @State private var numberOfResults = 10
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showingAuthorFilter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            VStack(alignment: .leading, spacing: 16) {
                searchModeToggle
                searchModeDescription
                searchInputSection
                searchButton
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Results Section
            if isSearching {
                Spacer()
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchResults.isEmpty {
                resultsListView
            } else if !searchText.isEmpty && !isSearching {
                Spacer()
                Text("No results found. Try a different search query.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Search through the Bahá'í Writings\nusing semantic similarity")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Filters") {
                    showingAuthorFilter = true
                }
            }
        }
        .sheet(isPresented: $showingAuthorFilter) {
            filterSheet
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var searchModeToggle: some View {
        HStack(spacing: 12) {
            ForEach(SearchMode.allCases, id: \.self) { mode in
                Button(mode.displayName) {
                    selectedMode = mode
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(selectedMode == mode ? .blue : .gray)
            }
        }
    }
    
    private var searchModeDescription: some View {
        Text(selectedMode.description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var searchInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Input")
                .font(.headline)
            
            TextEditor(text: $searchText)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if searchText.isEmpty {
                        Text(selectedMode.placeholder)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    private var searchButton: some View {
        Button("🔍 Search") {
            Task {
                await performSearch()
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
    }
    
    private var resultsListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Search Results (\(searchResults.count) found)")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                Spacer()
            }
            
            List(searchResults) { result in
                NavigationLink(destination: ResultDetailView(result: result)) {
                    SearchResultRow(result: result)
                }
            }
        }
    }
    
    private var filterSheet: some View {
        NavigationView {
            Form {
                Section("Author Filter") {
                    ForEach(Author.allCases, id: \.self) { author in
                        HStack {
                            Text(author.displayName)
                            Spacer()
                            if selectedAuthors.contains(author) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleAuthor(author)
                        }
                    }
                }
                
                Section("Number of Results") {
                    Stepper("\(numberOfResults) results", value: $numberOfResults, in: 1...20)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAuthorFilter = false
                    }
                }
            }
        }
    }
    
    private func toggleAuthor(_ author: Author) {
        if author == .all {
            selectedAuthors = [.all]
        } else {
            if selectedAuthors.contains(.all) {
                selectedAuthors = [author]
            } else if selectedAuthors.contains(author) {
                selectedAuthors.removeAll { $0 == author }
                if selectedAuthors.isEmpty {
                    selectedAuthors = [.all]
                }
            } else {
                selectedAuthors.append(author)
            }
        }
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            let queryText: String
            
            if selectedMode == .journal {
                queryText = try await openAIService.processJournalEntry(searchText)
            } else {
                queryText = searchText
            }
            
            let embedding = try await openAIService.generateEmbedding(for: queryText)
            let authorFilter = selectedAuthors.contains(.all) ? nil : selectedAuthors
            let results = try await pineconeService.search(
                queryVector: embedding,
                topK: numberOfResults,
                authorFilter: authorFilter
            )
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSearching = false
            }
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.text)
                .lineLimit(3)
                .font(.body)
            
            HStack {
                Label(result.sourceFile, systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Para \(result.paragraphId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        SearchView()
            .navigationTitle("📚 Insight")
    }
}