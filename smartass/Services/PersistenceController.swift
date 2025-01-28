import CoreData

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
    
    func saveArticle(url: String, title: String, author: String?, content: String, estimatedReadingTime: Double?) throws -> Article {
        let context = container.viewContext
        
        // Check if article already exists
        let fetchRequest: NSFetchRequest<Article> = Article.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "url == %@", url)
        
        if let existingArticle = try context.fetch(fetchRequest).first {
            return existingArticle
        }
        
        let article = Article(context: context)
        article.id = UUID()
        article.url = url
        article.title = title
        article.author = author
        article.content = content
        article.estimatedReadingTime = estimatedReadingTime ?? 0
        
        try context.save()
        return article
    }
    
    func updateArticleInitialContext(_ article: Article, context: String) throws {
        article.initialAIContext = context
        try container.viewContext.save()
    }
    
    // MARK: - Highlight Operations
    
    func saveHighlight(article: Article, selectedText: String, textRange: Data) throws -> Highlight {
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
    
    func saveSmartContext(highlight: Highlight, content: String) throws -> SmartContext {
        let context = container.viewContext
        
        let smartContext = SmartContext(context: context)
        smartContext.id = UUID()
        smartContext.content = content
        smartContext.createdAt = Date()
        smartContext.highlight = highlight
        
        try context.save()
        return smartContext
    }
    
    func deleteSmartContext(_ smartContext: SmartContext) throws {
        let context = container.viewContext
        context.delete(smartContext)
        try context.save()
    }
} 