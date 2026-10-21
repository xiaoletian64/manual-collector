import Foundation
import UIKit
import Vision

// MARK: - OCR Service Protocol
protocol OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> OcrPage
    func recognizeMultiple(_ images: [UIImage]) async throws -> [OcrPage]
}

enum OCRServiceError: Error {
    case imageConversionFailed
    case recognitionFailed(Error)
}

enum TextRole {
    case title, heading, body, table, caption, unknown
}

struct RecognizedBlock {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
    let role: TextRole
}

// MARK: - OCR Service Implementation
final class OCRService: OCRServiceProtocol {
    private let preprocessor: ImagePreprocessor.Type

    init(preprocessor: ImagePreprocessor.Type = ImagePreprocessor.self) {
        self.preprocessor = preprocessor
    }

    func recognizeText(from image: UIImage) async throws -> OcrPage {
        let preprocessed = try await preprocessor.preprocess(image)

        guard let cgImage = preprocessed.cgImage else {
            throw OCRServiceError.imageConversionFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.customWords = [
            "说明书", "型号", "规格", "安全须知", "使用方法",
            "故障排除", "保修条款", "注意事项", "技术参数",
            "安装说明", "操作指南", "维护保养", "产品概述",
            "开箱清单", "电源要求", "环境要求", "售后服务",
            "警告", "注意", "禁止", "必须", "额定电压",
            "额定功率", "净重", "毛重", "产品尺寸", "执行标准"
        ]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRServiceError.recognitionFailed(error)
        }

        guard let results = request.results else {
            return OcrPage(pageNumber: 0, rawText: "", confidence: 0)
        }

        var allText = ""
        var minConfidence: Float = 1.0
        var sections: [DetectedSection] = []

        let sortedResults = results.sorted { lhs, rhs in
            let lhsBox = lhs.boundingBox
            let rhsBox = rhs.boundingBox
            if abs(lhsBox.minY - rhsBox.minY) < 0.02 {
                return lhsBox.minX < rhsBox.minX
            }
            return lhsBox.minY > rhsBox.minY
        }

        for observation in sortedResults {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let text = topCandidate.string
            let confidence = topCandidate.confidence
            let box = observation.boundingBox

            if !allText.isEmpty {
                allText += "\n"
            }
            allText += text
            minConfidence = min(minConfidence, confidence)

            if text.count >= 2 && text.count <= 30 {
                let maybeTitle = isLikelySectionTitle(text)
                if maybeTitle {
                    sections.append(DetectedSection(
                        title: text,
                        boundingBox: box,
                        confidence: confidence
                    ))
                }
            }
        }

        let avgConfidence = results.isEmpty ? 0 : minConfidence
        return OcrPage(
            pageNumber: 0,
            rawText: allText,
            confidence: avgConfidence,
            detectedSections: sections
        )
    }

    func recognizeMultiple(_ images: [UIImage]) async throws -> [OcrPage] {
        var pages: [OcrPage] = []
        for (i, img) in images.enumerated() {
            var page = try await recognizeText(from: img)
            page.pageNumber = i + 1
            pages.append(page)
        }
        return pages
    }

    func recognizeTextBlocks(in image: UIImage) async throws -> [RecognizedBlock] {
        guard let cgImage = image.cgImage else {
            throw OCRServiceError.imageConversionFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let results = request.results else { return [] }

        return results.compactMap { observation -> RecognizedBlock? in
            guard let top = observation.topCandidates(1).first else { return nil }
            let role = classifyTextRole(
                text: top.string,
                boundingBox: observation.boundingBox,
                confidence: top.confidence
            )
            return RecognizedBlock(
                text: top.string,
                boundingBox: observation.boundingBox,
                confidence: top.confidence,
                role: role
            )
        }
    }

    static func classifyTextRole(text: String, boundingBox: CGRect, confidence: Float) -> TextRole {
        let titleKeywords = ["说明书", "手册", "指南", "须知", "说明"]
        let tableIndicators = ["参数", "规格", "型号", "尺寸", "电压", "功率", "重量"]
        let captionIndicators = ["图", "表", "注", "*"]

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= 15 && confidence > 0.8 {
            if titleKeywords.contains(where: { trimmed.contains($0) }) {
                return .title
            }
            if trimmed.hasPrefix("第") && (trimmed.hasSuffix("章") || trimmed.hasSuffix("节")) {
                return .heading
            }
            if trimmed.range(of: #"^\d+[\.\、]"#, options: .regularExpression) != nil {
                return .heading
            }
        }

        if tableIndicators.contains(where: { trimmed.contains($0) }) {
            return .table
        }

        if captionIndicators.contains(where: { trimmed.hasPrefix($0) }) {
            return .caption
        }

        if trimmed.count > 30 || confidence < 0.6 {
            return .body
        }

        return .unknown
    }

    private func isLikelySectionTitle(_ text: String) -> Bool {
        let sectionPatterns = [
            "安全须知", "注意事项", "使用方法", "操作说明",
            "故障排除", "保修条款", "技术参数", "规格参数",
            "安装说明", "维护保养", "产品概述", "开箱清单",
            "包装清单", "售后服务", "免责声明", "环保说明",
            "重要安全说明", "使用前须知", "产品介绍", "功能说明",
            "清洗与保养", "常见问题"
        ]
        if sectionPatterns.contains(where: { text.contains($0) }) {
            return true
        }
        if text.range(of: #"^第[一二三四五六七八九十百千]+[章节]"#, options: .regularExpression) != nil {
            return true
        }
        if text.range(of: #"^\d+[\.\、\s].{2,20}$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}
