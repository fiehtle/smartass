//
//  ArticleReaderViewModel.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import Foundation

@MainActor
class ArticleReaderViewModel: ObservableObject {
    @Published private(set) var article: Article?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    // Add formatting options
    @Published var fontSize: CGFloat = 17
    @Published var fontFamily = "-apple-system"
    @Published var isDarkMode = false
    @Published var lineHeight: CGFloat = 1.6
    
    private var articleService: ArticleService?
    private var serviceTask: Task<Void, Never>?
    
    init() {
        print("🔄 ViewModel: Initializing...")
        setupService()
    }
    
    private func setupService() {
        serviceTask = Task {
            print("🔄 ViewModel: Setting up service...")
            articleService = await ArticleService()
            print("✅ ViewModel: Service ready")
        }
    }
    
    var formattedContent: String {
        guard let article = article else { return "" }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system;
                    font-size: 18px;
                    line-height: 1.6;
                    color: \(isDarkMode ? "#FFFFFF" : "#000000");
                    background-color: \(isDarkMode ? "#000000" : "#FFFFFF");
                    margin: 0 auto;
                    max-width: 680px;
                    padding: 20px;
                }
                
                p {
                    margin: 0;
                    min-height: 1.6em;
                }
                
                p + p {
                    margin-top: 1.6em;
                }
                
                h1 { 
                    font-size: 1.5em;
                    line-height: 1.3;
                    margin: 1.5em 0 1em 0;
                }
                
                h1, h2, h3, h4, h5, h6 {
                    line-height: 1.3;
                    margin: 1.5em 0 0.8em 0;
                }
                
                h1 { font-size: 1.6em; }
                h2 { font-size: 1.4em; }
                h3 { font-size: 1.2em; }
                
                img {
                    max-width: 100%;
                    height: auto;
                    margin: 1em 0;
                    border-radius: 8px;
                }
                
                blockquote {
                    margin: 1.5em 0;
                    padding: 0.8em 1em;
                    border-left: 4px solid \(isDarkMode ? "#404040" : "#E0E0E0");
                    background: \(isDarkMode ? "#1A1A1A" : "#F5F5F5");
                }
                
                pre, code {
                    font-family: "SF Mono", monospace;
                    background: \(isDarkMode ? "#1A1A1A" : "#F5F5F5");
                    padding: 0.2em 0.4em;
                    border-radius: 4px;
                }
                
                ul, ol {
                    margin: 1em 0;
                    padding-left: 2em;
                }
                
                li {
                    margin: 0.5em 0;
                }
                
                a {
                    color: \(isDarkMode ? "#4BA1FF" : "#0066CC");
                    text-decoration: none;
                }
                
                hr {
                    border: none;
                    border-top: 1px solid \(isDarkMode ? "#404040" : "#E0E0E0");
                    margin: 2em 0;
                }
            </style>
        </head>
        <body>
            \(article.content)
        </body>
        </html>
        """
    }
    
    func fetchArticle(from url: String) {
        Task {
            print("🎯 ViewModel: Waiting for service...")
            await serviceTask?.value
            
            guard let service = articleService else {
                print("❌ ViewModel: Service initialization failed")
                return
            }
            
            print("🎯 ViewModel: Starting fetch for URL: \(url)")
            isLoading = true
            error = nil
            
            do {
                article = try await service.fetchArticle(from: url)
                print("✅ ViewModel: Article fetched successfully")
            } catch {
                print("❌ ViewModel: Error fetching article: \(error)")
                self.error = error
            }
            
            isLoading = false
        }
    }
} 
