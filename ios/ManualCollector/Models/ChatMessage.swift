import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let manualID: UUID
    let role: MessageRole
    let content: String
    let references: [ChatReference]
    let timestamp: Date

    init(id: UUID = UUID(),
         manualID: UUID,
         role: MessageRole,
         content: String,
         references: [ChatReference] = [],
         timestamp: Date = Date()) {
        self.id = id
        self.manualID = manualID
        self.role = role
        self.content = content
        self.references = references
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user, assistant
}

struct ChatReference: Identifiable, Codable {
    let id: UUID
    let pageNumber: Int
    let snippet: String
    let confidence: Float

    init(id: UUID = UUID(),
         pageNumber: Int,
         snippet: String,
         confidence: Float = 0) {
        self.id = id
        self.pageNumber = pageNumber
        self.snippet = snippet
        self.confidence = confidence
    }
}
