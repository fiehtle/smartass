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
            model: "gpt-4-1106-preview",
            messages: messages,
            temperature: 0.3,
            maxTokens: 150
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(chatRequest)
        request.httpBody = jsonData
        
        print("📤 Sending request to OpenAI:")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
        
        request.timeoutInterval = 10
        
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
        You are an expert analyst providing insight into this article. \
        Present a clear, well-structured overview that captures the essential ideas and context. \
        Maintain a professional yet accessible tone, avoiding technical jargon. \
        Keep your response concise and under 100 words.
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
        You are a subject matter expert providing clear, insightful analysis. \
        Explain the highlighted text with precision and clarity, integrating relevant context naturally. \
        Maintain a professional yet accessible tone. Your response should be concise, \
        under 50 words, and optimized for quick comprehension on mobile devices.
        """
        
        let highlightedText = highlight.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let messages: [ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: """
                Article context: \(article.initialAIContext ?? "")
                
                Highlighted text: \(highlightedText)
                
                Provide a clear, professional explanation.
                """)
        ]
        
        return try await makeRequest(messages: messages)
    }
} 
