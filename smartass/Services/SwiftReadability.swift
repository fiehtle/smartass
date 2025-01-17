//
//  SwiftReadability.swift
//  smartass
//
//  Created by Viet Le on 1/17/25.
//


import Foundation

class SwiftReadability {
    private let selectors = [
        // Substack
        ".substack-post-content",
        // Common article patterns
        "article",
        "main",
        ".post-content",
        ".article-content",
        ".entry-content",
        // Blog patterns
        ".blog-post",
        ".post",
        // Site specific
        ".markdownBody",  // Gwern
        "td font",        // Paul Graham
    ]
    
    struct ParseResult {
        let title: String
        let content: String
        let textContent: String
        let excerpt: String?
        let byline: String?
        let siteName: String?
        let length: Int
    }
    
    func parse(html: String, url: URL) throws -> ParseResult {
        let doc = try HTMLDocument(html: html)
        
        // Find title
        let title = findTitle(in: doc)
        
        // Find content
        let article = try findContent(in: doc, url: url)
        let cleanedContent = cleanContent(article)
        
        // Extract metadata
        let byline = findByline(in: doc)
        let siteName = findSiteName(in: doc, url: url)
        
        return ParseResult(
            title: title,
            content: cleanedContent,
            textContent: cleanedContent.strippingHTML(),
            excerpt: findExcerpt(in: doc),
            byline: byline,
            siteName: siteName,
            length: cleanedContent.count
        )
    }
    
    private func findContent(in doc: HTMLDocument, url: URL) throws -> HTMLNode {
        print("🔍 Looking for content in: \(url)")
        
        // First try site-specific patterns
        if let content = findSiteSpecificContent(in: doc, url: url) {
            print("✅ Found content using site-specific pattern")
            return content
        }
        
        // Then try common patterns
        for selector in selectors {
            print("🔎 Trying selector: \(selector)")
            if let content = doc.rootNode.querySelector(selector) {
                let text = content.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && text.count > 100 {
                    print("✅ Found content using selector: \(selector)")
                    return content
                }
            }
        }
        
        print("❌ No content found")
        throw NSError(domain: "SwiftReadability", code: 1,
                     userInfo: [NSLocalizedDescriptionKey: "Could not find main content"])
    }
    
    private func findSiteSpecificContent(in doc: HTMLDocument, url: URL) -> HTMLNode? {
        let urlString = url.absoluteString.lowercased()
        
        switch true {
        case urlString.contains("paulgraham.com"):
            return doc.rootNode.querySelectorAll("td")
                .first(where: { $0.childNodes.contains(where: { $0.tagName == "font" }) })
            
        case urlString.contains("substack.com") || urlString.contains("latent.space"):
            return doc.rootNode.querySelector(".substack-post-content")
            
        case urlString.contains("gwern.net"):
            return doc.rootNode.querySelector(".markdownBody")
            
        default:
            return nil
        }
    }
    
    private func cleanContent(_ node: HTMLNode) -> String {
        var html = node.content
        
        // Preserve headers
        for i in 1...6 {
            html = html.replacingOccurrences(
                of: "<h\(i)[^>]*>(.+?)</h\(i)>",
                with: "\n\n$1\n\n",
                options: .regularExpression
            )
        }
        
        // Preserve paragraphs and breaks
        html = html.replacingOccurrences(of: "<p[^>]*>", with: "\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "</p>", with: "\n\n")
        html = html.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        html = html.replacingOccurrences(of: "<br>", with: "\n")
        
        // Handle lists
        html = html.replacingOccurrences(of: "<li[^>]*>", with: "\n• ", options: .regularExpression)
        html = html.replacingOccurrences(of: "</li>", with: "")
        
        // Handle blockquotes
        html = html.replacingOccurrences(
            of: "<blockquote[^>]*>(.+?)</blockquote>",
            with: "\n\n> $1\n\n",
            options: .regularExpression
        )
        
        // Remove remaining HTML tags but preserve content
        html = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        html = html.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&ndash;", with: "–")
        
        // Clean up whitespace
        while html.contains("\n\n\n") {
            html = html.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func findTitle(in doc: HTMLDocument) -> String {
        // First try OpenGraph title
        if let metaTitle = findMetaTitle(in: doc) {
            return metaTitle
        }
        
        // Then try <h1>
        if let h1 = findFirstTag("h1", in: doc.rootNode) {
            return h1.textContent
        }
        
        // Finally, fall back to <title>
        if let title = findFirstTag("title", in: doc.rootNode) {
            return title.textContent
        }
        
        return "Untitled"
    }
    
    private func findMetaTitle(in doc: HTMLDocument) -> String? {
        for node in doc.rootNode.childNodes {
            if node.tagName?.lowercased() == "meta",
               node.attributes["property"]?.lowercased() == "og:title",
               let content = node.attributes["content"] {
                return content
            }
        }
        return nil
    }
    
    private func findFirstTag(_ tagName: String, in node: HTMLNode, withClass className: String? = nil, withFont: Bool = false) -> HTMLNode? {
        if node.tagName?.lowercased() == tagName.lowercased() {
            if let className = className {
                if node.className?.contains(className) == true {
                    return node
                }
            } else if withFont {
                if node.childNodes.contains(where: { $0.tagName?.lowercased() == "font" }) {
                    return node
                }
            } else {
                return node
            }
        }
        
        for child in node.childNodes {
            if let found = findFirstTag(tagName, in: child, withClass: className, withFont: withFont) {
                return found
            }
        }
        
        return nil
    }
    
    private func findByline(in doc: HTMLDocument) -> String? {
        // Simple implementation for testing
        return nil
    }
    
    private func findExcerpt(in doc: HTMLDocument) -> String? {
        // Simple implementation for testing
        return nil
    }
    
    private func findSiteName(in doc: HTMLDocument, url: URL) -> String? {
        // Simple implementation for testing
        return url.host
    }
}

// Helper extensions
private extension String {
    func strippingHTML() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 
