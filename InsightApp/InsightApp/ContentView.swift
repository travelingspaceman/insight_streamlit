import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            SearchView()
                .navigationTitle("📚 Insight")
                .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    ContentView()
}