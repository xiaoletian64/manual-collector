import Foundation

// MARK: - Cloud LLM Provider (DeepSeek / GLM / OpenAI-compatible)
protocol LLMProviderProtocol {
    func chat(systemPrompt: String, userPrompt: String, temperature: Double, maxTokens: Int) async throws -> String
    func embed(text: String) async throws -> [Float]
}

enum LLMProviderError: Error, LocalizedError {
    case apiError(statusCode: Int, body: String)
    case noApiKey
    case networkError(Error)
    case parseFailed
    case rateLimited(retryAfter: Int)

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body): return "API error \(code): \(body)"
        case .noApiKey: return "未配置 API Key，请在设置中输入"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .parseFailed: return "解析响应失败"
        case .rateLimited(let s): return "请求过于频繁，请 \(s) 秒后再试"
        }
    }
}

// MARK: - DeepSeek Provider
final class DeepSeekProvider: LLMProviderProtocol {
    private let apiKey: String
    private let baseURL: String
    private let chatModel: String
    private let embedModel: String

    init(apiKey: String,
         baseURL: String = "https://api.deepseek.com/v1",
         chatModel: String = "deepseek-chat",
         embedModel: String = "text-embedding-v2") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.chatModel = chatModel
        self.embedModel = embedModel
    }

    func chat(systemPrompt: String, userPrompt: String, temperature: Double = 0.3, maxTokens: Int = 1024) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": chatModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse else {
            throw LLMProviderError.networkError(URLError(.badServerResponse))
        }
        guard httpResp.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            if httpResp.statusCode == 429 {
                let retry = httpResp.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) } ?? 30
                throw LLMProviderError.rateLimited(retryAfter: retry)
            }
            throw LLMProviderError.apiError(statusCode: httpResp.statusCode, body: bodyStr)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMProviderError.parseFailed
        }
        return content
    }

    func embed(text: String) async throws -> [Float] {
        let url = URL(string: "\(baseURL)/embeddings")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = ["model": embedModel, "input": text]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw LLMProviderError.apiError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1, body: "")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArr = json["data"] as? [[String: Any]],
              let embedding = dataArr.first?["embedding"] as? [Double] else {
            throw LLMProviderError.parseFailed
        }
        return embedding.map { Float($0) }
    }
}

// MARK: - GLM-4 Provider (智谱)
final class GLMProvider: LLMProviderProtocol {
    private let apiKey: String
    private let baseURL: String
    private let model: String

    init(apiKey: String,
         baseURL: String = "https://open.bigmodel.cn/api/paas/v4",
         model: String = "glm-4-flash") {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
    }

    func chat(systemPrompt: String, userPrompt: String, temperature: Double = 0.3, maxTokens: Int = 1024) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw LLMProviderError.apiError(statusCode: (resp as? HTTPURLResponse)?.statusCode ?? -1, body: "")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMProviderError.parseFailed
        }
        return content
    }

    // GLM doesn't have a public embedding API, so we use DeepSeek for embedding
    func embed(text: String) async throws -> [Float] {
        throw LLMProviderError.apiError(statusCode: -1, body: "GLM does not support embedding. Use DeepSeekProvider for embedding.")
    }
}

// MARK: - Factory: creates provider from config, with auto-fallback
final class LLMProviderFactory {
    static func create(provider: String = "deepseek",
                       apiKey: String,
                       fallbackApiKey: String? = nil) -> LLMProviderProtocol {
        switch provider.lowercased() {
        case "glm", "glm-4", "zhipu":
            return GLMProvider(apiKey: apiKey)
        default:
            return DeepSeekProvider(apiKey: apiKey)
        }
    }

    static func createWithFallback(primaryProvider: String = "deepseek",
                                    primaryApiKey: String,
                                    fallbackApiKey: String? = nil) -> [LLMProviderProtocol] {
        var providers: [LLMProviderProtocol] = [create(provider: primaryProvider, apiKey: primaryApiKey)]
        if let fallbackKey = fallbackApiKey, !fallbackKey.isEmpty {
            let secondaryProvider = primaryProvider.lowercased() == "deepseek" ? "glm" : "deepseek"
            providers.append(create(provider: secondaryProvider, apiKey: fallbackKey))
        }
        return providers
    }
}
