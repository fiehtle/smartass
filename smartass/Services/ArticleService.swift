//
//  ArticleService.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//

import Foundation

actor ArticleService {
    enum Error: Swift.Error {
        case invalidURL
        case fetchFailed
        case parsingFailed
    }
    
    func fetchArticle(from urlString: String) async throws -> Article {
        print("📱 Starting to fetch article from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw Error.invalidURL
        }
        
        print("🌐 Fetching HTML content...")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw Error.fetchFailed
        }
        
        print("✅ HTML content fetched, parsing...")
        let parser = HTMLParser()
        let content = try parser.parse(html: html, baseURL: url)
        
        return Article(
            url: urlString,
            title: content.title,
            content: content.content,
            textContent: content.textContent,
            author: content.author,
            excerpt: content.excerpt,
            siteName: content.siteName,
            datePublished: nil,
            estimatedReadingTime: estimateReadingTime(for: content.textContent)
        )
    }
    
    private func estimateReadingTime(for content: String) -> Int {
        let words = content.split(separator: " ").count
        let wordsPerMinute = 200
        return max(1, Int(ceil(Double(words) / Double(wordsPerMinute))))
    }
}

// MARK: - HTML Parser
private class HTMLParser {
    struct ParsedContent {
        let title: String
        let content: String
        let textContent: String
        let author: String?
        let excerpt: String?
        let siteName: String?
    }
    
    func parse(html: String, baseURL: URL) throws -> ParsedContent {
        // Remove scripts and styles first
        var cleanHtml = html
            .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        
        // Extract title
        let title = extractContent(matching: "<title[^>]*>([^<]+)</title>", from: cleanHtml) ??
                   extractContent(matching: "<h1[^>]*>([^<]+)</h1>", from: cleanHtml) ??
                   baseURL.lastPathComponent
        
        // Extract main content based on common patterns
        let contentPatterns = [
            // Article tag
            "<article[^>]*>([\\s\\S]*?)</article>",
            // Main content div
            "<div[^>]*class=[\"']?(?:post-content|article-content|entry-content)[\"']?[^>]*>([\\s\\S]*?)</div>",
            // Table cell (for Paul Graham's site)
            "<td[^>]*>([\\s\\S]*?)</td>"
        ]
        
        var content = ""
        for pattern in contentPatterns {
            if let extracted = extractContent(matching: pattern, from: cleanHtml) {
                content = extracted
                break
            }
        }
        
        // If no content found, try to get the body
        if content.isEmpty {
            content = extractContent(matching: "<body[^>]*>([\\s\\S]*?)</body>", from: cleanHtml) ?? ""
        }
        
        // Clean up the content
        content = cleanContent(content)
        
        // Extract metadata
        let author = extractContent(matching: "<meta[^>]*name=[\"']?author[\"']?[^>]*content=[\"']([^\"']+)[\"']", from: html)
        let siteName = extractContent(matching: "<meta[^>]*property=[\"']?og:site_name[\"']?[^>]*content=[\"']([^\"']+)[\"']", from: html)
        let excerpt = extractContent(matching: "<meta[^>]*name=[\"']?description[\"']?[^>]*content=[\"']([^\"']+)[\"']", from: html)
        
        return ParsedContent(
            title: cleanText(title),
            content: content,
            textContent: cleanText(content),
            author: author.map(cleanText),
            excerpt: excerpt.map(cleanText),
            siteName: siteName.map(cleanText)
        )
    }
    
    private func extractContent(matching pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
    
    private func cleanContent(_ content: String) -> String {
        var cleaned = content
            // Convert breaks and paragraphs to newlines
            .replacingOccurrences(of: "<br\\s*/?>|</p>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<p[^>]*>", with: "\n", options: .regularExpression)
            // Remove remaining HTML tags
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            // Decode HTML entities
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        // Normalize whitespace
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cleanText(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 
