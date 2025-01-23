//
//  smartassApp.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import SwiftUI

@main
struct smartassApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                URLInputView()
            }
        }
    }
}

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
                .font(.title)
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
                    .font(.caption)
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
            
            // Example URLs
            VStack(alignment: .leading, spacing: 10) {
                Text("Try these examples:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Paul Graham: How to Do Great Work") {
                    urlString = "https://paulgraham.com/greatwork.html"
                }
                
                Button("Stripe Press: Working in Public") {
                    urlString = "https://press.stripe.com/working-in-public"
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .navigationDestination(isPresented: $isArticlePresented) {
            ArticleReaderView(urlString: urlString)
        }
    }
} 
