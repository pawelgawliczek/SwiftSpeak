//
//  AudioChunker.swift
//  SwiftSpeakCore
//
//  Service for splitting long audio files into chunks for transcription
//  Supports meeting recordings up to 2+ hours
//

import Foundation
import AVFoundation

/// Service for splitting long audio files into manageable chunks
/// Used for meeting recordings that exceed API file size limits
public actor AudioChunker {
    // MARK: - Configuration

    /// Maximum chunk size in bytes (20MB to stay under 25MB API limits)
    public let maxChunkSizeBytes: Int64

    /// Target chunk duration in seconds (15 minutes)
    public let chunkDurationSeconds: TimeInterval

    /// Overlap between chunks in seconds (helps maintain context at boundaries)
    public let overlapSeconds: TimeInterval

    // MARK: - Initialization

    public init(
        maxChunkSizeBytes: Int64 = 20 * 1024 * 1024,  // 20MB
        chunkDurationSeconds: TimeInterval = 15 * 60,  // 15 minutes
        overlapSeconds: TimeInterval = 2.0             // 2 second overlap
    ) {
        self.maxChunkSizeBytes = maxChunkSizeBytes
        self.chunkDurationSeconds = chunkDurationSeconds
        self.overlapSeconds = overlapSeconds
    }

    // MARK: - Public Interface

    /// Check if audio file needs chunking
    /// - Parameter audioURL: URL of the audio file
    /// - Returns: true if file exceeds size limit
    public func needsChunking(audioURL: URL) throws -> Bool {
        let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        return fileSize > maxChunkSizeBytes
    }

    /// Split audio file into chunks if needed
    /// - Parameters:
    ///   - audioURL: URL of the audio file to chunk
    ///   - progressHandler: Optional callback for progress updates (0.0 - 1.0)
    /// - Returns: Array of chunk URLs (single element if no chunking needed)
    public func chunkIfNeeded(
        audioURL: URL,
        progressHandler: ((Double) async -> Void)? = nil
    ) async throws -> [URL] {
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // If file is small enough, return as-is
        guard fileSize > maxChunkSizeBytes else {
            await progressHandler?(1.0)
            return [audioURL]
        }

        // Need to chunk the file
        return try await splitAudio(url: audioURL, progressHandler: progressHandler)
    }

    /// Get estimated chunk count for an audio file
    /// - Parameter audioURL: URL of the audio file
    /// - Returns: Estimated number of chunks
    public func estimatedChunkCount(audioURL: URL) async throws -> Int {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        if totalSeconds <= chunkDurationSeconds {
            return 1
        }

        return Int(ceil(totalSeconds / chunkDurationSeconds))
    }

    /// Merge multiple diarized transcripts maintaining speaker continuity
    /// - Parameter transcripts: Array of transcripts from each chunk
    /// - Returns: Merged transcript with adjusted timestamps
    public func mergeTranscripts(_ transcripts: [DiarizedTranscript]) -> DiarizedTranscript {
        guard !transcripts.isEmpty else {
            return DiarizedTranscript(segments: [], speakerCount: 0)
        }

        guard transcripts.count > 1 else {
            return transcripts[0]
        }

        var allSegments: [SpeakerSegment] = []
        var timeOffsetMs: Int = 0
        var combinedSpeakerNames: [String: String] = [:]

        for (index, transcript) in transcripts.enumerated() {
            // Merge speaker names
            for (key, value) in transcript.speakerNames {
                if combinedSpeakerNames[key] == nil {
                    combinedSpeakerNames[key] = value
                }
            }

            // Adjust timestamps and add segments
            let offsetSegments = transcript.segments.map { segment in
                SpeakerSegment(
                    speaker: segment.speaker,
                    text: segment.text,
                    startMs: segment.startMs + timeOffsetMs,
                    endMs: segment.endMs + timeOffsetMs,
                    confidence: segment.confidence
                )
            }

            // For chunks after the first, skip segments that might be in the overlap region
            if index > 0 {
                // Skip segments that start before the overlap threshold
                let overlapThresholdMs = Int(overlapSeconds * 1000)
                let filteredSegments = offsetSegments.filter { segment in
                    // Keep segment if it starts after the overlap region
                    segment.startMs - timeOffsetMs >= overlapThresholdMs / 2
                }
                allSegments.append(contentsOf: filteredSegments)
            } else {
                allSegments.append(contentsOf: offsetSegments)
            }

            // Update offset for next chunk (accounting for overlap)
            if let lastSegment = transcript.segments.last {
                timeOffsetMs += lastSegment.endMs - Int(overlapSeconds * 1000)
            }
        }

        // Count unique speakers across all chunks
        let speakerCount = Set(allSegments.map { $0.speaker }).count

        return DiarizedTranscript(
            segments: allSegments,
            speakerCount: speakerCount,
            speakerNames: combinedSpeakerNames
        )
    }

    /// Merge plain text transcripts
    /// - Parameter texts: Array of transcript texts from each chunk
    /// - Returns: Merged text
    public func mergeTexts(_ texts: [String]) -> String {
        texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
    }

    /// Clean up temporary chunk files
    /// - Parameter chunkURLs: Array of chunk file URLs to delete
    public func cleanupChunks(_ chunkURLs: [URL]) {
        for url in chunkURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Private Methods

    private func splitAudio(
        url: URL,
        progressHandler: ((Double) async -> Void)?
    ) async throws -> [URL] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        var chunks: [URL] = []
        var currentTime: TimeInterval = 0
        var chunkIndex = 0
        let totalChunks = Int(ceil(totalSeconds / chunkDurationSeconds))

        while currentTime < totalSeconds {
            // Calculate end time (with some overlap for context)
            let endTime = min(currentTime + chunkDurationSeconds + overlapSeconds, totalSeconds)

            // Export this chunk
            let chunkURL = try await exportChunk(
                asset: asset,
                startTime: currentTime,
                endTime: endTime,
                index: chunkIndex
            )
            chunks.append(chunkURL)

            // Update progress
            let progress = Double(chunkIndex + 1) / Double(totalChunks)
            await progressHandler?(min(progress, 1.0))

            // Move to next chunk (minus overlap)
            currentTime += chunkDurationSeconds
            chunkIndex += 1
        }

        return chunks
    }

    private func exportChunk(
        asset: AVAsset,
        startTime: TimeInterval,
        endTime: TimeInterval,
        index: Int
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meeting_chunk_\(index)_\(UUID().uuidString).m4a")

        // Create export session
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioChunkingError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 1000),
            end: CMTime(seconds: endTime, preferredTimescale: 1000)
        )

        // Export asynchronously
        await exportSession.export()

        // Check export status
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw AudioChunkingError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        case .cancelled:
            throw AudioChunkingError.exportCancelled
        default:
            throw AudioChunkingError.exportFailed("Unexpected export status: \(exportSession.status.rawValue)")
        }
    }
}

// MARK: - Errors

public enum AudioChunkingError: Error, Equatable, Sendable {
    case exportSessionCreationFailed
    case exportFailed(String)
    case exportCancelled
    case fileNotFound
    case invalidAudioFormat

    public var localizedDescription: String {
        switch self {
        case .exportSessionCreationFailed:
            return "Failed to create audio export session"
        case .exportFailed(let reason):
            return "Audio export failed: \(reason)"
        case .exportCancelled:
            return "Audio export was cancelled"
        case .fileNotFound:
            return "Audio file not found"
        case .invalidAudioFormat:
            return "Invalid audio format"
        }
    }
}

// MARK: - Chunk Info

/// Information about a processed audio chunk
public struct AudioChunkInfo: Sendable {
    /// Index of this chunk (0-based)
    public let index: Int

    /// Total number of chunks
    public let totalChunks: Int

    /// URL of the chunk file
    public let url: URL

    /// Start time in the original audio (seconds)
    public let startTime: TimeInterval

    /// End time in the original audio (seconds)
    public let endTime: TimeInterval

    /// Duration of this chunk (seconds)
    public var duration: TimeInterval {
        endTime - startTime
    }

    public init(
        index: Int,
        totalChunks: Int,
        url: URL,
        startTime: TimeInterval,
        endTime: TimeInterval
    ) {
        self.index = index
        self.totalChunks = totalChunks
        self.url = url
        self.startTime = startTime
        self.endTime = endTime
    }
}
