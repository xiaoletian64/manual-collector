import Foundation

// MARK: - Embedding Service Protocol
protocol EmbeddingServiceProtocol {
    var dimension: Int { get }
    func embed(_ text: String) async throws -> [Float]
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float
}

enum EmbeddingError: Error {
    case apiError(String)
    case noApiKey
}

// MARK: - Cloud Embedding Service
/// Calls DeepSeek text-embedding-v2 API via OpenAI-compatible protocol.
final class EmbeddingService: EmbeddingServiceProtocol {
    let dimension: Int = 1024

    private let apiKey: String
    private let baseURL: String
    private let modelName: String

    init(apiKey: String = "",
         baseURL: String = "https://api.deepseek.com/v1",
         modelName: String = "text-embedding-v2") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.modelName = modelName
    }

    func embed(_ text: String) async throws -> [Float] {
        let url = URL(string: "\(baseURL)/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": modelName,
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EmbeddingError.apiError("HTTP error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArr = json["data"] as? [[String: Any]],
              let embedding = dataArr.first?["embedding"] as? [Double] else {
            return []
        }

        return embedding.map { Float($0) }
    }

    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            let vec = try await embed(text)
            results.append(vec)
        }
        return results
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }
}
