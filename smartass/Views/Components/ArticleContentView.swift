//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import SwiftUI

struct ArticleContentView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show title only once at the top
            Text(article.title)
                .font(.title2)
                .fontWeight(.bold)
            
            // Show author if available
            if let author = article.author {
                Text(author)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Content blocks
            ForEach(article.content, id: \.content) { block in
                if !isPromotionalContent(block.content) && !isDuplicate(block) {
                    switch block.type {
                    case .heading:
                        // Skip headings that match the title
                        if block.content != article.title {
                            Text(block.content)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    case .paragraph, .list, .quote, .code, .image:
                        Text(block.content)
                            .font(.body)
                    }
                }
            }
        }
    }
    
    private func isPromotionalContent(_ content: String) -> Bool {
        let promotionalPhrases = [
            "Share this post",
            "Subscribe",
            "Copy link",
            "Facebook",
            "Email",
            "Notes",
            "More",
            "Share",
            "Previous",
            "Next",
            "Discussion about this post",
            "Comments",
            "Restacks",
            "Ready for more?",
            "© 2025",
            "Privacy",
            "Terms",
            "Collection notice",
            "Start Writing",
            "Get the app",
            "Substack",
            "min read",
            "Discover more from",
            "Continue reading",
            "Sign in",
            "subscribers",
            "newsletter",
            "podcast",
            "highlights from"
        ]
        
        return promotionalPhrases.contains { phrase in
            content.localizedCaseInsensitiveContains(phrase)
        }
    }
    
    private func isDuplicate(_ block: Article.ContentBlock) -> Bool {
        // Check if this block's content appears elsewhere in the article
        let content = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return article.content.filter { otherBlock in
            otherBlock.content.trimmingCharacters(in: .whitespacesAndNewlines) == content
        }.count > 1
    }
}

extension View {
    func applyFormatting(metadata: [String: String]?) -> some View {
        self
            .italic(metadata?["emphasis"] == "true")
            .fontWeight(metadata?["bold"] == "true" ? .bold : .regular)
    }
} 
