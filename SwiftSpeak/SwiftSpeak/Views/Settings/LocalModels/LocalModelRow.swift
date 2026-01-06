//
//  LocalModelRow.swift
//  SwiftSpeak
//
//  Local model row component
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Local Model Row

struct LocalModelRow: View {
    let type: LocalModelType
    let status: LocalModelStatus
    let subtitle: String
    let colorScheme: ColorScheme
    let onTap: () -> Void

    private var statusColor: Color {
        switch status {
        case .ready: return .green
        case .downloading: return .blue
        case .notConfigured: return .secondary
        case .notAvailable: return .secondary
        case .error: return .orange
        }
    }

    var body: some View {
        Button(action: {
            HapticManager.lightTap()
            onTap()
        }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            status == .ready
                                ? LinearGradient(colors: [.green.opacity(0.2), .green.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.secondary.opacity(0.15)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundStyle(status == .ready ? .green : .secondary)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(type.displayName)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(status == .notAvailable ? .secondary : .primary)

                        if type.isOnDevice {
                            Text("ON-DEVICE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Status indicator
                if status == .downloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .font(.caption)
                            .foregroundStyle(statusColor)

                        if status != .notAvailable {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(status == .notAvailable)
    }
}
