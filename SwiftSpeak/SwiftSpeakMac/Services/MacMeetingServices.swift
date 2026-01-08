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

    // MARK: - Recording Health Tracking

    /// Total number of audio buffers successfully written
    private var buffersWritten: Int = 0
    /// Total number of write errors encountered
    private var writeErrors: Int = 0
    /// Last successful write timestamp
    private var lastSuccessfulWrite: Date?
    /// Last progress log time
    private var lastProgressLogTime: Date?

    // MARK: - Auto-Save (Backup)

    /// Auto-save interval in seconds (5 minutes)
    private let autoSaveInterval: TimeInterval = 300
    /// Last auto-save timestamp
    private var lastAutoSaveTime: Date?
    /// Backup file URL
    private var backupURL: URL?

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

        // Reset recording health tracking
        buffersWritten = 0
        writeErrors = 0
        lastSuccessfulWrite = nil
        lastProgressLogTime = nil

        // Reset auto-save state
        lastAutoSaveTime = nil
        backupURL = nil

        macLog("Meeting recording started", category: "MeetingRecorder", level: .info)
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

        // Log recording summary
        let sizeMB = Double(fileSize) / (1024 * 1024)
        macLog("Recording stopped: \(buffersWritten) buffers written, \(writeErrors) errors, \(String(format: "%.2f", sizeMB)) MB", category: "MeetingRecorder", level: .info)

        if writeErrors > 0 {
            macLog("WARNING: Recording had \(writeErrors) write errors - audio may be incomplete", category: "MeetingRecorder", level: .warning)
        }

        // Clean up auto-save backups (recording succeeded)
        cleanupBackups()

        return url
    }

    public func getCurrentLevel() async -> Float {
        _currentLevel
    }

    /// Get current recording statistics for health monitoring
    /// Returns (buffersWritten, writeErrors, fileSizeBytes)
    public func getRecordingStats() async -> (buffers: Int, errors: Int, fileSize: Int64) {
        let fileSize: Int64
        if let url = recordingURL {
            fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        } else {
            fileSize = 0
        }
        return (buffersWritten, writeErrors, fileSize)
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

        do {
            // Convert buffer format if needed
            if let converter = createConverter(from: buffer.format, to: audioFile.processingFormat) {
                if let convertedBuffer = convertBuffer(buffer, using: converter, outputFormat: audioFile.processingFormat) {
                    try audioFile.write(from: convertedBuffer)
                } else {
                    writeErrors += 1
                    macLog("Audio buffer conversion failed (error #\(writeErrors))", category: "MeetingRecorder", level: .error)
                    return
                }
            } else {
                try audioFile.write(from: buffer)
            }

            // Track successful write
            buffersWritten += 1
            lastSuccessfulWrite = Date()

            // Log progress periodically and check auto-save
            let now = Date()
            if let lastLog = lastProgressLogTime {
                if now.timeIntervalSince(lastLog) >= 5.0 {
                    lastProgressLogTime = now
                    if buffersWritten % 500 == 0 {
                        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioFile.url.path)[.size] as? Int64) ?? 0
                        let sizeMB = Double(fileSize) / (1024 * 1024)
                        macLog("Recording progress: \(buffersWritten) buffers, \(String(format: "%.2f", sizeMB)) MB", category: "MeetingRecorder", level: .debug)
                    }
                    // Check if auto-save backup is needed (every 5 minutes)
                    performAutoSaveIfNeeded()
                }
            } else {
                lastProgressLogTime = now
            }
        } catch {
            writeErrors += 1
            let errorDesc = error.localizedDescription
            macLog("CRITICAL: Audio buffer write failed (error #\(writeErrors)): \(errorDesc)", category: "MeetingRecorder", level: .error)

            // Log detailed error info for first few errors
            if writeErrors <= 5 {
                macLog("Write error details - frameLength: \(buffer.frameLength), format: \(buffer.format)", category: "MeetingRecorder", level: .error)
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
        guard let sourceURL = recordingURL else { return }
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
            macLog("Auto-save backup created: \(String(format: "%.1f", sizeMB)) MB", category: "MeetingRecorder", level: .info)
        } catch {
            macLog("Auto-save backup failed: \(error.localizedDescription)", category: "MeetingRecorder", level: .warning)
        }
    }

    /// Clean up backup files after successful recording
    private func cleanupBackups() {
        if let backup = backupURL {
            try? FileManager.default.removeItem(at: backup)
            backupURL = nil
            macLog("Auto-save backup cleaned up", category: "MeetingRecorder", level: .debug)
        }
        lastAutoSaveTime = nil
    }
}
