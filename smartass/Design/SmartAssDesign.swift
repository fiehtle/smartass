//
//  SmartAssDesign.swift
//  smartass
//
//  Created by Viet Le on 2/5/25.
//


import SwiftUI

enum SmartAssDesign {
    enum Colors {
        static let background = Color(hex: "E4E4E4")
        static let surface = Color(hex: "F7F7F7")
        static let accent = Color(hex: "F1711F")
    }
    
    enum Typography {
        static let titleLarge = Font.custom("Helvetica", size: 28, relativeTo: .title)
        static let title = Font.custom("Helvetica", size: 22, relativeTo: .title2)
        static let headline = Font.custom("Helvetica", size: 17, relativeTo: .headline)
        static let body = Font.custom("Helvetica", size: 17, relativeTo: .body)
        static let footnote = Font.custom("Helvetica", size: 13, relativeTo: .footnote)
        static let caption = Font.custom("Helvetica", size: 12, relativeTo: .caption)
    }
}

// Helper extension to create colors from hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 