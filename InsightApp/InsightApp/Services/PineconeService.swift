import Foundation

class PineconeService: ObservableObject {
    private let apiKey: String
    private let indexName = "bahai-writings"
    private let environment: String
    
    init(apiKey: String, environment: String = "us-east-1-aws") {
        self.apiKey = apiKey
        self.environment = environment
    }
    
    private var baseURL: String {
        return "https://\(indexName)-\(environment).pinecone.io"
    }
    
    func search(queryVector: [Double], topK: Int = 10, authorFilter: [Author]? = nil) async throws -> [SearchResult] {
        let url = URL(string: "\(baseURL)/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var filter: [String: Any]? = nil
        if let authors = authorFilter, !authors.contains(.all) {
            let authorNames = authors.map { $0.rawValue }
            filter = ["author": ["$in": authorNames]]
        }
        
        let requestBody = PineconeQueryRequest(
            vector: queryVector,
            topK: topK,
            includeMetadata: true,
            filter: filter
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PineconeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data) {
                throw PineconeError.apiError(errorData.message)
            }
            throw PineconeError.httpError(httpResponse.statusCode)
        }
        
        let queryResponse = try JSONDecoder().decode(PineconeQueryResponse.self, from: data)
        
        return queryResponse.matches.compactMap { match in
            guard let metadata = match.metadata else { return nil }
            return SearchResult(
                text: metadata.text,
                sourceFile: metadata.source_file,
                paragraphId: metadata.paragraph_id,
                score: match.score,
                author: metadata.author
            )
        }
    }
    
    func getIndexStats() async throws -> PineconeIndexStats {
        let url = URL(string: "\(baseURL)/describe_index_stats")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PineconeError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PineconeError.httpError(httpResponse.statusCode)
        }
        
        let statsResponse = try JSONDecoder().decode(PineconeStatsResponse.self, from: data)
        return PineconeIndexStats(totalVectorCount: statsResponse.totalVectorCount)
    }
}

// MARK: - Request/Response Models

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

struct PineconeQueryRequest: Encodable {
    let vector: [Double]
    let topK: Int
    let includeMetadata: Bool
    let filter: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case vector, topK, includeMetadata, filter
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vector, forKey: .vector)
        try container.encode(topK, forKey: .topK)
        try container.encode(includeMetadata, forKey: .includeMetadata)
        
        if let filter = filter {
            // Convert [String: Any] to Data then to a container
            let filterData = try JSONSerialization.data(withJSONObject: filter)
            let filterJSON = try JSONSerialization.jsonObject(with: filterData) as? [String: Any]
            
            var filterContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .filter)
            try encodeAnyDictionary(filterJSON ?? [:], to: &filterContainer)
        }
    }
    
    private func encodeAnyDictionary(_ dict: [String: Any], to container: inout KeyedEncodingContainer<AnyCodingKey>) throws {
        for (key, value) in dict {
            let codingKey = AnyCodingKey(stringValue: key)!
            
            if let stringValue = value as? String {
                try container.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try container.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try container.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try container.encode(boolValue, forKey: codingKey)
            } else if let arrayValue = value as? [String] {
                try container.encode(arrayValue, forKey: codingKey)
            } else if let nestedDict = value as? [String: Any] {
                var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                try encodeAnyDictionary(nestedDict, to: &nestedContainer)
            }
        }
    }
}

struct PineconeQueryResponse: Codable {
    let matches: [PineconeMatch]
}

struct PineconeMatch: Codable {
    let id: String
    let score: Double
    let metadata: PineconeMetadata?
}

struct PineconeMetadata: Codable {
    let text: String
    let source_file: String
    let paragraph_id: Int
    let author: String
}

struct PineconeStatsResponse: Codable {
    let totalVectorCount: Int
}

struct PineconeIndexStats {
    let totalVectorCount: Int
}

struct PineconeErrorResponse: Codable {
    let message: String
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
            return "Invalid response from Pinecone API"
        case .httpError(let code):
            return "HTTP error \(code) from Pinecone API"
        case .apiError(let message):
            return "Pinecone API error: \(message)"
        case .decodingError:
            return "Failed to decode Pinecone API response"
        }
    }
}