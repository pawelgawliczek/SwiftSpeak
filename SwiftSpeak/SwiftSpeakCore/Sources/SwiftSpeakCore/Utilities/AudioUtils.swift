//
//  AudioUtils.swift
//  SwiftSpeak
//
//  Shared audio utilities for WAV file creation and audio data handling.
//

import AVFoundation
import Foundation

/// Utilities for audio data handling
public enum AudioUtils {

    /// Create WAV file data from raw PCM16 audio data
    /// - Parameters:
    ///   - pcmData: Raw PCM16 audio data
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Complete WAV file data with headers
    public static func createWAVData(from pcmData: Data, sampleRate: Int) -> Data {
        var wavData = Data()

        // WAV header constants
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = numChannels * (bitsPerSample / 8)
        let dataSize: UInt32 = UInt32(pcmData.count)
        let fileSize: UInt32 = 36 + dataSize

        // RIFF header
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wavData.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })  // Subchunk size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })   // Audio format (PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavData.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data subchunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        wavData.append(pcmData)

        return wavData
    }

    /// Save PCM16 audio data as a WAV file
    /// - Parameters:
    ///   - pcmData: Raw PCM16 audio data
    ///   - sampleRate: Sample rate in Hz
    ///   - prefix: Optional filename prefix (default: "audio")
    /// - Returns: URL to the saved WAV file, or nil if save failed
    public static func saveAsWAV(pcmData: Data, sampleRate: Int, prefix: String = "audio") -> URL? {
        guard !pcmData.isEmpty else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "\(prefix)_\(UUID().uuidString).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let wavData = createWAVData(from: pcmData, sampleRate: sampleRate)

        do {
            try wavData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Calculate approximate duration in seconds from PCM16 data
    /// - Parameters:
    ///   - dataSize: Size of PCM16 data in bytes
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Duration in seconds
    public static func duration(dataSize: Int, sampleRate: Int) -> Double {
        // PCM16 = 2 bytes per sample, mono
        return Double(dataSize) / Double(sampleRate * 2)
    }

    // MARK: - Audio Compression

    /// Threshold in bytes above which compression is recommended (5MB)
    public static let compressionThreshold: Int = 5 * 1024 * 1024

    /// Compress audio file for transcription upload
    /// Uses low bitrate suitable for speech (32kbps mono AAC)
    /// - Parameters:
    ///   - sourceURL: Original audio file URL
    ///   - targetBitrate: Target bitrate in bits per second (default 32000 for speech)
    /// - Returns: URL to compressed audio file, or original if compression fails/not needed
    public static func compressForTranscription(
        sourceURL: URL,
        targetBitrate: Int = 32000
    ) async throws -> URL {
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let fileSize = attributes[.size] as? Int else {
            return sourceURL
        }

        // Skip compression for small files
        if fileSize < compressionThreshold {
            print("📦 Audio file \(fileSize / 1024)KB - no compression needed")
            return sourceURL
        }

        print("📦 Compressing audio from \(fileSize / 1024 / 1024)MB (target: \(targetBitrate/1000)kbps)...")

        let asset = AVURLAsset(url: sourceURL)

        // Check if file has audio track
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            print("⚠️ No audio track found, using original file")
            return sourceURL
        }

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // Use AVAssetReader/Writer for explicit bitrate control
        do {
            let compressedURL = try await compressWithAssetWriter(
                asset: asset,
                audioTrack: audioTrack,
                outputURL: outputURL,
                targetBitrate: targetBitrate
            )

            // Check compressed size
            if let compressedAttributes = try? FileManager.default.attributesOfItem(atPath: compressedURL.path),
               let compressedSize = compressedAttributes[.size] as? Int {
                let ratio = Double(fileSize) / Double(compressedSize)
                print("📦 Compressed: \(fileSize / 1024 / 1024)MB → \(compressedSize / 1024)KB (ratio: \(String(format: "%.1f", ratio))x)")
            }
            return compressedURL

        } catch {
            print("⚠️ Compression failed: \(error.localizedDescription)")
            return sourceURL
        }
    }

    /// Compress audio using AVAssetReader/Writer with explicit bitrate control
    private static func compressWithAssetWriter(
        asset: AVAsset,
        audioTrack: AVAssetTrack,
        outputURL: URL,
        targetBitrate: Int
    ) async throws -> URL {
        // Use a helper class to handle Sendable requirements
        let compressor = AudioCompressor(
            asset: asset,
            audioTrack: audioTrack,
            outputURL: outputURL,
            targetBitrate: targetBitrate
        )
        return try await compressor.compress()
    }
}

// MARK: - Audio Compressor Helper

/// Helper class for audio compression that handles Sendable requirements
private final class AudioCompressor: @unchecked Sendable {
    private let asset: AVAsset
    private let audioTrack: AVAssetTrack
    private let outputURL: URL
    private let targetBitrate: Int

    init(asset: AVAsset, audioTrack: AVAssetTrack, outputURL: URL, targetBitrate: Int) {
        self.asset = asset
        self.audioTrack = audioTrack
        self.outputURL = outputURL
        self.targetBitrate = targetBitrate
    }

    func compress() async throws -> URL {
        // Set up reader
        let reader = try AVAssetReader(asset: asset)

        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,  // 16kHz is plenty for speech
            AVNumberOfChannelsKey: 1,  // Mono
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        // Set up writer
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)

        let writerInputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: targetBitrate,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // Start reading and writing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Process all samples
        while true {
            if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                while !writerInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
                }
                writerInput.append(sampleBuffer)
            } else {
                break
            }
        }

        writerInput.markAsFinished()

        if reader.status == .failed {
            writer.cancelWriting()
            throw reader.error ?? TranscriptionError.invalidAudioFile
        }

        await writer.finishWriting()

        if writer.status == .completed {
            return outputURL
        } else {
            throw writer.error ?? TranscriptionError.invalidAudioFile
        }
    }
}

// MARK: - AudioUtils Extension for shouldCompress

extension AudioUtils {
    /// Check if audio file should be compressed before upload
    /// - Parameter url: Audio file URL
    /// - Returns: true if file exceeds compression threshold
    public static func shouldCompress(url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int else {
            return false
        }
        return fileSize >= compressionThreshold
    }
}

// MARK: - Audio Chunking

extension AudioUtils {
    /// Maximum chunk size for providers with size limits
    /// Google has 10MB limit but sends base64 encoded (+33% overhead)
    /// 5MB file → ~6.7MB base64, safely under 10MB
    public static let maxChunkSize: Int = 5 * 1024 * 1024

    /// Maximum chunk duration for Google's sync API (60 second limit)
    /// Use 55 seconds for safety margin
    public static let maxGoogleChunkDuration: Double = 55.0

    /// Check if audio file needs to be chunked for upload
    /// - Parameter url: Audio file URL
    /// - Returns: true if file exceeds chunk size limit
    public static func needsChunking(url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int else {
            return false
        }
        return fileSize > maxChunkSize
    }

    /// Get file size in bytes
    public static func fileSize(url: URL) -> Int? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int else {
            return nil
        }
        return size
    }

    /// Split audio file into chunks under the size limit
    /// - Parameters:
    ///   - sourceURL: Original audio file URL
    ///   - maxSize: Maximum chunk size in bytes (default: 5MB)
    ///   - asWAV: If true, export chunks as WAV (LINEAR16) for Google compatibility
    ///   - maxDuration: Maximum chunk duration in seconds (for Google's 60s sync limit)
    /// - Returns: Array of chunk file URLs
    public static func splitIntoChunks(
        sourceURL: URL,
        maxSize: Int = maxChunkSize,
        asWAV: Bool = false,
        maxDuration: Double? = nil
    ) async throws -> [URL] {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = duration.seconds

        // For WAV output, calculate based on 16kHz mono 16-bit = 32KB/sec
        // For M4A, use actual file size ratio
        let bytesPerSecond: Double
        if asWAV {
            // WAV at 16kHz mono 16-bit
            bytesPerSecond = 16000 * 2
        } else if let fileSize = fileSize(url: sourceURL) {
            bytesPerSecond = Double(fileSize) / totalSeconds
        } else {
            // Fallback estimate
            bytesPerSecond = 16000
        }

        // Calculate chunk duration based on size limit
        let targetChunkSize = Double(maxSize) * 0.9
        var chunkDuration = targetChunkSize / bytesPerSecond

        // Apply duration limit if specified (for Google's 60s sync API limit)
        if let maxDur = maxDuration {
            chunkDuration = min(chunkDuration, maxDur)
        }

        // Check if chunking is needed (either size or duration)
        let estimatedOutputSize = asWAV ? Int(totalSeconds * bytesPerSecond) : (fileSize(url: sourceURL) ?? 0)
        let needsChunkingForSize = estimatedOutputSize > maxSize
        let needsChunkingForDuration = maxDuration != nil && totalSeconds > maxDuration!

        guard needsChunkingForSize || needsChunkingForDuration else {
            // File is small enough, return as single chunk (may need conversion)
            if asWAV {
                // Convert single file to WAV
                let wavURL = try await exportChunkAsWAV(
                    asset: asset,
                    timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: totalSeconds, preferredTimescale: 600)),
                    chunkIndex: 0
                )
                return [wavURL]
            }
            return [sourceURL]
        }

        // Calculate number of chunks needed
        let numChunks = Int(ceil(totalSeconds / chunkDuration))

        let format = asWAV ? "WAV" : "M4A"
        print("📦 Splitting audio into \(numChunks) \(format) chunks (~\(Int(chunkDuration))s each)")

        var chunkURLs: [URL] = []
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard audioTracks.first != nil else {
            throw TranscriptionError.invalidAudioFile
        }

        for i in 0..<numChunks {
            let startTime = CMTime(seconds: Double(i) * chunkDuration, preferredTimescale: 600)
            let endTime = CMTime(seconds: min(Double(i + 1) * chunkDuration, totalSeconds), preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, end: endTime)

            let chunkURL: URL
            if asWAV {
                chunkURL = try await exportChunkAsWAV(
                    asset: asset,
                    timeRange: timeRange,
                    chunkIndex: i
                )
            } else {
                chunkURL = try await exportChunkAsM4A(
                    asset: asset,
                    timeRange: timeRange,
                    chunkIndex: i
                )
            }
            chunkURLs.append(chunkURL)
        }

        return chunkURLs
    }

    /// Export a single chunk as M4A (passthrough - no re-encoding)
    private static func exportChunkAsM4A(
        asset: AVAsset,
        timeRange: CMTimeRange,
        chunkIndex: Int
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk_\(chunkIndex)_\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        // Use passthrough to avoid re-encoding (preserves quality)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw TranscriptionError.invalidAudioFile
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange

        await exportSession.export()

        if exportSession.status == .completed {
            if let size = fileSize(url: outputURL) {
                let durationSec = Int(timeRange.duration.seconds)
                print("📦 Chunk \(chunkIndex + 1): \(size / 1024)KB, \(durationSec)s (M4A passthrough)")
            }
            return outputURL
        } else {
            throw exportSession.error ?? TranscriptionError.invalidAudioFile
        }
    }

    /// Export a single chunk as WAV (LINEAR16) for Google compatibility
    /// Uses 16kHz mono 16-bit format
    private static func exportChunkAsWAV(
        asset: AVAsset,
        timeRange: CMTimeRange,
        chunkIndex: Int
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk_\(chunkIndex)_\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw TranscriptionError.invalidAudioFile
        }

        // Set up reader
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange

        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)

        // Collect PCM data
        reader.startReading()
        var pcmData = Data()

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                var length = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
                if let dataPointer = dataPointer {
                    pcmData.append(UnsafeBufferPointer(start: dataPointer, count: length))
                }
            }
        }

        if reader.status == .failed {
            throw reader.error ?? TranscriptionError.invalidAudioFile
        }

        // Create WAV file
        let wavData = createWAVData(from: pcmData, sampleRate: 16000)
        try wavData.write(to: outputURL)

        if let size = fileSize(url: outputURL) {
            print("📦 Chunk \(chunkIndex + 1): \(size / 1024)KB (WAV)")
        }

        return outputURL
    }

    /// Clean up temporary chunk files
    public static func cleanupChunks(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Convert an audio file to WAV format (LINEAR16, 16kHz mono)
    /// Used for Google Cloud STT compatibility without chunking
    public static func convertToWAV(sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        return try await exportChunkAsWAV(asset: asset, timeRange: timeRange, chunkIndex: 0)
    }
}
