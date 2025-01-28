//
//  SmartContextSidebar.swift
//  smartass
//
//  Created by Viet Le on 1/27/25.
//


import SwiftUI
import CoreData

struct SmartContextSidebar: View {
    @Environment(\.managedObjectContext) private var viewContext
    let article: StoredArticle
    @Binding var isPresented: Bool
    
    @FetchRequest private var highlights: FetchedResults<Highlight>
    
    init(article: StoredArticle, isPresented: Binding<Bool>) {
        self.article = article
        self._isPresented = isPresented
        
        // Configure fetch request for highlights
        let fetchRequest: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "article == %@", article)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Highlight.createdAt, ascending: false)]
        self._highlights = FetchRequest(fetchRequest: fetchRequest)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                // Sidebar content
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Smart Context")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Highlights list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(highlights) { highlight in
                                SmartContextCard(highlight: highlight)
                            }
                        }
                        .padding()
                    }
                }
                .frame(width: min(geometry.size.width * 0.8, 400))
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 10)
            }
        }
    }
}

struct SmartContextCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var highlight: Highlight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected text
            Text(highlight.selectedText ?? "No text selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            
            // Smart context content
            Group {
                if let smartContext = highlight.smartContext?.content {
                    Text(smartContext)
                        .font(.body)
                        .onAppear {
                            print("📱 Displaying smart context:", smartContext.prefix(50))
                        }
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                            .onAppear {
                                print("⏳ Showing loading spinner for highlight:", highlight.selectedText?.prefix(50) ?? "nil")
                            }
                        Spacer()
                    }
                    .frame(height: 50)
                }
            }
            .animation(.default, value: highlight.smartContext != nil)
            .onChange(of: highlight.smartContext) { newValue in
                print("🔄 Smart context updated:", newValue?.content?.prefix(50) ?? "nil")
            }
            
            // Delete button
            Button(role: .destructive, action: {
                withAnimation {
                    print("🗑️ Deleting highlight:", highlight.selectedText?.prefix(50) ?? "nil")
                    viewContext.delete(highlight)
                    try? viewContext.save()
                }
            }) {
                Label("Delete", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            print("📱 SmartContextCard appeared for highlight:", highlight.selectedText?.prefix(50) ?? "nil")
        }
    }
} 
