//
//  AudioSessionManager.swift
//  SwiftSpeak
//
//  Created by Claude Code on 26/12/2025.
//

import AVFoundation
import Foundation

/// Manages AVAudioSession configuration for recording
/// Handles permissions, interruptions, and audio session lifecycle
@MainActor
final class AudioSessionManager {

    // MARK: - Singleton

    static let shared = AudioSessionManager()

    // MARK: - Properties

    private let audioSession = AVAudioSession.sharedInstance()

    /// Current microphone permission status (iOS 17+)
    var permissionStatus: AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    /// Whether microphone permission has been granted
    var hasPermission: Bool {
        permissionStatus == .granted
    }

    /// Whether audio session is currently active
    private(set) var isSessionActive = false

    // MARK: - Initialization

    private init() {
        setupInterruptionObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Permission

    /// Request microphone permission (iOS 17+)
    /// - Returns: true if permission was granted
    @discardableResult
    func requestPermission() async -> Bool {
        switch permissionStatus {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    /// Check permission and throw appropriate error if not granted
    func checkPermission() throws {
        switch permissionStatus {
        case .granted:
            return
        case .denied:
            throw TranscriptionError.microphonePermissionDenied
        case .undetermined:
            throw TranscriptionError.microphonePermissionNotDetermined
        @unknown default:
            throw TranscriptionError.microphonePermissionDenied
        }
    }

    // MARK: - Session Configuration

    /// Configure audio session for recording
    /// Call this before starting to record
    func configureForRecording() throws {
        do {
            // Set category for recording with default mode
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )

            // Set preferred sample rate (16kHz is optimal for Whisper)
            try audioSession.setPreferredSampleRate(16000)

            // Set preferred buffer duration for low latency
            try audioSession.setPreferredIOBufferDuration(0.005)

        } catch {
            throw TranscriptionError.audioSessionConfigurationFailed(error.localizedDescription)
        }
    }

    /// Activate the audio session
    /// Must be called before recording starts
    func activate() throws {
        guard !isSessionActive else { return }

        do {
            try audioSession.setActive(true, options: [])
            isSessionActive = true
        } catch {
            throw TranscriptionError.audioSessionConfigurationFailed("Failed to activate: \(error.localizedDescription)")
        }
    }

    /// Deactivate the audio session
    /// Call when recording is complete
    func deactivate() {
        guard isSessionActive else { return }

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            isSessionActive = false
        } catch {
            // Log but don't throw - deactivation failure is not critical
            print("AudioSessionManager: Failed to deactivate session: \(error)")
        }
    }

    /// Pre-warm the audio session for faster startup
    /// Call this at app launch for <200ms recording start time
    func preWarm() {
        do {
            try configureForRecording()
            // Don't activate yet - just configure
        } catch {
            print("AudioSessionManager: Pre-warm failed: \(error)")
        }
    }

    // MARK: - Interruption Handling

    private var interruptionHandler: ((Bool) -> Void)?

    /// Set a handler to be called when audio is interrupted
    /// - Parameter handler: Called with `true` when interrupted, `false` when resumed
    func setInterruptionHandler(_ handler: @escaping (Bool) -> Void) {
        interruptionHandler = handler
    }

    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            // Audio was interrupted (e.g., phone call)
            isSessionActive = false
            interruptionHandler?(true)

        case .ended:
            // Interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Try to reactivate
                    try? activate()
                    interruptionHandler?(false)
                }
            }

        @unknown default:
            break
        }
    }
}
