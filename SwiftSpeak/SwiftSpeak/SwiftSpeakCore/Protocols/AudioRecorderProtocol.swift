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
    var isRecording: Bool { get }

    /// Current audio level (0.0 to 1.0) for waveform visualization
    var currentLevel: Float { get }

    /// Recording duration in seconds
    var duration: TimeInterval { get }

    /// Error if recording failed
    var error: TranscriptionError? { get }

    /// Start recording audio
    func startRecording() async throws

    /// Stop recording and return the audio file URL
    @discardableResult
    func stopRecording() throws -> URL

    /// Cancel recording without saving
    func cancelRecording()

    /// Delete the recorded file
    func deleteRecording()
}
