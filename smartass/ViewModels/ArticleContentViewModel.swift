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
    private let perplexityService: PerplexityService
    private let persistenceController: PersistenceController
    
    @Published var storedArticle: StoredArticle?
    @Published var showSmartContextSheet = false
    @Published var isGeneratingContext = false
    @Published var currentHighlight: (text: String, explanation: String?, citations: [PerplexityService.Citation]?)?
    
    init(article: DisplayArticle,
         perplexityService: PerplexityService = .shared,
         persistenceController: PersistenceController = .shared) {
        self.article = article
        self.perplexityService = perplexityService
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
                    let (initialContext, citations) = try await perplexityService.generateInitialContext(for: article)
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
        
        // Show sheet immediately with loading state
        currentHighlight = (text: selectedText, explanation: nil, citations: nil)
        showSmartContextSheet = true
        
        do {
            // Get or create stored article if not already loaded
            if storedArticle == nil {
                print("📝 No stored article found, creating one...")
                storedArticle = try await getOrCreateStoredArticle()
            }
            
            guard let storedArticle = storedArticle else {
                print("❌ Failed to get or create stored article")
                isGeneratingContext = false
                // Don't dismiss sheet, just show error state
                currentHighlight = (text: selectedText, explanation: "Failed to load article", citations: nil)
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
            
            // Generate initial context if it doesn't exist
            if storedArticle.initialAIContext == nil {
                print("🤖 Generating initial article context...")
                let (initialContext, _) = try await perplexityService.generateInitialContext(for: article)
                try persistenceController.updateArticleInitialContext(storedArticle, context: initialContext)
                print("✅ Initial context saved")
            }
            
            // Generate smart context
            print("🤖 Generating smart context...")
            let (smartContext, citations) = try await perplexityService.generateSmartContext(
                highlight: highlight,
                articleContent: article.textContent
            )
            
            // Save smart context with citations
            print("💾 Saving smart context...")
            try persistenceController.saveSmartContext(
                highlight: highlight,
                content: smartContext,
                citations: citations
            )
            print("✅ Smart context saved")
            
            // Update the current highlight with the explanation and citations
            currentHighlight = (text: selectedText, explanation: smartContext, citations: citations)
            
        } catch {
            print("❌ Error generating smart context:", error.localizedDescription)
            // Don't dismiss sheet, show error message instead
            currentHighlight = (text: selectedText, explanation: "Error: \(error.localizedDescription)", citations: nil)
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
