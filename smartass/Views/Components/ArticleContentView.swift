//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import SwiftUI

struct ArticleContentView: View {
    let article: Article
    
    // Precompute duplicates and promotional content once
    private var contentToDisplay: [(block: Article.ContentBlock, isDuplicate: Bool)] = []
    
    // Regex pattern for footnote detection - includes inline references
    private static let footnotePattern = try! NSRegularExpression(pattern: "\\[\\d+\\]|\\[\\w+\\]|^\\d+\\.", options: [])
    
    init(article: Article) {
        self.article = article
        
        // Create lookup set for faster duplicate detection
        var seen = Set<String>()
        var duplicates = Set<String>()
        
        // First pass - identify duplicates
        for block in article.content {
            let content = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !seen.insert(content).inserted {
                duplicates.insert(content)
            }
        }
        
        // Create promotional phrases set for O(1) lookup
        let promotionalPhrases: Set<String> = [
            "Share this post", "Subscribe", "Copy link", "Facebook", "Email",
            "Notes", "More", "Share", "Previous", "Next", "Discussion about this post",
            "Comments", "Restacks", "Ready for more?", "© 2025", "Privacy", "Terms",
            "Collection notice", "Start Writing", "Get the app", "Substack",
            "min read", "Discover more from", "Continue reading", "Sign in",
            "subscribers", "newsletter", "podcast", "highlights from"
        ]
        
        // Second pass - filter content
        contentToDisplay = article.content.compactMap { block in
            var content = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip promotional content
            guard !promotionalPhrases.contains(where: { content.localizedCaseInsensitiveContains($0) }) else {
                return nil
            }
            
            // For non-footnote blocks, clean any inline references
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            if Self.footnotePattern.firstMatch(in: content, range: range) == nil {
                // Clean inline references from the content
                content = Self.footnotePattern.stringByReplacingMatches(
                    in: content,
                    range: range,
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip if content becomes empty after cleaning
                guard !content.isEmpty else { return nil }
                
                return (block: Article.ContentBlock(
                    type: block.type,
                    content: content,
                    metadata: block.metadata
                ), isDuplicate: duplicates.contains(content))
            }
            
            // Skip complete footnote blocks
            return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(contentToDisplay, id: \.block.content) { item in
                if !item.isDuplicate {
                    switch item.block.type {
                    case .heading:
                        if item.block.content != article.title {
                            Text(item.block.content)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    case .paragraph, .list, .quote, .code, .image:
                        Text(item.block.content)
                            .font(.body)
                    }
                }
            }
        }
    }
}

extension View {
    func applyFormatting(metadata: [String: String]?) -> some View {
        self
            .italic(metadata?["emphasis"] == "true")
            .fontWeight(metadata?["bold"] == "true" ? .bold : .regular)
    }
} 
