
import SwiftUI

struct ArticleReaderView: View {
    @StateObject private var viewModel = ArticleViewModel()
    let urlString: String
    
    private func formatSource(_ url: String) -> String {
        guard let url = URL(string: url),
              let host = url.host?.replacingOccurrences(of: "www.", with: "") else {
            return url
        }
        return host
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let error = viewModel.error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                } else if let article = viewModel.article {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        Text(article.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Author/Source
                        if let author = article.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(formatSource(urlString))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Reading time
                        if let readingTime = article.estimatedReadingTime {
                            Text("\(Int(readingTime / 60)) min read")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Content
                        ArticleContentView(article: article)
                            .onAppear {
                                print("📄 Article content loaded")
                            }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            print("🔄 Loading article from URL:", urlString)
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL:", urlString)
                return
            }
            viewModel.fetchArticle(from: url)
        }
    }
}

#Preview {
    NavigationStack {
        ArticleReaderView(urlString: "https://www.latent.space/p/enterprise")
    }
} 
