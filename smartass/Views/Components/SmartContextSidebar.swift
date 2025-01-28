import SwiftUI

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
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                // Sidebar content
                HStack {
                    Spacer()
                    VStack {
                        // Header
                        HStack {
                            Text("Smart Context")
                                .font(.headline)
                            Spacer()
                            Button {
                                withAnimation {
                                    isPresented = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        
                        // Smart contexts list
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
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(radius: 10)
                }
                .padding()
            }
        }
    }
}

struct SmartContextCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    let highlight: Highlight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let smartContext = highlight.smartContext {
                // Show the smart context
                VStack(alignment: .leading, spacing: 8) {
                    Text(highlight.selectedText ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(smartContext.content)
                        .font(.body)
                }
            } else {
                // Loading state
                VStack(alignment: .leading, spacing: 8) {
                    Text(highlight.selectedText ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        ProgressView()
                        Text("Generating context...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Delete button
            HStack {
                Spacer()
                Button(role: .destructive) {
                    deleteHighlight(highlight)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func deleteHighlight(_ highlight: Highlight) {
        withAnimation {
            do {
                viewContext.delete(highlight)
                try viewContext.save()
            } catch {
                print("Error deleting highlight:", error)
            }
        }
    }
} 