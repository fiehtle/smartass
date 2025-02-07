//
//  URLInputView.swift
//  smartass
//
//  Created by Viet Le on 2/6/25.
//


import SwiftUI

struct URLInputView: View {
    @State private var urlString = ""
    @State private var isArticlePresented = false
    @State private var showError = false
    
    var isValidURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Article URL")
                .font(.custom("Helvetica Neue", size: 28))
                .fontWeight(.bold)
            
            TextField("https://...", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(.horizontal)
                .onChange(of: urlString) { _, _ in
                    showError = false
                }
            
            if showError {
                Text("Please enter a valid URL starting with http:// or https://")
                    .foregroundColor(.red)
                    .font(.custom("Helvetica Neue", size: 12))
            }
            
            Button("Read Article") {
                if isValidURL {
                    isArticlePresented = true
                } else {
                    showError = true
                }
            }
            .disabled(urlString.isEmpty)
            .buttonStyle(.borderedProminent)
            .tint(Color.accent)
            
            // Example URLs
            VStack(alignment: .leading, spacing: 10) {
                Text("Try these examples:")
                    .font(.custom("Helvetica Neue", size: 13))
                    .foregroundColor(.secondary)
                
                Button("Latent Space: Enterprise Infrastructure") {
                    urlString = "https://www.latent.space/p/enterprise"
                }
                
                Button("Paul Graham: The Origins of Wokeness") {
                    urlString = "https://paulgraham.com/woke.html"
                }
                
                Button("Stripe Press: Poor Charlie's Almanack") {
                    urlString = "https://www.stripe.press/poor-charlies-almanack/talk-five"
                }
            }
            .buttonStyle(.plain)
            .font(.custom("Helvetica Neue", size: 13))
            .foregroundColor(Color.accent)
        }
        .padding()
        .navigationDestination(isPresented: $isArticlePresented) {
            ArticleReaderView(urlString: urlString)
        }
    }
} 