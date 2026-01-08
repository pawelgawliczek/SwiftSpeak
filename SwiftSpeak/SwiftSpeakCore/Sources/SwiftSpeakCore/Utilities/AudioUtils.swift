//
//  AudioUtils.swift
//  SwiftSpeak
//
//  Shared audio utilities for WAV file creation and audio data handling.
//

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
}
