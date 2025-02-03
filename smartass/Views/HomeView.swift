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
        List {
            ForEach(savedArticles) { article in
                NavigationLink(destination: SavedArticleView(article: article)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title ?? "Untitled")
                            .font(.body)
                        
                        HStack {
                            if let author = article.author {
                                Text(author)
                            }
                            if let url = article.url {
                                if article.author != nil {
                                    Text("•")
                                }
                                Text(formatSource(url))
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .onDelete(perform: deleteArticles)
        }
        .navigationTitle("Articles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showAddArticle = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddArticle) {
            NavigationStack {
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
    
    private func deleteArticles(at offsets: IndexSet) {
        withAnimation {
            offsets.map { savedArticles[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
} 
