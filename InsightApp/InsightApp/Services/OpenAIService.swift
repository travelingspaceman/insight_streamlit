import Foundation

class OpenAIService: ObservableObject {
    private let backendBaseURL: String
    
    init(backendBaseURL: String = "https://your-backend-url.com/api/openai") {
        self.backendBaseURL = backendBaseURL
    }
    
    func generateEmbedding(for text: String) async throws -> [Double] {
        let url = URL(string: "\(backendBaseURL)/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["input": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error message from backend
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw OpenAIError.apiError(errorMessage)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let embedding = responseJSON?["embedding"] as? [Double] else {
            throw OpenAIError.decodingError
        }
        
        return embedding
    }
    
    func processJournalEntry(_ entry: String) async throws -> String {
        let url = URL(string: "\(backendBaseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["journalEntry": entry]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error message from backend
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw OpenAIError.apiError(errorMessage)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let response = responseJSON?["response"] as? String else {
            throw OpenAIError.decodingError
        }
        
        return response
    }
}

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from backend API"
        case .httpError(let code):
            return "HTTP error \(code) from backend API"
        case .decodingError:
            return "Failed to decode backend API response"
        case .apiError(let message):
            return "Backend API error: \(message)"
        }
    }
}