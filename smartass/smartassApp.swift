//
//  smartassApp.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import SwiftUI

@main
struct smartassApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
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
                
                Button("Latent Space: Enterprise Infrastructure Native") {
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
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .navigationDestination(isPresented: $isArticlePresented) {
            ArticleReaderView(urlString: urlString)
        }
    }
} 
