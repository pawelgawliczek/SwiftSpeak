//
//  MacStreamingAudioRecorder.swift
//  SwiftSpeakMac
//
//  macOS audio recorder for real-time streaming transcription
//  Captures raw PCM16 audio and provides chunks for WebSocket streaming
//

import AVFoundation
import Combine
import Foundation
import SwiftSpeakCore

/// Audio recorder optimized for streaming transcription on macOS
/// Captures raw PCM16 audio and provides chunks via callback
/// Note: NOT @MainActor because audio processing happens on background threads
/// and we need callbacks to fire without actor isolation issues
final class MacStreamingAudioRecorder: NSObject, ObservableObject {

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

    /// Callback for audio chunks - called on background queue
    var onAudioChunk: ((Data) -> Void)?

    /// Callback for audio level updates - called on main queue
    var onAudioLevel: ((Float) -> Void)?

    /// Publisher for audio level (alternative to callback for SwiftUI/Combine integration)
    let audioLevelSubject = PassthroughSubject<Float, Never>()

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var formatConverter: AVAudioConverter?
    private var startTime: Date?
    private var durationTimer: Timer?

    /// Buffer size in samples (50ms chunks at given sample rate)
    private var bufferSize: AVAudioFrameCount {
        AVAudioFrameCount(Double(sampleRate) * 0.05) // 50ms chunks
    }

    // MARK: - Debug Tracking

    /// Count of audio chunks generated
    private var chunksGenerated: Int = 0
    /// Total bytes of audio generated
    private var bytesGenerated: Int = 0
    /// Last time we logged stats
    private var lastStatsLog: Date?

    // MARK: - Initialization

    /// Initialize with sample rate
    /// - Parameter sampleRate: Sample rate in Hz (default 16000 for most providers, 24000 for OpenAI)
    init(sampleRate: Int = 16000) {
        self.sampleRate = sampleRate
        super.init()
    }

    // MARK: - Recording Control

    /// Start recording and streaming audio
    func startRecording() async throws {
        macLog("MacStreamingAudioRecorder.startRecording() - sampleRate: \(self.sampleRate)", category: "StreamingRecorder")

        // Check microphone permission
        guard await checkMicrophonePermission() else {
            throw TranscriptionError.microphonePermissionDenied
        }

        // Create and configure audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Get input format
        let inputFormat = inputNode.outputFormat(forBus: 0)
        macLog("[MacStreamingAudioRecorder] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch", category: "StreamingRecorder")

        // Create target format (PCM16 mono at desired sample rate)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        ) else {
            throw TranscriptionError.recordingFailed("Failed to create target audio format")
        }

        // Create format converter
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw TranscriptionError.recordingFailed("Failed to create audio format converter")
        }

        self.audioEngine = engine
        self.inputNode = inputNode
        self.formatConverter = converter

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }

        // Start engine
        do {
            try engine.start()
            macLog("[MacStreamingAudioRecorder] Audio engine started", category: "StreamingRecorder")
        } catch {
            throw TranscriptionError.recordingFailed("Failed to start audio engine: \(error.localizedDescription)")
        }

        // Update state
        startTime = Date()
        isRecording = true
        error = nil
        levelUpdateCount = 0

        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            DispatchQueue.main.async {
                self.duration = Date().timeIntervalSince(start)
            }
        }

        macLog("[MacStreamingAudioRecorder] Recording started", category: "StreamingRecorder")
    }

    /// Stop recording
    func stopRecording() {
        let kbGenerated = Double(bytesGenerated) / 1024.0
        macLog("[MacStreamingAudioRecorder] Stopping recording - generated \(chunksGenerated) chunks, \(String(format: "%.1f", kbGenerated)) KB", category: "StreamingRecorder")

        durationTimer?.invalidate()
        durationTimer = nil

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        formatConverter = nil

        isRecording = false
        macLog("[MacStreamingAudioRecorder] Recording stopped, duration: \(String(format: "%.1f", duration))s", category: "StreamingRecorder")

        // Reset stats for next session
        chunksGenerated = 0
        bytesGenerated = 0
        lastStatsLog = nil
    }

    /// Cancel recording without saving
    func cancelRecording() {
        macLog("[MacStreamingAudioRecorder] Cancelling recording", category: "StreamingRecorder")
        stopRecording()
        duration = 0
        currentLevel = 0
    }

    // MARK: - Private Methods

    /// Process audio buffer and send PCM16 chunks
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate) + 100
        ) else { return }

        // Convert to target format
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        guard status != .error, error == nil else {
            macLog("[MacStreamingAudioRecorder] Conversion error: \(error?.localizedDescription ?? "unknown")", category: "StreamingRecorder", level: .error)
            return
        }

        // Update audio level for visualization
        updateAudioLevel(from: buffer)

        // Extract PCM16 data
        guard let channelData = outputBuffer.int16ChannelData else { return }
        let frameLength = Int(outputBuffer.frameLength)
        let data = Data(bytes: channelData[0], count: frameLength * 2) // 2 bytes per Int16 sample

        // Track stats
        chunksGenerated += 1
        bytesGenerated += data.count

        // Log stats every 2 seconds
        let now = Date()
        if lastStatsLog == nil || now.timeIntervalSince(lastStatsLog!) >= 2.0 {
            let kbGenerated = Double(bytesGenerated) / 1024.0
            let hasCallback = onAudioChunk != nil
            macLog("[MacStreamingAudioRecorder] 📊 Audio: \(chunksGenerated) chunks, \(String(format: "%.1f", kbGenerated)) KB, callback set: \(hasCallback)", category: "StreamingRecorder")
            lastStatsLog = now
        }

        // Send chunk via callback
        if !data.isEmpty {
            if onAudioChunk != nil {
                onAudioChunk?(data)
            } else if chunksGenerated == 1 {
                // Log once if callback is nil
                macLog("[MacStreamingAudioRecorder] ⚠️ onAudioChunk callback is nil!", category: "StreamingRecorder", level: .warning)
            }
        }
    }

    /// Update audio level from buffer for visualization
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            // Log if we can't get float data (only once)
            if levelUpdateCount == 0 {
                macLog("[MacStreamingAudioRecorder] WARNING: No floatChannelData in buffer, format: \(buffer.format)", category: "StreamingRecorder", level: .warning)
            }
            levelUpdateCount += 1
            return
        }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0.0

        for i in 0..<frameLength {
            let sample = channelData[0][i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        // Convert to 0-1 range with aggressive scaling for low-level mic input
        // macOS mic levels are often very low (0.001-0.01 RMS), need 50-100x scaling
        let level = min(1.0, rms * 50.0)

        levelUpdateCount += 1

        // Call callback and publish on main thread for immediate UI update
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLevel = level
            self.onAudioLevel?(level)
            self.audioLevelSubject.send(level)
        }
    }

    private var levelUpdateCount: Int = 0

    /// Check microphone permission
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
}
