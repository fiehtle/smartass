//
//  SmartContextSheet.swift
//  smartass
//
//  Created by Viet Le on 1/29/25.
//


import SwiftUI
import CoreData

struct SmartContextSheet: View {
    let selectedText: String
    let explanation: String?
    let citations: [String]?
    @Binding var isPresented: Bool
    let onDelete: (() -> Void)?  // Add delete callback
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Handle indicator
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 36, height: 5)
                    Spacer()
                }
                .padding(.top, 8)
                
                // Selected text
                Text(selectedText)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if let explanation = explanation {
                    // Divider
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal)
                    
                    // Explanation
                    Text(explanation)
                        .font(.system(size: 15))
                        .padding(.horizontal)
                    
                    // Citations
                    if let citations = citations, !citations.isEmpty {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Citations")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(citations, id: \.self) { citation in
                                Link(destination: URL(string: citation) ?? URL(string: "https://google.com")!) {
                                    Text(citation)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Delete button
                    if let onDelete = onDelete {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                            .padding(.horizontal)
                        
                        Button(role: .destructive, action: {
                            onDelete()
                            isPresented = false
                        }) {
                            Label("Delete Highlight", systemImage: "trash")
                        }
                        .padding(.horizontal)
                    }
                    
                } else {
                    // Loading state
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding(.bottom)
        }
        .background(Color(uiColor: .systemBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden) // We're showing our own
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled(explanation == nil)  // Prevent dismissal while loading
    }
}

#Preview {
    SmartContextSheet(
        selectedText: "This is the selected text that will be explained",
        explanation: "Here is a detailed explanation of the selected text, providing more context and understanding.",
        citations: nil,
        isPresented: .constant(true),
        onDelete: nil
    )
} 
