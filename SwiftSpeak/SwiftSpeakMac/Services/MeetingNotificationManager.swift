//
//  MeetingNotificationManager.swift
//  SwiftSpeakMac
//
//  Handles notifications for meeting transcription completion
//  Allows background processing while user closes the recording window
//

import Foundation
import Combine
import UserNotifications
import SwiftSpeakCore

// MARK: - Meeting Notification Manager

@MainActor
final class MeetingNotificationManager: NSObject, ObservableObject {
    static let shared = MeetingNotificationManager()

    // Published state for UI binding
    @Published var pendingResult: MeetingRecord?
    @Published var showResultWindow = false

    // Notification identifiers
    private let meetingCompleteCategory = "MEETING_COMPLETE"
    private let viewActionIdentifier = "VIEW_ACTION"

    private override init() {
        super.init()
        setupNotifications()
    }

    // MARK: - Setup

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request permission
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                macLog("Notification permission error: \(error)", category: "Notification", level: .error)
            } else if granted {
                macLog("Notification permission granted", category: "Notification")
            }
        }

        // Define action
        let viewAction = UNNotificationAction(
            identifier: viewActionIdentifier,
            title: "View Transcript",
            options: [.foreground]
        )

        // Define category
        let category = UNNotificationCategory(
            identifier: meetingCompleteCategory,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
    }

    // MARK: - Show Notification

    /// Show notification when meeting transcription is complete
    func notifyMeetingComplete(record: MeetingRecord) {
        // Store the result for when user clicks notification
        self.pendingResult = record

        let content = UNMutableNotificationContent()
        content.title = "Meeting Transcription Complete"
        content.body = "\(record.title) - \(record.formattedDuration)"
        content.sound = .default
        content.categoryIdentifier = meetingCompleteCategory

        // Add record ID to userInfo so we can retrieve it
        content.userInfo = ["recordId": record.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "meeting-\(record.id.uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                macLog("Failed to show notification: \(error)", category: "Notification", level: .error)
            } else {
                macLog("Meeting complete notification shown", category: "Notification")
            }
        }
    }

    /// Show the result window for a completed meeting
    func showResult(for record: MeetingRecord) {
        pendingResult = record
        showResultWindow = true
    }

    /// Clear the pending result
    func clearPendingResult() {
        pendingResult = nil
        showResultWindow = false
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MeetingNotificationManager: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            // Check if this is a meeting notification
            if response.notification.request.content.categoryIdentifier == meetingCompleteCategory {
                // Show the result window
                if let record = pendingResult {
                    showResultWindow = true
                    macLog("Opening result window from notification", category: "Notification")
                }
            }
        }
        completionHandler()
    }
}
