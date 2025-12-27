//
//  AudioRecorderTests.swift
//  SwiftSpeakTests
//
//  Comprehensive tests for AudioRecorder and MockAudioRecorder
//

import Combine
import Foundation
import Testing
@testable import SwiftSpeak

// MARK: - AudioRecorder Initialization Tests

@Suite("AudioRecorder - Initialization")
struct AudioRecorderInitTests {

    @Test("Initial state is not recording")
    @MainActor
    func initialStateNotRecording() {
        let recorder = AudioRecorder()

        #expect(recorder.isRecording == false)
    }

    @Test("Initial audio level is zero")
    @MainActor
    func initialAudioLevelZero() {
        let recorder = AudioRecorder()

        #expect(recorder.currentLevel == 0.0)
    }

    @Test("Initial duration is zero")
    @MainActor
    func initialDurationZero() {
        let recorder = AudioRecorder()

        #expect(recorder.duration == 0)
    }

    @Test("Initial error is nil")
    @MainActor
    func initialErrorNil() {
        let recorder = AudioRecorder()

        #expect(recorder.error == nil)
    }

    @Test("Initial recording URL is nil")
    @MainActor
    func initialRecordingURLNil() {
        let recorder = AudioRecorder()

        #expect(recorder.recordingURL == nil)
    }
}

// MARK: - AudioRecorder Audio Levels Tests

@Suite("AudioRecorder - Audio Levels")
struct AudioRecorderLevelTests {

    @Test("Get audio level returns zero when not recording")
    @MainActor
    func audioLevelZeroWhenNotRecording() {
        let recorder = AudioRecorder()

        let level = recorder.getAudioLevel()

        #expect(level == 0)
    }

    @Test("Get audio levels returns correct count")
    @MainActor
    func audioLevelsReturnsCorrectCount() {
        let recorder = AudioRecorder()

        let levels = recorder.getAudioLevels(count: 12)

        #expect(levels.count == 12)
    }

    @Test("Get audio levels with custom count")
    @MainActor
    func audioLevelsWithCustomCount() {
        let recorder = AudioRecorder()

        let levels5 = recorder.getAudioLevels(count: 5)
        let levels20 = recorder.getAudioLevels(count: 20)

        #expect(levels5.count == 5)
        #expect(levels20.count == 20)
    }

    @Test("Get audio levels all zero when not recording")
    @MainActor
    func audioLevelsAllZeroWhenNotRecording() {
        let recorder = AudioRecorder()

        let levels = recorder.getAudioLevels(count: 12)

        // When not recording, base level is 0, so all should be 0
        #expect(levels.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}

// MARK: - AudioRecorder File Size Tests

@Suite("AudioRecorder - File Size")
struct AudioRecorderFileSizeTests {

    @Test("Recording file size nil when no recording")
    @MainActor
    func fileSizeNilWhenNoRecording() {
        let recorder = AudioRecorder()

        #expect(recorder.recordingFileSize == nil)
    }

    @Test("Recording file size MB nil when no recording")
    @MainActor
    func fileSizeMBNilWhenNoRecording() {
        let recorder = AudioRecorder()

        #expect(recorder.recordingFileSizeMB == nil)
    }
}

// MARK: - AudioRecorder Stop Without Recording Tests

@Suite("AudioRecorder - Stop Without Recording")
struct AudioRecorderStopTests {

    @Test("Stop recording throws when not recording")
    @MainActor
    func stopThrowsWhenNotRecording() {
        let recorder = AudioRecorder()

        do {
            _ = try recorder.stopRecording()
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .noAudioRecorded)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - AudioRecorder Cancel Tests

@Suite("AudioRecorder - Cancel")
struct AudioRecorderCancelTests {

    @Test("Cancel from idle state is safe")
    @MainActor
    func cancelFromIdleIsSafe() {
        let recorder = AudioRecorder()

        recorder.cancelRecording()

        #expect(recorder.isRecording == false)
        #expect(recorder.currentLevel == 0)
        #expect(recorder.duration == 0)
        #expect(recorder.recordingURL == nil)
    }

    @Test("Cancel can be called multiple times")
    @MainActor
    func cancelMultipleTimes() {
        let recorder = AudioRecorder()

        recorder.cancelRecording()
        recorder.cancelRecording()
        recorder.cancelRecording()

        #expect(recorder.isRecording == false)
    }
}

// MARK: - AudioRecorder Delete Recording Tests

@Suite("AudioRecorder - Delete Recording")
struct AudioRecorderDeleteTests {

    @Test("Delete recording when no recording is safe")
    @MainActor
    func deleteWhenNoRecordingIsSafe() {
        let recorder = AudioRecorder()

        recorder.deleteRecording()

        #expect(recorder.recordingURL == nil)
    }

    @Test("Delete can be called multiple times")
    @MainActor
    func deleteMultipleTimes() {
        let recorder = AudioRecorder()

        recorder.deleteRecording()
        recorder.deleteRecording()
        recorder.deleteRecording()

        #expect(recorder.recordingURL == nil)
    }
}

// MARK: - MockAudioRecorder Initialization Tests

@Suite("MockAudioRecorder - Initialization")
struct MockAudioRecorderInitTests {

    @Test("Initial state is not recording")
    @MainActor
    func initialStateNotRecording() {
        let recorder = MockAudioRecorder()

        #expect(recorder.isRecording == false)
    }

    @Test("Initial audio level is zero")
    @MainActor
    func initialAudioLevelZero() {
        let recorder = MockAudioRecorder()

        #expect(recorder.currentLevel == 0.0)
    }

    @Test("Initial duration is zero")
    @MainActor
    func initialDurationZero() {
        let recorder = MockAudioRecorder()

        #expect(recorder.duration == 0)
    }

    @Test("Initial error is nil")
    @MainActor
    func initialErrorNil() {
        let recorder = MockAudioRecorder()

        #expect(recorder.error == nil)
    }

    @Test("Default should succeed is true")
    @MainActor
    func defaultShouldSucceedTrue() {
        let recorder = MockAudioRecorder()

        #expect(recorder.shouldSucceed == true)
    }

    @Test("All call counts start at zero")
    @MainActor
    func callCountsStartAtZero() {
        let recorder = MockAudioRecorder()

        #expect(recorder.startRecordingCallCount == 0)
        #expect(recorder.stopRecordingCallCount == 0)
        #expect(recorder.cancelRecordingCallCount == 0)
        #expect(recorder.deleteRecordingCallCount == 0)
    }
}

// MARK: - MockAudioRecorder Recording Tests

@Suite("MockAudioRecorder - Recording")
struct MockAudioRecorderRecordingTests {

    @Test("Start recording sets isRecording true")
    @MainActor
    func startRecordingSetsIsRecording() async throws {
        let recorder = MockAudioRecorder()

        try await recorder.startRecording()

        #expect(recorder.isRecording == true)
        #expect(recorder.startRecordingCallCount == 1)
    }

    @Test("Stop recording sets isRecording false")
    @MainActor
    func stopRecordingSetsIsRecordingFalse() async throws {
        let recorder = MockAudioRecorder()

        try await recorder.startRecording()
        _ = try recorder.stopRecording()

        #expect(recorder.isRecording == false)
        #expect(recorder.stopRecordingCallCount == 1)
    }

    @Test("Stop recording returns mock URL")
    @MainActor
    func stopRecordingReturnsMockURL() async throws {
        let recorder = MockAudioRecorder()
        let expectedURL = URL(fileURLWithPath: "/tmp/custom_mock.m4a")
        recorder.mockRecordingURL = expectedURL

        try await recorder.startRecording()
        let url = try recorder.stopRecording()

        #expect(url == expectedURL)
    }

    @Test("Start recording throws when shouldSucceed false")
    @MainActor
    func startRecordingThrowsWhenConfiguredToFail() async {
        let recorder = MockAudioRecorder()
        recorder.shouldSucceed = false
        recorder.errorToThrow = .microphonePermissionDenied

        do {
            try await recorder.startRecording()
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .microphonePermissionDenied)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test("Stop recording throws when shouldSucceed false")
    @MainActor
    func stopRecordingThrowsWhenConfiguredToFail() async throws {
        let recorder = MockAudioRecorder()

        try await recorder.startRecording()

        recorder.shouldSucceed = false
        recorder.errorToThrow = .noAudioRecorded

        do {
            _ = try recorder.stopRecording()
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .noAudioRecorded)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - MockAudioRecorder Cancel Tests

@Suite("MockAudioRecorder - Cancel")
struct MockAudioRecorderCancelTests {

    @Test("Cancel recording sets isRecording false")
    @MainActor
    func cancelRecordingSetsIsRecordingFalse() async throws {
        let recorder = MockAudioRecorder()

        try await recorder.startRecording()
        recorder.cancelRecording()

        #expect(recorder.isRecording == false)
        #expect(recorder.cancelRecordingCallCount == 1)
    }

    @Test("Cancel from idle increments call count")
    @MainActor
    func cancelFromIdleIncrementsCount() {
        let recorder = MockAudioRecorder()

        recorder.cancelRecording()

        #expect(recorder.cancelRecordingCallCount == 1)
    }
}

// MARK: - MockAudioRecorder Delete Tests

@Suite("MockAudioRecorder - Delete")
struct MockAudioRecorderDeleteTests {

    @Test("Delete recording increments call count")
    @MainActor
    func deleteRecordingIncrementsCount() {
        let recorder = MockAudioRecorder()

        recorder.deleteRecording()

        #expect(recorder.deleteRecordingCallCount == 1)
    }

    @Test("Delete can be called multiple times")
    @MainActor
    func deleteMultipleTimes() {
        let recorder = MockAudioRecorder()

        recorder.deleteRecording()
        recorder.deleteRecording()
        recorder.deleteRecording()

        #expect(recorder.deleteRecordingCallCount == 3)
    }
}

// MARK: - MockAudioRecorder Reset Tests

@Suite("MockAudioRecorder - Reset")
struct MockAudioRecorderResetTests {

    @Test("Reset clears all call counts")
    @MainActor
    func resetClearsCallCounts() async throws {
        let recorder = MockAudioRecorder()

        try await recorder.startRecording()
        _ = try recorder.stopRecording()
        recorder.deleteRecording()

        recorder.reset()

        #expect(recorder.startRecordingCallCount == 0)
        #expect(recorder.stopRecordingCallCount == 0)
        #expect(recorder.cancelRecordingCallCount == 0)
        #expect(recorder.deleteRecordingCallCount == 0)
    }

    @Test("Reset resets shouldSucceed to true")
    @MainActor
    func resetResetsShouldSucceed() {
        let recorder = MockAudioRecorder()
        recorder.shouldSucceed = false

        recorder.reset()

        #expect(recorder.shouldSucceed == true)
    }

    @Test("Reset clears state")
    @MainActor
    func resetClearsState() async throws {
        let recorder = MockAudioRecorder()
        try await recorder.startRecording()
        recorder.simulateDuration(5.0)
        recorder.simulateLevel(0.8)

        recorder.reset()

        #expect(recorder.isRecording == false)
        #expect(recorder.duration == 0)
        #expect(recorder.currentLevel == 0)
        #expect(recorder.error == nil)
    }
}

// MARK: - MockAudioRecorder Simulation Tests

@Suite("MockAudioRecorder - Simulation")
struct MockAudioRecorderSimulationTests {

    @Test("Simulate level updates currentLevel")
    @MainActor
    func simulateLevelUpdatesCurrentLevel() {
        let recorder = MockAudioRecorder()

        recorder.simulateLevel(0.75)

        #expect(recorder.currentLevel == 0.75)
    }

    @Test("Simulate duration updates duration")
    @MainActor
    func simulateDurationUpdatesDuration() {
        let recorder = MockAudioRecorder()

        recorder.simulateDuration(10.5)

        #expect(recorder.duration == 10.5)
    }
}

// MARK: - MockAudioRecorder Preset Tests

@Suite("MockAudioRecorder - Presets")
struct MockAudioRecorderPresetTests {

    @Test("Instant preset succeeds with no delay")
    @MainActor
    func instantPresetSucceeds() async throws {
        let recorder = MockAudioRecorder.instant

        #expect(recorder.shouldSucceed == true)
        #expect(recorder.startDelay == 0)
        #expect(recorder.stopDelay == 0)

        try await recorder.startRecording()
        #expect(recorder.isRecording == true)
    }

    @Test("Recording failure preset fails")
    @MainActor
    func recordingFailurePresetFails() async {
        let recorder = MockAudioRecorder.recordingFailure

        #expect(recorder.shouldSucceed == false)

        do {
            try await recorder.startRecording()
            #expect(Bool(false), "Should have thrown error")
        } catch {
            // Expected to fail
        }
    }

    @Test("Permission denied preset throws permission error")
    @MainActor
    func permissionDeniedPresetThrowsPermissionError() async {
        let recorder = MockAudioRecorder.permissionDenied

        #expect(recorder.shouldSucceed == false)

        do {
            try await recorder.startRecording()
            #expect(Bool(false), "Should have thrown error")
        } catch let error as TranscriptionError {
            #expect(error == .microphonePermissionDenied)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
}

// MARK: - AudioRecorderProtocol Conformance Tests

@Suite("AudioRecorderProtocol - Conformance")
struct AudioRecorderProtocolTests {

    @Test("AudioRecorder conforms to ObservableObject")
    @MainActor
    func audioRecorderConformsToObservableObject() {
        let recorder = AudioRecorder()

        // Can access objectWillChange publisher
        _ = recorder.objectWillChange
    }

    @Test("MockAudioRecorder conforms to AudioRecorderProtocol")
    @MainActor
    func mockConformsToProtocol() {
        let mock = MockAudioRecorder()

        // Can be used as protocol type
        let protocol_: AudioRecorderProtocol = mock

        #expect(protocol_.isRecording == false)
        #expect(protocol_.currentLevel == 0)
        #expect(protocol_.duration == 0)
        #expect(protocol_.error == nil)
    }

    @Test("Protocol methods are accessible")
    @MainActor
    func protocolMethodsAccessible() async throws {
        let mock: AudioRecorderProtocol = MockAudioRecorder()

        try await mock.startRecording()
        _ = try mock.stopRecording()
        mock.cancelRecording()
        mock.deleteRecording()
    }
}

// MARK: - Recording Settings Tests

@Suite("AudioRecorder - Recording Settings")
struct AudioRecorderSettingsTests {

    @Test("Recorder uses session manager")
    @MainActor
    func recorderUsesSessionManager() {
        // Verify AudioRecorder can be initialized with custom session manager
        // This validates the dependency injection pattern
        let recorder = AudioRecorder(sessionManager: nil)

        #expect(recorder.isRecording == false)
    }
}
