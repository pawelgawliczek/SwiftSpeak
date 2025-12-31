//
//  AudioRecorder.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import AVFoundation
import Combine
import Foundation

/// Wraps AVAudioRecorder for voice recording
/// Publishes audio levels for waveform visualization
@MainActor
final class AudioRecorder: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Whether currently recording
    @Published private(set) var isRecording = false

    /// Current audio level (0.0 to 1.0) for waveform visualization
    @Published private(set) var currentLevel: Float = 0.0

    /// Recording duration in seconds
    @Published private(set) var duration: TimeInterval = 0

    /// Error if recording failed
    @Published private(set) var error: TranscriptionError?

    // MARK: - Properties

    /// URL of the recorded audio file (available after recording stops)
    private(set) var recordingURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?

    private let sessionManager: AudioSessionManager

    /// Audio format settings optimized for Whisper API
    /// - m4a format (AAC codec)
    /// - 16kHz sample rate (Whisper's native rate)
    /// - Mono channel
    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    // MARK: - Initialization

    init(sessionManager: AudioSessionManager? = nil) {
        self.sessionManager = sessionManager ?? AudioSessionManager.shared
        super.init()
    }

    // MARK: - Recording Control

    /// Start recording audio
    /// - Throws: TranscriptionError if recording fails to start
    func startRecording() async throws {
        // Request permission if needed (must come before checkPermission)
        if sessionManager.permissionStatus == .undetermined {
            let granted = await sessionManager.requestPermission()
            if !granted {
                throw TranscriptionError.microphonePermissionDenied
            }
        }

        // Check permission (will throw if denied)
        try sessionManager.checkPermission()

        // Configure and activate session
        try sessionManager.configureForRecording()
        try sessionManager.activate()

        // Create temporary file URL
        let url = createTemporaryURL()

        do {
            // Create and configure recorder
            let recorder = try AVAudioRecorder(url: url, settings: recordingSettings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true

            // Prepare recorder (allocates resources)
            guard recorder.prepareToRecord() else {
                throw TranscriptionError.recordingFailed("Failed to prepare recorder")
            }

            // Start recording
            guard recorder.record() else {
                throw TranscriptionError.recordingFailed("Failed to start recording")
            }

            self.audioRecorder = recorder
            self.recordingURL = url
            self.isRecording = true
            self.error = nil
            self.duration = 0

            // Start timers
            startTimers()

        } catch let recorderError as TranscriptionError {
            throw recorderError
        } catch {
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }
    }

    /// Stop recording and return the audio file URL
    /// - Returns: URL of the recorded audio file
    /// - Throws: TranscriptionError if no audio was recorded
    @discardableResult
    func stopRecording() throws -> URL {
        stopTimers()

        guard let recorder = audioRecorder else {
            throw TranscriptionError.noAudioRecorded
        }

        let recordedDuration = recorder.currentTime

        recorder.stop()
        audioRecorder = nil
        isRecording = false
        currentLevel = 0

        // Deactivate session
        sessionManager.deactivate()

        // Verify we have a recording
        guard recordedDuration > 0.1, let url = recordingURL else {
            throw TranscriptionError.noAudioRecorded
        }

        // Verify file exists and has content
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int,
              fileSize > 0
        else {
            throw TranscriptionError.noAudioRecorded
        }

        return url
    }

    /// Cancel recording without saving
    func cancelRecording() {
        stopTimers()

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        currentLevel = 0
        duration = 0

        // Delete the file if it exists
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil

        sessionManager.deactivate()
    }

    /// Delete the recorded file
    func deleteRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    // MARK: - Audio Levels

    /// Get current audio level for waveform
    /// Returns value between 0.0 and 1.0
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder, isRecording else {
            return 0
        }

        recorder.updateMeters()

        // Get average power in decibels (-160 to 0)
        let averagePower = recorder.averagePower(forChannel: 0)

        // Convert to linear scale (0.0 to 1.0)
        // -60 dB is considered silence, 0 dB is max
        let minDb: Float = -60
        let normalizedValue = max(0, (averagePower - minDb) / (-minDb))

        return normalizedValue
    }

    /// Get an array of audio levels for waveform visualization
    /// - Parameter count: Number of samples to return
    /// - Returns: Array of levels between 0.0 and 1.0
    func getAudioLevels(count: Int = 12) -> [Float] {
        let baseLevel = getAudioLevel()

        // Generate slightly varied levels for visual interest
        return (0..<count).map { index in
            let variance = Float.random(in: -0.15...0.15)
            let phase = sin(Float(index) * 0.5 + Float(duration) * 3)
            return max(0, min(1, baseLevel + variance * phase * baseLevel))
        }
    }

    // MARK: - File Management

    private func createTemporaryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "swiftspeak_recording_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(fileName)
    }

    /// Get the file size of the current recording in bytes
    var recordingFileSize: Int? {
        guard let url = recordingURL else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int
    }

    /// Get the file size in MB
    var recordingFileSizeMB: Double? {
        guard let bytes = recordingFileSize else { return nil }
        return Double(bytes) / (1024 * 1024)
    }

    // MARK: - Timers

    private func startTimers() {
        // Level metering timer (60fps for smooth animation)
        levelTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.currentLevel = self.getAudioLevel()
            }
        }

        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                if let recorder = self.audioRecorder {
                    self.duration = recorder.currentTime
                }
            }
        }
    }

    private func stopTimers() {
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = .recordingFailed("Recording did not complete successfully")
            }
            self.isRecording = false
            self.stopTimers()
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.error = .recordingFailed(error?.localizedDescription ?? "Encoding error")
            self.isRecording = false
            self.stopTimers()
        }
    }
}
