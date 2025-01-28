import Foundation

struct DisplayArticle {
    let title: String
    let author: String?
    let content: [ContentBlock]
    let estimatedReadingTime: TimeInterval?
    
    struct ContentBlock: Identifiable {
        let id = UUID()
        let type: BlockType
        let content: String
        var metadata: [String: String]?
        
        enum BlockType {
            case paragraph
            case heading(level: Int)
            case quote
            case list(ordered: Bool)
            case code
            case image(alt: String?)
        }
    }
}

extension DisplayArticle {
    var textContent: String {
        content.map { block in
            switch block.type {
            case .heading:
                return "\n\(block.content)\n"
            case .paragraph:
                return block.content
            case .quote:
                return "\"\(block.content)\""
            case .list:
                return "• \(block.content)"
            case .code:
                return block.content
            case .image(let alt):
                return alt ?? ""
            }
        }.joined(separator: "\n")
    }
} 
