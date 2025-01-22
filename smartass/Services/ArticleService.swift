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
    
    @MainActor private var readerMode: SafariReaderMode
    
    init() async {
        print("🔄 Service: Initializing...")
        self.readerMode = await MainActor.run {
            print("🔄 Service: Creating SafariReaderMode...")
            return SafariReaderMode()
        }
        print("✅ Service: Initialized")
    }
    
    func fetchArticle(from urlString: String) async throws -> Article {
        print("📱 Starting to fetch article from: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw Error.invalidURL
        }
        
        print("🌐 Fetching HTML content...")
        let result = try await readerMode.parse(url: url)
        
        print("✅ HTML content fetched, preprocessing...")
        let processedContent = preprocessHTML(result.content, from: urlString)
        
        return Article(
            url: urlString,
            title: result.title,
            content: processedContent,
            textContent: result.textContent,
            author: result.byline,
            excerpt: result.excerpt,
            siteName: result.siteName,
            datePublished: nil,
            estimatedReadingTime: estimateReadingTime(for: result.textContent)
        )
    }
    
    private func preprocessHTML(_ html: String, from urlString: String) -> String {
        print("🔄 Preprocessing HTML of length: \(html.count)")
        var processed = html
        
        // Site-specific optimizations for known sources
        if let url = URL(string: urlString), let host = url.host {
            print("📝 Processing content for host: \(host)")
            switch host {
            case "paulgraham.com":
                print("🔍 Applying Paul Graham specific processing")
                // Remove the title from content since it's shown in the header
                if let titleEndRange = processed.range(of: "</h1>") {
                    processed = String(processed[titleEndRange.upperBound...])
                }
                
                // PG's site uses simple HTML with br tags for spacing
                processed = processed.replacingOccurrences(
                    of: "<br><br>",
                    with: "</p><p>"
                )
                processed = "<p>" + processed + "</p>"
                
            case "stripe.press":
                print("🔍 Applying Stripe Press specific processing")
                // Stripe Press uses modern semantic HTML with multiple content containers
                let stripePatterns = [
                    // Main chapter content
                    "<div[^>]*class=\"[^\"]*chapter-content[^\"]*\"[^>]*>(.*?)</div>",
                    // Additional content sections
                    "<div[^>]*class=\"[^\"]*content-section[^\"]*\"[^>]*>(.*?)</div>",
                    // Text content blocks
                    "<div[^>]*class=\"[^\"]*text-content[^\"]*\"[^>]*>(.*?)</div>",
                    // Chapter text
                    "<div[^>]*class=\"[^\"]*chapter-text[^\"]*\"[^>]*>(.*?)</div>",
                    // Full chapter
                    "<div[^>]*class=\"[^\"]*chapter[^\"]*\"[^>]*>(.*?)</div>",
                    // Article blocks
                    "<article[^>]*>(.*?)</article>"
                ]
                
                print("🔍 Looking for content in \(stripePatterns.count) patterns")
                // Collect all content from different sections
                var allContent = ""
                for (index, pattern) in stripePatterns.enumerated() {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                        let range = NSRange(processed.startIndex..., in: processed)
                        let matches = regex.matches(in: processed, options: [], range: range)
                        
                        print("📝 Pattern \(index + 1): Found \(matches.count) matches")
                        for (matchIndex, match) in matches.enumerated() {
                            if let contentRange = Range(match.range(at: 1), in: processed) {
                                let content = processed[contentRange]
                                print("📝 Match \(matchIndex + 1) length: \(content.count)")
                                allContent += content + "\n"
                            }
                        }
                    }
                }
                
                // Use collected content if found, otherwise keep original
                if !allContent.isEmpty {
                    print("✅ Using combined content, length: \(allContent.count)")
                    processed = allContent
                } else {
                    print("⚠️ No content found in patterns, using original")
                }
                
            case "www.latent.space", "latent.space":
                // Substack-specific cleanup
                let substackCleanup = [
                    "<div[^>]*class=\"[^\"]*subscriber-only[^\"]*\"[^>]*>.*?</div>",
                    "<div[^>]*class=\"[^\"]*subscription-widget[^\"]*\"[^>]*>.*?</div>",
                    "<div[^>]*class=\"[^\"]*comments-section[^\"]*\"[^>]*>.*?</div>"
                ]
                
                for pattern in substackCleanup {
                    processed = processed.replacingOccurrences(
                        of: pattern,
                        with: "",
                        options: .regularExpression
                    )
                }
                
            default:
                // For unknown sources, apply general heuristics
                let commonNonContentPatterns = [
                    "<div[^>]*class=\"[^\"]*(?:subscriber|subscription|signup|newsletter)[^\"]*\"[^>]*>.*?</div>",
                    "<div[^>]*(?:id|class)=\"[^\"]*comments?[^\"]*\"[^>]*>.*?</div>",
                    "<nav[^>]*>.*?</nav>",
                    "<div[^>]*class=\"[^\"]*(?:share|social)[^\"]*\"[^>]*>.*?</div>"
                ]
                
                for pattern in commonNonContentPatterns {
                    processed = processed.replacingOccurrences(
                        of: pattern,
                        with: "",
                        options: .regularExpression
                    )
                }
            }
        }
        
        // Common processing for all sources
        
        // HEURISTIC 2: Identify and preserve semantic breaks
        let semanticBreakPatterns: [(pattern: String, replacement: String)] = [
            (pattern: "(<br\\s*/?>\\s*){2,}", replacement: "</p><p>"),
            (pattern: "<br\\s*/?>(?!\\s*<br)(?![^<]*?</(?:p|div|article|section)>)", replacement: " "),
            (pattern: "<p[^>]*>\\s*</p>", replacement: ""),
            (pattern: "</li>\\s*<li>", replacement: "</li><li>")
        ]
        
        for (pattern, replacement) in semanticBreakPatterns {
            processed = processed.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        
        // HEURISTIC 3: Clean up text nodes
        if !processed.contains("<p") && !processed.contains("<article") {
            let sentences = processed.components(separatedBy: ". ")
            processed = sentences
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { "<p>\($0).</p>" }
                .joined(separator: "\n")
        }
        
        // HEURISTIC 4: Normalize headings
        processed = processed.replacingOccurrences(
            of: "<h([1-6])[^>]*>\\s*(?:#*\\s*)?([^<]+?)\\s*(?:#*\\s*)?</h\\1>",
            with: "<h$1>$2</h$1>",
            options: .regularExpression
        )
        
        // HEURISTIC 5: Clean up whitespace
        processed = processed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        print("✅ Preprocessing complete. Result length: \(processed.count)")
        return processed
    }
    
    private func estimateReadingTime(for content: String) -> Int {
        let words = content.split(separator: " ").count
        let wordsPerMinute = 200
        return max(1, Int(ceil(Double(words) / Double(wordsPerMinute))))
    }
} 
