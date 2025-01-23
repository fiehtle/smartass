//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import SwiftUI

struct ArticleContentView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Content blocks
            ForEach(article.content) { block in
                switch block.type {
                case .heading(let level):
                    Text(block.content)
                        .font(.system(size: headingSize(for: level), weight: .bold))
                        .padding(.vertical, 8)
                        .applyFormatting(metadata: block.metadata)
                    
                case .paragraph:
                    Text(block.content)
                        .font(.system(size: 16))
                        .lineSpacing(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .applyFormatting(metadata: block.metadata)
                    
                case .quote:
                    Text(block.content)
                        .font(.system(size: 16))
                        .italic()
                        .padding(.leading)
                        .overlay(
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: 4)
                                .padding(.leading),
                            alignment: .leading
                        )
                        .applyFormatting(metadata: block.metadata)
                    
                case .list(let ordered):
                    HStack(alignment: .top) {
                        if ordered {
                            Text("\u{2022}")
                                .font(.system(size: 16))
                        }
                        Text(block.content)
                            .font(.system(size: 16))
                            .applyFormatting(metadata: block.metadata)
                    }
                    
                case .code:
                    Text(block.content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                case .image(let alt):
                    if let imageURL = URL(string: block.content) {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        if let alt = alt, !alt.isEmpty {
                            Text(alt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: 680)
    }
    
    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 32
        case 2: return 28
        case 3: return 24
        case 4: return 20
        case 5: return 18
        case 6: return 16
        default: return 16
        }
    }
}

extension View {
    func applyFormatting(metadata: [String: String]?) -> some View {
        self
            .italic(metadata?["emphasis"] == "true")
            .fontWeight(metadata?["bold"] == "true" ? .bold : .regular)
    }
} 
