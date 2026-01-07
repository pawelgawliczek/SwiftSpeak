//
//  MacKeyboardSettingsView.swift
//  SwiftSpeakMac
//
//  Keyboard settings for iOS keyboard configuration from macOS
//  Settings sync via iCloud to iOS devices
//  Phase 16: Dynamic keyboard height and customization
//

import SwiftUI

struct MacKeyboardSettingsView: View {
    @ObservedObject var settings: MacSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("iOS Keyboard Settings")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    Text("Configure your SwiftSpeak iOS keyboard from your Mac. Changes sync via iCloud.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                // Layout Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Layout")
                            .font(.headline)

                        Toggle(isOn: $settings.keyboardShowSwiftSpeakBar) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SwiftSpeak Bar")
                                    .font(.body)
                                Text("Top bar with translation, context, and voice controls")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Toggle(isOn: $settings.keyboardShowPredictionRow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Prediction Row")
                                    .font(.body)
                                Text("Word predictions, settings, and quick action button")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        Text("Hiding bars makes the keyboard more compact on iOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                // Programmable Buttons Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Programmable Buttons")
                            .font(.headline)

                        // Quick Action Button
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Action Button")
                                .font(.body)
                            Text("Rightmost button in prediction row")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("", selection: $settings.keyboardProgrammableAction) {
                                ForEach(MacProgrammableButtonAction.allCases) { action in
                                    Label(action.displayName, systemImage: action.iconName)
                                        .tag(action)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        .padding(.top, 4)

                        Divider()

                        Toggle(isOn: $settings.keyboardShowProgrammableNextToReturn) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Button Next to Return")
                                    .font(.body)
                                Text("Add an extra quick action button beside the return key")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)

                        if settings.keyboardShowProgrammableNextToReturn {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Return Button Action")
                                    .font(.body)

                                Picker("", selection: $settings.keyboardReturnProgrammableAction) {
                                    ForEach(MacProgrammableButtonAction.allCases) { action in
                                        Label(action.displayName, systemImage: action.iconName)
                                            .tag(action)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Tips Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("iOS Keyboard Tips")
                            .font(.headline)

                        tipRow(icon: "hand.tap.fill", title: "Tap", description: "Tap the microphone to start voice transcription")
                        tipRow(icon: "hand.tap.fill", title: "Long Press", description: "Long press the microphone to toggle Edit Mode")
                        tipRow(icon: "globe", title: "Globe Key", description: "Tap to switch keyboards, long press for quick settings")
                        tipRow(icon: "arrow.left.arrow.right", title: "Swipe", description: "Swipe left/right to switch between voice and typing modes")
                    }
                    .padding(.vertical, 4)
                }

                // Sync Info
                HStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .foregroundStyle(.secondary)
                    Text("Settings sync automatically to your iOS devices via iCloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    MacKeyboardSettingsView(settings: MacSettings.shared)
}
