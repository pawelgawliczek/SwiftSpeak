//
//  GoogleMeetingService.swift
//  SwiftSpeakCore
//
//  Google Cloud Speech-to-Text service with speaker diarization support
//  Implements MeetingTranscriptionService protocol for meeting recording
//  Shared between iOS and macOS
//

import Foundation
import AVFoundation

// MARK: - Google Meeting Transcription Service

/// Google Cloud STT transcription service with speaker diarization support
/// Implements MeetingTranscriptionService protocol for meeting recording
public final class GoogleMeetingService: MeetingTranscriptionService, @unchecked Sendable {

    private let apiKey: String
    private let projectId: String
    private let model: String

    // MARK: - Initialization

    public init(apiKey: String, projectId: String, model: String = "latest_long") {
        self.apiKey = apiKey
        self.projectId = projectId
        self.model = model
    }

    /// Initialize from AIProviderConfig if available
    public convenience init?(config: AIProviderConfig) {
        guard config.provider == .google,
              !config.apiKey.isEmpty,
              let projectId = config.googleProjectId,
              !projectId.isEmpty else {
            return nil
        }
        self.init(
            apiKey: config.apiKey,
            projectId: projectId,
            model: config.transcriptionModel ?? "latest_long"
        )
    }

    // MARK: - MeetingTranscriptionService

    public var supportsDiarization: Bool { true }

    public func transcribe(
        audioURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]? = nil
    ) async throws -> DiarizedTranscriptionResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw MeetingRecordingError.transcriptionFailed("Audio file not found")
        }

        // Check if we need to convert the audio format
        // Google Cloud STT v1 doesn't support M4A/AAC well, so convert to WAV
        let processedURL: URL
        let needsCleanup: Bool
        let ext = audioURL.pathExtension.lowercased()

        if ext == "m4a" || ext == "aac" || ext == "mp4" {
            #if DEBUG
            print("[GoogleMeetingService] Converting \(ext.uppercased()) to WAV for Google compatibility...")
            #endif
            processedURL = try await convertToWAV(audioURL: audioURL)
            needsCleanup = true
        } else {
            processedURL = audioURL
            needsCleanup = false
        }

        defer {
            // Clean up temporary WAV file if we created one
            if needsCleanup {
                try? FileManager.default.removeItem(at: processedURL)
            }
        }

        let audioData = try Data(contentsOf: processedURL)
        let base64Audio = audioData.base64EncodedString()

        // Google Cloud Speech-to-Text v1 API endpoint
        let endpoint = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(apiKey)")!

        // Determine audio encoding from file extension
        let (encoding, sampleRate) = determineAudioEncoding(for: processedURL)

        // Build the request config
        var config: [String: Any] = [
            "encoding": encoding,
            "languageCode": convertToGoogleLanguageCode(language) ?? "en-US",
            "model": model,
            "enableAutomaticPunctuation": true,
            "enableWordTimeOffsets": true  // Required for diarization
        ]

        if let rate = sampleRate {
            config["sampleRateHertz"] = rate
        }

        // Add diarization config if requested
        if withDiarization {
            var diarizationConfig: [String: Any] = [
                "enableSpeakerDiarization": true
            ]

            if let count = speakerCount {
                // Set min and max to the expected count for better accuracy
                diarizationConfig["minSpeakerCount"] = max(1, count)
                diarizationConfig["maxSpeakerCount"] = max(2, count + 2)  // Allow some flexibility
            } else {
                // Auto-detect: allow 2-6 speakers
                diarizationConfig["minSpeakerCount"] = 2
                diarizationConfig["maxSpeakerCount"] = 6
            }

            config["diarizationConfig"] = diarizationConfig
        }

        // Add speech contexts for word boost
        if let words = wordBoost, !words.isEmpty {
            let phrases = Array(words.prefix(500))  // Google limits to 500 phrases
            config["speechContexts"] = [
                [
                    "phrases": phrases,
                    "boost": 15  // Higher boost for meeting-specific vocabulary
                ]
            ]
        }

        let requestBody: [String: Any] = [
            "config": config,
            "audio": ["content": base64Audio]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 300  // 5 minutes for long recordings

        #if DEBUG
        print("[GoogleMeetingService] Sending request to Google Cloud STT...")
        print("[GoogleMeetingService] Audio file: \(processedURL.lastPathComponent), size: \(audioData.count) bytes, encoding: \(encoding)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MeetingRecordingError.transcriptionFailed("Invalid response")
        }

        #if DEBUG
        print("[GoogleMeetingService] Response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[GoogleMeetingService] Response body: \(responseString.prefix(1000))")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            #if DEBUG
            print("[GoogleMeetingService] ERROR: \(errorMessage)")
            #endif
            throw MeetingRecordingError.transcriptionFailed("Google STT error: \(errorMessage)")
        }

        return try parseResponse(data: data, withDiarization: withDiarization)
    }

    // MARK: - Private Methods

    /// Convert audio file to WAV format for Google Cloud STT compatibility
    /// Google STT v1 API works best with LINEAR16 (WAV) format
    private func convertToWAV(audioURL: URL) async throws -> URL {
        // Create output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("google_stt_\(UUID().uuidString).wav")

        // Open source audio file
        let sourceFile = try AVAudioFile(forReading: audioURL)
        let sourceFormat = sourceFile.processingFormat

        #if DEBUG
        print("[GoogleMeetingService] Source format: \(sourceFormat.sampleRate)Hz, \(sourceFormat.channelCount)ch")
        #endif

        // Define target format: 16kHz mono 16-bit PCM
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            throw MeetingRecordingError.transcriptionFailed("Failed to create target audio format")
        }

        // Create converter
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw MeetingRecordingError.transcriptionFailed("Failed to create audio converter")
        }

        // Calculate output buffer size
        let frameCount = AVAudioFrameCount(sourceFile.length)
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * ratio)

        // Read source audio into buffer
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw MeetingRecordingError.transcriptionFailed("Failed to create source buffer")
        }
        try sourceFile.read(into: sourceBuffer)

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            throw MeetingRecordingError.transcriptionFailed("Failed to create output buffer")
        }

        // Convert
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            throw MeetingRecordingError.transcriptionFailed("Audio conversion failed: \(error.localizedDescription)")
        }

        // Write output WAV file
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )
        try outputFile.write(from: outputBuffer)

        #if DEBUG
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        let duration = Double(outputBuffer.frameLength) / targetFormat.sampleRate
        print("[GoogleMeetingService] Converted to WAV: \(fileSize) bytes, \(String(format: "%.1f", duration))s duration")
        #endif

        return outputURL
    }

    private func determineAudioEncoding(for url: URL) -> (String, Int?) {
        switch url.pathExtension.lowercased() {
        case "wav":
            return ("LINEAR16", 16000)
        case "flac":
            return ("FLAC", nil)
        case "mp3":
            return ("MP3", nil)
        case "ogg", "opus":
            return ("OGG_OPUS", nil)
        case "webm":
            return ("WEBM_OPUS", nil)
        case "m4a", "aac", "mp4":
            // Should not reach here as we convert these formats to WAV
            return ("ENCODING_UNSPECIFIED", nil)
        default:
            return ("ENCODING_UNSPECIFIED", nil)
        }
    }

    private func convertToGoogleLanguageCode(_ language: String?) -> String? {
        guard let lang = language else { return nil }

        // Convert short codes to BCP-47 format that Google expects
        let languageMap: [String: String] = [
            "en": "en-US",
            "es": "es-ES",
            "fr": "fr-FR",
            "de": "de-DE",
            "it": "it-IT",
            "pt": "pt-BR",
            "pl": "pl-PL",
            "ru": "ru-RU",
            "zh": "zh-CN",
            "ja": "ja-JP",
            "ko": "ko-KR",
            "ar": "ar-SA"
        ]

        return languageMap[lang] ?? lang
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    private func parseResponse(data: Data, withDiarization: Bool) throws -> DiarizedTranscriptionResult {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MeetingRecordingError.transcriptionFailed("Failed to parse response")
        }

        guard let results = json["results"] as? [[String: Any]], !results.isEmpty else {
            throw MeetingRecordingError.transcriptionFailed("No speech detected")
        }

        // For diarization, we need to use the last result which contains all speaker-tagged words
        // Google's diarization returns cumulative results, with the final one having all words tagged
        var fullTranscript = ""
        var allWords: [[String: Any]] = []
        var totalDuration: Double = 0

        for result in results {
            if let alternatives = result["alternatives"] as? [[String: Any]],
               let firstAlt = alternatives.first {

                if let transcript = firstAlt["transcript"] as? String {
                    fullTranscript += transcript + " "
                }

                // Collect words with speaker tags (for diarization)
                if withDiarization, let words = firstAlt["words"] as? [[String: Any]] {
                    allWords = words  // Use the last result's words (cumulative)
                }
            }

            // Extract duration from result end time
            if let resultEndTime = result["resultEndTime"] as? String {
                if let duration = parseGoogleDuration(resultEndTime) {
                    totalDuration = max(totalDuration, duration)
                }
            }
        }

        fullTranscript = fullTranscript.trimmingCharacters(in: .whitespaces)

        // Build diarization if requested and we have speaker-tagged words
        var diarization: DiarizedTranscript?

        if withDiarization && !allWords.isEmpty {
            let segments = buildSpeakerSegments(from: allWords)
            if !segments.isEmpty {
                diarization = DiarizedTranscript(segments: segments)
            }
        }

        return DiarizedTranscriptionResult(
            text: fullTranscript,
            language: nil,
            duration: totalDuration,
            diarization: diarization
        )
    }

    private func buildSpeakerSegments(from words: [[String: Any]]) -> [SpeakerSegment] {
        var segments: [SpeakerSegment] = []
        var currentSpeaker: Int?
        var currentWords: [String] = []
        var segmentStartMs: Int = 0
        var segmentEndMs: Int = 0

        for word in words {
            guard let wordText = word["word"] as? String else { continue }

            let speakerTag = word["speakerTag"] as? Int ?? 0
            let startTime = word["startTime"] as? String ?? "0s"
            let endTime = word["endTime"] as? String ?? "0s"

            let startMs = parseGoogleDurationMs(startTime)
            let endMs = parseGoogleDurationMs(endTime)

            if currentSpeaker == nil {
                // First word
                currentSpeaker = speakerTag
                segmentStartMs = startMs
            }

            if speakerTag != currentSpeaker {
                // Speaker changed, save current segment
                if !currentWords.isEmpty {
                    let segmentText = currentWords.joined(separator: " ")
                    segments.append(SpeakerSegment(
                        speaker: speakerLabel(for: currentSpeaker ?? 0),
                        text: segmentText,
                        startMs: segmentStartMs,
                        endMs: segmentEndMs,
                        confidence: nil
                    ))
                }

                // Start new segment
                currentSpeaker = speakerTag
                currentWords = [wordText]
                segmentStartMs = startMs
            } else {
                currentWords.append(wordText)
            }

            segmentEndMs = endMs
        }

        // Don't forget the last segment
        if !currentWords.isEmpty {
            let segmentText = currentWords.joined(separator: " ")
            segments.append(SpeakerSegment(
                speaker: speakerLabel(for: currentSpeaker ?? 0),
                text: segmentText,
                startMs: segmentStartMs,
                endMs: segmentEndMs,
                confidence: nil
            ))
        }

        return segments
    }

    private func speakerLabel(for tag: Int) -> String {
        // Convert numeric speaker tags to letter labels (A, B, C, etc.)
        // Google uses 1-based speaker tags
        let index = max(0, tag - 1)
        if index < 26 {
            return String(Character(UnicodeScalar(65 + index)!))  // A, B, C, ...
        } else {
            return "Speaker \(tag)"
        }
    }

    private func parseGoogleDuration(_ duration: String) -> Double? {
        // Google returns duration like "45.200s" or "1m30.500s"
        var value = duration.trimmingCharacters(in: .whitespaces)

        if value.hasSuffix("s") {
            value.removeLast()
        }

        return Double(value)
    }

    private func parseGoogleDurationMs(_ duration: String) -> Int {
        guard let seconds = parseGoogleDuration(duration) else { return 0 }
        return Int(seconds * 1000)
    }
}
