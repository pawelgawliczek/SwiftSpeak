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
/// Outputs 16kHz mono AAC optimized for transcription APIs
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
    private var formatConverter: AVAudioConverter?
    private(set) var recordingURL: URL?
    private var durationTimer: Timer?
    private var startTime: Date?

    var recordingFileSize: Int? {
        guard let url = recordingURL else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
    }

    // MARK: - Public Methods

    /// Pre-warm the audio engine to avoid delay on first recording
    /// Call this on app launch to initialize the audio subsystem early
    func prewarm() {
        Task.detached(priority: .background) {
            // Creating an AVAudioEngine triggers audio subsystem initialization
            let engine = AVAudioEngine()
            _ = engine.inputNode.outputFormat(forBus: 0)
            // Don't start the engine, just warm up the subsystem
            macLog("Audio engine pre-warmed", category: "Audio")
        }
    }

    /// Async version of prewarm that can be awaited
    /// Use this when you want to show a loading indicator during initialization
    func prewarmAsync() async {
        await Task.detached(priority: .userInitiated) {
            let startTime = Date()
            // Creating an AVAudioEngine triggers audio subsystem initialization
            let engine = AVAudioEngine()
            _ = engine.inputNode.outputFormat(forBus: 0)
            // Don't start the engine, just warm up the subsystem
            let elapsed = Date().timeIntervalSince(startTime)
            macLog("Audio engine pre-warmed in \(String(format: "%.2f", elapsed))s", category: "Audio")
        }.value
    }

    func startRecording() async throws {
        // Check microphone permission
        guard await checkMicrophonePermission() else {
            throw TranscriptionError.microphonePermissionDenied
        }

        // Capture start time IMMEDIATELY before any heavy work
        // This ensures duration tracking starts from when user triggered recording
        let recordingStartTime = Date()

        // Create temporary file URL
        let url = createTemporaryURL()

        // Move heavy audio engine setup off main thread
        // AVAudioEngine initialization can take 2-5 seconds on first use
        let (engine, inputFormat, targetFormat, converter) = try await Task.detached(priority: .userInitiated) {
            // Setup audio engine (HEAVY - can block for seconds on first call)
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            print("[MacAudioRecorder] Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

            // Target format: 16kHz mono PCM (will be encoded to AAC by AVAudioFile)
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            ) else {
                throw TranscriptionError.recordingFailed("Failed to create target audio format")
            }

            // Create format converter (input format -> target format)
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
                throw TranscriptionError.recordingFailed("Failed to create audio format converter")
            }

            return (engine, inputFormat, targetFormat, converter)
        }.value

        // Recording settings (AAC for smaller file size, compatible with all providers)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create output file (must be on main thread for file coordination)
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: settings)
            print("[MacAudioRecorder] Output file processing format: \(audioFile!.processingFormat)")
        } catch {
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        self.formatConverter = converter
        print("[MacAudioRecorder] Format converter created: \(inputFormat.sampleRate)Hz -> \(targetFormat.sampleRate)Hz")

        // Install tap for audio data
        let bufferSize: AVAudioFrameCount = 4096
        engine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, targetFormat: targetFormat)
        }

        // Start engine
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        // Update state - use the captured start time from BEFORE heavy work
        self.audioEngine = engine
        self.recordingURL = url
        self.isRecording = true
        self.startTime = recordingStartTime  // Use early captured time
        self.error = nil

        // Start duration timer
        startDurationTimer()
        print("[MacAudioRecorder] Recording started (setup took \(String(format: "%.2f", Date().timeIntervalSince(recordingStartTime)))s)")
    }

    @discardableResult
    func stopRecording() throws -> URL {
        stopDurationTimer()

        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        formatConverter = nil

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
        print("[MacAudioRecorder] Recording stopped, file size: \(fileSize) bytes")

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
        formatConverter = nil

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

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        // Calculate audio level for waveform visualization
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

        // Convert and write to file
        guard let converter = formatConverter,
              let file = audioFile else { return }

        // Calculate output frame count based on sample rate ratio
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            Task { @MainActor in
                if let err = error {
                    print("[MacAudioRecorder] Conversion error: \(err)")
                    self.error = .recordingFailed(err.localizedDescription)
                }
            }
            return
        }

        // Write converted buffer to file
        if convertedBuffer.frameLength > 0 {
            do {
                try file.write(from: convertedBuffer)
            } catch {
                Task { @MainActor in
                    print("[MacAudioRecorder] Write error: \(error)")
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
