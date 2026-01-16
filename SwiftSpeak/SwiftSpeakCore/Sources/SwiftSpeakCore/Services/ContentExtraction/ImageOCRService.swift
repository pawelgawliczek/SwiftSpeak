//
//  ImageOCRService.swift
//  SwiftSpeakCore
//
//  Extracts text from images using Vision framework OCR
//  Shared between iOS and macOS
//

import Foundation
import CoreGraphics

#if canImport(Vision)
import Vision
#endif

// MARK: - OCR Error

public enum OCRError: Error, LocalizedError {
    case imageNotFound
    case invalidImage
    case noTextDetected
    case visionNotAvailable
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .imageNotFound:
            return "Image file not found"
        case .invalidImage:
            return "Invalid or corrupted image"
        case .noTextDetected:
            return "No text detected in image"
        case .visionNotAvailable:
            return "Vision framework not available"
        case .extractionFailed(let message):
            return "OCR extraction failed: \(message)"
        }
    }
}

// MARK: - Image OCR Service

/// Extracts text from images using Vision framework OCR
/// Works on both iOS (15+) and macOS (12+)
public final class ImageOCRService: @unchecked Sendable {

    /// Supported recognition languages
    public enum RecognitionLanguage: String, CaseIterable {
        case english = "en-US"
        case polish = "pl-PL"
        case german = "de-DE"
        case french = "fr-FR"
        case spanish = "es-ES"
        case italian = "it-IT"
        case portuguese = "pt-BR"
        case dutch = "nl-NL"
        case russian = "ru-RU"
        case chinese = "zh-Hans"
        case japanese = "ja-JP"
        case korean = "ko-KR"
    }

    /// Recognition level (speed vs accuracy)
    public enum RecognitionLevel {
        case fast
        case accurate
    }

    private let languages: [String]
    private let level: RecognitionLevel

    public init(
        languages: [RecognitionLanguage] = [.english],
        level: RecognitionLevel = .accurate
    ) {
        self.languages = languages.map { $0.rawValue }
        self.level = level
    }

    // MARK: - Public Methods

    /// Extract text from a CGImage
    /// - Parameter image: The image to process
    /// - Returns: Extracted text content
    public func extractText(from image: CGImage) async throws -> String {
        #if canImport(Vision)
        return try await withCheckedThrowingContinuation { continuation in
            performOCR(on: image) { result in
                continuation.resume(with: result)
            }
        }
        #else
        throw OCRError.visionNotAvailable
        #endif
    }

    /// Extract text from image data
    /// - Parameter data: Raw image data (PNG, JPEG, etc.)
    /// - Returns: Extracted text content
    public func extractText(from data: Data) async throws -> String {
        #if canImport(Vision)
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw OCRError.invalidImage
        }

        return try await extractText(from: cgImage)
        #else
        throw OCRError.visionNotAvailable
        #endif
    }

    /// Extract text from image file URL
    /// - Parameter url: File URL to the image
    /// - Returns: Extracted text content
    public func extractText(from url: URL) async throws -> String {
        #if canImport(Vision)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OCRError.imageNotFound
        }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw OCRError.invalidImage
        }

        return try await extractText(from: cgImage)
        #else
        throw OCRError.visionNotAvailable
        #endif
    }

    // MARK: - Private Methods

    #if canImport(Vision)
    private func performOCR(on image: CGImage, completion: @escaping (Result<String, Error>) -> Void) {
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(OCRError.extractionFailed(error.localizedDescription)))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextDetected))
                return
            }

            let text = self.processObservations(observations)

            if text.isEmpty {
                completion(.failure(OCRError.noTextDetected))
            } else {
                completion(.success(text))
            }
        }

        // Configure request
        request.recognitionLevel = level == .accurate ? .accurate : .fast
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(OCRError.extractionFailed(error.localizedDescription)))
        }
    }

    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> String {
        // Sort observations by vertical position (top to bottom)
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        var lines: [String] = []
        var currentLineY: CGFloat = -1
        var currentLine: [String] = []
        let lineThreshold: CGFloat = 0.02 // Consider same line if Y difference < 2%

        for observation in sorted {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let y = observation.boundingBox.minY

            if currentLineY < 0 {
                // First observation
                currentLineY = y
                currentLine = [candidate.string]
            } else if abs(y - currentLineY) < lineThreshold {
                // Same line - add to current
                currentLine.append(candidate.string)
            } else {
                // New line - save current and start new
                if !currentLine.isEmpty {
                    lines.append(currentLine.joined(separator: " "))
                }
                currentLineY = y
                currentLine = [candidate.string]
            }
        }

        // Don't forget the last line
        if !currentLine.isEmpty {
            lines.append(currentLine.joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }
    #endif
}

// MARK: - Static Convenience Methods

public extension ImageOCRService {
    /// Static convenience method to extract text from CGImage
    static func extractText(from image: CGImage, languages: [RecognitionLanguage] = [.english]) async throws -> String {
        try await ImageOCRService(languages: languages).extractText(from: image)
    }

    /// Static convenience method to extract text from image data
    static func extractText(from data: Data, languages: [RecognitionLanguage] = [.english]) async throws -> String {
        try await ImageOCRService(languages: languages).extractText(from: data)
    }

    /// Static convenience method to extract text from image URL
    static func extractText(from url: URL, languages: [RecognitionLanguage] = [.english]) async throws -> String {
        try await ImageOCRService(languages: languages).extractText(from: url)
    }
}
