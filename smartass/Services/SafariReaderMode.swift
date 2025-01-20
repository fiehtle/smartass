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
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        controller.addUserScript(script)
    }
    
    private let readabilityJS = #"""
        class Readability {
            constructor(doc) {
                this.doc = doc;
            }
            
            parse() {
                try {
                    // First try general purpose parsing
                    let article = this.findMainContent();
                    if (article) {
                        return this.createResult(article);
                    }
                    
                    // If that fails, try site-specific rules
                    if (window.location.hostname.includes('paulgraham.com')) {
                        return this.parsePaulGraham();
                    } else if (window.location.hostname.includes('stripe.press')) {
                        return this.parseStripePress();
                    }
                    
                    throw new Error("Could not parse article");
                } catch (e) {
                    console.error("Parsing error:", e);
                    throw e;
                }
            }
            
            findMainContent() {
                // Try common article containers first
                const candidates = [
                    this.doc.querySelector('article'),
                    this.doc.querySelector('[role="article"]'),
                    this.doc.querySelector('main'),
                    this.doc.querySelector('.post-content'),
                    this.doc.querySelector('.article-content'),
                    this.doc.querySelector('[data-text-content]') // Add Stripe Press selector
                ].filter(Boolean);
                
                for (const candidate of candidates) {
                    if (this.isValidArticle(candidate)) {
                        return candidate;
                    }
                }
                
                return null;
            }
            
            isValidArticle(element) {
                if (!element) return false;
                
                // Check if it has enough text content
                const text = element.textContent || '';
                if (text.length < 140) return false; // Too short
                
                // Check text to link ratio
                const links = element.getElementsByTagName('a');
                const linkText = Array.from(links).reduce((acc, link) => acc + (link.textContent || '').length, 0);
                const textRatio = linkText / text.length;
                if (textRatio > 0.5) return false; // Too many links
                
                return true;
            }
            
            parsePaulGraham() {
                const contentDiv = this.doc.querySelector('#caption');
                if (!contentDiv) {
                    throw new Error("Could not find content div");
                }
                
                return {
                    title: this.doc.title || 'Untitled',
                    content: contentDiv.innerHTML,
                    textContent: contentDiv.textContent,
                    byline: 'Paul Graham',
                    excerpt: null,
                    siteName: 'paulgraham.com',
                    length: contentDiv.textContent.length
                };
            }
            
            parseStripePress() {
                // Find all text content sections
                const sections = Array.from(this.doc.querySelectorAll('[data-text-content]'));
                if (!sections.length) {
                    throw new Error("Could not find Stripe Press content sections");
                }
                
                // Create a container for all sections
                const container = document.createElement('div');
                sections.forEach(section => {
                    container.appendChild(section.cloneNode(true));
                });
                
                return {
                    title: this.doc.title || 'Untitled',
                    content: container.innerHTML,
                    textContent: container.textContent,
                    byline: null,
                    excerpt: null,
                    siteName: 'stripe.press',
                    length: container.textContent.length
                };
            }
            
            createResult(article) {
                return {
                    title: this.doc.title || 'Untitled',
                    content: article.innerHTML,
                    textContent: article.textContent,
                    byline: this.doc.querySelector('meta[name="author"]')?.content || null,
                    excerpt: this.doc.querySelector('meta[name="description"]')?.content || null,
                    siteName: this.doc.querySelector('meta[property="og:site_name"]')?.content || null,
                    length: article.textContent.length
                };
            }
        }
    """#
    
    func parse(url: URL) async throws -> ReaderResult {
        try await withCheckedThrowingContinuation { continuation in
            guard let configuration = configuration else {
                continuation.resume(throwing: ReaderError.parsingFailed)
                return
            }
            
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800), configuration: configuration)
            self.webView = webView
            
            let delegate = LoadDelegate(continuation: continuation) { [weak self] in
                // Cleanup
                self?.webView = nil
                self?.delegate = nil
            }
            self.delegate = delegate
            webView.navigationDelegate = delegate
            
            // Create request with browser-like headers
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
                "Accept-Encoding": "gzip, deflate, br"
            ]
            
            // Load the URL with the custom headers
            webView.load(request)
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
        print("🌐 WebView: Page load finished")
        Task { @MainActor in
            do {
                print("🌐 WebView: Starting JavaScript evaluation")
                
                // First check if we can access the document at all
                let documentReady = try await webView.evaluateJavaScript("""
                    document && document.readyState
                """) as? String
                print("🌐 WebView: Document ready state:", documentReady ?? "nil")
                
                // Wait for initial load
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                // Try to parse with detailed error logging
                let result = try await webView.evaluateJavaScript("""
                    (() => {
                        try {
                            console.log("Starting Readability parse");
                            const reader = new Readability(document);
                            const result = reader.parse();
                            console.log("Parse result:", result);
                            return {
                                success: true,
                                result: result
                            };
                        } catch (error) {
                            console.error("Parsing error:", error);
                            return {
                                success: false,
                                error: error.toString()
                            };
                        }
                    })()
                """) as? [String: Any]
                
                print("🌐 WebView: JavaScript result:", result ?? "nil")
                
                guard let result = result else {
                    throw SafariReaderMode.ReaderError.parsingFailed
                }
                
                if let success = result["success"] as? Bool, !success {
                    print("🌐 WebView: Parsing error:", result["error"] ?? "unknown error")
                    throw SafariReaderMode.ReaderError.parsingFailed
                }
                
                guard let parseResult = result["result"] as? [String: Any] else {
                    throw SafariReaderMode.ReaderError.parsingFailed
                }
                
                // Convert to ReaderResult
                let readerResult = SafariReaderMode.ReaderResult(
                    title: parseResult["title"] as? String ?? "",
                    content: parseResult["content"] as? String ?? "",
                    textContent: parseResult["textContent"] as? String ?? "",
                    byline: parseResult["byline"] as? String,
                    excerpt: parseResult["excerpt"] as? String,
                    siteName: parseResult["siteName"] as? String,
                    length: parseResult["length"] as? Int ?? 0
                )
                
                complete(with: .success(readerResult))
            } catch {
                print("🌐 WebView: Error during parsing:", error)
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
