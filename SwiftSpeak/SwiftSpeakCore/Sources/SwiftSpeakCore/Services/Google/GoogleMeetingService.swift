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

    /// Maximum size for Google API payload (10MB)
    /// Both sync and async APIs have this limit for inline content
    private let maxPayloadSize = 10_485_760

    /// Target chunk size (8MB to leave room for base64 overhead)
    private let targetChunkSize = 8_000_000

    /// Polling interval for async operations (seconds)
    private let pollInterval: TimeInterval = 5.0

    /// Maximum time to wait for async operation (10 minutes)
    private let maxWaitTime: TimeInterval = 600.0

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

        // Check if file exceeds payload limit - use chunked processing for large files
        // Note: Both sync and async APIs have 10MB inline content limit
        if audioData.count > maxPayloadSize {
            #if DEBUG
            print("[GoogleMeetingService] File size \(audioData.count) bytes exceeds limit (\(maxPayloadSize)), using chunked processing...")
            #endif
            return try await transcribeChunked(
                audioURL: processedURL,
                withDiarization: withDiarization,
                language: language,
                speakerCount: speakerCount,
                wordBoost: wordBoost
            )
        }

        let base64Audio = audioData.base64EncodedString()

        // Google Cloud Speech-to-Text v1 API endpoint (sync)
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

    // MARK: - Chunked Transcription (Large Files)

    /// Transcribe large audio files by splitting into chunks under 10MB
    /// This is required because Google STT has a 10MB payload limit for inline content
    private func transcribeChunked(
        audioURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]?
    ) async throws -> DiarizedTranscriptionResult {
        // Read the WAV file
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let totalFrames = AVAudioFrameCount(audioFile.length)

        // Calculate frames per chunk based on target size
        // WAV 16kHz mono 16-bit = 32000 bytes/sec = 32 bytes/frame
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        let framesPerChunk = AVAudioFrameCount(targetChunkSize / bytesPerFrame)

        // Calculate number of chunks needed
        let numChunks = Int(ceil(Double(totalFrames) / Double(framesPerChunk)))

        #if DEBUG
        let totalDuration = Double(totalFrames) / format.sampleRate
        print("[GoogleMeetingService] Splitting \(String(format: "%.1f", totalDuration))s audio into \(numChunks) chunks")
        #endif

        var allResults: [DiarizedTranscriptionResult] = []
        var cumulativeOffset: Double = 0

        for chunkIndex in 0..<numChunks {
            let startFrame = AVAudioFramePosition(chunkIndex) * AVAudioFramePosition(framesPerChunk)
            let remainingFrames = totalFrames - AVAudioFrameCount(startFrame)
            let chunkFrames = min(framesPerChunk, remainingFrames)

            #if DEBUG
            let chunkDuration = Double(chunkFrames) / format.sampleRate
            print("[GoogleMeetingService] Processing chunk \(chunkIndex + 1)/\(numChunks) (\(String(format: "%.1f", chunkDuration))s)...")
            #endif

            // Extract chunk to temporary file
            let chunkURL = try await extractAudioChunk(
                from: audioURL,
                startFrame: startFrame,
                frameCount: chunkFrames,
                format: format
            )

            defer {
                try? FileManager.default.removeItem(at: chunkURL)
            }

            // Transcribe chunk
            let chunkData = try Data(contentsOf: chunkURL)
            let result = try await transcribeSingleChunk(
                audioData: chunkData,
                audioURL: chunkURL,
                withDiarization: withDiarization,
                language: language,
                speakerCount: speakerCount,
                wordBoost: wordBoost,
                timeOffset: cumulativeOffset
            )

            allResults.append(result)
            cumulativeOffset += Double(chunkFrames) / format.sampleRate
        }

        // Merge all chunk results
        return mergeChunkResults(allResults, withDiarization: withDiarization)
    }

    /// Extract a portion of audio to a new file
    private func extractAudioChunk(
        from sourceURL: URL,
        startFrame: AVAudioFramePosition,
        frameCount: AVAudioFrameCount,
        format: AVAudioFormat
    ) async throws -> URL {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        sourceFile.framePosition = startFrame

        let chunkURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("google_chunk_\(UUID().uuidString).wav")

        // Create output file with same format
        let outputFile = try AVAudioFile(
            forWriting: chunkURL,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        // Read and write in smaller buffers to avoid memory issues
        let bufferSize: AVAudioFrameCount = 65536
        var framesRemaining = frameCount

        while framesRemaining > 0 {
            let framesToRead = min(bufferSize, framesRemaining)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                throw MeetingRecordingError.transcriptionFailed("Failed to create audio buffer")
            }

            try sourceFile.read(into: buffer, frameCount: framesToRead)
            try outputFile.write(from: buffer)
            framesRemaining -= framesToRead
        }

        return chunkURL
    }

    /// Transcribe a single chunk of audio
    private func transcribeSingleChunk(
        audioData: Data,
        audioURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]?,
        timeOffset: Double
    ) async throws -> DiarizedTranscriptionResult {
        let base64Audio = audioData.base64EncodedString()

        let endpoint = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(apiKey)")!
        let (encoding, sampleRate) = determineAudioEncoding(for: audioURL)

        var config: [String: Any] = [
            "encoding": encoding,
            "languageCode": convertToGoogleLanguageCode(language) ?? "en-US",
            "model": model,
            "enableAutomaticPunctuation": true,
            "enableWordTimeOffsets": true
        ]

        if let rate = sampleRate {
            config["sampleRateHertz"] = rate
        }

        if withDiarization {
            var diarizationConfig: [String: Any] = ["enableSpeakerDiarization": true]
            if let count = speakerCount {
                diarizationConfig["minSpeakerCount"] = max(1, count)
                diarizationConfig["maxSpeakerCount"] = max(2, count + 2)
            } else {
                diarizationConfig["minSpeakerCount"] = 2
                diarizationConfig["maxSpeakerCount"] = 6
            }
            config["diarizationConfig"] = diarizationConfig
        }

        if let words = wordBoost, !words.isEmpty {
            config["speechContexts"] = [["phrases": Array(words.prefix(500)), "boost": 15]]
        }

        let requestBody: [String: Any] = [
            "config": config,
            "audio": ["content": base64Audio]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 300

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = extractErrorMessage(from: data) ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            throw MeetingRecordingError.transcriptionFailed("Google STT chunk error: \(errorMessage)")
        }

        // Parse and adjust timestamps by offset
        var result = try parseResponse(data: data, withDiarization: withDiarization)

        // Adjust diarization timestamps if present
        if let diarization = result.diarization {
            let offsetMs = Int(timeOffset * 1000)
            let adjustedSegments = diarization.segments.map { segment in
                SpeakerSegment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startMs: segment.startMs + offsetMs,
                    endMs: segment.endMs + offsetMs,
                    confidence: segment.confidence
                )
            }
            result = DiarizedTranscriptionResult(
                text: result.text,
                language: result.language,
                duration: result.duration,
                diarization: DiarizedTranscript(segments: adjustedSegments, speakerNames: diarization.speakerNames)
            )
        }

        return result
    }

    /// Merge results from multiple chunks
    private func mergeChunkResults(
        _ results: [DiarizedTranscriptionResult],
        withDiarization: Bool
    ) -> DiarizedTranscriptionResult {
        guard !results.isEmpty else {
            return DiarizedTranscriptionResult(text: "", language: nil, duration: 0, diarization: nil)
        }

        // Merge text
        let mergedText = results.map { $0.text }.joined(separator: " ")

        // Merge duration
        let totalDuration = results.map { $0.duration }.reduce(0, +)

        // Merge diarization if present
        var mergedDiarization: DiarizedTranscript?
        if withDiarization {
            var allSegments: [SpeakerSegment] = []
            var speakerNames: [String: String] = [:]

            for result in results {
                if let diarization = result.diarization {
                    allSegments.append(contentsOf: diarization.segments)
                    speakerNames.merge(diarization.speakerNames) { _, new in new }
                }
            }

            if !allSegments.isEmpty {
                // Sort by start time
                allSegments.sort { $0.startMs < $1.startMs }
                mergedDiarization = DiarizedTranscript(segments: allSegments, speakerNames: speakerNames)
            }
        }

        #if DEBUG
        print("[GoogleMeetingService] Merged \(results.count) chunks: \(mergedText.count) chars, \(String(format: "%.1f", totalDuration))s")
        #endif

        return DiarizedTranscriptionResult(
            text: mergedText,
            language: results.first?.language,
            duration: totalDuration,
            diarization: mergedDiarization
        )
    }

    // MARK: - Async Transcription (Legacy - kept for reference)

    /// Transcribe large audio files using the async longrunningrecognize API
    /// Note: This still has 10MB inline content limit, use chunked processing instead
    private func transcribeAsync(
        audioData: Data,
        processedURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]?
    ) async throws -> DiarizedTranscriptionResult {
        let base64Audio = audioData.base64EncodedString()

        // Google Cloud Speech-to-Text v1 async API endpoint
        let endpoint = URL(string: "https://speech.googleapis.com/v1/speech:longrunningrecognize?key=\(apiKey)")!

        // Determine audio encoding from file extension
        let (encoding, sampleRate) = determineAudioEncoding(for: processedURL)

        // Build the request config
        var config: [String: Any] = [
            "encoding": encoding,
            "languageCode": convertToGoogleLanguageCode(language) ?? "en-US",
            "model": model,
            "enableAutomaticPunctuation": true,
            "enableWordTimeOffsets": true
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
                diarizationConfig["minSpeakerCount"] = max(1, count)
                diarizationConfig["maxSpeakerCount"] = max(2, count + 2)
            } else {
                diarizationConfig["minSpeakerCount"] = 2
                diarizationConfig["maxSpeakerCount"] = 6
            }

            config["diarizationConfig"] = diarizationConfig
        }

        // Add speech contexts for word boost
        if let words = wordBoost, !words.isEmpty {
            let phrases = Array(words.prefix(500))
            config["speechContexts"] = [
                [
                    "phrases": phrases,
                    "boost": 15
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
        request.timeoutInterval = 60  // Initial request timeout

        #if DEBUG
        print("[GoogleMeetingService] Sending async request to Google Cloud STT...")
        print("[GoogleMeetingService] Audio file: \(processedURL.lastPathComponent), size: \(audioData.count) bytes")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MeetingRecordingError.transcriptionFailed("Invalid response")
        }

        #if DEBUG
        print("[GoogleMeetingService] Async response status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[GoogleMeetingService] Response: \(responseString.prefix(500))")
        }
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = extractErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw MeetingRecordingError.transcriptionFailed("Google STT async error: \(errorMessage)")
        }

        // Parse operation response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let operationName = json["name"] as? String else {
            throw MeetingRecordingError.transcriptionFailed("Failed to parse async operation response")
        }

        #if DEBUG
        print("[GoogleMeetingService] Operation started: \(operationName)")
        print("[GoogleMeetingService] Polling for completion (max \(Int(maxWaitTime))s)...")
        #endif

        // Poll for operation completion
        return try await pollOperation(operationName: operationName, withDiarization: withDiarization)
    }

    /// Poll an async operation until completion
    private func pollOperation(
        operationName: String,
        withDiarization: Bool
    ) async throws -> DiarizedTranscriptionResult {
        let pollEndpoint = URL(string: "https://speech.googleapis.com/v1/operations/\(operationName)?key=\(apiKey)")!
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < maxWaitTime {
            var request = URLRequest(url: pollEndpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw MeetingRecordingError.transcriptionFailed("Failed to poll operation status")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MeetingRecordingError.transcriptionFailed("Failed to parse operation response")
            }

            // Check if operation is done
            if let done = json["done"] as? Bool, done {
                #if DEBUG
                let elapsed = Date().timeIntervalSince(startTime)
                print("[GoogleMeetingService] Operation completed in \(String(format: "%.1f", elapsed))s")
                #endif

                // Check for error
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw MeetingRecordingError.transcriptionFailed("Transcription failed: \(message)")
                }

                // Parse the response
                guard let result = json["response"] as? [String: Any] else {
                    throw MeetingRecordingError.transcriptionFailed("No response in completed operation")
                }

                return try parseAsyncResponse(result: result, withDiarization: withDiarization)
            }

            // Check for progress metadata
            #if DEBUG
            if let metadata = json["metadata"] as? [String: Any],
               let progressPercent = metadata["progressPercent"] as? Int {
                print("[GoogleMeetingService] Progress: \(progressPercent)%")
            }
            #endif

            // Wait before polling again
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        throw MeetingRecordingError.transcriptionFailed("Operation timed out after \(Int(maxWaitTime)) seconds")
    }

    /// Parse the async operation response
    private func parseAsyncResponse(
        result: [String: Any],
        withDiarization: Bool
    ) throws -> DiarizedTranscriptionResult {
        guard let results = result["results"] as? [[String: Any]], !results.isEmpty else {
            throw MeetingRecordingError.transcriptionFailed("No speech detected")
        }

        var fullTranscript = ""
        var allWords: [[String: Any]] = []
        var totalDuration: Double = 0

        for res in results {
            if let alternatives = res["alternatives"] as? [[String: Any]],
               let firstAlt = alternatives.first {

                if let transcript = firstAlt["transcript"] as? String {
                    fullTranscript += transcript + " "
                }

                if withDiarization, let words = firstAlt["words"] as? [[String: Any]] {
                    allWords = words
                }
            }

            if let resultEndTime = res["resultEndTime"] as? String {
                if let duration = parseGoogleDuration(resultEndTime) {
                    totalDuration = max(totalDuration, duration)
                }
            }
        }

        fullTranscript = fullTranscript.trimmingCharacters(in: .whitespaces)

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

    // MARK: - Private Methods

    /// Convert audio file to WAV format for Google Cloud STT compatibility
    /// Google STT v1 API works best with LINEAR16 (WAV) format
    /// Uses streaming conversion to avoid memory issues with large files
    private func convertToWAV(audioURL: URL) async throws -> URL {
        // Create output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("google_stt_\(UUID().uuidString).wav")

        // Open source audio file
        let sourceFile = try AVAudioFile(forReading: audioURL)
        let sourceFormat = sourceFile.processingFormat
        let totalFrames = AVAudioFrameCount(sourceFile.length)

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

        // Create output file
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: true
        )

        // Process in chunks to avoid memory issues with large files
        // Use 10 second chunks at source sample rate
        let chunkFrames = AVAudioFrameCount(sourceFormat.sampleRate * 10)
        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate

        var framesRead: AVAudioFrameCount = 0
        var totalOutputFrames: AVAudioFrameCount = 0

        while framesRead < totalFrames {
            let framesToRead = min(chunkFrames, totalFrames - framesRead)

            // Create source buffer for this chunk
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: framesToRead) else {
                throw MeetingRecordingError.transcriptionFailed("Failed to create source buffer")
            }

            // Read chunk from source file
            try sourceFile.read(into: sourceBuffer, frameCount: framesToRead)

            // Create output buffer for converted chunk
            let expectedOutputFrames = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 1
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: expectedOutputFrames) else {
                throw MeetingRecordingError.transcriptionFailed("Failed to create output buffer")
            }

            // Convert chunk
            var error: NSError?
            var inputBufferConsumed = false

            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                if inputBufferConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputBufferConsumed = true
                outStatus.pointee = .haveData
                return sourceBuffer
            }

            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

            if let error = error {
                throw MeetingRecordingError.transcriptionFailed("Audio conversion failed: \(error.localizedDescription)")
            }

            // Write converted chunk to output file
            if outputBuffer.frameLength > 0 {
                try outputFile.write(from: outputBuffer)
                totalOutputFrames += outputBuffer.frameLength
            }

            framesRead += framesToRead
        }

        #if DEBUG
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int) ?? 0
        let duration = Double(totalOutputFrames) / targetFormat.sampleRate
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
