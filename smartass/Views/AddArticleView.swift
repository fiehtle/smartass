//
//  AddArticleView.swift
//  smartass
//
//  Created by Viet Le on 2/3/25.
//


import SwiftUI

struct AddArticleView: View {
    @StateObject private var viewModel = HomeViewModel()
    @Binding var isPresented: Bool
    
    var body: some View {
        Form {
            Section {
                TextField("https://...", text: $viewModel.urlString)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } header: {
                Text("Article URL")
            } footer: {
                if viewModel.showError {
                    Text("Please enter a valid URL starting with http:// or https://")
                        .foregroundColor(.red)
                }
            }
            
            Section {
                Button("Add Article") {
                    viewModel.validateAndPresentArticle()
                }
                .frame(maxWidth: .infinity)
                .disabled(viewModel.urlString.isEmpty)
            }
            
            Section {
                Text("Try these examples:")
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
                
                Button("Latent Space: Enterprise Infrastructure") {
                    viewModel.urlString = "https://www.latent.space/p/enterprise"
                }
                
                Button("Paul Graham: The Origins of Wokeness") {
                    viewModel.urlString = "https://paulgraham.com/woke.html"
                }
                
                Button("Stripe Press: Poor Charlie's Almanack") {
                    viewModel.urlString = "https://www.stripe.press/poor-charlies-almanack/talk-five"
                }
            }
        }
        .navigationTitle("Add Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .navigationDestination(isPresented: $viewModel.isArticlePresented) {
            ArticleReaderView(urlString: viewModel.urlString)
        }
    }
} 