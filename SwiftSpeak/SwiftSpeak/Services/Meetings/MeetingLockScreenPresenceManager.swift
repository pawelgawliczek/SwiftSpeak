//
//  MeetingLockScreenPresenceManager.swift
//  SwiftSpeak
//
//  Manages lock screen presence for meeting recording using Live Activities
//  Shows timer and recording indicator on lock screen and Dynamic Island
//

import Foundation
import Combine
import ActivityKit
import UIKit

/// Manages lock screen presence for meeting recording via Live Activities
@MainActor
public final class MeetingLockScreenPresenceManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = MeetingLockScreenPresenceManager()

    // MARK: - State

    @Published public private(set) var isActive = false

    private var currentActivity: Activity<MeetingRecordingAttributes>?
    private var updateTimer: Timer?
    private var startTime: Date?
    private var pausedDuration: TimeInterval = 0
    private var isPaused = false

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Start showing lock screen presence for a meeting recording
    public func startPresence(title: String = "Meeting Recording") {
        guard !isActive else {
            appLog("Live Activity already active", category: "LiveActivity")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            appLog("Live Activities are not enabled", category: "LiveActivity", level: .error)
            return
        }

        appLog("Starting Live Activity for: \(title)", category: "LiveActivity")

        startTime = Date()
        pausedDuration = 0
        isPaused = false
        isActive = true

        // Create the activity
        let attributes = MeetingRecordingAttributes(meetingTitle: title)
        let initialState = MeetingRecordingAttributes.ContentState(
            elapsedSeconds: 0,
            isPaused: false,
            statusText: "Recording"
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            appLog("Live Activity started: \(currentActivity?.id ?? "unknown")", category: "LiveActivity")

            // Start updating timer
            startUpdateTimer()
        } catch {
            appLog("Failed to start Live Activity: \(error)", category: "LiveActivity", level: .error)
            isActive = false
        }
    }

    /// Pause the recording (update lock screen to show paused state)
    public func pausePresence() {
        guard isActive, let activity = currentActivity else { return }

        if let start = startTime {
            pausedDuration += Date().timeIntervalSince(start)
        }
        startTime = nil
        isPaused = true

        appLog("Pausing Live Activity", category: "LiveActivity")

        Task {
            let state = MeetingRecordingAttributes.ContentState(
                elapsedSeconds: Int(currentElapsedTime),
                isPaused: true,
                statusText: "Paused"
            )
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Resume the recording
    public func resumePresence() {
        guard isActive, let activity = currentActivity else { return }

        startTime = Date()
        isPaused = false

        appLog("Resuming Live Activity", category: "LiveActivity")

        Task {
            let state = MeetingRecordingAttributes.ContentState(
                elapsedSeconds: Int(currentElapsedTime),
                isPaused: false,
                statusText: "Recording"
            )
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Update status text (e.g., "Transcribing...")
    public func updateStatus(_ status: String) {
        guard isActive, let activity = currentActivity else { return }

        Task {
            let state = MeetingRecordingAttributes.ContentState(
                elapsedSeconds: Int(currentElapsedTime),
                isPaused: isPaused,
                statusText: status
            )
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Stop showing lock screen presence
    public func stopPresence() {
        guard isActive else { return }

        appLog("Stopping Live Activity", category: "LiveActivity")

        isActive = false
        stopUpdateTimer()

        // End the activity
        if let activity = currentActivity {
            Task {
                let finalState = MeetingRecordingAttributes.ContentState(
                    elapsedSeconds: Int(currentElapsedTime),
                    isPaused: false,
                    statusText: "Complete"
                )
                await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
            }
        }

        currentActivity = nil
        startTime = nil
        pausedDuration = 0
        isPaused = false
    }

    // MARK: - Private Methods

    private var currentElapsedTime: TimeInterval {
        var elapsed = pausedDuration
        if let start = startTime {
            elapsed += Date().timeIntervalSince(start)
        }
        return elapsed
    }

    private func startUpdateTimer() {
        stopUpdateTimer()

        // Create timer and add to main run loop explicitly
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.updateActivity()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer

        appLog("Live Activity update timer started", category: "LiveActivity")
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateActivity() async {
        guard isActive, !isPaused, let activity = currentActivity else { return }

        let elapsed = Int(currentElapsedTime)
        let state = MeetingRecordingAttributes.ContentState(
            elapsedSeconds: elapsed,
            isPaused: false,
            statusText: "Recording"
        )

        await activity.update(ActivityContent(state: state, staleDate: nil))
    }
}
