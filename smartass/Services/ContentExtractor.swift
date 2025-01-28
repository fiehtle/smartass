//
//  ContentExtractor.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import Foundation
import WebKit
import SwiftSoup

@MainActor
class ContentExtractor: NSObject, WKNavigationDelegate {
    // Cache compiled regex patterns
    private static let htmlTagPattern = try! NSRegularExpression(pattern: "^\\s*<[^>]+>\\s*$", options: [])
    private static let boilerplatePatterns: [NSRegularExpression] = {
        let patterns = [
            "^\\s*navigation\\s*$",
            "^\\s*menu\\s*$",
            "^\\s*search\\s*$",
            "^\\s*copyright\\s*",
            "^\\s*all\\s+rights\\s+reserved\\s*",
            "^\\s*privacy\\s+policy\\s*",
            "^\\s*terms\\s+of\\s+service\\s*",
            "^\\s*skip\\s+to\\s+content\\s*$"
        ]
        return patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }()
    
    // Cache common selectors
    private static let substackSelectors = [
        "article.post",
        "div.post-content",
        "div[class*=post]"
    ]
    
    private static let authorSelectors = [
        "[itemprop=author]",
        "[class*=author]",
        "[rel=author]",
        ".byline",
        ".meta-author"
    ]
    
    private var webView: WKWebView?
    private var continuations: [CheckedContinuation<String, Error>] = []
    
    func extract(from url: URL) async throws -> DisplayArticle {
        // Create a new WebView for each extraction to avoid state issues
        let config = WKWebViewConfiguration()
        // Modern way to configure JavaScript
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: config)
        webView.navigationDelegate = self
        
        // Get fully rendered HTML
        let html = try await loadAndExtractHTML(webView: webView, url: url)
        
        // Parse with SwiftSoup
        let doc = try SwiftSoup.parse(html)
        
        // Extract structural content
        let article = try parseStructuredContent(doc)
        print("Extracted article with \(article.content.count) blocks")
        
        // Clean up
        webView.navigationDelegate = nil
        
        return article
    }
    
    private func loadAndExtractHTML(webView: WKWebView, url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
            webView.load(URLRequest(url: url))
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task {
            do {
                // Reduced initial wait time but added check for readiness
                try await Task.sleep(nanoseconds: 500 * NSEC_PER_MSEC)
                
                // More efficient scrolling - do fewer passes but scroll larger distances
                for _ in 0..<3 {
                    let height = try await webView.evaluateJavaScript("""
                        window.scrollTo(0, document.body.scrollHeight * 2);
                        document.body.scrollHeight;
                    """) as? Double ?? 0
                    
                    // Only wait briefly between scrolls
                    try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
                    
                    // If we've reached the bottom, stop scrolling
                    let scrollPos = try await webView.evaluateJavaScript("window.scrollY") as? Double ?? 0
                    if scrollPos >= height - webView.frame.height {
                        break
                    }
                }
                
                // Get the fully rendered HTML - more targeted extraction
                let html = try await webView.evaluateJavaScript("""
                    document.documentElement.outerHTML;
                """) as? String ?? ""
                
                guard !html.isEmpty else {
                    throw ExtractorError.contentExtractionFailed
                }
                
                // Resume all waiting continuations
                continuations.forEach { $0.resume(returning: html) }
                continuations.removeAll()
                
            } catch {
                continuations.forEach { $0.resume(throwing: error) }
                continuations.removeAll()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuations.forEach { $0.resume(throwing: error) }
        continuations.removeAll()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuations.forEach { $0.resume(throwing: error) }
        continuations.removeAll()
    }
    
    // MARK: - Content Parsing
    
    private func parseStructuredContent(_ doc: Document) throws -> DisplayArticle {
        // First identify the title - look for the most prominent heading
        let title = try findTitle(in: doc)
        
        // Then try to find the author
        let author = try findAuthor(in: doc)
        
        // Find the main article content
        let mainContent = try findArticleContent(in: doc)
        
        // Parse the content preserving structure
        var blocks = [DisplayArticle.ContentBlock]()
        blocks.reserveCapacity(50) // Pre-allocate space for typical article size
        try parseContentStructure(mainContent, into: &blocks)
        
        // Filter out any remaining HTML tags or boilerplate
        let cleanedBlocks = blocks.filter { block in
            let content = block.content
            guard !content.isEmpty else { return false }
            
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            
            // Skip blocks that are just HTML tags
            guard Self.htmlTagPattern.firstMatch(in: content, range: range) == nil else {
                return false
            }
            
            // Skip empty or whitespace-only blocks
            guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
            
            // Skip navigation/boilerplate text
            return !isBoilerplate(content)
        }
        
        return DisplayArticle(
            title: title,
            author: author,
            content: cleanedBlocks,
            estimatedReadingTime: estimateReadingTime(blocks: cleanedBlocks)
        )
    }
    
    private func findArticleContent(in doc: Document) throws -> Element {
        if try isSubstackArticle(doc) {
            for selector in Self.substackSelectors {
                let elements = try doc.select(selector)
                if !elements.isEmpty() {
                    let mainContent = elements.first()!
                    try mainContent.select([
                        "div[class*=share]",
                        "button",
                        "div[class*=subscription]",
                        "div[class*=comment]",
                        "div.author-bio",
                        "div[class*=footer]",
                        "div[class*=social]"
                    ].joined(separator: ", ")).remove()
                    return mainContent
                }
            }
        }
        
        // Default article content finding logic for other sites
        let articleSelectors = [
            "article",
            "[role=main]",
            "[role=article]",
            ".article-content",
            ".post-content",
            "#article-content",
            "#post-content",
            ".entry-content",
            ".content",
            ".main-content"
        ]
        
        // First try article-specific selectors
        for selector in articleSelectors {
            let elements = try doc.select(selector)
            if !elements.isEmpty() {
                return elements.first()!
            }
        }
        
        // If no article container found, find the densest content area
        return try findDensestContent(in: doc.body()!)
    }
    
    private func findDensestContent(in element: Element) throws -> Element {
        var bestElement = element
        var bestScore = 0.0
        
        try element.getAllElements().forEach { el in
            let score = try scoreElement(el)
            if score > bestScore {
                bestScore = score
                bestElement = el
            }
        }
        
        return bestElement
    }
    
    private func scoreElement(_ element: Element) throws -> Double {
        let text = try element.text()
        let words = text.split(whereSeparator: \.isWhitespace)
        
        // Ignore very short text
        guard words.count > 10 else { return 0 }
        
        // Calculate various metrics
        let paragraphs = try element.select("p")
        let links = try element.select("a")
        let headers = try element.select("h1, h2, h3, h4, h5, h6")
        
        // Scoring factors:
        let textScore = Double(words.count)
        let paragraphScore = Double(paragraphs.count) * 30
        let headerScore = Double(headers.count) * 20
        let linkPenalty = Double(links.count) * 5
        
        // Bonus for article-like containers
        let tagScore: Double
        switch element.tagName() {
        case "article": tagScore = 100
        case "main": tagScore = 80
        case "div": tagScore = 0
        default: tagScore = -20
        }
        
        return textScore + paragraphScore + headerScore - linkPenalty + tagScore
    }
    
    private func isBoilerplate(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Self.boilerplatePatterns.contains { pattern in
            pattern.firstMatch(in: text, range: range) != nil
        }
    }
    
    private func findTitle(in doc: Document) throws -> String {
        // Try multiple strategies to find the title
        
        // 1. Look for article headline markers
        let headlineSelectors = [
            "[itemprop=headline]",
            "[property='og:title']",
            ".article-title",
            ".post-title",
            ".entry-title"
        ]
        
        for selector in headlineSelectors {
            if let headline = try doc.select(selector).first() {
                let text = try headline.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
            }
        }
        
        // 2. Find the most prominent h1
        if let h1 = try doc.select("h1").first() {
            let text = try h1.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        
        // 3. Fallback to document title
        return try doc.title()
    }
    
    private func findAuthor(in doc: Document) throws -> String? {
        for selector in Self.authorSelectors {
            if let author = try doc.select(selector).first() {
                let text = try author.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    return text.replacingOccurrences(of: "^[Bb]y\\s+", with: "", options: .regularExpression)
                }
            }
        }
        return nil
    }
    
    private func parseContentStructure(_ element: Element, into blocks: inout [DisplayArticle.ContentBlock]) throws {
        // Process all elements to identify structure
        try processNode(element, into: &blocks)
    }
    
    private func processNode(_ node: Node, into blocks: inout [DisplayArticle.ContentBlock]) throws {
        // Handle text nodes
        if node is TextNode {
            let text = (node as! TextNode).text()
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Create text block with parent's formatting
                if let parent = node.parent() as? Element {
                    let metadata = try getFormattingMetadata(parent)
                    blocks.append(.init(type: .paragraph, content: text, metadata: metadata))
                } else {
                    blocks.append(.init(type: .paragraph, content: text, metadata: [:]))
                }
            }
            return
        }
        
        guard let element = node as? Element else { return }
        
        // Preserve structural information
        switch element.tagName() {
        case "br":
            // Explicit line break
            blocks.append(.init(type: .paragraph, content: "\n", metadata: [:]))
            return
            
        case "p":
            // Paragraph with potential formatting
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let metadata = try getFormattingMetadata(element)
                blocks.append(.init(type: .paragraph, content: text, metadata: metadata))
                // Add extra break after paragraphs for spacing
                blocks.append(.init(type: .paragraph, content: "\n", metadata: [:]))
            }
            return
            
        case "h1", "h2", "h3", "h4", "h5", "h6":
            // Headings
            let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let level = Int(element.tagName().dropFirst())!
                blocks.append(.init(type: .heading(level: level), content: text, metadata: [:]))
                // Add break after headings
                blocks.append(.init(type: .paragraph, content: "\n", metadata: [:]))
            }
            return
            
        case "ul", "ol":
            // Lists
            try element.children().forEach { item in
                if item.tagName() == "li" {
                    let text = try item.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        blocks.append(.init(
                            type: .list(ordered: element.tagName() == "ol"),
                            content: text,
                            metadata: try getFormattingMetadata(item)
                        ))
                    }
                }
            }
            // Add break after list
            blocks.append(.init(type: .paragraph, content: "\n", metadata: [:]))
            return
            
        case "div", "section", "article":
            // Container elements - check for specific classes that indicate structure
            let classNames = try element.classNames()
            if classNames.contains(where: { $0.contains("chapter") || $0.contains("section") }) {
                // This is a structural container, add spacing around it
                blocks.append(.init(type: .paragraph, content: "\n", metadata: [:]))
                try processChildren(element, into: &blocks)
                blocks.append(.init(type: .paragraph, content: "\n", metadata: [:]))
                return
            }
        default:
            break
        }
        
        // Process children for other elements
        try processChildren(element, into: &blocks)
    }
    
    private func processChildren(_ element: Element, into blocks: inout [DisplayArticle.ContentBlock]) throws {
        for child in element.getChildNodes() {
            try processNode(child, into: &blocks)
        }
    }
    
    private func getFormattingMetadata(_ element: Element) throws -> [String: String] {
        var metadata: [String: String] = [:]
        
        // Only apply formatting to titles and headings
        let tagName = element.tagName().lowercased()
        if tagName.hasPrefix("h") {
            // Check for bold in headings
            if try !element.select("strong, b").isEmpty() {
                metadata["bold"] = "true"
            }
            // Check for emphasis in headings
            if try !element.select("em, i").isEmpty() {
                metadata["emphasis"] = "true"
            }
        }
        
        return metadata
    }
    
    private func estimateReadingTime(blocks: [DisplayArticle.ContentBlock]) -> TimeInterval {
        let wordsPerMinute = 250.0
        let totalWords = blocks.reduce(0) { count, block in
            count + block.content.split(whereSeparator: \.isWhitespace).count
        }
        return (Double(totalWords) / wordsPerMinute) * 60
    }
    
    private func isSubstackArticle(_ doc: Document) throws -> Bool {
        // Check for Substack-specific elements or metadata
        let isSubstack = try !doc.select("meta[content*=substack]").isEmpty()
        let hasSubstackClass = try !doc.select("[class*=substack]").isEmpty()
        return isSubstack || hasSubstackClass
    }
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

extension String {
    func matches(regex pattern: String, options: NSRegularExpression.Options = []) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
} 
