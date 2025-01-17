//
//  SafariReaderMode.swift
//  smartass
//
//  Created by Viet Le on 1/17/25.
//


import WebKit

@MainActor
class SafariReaderMode {
    enum ReaderError: Error {
        case loadingFailed
        case parsingFailed
    }
    
    struct ReaderResult: Decodable {
        let title: String
        let content: String
        let textContent: String
        let byline: String?
        let excerpt: String?
        let siteName: String?
        let length: Int
    }
    
    // Store webView to prevent deallocation
    private var webView: WKWebView?
    private var delegate: LoadDelegate?
    
    // Add strong reference to configuration and controller
    private var configuration: WKWebViewConfiguration?
    private var controller: WKUserContentController?
    
    init() {
        // Initialize configuration and controller in init
        self.configuration = WKWebViewConfiguration()
        self.controller = WKUserContentController()
        
        guard let controller = controller,
              let configuration = configuration else { return }
        
        // Add logging handler
        controller.add(LogHandler(), name: "logging")
        configuration.userContentController = controller
        
        // Add Readability script
        let script = WKUserScript(
            source: readabilityJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(script)
    }
    
    private let readabilityJS = #"""
        // First add helper functions that Readability.js expects
        function isProbablyReaderable(doc) {
            // Return true if this document looks like it has interesting content
            return true;
        }
        
        function getReadTime(doc) {
            return 5; // Default 5 min read time
        }
        
        // Add console logging for debugging
        console = {
            log: function(msg) { 
                window.webkit.messageHandlers.logging.postMessage("📝 " + msg);
            },
            error: function(msg) {
                window.webkit.messageHandlers.logging.postMessage("❌ " + msg);
            }
        };
        
        // Then add Readability
        class Readability {
            constructor(doc) {
                this.doc = doc;
            }
            
            parse() {
                try {
                    // Get article content
                    let article = this.doc.querySelector('article') || 
                                this.doc.querySelector('.article') ||
                                this.doc.querySelector('.post') ||
                                this.doc.querySelector('main') ||
                                this.doc.body;
                                
                    // Get title
                    let title = this.doc.querySelector('h1')?.textContent ||
                              this.doc.querySelector('title')?.textContent ||
                              'Untitled';
                              
                    // Get metadata
                    let byline = this.doc.querySelector('meta[name="author"]')?.content;
                    let excerpt = this.doc.querySelector('meta[name="description"]')?.content;
                    let siteName = this.doc.querySelector('meta[property="og:site_name"]')?.content;
                    
                    return {
                        title: title.trim(),
                        content: article.innerHTML,
                        textContent: article.textContent.trim(),
                        byline: byline,
                        excerpt: excerpt,
                        siteName: siteName,
                        length: article.textContent.trim().length
                    };
                } catch (e) {
                    console.error('Parsing error: ' + e.message);
                    return null;
                }
            }
        }
    """#
    
    func parse(url: URL) async throws -> ReaderResult {
        try await withCheckedThrowingContinuation { continuation in
            guard let configuration = configuration else {
                continuation.resume(throwing: ReaderError.parsingFailed)
                return
            }
            
            let webView = WKWebView(frame: .zero, configuration: configuration)
            self.webView = webView
            
            let delegate = LoadDelegate(continuation: continuation) { [weak self] in
                // Cleanup
                self?.webView = nil
                self?.delegate = nil
            }
            self.delegate = delegate
            webView.navigationDelegate = delegate
            
            // Load the URL
            webView.load(URLRequest(url: url))
        }
    }
    
    deinit {
        // Clean up
        webView = nil
        delegate = nil
        controller = nil
        configuration = nil
    }
}

private class LoadDelegate: NSObject, WKNavigationDelegate {
    private let continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>
    private let cleanup: () -> Void
    private var hasCompleted = false
    
    init(continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>, cleanup: @escaping () -> Void) {
        self.continuation = continuation
        self.cleanup = cleanup
        super.init()
    }
    
    private func complete(with result: Result<SafariReaderMode.ReaderResult, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        cleanup()
        
        switch result {
        case .success(let article):
            continuation.resume(returning: article)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                // Wait for page to load
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                let result = try await webView.evaluateJavaScript("""
                    try {
                        let article = new Readability(document).parse();
                        if (!article) {
                            console.error('No article found');
                            throw new Error('No article found');
                        }
                        console.log('Article found:', article.title);
                        JSON.stringify(article);
                    } catch (e) {
                        console.error('Parsing error:', e);
                        throw e;
                    }
                """) as? String
                
                guard let result = result,
                      let data = result.data(using: .utf8),
                      let article = try? JSONDecoder().decode(SafariReaderMode.ReaderResult.self, from: data) else {
                    print("❌ Failed to decode result")
                    complete(with: .failure(SafariReaderMode.ReaderError.parsingFailed))
                    return
                }
                
                print("✅ Successfully parsed article: \(article.title)")
                complete(with: .success(article))
                
            } catch {
                print("❌ JavaScript error: \(error)")
                complete(with: .failure(SafariReaderMode.ReaderError.parsingFailed))
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Navigation failed: \(error)")
        complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Provisional navigation failed: \(error)")
        complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed))
    }
}

// Add logging handler
private class LogHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let msg = message.body as? String {
            print("🌐 WebView: \(msg)")
        }
    }
} 
