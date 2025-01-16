import Foundation
import WebKit

actor ReadabilityParser {
    private let readabilityJS = """
        function cleanText(text) {
            return text.replace(/\\s+/g, ' ').trim();
        }
        
        function parseArticle() {
            // Add Readability.js to the page
            var readabilityScript = document.createElement('script');
            readabilityScript.src = 'https://cdnjs.cloudflare.com/ajax/libs/Readability/0.4.4/Readability.js';
            document.head.appendChild(readabilityScript);
            
            return new Promise((resolve, reject) => {
                readabilityScript.onload = function() {
                    try {
                        var documentClone = document.cloneNode(true);
                        var article = new Readability(documentClone).parse();
                        
                        if (article) {
                            resolve({
                                title: cleanText(article.title),
                                content: article.content,
                                textContent: cleanText(article.textContent),
                                excerpt: article.excerpt ? cleanText(article.excerpt) : null,
                                byline: article.byline ? cleanText(article.byline) : null,
                                length: article.length,
                                siteName: article.siteName
                            });
                        } else {
                            reject('Failed to parse article');
                        }
                    } catch (error) {
                        reject(error.toString());
                    }
                };
                
                readabilityScript.onerror = function() {
                    reject('Failed to load Readability.js');
                };
            });
        }
        
        parseArticle();
    """
    
    private var webView: WKWebView?
    
    func parseArticle(from html: String, baseURL: URL) async throws -> ParsedArticle {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let configuration = WKWebViewConfiguration()
                self.webView = WKWebView(frame: .zero, configuration: configuration)
                
                self.webView?.loadHTMLString(html, baseURL: baseURL)
                
                self.webView?.evaluateJavaScript(self.readabilityJS) { result, error in
                    if let error = error {
                        continuation.resume(throwing: ArticleError.parsingFailed)
                        return
                    }
                    
                    guard let resultDict = result as? [String: Any] else {
                        continuation.resume(throwing: ArticleError.parsingFailed)
                        return
                    }
                    
                    let article = ParsedArticle(
                        title: resultDict["title"] as? String ?? "Untitled",
                        content: resultDict["content"] as? String ?? "",
                        textContent: resultDict["textContent"] as? String ?? "",
                        excerpt: resultDict["excerpt"] as? String,
                        byline: resultDict["byline"] as? String,
                        length: resultDict["length"] as? Int ?? 0,
                        siteName: resultDict["siteName"] as? String
                    )
                    
                    continuation.resume(returning: article)
                    self.webView = nil
                }
            }
        }
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