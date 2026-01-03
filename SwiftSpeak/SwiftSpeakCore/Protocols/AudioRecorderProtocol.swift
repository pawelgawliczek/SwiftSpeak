//
//  AudioRecorderProtocol.swift
//  SwiftSpeak
//
//  Protocol for audio recording to enable testing
//

import Combine
import Foundation

/// Protocol for audio recording operations
/// Enables dependency injection and testing
@MainActor
public protocol AudioRecorderProtocol: ObservableObject {
    /// Whether currently recording
    public var isRecording: Bool { get }

    /// Current audio level (0.0 to 1.0) for waveform visualization
    public var currentLevel: Float { get }

    /// Recording duration in seconds
    public var duration: TimeInterval { get }

    /// Error if recording failed
    public var error: TranscriptionError? { get }

    /// Start recording audio
    public func startRecording() async throws

    /// Stop recording and return the audio file URL
    @discardableResult
    public func stopRecording() throws -> URL

    /// Cancel recording without saving
    public func cancelRecording()

    /// Delete the recorded file
    public func deleteRecording()
}

// MARK: - AudioRecorder Conformance

public extension AudioRecorder: AudioRecorderProtocol {}
