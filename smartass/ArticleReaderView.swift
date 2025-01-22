//
//  ArticleReaderView.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//


import SwiftUI

struct ArticleReaderView: View {
    let articleURL: String
    @StateObject private var viewModel = ArticleReaderViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                }
            } else if let article = viewModel.article {
                VStack(alignment: .leading, spacing: 16) {
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let author = article.author {
                        Text("By \(author)")
                            .foregroundColor(.secondary)
                    }
                    
                    HTMLContent(html: article.content)
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchArticle(from: articleURL)
        }
    }
}

// Simple UIViewRepresentable for HTML rendering
private struct HTMLContent: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        let htmlTemplate = """
        <html>
        <head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <style>
        body {
            font-family: -apple-system;
            font-size: 17px;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
        }
        p { margin: 1em 0; }
        img { max-width: 100%; height: auto; }
        pre { overflow-x: auto; }
        </style>
        </head>
        <body>
        \(html)
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
            textView.attributedText = attributedString
        }
    }
}

#Preview {
    NavigationStack {
        ArticleReaderView(articleURL: "https://example.com")
    }
} 
