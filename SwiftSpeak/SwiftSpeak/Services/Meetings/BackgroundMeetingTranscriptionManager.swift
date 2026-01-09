//
//  BackgroundMeetingTranscriptionManager.swift
//  SwiftSpeak
//
//  Manages meeting transcription in the background with local notifications
//  Allows users to dismiss the recording view while transcription continues
//

import Foundation
import Combine
import UserNotifications
import SwiftSpeakCore

/// Manages background meeting transcription with notification support
@MainActor
public final class BackgroundMeetingTranscriptionManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = BackgroundMeetingTranscriptionManager()

    // MARK: - Published State

    /// Currently processing meetings (by ID)
    @Published public private(set) var processingMeetingIds: Set<UUID> = []

    /// Active orchestrators being managed
    private var activeOrchestrators: [UUID: MeetingRecordingOrchestrator] = [:]

    // MARK: - Initialization

    private init() {
        requestNotificationPermission()
    }

    // MARK: - Public API

    /// Take over transcription from a MeetingRecordingView
    /// The orchestrator will continue processing in the background
    /// - Parameters:
    ///   - orchestrator: The active orchestrator to manage
    ///   - meetingId: The meeting ID being processed
    public func takeOverTranscription(
        orchestrator: MeetingRecordingOrchestrator,
        meetingId: UUID
    ) {
        appLog("Taking over transcription for meeting: \(meetingId)", category: "BackgroundTranscription")

        processingMeetingIds.insert(meetingId)
        activeOrchestrators[meetingId] = orchestrator

        // Monitor state changes
        Task {
            await monitorOrchestrator(orchestrator, meetingId: meetingId)
        }
    }

    /// Check if a meeting is currently being processed in background
    public func isProcessing(meetingId: UUID) -> Bool {
        processingMeetingIds.contains(meetingId)
    }

    // MARK: - Private Methods

    private func monitorOrchestrator(_ orchestrator: MeetingRecordingOrchestrator, meetingId: UUID) async {
        // Poll for state changes until complete or error
        while true {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            switch orchestrator.state {
            case .complete(let record):
                appLog("Background transcription complete for meeting: \(meetingId)", category: "BackgroundTranscription")
                await sendCompletionNotification(for: record)
                cleanupOrchestrator(meetingId: meetingId)
                return

            case .error(let error):
                appLog("Background transcription failed for meeting: \(meetingId) - \(error.localizedDescription)", category: "BackgroundTranscription", level: .error)
                await sendErrorNotification(meetingId: meetingId, error: error)
                cleanupOrchestrator(meetingId: meetingId)
                return

            case .idle:
                // Orchestrator was reset or cancelled
                appLog("Background transcription cancelled for meeting: \(meetingId)", category: "BackgroundTranscription")
                cleanupOrchestrator(meetingId: meetingId)
                return

            default:
                // Still processing - continue monitoring
                break
            }
        }
    }

    private func cleanupOrchestrator(meetingId: UUID) {
        processingMeetingIds.remove(meetingId)
        activeOrchestrators.removeValue(forKey: meetingId)
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                appLog("Notification permission granted: \(granted)", category: "BackgroundTranscription")
            } catch {
                appLog("Failed to request notification permission: \(error)", category: "BackgroundTranscription", level: .error)
            }
        }
    }

    private func sendCompletionNotification(for record: MeetingRecord) async {
        let content = UNMutableNotificationContent()
        content.title = "Meeting Transcription Complete"
        content.body = "\"\(record.title)\" has been transcribed successfully."
        content.sound = .default
        content.categoryIdentifier = "MEETING_COMPLETE"

        // Add userInfo for deep linking
        content.userInfo = ["meetingId": record.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "meeting-complete-\(record.id.uuidString)",
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            appLog("Sent completion notification for meeting: \(record.title)", category: "BackgroundTranscription")
        } catch {
            appLog("Failed to send notification: \(error)", category: "BackgroundTranscription", level: .error)
        }
    }

    private func sendErrorNotification(meetingId: UUID, error: Error) async {
        let content = UNMutableNotificationContent()
        content.title = "Meeting Transcription Failed"
        content.body = "Transcription failed. You can retry from the Meetings tab."
        content.sound = .default
        content.categoryIdentifier = "MEETING_ERROR"

        content.userInfo = ["meetingId": meetingId.uuidString]

        let request = UNNotificationRequest(
            identifier: "meeting-error-\(meetingId.uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            appLog("Failed to send error notification: \(error)", category: "BackgroundTranscription", level: .error)
        }
    }
}
