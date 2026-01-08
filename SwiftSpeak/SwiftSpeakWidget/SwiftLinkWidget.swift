//
//  SwiftLinkWidget.swift
//  SwiftSpeakWidget
//
//  Lock Screen and Home Screen widgets for SwiftLink status
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data

struct SwiftLinkWidgetEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let isRecording: Bool
    let targetAppName: String?
    let targetAppIcon: String?
    let sessionEndTime: Date?

    var timeRemaining: TimeInterval? {
        guard let endTime = sessionEndTime, isActive else { return nil }
        let remaining = endTime.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    var timeRemainingText: String {
        guard let remaining = timeRemaining else { return "Active" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static var placeholder: SwiftLinkWidgetEntry {
        SwiftLinkWidgetEntry(
            date: Date(),
            isActive: true,
            isRecording: false,
            targetAppName: "WhatsApp",
            targetAppIcon: "message.fill",
            sessionEndTime: Date().addingTimeInterval(300)
        )
    }

    static var inactive: SwiftLinkWidgetEntry {
        SwiftLinkWidgetEntry(
            date: Date(),
            isActive: false,
            isRecording: false,
            targetAppName: nil,
            targetAppIcon: nil,
            sessionEndTime: nil
        )
    }
}

// MARK: - Timeline Provider

struct SwiftLinkTimelineProvider: TimelineProvider {
    private let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    func placeholder(in context: Context) -> SwiftLinkWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SwiftLinkWidgetEntry) -> Void) {
        completion(readWidgetData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwiftLinkWidgetEntry>) -> Void) {
        let entry = readWidgetData()

        // Determine refresh policy
        let refreshDate: Date
        if entry.isActive {
            // Refresh every minute when active (for countdown)
            refreshDate = Date().addingTimeInterval(60)
        } else {
            // Refresh every 15 minutes when inactive
            refreshDate = Date().addingTimeInterval(15 * 60)
        }

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func readWidgetData() -> SwiftLinkWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)

        let isActive = defaults?.bool(forKey: "swiftLinkSessionActive") ?? false
        let isRecording = defaults?.bool(forKey: "swiftLinkWidgetIsRecording") ?? false
        let targetAppName = defaults?.string(forKey: "swiftLinkWidgetTargetAppName")
        let targetAppIcon = defaults?.string(forKey: "swiftLinkWidgetTargetAppIcon")

        var sessionEndTime: Date? = nil
        if let endTimeInterval = defaults?.double(forKey: "swiftLinkWidgetSessionEndTime"), endTimeInterval > 0 {
            sessionEndTime = Date(timeIntervalSince1970: endTimeInterval)
        }

        return SwiftLinkWidgetEntry(
            date: Date(),
            isActive: isActive,
            isRecording: isRecording,
            targetAppName: targetAppName,
            targetAppIcon: targetAppIcon,
            sessionEndTime: sessionEndTime
        )
    }
}

// MARK: - Widget Views

// Lock Screen Circular Widget
struct SwiftLinkAccessoryCircularView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        ZStack {
            if entry.isActive {
                // Active state - filled circle with icon
                AccessoryWidgetBackground()
                Image(systemName: "link.circle.fill")
                    .font(.title)
                    .foregroundStyle(.green)
            } else {
                // Inactive state
                AccessoryWidgetBackground()
                Image(systemName: "link.circle")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Lock Screen Rectangular Widget
struct SwiftLinkAccessoryRectangularView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.isActive ? "link.circle.fill" : "link.circle")
                .font(.title2)
                .foregroundStyle(entry.isActive ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("SwiftLink")
                    .font(.headline)
                    .widgetAccentable()

                if entry.isActive {
                    HStack(spacing: 4) {
                        if let appName = entry.targetAppName {
                            Text(appName)
                        }
                        Text("•")
                        Text(entry.timeRemainingText)
                        if entry.isRecording {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// Home Screen Small Widget
struct SwiftLinkSmallWidgetView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: entry.isActive ? "link.circle.fill" : "link.circle")
                    .font(.title2)
                    .foregroundStyle(entry.isActive ? .green : .orange)

                Spacer()

                if entry.isRecording {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Title
            Text("SwiftLink")
                .font(.subheadline.weight(.semibold))

            // Status
            if entry.isActive {
                VStack(alignment: .leading, spacing: 2) {
                    if let appName = entry.targetAppName {
                        Text(appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(entry.timeRemainingText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap to start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration

struct SwiftLinkWidget: Widget {
    let kind: String = "SwiftLinkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwiftLinkTimelineProvider()) { entry in
            SwiftLinkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SwiftLink")
        .description("Monitor and control SwiftLink background dictation")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall
        ])
    }
}

struct SwiftLinkWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            SwiftLinkAccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            SwiftLinkAccessoryRectangularView(entry: entry)
        case .systemSmall:
            SwiftLinkSmallWidgetView(entry: entry)
        default:
            SwiftLinkSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Circular - Active", as: .accessoryCircular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.placeholder
}

#Preview("Circular - Inactive", as: .accessoryCircular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.inactive
}

#Preview("Rectangular - Active", as: .accessoryRectangular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.placeholder
}

#Preview("Small - Active", as: .systemSmall) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.placeholder
}

#Preview("Small - Inactive", as: .systemSmall) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.inactive
}
