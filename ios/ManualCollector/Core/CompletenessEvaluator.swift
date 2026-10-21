import Foundation

// MARK: - Completeness Result
struct CompletenessResult {
    let overallScore: Int
    let dimensionScores: DimensionScores
    let detectedSections: [String]
    let missingSections: [String]
    let suggestions: [String]
}

// MARK: - Completeness Evaluator
/// 5维评分算法
///
/// 维度：
/// 1. structuralIntegrity（结构完整性）- 通过检测到的章节数量评估，权重0.25
/// 2. textClarity（文字清晰度）- 通过 OCR confidence 均值评估，权重0.20
/// 3. pageCompleteness（页面完整度）- 通过预期页面与实际页面比例评估，权重0.25
/// 4. sectionDiversity（章节多样性）- 通过章节标题的语义覆盖度评估，权重0.15
/// 5. imageQuality（图像质量）- 通过边缘强度与亮度分布评估，权重0.15
final class CompletenessEvaluator {
    struct EvaluationInput {
        let pages: [OcrPage]
        let totalPages: Int
        let expectedSections: [String]
        let imageQualityMetrics: ImageQualityMetrics?
    }

    struct ImageQualityMetrics {
        let edgeStrength: Float
        let brightnessVariance: Float
        let blurEstimate: Float
    }

    private let weights: [Float] = [0.25, 0.20, 0.25, 0.15, 0.15]

    func evaluate(input: EvaluationInput) -> CompletenessResult {
        let si = evaluateStructuralIntegrity(input: input)
        let tc = evaluateTextClarity(input: input)
        let pc = evaluatePageCompleteness(input: input)
        let sd = evaluateSectionDiversity(input: input)
        let iq = evaluateImageQuality(input: input)

        let dim = DimensionScores(
            structuralIntegrity: si,
            textClarity: tc,
            pageCompleteness: pc,
            sectionDiversity: sd,
            imageQuality: iq
        )

        let overall = Int(round(
            Float(si) * weights[0]
            + Float(tc) * weights[1]
            + Float(pc) * weights[2]
            + Float(sd) * weights[3]
            + Float(iq) * weights[4]
        ))

        let detected = extractSectionTitles(from: input.pages)
        let missing = computeMissingSections(detected: detected, expected: input.expectedSections)
        let suggestions = generateSuggestions(dim: dim, missing: missing)

        return CompletenessResult(
            overallScore: min(100, max(0, overall)),
            dimensionScores: dim,
            detectedSections: detected,
            missingSections: missing,
            suggestions: suggestions
        )
    }

    // MARK: - Dimension 1: Structural Integrity (0-100)
    private func evaluateStructuralIntegrity(input: EvaluationInput) -> Int {
        let sectionTitles = extractSectionTitles(from: input.pages)

        guard !input.expectedSections.isEmpty else {
            let count = sectionTitles.count
            switch count {
            case 0: return 0
            case 1: return 30
            case 2: return 50
            case 3: return 70
            case 4: return 85
            default: return 100
            }
        }

        let detectedSet = Set(sectionTitles.map { $0.lowercased().trimmed() })
        let expectedSet = Set(input.expectedSections.map { $0.lowercased().trimmed() })

        guard !expectedSet.isEmpty else { return 0 }
        let hitCount = detectedSet.intersection(expectedSet).count
        let ratio = Float(hitCount) / Float(expectedSet.count)
        return Int(round(ratio * 100))
    }

    // MARK: - Dimension 2: Text Clarity (0-100)
    private func evaluateTextClarity(input: EvaluationInput) -> Int {
        guard !input.pages.isEmpty else { return 0 }
        let confidences = input.pages.flatMap { page in
            [page.confidence] + page.detectedSections.map(\.confidence)
        }
        guard !confidences.isEmpty else { return 50 }
        let avg = confidences.reduce(0, +) / Float(confidences.count)
        return Int(round(avg * 100))
    }

    // MARK: - Dimension 3: Page Completeness (0-100)
    private func evaluatePageCompleteness(input: EvaluationInput) -> Int {
        guard input.totalPages > 0 else {
            return input.pages.isEmpty ? 0 : 80
        }
        let captured = min(input.pages.count, input.totalPages)
        let ratio = Float(captured) / Float(input.totalPages)
        return Int(round(min(1, ratio) * 100))
    }

    // MARK: - Dimension 4: Section Diversity (0-100)
    private func evaluateSectionDiversity(input: EvaluationInput) -> Int {
        let sectionTitles = extractSectionTitles(from: input.pages)
        guard sectionTitles.count >= 2 else {
            return sectionTitles.count == 1 ? 30 : 0
        }

        let uniqueTitles = Set(sectionTitles.map { $0.lowercased().trimmed() })
        let baseScore = min(100, uniqueTitles.count * 20)

        let functionalKeywords = ["安全", "安装", "使用", "操作", "功能",
                                   "维护", "清洁", "故障", "参数", "保修"]
        let keywordHits = functionalKeywords.filter { kw in
            uniqueTitles.contains { $0.contains(kw) }
        }.count
        let bonus = min(20, keywordHits * 5)

        return min(100, baseScore + bonus)
    }

    // MARK: - Dimension 5: Image Quality (0-100)
    private func evaluateImageQuality(input: EvaluationInput) -> Int {
        guard let metrics = input.imageQualityMetrics else {
            return 70
        }

        var score: Float = 100

        if metrics.edgeStrength < 0.2 {
            score -= 20
        } else if metrics.edgeStrength > 0.9 {
            score -= 10
        }

        if metrics.blurEstimate > 0.6 {
            score -= 25
        } else if metrics.blurEstimate > 0.3 {
            score -= 10
        }

        if metrics.brightnessVariance < 0.1 {
            score -= 15
        } else if metrics.brightnessVariance > 0.8 {
            score -= 10
        }

        return Int(round(max(0, min(100, score))))
    }

    // MARK: - Helpers
    private func extractSectionTitles(from pages: [OcrPage]) -> [String] {
        return pages.flatMap { $0.detectedSections.map(\.title) }
    }

    private func computeMissingSections(detected: [String], expected: [String]) -> [String] {
        let detectedSet = Set(detected.map { $0.lowercased().trimmed() })
        return expected.filter { !detectedSet.contains($0.lowercased().trimmed()) }
    }

    private func generateSuggestions(dim: DimensionScores, missing: [String]) -> [String] {
        var suggestions: [String] = []

        if dim.structuralIntegrity < 60 {
            suggestions.append("当前结构完整性偏低，建议补充更多章节页")
        }
        if dim.textClarity < 50 {
            suggestions.append("部分文字识别不清晰，建议重新拍摄模糊页面")
        }
        if dim.pageCompleteness < 60 {
            suggestions.append("页面数量不足，请确认是否已拍摄全部页面")
        }
        if dim.sectionDiversity < 50 {
            suggestions.append("章节种类较少，建议包含安全、安装、维护等核心章节")
        }
        if dim.imageQuality < 50 {
            suggestions.append("图像质量不足，请在光线充足的环境下拍摄")
        }
        for m in missing {
            suggestions.append("建议补充\"\(m)\"章节")
        }
        return suggestions
    }

    // MARK: - Static API

    static func evaluate(pages: [OcrPage], images: [UIImage]) -> CompletenessReport {
        let evaluator = CompletenessEvaluator()

        let qualityMetrics = computeImageQualityMetrics(images)
        let totalPages = extractPageNumbers(from: pages.reduce("") { $0 + $1.rawText + "\n" }) ?? pages.count

        let expectedSections = [
            "安全须知", "规格参数", "使用方法", "故障排除", "保修条款",
            "注意事项", "安装说明", "维护保养", "产品概述", "包装清单"
        ]

        let input = EvaluationInput(
            pages: pages,
            totalPages: totalPages,
            expectedSections: expectedSections,
            imageQualityMetrics: qualityMetrics
        )

        let result = evaluator.evaluate(input: input)

        return CompletenessReport(
            manualID: UUID(),
            overallScore: result.overallScore,
            dimensionScores: result.dimensionScores,
            detectedSections: result.detectedSections,
            missingSections: result.missingSections,
            suggestions: result.suggestions,
            evaluatedAt: Date()
        )
    }

    private static func computeImageQualityMetrics(_ images: [UIImage]) -> ImageQualityMetrics? {
        guard let first = images.first else { return nil }
        let edgeStrength = ImagePreprocessor.computeSharpnessScore(first)
        return ImageQualityMetrics(
            edgeStrength: edgeStrength,
            brightnessVariance: 0.5,
            blurEstimate: 1.0 - edgeStrength
        )
    }

    private static func extractPageNumbers(from text: String) -> Int? {
        let patterns = [
            #"共\s*(\d+)\s*页"#,
            #"共\s*(\d+)\s*頁"#,
            #"总计\s*(\d+)\s*页"#,
            #"total\s+(\d+)\s+pages"#i,
            #"(\d+)\s*pages?\s*total"#i
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let matched = text[range]
                if let numRange = matched.range(of: #"\d+"#, options: .regularExpression) {
                    return Int(matched[numRange])
                }
            }
        }
        return nil
    }

    static func detectTOC(from text: String) -> Bool {
        let patterns = ["^\\s*目录\\s*$", "^\\s*contents\\s*$"]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for pattern in patterns {
                if trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    return true
                }
            }
        }
        return false
    }

    static func detectNumberedHeaders(from text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        let headerCount = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.range(of: #"^\d+[\.\、\s]"#, options: .regularExpression) != nil {
                return true
            }
            if trimmed.range(of: #"^第[一二三四五六七八九十百千]+[章节]"#, options: .regularExpression) != nil {
                return true
            }
            return false
        }.count
        return headerCount >= 2
    }

    static func generateRecommendation(score: Int, missingSections: [String], lowConfWords: Int) -> String {
        switch score {
        case 90...100:
            return "非常好！内容完整度高 (\(score)分)，已足够生成电子版说明书。"
        case 70..<90:
            var msg = "基本完整 (\(score)分)，建议补拍以下章节："
            if !missingSections.isEmpty {
                msg += " " + missingSections.joined(separator: "、")
            }
            if lowConfWords > 10 {
                msg += "；另有 \(lowConfWords) 处文字识别置信度偏低，建议重新拍摄对应页面。"
            }
            return msg
        case 50..<70:
            var msg = "部分完整 (\(score)分)，建议补拍："
            if !missingSections.isEmpty {
                msg += " " + missingSections.joined(separator: "、")
            }
            msg += "。同时注意在光线充足、页面平整的条件下拍摄。"
            return msg
        default:
            return "完整度较低 (\(score)分)，建议重新拍摄全部页面，确保每页清晰可读。"
        }
    }
}
