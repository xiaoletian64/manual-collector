import Foundation

struct CompletenessReport: Identifiable, Codable {
    let id: UUID
    let manualID: UUID
    var overallScore: Int
    var dimensionScores: DimensionScores
    var detectedSections: [String]
    var missingSections: [String]
    var suggestions: [String]
    var evaluatedAt: Date

    init(id: UUID = UUID(),
         manualID: UUID,
         overallScore: Int = 0,
         dimensionScores: DimensionScores = DimensionScores(),
         detectedSections: [String] = [],
         missingSections: [String] = [],
         suggestions: [String] = [],
         evaluatedAt: Date = Date()) {
        self.id = id
        self.manualID = manualID
        self.overallScore = overallScore
        self.dimensionScores = dimensionScores
        self.detectedSections = detectedSections
        self.missingSections = missingSections
        self.suggestions = suggestions
        self.evaluatedAt = evaluatedAt
    }
}

struct DimensionScores: Codable {
    var structuralIntegrity: Int
    var textClarity: Int
    var pageCompleteness: Int
    var sectionDiversity: Int
    var imageQuality: Int

    init(structuralIntegrity: Int = 0,
         textClarity: Int = 0,
         pageCompleteness: Int = 0,
         sectionDiversity: Int = 0,
         imageQuality: Int = 0) {
        self.structuralIntegrity = structuralIntegrity
        self.textClarity = textClarity
        self.pageCompleteness = pageCompleteness
        self.sectionDiversity = sectionDiversity
        self.imageQuality = imageQuality
    }
}
