//
//  ContentExtractor.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import Foundation
import WebKit
import SwiftSoup

actor ContentExtractor {
    private var webView: WKWebView?
    private let parser = ArticleParser()
    
    func extract(from url: URL) async throws -> Article {
        // Get fully rendered HTML
        let html = try await loadAndExtractHTML(from: url)
        
        // Parse with SwiftSoup
        let doc = try SwiftSoup.parse(html)
        
        // Extract structural content
        let article = try parser.parseStructuredContent(doc)
        print("Extracted article with \(article.content.count) blocks")
        return article
    }
    
    private func loadAndExtractHTML(from url: URL) async throws -> String {
        if webView == nil {
            let config = WKWebViewConfiguration()
            webView = WKWebView(frame: .zero, configuration: config)
        }
        
        guard let webView = webView else {
            throw ExtractorError.webViewInitFailed
        }
        
        // Load the page
        _ = try await webView.load(URLRequest(url: url))
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
        
        // Scroll multiple times to reveal all content
        for _ in 0..<5 {
            try await webView.evaluateJavaScript("""
                window.scrollTo(0, document.body.scrollHeight);
            """)
            try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
        }
        
        // Get the fully rendered HTML
        let html = try await webView.evaluateJavaScript(
            "document.documentElement.outerHTML"
        ) as? String ?? ""
        
        return html
    }
}

// Separate parser class for better organization
class ArticleParser {
    func parseStructuredContent(_ doc: Document) throws -> Article {
        // Clean up first
        try removeNoise(from: doc)
        
        // Find main content area
        let mainContent = try findMainContent(in: doc)
        
        // Extract metadata
        let title = try extractTitle(from: doc, mainContent: mainContent)
        let author = try? extractAuthor(from: doc)
        
        // Parse content blocks with rich formatting
        let blocks = try parseBlocks(from: mainContent)
        
        return Article(
            title: title,
            author: author,
            content: blocks,
            estimatedReadingTime: estimateReadingTime(blocks: blocks)
        )
    }
    
    private func parseBlocks(from element: Element) throws -> [Article.ContentBlock] {
        var blocks: [Article.ContentBlock] = []
        
        for child in element.children() {
            try autoreleasepool {
                let block = try parseBlock(child)
                if let block = block {
                    blocks.append(block)
                }
            }
        }
        
        return blocks
    }
    
    private func parseBlock(_ element: Element) throws -> Article.ContentBlock? {
        let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        
        // Check for text formatting
        let hasEmphasis = !try element.select("em, i").isEmpty()
        let hasBold = !try element.select("strong, b").isEmpty()
        
        // Create metadata for formatting
        var metadata: [String: String] = [:]
        if hasEmphasis { metadata["emphasis"] = "true" }
        if hasBold { metadata["bold"] = "true" }
        
        switch element.tagName() {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(element.tagName().dropFirst())!
            return .init(type: .heading(level: level), content: text, metadata: metadata)
            
        case "p":
            return .init(type: .paragraph, content: text, metadata: metadata)
            
        case "blockquote":
            return .init(type: .quote, content: text, metadata: metadata)
            
        case "pre", "code":
            return .init(type: .code, content: text)
            
        case "ul":
            var listBlocks: [Article.ContentBlock] = []
            try element.select("li").forEach { li in
                let itemText = try li.text()
                if !itemText.isEmpty {
                    listBlocks.append(.init(type: .list(ordered: false), content: itemText, metadata: metadata))
                }
            }
            return listBlocks.first
            
        case "ol":
            var listBlocks: [Article.ContentBlock] = []
            try element.select("li").forEach { li in
                let itemText = try li.text()
                if !itemText.isEmpty {
                    listBlocks.append(.init(type: .list(ordered: true), content: itemText, metadata: metadata))
                }
            }
            return listBlocks.first
            
        case "img":
            let alt = try element.attr("alt")
            let src = try element.attr("src")
            return .init(type: .image(alt: alt), content: src)
            
        default:
            if !text.isEmpty {
                return .init(type: .paragraph, content: text, metadata: metadata)
            }
            return nil
        }
    }
    
    // ... rest of the helper methods from ArticleParser ...
}

enum ExtractorError: LocalizedError {
    case webViewInitFailed
    case contentExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .webViewInitFailed:
            return "Failed to initialize web view"
        case .contentExtractionFailed:
            return "Failed to extract content from the page"
        }
    }
} 