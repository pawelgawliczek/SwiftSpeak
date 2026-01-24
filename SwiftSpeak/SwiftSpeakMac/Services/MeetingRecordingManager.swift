//
//  MeetingRecordingManager.swift
//  SwiftSpeakMac
//
//  Singleton manager for meeting recordings
//  Ensures recording state survives window closures
//  Allows new windows to reconnect to active recordings
//

import Foundation
import SwiftSpeakCore
import Combine

// MARK: - Meeting Recording Manager

/// Singleton manager that maintains meeting recording state across window lifecycles
/// Prevents orphaned recordings when windows close unexpectedly
@MainActor
public final class MeetingRecordingManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = MeetingRecordingManager()

    // MARK: - Published State

    /// Whether a recording is currently active
    @Published public private(set) var isRecordingActive = false

    /// Current recording duration (updated while recording)
    @Published public private(set) var currentDuration: TimeInterval = 0

    /// Current recording file size in MB
    @Published public private(set) var currentFileSizeMB: Double = 0

    // MARK: - Shared Services

    /// Shared audio recorder - survives window closures
    public let audioRecorder = MacDualSourceAudioRecorder()

    /// Shared orchestrator - survives window closures
    public let orchestrator = MeetingRecordingOrchestrator()

    // MARK: - Private State

    private var statusTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupObservers()
        macLog("MeetingRecordingManager initialized", category: "Meeting")
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe orchestrator state changes
        orchestrator.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
    }

    private func handleStateChange(_ state: MeetingRecordingState) {
        switch state {
        case .recording:
            isRecordingActive = true
            startStatusUpdates()
            macLog("Recording became active", category: "Meeting")

        case .idle, .complete, .error:
            isRecordingActive = false
            stopStatusUpdates()
            currentDuration = 0
            currentFileSizeMB = 0
            macLog("Recording became inactive (state: \(state))", category: "Meeting")

        default:
            // Processing states - keep isRecordingActive as-is
            break
        }
    }

    // MARK: - Status Updates

    private func startStatusUpdates() {
        stopStatusUpdates()

        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateStatus()
            }
        }
    }

    private func stopStatusUpdates() {
        statusTimer?.invalidate()
        statusTimer = nil
    }

    private func updateStatus() async {
        currentDuration = orchestrator.duration

        // Get file size from recorder
        let stats = await audioRecorder.getRecordingStats()
        currentFileSizeMB = Double(stats.fileSize) / (1024 * 1024)
    }

    // MARK: - Public Methods

    /// Check if there's an active recording that a new window should reconnect to
    public func hasActiveRecording() -> Bool {
        return isRecordingActive
    }

    /// Get the current orchestrator state
    public func getCurrentState() -> MeetingRecordingState {
        return orchestrator.state
    }

    /// Emergency stop - use when window is closing during recording
    public func emergencyStop() async {
        guard isRecordingActive else { return }

        macLog("Emergency stop triggered", category: "Meeting", level: .warning)
        await orchestrator.stopRecording()
    }

    /// Reset manager state (call after successful completion or cancellation)
    public func reset() {
        isRecordingActive = false
        currentDuration = 0
        currentFileSizeMB = 0
        stopStatusUpdates()
        orchestrator.reset()
        macLog("MeetingRecordingManager reset", category: "Meeting")
    }
}
