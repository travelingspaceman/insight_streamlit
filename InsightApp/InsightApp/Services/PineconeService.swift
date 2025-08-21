import Foundation

class PineconeService: ObservableObject {
    private let backendBaseURL: String
    
    init(backendBaseURL: String = "https://your-backend-url.com/api/pinecone") {
        self.backendBaseURL = backendBaseURL
    }
    
    func search(queryVector: [Double], topK: Int = 10, authorFilter: [Author]? = nil) async throws -> [SearchResult] {
        let url = URL(string: "\(backendBaseURL)/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prepare author filter array
        var authorFilterArray: [String]? = nil
        if let authors = authorFilter, !authors.contains(.all) {
            authorFilterArray = authors.map { $0.rawValue }
        }
        
        var requestBody: [String: Any] = [
            "vector": queryVector,
            "topK": topK
        ]
        
        if let authorFilter = authorFilterArray {
            requestBody["authorFilter"] = authorFilter
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PineconeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error message from backend
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw PineconeError.apiError(errorMessage)
            }
            throw PineconeError.httpError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let resultsArray = responseJSON?["results"] as? [[String: Any]] else {
            throw PineconeError.decodingError
        }
        
        return resultsArray.compactMap { resultDict in
            guard let text = resultDict["text"] as? String,
                  let sourceFile = resultDict["sourceFile"] as? String,
                  let paragraphId = resultDict["paragraphId"] as? Int,
                  let score = resultDict["score"] as? Double,
                  let author = resultDict["author"] as? String else {
                return nil
            }
            
            return SearchResult(
                text: text,
                sourceFile: sourceFile,
                paragraphId: paragraphId,
                score: score,
                author: author
            )
        }
    }
    
    func getIndexStats() async throws -> PineconeIndexStats {
        let url = URL(string: "\(backendBaseURL)/stats")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PineconeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            // Try to decode error message from backend
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                throw PineconeError.apiError(errorMessage)
            }
            throw PineconeError.httpError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let totalVectorCount = responseJSON?["totalVectorCount"] as? Int else {
            throw PineconeError.decodingError
        }
        
        return PineconeIndexStats(totalVectorCount: totalVectorCount)
    }
}

// MARK: - Response Models

struct PineconeIndexStats {
    let totalVectorCount: Int
}

// MARK: - Errors

enum PineconeError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from backend API"
        case .httpError(let code):
            return "HTTP error \(code) from backend API"
        case .apiError(let message):
            return "Backend API error: \(message)"
        case .decodingError:
            return "Failed to decode backend API response"
        }
    }
}