//
//  ArticleViewModel.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import Foundation
import SwiftUI

@MainActor
class ArticleViewModel: ObservableObject {
    @Published var article: DisplayArticle?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let extractor = ContentExtractor()
    private let openAIService = OpenAIService.shared
    private let persistenceController = PersistenceController.shared
    private var currentTask: Task<Void, Never>?
    
    func fetchArticle(from url: URL) {
        // Cancel any existing task
        currentTask?.cancel()
        
        isLoading = true
        error = nil
        
        currentTask = Task {
            do {
                // Extract article content
                let article = try await extractor.extract(from: url)
                self.article = article
                
                // Save article and generate initial context in the background
                Task {
                    do {
                        let storedArticle = try await persistenceController.saveArticle(
                            url: url.absoluteString,
                            title: article.title,
                            author: article.author,
                            content: article.textContent,
                            estimatedReadingTime: article.estimatedReadingTime
                        )
                        
                        // Generate initial context if it doesn't exist
                        if storedArticle.initialAIContext == nil {
                            let initialContext = try await openAIService.generateInitialContext(for: article)
                            try persistenceController.updateArticleInitialContext(storedArticle, context: initialContext)
                        }
                    } catch {
                        print("❌ Background processing error:", error.localizedDescription)
                    }
                }
            } catch {
                self.error = error
            }
            isLoading = false
        }
    }
    
    deinit {
        currentTask?.cancel()
    }
} 
