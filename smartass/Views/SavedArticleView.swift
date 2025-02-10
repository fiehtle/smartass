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
        _viewModel = StateObject(wrappedValue: ArticleContentViewModel(article: displayArticle))
    }
    
    var body: some View {
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
        .navigationBarTitleDisplayMode(.inline)
    }
} 
