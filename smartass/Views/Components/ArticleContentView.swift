//
//  ArticleContentView.swift
//  smartass
//
//  Created by Viet Le on 1/22/25.
//


import SwiftUI
import CoreData

private struct OpenAIServiceKey: EnvironmentKey {
    static let defaultValue: OpenAIService = OpenAIService()
}

extension EnvironmentValues {
    var openAIService: OpenAIService {
        get { self[OpenAIServiceKey.self] }
        set { self[OpenAIServiceKey.self] = newValue }
    }
}

struct ArticleContentView: View {
    let article: DisplayArticle
    @StateObject private var viewModel: ArticleContentViewModel
    
    init(article: DisplayArticle) {
        self.article = article
        self._viewModel = StateObject(wrappedValue: ArticleContentViewModel(article: article))
    }
    
    var body: some View {
        ZStack {
            // Article content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(article.content.enumerated()), id: \.element.id) { _, block in
                        switch block.type {
                        case .paragraph:
                            Text(block.content)
                                .font(.body)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = block.content
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            await viewModel.generateSmartContext(for: block.content)
                                        }
                                    }) {
                                        Label("Smart Context", systemImage: "brain")
                                    }
                                }
                        case .heading(let level):
                            Text(block.content)
                                .font(headingFont(for: level))
                                .fontWeight(.semibold)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = block.content
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            await viewModel.generateSmartContext(for: block.content)
                                        }
                                    }) {
                                        Label("Smart Context", systemImage: "brain")
                                    }
                                }
                        case .quote:
                            Text(block.content)
                                .italic()
                                .padding(.leading)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = block.content
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            await viewModel.generateSmartContext(for: block.content)
                                        }
                                    }) {
                                        Label("Smart Context", systemImage: "brain")
                                    }
                                }
                        case .list(let ordered):
                            Text(ordered ? "\(block.content)" : "• \(block.content)")
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = block.content
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            await viewModel.generateSmartContext(for: block.content)
                                        }
                                    }) {
                                        Label("Smart Context", systemImage: "brain")
                                    }
                                }
                        case .code:
                            Text(block.content)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button(action: {
                                        UIPasteboard.general.string = block.content
                                    }) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                }
                        case .image(let alt):
                            if let url = URL(string: block.content) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                                }
                                if let alt = alt {
                                    Text(alt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Smart Context Sidebar
            if viewModel.showSmartContextSidebar, let article = viewModel.storedArticle {
                SmartContextSidebar(article: article, isPresented: $viewModel.showSmartContextSidebar)
                    .transition(.move(edge: .trailing))
            }
        }
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }
}

// Helper view to observe text selection
struct TextSelectionObserver: UIViewRepresentable {
    let onSelectionChanged: (String?) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged),
            name: UIMenuController.didShowMenuNotification,
            object: nil
        )
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChanged: onSelectionChanged)
    }
    
    class Coordinator: NSObject {
        let onSelectionChanged: (String?) -> Void
        
        init(onSelectionChanged: @escaping (String?) -> Void) {
            self.onSelectionChanged = onSelectionChanged
        }
        
        @objc func selectionChanged() {
            DispatchQueue.main.async {
                if let selectedText = UIPasteboard.general.string {
                    self.onSelectionChanged(selectedText)
                }
            }
        }
    }
} 
