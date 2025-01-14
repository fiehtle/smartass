//
//  ContentView.swift
//  smartass
//
//  Created by Viet Le on 1/14/25.
//

import SwiftUI

struct ContentView: View {
    @State private var articleURL: String = ""
    @State private var isShowingReader: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("smartass")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Paste article URL", text: $articleURL)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Button(action: {
                    // Placeholder for article fetching logic
                    isShowingReader = true
                }) {
                    Text("Read Article")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(articleURL.isEmpty)
                
                Spacer()
            }
            .navigationDestination(isPresented: $isShowingReader) {
                ArticleReaderView(articleURL: articleURL)
            }
        }
    }
}

#Preview {
    ContentView()
} 
