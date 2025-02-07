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
        static let titleLarge = Font.custom("HelveticaNeue-Bold", size: 34)
        static let title = Font.custom("HelveticaNeue-Medium", size: 22)
        static let headline = Font.custom("HelveticaNeue-Medium", size: 17)
        static let body = Font.custom("HelveticaNeue", size: 17)
        static let footnote = Font.custom("HelveticaNeue", size: 13)
        static let caption = Font.custom("HelveticaNeue", size: 12)
        
        // Fallback to system font if Helvetica is not available
        static func customFont(_ font: Font) -> Font {
            if UIFont(name: "HelveticaNeue", size: 17) != nil {
                return font
            }
            // Convert custom font size to system font
            switch font {
            case titleLarge: return .system(size: 34, weight: .bold)
            case title: return .system(size: 22, weight: .medium)
            case headline: return .system(size: 17, weight: .medium)
            case body: return .system(size: 17, weight: .regular)
            case footnote: return .system(size: 13, weight: .regular)
            case caption: return .system(size: 12, weight: .regular)
            default: return font
            }
        }
    }
    
    static func configureListAppearance() {
        UITableView.appearance().backgroundColor = UIColor(Color.background)
        UITableViewCell.appearance().backgroundColor = UIColor(Color.surface)
    }
}

extension Font {
    static func smartAssFont(_ font: Font) -> Font {
        SmartAssDesign.Typography.customFont(font)
    }
}

// Helper extension to create colors from hex values
extension Color {
    static var background: Color { SmartAssDesign.Colors.background }
    static var surface: Color { SmartAssDesign.Colors.surface }
    static var accent: Color { SmartAssDesign.Colors.accent }
    
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
