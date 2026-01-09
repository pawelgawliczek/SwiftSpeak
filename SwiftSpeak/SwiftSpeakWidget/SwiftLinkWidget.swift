//
//  SwiftLinkWidget.swift
//  SwiftSpeakWidget
//
//  Simple toggle widget for SwiftLink - tap to enable/disable
//

import WidgetKit
import SwiftUI

// MARK: - Widget Data

struct SwiftLinkWidgetEntry: TimelineEntry {
    let date: Date
    let isActive: Bool

    static var active: SwiftLinkWidgetEntry {
        SwiftLinkWidgetEntry(date: Date(), isActive: true)
    }

    static var inactive: SwiftLinkWidgetEntry {
        SwiftLinkWidgetEntry(date: Date(), isActive: false)
    }
}

// MARK: - Timeline Provider

struct SwiftLinkTimelineProvider: TimelineProvider {
    private let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    func placeholder(in context: Context) -> SwiftLinkWidgetEntry {
        .active
    }

    func getSnapshot(in context: Context, completion: @escaping (SwiftLinkWidgetEntry) -> Void) {
        completion(readWidgetData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwiftLinkWidgetEntry>) -> Void) {
        let entry = readWidgetData()

        // Refresh every 30 seconds to keep status current
        let refreshDate = Date().addingTimeInterval(30)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func readWidgetData() -> SwiftLinkWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let isActive = defaults?.bool(forKey: "swiftLinkSessionActive") ?? false
        return SwiftLinkWidgetEntry(date: Date(), isActive: isActive)
    }
}

// MARK: - Widget Views

// Lock Screen Circular Widget - Simple toggle button
struct SwiftLinkCircularView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image("SwiftSpeakLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(entry.isActive ? .green : .primary)
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "swiftspeak://swiftlink-toggle"))
    }
}

// Lock Screen Rectangular Widget - Toggle with label
struct SwiftLinkRectangularView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(entry.isActive ? Color.green.opacity(0.3) : Color.primary.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image("SwiftSpeakLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(entry.isActive ? .green : .primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("SwiftSpeak")
                    .font(.headline)
                    .widgetAccentable()

                Text(entry.isActive ? "On" : "Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "swiftspeak://swiftlink-toggle"))
    }
}

// Home Screen Small Widget - Large toggle button
struct SwiftLinkSmallView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        ZStack {
            // Background color based on state
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(entry.isActive ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))

            VStack(spacing: 12) {
                // Large icon with SwiftSpeak logo
                ZStack {
                    Circle()
                        .fill(entry.isActive ? Color.green : Color.orange)
                        .frame(width: 56, height: 56)

                    Image("SwiftSpeakLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.white)
                }

                // Label
                Text("SwiftSpeak")
                    .font(.subheadline.weight(.semibold))

                // Status
                Text(entry.isActive ? "Active" : "Tap to Start")
                    .font(.caption)
                    .foregroundStyle(entry.isActive ? .green : .secondary)
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "swiftspeak://swiftlink-toggle"))
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
        .description("Tap to enable or disable SwiftLink background dictation")
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
            SwiftLinkCircularView(entry: entry)
        case .accessoryRectangular:
            SwiftLinkRectangularView(entry: entry)
        case .systemSmall:
            SwiftLinkSmallView(entry: entry)
        default:
            SwiftLinkSmallView(entry: entry)
        }
    }
}

// MARK: - Previews

#Preview("Circular - Active", as: .accessoryCircular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.active
}

#Preview("Circular - Inactive", as: .accessoryCircular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.inactive
}

#Preview("Rectangular - Active", as: .accessoryRectangular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.active
}

#Preview("Rectangular - Inactive", as: .accessoryRectangular) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.inactive
}

#Preview("Small - Active", as: .systemSmall) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.active
}

#Preview("Small - Inactive", as: .systemSmall) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.inactive
}
