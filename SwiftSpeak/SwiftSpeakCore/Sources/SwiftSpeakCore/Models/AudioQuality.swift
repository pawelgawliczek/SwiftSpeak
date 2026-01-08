//
//  AudioQuality.swift
//  SwiftSpeakCore
//
//  Audio quality mode for transcription - trades quality for upload speed
//

import Foundation
import AVFoundation

/// Audio quality mode for transcription - trades quality for upload speed
public enum AudioQualityMode: String, CaseIterable, Codable, Sendable {
    case auto = "auto"              // Detect network and adjust automatically
    case high = "high"              // Best quality (16kHz, high bitrate) - for fast networks
    case standard = "standard"      // Balanced (16kHz, medium bitrate)
    case lowBandwidth = "low"       // Smaller files (8kHz) - for slow networks

    public var displayName: String {
        switch self {
        case .auto: return "Auto (detect network)"
        case .high: return "High Quality"
        case .standard: return "Standard"
        case .lowBandwidth: return "Low Bandwidth"
        }
    }

    public var description: String {
        switch self {
        case .auto: return "Automatically adjusts based on network speed"
        case .high: return "Best transcription accuracy, larger files (~100KB/min)"
        case .standard: return "Good quality, moderate file size (~60KB/min)"
        case .lowBandwidth: return "Faster uploads, smaller files (~30KB/min)"
        }
    }

    /// Sample rate for this quality mode
    public var sampleRate: Double {
        switch self {
        case .auto, .high, .standard:
            return 16000  // 16kHz - optimal for speech recognition
        case .lowBandwidth:
            return 8000   // 8kHz - still good for speech, much smaller files
        }
    }

    /// AAC encoder quality for this mode
    public var encoderQuality: AVAudioQuality {
        switch self {
        case .auto, .high:
            return .high
        case .standard:
            return .medium
        case .lowBandwidth:
            return .low
        }
    }
}
