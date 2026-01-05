//
//  MacAudioRecorder.swift
//  SwiftSpeakMac
//
//  macOS audio recorder using AVAudioEngine
//  Conforms to AudioRecorderProtocol from SwiftSpeakCore
//

import AVFoundation
import Combine
import SwiftSpeakCore

/// macOS audio recorder using AVAudioEngine
/// Outputs 16kHz mono AAC optimized for Whisper API
@MainActor
final class MacAudioRecorder: NSObject, AudioRecorderProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRecording = false
    @Published private(set) var currentLevel: Float = 0.0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: TranscriptionError?

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var recordingURL: URL?
    private var durationTimer: Timer?
    private var startTime: Date?

    var recordingFileSize: Int? {
        guard let url = recordingURL else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
    }

    // MARK: - Public Methods

    func startRecording() async throws {
        // Check microphone permission
        guard await checkMicrophonePermission() else {
            throw TranscriptionError.microphonePermissionDenied
        }

        // Create temporary file URL
        let url = createTemporaryURL()

        // Setup audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Recording settings (16kHz mono for Whisper)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create output file
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: settings)
        } catch {
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        // Install tap for audio data
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // Start engine
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        // Update state
        self.audioEngine = engine
        self.recordingURL = url
        self.isRecording = true
        self.startTime = Date()
        self.error = nil

        // Start duration timer
        startDurationTimer()
    }

    @discardableResult
    func stopRecording() throws -> URL {
        stopDurationTimer()

        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Close audio file
        audioFile = nil

        // Validate recording
        guard let url = recordingURL else {
            throw TranscriptionError.noAudioRecorded
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.noAudioRecorded
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        if fileSize < 1000 {
            throw TranscriptionError.audioTooShort(duration: duration, minDuration: 0.5)
        }

        // Reset state
        isRecording = false
        currentLevel = 0

        return url
    }

    func cancelRecording() {
        stopDurationTimer()

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordingURL = nil
        isRecording = false
        currentLevel = 0
        duration = 0
    }

    func deleteRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    // MARK: - Private Methods

    private func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level for waveform
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let average = sum / Float(max(frameLength, 1))

        // Update level on main thread
        Task { @MainActor in
            self.currentLevel = min(1.0, average * 10)
        }

        // Write to file (format conversion happens automatically)
        if let file = audioFile {
            do {
                try file.write(from: buffer)
            } catch {
                Task { @MainActor in
                    self.error = .recordingFailed(error.localizedDescription)
                }
            }
        }
    }

    private func createTemporaryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "swiftspeak_mac_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            Task { @MainActor in
                self.duration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
