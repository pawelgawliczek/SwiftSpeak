//
//  MockAudioRecorder.swift
//  SwiftSpeak
//
//  Mock audio recorder for testing PowerModeOrchestrator
//

import Combine
import Foundation
import SwiftSpeakCore

/// Mock audio recorder for unit testing
/// Simulates recording behavior without actual audio capture
@MainActor
final class MockAudioRecorder: ObservableObject, AudioRecorderProtocol {

    // MARK: - Published Properties (Protocol Requirements)

    @Published private(set) var isRecording = false
    @Published private(set) var currentLevel: Float = 0.0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: TranscriptionError?

    // MARK: - Configuration

    /// Whether recording should succeed
    var shouldSucceed: Bool = true

    /// Error to throw when shouldSucceed is false
    var errorToThrow: TranscriptionError = .recordingFailed("Mock recording error")

    /// Simulated recording URL
    var mockRecordingURL: URL = URL(fileURLWithPath: "/tmp/mock_recording.m4a")

    /// Simulated delay for start recording (seconds)
    var startDelay: TimeInterval = 0

    /// Simulated delay for stop recording (seconds)
    var stopDelay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Number of times startRecording was called
    private(set) var startRecordingCallCount = 0

    /// Number of times stopRecording was called
    private(set) var stopRecordingCallCount = 0

    /// Number of times cancelRecording was called
    private(set) var cancelRecordingCallCount = 0

    /// Number of times deleteRecording was called
    private(set) var deleteRecordingCallCount = 0

    // MARK: - AudioRecorderProtocol Methods

    func startRecording() async throws {
        startRecordingCallCount += 1

        if startDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
        }

        if !shouldSucceed {
            throw errorToThrow
        }

        isRecording = true
    }

    @discardableResult
    func stopRecording() throws -> URL {
        stopRecordingCallCount += 1
        isRecording = false

        if !shouldSucceed {
            throw errorToThrow
        }

        return mockRecordingURL
    }

    func cancelRecording() {
        cancelRecordingCallCount += 1
        isRecording = false
    }

    func deleteRecording() {
        deleteRecordingCallCount += 1
    }

    // MARK: - Test Helpers

    /// Reset all recorded state
    func reset() {
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
        cancelRecordingCallCount = 0
        deleteRecordingCallCount = 0
        shouldSucceed = true
        errorToThrow = .recordingFailed("Mock recording error")
        isRecording = false
        duration = 0
        currentLevel = 0
        error = nil
    }

    /// Simulate audio level changes
    func simulateLevel(_ level: Float) {
        currentLevel = level
    }

    /// Simulate duration updates
    func simulateDuration(_ duration: TimeInterval) {
        self.duration = duration
    }
}

// MARK: - Preset Configurations

extension MockAudioRecorder {

    /// Quick success with no delay
    static var instant: MockAudioRecorder {
        let recorder = MockAudioRecorder()
        recorder.shouldSucceed = true
        recorder.startDelay = 0
        recorder.stopDelay = 0
        return recorder
    }

    /// Simulates recording failure
    static var recordingFailure: MockAudioRecorder {
        let recorder = MockAudioRecorder()
        recorder.shouldSucceed = false
        recorder.errorToThrow = .recordingFailed("Mock recording failed")
        return recorder
    }

    /// Simulates microphone permission denied
    static var permissionDenied: MockAudioRecorder {
        let recorder = MockAudioRecorder()
        recorder.shouldSucceed = false
        recorder.errorToThrow = .microphonePermissionDenied
        return recorder
    }
}
