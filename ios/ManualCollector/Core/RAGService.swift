import Foundation

// MARK: - RAG Service Protocol
protocol RAGServiceProtocol {
    func indexPages(_ pages: [OcrPage], for manualID: UUID) async throws
    func query(question: String, manualID: UUID, topK: Int) async throws -> RAGResult
    func clearIndex(manualID: UUID) async throws
}

struct RAGResult {
    let answer: String
    let references: [ChatReference]
    let tokensUsed: Int
}

enum RAGServiceError: Error {
    case apiError(String)
    case noApiKey
    case networkError(Error)
    case emptyResult
}

// MARK: - RAG Service Implementation (Cloud LLM)
final class RAGService: RAGServiceProtocol {
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let embeddingService: EmbeddingServiceProtocol

    private var chunks: [(id: UUID, manualId: UUID, page: Int, text: String)] = []
    private let indexQueue = DispatchQueue(label: "com.manualcollector.rag.index", qos: .userInitiated)

    init(apiKey: String,
         baseURL: String = "https://api.deepseek.com/v1",
         model: String = "deepseek-chat",
         embeddingService: EmbeddingServiceProtocol = EmbeddingService()) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.embeddingService = embeddingService
    }

    convenience init(glmKey: String) {
        self.init(
            apiKey: glmKey,
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            model: "glm-4-flash"
        )
    }

    // MARK: - Indexing

    func indexPages(_ pages: [OcrPage], for manualID: UUID) async throws {
        var newChunks: [(id: UUID, manualId: UUID, page: Int, text: String)] = []
        for page in pages {
            let blocks = chunkText(page.rawText, maxLength: 256)
            for block in blocks {
                newChunks.append((
                    id: UUID(),
                    manualId: manualID,
                    page: page.pageNumber,
                    text: block
                ))
            }
        }
        indexQueue.sync {
            chunks.removeAll { $0.manualId == manualID }
            chunks.append(contentsOf: newChunks)
        }
    }

    func clearIndex(manualID: UUID) async throws {
        indexQueue.sync {
            chunks.removeAll { $0.manualId == manualID }
        }
    }

    // MARK: - Query

    func query(question: String, manualID: UUID, topK: Int = 5) async throws -> RAGResult {
        let relevant = try await retrieve(question: question, manualID: manualID, topK: topK)

        guard !relevant.isEmpty else {
            return RAGResult(answer: "未在说明书中找到相关内容。", references: [], tokensUsed: 0)
        }

        let context = relevant.map { r in
            "[第\(r.page)页] \(r.text)"
        }.joined(separator: "\n")

        let prompt = """
你是一个说明书助手。只基于以下说明书内容回答用户问题。
如果信息不在原文中，请回答"未在说明书中找到"。
在回答末尾标注引用页码，如（第3页）。

说明书内容：
===
\(context)
===

用户问：\(question)

回答：
"""

        let answer = try await callLLM(prompt: prompt)
        let references = relevant.map { ChatReference(pageNumber: $0.page, snippet: $0.text, confidence: 0.9) }

        return RAGResult(answer: answer, references: references, tokensUsed: answer.count / 2)
    }

    // MARK: - Retrieval (BM25)

    private func retrieve(question: String, manualID: UUID, topK: Int) async throws -> [(text: String, page: Int, score: Double)] {
        let queryWords = Set(question.lowercased()
            .replacingOccurrences(of: "[，。！？、；：""''【】（）《》\n]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init))

        let manualChunks: [(id: UUID, manualId: UUID, page: Int, text: String)]
        indexQueue.sync {
            manualChunks = chunks.filter { $0.manualId == manualID }
        }

        guard !manualChunks.isEmpty else {
            throw NSError(domain: "RAGService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No indexed content for this manual"])
        }

        var scored: [(text: String, page: Int, score: Double)] = []
        for chunk in manualChunks {
            let chunkWords = Set(chunk.text.lowercased()
                .replacingOccurrences(of: "[，。！？、；：""''【】（）《》\n]", with: " ", options: .regularExpression)
                .split(separator: " ")
                .map(String.init))
            let intersection = queryWords.intersection(chunkWords)
            let score = queryWords.isEmpty ? 0 : Double(intersection.count) / Double(queryWords.count)
            if score > 0 {
                scored.append((text: chunk.text, page: chunk.page, score: score))
            }
        }

        return scored.sorted { $0.score > $1.score }.prefix(topK).map { ($0.text, $0.page, $0.score) }
    }

    // MARK: - LLM Call

    private func callLLM(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "你是一个专业的说明书助手，基于提供的说明书内容回答用户问题，回复简洁准确，使用中文，标注引用页码。"],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RAGServiceError.apiError("HTTP error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return "抱歉，暂时无法回答。"
        }

        return content
    }

    // MARK: - Text Chunking

    private func chunkText(_ text: String, maxLength: Int) -> [String] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            let trimmed = sentence.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if current.count + trimmed.count > maxLength {
                chunks.append(current)
                current = trimmed
            } else {
                current += (current.isEmpty ? "" : "。") + trimmed
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.isEmpty ? [text] : chunks
    }
}
