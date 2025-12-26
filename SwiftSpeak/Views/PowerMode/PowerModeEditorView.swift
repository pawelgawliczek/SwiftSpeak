//
//  PowerModeEditorView.swift
//  SwiftSpeak
//
//  Create or edit a Power Mode with all configuration options
//

import SwiftUI

struct PowerModeEditorView: View {
    let powerMode: PowerMode?
    let onSave: (PowerMode) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var icon: String = "bolt.fill"
    @State private var iconColor: PowerModeColorPreset = .orange
    @State private var iconBackgroundColor: PowerModeColorPreset = .orange
    @State private var instruction: String = ""
    @State private var outputFormat: String = ""
    @State private var enabledCapabilities: Set<PowerModeCapability> = []

    // UI state
    @State private var showingIconPicker = false

    // Mock selected provider for capability filtering
    @State private var selectedProvider: LLMProvider = .openAI

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !instruction.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(powerMode: PowerMode?, onSave: @escaping (PowerMode) -> Void) {
        self.powerMode = powerMode
        self.onSave = onSave

        // Initialize state from powerMode if editing
        if let mode = powerMode {
            _name = State(initialValue: mode.name)
            _icon = State(initialValue: mode.icon)
            _iconColor = State(initialValue: mode.iconColor)
            _iconBackgroundColor = State(initialValue: mode.iconBackgroundColor)
            _instruction = State(initialValue: mode.instruction)
            _outputFormat = State(initialValue: mode.outputFormat)
            _enabledCapabilities = State(initialValue: mode.enabledCapabilities)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and name section
                    iconAndNameSection

                    // Instruction section
                    instructionSection

                    // Output format section
                    outputFormatSection

                    // Capabilities section
                    capabilitiesSection
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle(powerMode == nil ? "New Power Mode" : "Edit Power Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(
                    selectedIcon: $icon,
                    iconColor: $iconColor,
                    iconBackgroundColor: $iconBackgroundColor
                )
            }
        }
    }

    // MARK: - Icon and Name Section

    private var iconAndNameSection: some View {
        VStack(spacing: 20) {
            // Icon button
            Button(action: {
                HapticManager.selection()
                showingIconPicker = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(iconColor.gradient)
                        .frame(width: 80, height: 80)
                        .background(iconBackgroundColor.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                    Text("Tap to change icon & colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Name field
            TextField("Mode Name", text: $name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Instruction Section

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSTRUCTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $instruction)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("What the AI should do with your voice input")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Output Format Section

    private var outputFormatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUTPUT FORMAT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $outputFormat)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("How to format the response (markdown)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Capabilities Section

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CAPABILITIES (PROVIDER-EXECUTED)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(PowerModeCapability.allCases, id: \.self) { capability in
                    CapabilityToggleRow(
                        capability: capability,
                        isEnabled: enabledCapabilities.contains(capability),
                        isSupported: capability.isSupported(by: selectedProvider),
                        onToggle: {
                            HapticManager.selection()
                            if enabledCapabilities.contains(capability) {
                                enabledCapabilities.remove(capability)
                            } else {
                                enabledCapabilities.insert(capability)
                            }
                        }
                    )

                    if capability != PowerModeCapability.allCases.last {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        let savedMode = PowerMode(
            id: powerMode?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            iconColor: iconColor,
            iconBackgroundColor: iconBackgroundColor,
            instruction: instruction.trimmingCharacters(in: .whitespaces),
            outputFormat: outputFormat.trimmingCharacters(in: .whitespaces),
            enabledCapabilities: enabledCapabilities,
            createdAt: powerMode?.createdAt ?? Date(),
            updatedAt: Date(),
            usageCount: powerMode?.usageCount ?? 0
        )
        HapticManager.success()
        onSave(savedMode)
        dismiss()
    }
}

// MARK: - Color Picker Row

struct ColorPickerRow: View {
    let label: String
    @Binding var selectedColor: PowerModeColorPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PowerModeColorPreset.allCases) { colorPreset in
                        Button(action: {
                            HapticManager.selection()
                            selectedColor = colorPreset
                        }) {
                            Circle()
                                .fill(colorPreset.gradient)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == colorPreset ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == colorPreset ? colorPreset.color : Color.clear, lineWidth: 4)
                                        .scaleEffect(1.25)
                                )
                                .scaleEffect(selectedColor == colorPreset ? 1.1 : 1.0)
                                .animation(AppTheme.quickSpring, value: selectedColor)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Capability Toggle Row

struct CapabilityToggleRow: View {
    let capability: PowerModeCapability
    let isEnabled: Bool
    let isSupported: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: {
            if isSupported {
                onToggle()
            }
        }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: capability.icon)
                    .font(.body)
                    .foregroundStyle(isSupported ? (isEnabled ? AppTheme.powerAccent : .primary) : .secondary.opacity(0.5))
                    .frame(width: 32)

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(capability.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isSupported ? Color.primary : Color.secondary.opacity(0.5))

                    Text(capability.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Provider support indicator
                    HStack(spacing: 4) {
                        ForEach(capability.supportedProviders, id: \.self) { provider in
                            Text(provider.shortName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                // Toggle indicator
                if isSupported {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isEnabled ? AppTheme.powerAccent : .secondary.opacity(0.3))
                } else {
                    Text("N/A")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isSupported)
    }
}

// MARK: - Preview

#Preview("New Mode") {
    PowerModeEditorView(powerMode: nil) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Edit Mode") {
    PowerModeEditorView(powerMode: PowerMode.presets.first!) { _ in }
        .preferredColorScheme(.dark)
}
