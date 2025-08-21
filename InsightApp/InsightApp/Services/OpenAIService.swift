import Foundation

class OpenAIService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func generateEmbedding(for text: String) async throws -> [Double] {
        let url = URL(string: "\(baseURL)/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = EmbeddingRequest(
            model: "text-embedding-3-large",
            input: text,
            encoding_format: "float"
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        return embeddingResponse.data.first?.embedding ?? []
    }
    
    func processJournalEntry(_ entry: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = "Here is a journal entry. Provide a compassionate and uplifting response to the user based on the Teachings of the Baha'i Faith. In your response, restate what the user is saying to you."
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: entry)
            ],
            max_tokens: 500,
            temperature: 0.7
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return chatResponse.choices.first?.message.content ?? ""
    }
}

// MARK: - Request/Response Models

struct EmbeddingRequest: Codable {
    let model: String
    let input: String
    let encoding_format: String
}

struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
}

struct EmbeddingData: Codable {
    let embedding: [Double]
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let max_tokens: Int
    let temperature: Double
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let code):
            return "HTTP error \(code) from OpenAI API"
        case .decodingError:
            return "Failed to decode OpenAI API response"
        }
    }
}