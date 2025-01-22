//
//  SafariReaderMode.swift
//  smartass
//
//  Created by Viet Le on 1/17/25.
//


// Import WebKit framework which provides web browsing capabilities
import WebKit

// @MainActor ensures this class only runs on the main thread, which is required for UI operations
@MainActor
class SafariReaderMode {
    // Define possible errors that can occur during reading mode operations
    enum ReaderError: Error {
        // Error when page loading fails, with optional underlying error details
        case loadingFailed(underlying: Error?)
        // Error when content parsing fails, with a reason message
        case parsingFailed(reason: String)
        // Error when operation takes too long
        case timeout
        // Error when web configuration is invalid
        case invalidConfiguration
    }
    
    // Define the structure for the parsed article result
    struct ReaderResult: Decodable {
        let title: String       // Article title
        let content: String     // Full HTML content
        let textContent: String // Plain text content
        let byline: String?     // Author information (optional)
        let excerpt: String?    // Article summary (optional)
        let siteName: String?   // Website name (optional)
        let length: Int         // Content length in characters
    }
    
    // Instance properties to maintain state
    // We need to keep strong references to prevent automatic cleanup
    private var webView: WKWebView?                    // The web view that loads the page
    private var delegate: LoadDelegate?                // Handles web view events
    private var configuration: WKWebViewConfiguration?  // Web view configuration
    private var controller: WKUserContentController?   // Manages JavaScript injection
    
    // Initialize the SafariReaderMode
    init() {
        // Create new configuration and controller instances
        self.configuration = WKWebViewConfiguration()
        self.controller = WKUserContentController()
        
        // Force unwrap is safe here since we just created these
        let controller = self.controller!
        let configuration = self.configuration!
        
        // Add a handler to receive JavaScript console logs
        controller.add(LogHandler(), name: "logging")
        configuration.userContentController = controller
        
        // Inject our Readability JavaScript code when the page loads
        let script = WKUserScript(
            source: readabilityJS,
            injectionTime: .atDocumentEnd,  // Run after page loads
            forMainFrameOnly: true          // Only run in main frame, not iframes
        )
        controller.addUserScript(script)
    }
    
    // JavaScript code that extracts readable content from web pages
    private let readabilityJS = #"""
        class Readability {
            constructor(doc) {
                this.doc = doc;
            }
            
            parse() {
                try {
                    console.log("Starting Readability parse");
                    // Try different content finding strategies in order
                    const article = 
                        this.findByMainContent() ||
                        this.findByTextDensity() ||
                        this.findByDynamicContent();
                    
                    if (article) {
                        console.log("Found article content, length:", article.textContent.length);
                        console.log("Content preview:", article.textContent.substring(0, 200));
                        return this.createResult(article);
                    }
                    
                    throw new Error("Could not parse article");
                } catch (e) {
                    console.error("Parsing error:", e);
                    throw e;
                }
            }
            
            findByMainContent() {
                console.log("Trying findByMainContent strategy");
                // Try common article containers and semantic HTML
                const candidates = [
                    // Stripe Press specific selectors
                    this.doc.querySelector('.chapter-content'),
                    this.doc.querySelector('.content-section'),
                    this.doc.querySelector('.text-content'),
                    this.doc.querySelector('.chapter-text'),
                    this.doc.querySelector('.chapter'),
                    // Common article containers
                    this.doc.querySelector('article'),
                    this.doc.querySelector('[role="article"]'),
                    this.doc.querySelector('main'),
                    this.doc.querySelector('.post-content'),
                    this.doc.querySelector('.article-content'),
                    this.doc.querySelector('.content'),
                    this.doc.querySelector('#content')
                ].filter(Boolean);
                
                console.log("Found candidates:", candidates.length);
                
                // If we find multiple content sections, combine them
                if (candidates.length > 1) {
                    console.log("Combining multiple content sections");
                    const container = this.doc.createElement('div');
                    candidates.forEach(candidate => {
                        console.log("Adding section, length:", candidate.textContent.length);
                        container.appendChild(candidate.cloneNode(true));
                    });
                    return container;
                }
                
                const found = candidates.find(this.isValidArticle.bind(this));
                console.log("Found valid article:", found ? "yes" : "no");
                return found;
            }
            
            findByTextDensity() {
                console.log("Trying findByTextDensity strategy");
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
                                console.log("Found better element, score:", score, "length:", text.length);
                            }
                        }
                        Array.from(node.children).forEach(walk);
                    }
                };
                
                walk(body);
                return bestElement;
            }
            
            findByDynamicContent() {
                console.log("Trying findByDynamicContent strategy");
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
                
                console.log("Found dynamic candidates:", candidates.length);
                return candidates.find(this.isValidArticle.bind(this));
            }
            
            isValidArticle(element) {
                if (!element) return false;
                
                const text = element.textContent || '';
                console.log("Validating article, text length:", text.length);
                
                if (text.length < 140) {
                    console.log("Too short");
                    return false;
                }
                
                // Check text to markup ratio
                const markup = element.innerHTML || '';
                const textDensity = text.length / markup.length;
                console.log("Text density:", textDensity);
                
                if (textDensity < 0.2) {
                    console.log("Too much markup");
                    return false;
                }
                
                // Check text to link ratio
                const links = element.getElementsByTagName('a');
                const linkText = Array.from(links).reduce((acc, link) => 
                    acc + (link.textContent || '').length, 0);
                const textRatio = linkText / text.length;
                console.log("Link ratio:", textRatio);
                
                if (textRatio > 0.5) {
                    console.log("Too many links");
                    return false;
                }
                
                return true;
            }
            
            createResult(article) {
                console.log("Creating final result");
                // Find the best title
                const title = 
                    this.doc.querySelector('h1')?.textContent ||
                    this.doc.querySelector('meta[property="og:title"]')?.content ||
                    this.doc.title ||
                    'Untitled';
                
                const result = {
                    title: title,
                    content: article.innerHTML,
                    textContent: article.textContent,
                    byline: this.doc.querySelector('meta[name="author"]')?.content || null,
                    excerpt: this.doc.querySelector('meta[name="description"]')?.content || null,
                    siteName: this.doc.querySelector('meta[property="og:site_name"]')?.content || null,
                    length: article.textContent.length
                };
                
                console.log("Final result length:", result.length);
                console.log("Content preview:", result.textContent.substring(0, 200));
                return result;
            }
        }
    """#
    
    // Main function to parse a webpage at the given URL
    func parse(url: URL) async throws -> ReaderResult {
        // Check if the task has been cancelled
        try Task.checkCancellation()
        
        // Use continuation to bridge between async/await and completion handler style
        return try await withCheckedThrowingContinuation { continuation in
            // Ensure configuration exists
            guard let configuration = configuration else {
                continuation.resume(throwing: ReaderError.parsingFailed(reason: "Invalid configuration"))
                return
            }
            
            // Create a web view with reasonable dimensions
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800), configuration: configuration)
            self.webView = webView
            
            // Create and set up the delegate to handle web view events
            let delegate = LoadDelegate(continuation: continuation) { [weak self] in
                // Cleanup closure to prevent memory leaks
                self?.webView = nil
                self?.delegate = nil
            }
            self.delegate = delegate
            webView.navigationDelegate = delegate
            
            // Set up the request with browser-like headers to avoid website blocks
            var request = URLRequest(url: url)
            request.allHTTPHeaderFields = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
                "Accept-Encoding": "gzip, deflate, br"
            ]
            
            // Start loading the webpage
            webView.load(request)
        }
    }
    
    // Clean up resources when this object is destroyed
    deinit {
        webView = nil
        delegate = nil
        controller = nil
        configuration = nil
    }
}

// Delegate class to handle web view loading events
private class LoadDelegate: NSObject, WKNavigationDelegate {
    // Store the continuation to resume async function
    private let continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>
    private let cleanup: () -> Void
    private var hasCompleted = false
    private var timeoutTask: Task<Void, Never>?
    
    // Initialize the delegate
    init(continuation: CheckedContinuation<SafariReaderMode.ReaderResult, Error>, cleanup: @escaping () -> Void) {
        self.continuation = continuation
        self.cleanup = cleanup
        super.init()
        
        // Set up timeout task
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: nil)))
        }
    }
    
    // Helper function to complete the operation exactly once
    private func complete(with result: Result<SafariReaderMode.ReaderResult, Error>) {
        timeoutTask?.cancel()
        guard !hasCompleted else { return }
        hasCompleted = true
        cleanup()
        
        // Resume the async function with success or failure
        switch result {
        case .success(let article):
            continuation.resume(returning: article)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
    
    // Called when page finishes loading
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🌐 WebView: Page load finished")
        Task { @MainActor in
            do {
                // Check if document is accessible
                let documentReady = try await webView.evaluateJavaScript("""
                    document && document.readyState
                """) as? String
                
                // Wait for any dynamic content to load
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                // Run our Readability parser
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
                
                // Process the JavaScript result
                guard let result = result else {
                    throw SafariReaderMode.ReaderError.parsingFailed(reason: "No result from JavaScript")
                }
                
                // Check for parsing success
                if let success = result["success"] as? Bool, !success {
                    throw SafariReaderMode.ReaderError.parsingFailed(reason: result["error"] as? String ?? "unknown error")
                }
                
                // Extract the parsed result
                guard let parseResult = result["result"] as? [String: Any] else {
                    throw SafariReaderMode.ReaderError.parsingFailed(reason: "No valid result format")
                }
                
                // Convert JavaScript result to Swift ReaderResult
                let readerResult = SafariReaderMode.ReaderResult(
                    title: parseResult["title"] as? String ?? "",
                    content: parseResult["content"] as? String ?? "",
                    textContent: parseResult["textContent"] as? String ?? "",
                    byline: parseResult["byline"] as? String,
                    excerpt: parseResult["excerpt"] as? String,
                    siteName: parseResult["siteName"] as? String,
                    length: parseResult["length"] as? Int ?? 0
                )
                
                // Complete successfully with the parsed result
                complete(with: .success(readerResult))
            } catch {
                // Handle any errors during the process
                complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: error)))
            }
        }
    }
    
    // Handle navigation failures
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: error)))
    }
    
    // Handle early navigation failures (like invalid URLs)
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        complete(with: .failure(SafariReaderMode.ReaderError.loadingFailed(underlying: error)))
    }
}

// Handler for JavaScript console logs
private class LogHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Print JavaScript console messages to Swift console
        if let msg = message.body as? String {
            print("🌐 WebView: \(msg)")
        }
    }
}
