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
                    .font(.smartAssFont(SmartAssDesign.Typography.body))
            } header: {
                Text("Article URL")
                    .font(.smartAssFont(SmartAssDesign.Typography.footnote))
            } footer: {
                if viewModel.showError {
                    Text("Please enter a valid URL starting with http:// or https://")
                        .foregroundColor(.red)
                        .font(.smartAssFont(SmartAssDesign.Typography.caption))
                }
            }
            
            Section {
                Button("Add Article") {
                    viewModel.validateAndPresentArticle()
                }
                .frame(maxWidth: .infinity)
                .disabled(viewModel.urlString.isEmpty)
                .tint(Color.accent)
                .font(.smartAssFont(SmartAssDesign.Typography.body))
            }
            
            Section {
                Text("Try these examples:")
                    .foregroundColor(.secondary)
                    .font(.smartAssFont(SmartAssDesign.Typography.footnote))
                    .listRowBackground(Color.clear)
                
                Button("Latent Space: Enterprise Infrastructure") {
                    viewModel.urlString = "https://www.latent.space/p/enterprise"
                }
                .tint(Color.accent)
                .font(.smartAssFont(SmartAssDesign.Typography.body))
                
                Button("Paul Graham: The Origins of Wokeness") {
                    viewModel.urlString = "https://paulgraham.com/woke.html"
                }
                .tint(Color.accent)
                .font(.smartAssFont(SmartAssDesign.Typography.body))
                
                Button("Stripe Press: Poor Charlie's Almanack") {
                    viewModel.urlString = "https://www.stripe.press/poor-charlies-almanack/talk-five"
                }
                .tint(Color.accent)
                .font(.smartAssFont(SmartAssDesign.Typography.body))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Add Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
                .tint(Color.accent)
                .font(.smartAssFont(SmartAssDesign.Typography.body))
            }
        }
        .navigationDestination(isPresented: $viewModel.isArticlePresented) {
            ArticleReaderView(urlString: viewModel.urlString)
        }
    }
} 
