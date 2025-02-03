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
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("https://...", text: $viewModel.urlString)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: viewModel.urlString) { _, _ in
                            viewModel.showError = false
                        }
                    
                    if viewModel.showError {
                        Text("Please enter a valid URL starting with http:// or https://")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button("Read Article") {
                        viewModel.validateAndPresentArticle()
                    }
                    .disabled(viewModel.urlString.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Add New Article")
            }
            
            Section {
                ForEach(savedArticles) { article in
                    NavigationLink(destination: ArticleReaderView(urlString: article.url ?? "")) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title ?? "Untitled")
                                .font(.headline)
                            
                            if let author = article.author {
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let url = article.url {
                                Text(formatSource(url))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Saved Articles")
            }
        }
        .navigationTitle("SmartAss")
        .navigationDestination(isPresented: $viewModel.isArticlePresented) {
            ArticleReaderView(urlString: viewModel.urlString)
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