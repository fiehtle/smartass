import SwiftUI

struct ArticleReaderView: View {
    @StateObject private var viewModel = ArticleViewModel()
    let urlString: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                } else if let article = viewModel.article {
                    // Title
                    Text(article.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Author
                    if let author = article.author {
                        Text("By \(author)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Reading time
                    if let readingTime = article.estimatedReadingTime {
                        Text("\(Int(readingTime / 60)) min read")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Content
                    ArticleContentView(article: article)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let url = URL(string: urlString) else { return }
            viewModel.fetchArticle(from: url)
        }
    }
}

#Preview {
    NavigationStack {
        ArticleReaderView(urlString: "https://www.latent.space/p/enterprise")
    }
} 
