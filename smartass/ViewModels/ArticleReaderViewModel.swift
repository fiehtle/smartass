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
    
    private let articleService = ArticleService()
    
    func fetchArticle(from url: String) async {
        print("🎯 ViewModel: Starting fetch for URL: \(url)")
        isLoading = true
        error = nil
        
        do {
            article = try await articleService.fetchArticle(from: url)
            print("✅ ViewModel: Article fetched successfully")
        } catch {
            print("❌ ViewModel: Error fetching article: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
} 
