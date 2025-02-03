import SwiftUI
import CoreData

@MainActor
class HomeViewModel: ObservableObject {
    @Published var urlString = ""
    @Published var showError = false
    @Published var isArticlePresented = false
    
    var isValidURL: Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http"
    }
    
    func validateAndPresentArticle() {
        if isValidURL {
            isArticlePresented = true
        } else {
            showError = true
        }
    }
} 