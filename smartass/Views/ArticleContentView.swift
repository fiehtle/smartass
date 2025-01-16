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
            .frame(maxWidth: .infinity)
    }
}

struct ArticleTextView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = .preferredFont(forTextStyle: .body)
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let htmlTemplate = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system;
                    font-size: 17px;
                    line-height: 1.6;
                    margin: 0;
                    padding: 0;
                }
                img { max-width: 100%; height: auto; }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        if let data = htmlTemplate.data(using: .utf8),
           let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil) {
            
            DispatchQueue.main.async {
                textView.attributedText = attributedString
            }
        }
    }
} 
