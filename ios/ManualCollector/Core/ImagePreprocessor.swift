import UIKit
import Vision
import CoreImage
import CoreGraphics
import Accelerate

// MARK: - Image Preprocessor
/// 边缘检测 + 畸变矫正 + 对比度增强
final class ImagePreprocessor {
    static func preprocess(_ image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }

        // Step 1: Edge detection using CIEdges
        let edgeImage = try await applyEdgeDetection(to: image)

        // Step 2: Perspective correction using VNDetectRectanglesRequest
        let correctedImage: UIImage
        if let docRect = await detectDocumentRect(in: image) {
            correctedImage = try await applyPerspectiveCorrection(to: image, observation: docRect)
        } else {
            correctedImage = image
        }

        // Step 3: Shadow removal using CIHighlightShadowAdjust + CIGammaAdjust
        let shadowRemoved = try await removeShadows(from: correctedImage)

        // Step 4: Contrast enhancement
        let contrastEnhanced = try await enhanceContrast(from: shadowRemoved)

        // Step 5: Adaptive binarization using CIColorControls + CIPhotoEffectNoir
        let binarized = try await adaptiveBinarize(from: contrastEnhanced)

        // Step 6: Noise reduction
        let denoised = try await reduceNoise(from: binarized)

        // Step 7: Sharpening using CISharpenLuminance
        let sharpened = try await sharpen(from: denoised)

        return sharpened
    }

    static func detectDocumentRect(in image: UIImage) async -> VNRectangleObservation? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.2
        request.quadratureTolerance = 45
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first
        } catch {
            return nil
        }
    }

    static func computeSharpnessScore(_ image: UIImage) -> Float {
        guard let ciImage = CIImage(image: image) else { return 0.5 }

        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.0, forKey: kCIInputIntensityKey)

        guard let output = filter?.outputImage,
              let cgImage = createCGImage(from: output) else {
            return 0.5
        }

        guard let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return 0.5
        }

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        var sum: Float = 0

        for i in 0..<totalPixels {
            let pixel = data[i * 4]
            sum += Float(pixel)
        }

        let meanEdge = sum / Float(totalPixels)
        let normalizedScore = min(1.0, meanEdge / 128.0)

        return normalizedScore
    }

    // MARK: - Private Pipeline Steps

    private static func applyEdgeDetection(to image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(5.0, forKey: kCIInputIntensityKey)
        guard let output = filter?.outputImage else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        return UIImage(ciImage: output)
    }

    private static func applyPerspectiveCorrection(to image: UIImage, observation: VNRectangleObservation) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        let imageSize = ciImage.extent.size
        let topLeft = CGPoint(x: observation.topLeft.x * imageSize.width,
                              y: (1 - observation.topLeft.y) * imageSize.height)
        let topRight = CGPoint(x: observation.topRight.x * imageSize.width,
                               y: (1 - observation.topRight.y) * imageSize.height)
        let bottomLeft = CGPoint(x: observation.bottomLeft.x * imageSize.width,
                                 y: (1 - observation.bottomLeft.y) * imageSize.height)
        let bottomRight = CGPoint(x: observation.bottomRight.x * imageSize.width,
                                  y: (1 - observation.bottomRight.y) * imageSize.height)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage,
              let cgImage = createCGImage(from: output) else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    private static func removeShadows(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let shadowFilter = CIFilter(name: "CIHighlightShadowAdjust") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        shadowFilter.setValue(ciImage, forKey: kCIInputImageKey)
        shadowFilter.setValue(0.3, forKey: "inputShadowAmount")
        shadowFilter.setValue(0.8, forKey: "inputHighlightAmount")

        guard let shadowOutput = shadowFilter.outputImage else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        gammaFilter.setValue(shadowOutput, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.2, forKey: "inputPower")

        guard let output = gammaFilter.outputImage,
              let cgImage = createCGImage(from: output) else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    private static func enhanceContrast(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(0.3, forKey: kCIInputEVKey)

        guard let exposureOutput = exposureFilter.outputImage else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let controlsFilter = CIFilter(name: "CIColorControls") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        controlsFilter.setValue(exposureOutput, forKey: kCIInputImageKey)
        controlsFilter.setValue(1.5, forKey: kCIInputContrastKey)
        controlsFilter.setValue(0.05, forKey: kCIInputBrightnessKey)
        controlsFilter.setValue(1.0, forKey: kCIInputSaturationKey)

        guard let output = controlsFilter.outputImage,
              let cgImage = createCGImage(from: output) else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    private static func adaptiveBinarize(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let noirFilter = CIFilter(name: "CIPhotoEffectNoir") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        noirFilter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let noirOutput = noirFilter.outputImage else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let controlsFilter = CIFilter(name: "CIColorControls") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        controlsFilter.setValue(noirOutput, forKey: kCIInputImageKey)
        controlsFilter.setValue(2.0, forKey: kCIInputContrastKey)
        controlsFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
        controlsFilter.setValue(0.0, forKey: kCIInputSaturationKey)

        guard let output = controlsFilter.outputImage,
              let cgImage = createCGImage(from: output) else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    private static func reduceNoise(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let filter = CIFilter(name: "CINoiseReduction") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.02, forKey: kCIInputNoiseLevelKey)
        filter.setValue(0.4, forKey: kCIInputSharpnessKey)

        guard let output = filter.outputImage,
              let cgImage = createCGImage(from: output) else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    private static func sharpen(from image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }

        guard let filter = CIFilter(name: "CISharpenLuminance") else {
            throw ImagePreprocessorError.ciImageCreationFailed
        }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.4, forKey: kCIInputSharpnessKey)

        guard let output = filter.outputImage,
              let cgImage = createCGImage(from: output) else {
            throw ImagePreprocessorError.cgImageCreationFailed
        }
        return UIImage(cgImage: cgImage)
    }

    private static func createCGImage(from ciImage: CIImage) -> CGImage? {
        let context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? NSNull(),
            .highQualityDownsample: true
        ])
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

enum ImagePreprocessorError: Error {
    case ciContextCreationFailed
    case ciImageCreationFailed
    case cgImageCreationFailed
}
