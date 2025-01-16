//
//  ReadabilityParser.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//

import Foundation

actor ReadabilityParser {
    func parseArticle(from html: String, baseURL: URL) async throws -> ParsedArticle {
        let cleanedHtml = cleanHtml(html)
        
        // Detect site type for specific parsing strategies
        let siteType = detectSiteType(from: baseURL, and: cleanedHtml)
        
        let title = extractTitle(from: cleanedHtml, siteType: siteType) ?? baseURL.host ?? "Untitled"
        let content = extractContent(from: cleanedHtml, siteType: siteType) ?? "No content available"
        
        return ParsedArticle(
            title: title,
            content: content,
            textContent: cleanText(content),
            excerpt: extractExcerpt(from: content),
            byline: extractByline(from: cleanedHtml, siteType: siteType),
            length: content.count,
            siteName: extractSiteName(from: cleanedHtml, baseURL: baseURL)
        )
    }
    
    private enum SiteType {
        case substack    // For Latent Space
        case gwern       // For gwern.net
        case stripe      // For stripe.press
        case standard    // Default fallback
    }
    
    private func detectSiteType(from url: URL, and html: String) -> SiteType {
        let host = url.host?.lowercased() ?? ""
        
        if host.contains("substack") || host.contains("latent.space") {
            return .substack
        } else if host.contains("gwern.net") {
            return .gwern
        } else if host.contains("stripe.press") {
            return .stripe
        }
        return .standard
    }
    
    private func extractTitle(from html: String, siteType: SiteType) -> String? {
        switch siteType {
        case .substack:
            // Substack usually has h1 with the main title
            if let title = extractContent(matching: "<h1[^>]*>([^<]+)</h1>", in: html) {
                return cleanText(title)
            }
        case .gwern:
            // Gwern uses specific header structure
            if let title = extractContent(matching: "<h1[^>]*id=\"title\"[^>]*>([^<]+)</h1>", in: html) {
                return cleanText(title)
            }
        case .stripe:
            // Stripe Press uses article headers
            if let title = extractContent(matching: "<article[^>]*>\\s*<h1[^>]*>([^<]+)</h1>", in: html) {
                return cleanText(title)
            }
        case .standard:
            // Try standard title patterns
            if let h1Content = extractContent(matching: "<h1[^>]*>([^<]+)</h1>", in: html) {
                return cleanText(h1Content)
            }
        }
        
        // Fallback to meta title or regular title tag
        if let metaTitle = extractContent(matching: "<meta\\s+property=\"og:title\"\\s+content=\"([^\"]+)\"", in: html) {
            return cleanText(metaTitle)
        }
        
        return extractContent(matching: "<title[^>]*>([^<]+)</title>", in: html)
    }
    
    private func extractContent(from html: String, siteType: SiteType) -> String? {
        switch siteType {
        case .substack:
            // Substack specific content patterns
            let substackPatterns = [
                "<div[^>]*class=\"[^\"]*post-content[^\"]*\"[^>]*>([\\s\\S]*?)</div>",
                "<div[^>]*class=\"[^\"]*body[^\"]*\"[^>]*>([\\s\\S]*?)</div>"
            ]
            for pattern in substackPatterns {
                if let content = extractContent(matching: pattern, in: html) {
                    return cleanContent(content)
                }
            }
            
        case .gwern:
            // Gwern uses specific article structure
            let gwernPatterns = [
                "<div[^>]*id=\"markdownBody\"[^>]*>([\\s\\S]*?)</div>",
                "<article[^>]*class=\"[^\"]*content[^\"]*\"[^>]*>([\\s\\S]*?)</article>"
            ]
            for pattern in gwernPatterns {
                if let content = extractContent(matching: pattern, in: html) {
                    return cleanContent(content)
                }
            }
            
        case .stripe:
            // Stripe Press specific patterns
            let stripePatterns = [
                "<article[^>]*>([\\s\\S]*?)</article>",
                "<main[^>]*role=\"main\"[^>]*>([\\s\\S]*?)</main>"
            ]
            for pattern in stripePatterns {
                if let content = extractContent(matching: pattern, in: html) {
                    return cleanContent(content)
                }
            }
            
        case .standard:
            // Standard fallback patterns
            let standardPatterns = [
                "<article[^>]*>([\\s\\S]*?)</article>",
                "<main[^>]*>([\\s\\S]*?)</main>",
                "<div[^>]*class=[\"']?(?:post-content|article-content|entry-content|content-article)[\"']?[^>]*>([\\s\\S]*?)</div>",
                "<div[^>]*id=[\"']?(?:post-content|article-content|entry-content|content)[\"']?[^>]*>([\\s\\S]*?)</div>"
            ]
            for pattern in standardPatterns {
                if let content = extractContent(matching: pattern, in: html) {
                    return cleanContent(content)
                }
            }
        }
        
        return nil
    }
    
    private func extractByline(from html: String, siteType: SiteType) -> String? {
        switch siteType {
        case .substack:
            return extractContent(matching: "<a[^>]*class=\"[^\"]*author-name[^\"]*\"[^>]*>([^<]+)</a>", in: html)
        case .gwern:
            return "Gwern Branwen"  // Static author
        case .stripe:
            return extractContent(matching: "<meta\\s+name=\"author\"\\s+content=\"([^\"]+)\"", in: html)
        case .standard:
            // Try various author patterns
            let authorPatterns = [
                "<meta\\s+name=\"author\"\\s+content=\"([^\"]+)\"",
                "<a[^>]*class=\"[^\"]*author[^\"]*\"[^>]*>([^<]+)</a>",
                "<span[^>]*class=\"[^\"]*author[^\"]*\"[^>]*>([^<]+)</span>"
            ]
            for pattern in authorPatterns {
                if let author = extractContent(matching: pattern, in: html) {
                    return cleanText(author)
                }
            }
            return nil
        }
    }
    
    private func cleanHtml(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<script\\b[^<]*(?:(?!<\\/script>)<[^<]*)*<\\/script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style\\b[^<]*(?:(?!<\\/style>)<[^<]*)*<\\/style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
            // Handle Paul Graham's specific table structure
            .replacingOccurrences(of: "<td[^>]*>([\\s\\S]*?)</td>", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "<tr[^>]*>([\\s\\S]*?)</tr>", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "<table[^>]*>([\\s\\S]*?)</table>", with: "$1", options: .regularExpression)
    }
    
    private func cleanText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractExcerpt(from content: String) -> String? {
        let words = content.split(separator: " ")
        if words.count > 30 {
            return words.prefix(30).joined(separator: " ") + "..."
        }
        return nil
    }
    
    private func extractSiteName(from html: String, baseURL: URL) -> String? {
        let host = baseURL.host ?? ""
        if let siteName = extractContent(matching: "<meta\\s+name=\"application-name\"\\s+content=\"([^\"]+)\"", in: html) {
            return cleanText(siteName)
        }
        return host
    }
    
    private func extractContent(matching pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        return String(text[contentRange])
    }
    
    private func cleanContent(_ content: String) -> String {
        var cleaned = content
            // Handle headers
            .replacingOccurrences(of: "<h[1-6][^>]*>\\s*(.+?)\\s*</h[1-6]>", with: "\n\n$1\n\n", options: .regularExpression)
            // Handle paragraphs with proper spacing
            .replacingOccurrences(of: "</p>\\s*<p[^>]*>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "<p[^>]*>|</p>", with: "\n", options: .regularExpression)
            // Handle line breaks
            .replacingOccurrences(of: "<br\\s*/?>|<br>", with: "\n", options: .regularExpression)
            // Handle lists
            .replacingOccurrences(of: "<li[^>]*>\\s*(.+?)\\s*</li>", with: "\n• $1", options: .regularExpression)
            // Remove remaining HTML tags
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            // Handle common HTML entities
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            // Fix whitespace while preserving paragraph breaks
            .replacingOccurrences(of: "\\s*\n\\s*", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        
        // Normalize paragraph breaks
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        // Ensure proper paragraph spacing
        cleaned = cleaned.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ParsedArticle {
    let title: String
    let content: String
    let textContent: String
    let excerpt: String?
    let byline: String?
    let length: Int
    let siteName: String?
} 
