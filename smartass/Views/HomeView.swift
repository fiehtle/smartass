//
//  HomeView.swift
//  smartass
//
//  Created by Viet Le on 2/3/25.
//


import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StoredArticle.id, ascending: false)],
        animation: .default)
    private var savedArticles: FetchedResults<StoredArticle>
    
    var body: some View {
        NavigationStack {
            List(savedArticles) { article in
                NavigationLink(destination: SavedArticleView(article: article)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title ?? "Untitled")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let url = article.url {
                            Text(formatSource(url))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Articles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showAddArticle.toggle() }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddArticle) {
                AddArticleView(isPresented: $viewModel.showAddArticle)
            }
        }
    }
    
    private func formatSource(_ url: String) -> String {
        guard let url = URL(string: url),
              let host = url.host?.replacingOccurrences(of: "www.", with: "") else {
            return url
        }
        return host
    }
}

private struct ArticleList: View {
    let savedArticles: FetchedResults<StoredArticle>
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(savedArticles) { article in
                    ArticleRow(article: article)
                }
            }
            .padding()
        }
    }
}

private struct ArticleRow: View {
    let article: StoredArticle
    
    var body: some View {
        NavigationLink(destination: SavedArticleView(article: article)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title ?? "Untitled")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let url = article.url {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
} 
