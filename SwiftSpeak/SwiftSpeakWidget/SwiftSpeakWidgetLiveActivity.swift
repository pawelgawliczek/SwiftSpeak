//
//  SwiftSpeakWidgetLiveActivity.swift
//  SwiftSpeakWidget
//
//  Live Activity for meeting recording - shows on lock screen and Dynamic Island
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Meeting Recording Attributes

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

// MARK: - Meeting Recording Live Activity Widget

struct MeetingRecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeetingRecordingAttributes.self) { context in
            // Lock screen / Banner UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        recordingIndicator(isPaused: context.state.isPaused)
                        Text(context.state.isPaused ? "Paused" : "REC")
                            .font(.caption.bold())
                            .foregroundStyle(context.state.isPaused ? .orange : .red)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedDuration)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.meetingTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.red)
                        Text(context.state.statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                // Compact leading - recording indicator
                recordingIndicator(isPaused: context.state.isPaused)
            } compactTrailing: {
                // Compact trailing - timer
                Text(context.state.formattedDuration)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(context.state.isPaused ? .orange : .primary)
                    .contentTransition(.numericText())
            } minimal: {
                // Minimal - just recording dot
                recordingIndicator(isPaused: context.state.isPaused)
            }
            .widgetURL(URL(string: "swiftspeak://meeting"))
            .keylineTint(context.state.isPaused ? .orange : .red)
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<MeetingRecordingAttributes>) -> some View {
        HStack(spacing: 16) {
            // Recording indicator
            ZStack {
                Circle()
                    .fill(context.state.isPaused ? Color.orange : Color.red)
                    .frame(width: 44, height: 44)

                Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.meetingTitle)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(context.state.formattedDuration)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(context.state.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // SwiftSpeak branding
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: - Recording Indicator

    @ViewBuilder
    private func recordingIndicator(isPaused: Bool) -> some View {
        Circle()
            .fill(isPaused ? Color.orange : Color.red)
            .frame(width: 12, height: 12)
    }
}

// MARK: - Legacy Attributes (keep for compatibility)

struct SwiftSpeakWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }
    var name: String
}

struct SwiftSpeakWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SwiftSpeakWidgetAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
        }
    }
}

// MARK: - Previews

extension MeetingRecordingAttributes {
    fileprivate static var preview: MeetingRecordingAttributes {
        MeetingRecordingAttributes(meetingTitle: "Team Standup")
    }
}

extension MeetingRecordingAttributes.ContentState {
    fileprivate static var recording: MeetingRecordingAttributes.ContentState {
        MeetingRecordingAttributes.ContentState(elapsedSeconds: 125, isPaused: false, statusText: "Recording")
    }

    fileprivate static var paused: MeetingRecordingAttributes.ContentState {
        MeetingRecordingAttributes.ContentState(elapsedSeconds: 300, isPaused: true, statusText: "Paused")
    }

    fileprivate static var transcribing: MeetingRecordingAttributes.ContentState {
        MeetingRecordingAttributes.ContentState(elapsedSeconds: 1845, isPaused: false, statusText: "Transcribing...")
    }
}

#Preview("Recording", as: .content, using: MeetingRecordingAttributes.preview) {
    MeetingRecordingLiveActivity()
} contentStates: {
    MeetingRecordingAttributes.ContentState.recording
    MeetingRecordingAttributes.ContentState.paused
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: MeetingRecordingAttributes.preview) {
    MeetingRecordingLiveActivity()
} contentStates: {
    MeetingRecordingAttributes.ContentState.recording
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: MeetingRecordingAttributes.preview) {
    MeetingRecordingLiveActivity()
} contentStates: {
    MeetingRecordingAttributes.ContentState.recording
    MeetingRecordingAttributes.ContentState.paused
}
