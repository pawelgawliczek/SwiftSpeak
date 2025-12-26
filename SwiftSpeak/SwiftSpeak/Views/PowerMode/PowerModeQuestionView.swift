//
//  PowerModeQuestionView.swift
//  SwiftSpeak
//
//  Claude Code-style clarification question UI
//

import SwiftUI

struct PowerModeQuestionView: View {
    let question: PowerModeQuestion
    let onAnswer: (String) -> Void
    let onVoiceAnswer: () -> Void

    @State private var customAnswer = ""
    @FocusState private var isCustomAnswerFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Question icon
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)

            // Question header
            Text("I need more information")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            // Question text
            Text(question.questionText)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(16)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Options
            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    QuestionOptionButton(
                        option: option,
                        onSelect: {
                            HapticManager.mediumTap()
                            onAnswer(option.value)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)

            // Custom answer section
            if question.allowFreeform {
                VStack(spacing: 16) {
                    // Divider with OR
                    HStack {
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(height: 1)
                        Text("OR")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)

                    // Custom text input
                    HStack(spacing: 12) {
                        TextField("Type custom answer...", text: $customAnswer)
                            .textFieldStyle(.plain)
                            .focused($isCustomAnswerFocused)

                        Button(action: {
                            if !customAnswer.isEmpty {
                                HapticManager.mediumTap()
                                onAnswer(customAnswer)
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(customAnswer.isEmpty ? .secondary.opacity(0.3) : AppTheme.powerAccent)
                        }
                        .disabled(customAnswer.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        isCustomAnswerFocused = true
                    }

                    // Voice answer button
                    Button(action: {
                        HapticManager.mediumTap()
                        onVoiceAnswer()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .font(.body)
                            Text("Answer by Voice")
                                .font(.callout.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.powerGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
    }
}

// MARK: - Question Option Button

struct QuestionOptionButton: View {
    let option: PowerModeQuestionOption
    let onSelect: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon (use calendar as default for time-based options)
                Image(systemName: iconForOption())
                    .font(.body)
                    .foregroundStyle(AppTheme.powerAccent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if let description = option.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(AppTheme.quickSpring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func iconForOption() -> String {
        // Determine icon based on option title/value
        let title = option.title.lowercased()
        if title.contains("24 hours") || title.contains("today") {
            return "clock.fill"
        } else if title.contains("week") {
            return "calendar"
        } else if title.contains("month") {
            return "calendar.badge.clock"
        } else if title.contains("all time") || title.contains("ever") {
            return "infinity"
        } else {
            return "checkmark.circle.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()

        PowerModeQuestionView(
            question: PowerModeQuestion.sample,
            onAnswer: { _ in },
            onVoiceAnswer: {}
        )
    }
    .preferredColorScheme(.dark)
}
