//
//  PerplexityService.swift
//  smartass
//
//  Created by Viet Le on 1/29/25.
//


import Foundation

actor PerplexityService {
    static let shared = PerplexityService()
    
    private let apiKey = Config.perplexityApiKey
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    enum PerplexityError: LocalizedError {
        case invalidResponse
        case apiError(String)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from Perplexity"
            case .apiError(let message):
                return "Perplexity API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode Perplexity response: \(error.localizedDescription)"
            }
        }
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    // Citations are just strings in the response
    typealias Citation = String
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let returnCitations: Bool
        let maxTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case returnCitations = "return_citations"
            case maxTokens = "max_tokens"
        }
    }
    
    struct ChatResponse: Codable {
        let id: String
        let model: String
        let created: Int
        let usage: Usage
        let citations: [Citation]?
        let object: String
        let choices: [Choice]
        
        struct Usage: Codable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
        }
        
        struct Choice: Codable {
            let index: Int
            let finishReason: String?
            let message: ChatMessage
            let delta: Delta?
            
            struct Delta: Codable {
                let role: String?
                let content: String?
            }
        }
    }
    
    private func makeRequest(messages: [ChatMessage]) async throws -> (content: String, citations: [Citation]?) {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = ChatRequest(
            model: "llama-3.1-sonar-small-128k-online",
            messages: messages,
            temperature: 0.3,
            returnCitations: true,
            maxTokens: 150
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(chatRequest)
        request.httpBody = jsonData
        
        print("📤 Sending request to Perplexity:")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PerplexityError.invalidResponse
        }
        
        print("📥 Received response from Perplexity (status: \(httpResponse.statusCode)):")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PerplexityError.apiError(errorMessage)
        }
        
        do {
            let chatResponse = try jsonDecoder.decode(ChatResponse.self, from: data)
            return (
                content: chatResponse.choices.first?.message.content ?? "",
                citations: chatResponse.citations
            )
        } catch {
            print("❌ Decoding error details:", error)
            throw PerplexityError.decodingError(error)
        }
    }
    
    func generateInitialContext(for article: DisplayArticle) async throws -> (content: String, citations: [Citation]?) {
        print("📝 Generating initial context for article:", article.title)
        
        let systemPrompt = """
        You are an expert analyst providing insight into this article. \
        Present a clear, well-structured overview that captures the essential ideas and context. \
        Maintain a professional yet accessible tone, avoiding technical jargon. \
        Keep your response concise and under 100 words. \
        Include relevant citations to support your analysis.
        """
        
        let messages: [ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: article.textContent)
        ]
        
        return try await makeRequest(messages: messages)
    }
    
    func generateSmartContext(highlight: Highlight, articleContent: String) async throws -> (content: String, citations: [Citation]?) {
        guard let article = highlight.article else {
            throw PerplexityError.invalidResponse
        }
        
        print("📝 Generating smart context for highlight:", highlight.selectedText ?? "")
        
        let systemPrompt = """
        You are an expert providing concise, encyclopedia-style explanations. Follow this structure:
        1. Start with a clear, direct definition or explanation of the highlighted text
        2. Add one crucial piece of context that enhances understanding
        
        Key requirements:
        - Write like a concise encyclopedia entry
        - Focus solely on explaining the highlighted text
        - Keep response under 50 words
        - Use clear, accessible language
        - Include relevant citations
        - Avoid tangential information
        
        The article context provided should only be used if it significantly changes or enhances the core meaning of the highlighted text.
        """
        
        let highlightedText = highlight.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let messages: [ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: """
                Explain this highlighted text in encyclopedia style: \(highlightedText)
                
                Supporting article context (only if it significantly affects the meaning): \(article.initialAIContext ?? "")
                
                Provide a focused explanation of the highlight itself, as if writing a concise encyclopedia entry.
                """)
        ]
        
        return try await makeRequest(messages: messages)
    }
} 
