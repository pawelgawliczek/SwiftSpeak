//
//  MacDualSourceAudioRecorder.swift
//  SwiftSpeakMac
//
//  Dual-source audio recorder for online meetings
//  Captures microphone (user) and system audio (remote participants) separately
//  Uses ScreenCaptureKit for system audio capture (macOS 13+)
//

import AVFoundation
import AudioToolbox
import ScreenCaptureKit
import SwiftSpeakCore

// MARK: - Dual Source Audio Recorder

/// macOS audio recorder that captures both microphone and system audio separately
/// Microphone = user's voice (tagged as "Me")
/// System audio = remote participants (sent through diarization)
public actor MacDualSourceAudioRecorder: DualSourceMeetingAudioRecorder {

    // MARK: - State

    private var audioEngine: AVAudioEngine?
    private var microphoneFile: AVAudioFile?
    private var systemAudioFile: AVAudioFile?
    private var combinedFile: AVAudioFile?

    private var microphoneURL: URL?
    private var systemAudioURL: URL?
    private var combinedURL: URL?

    private var _isRecording = false
    private var _isPaused = false
    private var _currentDuration: TimeInterval = 0
    private var _microphoneLevel: Float = 0
    private var _systemAudioLevel: Float = 0

    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastPauseTime: Date?

    // ScreenCaptureKit
    private var stream: SCStream?
    private var streamOutput: SystemAudioStreamOutput?
    private var videoOutput: DummyVideoStreamOutput?  // Suppress "stream output NOT found" errors
    private var targetApplication: AudioApplication?
    private var isStreamCapturing = false  // Track stream state to avoid double-stop errors
    /// Dedicated queue for SCStream audio callbacks - must be serial and retained
    private let systemAudioQueue = DispatchQueue(label: "com.swiftspeak.systemAudio", qos: .userInteractive)
    private let systemVideoQueue = DispatchQueue(label: "com.swiftspeak.systemVideo", qos: .utility)

    // Single-source fallback state
    private var singleSourceMode = false
    private var singleSourceURL: URL?
    private var singleSourceFile: AVAudioFile?

    // Device selection
    private var _selectedDeviceID: AudioDeviceID?

    // MARK: - Recording Health Tracking

    /// Total number of audio buffers successfully written
    private var buffersWritten: Int = 0
    /// Total number of write errors encountered
    private var writeErrors: Int = 0
    /// Last successful write timestamp
    private var lastSuccessfulWrite: Date?
    /// Periodic flush interval (in seconds)
    private let flushInterval: TimeInterval = 5.0
    /// Last flush timestamp
    private var lastFlushTime: Date?

    // MARK: - Auto-Save (Backup)

    /// Auto-save interval in seconds (5 minutes)
    private let autoSaveInterval: TimeInterval = 300
    /// Last auto-save timestamp
    private var lastAutoSaveTime: Date?
    /// Backup file URL
    private var backupURL: URL?

    // MARK: - Device Selection

    /// Set the selected audio input device ID
    /// Call this before starting recording to use a specific microphone
    public func setSelectedDeviceID(_ deviceID: AudioDeviceID?) {
        _selectedDeviceID = deviceID
    }

    /// Get the currently selected device ID
    public func getSelectedDeviceID() -> AudioDeviceID? {
        _selectedDeviceID
    }

    // MARK: - Initialization

    public init() {}

    /// Clean up all resources - call this before the recorder is deallocated
    public func cleanup() async {
        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Stop and remove stream outputs before stopping stream
        if #available(macOS 13.0, *) {
            if let stream = stream {
                if let output = streamOutput {
                    try? stream.removeStreamOutput(output, type: .audio)
                }
                if let video = videoOutput {
                    try? stream.removeStreamOutput(video, type: .screen)
                }
            }
            // Only stop if actually capturing
            if isStreamCapturing {
                try? await stream?.stopCapture()
                isStreamCapturing = false
            }
        }
        stream = nil
        streamOutput = nil
        videoOutput = nil

        // Close all files
        microphoneFile = nil
        systemAudioFile = nil
        combinedFile = nil
        singleSourceFile = nil

        // Reset state
        _isRecording = false
        _isPaused = false
    }

    // MARK: - MeetingAudioRecorder Protocol (Single Source)

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
        // Single-source mode - just microphone
        singleSourceMode = true
        singleSourceURL = url

        guard await checkMicrophonePermission() else {
            throw MeetingRecordingError.microphoneAccessDenied
        }

        let engine = AVAudioEngine()

        // Set input device if specified
        if let deviceID = _selectedDeviceID {
            try Self.setInputDevice(deviceID, on: engine)
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        singleSourceFile = try AVAudioFile(forWriting: url, settings: settings)

        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            Task { [weak self] in
                await self?.processMicrophoneBuffer(buffer, toFile: true)
            }
        }

        try engine.start()

        self.audioEngine = engine
        self._isRecording = true
        self._isPaused = false
        self.startTime = Date()
        self.pausedDuration = 0

        // Reset recording health tracking
        buffersWritten = 0
        writeErrors = 0
        lastSuccessfulWrite = nil
        lastFlushTime = nil

        // Reset auto-save state
        lastAutoSaveTime = nil
        backupURL = nil

        macLog("Single-source recording started", category: "DualAudioRecorder", level: .info)
    }

    public func pauseRecording() async {
        guard _isRecording, !_isPaused else { return }
        audioEngine?.pause()
        if #available(macOS 13.0, *), isStreamCapturing {
            try? await stream?.stopCapture()
            isStreamCapturing = false
        }
        _isPaused = true
        lastPauseTime = Date()
    }

    public func resumeRecording() async {
        guard _isRecording, _isPaused else { return }

        if let pauseStart = lastPauseTime {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }

        try? audioEngine?.start()
        if #available(macOS 13.0, *), stream != nil {
            try? await stream?.startCapture()
            isStreamCapturing = true
        }
        _isPaused = false
        lastPauseTime = nil
    }

    public func stopRecording() async throws -> URL {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Remove stream outputs before stopping to prevent callbacks to deallocated handler
        if #available(macOS 13.0, *) {
            if let stream = stream {
                if let output = streamOutput {
                    try? stream.removeStreamOutput(output, type: .audio)
                }
                if let video = videoOutput {
                    try? stream.removeStreamOutput(video, type: .screen)
                }
            }
            // Only stop if actually capturing
            if isStreamCapturing {
                try? await stream?.stopCapture()
                isStreamCapturing = false
            }
        }
        stream = nil
        streamOutput = nil
        videoOutput = nil

        _currentDuration = currentDuration

        let url: URL
        if singleSourceMode, let singleURL = singleSourceURL {
            singleSourceFile = nil
            url = singleURL
        } else if let combined = combinedURL {
            microphoneFile = nil
            systemAudioFile = nil
            combinedFile = nil
            url = combined
        } else {
            throw MeetingRecordingError.recordingFailed("No recording URL")
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MeetingRecordingError.recordingFailed("Recording file not found")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        if fileSize < 1000 {
            throw MeetingRecordingError.audioTooShort
        }

        _isRecording = false
        _isPaused = false
        _microphoneLevel = 0
        _systemAudioLevel = 0
        singleSourceMode = false

        // Log recording summary
        let sizeMB = Double(fileSize) / (1024 * 1024)
        macLog("Recording stopped: \(buffersWritten) buffers written, \(writeErrors) errors, \(String(format: "%.2f", sizeMB)) MB", category: "DualAudioRecorder", level: .info)

        if writeErrors > 0 {
            macLog("WARNING: Recording had \(writeErrors) write errors - audio may be incomplete", category: "DualAudioRecorder", level: .warning)
        }

        // Clean up auto-save backups (recording succeeded)
        // DISABLED: Keep backups for debugging until dual-source audio is fixed
        // cleanupBackups()

        return url
    }

    public func getCurrentLevel() async -> Float {
        // Return combined level for visualization
        max(_microphoneLevel, _systemAudioLevel)
    }

    // MARK: - DualSourceMeetingAudioRecorder Protocol

    public var isDualSourceAvailable: Bool {
        get async {
            // ScreenCaptureKit requires macOS 13+
            if #available(macOS 13.0, *) {
                // Check for screen recording permission
                do {
                    let content = try await SCShareableContent.current
                    return !content.applications.isEmpty
                } catch {
                    return false
                }
            }
            return false
        }
    }

    public func listAudioApplications() async throws -> [AudioApplication] {
        guard #available(macOS 13.0, *) else {
            return []
        }

        let content = try await SCShareableContent.current

        // Filter to running applications that produce audio
        var apps: [AudioApplication] = []

        for app in content.applications {
            // Skip system apps and apps without windows
            guard !app.bundleIdentifier.hasPrefix("com.apple.") ||
                  app.bundleIdentifier == "com.apple.Safari" else {
                continue
            }

            // Prioritize known meeting apps
            let isMeetingApp = AudioApplication.commonMeetingApps.contains(app.bundleIdentifier)

            let audioApp = AudioApplication(
                id: "\(app.processID)",
                name: app.applicationName,
                bundleIdentifier: app.bundleIdentifier,
                icon: nil  // Could extract icon if needed
            )

            if isMeetingApp {
                apps.insert(audioApp, at: 0)  // Meeting apps first
            } else {
                apps.append(audioApp)
            }
        }

        return apps
    }

    public func startDualSourceRecording(
        microphoneURL: URL,
        systemAudioURL: URL,
        combinedURL: URL,
        targetApp: AudioApplication?
    ) async throws {
        guard #available(macOS 13.0, *) else {
            throw MeetingRecordingError.recordingFailed("System audio capture requires macOS 13+")
        }

        singleSourceMode = false
        self.microphoneURL = microphoneURL
        self.systemAudioURL = systemAudioURL
        self.combinedURL = combinedURL
        self.targetApplication = targetApp

        // Check permissions
        guard await checkMicrophonePermission() else {
            throw MeetingRecordingError.microphoneAccessDenied
        }

        // Setup audio files
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        microphoneFile = try AVAudioFile(forWriting: microphoneURL, settings: settings)
        systemAudioFile = try AVAudioFile(forWriting: systemAudioURL, settings: settings)
        combinedFile = try AVAudioFile(forWriting: combinedURL, settings: settings)

        // Setup microphone capture
        let engine = AVAudioEngine()

        // Set input device if specified
        if let deviceID = _selectedDeviceID {
            try Self.setInputDevice(deviceID, on: engine)
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            Task { [weak self] in
                await self?.processMicrophoneBuffer(buffer, toFile: true)
            }
        }

        try engine.start()
        self.audioEngine = engine

        // Setup system audio capture via ScreenCaptureKit
        try await setupSystemAudioCapture(targetApp: targetApp)

        // Update state
        _isRecording = true
        _isPaused = false
        startTime = Date()
        pausedDuration = 0
        lastPauseTime = nil

        // Reset recording health tracking
        buffersWritten = 0
        writeErrors = 0
        lastSuccessfulWrite = nil
        lastFlushTime = nil

        // Reset auto-save state
        lastAutoSaveTime = nil
        backupURL = nil

        macLog("Dual-source recording started", category: "DualAudioRecorder", level: .info)
    }

    public func stopDualSourceRecording() async throws -> DualSourceRecordingResult {
        // Stop microphone
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Remove stream outputs before stopping to prevent callbacks to deallocated handler
        if #available(macOS 13.0, *) {
            if let stream = stream {
                if let output = streamOutput {
                    try? stream.removeStreamOutput(output, type: .audio)
                }
                if let video = videoOutput {
                    try? stream.removeStreamOutput(video, type: .screen)
                }
            }
            // Only stop if actually capturing
            if isStreamCapturing {
                try? await stream?.stopCapture()
                isStreamCapturing = false
            }
        }
        stream = nil
        streamOutput = nil
        videoOutput = nil

        _currentDuration = currentDuration

        // Close files
        microphoneFile = nil
        systemAudioFile = nil
        combinedFile = nil

        // Validate files
        guard let micURL = microphoneURL,
              let sysURL = systemAudioURL,
              let combURL = combinedURL else {
            throw MeetingRecordingError.recordingFailed("Recording URLs not set")
        }

        guard FileManager.default.fileExists(atPath: micURL.path) else {
            throw MeetingRecordingError.recordingFailed("Microphone file not found")
        }

        _isRecording = false
        _isPaused = false
        _microphoneLevel = 0
        _systemAudioLevel = 0

        // Log recording summary
        let combFileSize = (try? FileManager.default.attributesOfItem(atPath: combURL.path)[.size] as? Int64) ?? 0
        let sizeMB = Double(combFileSize) / (1024 * 1024)
        macLog("Recording stopped: \(buffersWritten) buffers written, \(writeErrors) errors, \(String(format: "%.2f", sizeMB)) MB", category: "DualAudioRecorder", level: .info)

        if writeErrors > 0 {
            macLog("WARNING: Recording had \(writeErrors) write errors - audio may be incomplete", category: "DualAudioRecorder", level: .warning)
        }

        // Clean up auto-save backups (recording succeeded)
        // DISABLED: Keep backups for debugging until dual-source audio is fixed
        // cleanupBackups()

        return DualSourceRecordingResult(
            microphoneURL: micURL,
            systemAudioURL: FileManager.default.fileExists(atPath: sysURL.path) ? sysURL : nil,
            combinedURL: combURL
        )
    }

    public func getMicrophoneLevel() async -> Float {
        _microphoneLevel
    }

    public func getSystemAudioLevel() async -> Float {
        _systemAudioLevel
    }

    /// Get current recording statistics for health monitoring
    /// Returns (buffersWritten, writeErrors, fileSizeBytes)
    public func getRecordingStats() async -> (buffers: Int, errors: Int, fileSize: Int64) {
        let fileSize: Int64
        if let url = combinedURL ?? singleSourceURL {
            fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        } else {
            fileSize = 0
        }
        return (buffersWritten, writeErrors, fileSize)
    }

    // MARK: - Auto-Save Methods

    /// Perform auto-save backup of current recording
    /// Called periodically during long recordings to prevent data loss
    private func performAutoSaveIfNeeded() {
        guard _isRecording else { return }

        // Check if enough time has passed since last auto-save
        let now = Date()
        if let lastSave = lastAutoSaveTime {
            guard now.timeIntervalSince(lastSave) >= autoSaveInterval else { return }
        } else {
            // First auto-save after 5 minutes of recording
            guard let start = startTime, now.timeIntervalSince(start) >= autoSaveInterval else { return }
        }

        // Get the source file URL
        guard let sourceURL = combinedURL ?? singleSourceURL else { return }
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }

        // Create backup directory if needed
        let backupDir = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftSpeakBackups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Delete old backup if exists
        if let oldBackup = backupURL {
            try? FileManager.default.removeItem(at: oldBackup)
        }

        // Create new backup with timestamp
        let timestamp = Int(now.timeIntervalSince1970)
        let backupName = "recording_backup_\(timestamp).m4a"
        let newBackupURL = backupDir.appendingPathComponent(backupName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: newBackupURL)
            backupURL = newBackupURL
            lastAutoSaveTime = now

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: newBackupURL.path)[.size] as? Int64) ?? 0
            let sizeMB = Double(fileSize) / (1024 * 1024)
            macLog("Auto-save backup created: \(String(format: "%.1f", sizeMB)) MB", category: "DualAudioRecorder", level: .info)
        } catch {
            macLog("Auto-save backup failed: \(error.localizedDescription)", category: "DualAudioRecorder", level: .warning)
        }
    }

    /// Clean up backup files after successful recording
    private func cleanupBackups() {
        if let backup = backupURL {
            try? FileManager.default.removeItem(at: backup)
            backupURL = nil
            macLog("Auto-save backup cleaned up", category: "DualAudioRecorder", level: .debug)
        }
        lastAutoSaveTime = nil
    }

    // MARK: - Private Methods

    /// Set the input device for an AVAudioEngine
    /// - Parameters:
    ///   - deviceID: The Core Audio device ID to use
    ///   - engine: The AVAudioEngine to configure
    /// - Throws: MeetingRecordingError if device selection fails
    private static func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
        let inputNode = engine.inputNode

        // Get the underlying AudioUnit from the input node
        guard let audioUnit = inputNode.audioUnit else {
            throw MeetingRecordingError.recordingFailed("Failed to get audio unit from input node")
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
            throw MeetingRecordingError.recordingFailed("Failed to set input device (error: \(status))")
        }

        macLog("Set input device ID: \(deviceID)", category: "DualSourceRecorder")
    }

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

    @available(macOS 13.0, *)
    private func setupSystemAudioCapture(targetApp: AudioApplication?) async throws {
        let content = try await SCShareableContent.current

        macLog("Setting up system audio capture, apps available: \(content.applications.count)", category: "DualAudioRecorder", level: .debug)

        // Find target app or capture all system audio
        let filter: SCContentFilter
        if let target = targetApp,
           let app = content.applications.first(where: { "\($0.processID)" == target.id }) {
            macLog("Capturing audio from specific app: \(app.applicationName)", category: "DualAudioRecorder", level: .info)
            // Capture specific app's audio using display-based filter (more reliable for audio)
            filter = SCContentFilter(
                display: content.displays.first!,
                including: [app],
                exceptingWindows: []
            )
        } else {
            // Capture all system audio (excluding our app)
            let excludedApps = content.applications.filter {
                $0.bundleIdentifier == Bundle.main.bundleIdentifier
            }
            macLog("Capturing all system audio, excluding \(excludedApps.count) apps", category: "DualAudioRecorder", level: .info)
            filter = SCContentFilter(
                display: content.displays.first!,
                excludingApplications: excludedApps,
                exceptingWindows: []
            )
        }

        // Configure stream for audio capture
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000
        config.channelCount = 1

        // Minimal video settings (required even for audio-only capture)
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 fps minimum
        config.showsCursor = false
        config.queueDepth = 3  // Allow some buffering

        // Create output handler FIRST (must be retained)
        let output = SystemAudioStreamOutput { [weak self] buffer in
            Task { [weak self] in
                await self?.processSystemAudioBuffer(buffer)
            }
        }
        self.streamOutput = output

        // Create stream with delegate for error reporting
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        self.stream = stream

        // Add output handlers to stream using dedicated serial queues
        // IMPORTANT: Must use dedicated retained queues, not .global()
        do {
            // Add audio output handler
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: systemAudioQueue)
            macLog("Added audio stream output with dedicated queue", category: "DualAudioRecorder", level: .debug)

            // Add dummy video output handler to suppress "stream output NOT found" errors
            let dummyVideo = DummyVideoStreamOutput()
            self.videoOutput = dummyVideo
            try stream.addStreamOutput(dummyVideo, type: .screen, sampleHandlerQueue: systemVideoQueue)
            macLog("Added video stream output (dummy) to suppress errors", category: "DualAudioRecorder", level: .debug)
        } catch {
            macLog("Failed to add stream output: \(error)", category: "DualAudioRecorder", level: .error)
            throw error
        }

        // Start capture
        do {
            try await stream.startCapture()
            self.isStreamCapturing = true
            macLog("System audio capture started successfully", category: "DualAudioRecorder", level: .info)
        } catch {
            macLog("Failed to start system audio capture: \(error)", category: "DualAudioRecorder", level: .error)
            // Clean up on failure
            self.stream = nil
            self.streamOutput = nil
            throw error
        }
    }

    private func processMicrophoneBuffer(_ buffer: AVAudioPCMBuffer, toFile: Bool) {
        guard !_isPaused else { return }

        // Update level
        if let channelData = buffer.floatChannelData?[0] {
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let avg = sum / Float(frameLength)
            _microphoneLevel = min(1.0, avg * 10)
        }

        // Write to microphone file
        if toFile {
            if singleSourceMode {
                writeBuffer(buffer, to: singleSourceFile)
            } else {
                writeBuffer(buffer, to: microphoneFile)
                writeBuffer(buffer, to: combinedFile)  // Also write to combined
            }
        }
    }

    private func processSystemAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard !_isPaused else { return }

        // Update level
        if let channelData = buffer.floatChannelData?[0] {
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let avg = sum / Float(frameLength)
            _systemAudioLevel = min(1.0, avg * 10)
        }

        // Write to system audio file
        writeBuffer(buffer, to: systemAudioFile)
        writeBuffer(buffer, to: combinedFile)  // Also write to combined
    }

    private func writeBuffer(_ buffer: AVAudioPCMBuffer, to file: AVAudioFile?) {
        guard let file = file else { return }

        do {
            // Convert format if needed
            if let converter = createConverter(from: buffer.format, to: file.processingFormat) {
                if let convertedBuffer = convertBuffer(buffer, using: converter, outputFormat: file.processingFormat) {
                    try file.write(from: convertedBuffer)
                } else {
                    writeErrors += 1
                    macLog("Audio buffer conversion failed (error #\(writeErrors))", category: "DualAudioRecorder", level: .error)
                    return
                }
            } else {
                try file.write(from: buffer)
            }

            // Track successful write
            buffersWritten += 1
            lastSuccessfulWrite = Date()

            // Periodic flush to ensure data is on disk (every 5 seconds)
            if let lastFlush = lastFlushTime {
                if Date().timeIntervalSince(lastFlush) >= flushInterval {
                    // Force sync file to disk by closing and reopening is not practical
                    // Instead, we log progress periodically
                    lastFlushTime = Date()
                    if buffersWritten % 500 == 0 {
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: file.url.path)[.size] as? Int64) ?? 0
                        let sizeMB = Double(fileSize) / (1024 * 1024)
                        macLog("Recording progress: \(buffersWritten) buffers, \(String(format: "%.2f", sizeMB)) MB", category: "DualAudioRecorder", level: .debug)
                    }

                    // Check if auto-save backup is needed (every 5 minutes)
                    performAutoSaveIfNeeded()
                }
            } else {
                lastFlushTime = Date()
            }
        } catch {
            writeErrors += 1
            let errorDesc = error.localizedDescription
            macLog("CRITICAL: Audio buffer write failed (error #\(writeErrors)): \(errorDesc)", category: "DualAudioRecorder", level: .error)

            // Log detailed error info for first few errors
            if writeErrors <= 5 {
                macLog("Write error details - frameLength: \(buffer.frameLength), format: \(buffer.format)", category: "DualAudioRecorder", level: .error)
            }
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

// MARK: - System Audio Stream Output

/// SCStreamOutput handler for system audio
@available(macOS 13.0, *)
private class SystemAudioStreamOutput: NSObject, SCStreamOutput {
    private let handler: (AVAudioPCMBuffer) -> Void
    private var callbackCount = 0
    private var lastLogTime: Date?

    init(handler: @escaping (AVAudioPCMBuffer) -> Void) {
        self.handler = handler
        super.init()
        macLog("SystemAudioStreamOutput initialized", category: "DualAudioRecorder", level: .debug)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Log first callback and periodically
        callbackCount += 1
        if callbackCount == 1 {
            macLog("First SCStream callback received, type: \(type)", category: "DualAudioRecorder", level: .info)
        } else if callbackCount % 1000 == 0 {
            macLog("SCStream callbacks received: \(callbackCount)", category: "DualAudioRecorder", level: .debug)
        }

        guard type == .audio else {
            // Log video frames being received (we don't need them but they indicate stream is working)
            if callbackCount <= 5 {
                macLog("Received non-audio frame type: \(type)", category: "DualAudioRecorder", level: .debug)
            }
            return
        }

        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let formatDescription = sampleBuffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            macLog("Failed to get audio format description", category: "DualAudioRecorder", level: .warning)
            return
        }

        guard let format = AVAudioFormat(streamDescription: asbd) else {
            macLog("Failed to create AVAudioFormat", category: "DualAudioRecorder", level: .warning)
            return
        }

        guard let blockBuffer = sampleBuffer.dataBuffer else {
            macLog("No data buffer in sample", category: "DualAudioRecorder", level: .warning)
            return
        }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            macLog("Failed to create PCM buffer", category: "DualAudioRecorder", level: .warning)
            return
        }

        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy audio data
        var dataPointer: UnsafeMutablePointer<Int8>?
        var length: Int = 0
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard status == noErr, let source = dataPointer, length > 0 else {
            macLog("Failed to get block buffer data: \(status)", category: "DualAudioRecorder", level: .warning)
            return
        }

        // Copy data based on format
        if let destination = pcmBuffer.floatChannelData?[0] {
            memcpy(destination, source, min(length, Int(pcmBuffer.frameCapacity) * MemoryLayout<Float>.size))
        } else if let destination = pcmBuffer.int16ChannelData?[0] {
            memcpy(destination, source, min(length, Int(pcmBuffer.frameCapacity) * MemoryLayout<Int16>.size))
        }

        handler(pcmBuffer)
    }
}

// MARK: - Dummy Video Stream Output

/// Dummy SCStreamOutput handler for video frames
/// Only exists to suppress "stream output NOT found" errors - does nothing with the frames
@available(macOS 13.0, *)
private class DummyVideoStreamOutput: NSObject, SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Intentionally empty - we just need to receive the frames to suppress errors
    }
}
