//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import SwiftUI

struct ArticleContentView: View {
    let content: [Article.ContentBlock]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(content) { block in
                switch block.type {
                case .heading(let level):
                    Text(block.content)
                        .font(headingFont(for: level))
                        .fontWeight(.bold)
                        .padding(.top, headingPadding(for: level))
                    
                case .paragraph:
                    Text(block.content)
                        .font(.body)
                        .lineSpacing(8)
                    
                case .quote:
                    Text(block.content)
                        .italic()
                        .padding(.horizontal)
                        .overlay(
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 4)
                                .padding(.vertical, 4),
                            alignment: .leading
                        )
                    
                case .list(let ordered):
                    if ordered {
                        Text(block.content) // TODO: Implement ordered list
                    } else {
                        HStack(alignment: .top) {
                            Text("•")
                            Text(block.content)
                        }
                    }
                    
                case .code:
                    Text(block.content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                case .image(let alt):
                    // TODO: Implement image loading
                    if let alt = alt {
                        Text(alt)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .textSelection(.enabled) // Enable text selection for copy/paste and context menu
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        default: return .headline
        }
    }
    
    private func headingPadding(for level: Int) -> CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 16
        default: return 12
        }
    }
} 