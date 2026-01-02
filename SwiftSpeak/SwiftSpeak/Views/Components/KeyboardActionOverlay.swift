//
//  KeyboardActionOverlay.swift
//  SwiftSpeak
//
//  Unified overlay view for all keyboard actions.
//  Displays status, progress, and results for transcription,
//  edit, AI processing, prediction, and SwiftLink operations.
//

import SwiftUI

struct KeyboardActionOverlay: View {
    @ObservedObject var handler: KeyboardActionHandler
    @Environment(\.colorScheme) var colorScheme

    @State private var pulseAnimation = false
    @State private var showCancelButton = false

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.95)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on tap during processing
                }

            // Content card
            VStack(spacing: 24) {
                // Icon
                actionIcon
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )

                // Status text
                VStack(spacing: 8) {
                    Text(handler.statusMessage)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    if let action = handler.currentAction {
                        actionSubtitle(for: action)
                    }
                }

                // Streaming transcript (for transcription)
                if handler.status == .recording || handler.status == .streaming,
                   !handler.streamingTranscript.isEmpty {
                    streamingTranscriptView
                }

                // Error message
                if let error = handler.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Cancel button (appears after delay)
                if showCancelButton && handler.status.isActive {
                    Button(action: {
                        HapticManager.lightTap()
                        handler.cancelAction()
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(32)
            .frame(maxWidth: 320)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
        .onAppear {
            pulseAnimation = true

            // Show cancel button after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showCancelButton = true
                }
            }
        }
        .onDisappear {
            pulseAnimation = false
            showCancelButton = false
        }
    }

    // MARK: - Action Icon

    @ViewBuilder
    private var actionIcon: some View {
        let action = handler.currentAction

        ZStack {
            // Background circle
            Circle()
                .fill(iconBackgroundColor.gradient)
                .frame(width: 80, height: 80)

            // Icon or indicator
            Group {
                switch handler.status {
                case .recording:
                    // Recording indicator
                    Circle()
                        .fill(.red)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        )

                case .processing, .starting, .streaming:
                    // Processing spinner
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                case .complete:
                    // Success checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                case .error:
                    // Error icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)

                case .cancelled, .pending:
                    // Action type icon
                    Image(systemName: action?.type.icon ?? "sparkles")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var iconBackgroundColor: Color {
        switch handler.status {
        case .recording:
            return .red
        case .error:
            return .red
        case .complete:
            return .green
        case .cancelled:
            return .gray
        default:
            return actionTypeColor
        }
    }

    private var actionTypeColor: Color {
        guard let action = handler.currentAction else { return AppTheme.accent }

        switch action.type {
        case .transcription:
            return AppTheme.accent
        case .edit:
            return .green
        case .aiProcess:
            return AppTheme.powerAccent
        case .prediction:
            return .purple
        case .enableSwiftLink:
            return .orange
        }
    }

    // MARK: - Action Subtitle

    @ViewBuilder
    private func actionSubtitle(for action: KeyboardAction) -> some View {
        Group {
            switch action.type {
            case .transcription:
                if let mode = action.formattingMode {
                    Label(mode.displayName, systemImage: mode.icon)
                }

            case .edit:
                if let original = action.originalText {
                    Text("Editing: \"\(original.prefix(30))...\"")
                        .lineLimit(1)
                }

            case .aiProcess:
                if let contextName = action.contextName {
                    Label(contextName, systemImage: "person.circle")
                } else if let powerModeName = action.powerModeName {
                    Label(powerModeName, systemImage: "bolt.fill")
                } else if action.translateEnabled {
                    Label(action.targetLanguage?.displayName ?? "Translation", systemImage: "globe")
                }

            case .prediction:
                if let contextName = action.activeContextName {
                    Label(contextName, systemImage: "person.circle")
                } else {
                    Label("AI Prediction", systemImage: "sparkles")
                }

            case .enableSwiftLink:
                if let appName = action.sourceAppName {
                    Label(appName, systemImage: "link")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Streaming Transcript View

    private var streamingTranscriptView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live transcript:")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            ScrollView {
                Text(handler.streamingTranscript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 80)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Processing") {
    let handler = KeyboardActionHandler.shared
    return KeyboardActionOverlay(handler: handler)
}
