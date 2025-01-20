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
        case loadingFailed(underlying: Error?)
        case parsingFailed(reason: String)
        case timeout
        case invalidConfiguration
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
        
        let controller = self.controller!
        let configuration = self.configuration!
        
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
                    // Try different content finding strategies in order
                    const article = 
                        this.findByMainContent() ||
                        this.findByTextDensity() ||
                        this.findByDynamicContent();
                    
                    if (article) {
                        return this.createResult(article);
                    }
                    
                    throw new Error("Could not parse article");
                } catch (e) {
                    console.error("Parsing error:", e);
                    throw e;
                }
            }
            
            findByMainContent() {
                // Try common article containers and semantic HTML
                const candidates = [
                    this.doc.querySelector('article'),
                    this.doc.querySelector('[role="article"]'),
                    this.doc.querySelector('main'),
                    this.doc.querySelector('.post-content'),
                    this.doc.querySelector('.article-content'),
                    this.doc.querySelector('.content'),
                    this.doc.querySelector('#content')
                ].filter(Boolean);
                
                return candidates.find(this.isValidArticle.bind(this));
            }
            
            findByTextDensity() {
                // Find the element with the highest text-to-markup ratio
                const body = this.doc.body;
                if (!body) return null;
                
                let bestElement = null;
                let bestScore = 0;
                
                const walk = (node) => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        const text = node.textContent || '';
                        const markup = node.innerHTML || '';
                        if (text.length > 140) { // Minimum text threshold
                            const score = text.length / markup.length;
                            if (score > bestScore) {
                                bestScore = score;
                                bestElement = node;
                            }
                        }
                        Array.from(node.children).forEach(walk);
                    }
                };
                
                walk(body);
                return bestElement;
            }
            
            findByDynamicContent() {
                // Look for elements that might contain dynamic content
                const candidates = [
                    // Data attributes often used for dynamic content
                    ...Array.from(this.doc.querySelectorAll('[data-content]')),
                    ...Array.from(this.doc.querySelectorAll('[data-text-content]')),
                    ...Array.from(this.doc.querySelectorAll('[data-article]')),
                    
                    // Common dynamic content containers
                    ...Array.from(this.doc.querySelectorAll('.dynamic-content')),
                    ...Array.from(this.doc.querySelectorAll('.lazy-content')),
                    
                    // Find elements with substantial text content
                    ...Array.from(this.doc.querySelectorAll('*')).filter(el => {
                        const text = el.textContent || '';
                        return text.length > 1000; // Substantial text threshold
                    })
                ];
                
                return candidates.find(this.isValidArticle.bind(this));
            }
            
            isValidArticle(element) {
                if (!element) return false;
                
                const text = element.textContent || '';
                if (text.length < 140) return false; // Too short
                
                // Check text to markup ratio
                const markup = element.innerHTML || '';
                const textDensity = text.length / markup.length;
                if (textDensity < 0.2) return false; // Too much markup
                
                // Check text to link ratio
                const links = element.getElementsByTagName('a');
                const linkText = Array.from(links).reduce((acc, link) => 
                    acc + (link.textContent || '').length, 0);
                const textRatio = linkText / text.length;
                if (textRatio > 0.5) return false; // Too many links
                
                // Check for common article indicators
                const hasArticleStructure = 
                    element.querySelector('h1, h2, h3, p') !== null ||
                    element.matches('article, [role="article"], main, .post-content, .article-content');
                
                return hasArticleStructure;
            }
            
            createResult(article) {
                // Find the best title
                const title = 
                    this.doc.querySelector('h1')?.textContent ||
                    this.doc.querySelector('meta[property="og:title"]')?.content ||
                    this.doc.title ||
                    'Untitled';
                
                return {
                    title: title,
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
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            guard let configuration = configuration else {
                continuation.resume(throwing: ReaderError.parsingFailed(reason: "Invalid configuration"))
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
    private var timeoutTask: Task<Void, Never>?
    
    init(continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>, cleanup: @escaping () -> Void) {
        self.continuation = continuation
        self.cleanup = cleanup
        super.init()
        
        // Add timeout
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: nil)))
        }
    }
    
    private func complete(with result: Result<SafariReaderMode.ReaderResult, Error>) {
        timeoutTask?.cancel()
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
                    throw SafariReaderMode.ReaderError.parsingFailed(reason: "No result from JavaScript")
                }
                
                if let success = result["success"] as? Bool, !success {
                    print("🌐 WebView: Parsing error:", result["error"] ?? "unknown error")
                    throw SafariReaderMode.ReaderError.parsingFailed(reason: result["error"] as? String ?? "unknown error")
                }
                
                guard let parseResult = result["result"] as? [String: Any] else {
                    throw SafariReaderMode.ReaderError.parsingFailed(reason: "No valid result format")
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
                complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: error)))
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Navigation failed: \(error)")
        complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: error)))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ Provisional navigation failed: \(error)")
        complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: error)))
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
