//
//  KeyboardSettingsView.swift
//  SwiftSpeak
//
//  Keyboard settings subpage - layout, programmable buttons, and appearance options
//  Phase 16: Dynamic keyboard height and customization
//

import SwiftUI

struct KeyboardSettingsView: View {
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
                // Layout Section
                layoutSection

                // Programmable Buttons Section
                programmableButtonsSection

                // Tips Section
                tipsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Keyboard")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Reload keyboard settings from App Groups to pick up changes from keyboard extension
            settings.reloadKeyboardSettings()
        }
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        Section {
            Toggle(isOn: $settings.keyboardShowSwiftSpeakBar) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SwiftSpeak Bar")
                        .font(.callout)
                    Text("Top bar with translation, context, and voice controls")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)

            Toggle(isOn: $settings.keyboardShowPredictionRow) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prediction Row")
                        .font(.callout)
                    Text("Word predictions, settings, and quick action button")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)
        } header: {
            Text("Layout")
        } footer: {
            Text("Hiding bars makes the keyboard more compact. Access settings via the gear icon in the prediction row or by long-pressing the globe key.")
        }
    }

    // MARK: - Programmable Buttons Section

    private var programmableButtonsSection: some View {
        Section {
            // Quick Action Button (in prediction row)
            Picker(selection: $settings.keyboardProgrammableAction) {
                ForEach(ProgrammableButtonAction.allCases) { action in
                    Label {
                        Text(action.displayName)
                    } icon: {
                        Image(systemName: action.iconName)
                            .foregroundStyle(action.iconColor)
                    }
                    .tag(action)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Action Button")
                        .font(.callout)
                    Text("Rightmost button in prediction row")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(rowBackground)

            Toggle(isOn: $settings.keyboardShowProgrammableNextToReturn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Button Next to Return")
                        .font(.callout)
                    Text("Add an extra quick action button beside the return key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .listRowBackground(rowBackground)

            if settings.keyboardShowProgrammableNextToReturn {
                Picker(selection: $settings.keyboardReturnProgrammableAction) {
                    ForEach(ProgrammableButtonAction.allCases) { action in
                        Label {
                            Text(action.displayName)
                        } icon: {
                            Image(systemName: action.iconName)
                                .foregroundStyle(action.iconColor)
                        }
                        .tag(action)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Return Button Action")
                            .font(.callout)
                        Text("Action for button next to return key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(rowBackground)
            }
        } header: {
            Text("Programmable Buttons")
        } footer: {
            Text("Assign quick actions to buttons for faster access to SwiftSpeak features.")
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                tipRow(
                    icon: "hand.tap.fill",
                    title: "Tap",
                    description: "Tap the microphone to start voice transcription"
                )

                tipRow(
                    icon: "hand.tap.fill",
                    title: "Long Press",
                    description: "Long press the microphone to toggle Edit Mode"
                )

                tipRow(
                    icon: "globe",
                    title: "Globe Key",
                    description: "Tap to switch keyboards, long press for quick settings"
                )

                tipRow(
                    icon: "arrow.left.arrow.right",
                    title: "Swipe",
                    description: "Swipe left/right to switch between voice and typing modes"
                )
            }
            .listRowBackground(rowBackground)
        } header: {
            Text("Tips")
        }
    }

    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Icon Color Extension

private extension ProgrammableButtonAction {
    var iconColor: Color {
        switch self {
        case .aiSparkles: return .purple
        case .transcribe: return AppTheme.accent
        case .translate: return .green
        case .aiFormat: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardSettingsView()
            .environmentObject(SharedSettings.shared)
    }
}
