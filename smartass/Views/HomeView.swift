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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(savedArticles) { article in
                    NavigationLink(destination: SavedArticleView(article: article)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title ?? "Untitled")
                                .font(.smartAssFont(SmartAssDesign.Typography.headline))
                                .foregroundColor(.primary)
                            
                            Text(formatSource(article.url ?? ""))
                                .font(.smartAssFont(SmartAssDesign.Typography.footnote))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationTitle("Articles")
        .navigationBarTitleDisplayMode(.large)
        .background(Color.surface)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.showAddArticle = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Color.accent)
                        .font(.system(size: 17, weight: .semibold))
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
} 
