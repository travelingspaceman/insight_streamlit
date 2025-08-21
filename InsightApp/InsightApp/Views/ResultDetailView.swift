import SwiftUI
import SafariServices

struct ResultDetailView: View {
    let result: SearchResult
    @State private var showingSafari = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Main text content
                Text(result.text)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                // Metadata section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source Information")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        metadataRow(label: "Author", value: result.author, icon: "person.fill")
                        metadataRow(label: "Source", value: result.sourceFile, icon: "doc.text")
                        metadataRow(label: "Paragraph", value: "\(result.paragraphId)", icon: "number")
                        metadataRow(label: "Relevance", value: String(format: "%.1f%%", result.score * 100), icon: "chart.bar.fill")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Action buttons
                VStack(spacing: 12) {
                    if result.bahaiLibraryURL != nil {
                        Button(action: {
                            showingSafari = true
                        }) {
                            HStack {
                                Image(systemName: "book.fill")
                                Text("Open in Bahá'í Library")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    Button(action: {
                        shareResult()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Passage")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("Result Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSafari) {
            if let url = result.bahaiLibraryURL {
                SafariView(url: url)
            }
        }
    }
    
    private func metadataRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label + ":")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func shareResult() {
        let shareText = """
        "\(result.text)"
        
        — \(result.author)
        Source: \(result.sourceFile), Paragraph \(result.paragraphId)
        
        Found using Insight - Bahá'í Writings Search
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Handle iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    NavigationView {
        ResultDetailView(result: SearchResult(
            text: "O Son of Spirit! My first counsel is this: Possess a pure, kindly and radiant heart, that thine may be a sovereignty ancient, imperishable and everlasting.",
            sourceFile: "hidden-words.docx",
            paragraphId: 1,
            score: 0.89,
            author: "Bahá'u'lláh"
        ))
    }
}
