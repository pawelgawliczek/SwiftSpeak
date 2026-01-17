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

// Home Screen Small Widget - Compact 3-button layout
struct SwiftLinkSmallView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            // SwiftLink button at top (larger, primary action)
            Link(destination: URL(string: "swiftspeak://swiftlink-toggle")!) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(entry.isActive ? Color.green : Color.orange)
                            .frame(width: 32, height: 32)

                        Image("SwiftSpeakLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("SwiftLink")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(entry.isActive ? "Active" : "Start")
                            .font(.system(size: 10))
                            .foregroundStyle(entry.isActive ? .green : .secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.15))
                )
            }

            // Bottom row: Meeting + Power buttons
            HStack(spacing: 8) {
                Link(destination: URL(string: "swiftspeak://meeting")!) {
                    SmallWidgetButton(
                        icon: "mic.badge.plus",
                        label: "Meeting",
                        color: .blue
                    )
                }

                Link(destination: URL(string: "swiftspeak://powermode-picker")!) {
                    SmallWidgetButton(
                        icon: "bolt.fill",
                        label: "Power",
                        color: .purple
                    )
                }
            }
        }
        .padding(10)
        .containerBackground(.clear, for: .widget)
    }
}

// Compact button for small widget
struct SmallWidgetButton: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.15))
        )
    }
}

// Home Screen Medium Widget - 3 action buttons
struct SwiftLinkMediumView: View {
    let entry: SwiftLinkWidgetEntry

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                // SwiftLink Button
                Link(destination: URL(string: "swiftspeak://swiftlink-toggle")!) {
                    WidgetActionButton(
                        icon: "waveform.circle.fill",
                        customIcon: "SwiftSpeakLogo",
                        title: "SwiftLink",
                        subtitle: entry.isActive ? "Active" : "Start",
                        accentColor: entry.isActive ? .green : .orange,
                        isActive: entry.isActive
                    )
                }

                // Meeting Button
                Link(destination: URL(string: "swiftspeak://meeting")!) {
                    WidgetActionButton(
                        icon: "mic.badge.plus",
                        customIcon: nil,
                        title: "Meeting",
                        subtitle: "Record",
                        accentColor: .blue,
                        isActive: false
                    )
                }

                // Power Mode Button
                Link(destination: URL(string: "swiftspeak://powermode-picker")!) {
                    WidgetActionButton(
                        icon: "bolt.fill",
                        customIcon: nil,
                        title: "Power",
                        subtitle: "Modes",
                        accentColor: .purple,
                        isActive: false
                    )
                }
            }
            .padding(12)
        }
        .containerBackground(.clear, for: .widget)
    }
}

// Reusable action button for medium widget
struct WidgetActionButton: View {
    let icon: String
    let customIcon: String?
    let title: String
    let subtitle: String
    let accentColor: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isActive ? 0.3 : 0.2))
                    .frame(width: 48, height: 48)

                if let customIcon = customIcon {
                    Image(customIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .foregroundStyle(accentColor)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(isActive ? accentColor : .secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.15))
        )
    }
}

// MARK: - Widget Configuration

struct SwiftLinkWidget: Widget {
    let kind: String = "SwiftLinkWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SwiftLinkTimelineProvider()) { entry in
            SwiftLinkWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SwiftSpeak")
        .description("Quick access to SwiftLink, Meeting recording, and Power Modes")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .systemSmall,
            .systemMedium
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
        case .systemMedium:
            SwiftLinkMediumView(entry: entry)
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

#Preview("Medium - Active", as: .systemMedium) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.active
}

#Preview("Medium - Inactive", as: .systemMedium) {
    SwiftLinkWidget()
} timeline: {
    SwiftLinkWidgetEntry.inactive
}
