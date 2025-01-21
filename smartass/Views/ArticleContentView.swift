//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import SwiftUI

struct ArticleContentView: View {
    let htmlContent: String
    
    var body: some View {
        ArticleTextView(htmlContent: htmlContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ArticleTextView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> UITextView {
        print("📱 Creating UITextView")
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        print("🔄 Updating UITextView with content length: \(htmlContent.count)")
        
        let htmlTemplate = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system;
                    font-size: 17px;
                    line-height: 1.5;
                    margin: 0;
                    padding: 16px;
                    color: #1c1c1e;
                }
                
                /* Text blocks with improved spacing */
                p, div, article, section, main {
                    margin: 0 0 1em 0;
                }
                
                /* Headers with system font weights */
                h1, h2, h3, h4, h5, h6 {
                    font-family: -apple-system;
                    margin: 1.5em 0 0.8em 0;
                    line-height: 1.3;
                }
                
                h1 { 
                    font-size: 28px;
                    font-weight: 700;
                    margin-top: 0;
                }
                h2 { 
                    font-size: 24px;
                    font-weight: 600;
                }
                h3 { 
                    font-size: 20px;
                    font-weight: 600;
                }
                h4, h5, h6 { 
                    font-size: 17px;
                    font-weight: 600;
                }
                
                /* Lists with native spacing */
                ul, ol {
                    margin: 1em 0;
                    padding-left: 1.5em;
                }
                
                li {
                    margin: 0.3em 0;
                }
                
                /* Native-style blockquotes */
                blockquote {
                    margin: 1em 0;
                    padding-left: 1em;
                    border-left: 2px solid #8e8e93;
                    color: #636366;
                }
                
                /* Native-style links */
                a {
                    color: #007AFF;
                    text-decoration: none;
                }
                
                /* Code blocks with SF Mono */
                pre, code {
                    font-family: "SF Mono", monospace;
                    font-size: 15px;
                    background: #f2f2f7;
                    border-radius: 6px;
                }
                
                code {
                    padding: 0.2em 0.4em;
                }
                
                pre {
                    padding: 1em;
                    overflow-x: auto;
                    margin: 1em 0;
                }
                
                pre code {
                    padding: 0;
                    background: none;
                }
                
                /* Improved text wrapping */
                * {
                    overflow-wrap: break-word;
                    word-wrap: break-word;
                    -webkit-hyphens: auto;
                    hyphens: auto;
                }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        print("📝 Final HTML template length: \(htmlTemplate.count)")
        
        if let data = htmlTemplate.data(using: .utf8),
           let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil) {
            
            print("✅ Successfully created attributed string")
            DispatchQueue.main.async {
                textView.attributedText = attributedString
                textView.sizeToFit()
            }
        } else {
            print("❌ Failed to create attributed string")
        }
    }
} 
