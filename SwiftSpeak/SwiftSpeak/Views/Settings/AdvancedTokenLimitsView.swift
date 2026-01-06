//
//  AdvancedTokenLimitsView.swift
//  SwiftSpeak
//
//  Phase 11: Configure token limits for AI context
//

import SwiftUI
import SwiftSpeakCore

struct AdvancedTokenLimitsView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("What are tokens?")
                                .font(.callout.weight(.semibold))
                        }

                        Text("Tokens are chunks of text that AI models process. Roughly 4 characters = 1 token for English, or 2 characters for CJK languages (Chinese, Japanese, Korean).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Lower limits = faster responses & lower costs\nHigher limits = more context for better results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(rowBackground)
                }

                // Global Memory Section
                Section {
                    TokenLimitRow(
                        title: "Global Memory",
                        description: "AI's long-term memory that persists across all transcriptions. Contains user preferences, writing style, and frequently used information.",
                        value: $settings.tokenLimitGlobalMemory,
                        range: 100...2000,
                        defaultValue: 500
                    )
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Memory Limits")
                } footer: {
                    Text("Recommended: 500 tokens. Higher values let AI remember more but increase costs.")
                }

                // Context Memory Section
                Section {
                    TokenLimitRow(
                        title: "Context Memory",
                        description: "Memory specific to each conversation context (Work, Personal, etc). Contains context-specific preferences and history.",
                        value: $settings.tokenLimitContextMemory,
                        range: 100...1500,
                        defaultValue: 400
                    )
                    .listRowBackground(rowBackground)
                } footer: {
                    Text("Recommended: 400 tokens. Each context maintains its own memory separately.")
                }

                // RAG Section
                Section {
                    TokenLimitRow(
                        title: "Knowledge Documents",
                        description: "Content from uploaded documents in Power Mode (PDFs, text files). This is the RAG (Retrieval-Augmented Generation) context.",
                        value: $settings.tokenLimitRAGChunks,
                        range: 500...8000,
                        defaultValue: 2000
                    )
                    .listRowBackground(rowBackground)
                } footer: {
                    Text("Recommended: 2000 tokens. Higher values include more document content for reference.")
                }

                // User Input Section
                Section {
                    TokenLimitRow(
                        title: "User Input",
                        description: "Maximum length of your transcribed text. Very long transcriptions will be truncated to fit this limit.",
                        value: $settings.tokenLimitUserInput,
                        range: 1000...16000,
                        defaultValue: 4000
                    )
                    .listRowBackground(rowBackground)
                } footer: {
                    Text("Recommended: 4000 tokens (~15,000 characters). Increase for very long dictations.")
                }

                // Total Budget Info
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Estimated Max Context")
                                .font(.callout)
                            Spacer()
                            Text("\(estimatedTotalTokens) tokens")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: Double(estimatedTotalTokens), total: 8000)
                            .tint(estimatedTotalTokens > 8000 ? .orange : AppTheme.accent)

                        if estimatedTotalTokens > 8000 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("High token usage may exceed some model limits")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Total Usage")
                } footer: {
                    Text("Most models support 4K-128K context windows. Keep total under 8K for compatibility with smaller models.")
                }

                // Reset Section
                Section {
                    Button(action: resetToDefaults) {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                    .listRowBackground(rowBackground)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Token Limits")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var estimatedTotalTokens: Int {
        settings.tokenLimitGlobalMemory +
        settings.tokenLimitContextMemory +
        settings.tokenLimitRAGChunks +
        settings.tokenLimitUserInput
    }

    private func resetToDefaults() {
        HapticManager.mediumTap()
        withAnimation {
            settings.tokenLimitGlobalMemory = 500
            settings.tokenLimitContextMemory = 400
            settings.tokenLimitRAGChunks = 2000
            settings.tokenLimitUserInput = 4000
        }
    }
}

// MARK: - Token Limit Row

struct TokenLimitRow: View {
    let title: String
    let description: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let defaultValue: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with disclosure
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("\(value) tokens")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Slider
                    HStack {
                        Text("\(range.lowerBound)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Slider(
                            value: Binding(
                                get: { Double(value) },
                                set: { value = Int($0) }
                            ),
                            in: Double(range.lowerBound)...Double(range.upperBound),
                            step: 100
                        )
                        .tint(AppTheme.accent)

                        Text("\(range.upperBound)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button(action: {
                                HapticManager.lightTap()
                                withAnimation { value = preset }
                            }) {
                                Text("\(preset)")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(value == preset ? AppTheme.accent : Color.gray.opacity(0.2))
                                    .foregroundStyle(value == preset ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if value != defaultValue {
                            Button("Default") {
                                HapticManager.lightTap()
                                withAnimation { value = defaultValue }
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    private var presets: [Int] {
        // Generate 3 sensible presets based on range
        let step = (range.upperBound - range.lowerBound) / 4
        return [
            range.lowerBound + step,
            defaultValue,
            range.upperBound - step
        ].sorted()
    }
}

#Preview {
    NavigationStack {
        AdvancedTokenLimitsView()
            .environmentObject(SharedSettings.shared)
    }
}
