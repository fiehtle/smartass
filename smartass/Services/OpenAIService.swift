import Foundation

actor OpenAIService {
    static let shared = OpenAIService()
    
    private let apiKey = Config.openAIApiKey
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    enum OpenAIError: LocalizedError {
        case invalidResponse
        case apiError(String)
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from OpenAI"
            case .apiError(let message):
                return "OpenAI API error: \(message)"
            case .decodingError:
                return "Failed to decode OpenAI response"
            }
        }
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        
        private enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
        
        let maxTokens: Int
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(model, forKey: .model)
            try container.encode(messages, forKey: .messages)
            try container.encode(temperature, forKey: .temperature)
            try container.encode(maxTokens, forKey: .maxTokens)
        }
    }
    
    struct ChatResponse: Codable {
        let choices: [Choice]
        
        struct Choice: Codable {
            let message: ChatMessage
        }
    }
    
    private func makeRequest(messages: [ChatMessage]) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let chatRequest = ChatRequest(
            model: "gpt-4-turbo-preview",
            messages: messages,
            temperature: 0.7,
            maxTokens: 500
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(chatRequest)
        request.httpBody = jsonData
        
        print("📤 Sending request to OpenAI:")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        print("📥 Received response from OpenAI (status: \(httpResponse.statusCode)):")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(errorMessage)
        }
        
        let chatResponse = try jsonDecoder.decode(ChatResponse.self, from: data)
        return chatResponse.choices.first?.message.content ?? ""
    }
    
    func generateInitialContext(for article: DisplayArticle) async throws -> String {
        print("📝 Generating initial context for article:", article.title)
        
        let systemPrompt = """
        You are a knowledgeable assistant helping to analyze an article. \
        Provide a brief, high-level understanding of the article that will help \
        provide context for specific passages later. Keep it concise and focus on \
        the main themes and concepts. This will be used as background context \
        when explaining specific highlighted passages.
        """
        
        let messages: [ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: article.textContent)
        ]
        
        return try await makeRequest(messages: messages)
    }
    
    func generateSmartContext(highlight: Highlight, articleContent: String) async throws -> String {
        guard let article = highlight.article else {
            throw OpenAIError.invalidResponse
        }
        
        print("📝 Generating smart context for highlight:", highlight.selectedText ?? "")
        
        let systemPrompt = """
        You're a concise encyclopedia that explains things in clear, simple language.

        For different topics:
        - History: Include the key year/period and one significant impact
        - Science/Tech: Explain the core idea and why it matters
        - Biography: Note their main achievement or influence
        - Concepts: Define it simply and give a real-world example
        
        Structure (2-3 short sentences total):
        1. Clear explanation using simple words
        2. Most relevant context based on topic type
        
        Style:
        - Use everyday language
        - Keep sentences short
        - Avoid jargon unless essential
        - Make it readable at a glance on mobile
        """
        
        let highlightedText = highlight.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let messages: [ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: """
                Article context: \(article.initialAIContext ?? "")
                
                Highlighted text: \(highlightedText)
                
                Explain this like a clear, simple encyclopedia entry.
                """)
        ]
        
        return try await makeRequest(messages: messages)
    }
} 