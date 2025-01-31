//
//  PersistenceController.swift
//  smartass
//
//  Created by Viet Le on 1/24/25.
//


import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SmartAssDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Article Operations
    
    func saveArticle(url: String, title: String, author: String?, content: String, estimatedReadingTime: Double?) throws -> StoredArticle {
        let context = container.viewContext
        
        // Check if article already exists
        let fetchRequest: NSFetchRequest<StoredArticle> = StoredArticle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "url == %@", url)
        
        if let existingArticle = try context.fetch(fetchRequest).first {
            return existingArticle
        }
        
        let article = StoredArticle(context: context)
        article.id = UUID()
        article.url = url
        article.title = title
        article.author = author
        article.content = content
        article.estimatedReadingTime = estimatedReadingTime ?? 0
        
        try context.save()
        return article
    }
    
    func updateArticleInitialContext(_ article: StoredArticle, context: String) throws {
        article.initialAIContext = context
        try container.viewContext.save()
    }
    
    // MARK: - Highlight Operations
    
    func saveHighlight(article: StoredArticle, selectedText: String, textRange: Data) throws -> Highlight {
        let context = container.viewContext
        
        let highlight = Highlight(context: context)
        highlight.id = UUID()
        highlight.selectedText = selectedText
        highlight.textRange = textRange
        highlight.createdAt = Date()
        highlight.article = article
        
        try context.save()
        return highlight
    }
    
    func deleteHighlight(_ highlight: Highlight) throws {
        let context = container.viewContext
        context.delete(highlight)
        try context.save()
    }
    
    // MARK: - Smart Context Operations
    
    func saveSmartContext(highlight: Highlight, content: String, citations: [PerplexityService.Citation]? = nil) throws -> SmartContext {
        let context = container.viewContext
        
        let smartContext = SmartContext(context: context)
        smartContext.id = UUID()
        smartContext.content = content
        smartContext.createdAt = Date()
        smartContext.highlight = highlight
        
        // Save citations if provided
        if let citations = citations {
            for citationUrl in citations {
                let citation = Citation(context: context)
                citation.id = UUID()
                citation.url = citationUrl
                citation.text = citationUrl // For backward compatibility, we store the URL as text too
                citation.smartContext = smartContext
            }
        }
        
        try context.save()
        return smartContext
    }
    
    func deleteSmartContext(_ smartContext: SmartContext) throws {
        let context = container.viewContext
        context.delete(smartContext)
        try context.save()
    }
} 
