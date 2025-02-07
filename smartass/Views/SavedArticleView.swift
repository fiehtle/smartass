//
//  SavedArticleView.swift
//  smartass
//
//  Created by Viet Le on 2/3/25.
//


import SwiftUI
import CoreData

struct SavedArticleView: View {
    let article: StoredArticle
    @StateObject private var viewModel: ArticleContentViewModel
    
    init(article: StoredArticle) {
        self.article = article
        // Create a DisplayArticle from StoredArticle
        let displayArticle = DisplayArticle(
            title: article.title ?? "",
            author: article.author,
            content: [
                DisplayArticle.ContentBlock(
                    type: .paragraph,
                    content: article.content ?? ""
                )
            ],
            estimatedReadingTime: article.estimatedReadingTime
        )
        self._viewModel = StateObject(wrappedValue: ArticleContentViewModel(article: displayArticle))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(article.title ?? "")
                    .font(SmartAssDesign.Typography.titleLarge)
                    .fontWeight(.bold)
                
                // Author/Source
                if let author = article.author {
                    Text(author)
                        .font(SmartAssDesign.Typography.footnote)
                        .foregroundColor(.secondary)
                }
                
                // Reading time
                if article.estimatedReadingTime > 0 {
                    Text("\(Int(article.estimatedReadingTime / 60)) min read")
                        .font(SmartAssDesign.Typography.footnote)
                        .foregroundColor(.secondary)
                }
                
                // Content
                ArticleContentView(article: DisplayArticle(
                    title: article.title ?? "",
                    author: article.author,
                    content: [
                        DisplayArticle.ContentBlock(
                            type: .paragraph,
                            content: article.content ?? ""
                        )
                    ],
                    estimatedReadingTime: article.estimatedReadingTime
                ))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(SmartAssDesign.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .tint(SmartAssDesign.Colors.accent)
    }
} 
