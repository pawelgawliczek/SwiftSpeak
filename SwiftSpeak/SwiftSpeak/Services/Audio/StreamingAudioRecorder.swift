//
//  StreamingAudioRecorder.swift
//  SwiftSpeak
//
//  Audio recorder for real-time streaming transcription
//  Captures raw PCM audio and provides chunks for WebSocket streaming
//

import AVFoundation
import Combine
import Foundation
import SwiftSpeakCore

/// Audio recorder optimized for streaming transcription
/// Captures raw PCM16 audio and provides chunks via callback
@MainActor
final class StreamingAudioRecorder: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Whether currently recording
    @Published private(set) var isRecording = false

    /// Current audio level (0.0 to 1.0) for waveform visualization
    @Published private(set) var currentLevel: Float = 0.0

    /// Recording duration in seconds
    @Published private(set) var duration: TimeInterval = 0

    /// Error if recording failed
    @Published private(set) var error: TranscriptionError?

    // MARK: - Audio Properties

    /// Sample rate for recording (configurable per provider)
    let sampleRate: Int

    /// Callback for audio chunks
    var onAudioChunk: ((Data) -> Void)?

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let sessionManager: AudioSessionManager
    private var startTime: Date?
    private var durationTimer: Timer?

    /// Accumulated audio data for hybrid approach (streaming + final batch transcription)
    private var accumulatedAudioData = Data()
    private let audioDataLock = NSLock()

    /// Buffer size in samples (100ms chunks at given sample rate)
    /// AssemblyAI recommends 100-450ms for optimal accuracy
    /// Larger chunks provide better context per chunk for the STT model
    private var bufferSize: AVAudioFrameCount {
        AVAudioFrameCount(Double(sampleRate) * 0.1) // 100ms chunks (was 50ms)
    }

    // MARK: - Initialization

    /// Initialize with sample rate
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz (default 16000 for most providers, 24000 for OpenAI)
    ///   - sessionManager: Audio session manager
    init(sampleRate: Int = 16000, sessionManager: AudioSessionManager? = nil) {
        self.sampleRate = sampleRate
        self.sessionManager = sessionManager ?? AudioSessionManager.shared
        super.init()
    }

    // MARK: - Recording Control

    /// Start recording and streaming audio
    func startRecording() async throws {
        appLog("startRecording() called - sampleRate: \(self.sampleRate)", category: "StreamingRecorder")

        // Request permission if needed
        if sessionManager.permissionStatus == .undetermined {
            appLog("Requesting microphone permission...", category: "StreamingRecorder")
            let granted = await sessionManager.requestPermission()
            if !granted {
                appLog("Microphone permission denied", category: "StreamingRecorder", level: .error)
                throw TranscriptionError.microphonePermissionDenied
            }
        }

        // Check permission
        appLog("Checking microphone permission...", category: "StreamingRecorder")
        try sessionManager.checkPermission()
        appLog("Permission granted", category: "StreamingRecorder")

        // Configure and activate session for recording
        appLog("Configuring audio session...", category: "StreamingRecorder")
        try sessionManager.configureForRecording()
        try sessionManager.activate()
        appLog("Audio session activated", category: "StreamingRecorder")

        // Create audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Get the native format and create our target format
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        appLog("Native format: \(nativeFormat.sampleRate) Hz, \(nativeFormat.channelCount) channels", category: "StreamingRecorder")

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        ) else {
            appLog("Failed to create target audio format", category: "StreamingRecorder", level: .error)
            throw TranscriptionError.recordingFailed("Failed to create audio format")
        }
        appLog("Target format: \(targetFormat.sampleRate) Hz, PCM16 mono", category: "StreamingRecorder")

        // Install tap on input node
        appLog("Installing audio tap with buffer size: \(self.bufferSize)", category: "StreamingRecorder")
        var chunkCount = 0
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nativeFormat) { [weak self] buffer, time in
            guard let self else { return }

            // Convert buffer to our target format (PCM16, mono, target sample rate)
            guard let convertedBuffer = self.convertBuffer(buffer, to: targetFormat) else {
                return
            }

            // Extract PCM16 data
            let audioData = self.extractPCM16Data(from: convertedBuffer)

            // Update audio level
            let level = self.calculateLevel(from: buffer)
            Task { @MainActor in
                self.currentLevel = level
            }

            // Accumulate audio data for final batch transcription (hybrid approach)
            self.audioDataLock.lock()
            self.accumulatedAudioData.append(audioData)
            self.audioDataLock.unlock()

            // Send chunk to callback for real-time streaming
            chunkCount += 1
            if chunkCount % 20 == 0 {
                appLog("Sent \(chunkCount) audio chunks, latest: \(audioData.count) bytes, total: \(self.accumulatedAudioData.count) bytes", category: "StreamingRecorder", level: .debug)
            }
            self.onAudioChunk?(audioData)
        }

        // Start the engine
        appLog("Starting audio engine...", category: "StreamingRecorder")
        do {
            try engine.start()
            appLog("Audio engine started successfully", category: "StreamingRecorder")
        } catch {
            appLog("Failed to start audio engine: \(error.localizedDescription)", category: "StreamingRecorder", level: .error)
            throw TranscriptionError.recordingFailed("Failed to start audio engine: \(error.localizedDescription)")
        }

        self.audioEngine = engine
        self.inputNode = inputNode
        self.isRecording = true
        self.error = nil
        self.startTime = Date()

        // Clear accumulated audio for new recording
        audioDataLock.lock()
        accumulatedAudioData = Data()
        audioDataLock.unlock()

        // Start duration timer
        startDurationTimer()
        appLog("Recording started", category: "StreamingRecorder")
    }

    /// Stop recording
    func stopRecording() {
        appLog("stopRecording() called", category: "StreamingRecorder")
        stopDurationTimer()

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        isRecording = false
        currentLevel = 0

        sessionManager.deactivate()
        appLog("Recording stopped, duration: \(self.duration) seconds", category: "StreamingRecorder")
    }

    /// Cancel recording
    func cancelRecording() {
        appLog("cancelRecording() called", category: "StreamingRecorder")
        stopRecording()
        duration = 0
    }

    // MARK: - Audio Conversion

    /// Convert audio buffer to target format
    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            return nil
        }

        // Calculate output frame capacity
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            return nil
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            return nil
        }

        return outputBuffer
    }

    /// Extract raw PCM16 data from buffer
    private func extractPCM16Data(from buffer: AVAudioPCMBuffer) -> Data {
        guard let int16Data = buffer.int16ChannelData else {
            return Data()
        }

        let frameLength = Int(buffer.frameLength)
        let data = Data(bytes: int16Data[0], count: frameLength * 2) // 2 bytes per Int16
        return data
    }

    /// Calculate audio level from buffer for visualization
    private func calculateLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let floatData = buffer.floatChannelData else {
            return 0
        }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            sum += abs(floatData[0][i])
        }

        let average = sum / Float(frameLength)

        // Convert to dB-like scale (0 to 1)
        let level = min(1.0, average * 5.0)
        return level
    }

    // MARK: - Audio Levels

    /// Get an array of audio levels for waveform visualization
    func getAudioLevels(count: Int = 12) -> [Float] {
        let baseLevel = currentLevel

        // Generate slightly varied levels for visual interest
        return (0..<count).map { index in
            let variance = Float.random(in: -0.15...0.15)
            let phase = sin(Float(index) * 0.5 + Float(duration) * 3)
            return max(0, min(1, baseLevel + variance * phase * baseLevel))
        }
    }

    // MARK: - Timer

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                if let startTime = self.startTime {
                    self.duration = Date().timeIntervalSince(startTime)
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Accumulated Audio (Hybrid Approach)

    /// Get the accumulated raw PCM16 audio data
    /// Use this for batch transcription after streaming completes
    func getAccumulatedAudioData() -> Data {
        audioDataLock.lock()
        defer { audioDataLock.unlock() }
        return accumulatedAudioData
    }

    /// Save accumulated audio to a WAV file for batch transcription
    /// - Returns: URL to the WAV file, or nil if no audio data
    func saveAccumulatedAudioAsWAV() -> URL? {
        audioDataLock.lock()
        let audioData = accumulatedAudioData
        audioDataLock.unlock()

        guard !audioData.isEmpty else {
            appLog("No accumulated audio data to save", category: "StreamingRecorder", level: .warning)
            return nil
        }

        guard let fileURL = AudioUtils.saveAsWAV(pcmData: audioData, sampleRate: sampleRate, prefix: "streaming") else {
            appLog("Failed to save WAV file", category: "StreamingRecorder", level: .error)
            return nil
        }

        let durationSec = AudioUtils.duration(dataSize: audioData.count, sampleRate: sampleRate)
        appLog("Saved accumulated audio to WAV: \(fileURL.lastPathComponent), ~\(String(format: "%.1f", durationSec))s", category: "StreamingRecorder")
        return fileURL
    }

    /// Clear accumulated audio data
    func clearAccumulatedAudio() {
        audioDataLock.lock()
        accumulatedAudioData = Data()
        audioDataLock.unlock()
        appLog("Cleared accumulated audio data", category: "StreamingRecorder")
    }
}
