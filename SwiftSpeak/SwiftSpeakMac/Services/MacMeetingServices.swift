//
//  MacMeetingServices.swift
//  SwiftSpeakMac
//
//  macOS-specific meeting services
//  Audio recorder with pause/resume support for meetings
//

import AVFoundation
import SwiftSpeakCore

// MARK: - Meeting Audio Recorder

/// macOS audio recorder with pause/resume support for meetings
/// Implements MeetingAudioRecorder protocol from SwiftSpeakCore
public actor MacMeetingAudioRecorder: MeetingAudioRecorder {

    // MARK: - State

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    private var _isRecording = false
    private var _isPaused = false
    private var _currentDuration: TimeInterval = 0
    private var _currentLevel: Float = 0

    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseTime: Date?

    // MARK: - Initialization

    public init() {}

    // MARK: - MeetingAudioRecorder Protocol

    public var isRecording: Bool {
        _isRecording
    }

    public var isPaused: Bool {
        _isPaused
    }

    public var currentDuration: TimeInterval {
        guard _isRecording, let start = startTime else { return _currentDuration }
        if _isPaused, let pauseStart = lastPauseTime {
            return pauseStart.timeIntervalSince(start) - pausedDuration
        }
        return Date().timeIntervalSince(start) - pausedDuration
    }

    public func startRecording(to url: URL) async throws {
        // Check microphone permission
        guard await checkMicrophonePermission() else {
            throw MeetingRecordingError.recordingFailed("Microphone permission denied")
        }

        // Setup audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Recording settings optimized for transcription
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
            throw MeetingRecordingError.recordingFailed("Failed to create audio file: \(error.localizedDescription)")
        }

        // Install tap for audio data
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            Task { [weak self] in
                await self?.processAudioBuffer(buffer)
            }
        }

        // Start engine
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw MeetingRecordingError.recordingFailed("Failed to start audio engine: \(error.localizedDescription)")
        }

        // Update state
        self.audioEngine = engine
        self.recordingURL = url
        self._isRecording = true
        self._isPaused = false
        self.startTime = Date()
        self.pausedDuration = 0
        self.lastPauseTime = nil
    }

    public func pauseRecording() async {
        guard _isRecording, !_isPaused else { return }

        audioEngine?.pause()
        _isPaused = true
        lastPauseTime = Date()
    }

    public func resumeRecording() async {
        guard _isRecording, _isPaused else { return }

        // Calculate paused duration
        if let pauseStart = lastPauseTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }

        try? audioEngine?.start()
        _isPaused = false
        lastPauseTime = nil
    }

    public func stopRecording() async throws -> URL {
        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Close audio file
        audioFile = nil

        // Get final duration before resetting
        _currentDuration = currentDuration

        // Validate recording
        guard let url = recordingURL else {
            throw MeetingRecordingError.recordingFailed("No recording URL")
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MeetingRecordingError.recordingFailed("Recording file not found")
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        if fileSize < 1000 {
            throw MeetingRecordingError.audioTooShort
        }

        // Reset state
        _isRecording = false
        _isPaused = false
        _currentLevel = 0

        return url
    }

    public func getCurrentLevel() async -> Float {
        _currentLevel
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
        guard !_isPaused else { return }

        // Update audio level
        if let channelData = buffer.floatChannelData?[0] {
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let avg = sum / Float(frameLength)
            _currentLevel = min(1.0, avg * 10) // Normalize
        }

        // Write to file
        guard let audioFile = audioFile else { return }

        // Convert buffer format if needed
        if let converter = createConverter(from: buffer.format, to: audioFile.processingFormat) {
            if let convertedBuffer = convertBuffer(buffer, using: converter, outputFormat: audioFile.processingFormat) {
                try? audioFile.write(from: convertedBuffer)
            }
        } else {
            try? audioFile.write(from: buffer)
        }
    }

    private func createConverter(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) -> AVAudioConverter? {
        guard inputFormat.sampleRate != outputFormat.sampleRate ||
              inputFormat.channelCount != outputFormat.channelCount else {
            return nil
        }
        return AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter, outputFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        var hasData = true

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .haveData
                hasData = false
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        return error == nil ? outputBuffer : nil
    }
}
