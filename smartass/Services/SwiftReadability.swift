import Foundation

class SwiftReadability {
    private let minTextLength = 25
    private let minScore = 20
    
    private let unlikelyCandidates = try! NSRegularExpression(pattern: "combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter", options: .caseInsensitive)
    
    private let okMaybeItsACandidate = try! NSRegularExpression(pattern: "and|article|body|column|main|shadow", options: .caseInsensitive)
    
    private let positive = try! NSRegularExpression(pattern: "article|body|content|entry|hentry|main|page|pagination|post|text|blog|story", options: .caseInsensitive)
    
    private let negative = try! NSRegularExpression(pattern: "combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget", options: .caseInsensitive)
    
    private let divToPElements = try! NSRegularExpression(pattern: "<(a|blockquote|dl|div|img|ol|p|pre|table|ul)", options: .caseInsensitive)
    
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
        // Create DOM-like structure
        let doc = try HTMLDocument(html: html)
        
        // 1. Find title
        let title = findTitle(in: doc)
        
        // 2. Prep the document
        prepDocument(doc)
        
        // 3. Find the main content
        let article = try findMainContent(in: doc)
        
        // 4. Clean up the content
        let cleanedContent = cleanContent(article)
        
        // 5. Extract metadata
        let byline = findByline(in: doc)
        let excerpt = findExcerpt(in: doc)
        let siteName = findSiteName(in: doc, url: url)
        
        return ParseResult(
            title: title,
            content: cleanedContent,
            textContent: cleanedContent.strippingHTML(),
            excerpt: excerpt,
            byline: byline,
            siteName: siteName,
            length: cleanedContent.count
        )
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
    
    private func findFirstTag(_ tagName: String, in node: HTMLNode) -> HTMLNode? {
        if node.tagName?.lowercased() == tagName.lowercased() {
            return node
        }
        
        for child in node.childNodes {
            if let found = findFirstTag(tagName, in: child) {
                return found
            }
        }
        
        return nil
    }
    
    private func prepDocument(_ doc: HTMLDocument) {
        // For now, just a placeholder
        // We'll add proper document preparation later
    }
    
    private func findMainContent(in doc: HTMLDocument) throws -> HTMLNode {
        // For initial testing, let's find the first article or main content div
        if let article = findFirstTag("article", in: doc.rootNode) {
            return article
        }
        
        if let main = findFirstTag("main", in: doc.rootNode) {
            return main
        }
        
        // For Paul Graham's site
        if let td = findFirstTag("td", in: doc.rootNode) {
            return td
        }
        
        throw NSError(domain: "SwiftReadability", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find main content"])
    }
    
    private func cleanContent(_ node: HTMLNode) -> String {
        // For initial testing, just return the text content
        return node.textContent
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