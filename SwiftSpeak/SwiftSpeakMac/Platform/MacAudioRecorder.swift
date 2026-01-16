//
//  MacAudioRecorder.swift
//  SwiftSpeakMac
//
//  macOS audio recorder using AVAudioEngine
//  Conforms to AudioRecorderProtocol from SwiftSpeakCore
//

import AVFoundation
import AudioToolbox
import Accelerate
import Combine
import SwiftSpeakCore

// MARK: - Recording Format

/// Audio format for recording - provider-specific
enum RecordingFormat {
    case wav      // Linear PCM WAV - universal, works with ALL providers including Google STT
    case aac      // AAC in M4A container - smaller files, NOT supported by Google STT

    /// Get the best format for a transcription provider
    static func forProvider(_ provider: AIProvider) -> RecordingFormat {
        switch provider {
        case .google:
            return .wav  // Google STT doesn't support AAC/M4A
        default:
            return .aac  // Smaller files, works with OpenAI, AssemblyAI, Deepgram, etc.
        }
    }

    var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .aac: return "m4a"
        }
    }

    /// Get audio settings for a specific quality mode
    func audioSettings(quality: AudioQualityMode) -> [String: Any] {
        // Resolve auto to actual quality
        let effectiveQuality = quality == .auto
            ? NetworkQualityMonitor.shared.recommendedQuality
            : quality

        switch self {
        case .wav:
            return [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: effectiveQuality.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        case .aac:
            return [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: effectiveQuality.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: effectiveQuality.encoderQuality.rawValue
            ]
        }
    }

    /// Legacy: default settings (high quality)
    var audioSettings: [String: Any] {
        audioSettings(quality: .high)
    }
}

/// macOS audio recorder using AVAudioEngine
/// Outputs 16kHz mono audio optimized for transcription APIs
@MainActor
final class MacAudioRecorder: NSObject, AudioRecorderProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isRecording = false
    @Published private(set) var currentLevel: Float = 0.0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: TranscriptionError?

    // MARK: - Configuration

    /// Recording format - set based on target transcription provider
    var recordingFormat: RecordingFormat = .aac

    /// Audio quality mode - affects file size and upload speed
    var audioQuality: AudioQualityMode = .auto

    /// Microphone gain boost (1.0 = no boost, 2.0 = +6dB, 4.0 = +12dB)
    /// Applied to audio samples before writing to file
    var microphoneGain: Float = 1.0

    // MARK: - Device Selection

    /// Selected audio input device ID (nil = system default)
    var selectedDeviceID: AudioDeviceID?

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var formatConverter: AVAudioConverter?
    private(set) var recordingURL: URL?
    private var durationTimer: Timer?
    private var startTime: Date?
    /// Captured gain value for current recording (thread-safe copy)
    private var effectiveGain: Float = 1.0

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

        // Capture selected device and format before detached task
        let deviceID = self.selectedDeviceID
        let format = self.recordingFormat
        let quality = self.audioQuality

        // Resolve auto quality to actual quality based on network
        let effectiveQuality = quality == .auto
            ? NetworkQualityMonitor.shared.recommendedQuality
            : quality
        let targetSampleRate = effectiveQuality.sampleRate

        macLog("Recording with quality: \(effectiveQuality.displayName) (\(Int(targetSampleRate))Hz)", category: "Audio")

        // Move heavy audio engine setup off main thread
        // AVAudioEngine initialization can take 2-5 seconds on first use
        let (engine, inputFormat, targetFormat, converter) = try await Task.detached(priority: .userInitiated) {
            // Setup audio engine (HEAVY - can block for seconds on first call)
            let engine = AVAudioEngine()

            // Set input device if specified (must be done before accessing inputNode format)
            if let deviceID = deviceID {
                try Self.setInputDevice(deviceID, on: engine)
            }

            let inputNode = engine.inputNode

            // IMPORTANT: On macOS, we must use the hardware format for the tap.
            // Reading outputFormat(forBus: 0) gives us the native hardware format.
            // We use nil for installTap format to avoid format mismatch errors.
            let hardwareFormat = inputNode.outputFormat(forBus: 0)

            // Validate the hardware format is usable
            guard hardwareFormat.sampleRate > 0 && hardwareFormat.channelCount > 0 else {
                throw TranscriptionError.recordingFailed("Invalid hardware audio format: \(hardwareFormat)")
            }

            print("[MacAudioRecorder] Hardware format: \(hardwareFormat.sampleRate)Hz, \(hardwareFormat.channelCount)ch")

            // Target format: mono Float32 at quality-determined sample rate for transcription
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            ) else {
                throw TranscriptionError.recordingFailed("Failed to create target audio format")
            }
            print("[MacAudioRecorder] Target format: \(Int(targetSampleRate))Hz mono Float32, file format: \(format)")

            // Create format converter (hardware format -> target format)
            // The converter handles both sample rate conversion and channel downmixing
            guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
                throw TranscriptionError.recordingFailed("Failed to create audio format converter from \(hardwareFormat) to \(targetFormat)")
            }
            print("[MacAudioRecorder] Format converter: \(hardwareFormat.sampleRate)Hz \(hardwareFormat.channelCount)ch -> \(targetSampleRate)Hz 1ch")

            return (engine, hardwareFormat, targetFormat, converter)
        }.value

        // Recording settings based on target provider and quality
        let settings = recordingFormat.audioSettings(quality: effectiveQuality)

        // Create output file with explicit processing format
        // File format: WAV (Int16) or AAC - specified by settings
        // Processing format: Float32 - used for write operations
        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            print("[MacAudioRecorder] Output file created: \(recordingFormat), processing: \(audioFile!.processingFormat)")
        } catch {
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        self.formatConverter = converter
        print("[MacAudioRecorder] Format converter ready: \(inputFormat.sampleRate)Hz \(inputFormat.channelCount)ch -> \(targetFormat.sampleRate)Hz \(targetFormat.channelCount)ch")

        // Install tap for audio data
        // IMPORTANT: Use nil for format to let the system use the native hardware format.
        // This avoids format mismatch errors when the hardware format differs from our expected format.
        // The buffer will come in the hardware's native format, and we convert it in processAudioBuffer.
        let bufferSize: AVAudioFrameCount = 4096
        engine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
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
        self.effectiveGain = microphoneGain  // Capture gain for this recording session

        // Start duration timer
        startDurationTimer()
        print("[MacAudioRecorder] Recording started (setup took \(String(format: "%.2f", Date().timeIntervalSince(recordingStartTime)))s)")
    }

    @discardableResult
    func stopRecording() throws -> URL {
        stopDurationTimer()

        // Stop audio engine - must remove tap BEFORE stopping
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            engine.reset()  // Reset engine state to avoid format caching issues
        }
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

        // Stop audio engine - must remove tap BEFORE stopping
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            engine.reset()  // Reset engine state to avoid format caching issues
        }
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
        // Calculate audio level using RMS for better visualization
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(max(frameLength, 1)))

        // Convert to dB and normalize to 0-1 range (-60dB to 0dB)
        let db = 20 * log10(max(rms, 0.000001))
        let normalized = Float(max(0, min(1, (db + 60) / 60)))

        // Update level on main thread
        Task { @MainActor in
            self.currentLevel = normalized
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

        // Apply microphone gain boost if needed
        if convertedBuffer.frameLength > 0 && effectiveGain != 1.0 {
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let frameCount = Int(convertedBuffer.frameLength)
                var gain = effectiveGain
                // Use vDSP for efficient in-place scalar multiplication
                vDSP_vsmul(channelData, 1, &gain, channelData, 1, vDSP_Length(frameCount))
            }
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
        let filename = "swiftspeak_mac_\(UUID().uuidString).\(recordingFormat.fileExtension)"
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

    // MARK: - Device Selection

    /// Set the input device for an AVAudioEngine
    /// - Parameters:
    ///   - deviceID: The Core Audio device ID to use
    ///   - engine: The AVAudioEngine to configure
    /// - Throws: TranscriptionError if device selection fails
    private static func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
        let inputNode = engine.inputNode

        // Get the underlying AudioUnit from the input node
        guard let audioUnit = inputNode.audioUnit else {
            throw TranscriptionError.recordingFailed("Failed to get audio unit from input node")
        }

        // Set the current device on the audio unit
        var deviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw TranscriptionError.recordingFailed("Failed to set input device (error: \(status))")
        }

        print("[MacAudioRecorder] Set input device ID: \(deviceID)")
    }
}
