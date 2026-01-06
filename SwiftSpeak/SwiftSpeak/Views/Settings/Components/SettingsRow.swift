//
//  SettingsRow.swift
//  SwiftSpeak
//
//  Generic settings row component
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

#Preview("Settings Row") {
    List {
        SettingsRow(
            icon: "gear",
            iconColor: .blue,
            title: "Settings",
            subtitle: "Configure your preferences"
        )

        SettingsRow(
            icon: "lock.shield",
            iconColor: .green,
            title: "Security",
            subtitle: nil
        )
    }
}
