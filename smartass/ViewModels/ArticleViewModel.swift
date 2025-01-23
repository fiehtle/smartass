import SwiftUI

@MainActor
class ArticleViewModel: ObservableObject {
    @Published private(set) var article: Article?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    func fetchArticle(from urlString: String) async {
        isLoading = true
        error = nil
        
        do {
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { throw URLError(.badServerResponse) }
            
            // Simple HTML parsing using string operations
            let doc = html.lowercased()
            let title = html.firstMatch(of: /<title>(.*?)<\/title>/)?.1 ?? "Untitled"
            let author = html.firstMatch(of: /by\s+(.*?)[<\n]/)?.1
            
            // Remove common nav/header/footer elements
            var content = html
            ["header", "footer", "nav", "script", "style", "noscript"].forEach { tag in
                content = content.replacing(/<\(tag).*?<\/\(tag)>/s, with: "")
            }
            
            // Extract main content (usually in article, main, or div with article-like class)
            if let mainContent = content.firstMatch(of: /<(article|main).*?>(.*?)<\/\1>/s)?.2 ??
                                content.firstMatch(of: /<div[^>]*?(post|article|content).*?>(.*?)<\/div>/s)?.2 {
                content = String(mainContent)
            }
            
            article = Article(
                title: String(title),
                author: author.map(String.init),
                content: content
            )
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
} 