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
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from Perplexity"
            case .apiError(let message):
                return "Perplexity API error: \(message)"
            case .decodingError:
                return "Failed to decode Perplexity response"
            }
        }
    }
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    struct Citation: Codable {
        let url: String
        let text: String
    }
    
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
        let choices: [Choice]
        let citations: [Citation]?
        
        struct Choice: Codable {
            let message: ChatMessage
            let finishReason: String?
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
        
        let chatResponse = try jsonDecoder.decode(ChatResponse.self, from: data)
        return (
            content: chatResponse.choices.first?.message.content ?? "",
            citations: chatResponse.citations
        )
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
        You are a subject matter expert providing clear, insightful analysis. \
        Explain the highlighted text with precision and clarity, integrating relevant context naturally. \
        Maintain a professional yet accessible tone. Your response should be concise, \
        under 50 words, and optimized for quick comprehension on mobile devices. \
        Include relevant citations to support your explanation.
        """
        
        let highlightedText = highlight.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let messages: [ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: """
                Article context: \(article.initialAIContext ?? "")
                
                Highlighted text: \(highlightedText)
                
                Provide a clear, professional explanation with relevant citations.
                """)
        ]
        
        return try await makeRequest(messages: messages)
    }
} 