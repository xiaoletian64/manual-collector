import Foundation

struct OcrPage: Identifiable, Codable {
    let id: UUID
    let pageNumber: Int
    var rawText: String
    var confidence: Float
    var detectedSections: [DetectedSection]

    init(id: UUID = UUID(),
         pageNumber: Int,
         rawText: String = "",
         confidence: Float = 0,
         detectedSections: [DetectedSection] = []) {
        self.id = id
        self.pageNumber = pageNumber
        self.rawText = rawText
        self.confidence = confidence
        self.detectedSections = detectedSections
    }
}

struct DetectedSection: Identifiable, Codable {
    let id: UUID
    var title: String
    var boundingBox: CGRect
    var confidence: Float

    init(id: UUID = UUID(),
         title: String,
         boundingBox: CGRect = .zero,
         confidence: Float = 0) {
        self.id = id
        self.title = title
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}
