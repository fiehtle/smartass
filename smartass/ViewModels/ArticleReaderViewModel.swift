//
//  ArticleReaderViewModel.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import Foundation

@MainActor
class ArticleReaderViewModel: ObservableObject {
    @Published private(set) var article: Article?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var articleService: ArticleService?
    private var serviceTask: Task<Void, Never>?
    
    init() {
        print("🔄 ViewModel: Initializing...")
        setupService()
    }
    
    private func setupService() {
        serviceTask = Task {
            print("🔄 ViewModel: Setting up service...")
            articleService = await ArticleService()
            print("✅ ViewModel: Service ready")
        }
    }
    
    func fetchArticle(from url: String) {
        Task {
            print("🎯 ViewModel: Waiting for service...")
            // Wait for service to be ready
            await serviceTask?.value
            
            guard let service = articleService else {
                print("❌ ViewModel: Service initialization failed")
                return
            }
            
            print("🎯 ViewModel: Starting fetch for URL: \(url)")
            isLoading = true
            error = nil
            
            do {
                article = try await service.fetchArticle(from: url)
                print("✅ ViewModel: Article fetched successfully")
            } catch {
                print("❌ ViewModel: Error fetching article: \(error)")
                self.error = error
            }
            
            isLoading = false
        }
    }
} 
