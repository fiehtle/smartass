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
    @Published var article: Article?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let extractor = ContentExtractor()
    private var currentTask: Task<Void, Never>?
    
    func fetchArticle(from url: URL) {
        // Cancel any existing task
        currentTask?.cancel()
        
        isLoading = true
        error = nil
        
        currentTask = Task {
            do {
                article = try await extractor.extract(from: url)
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
