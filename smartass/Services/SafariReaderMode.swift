//
//  SafariReaderMode.swift
//  smartass
//
//  Created by Viet Le on 1/17/25.
//


import WebKit

actor SafariReaderMode {
    enum Error: Swift.Error {
        case loadingFailed
        case parsingFailed
    }
    
    struct ReaderResult {
        let title: String
        let content: String
        let textContent: String
        let byline: String?
        let excerpt: String?
        let siteName: String?
        let length: Int
    }
    
    private let readabilityJS = """
        // Mozilla's Readability.js (minified version)
        // From: https://github.com/mozilla/readability/blob/master/Readability.js
        !function(t,e){"object"==typeof exports&&"undefined"!=typeof module?module.exports=e():"function"==typeof define&&define.amd?define(e):(t="undefined"!=typeof globalThis?globalThis:t||self).Readability=e()}(this,(function(){"use strict";...
    """
    
    private let parseJS = """
        new Readability(document).parse();
    """
    
    func parse(url: URL) async throws -> ReaderResult {
        return try await withCheckedThrowingContinuation { continuation in
            let webView = WKWebView()
            let config = webView.configuration
            
            // Inject Readability.js
            let script = WKUserScript(
                source: readabilityJS,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(script)
            
            // Set up load completion handler
            let delegate = LoadDelegate(continuation: continuation)
            webView.navigationDelegate = delegate
            
            // Load the URL
            webView.load(URLRequest(url: url))
        }
    }
}

private class LoadDelegate: NSObject, WKNavigationDelegate {
    private let continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>
    
    init(continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>) {
        self.continuation = continuation
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a bit for dynamic content
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webView.evaluateJavaScript("""
                var article = new Readability(document).parse();
                JSON.stringify(article);
            """) { result, error in
                if let error = error {
                    self.continuation.resume(throwing: .parsingFailed)
                    return
                }
                
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let article = try? JSONDecoder().decode(ReaderResult.self, from: data) else {
                    self.continuation.resume(throwing: .parsingFailed)
                    return
                }
                
                self.continuation.resume(returning: article)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation.resume(throwing: .loadingFailed)
    }
} 