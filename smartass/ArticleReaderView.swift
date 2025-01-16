//
//  ArticleReaderView.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import SwiftUI

struct ArticleReaderView: View {
    let articleURL: String
    @StateObject private var viewModel = ArticleReaderViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load article")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let article = viewModel.article {
                VStack(alignment: .leading, spacing: 16) {
                    if let siteName = article.siteName {
                        Text(siteName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let author = article.author {
                        Text("By \(author)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let readingTime = article.estimatedReadingTime {
                        Text("\(readingTime) min read")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Use the full content instead of excerpt
                    Text(article.textContent)
                        .font(.body)
                        .lineSpacing(8)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // Add sharing functionality later
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await viewModel.fetchArticle(from: articleURL)
        }
    }
}

#Preview {
    NavigationStack {
        ArticleReaderView(articleURL: "https://example.com")
    }
} 
