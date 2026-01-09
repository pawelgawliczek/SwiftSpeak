//
//  MeetingRecordingAttributes.swift
//  SwiftSpeak
//
//  Live Activity attributes for meeting recording
//  IMPORTANT: Keep in sync with SwiftSpeakWidget/SwiftSpeakWidgetLiveActivity.swift
//

import Foundation
import ActivityKit

/// Live Activity attributes for meeting recording
/// Displayed on lock screen and Dynamic Island during recording
public struct MeetingRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Recording duration in seconds
        public var elapsedSeconds: Int

        /// Whether recording is paused
        public var isPaused: Bool

        /// Current status text
        public var statusText: String

        public init(elapsedSeconds: Int = 0, isPaused: Bool = false, statusText: String = "Recording") {
            self.elapsedSeconds = elapsedSeconds
            self.isPaused = isPaused
            self.statusText = statusText
        }

        /// Formatted duration string (MM:SS or HH:MM:SS)
        public var formattedDuration: String {
            let hours = elapsedSeconds / 3600
            let minutes = (elapsedSeconds % 3600) / 60
            let seconds = elapsedSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }

    /// Meeting title
    public var meetingTitle: String

    public init(meetingTitle: String = "Meeting Recording") {
        self.meetingTitle = meetingTitle
    }
}
