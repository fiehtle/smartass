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
                    this.doc.querySelector('.article-content')
                ].filter(Boolean); // Remove null values
                
                for (const candidate of candidates) {
                    if (this.isValidArticle(candidate)) {
                        return candidate;
                    }
                }
                
                return null; // Will trigger site-specific parsing
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
        print("🌐 WebView: Page load finished")
        Task { @MainActor in
            do {
                print("🌐 WebView: Starting JavaScript evaluation")
                
                // First let's check what we're working with
                let documentHTML = try await webView.evaluateJavaScript("""
                    document.documentElement.outerHTML
                """) as? String
                print("🌐 WebView: Document HTML:", documentHTML ?? "nil")
                
                let result = try await webView.evaluateJavaScript("""
                    (() => {
                        console.log("Starting Readability parse");
                        const reader = new Readability(document);
                        const result = reader.parse();
                        console.log("Parse result:", result);
                        return result;
                    })()
                """) as? [String: Any]
                
                print("🌐 WebView: JavaScript result:", result ?? "nil")
                
                guard let result = result else {
                    throw SafariReaderMode.ReaderError.parsingFailed
                }
                
                // Convert to ReaderResult
                let readerResult = SafariReaderMode.ReaderResult(
                    title: result["title"] as? String ?? "",
                    content: result["content"] as? String ?? "",
                    textContent: result["textContent"] as? String ?? "",
                    byline: result["byline"] as? String,
                    excerpt: result["excerpt"] as? String,
                    siteName: result["siteName"] as? String,
                    length: result["length"] as? Int ?? 0
                )
                
                complete(with: .success(readerResult))
            } catch {
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
