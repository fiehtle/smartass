import Foundation

struct Article: Identifiable {
    let id = UUID()
    let url: String
    let title: String
    let content: String
    let author: String?
    let datePublished: Date?
    let estimatedReadingTime: Int?
} 