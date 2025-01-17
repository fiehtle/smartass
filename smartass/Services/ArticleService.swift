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
        
        print("✅ HTML content fetched, parsing...")
        return Article(
            url: urlString,
            title: result.title,
            content: result.content,
            textContent: result.textContent,
            author: result.byline,
            excerpt: result.excerpt,
            siteName: result.siteName,
            datePublished: nil,
            estimatedReadingTime: estimateReadingTime(for: result.textContent)
        )
    }
    
    private func estimateReadingTime(for content: String) -> Int {
        let words = content.split(separator: " ").count
        let wordsPerMinute = 200
        return max(1, Int(ceil(Double(words) / Double(wordsPerMinute))))
    }
} 
