//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import SwiftUI
import CoreData
import UIKit

private struct OpenAIServiceKey: EnvironmentKey {
    static let defaultValue: OpenAIService = OpenAIService()
}

extension EnvironmentValues {
    var openAIService: OpenAIService {
        get { self[OpenAIServiceKey.self] }
        set { self[OpenAIServiceKey.self] = newValue }
    }
}

// Custom UITextView to override menu items
class CustomTextView: UITextView {
    var onSmartContext: ((String) -> Void)?
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(smartContextAction) {
            return true
        }
        return false
    }
    
    @objc func smartContextAction() {
        guard let selectedRange = selectedTextRange,
              let selectedText = text(in: selectedRange)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selectedText.isEmpty
        else { return }
        
        onSmartContext?(selectedText)
    }
}

// Native text view with selection support
struct NativeTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let onSmartContext: (String) -> Void
    let highlights: [Highlight]
    let onHighlightTapped: (Highlight) -> Void
    
    func makeUIView(context: Context) -> CustomTextView {
        let textView = CustomTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.delegate = context.coordinator
        textView.onSmartContext = onSmartContext
        
        // Enable link interaction
        textView.isUserInteractionEnabled = true
        textView.linkTextAttributes = [
            .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
            .foregroundColor: UIColor.label
        ]
        
        return textView
    }
    
    func updateUIView(_ textView: CustomTextView, context: Context) {
        // Create mutable attributed string from the base text
        let mutableText = NSMutableAttributedString(attributedString: attributedText)
        
        // Add highlights with dotted underlines
        for highlight in highlights {
            if let range = findRange(of: highlight.selectedText ?? "", in: mutableText.string) {
                // Add link attribute for the highlight
                mutableText.addAttribute(.link, value: highlight.id?.uuidString ?? "", range: range)
            }
        }
        
        textView.attributedText = mutableText
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Helper to find range of highlighted text
    private func findRange(of text: String, in string: String) -> NSRange? {
        guard let range = string.range(of: text) else { return nil }
        return NSRange(range, in: string)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NativeTextView
        
        init(_ parent: NativeTextView) {
            self.parent = parent
        }
        
        // Handle taps on highlighted text
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let highlightId = UUID(uuidString: URL.absoluteString),
               let highlight = parent.highlights.first(where: { h in h.id == highlightId }) {
                parent.onHighlightTapped(highlight)
            }
            return false
        }
        
        // Original menu handling
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0 else { return nil }
            
            let smartContextAction = UIAction(title: "Smart Context", image: nil) { _ in
                if let selectedText = textView.text(in: textView.selectedTextRange!)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !selectedText.isEmpty,
                   let customTextView = textView as? CustomTextView {
                    customTextView.onSmartContext?(selectedText)
                }
            }
            
            return UIMenu(children: [smartContextAction])
        }
    }
}

extension UIResponder {
    private static weak var _currentFirstResponder: UIResponder?
    
    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(findFirstResponder), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }
    
    @objc private func findFirstResponder() {
        UIResponder._currentFirstResponder = self
    }
}

struct ArticleContentView: View {
    let article: DisplayArticle
    @StateObject private var viewModel: ArticleContentViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    init(article: DisplayArticle) {
        self.article = article
        self._viewModel = StateObject(wrappedValue: ArticleContentViewModel(article: article))
        print("📱 ArticleContentView init with \(article.content.count) blocks")
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Content sections
                ForEach(combinedBlocks, id: \.id) { section in
                    NativeTextView(
                        attributedText: section.attributedText,
                        onSmartContext: { selectedText in
                            Task {
                                await viewModel.generateSmartContext(for: selectedText)
                            }
                        },
                        highlights: viewModel.highlights,
                        onHighlightTapped: { highlight in
                            Task {
                                await viewModel.handleHighlightTapped(highlight)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            print("📱 ScrollView appeared with \(combinedBlocks.count) sections")
        }
        .sheet(isPresented: $viewModel.showSmartContextSheet) {
            if let highlight = viewModel.currentHighlight {
                SmartContextSheet(
                    selectedText: highlight.text,
                    explanation: highlight.explanation,
                    citations: highlight.citations,
                    isPresented: $viewModel.showSmartContextSheet,
                    onDelete: highlight.explanation != nil ? {
                        // Only show delete for existing highlights (not loading state)
                        Task {
                            if let storedHighlight = viewModel.highlights.first(where: { h in h.selectedText == highlight.text }) {
                                try await viewModel.deleteHighlight(storedHighlight)
                            }
                        }
                    } : nil
                )
            }
        }
    }
    
    // Combined blocks structure
    private struct CombinedSection: Identifiable {
        let id = UUID()
        let attributedText: NSAttributedString
    }
    
    // Combine consecutive blocks into sections
    private var combinedBlocks: [CombinedSection] {
        var sections: [CombinedSection] = []
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 12
        paragraphStyle.lineSpacing = 6
        
        var currentText = NSMutableAttributedString()
        var isFirstBlock = true
        var hasSkippedTitle = false
        
        print("🔄 Processing \(article.content.count) blocks into sections")
        
        for block in article.content {
            // Skip the first heading if it matches the article title
            if !hasSkippedTitle, case .heading(_) = block.type, block.content == article.title {
                hasSkippedTitle = true
                continue
            }
            
            let blockText = NSMutableAttributedString()
            
            // Add spacing between blocks
            if !isFirstBlock {
                blockText.append(NSAttributedString(string: "\n"))
            }
            
            // Format based on block type
            switch block.type {
            case .heading(let level):
                let font = UIFont.preferredFont(forTextStyle: headingTextStyle(for: level)).withWeight(.bold)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor { $0.userInterfaceStyle == .dark ? .white : .black },
                    .paragraphStyle: paragraphStyle
                ]
                blockText.append(NSAttributedString(string: block.content, attributes: attributes))
                
                // Start a new section after headings
                if !currentText.string.isEmpty {
                    sections.append(CombinedSection(attributedText: currentText))
                    currentText = NSMutableAttributedString()
                    isFirstBlock = true
                }
                sections.append(CombinedSection(attributedText: blockText))
                continue
                
            case .paragraph:
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: UIColor { $0.userInterfaceStyle == .dark ? .white : .black },
                    .paragraphStyle: paragraphStyle
                ]
                blockText.append(NSAttributedString(string: block.content, attributes: attributes))
                
            case .quote:
                let font = UIFont.preferredFont(forTextStyle: .body).withTraits(.traitItalic)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor { $0.userInterfaceStyle == .dark ? .white : .black },
                    .paragraphStyle: paragraphStyle
                ]
                blockText.append(NSAttributedString(string: block.content, attributes: attributes))
                
            case .list(let ordered):
                let text = ordered ? "\(block.content)" : "• \(block.content)"
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.preferredFont(forTextStyle: .body),
                    .foregroundColor: UIColor { $0.userInterfaceStyle == .dark ? .white : .black },
                    .paragraphStyle: paragraphStyle
                ]
                blockText.append(NSAttributedString(string: text, attributes: attributes))
                
            case .code:
                // Code blocks get their own section
                if !currentText.string.isEmpty {
                    sections.append(CombinedSection(attributedText: currentText))
                    currentText = NSMutableAttributedString()
                    isFirstBlock = true
                }
                let codeStyle = NSMutableParagraphStyle()
                codeStyle.paragraphSpacing = 12
                let font = UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor { $0.userInterfaceStyle == .dark ? .white : .black },
                    .paragraphStyle: codeStyle,
                    .backgroundColor: UIColor.systemGray6
                ]
                blockText.append(NSAttributedString(string: block.content, attributes: attributes))
                sections.append(CombinedSection(attributedText: blockText))
                continue
                
            case .image:
                // Images get their own section
                if !currentText.string.isEmpty {
                    sections.append(CombinedSection(attributedText: currentText))
                    currentText = NSMutableAttributedString()
                    isFirstBlock = true
                }
                continue
            }
            
            currentText.append(blockText)
            isFirstBlock = false
        }
        
        // Add any remaining text
        if !currentText.string.isEmpty {
            sections.append(CombinedSection(attributedText: currentText))
        }
        
        print("✅ Created \(sections.count) combined sections")
        return sections
    }
    
    private func headingTextStyle(for level: Int) -> UIFont.TextStyle {
        switch level {
        case 1: return .title1
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }
}

extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0)
    }
    
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let newDescriptor = fontDescriptor.addingAttributes([.traits: [
            UIFontDescriptor.TraitKey.weight: weight
        ]])
        return UIFont(descriptor: newDescriptor, size: 0)
    }
} 
