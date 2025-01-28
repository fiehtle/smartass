import Foundation
import CoreData

@MainActor
class ArticleContentViewModel: ObservableObject {
    private let article: DisplayArticle
    private let openAIService: OpenAIService
    private let storageService: ArticleStorageService
    
    @Published var storedArticle: StoredArticle?
    @Published var showSmartContextSidebar = false
    @Published var isGeneratingContext = false
    
    init(
        article: DisplayArticle,
        openAIService: OpenAIService = .shared,
        storageService: ArticleStorageService = .shared
    ) {
        self.article = article
        self.openAIService = openAIService
        self.storageService = storageService
    }
    
    func generateSmartContext(for text: String) async {
        guard !isGeneratingContext else { return }
        
        isGeneratingContext = true
        print("🤖 Generating context with OpenAI...")
        print("📝 Selected text:", text)
        
        do {
            // Get or create stored article
            let article = try await storageService.getOrCreateArticle(from: self.article)
            storedArticle = article
            
            // Generate initial context if needed
            if article.initialAIContext == nil {
                print("🔄 Generating initial article context...")
                let initialContext = try await openAIService.generateInitialContext(for: self.article)
                try await storageService.updateArticleContext(article, context: initialContext)
                print("✅ Initial context generated:", initialContext)
            }
            
            // Create highlight
            let highlight = try await storageService.createHighlight(text: text, for: article)
            
            // Generate and save smart context
            let context = try await openAIService.generateSmartContext(
                highlight: highlight,
                articleContent: self.article.textContent
            )
            
            try await storageService.createSmartContext(content: context, for: highlight)
            print("✅ Context generated:", context)
            
            // Show sidebar if not already shown
            withAnimation {
                showSmartContextSidebar = true
            }
        } catch {
            print("❌ Error generating context:", error.localizedDescription)
        }
        
        isGeneratingContext = false
    }
} 