//
//  ArticleStorageService.swift
//  smartass
//
//  Created by Viet Le on 1/27/25.
//


import CoreData
import Foundation

actor ArticleStorageService {
    static let shared = ArticleStorageService()
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }
    
    func getOrCreateArticle(from displayArticle: DisplayArticle) async throws -> StoredArticle {
        // Check if article already exists
        let fetchRequest: NSFetchRequest<StoredArticle> = StoredArticle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@ AND content == %@", 
            displayArticle.title, displayArticle.textContent)
        
        if let existingArticle = try viewContext.fetch(fetchRequest).first {
            return existingArticle
        }
        
        // Create new article if not found
        let stored = StoredArticle(context: viewContext)
        stored.id = UUID()
        stored.title = displayArticle.title
        stored.content = displayArticle.textContent
        stored.author = displayArticle.author
        stored.estimatedReadingTime = displayArticle.estimatedReadingTime ?? 0
        stored.url = "temp_url"  // Required field
        
        try viewContext.save()
        return stored
    }
    
    func createHighlight(text: String, for article: StoredArticle) async throws -> Highlight {
        let highlight = Highlight(context: viewContext)
        highlight.id = UUID()
        highlight.selectedText = text
        highlight.createdAt = Date()
        highlight.article = article
        highlight.textRange = Data() // Required field
        
        try viewContext.save()
        return highlight
    }
    
    func createSmartContext(content: String, for highlight: Highlight) async throws -> SmartContext {
        let smartContext = SmartContext(context: viewContext)
        smartContext.id = UUID()
        smartContext.content = content
        smartContext.createdAt = Date()
        smartContext.highlight = highlight
        
        try viewContext.save()
        return smartContext
    }
    
    func deleteHighlight(_ highlight: Highlight) async throws {
        viewContext.delete(highlight)
        try viewContext.save()
    }
    
    func updateArticleContext(_ article: StoredArticle, context: String) async throws {
        article.initialAIContext = context
        try viewContext.save()
    }
} 