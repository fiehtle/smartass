//
//  ArticleContentViewModel.swift
//  smartass
//
//  Created by Viet Le on 1/27/25.
//


import SwiftUI
import CoreData

@MainActor
class ArticleContentViewModel: ObservableObject {
    private let article: DisplayArticle
    private let openAIService: OpenAIService
    private let persistenceController: PersistenceController
    
    @Published var storedArticle: StoredArticle?
    @Published var showSmartContextSidebar = false
    @Published var isGeneratingContext = false
    
    init(article: DisplayArticle,
         openAIService: OpenAIService = .shared,
         persistenceController: PersistenceController = .shared) {
        self.article = article
        self.openAIService = openAIService
        self.persistenceController = persistenceController
        
        print("🏗️ Initializing ArticleContentViewModel")
        // Try to find existing stored article and generate initial context
        Task {
            do {
                storedArticle = try await getOrCreateStoredArticle()
                print("📝 Found/Created stored article:", storedArticle?.title ?? "nil")
                
                // Generate initial context immediately if it doesn't exist
                if let storedArticle = storedArticle, storedArticle.initialAIContext == nil {
                    print("🤖 Generating initial article context on load...")
                    let initialContext = try await openAIService.generateInitialContext(for: article)
                    try persistenceController.updateArticleInitialContext(storedArticle, context: initialContext)
                    print("✅ Initial context saved:", initialContext.prefix(100))
                } else if let context = storedArticle?.initialAIContext {
                    print("📚 Existing initial context:", context.prefix(100))
                }
            } catch {
                print("❌ Error loading stored article:", error.localizedDescription)
            }
        }
    }
    
    func generateSmartContext(for selectedText: String) async {
        guard !isGeneratingContext else { return }
        print("🎯 Starting smart context generation for text:", selectedText.prefix(50))
        isGeneratingContext = true
        
        do {
            // Get or create stored article if not already loaded
            if storedArticle == nil {
                print("📝 No stored article found, creating one...")
                storedArticle = try await getOrCreateStoredArticle()
            }
            
            guard let storedArticle = storedArticle else {
                print("❌ Failed to get or create stored article")
                isGeneratingContext = false
                return
            }
            
            // Create highlight first
            print("✨ Creating highlight...")
            let highlight = try persistenceController.saveHighlight(
                article: storedArticle,
                selectedText: selectedText,
                textRange: Data() // TODO: Implement text range storage
            )
            print("✅ Highlight created")
            
            // Show sidebar immediately
            print("📱 Showing sidebar...")
            withAnimation {
                showSmartContextSidebar = true
            }
            
            // Generate initial context if it doesn't exist
            if storedArticle.initialAIContext == nil {
                print("🤖 Generating initial article context...")
                let initialContext = try await openAIService.generateInitialContext(for: article)
                try persistenceController.updateArticleInitialContext(storedArticle, context: initialContext)
                print("✅ Initial context saved")
            }
            
            // Generate smart context
            print("🤖 Generating smart context...")
            let smartContext = try await openAIService.generateSmartContext(
                highlight: highlight,
                articleContent: article.textContent
            )
            
            // Save smart context
            print("💾 Saving smart context...")
            try persistenceController.saveSmartContext(
                highlight: highlight,
                content: smartContext
            )
            print("✅ Smart context saved")
            
        } catch {
            print("❌ Error generating smart context:", error.localizedDescription)
        }
        
        isGeneratingContext = false
        print("✅ Smart context generation complete")
    }
    
    private func getOrCreateStoredArticle() async throws -> StoredArticle {
        // Try to find existing article by URL
        let fetchRequest: NSFetchRequest<StoredArticle> = StoredArticle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@ AND content == %@", article.title, article.textContent)
        
        if let existingArticle = try persistenceController.container.viewContext.fetch(fetchRequest).first {
            print("📝 Found existing article:", existingArticle.title ?? "nil")
            return existingArticle
        }
        
        print("📝 Creating new article...")
        // Create new article if not found
        return try persistenceController.saveArticle(
            url: "placeholder-url", // TODO: Add URL to DisplayArticle
            title: article.title,
            author: article.author,
            content: article.textContent,
            estimatedReadingTime: article.estimatedReadingTime
        )
    }
} 
