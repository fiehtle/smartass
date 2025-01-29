import SwiftUI

struct SmartContextSheet: View {
    let selectedText: String
    let explanation: String?
    @Binding var isPresented: Bool
    
    var body: some View {
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
                Divider()
                    .padding(.horizontal)
                
                // Smart Context explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Context")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(explanation)
                        .font(.system(size: 15))
                }
                .padding(.horizontal)
            } else {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            }
            
            Spacer(minLength: 20)
        }
        .background(Color(uiColor: .systemBackground))
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden) // We're showing our own
        .presentationBackgroundInteraction(.enabled)
    }
}

#Preview {
    SmartContextSheet(
        selectedText: "This is the selected text that will be explained",
        explanation: "Here is a detailed explanation of the selected text, providing more context and understanding.",
        isPresented: .constant(true)
    )
} 