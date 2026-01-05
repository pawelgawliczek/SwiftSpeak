//
//  MacPowerModeOverlayView.swift
//  SwiftSpeakMac
//
//  Floating overlay panel for Power Mode execution with 6 states
//  Phase 5: Context preview → Recording → Processing → Question → Result → Complete
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Main Overlay View

struct MacPowerModeOverlayView: View {
    @ObservedObject var viewModel: MacPowerModeOverlayViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content (changes based on state)
            contentView
                .frame(minHeight: 200, maxHeight: 500)
                .animation(.easeInOut(duration: 0.3), value: viewModel.state)

            // Error banner (if any)
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            // DEBUG: Show captured context info
            if !viewModel.debugInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.debugInfo)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.8))
            }

            Divider()

            // Footer (actions)
            footerView
        }
        .frame(width: 500)
        .background(overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .task {
            await viewModel.loadContext()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Power Mode selector with icon and name
            if viewModel.state == .contextPreview && viewModel.availablePowerModes.count > 1 {
                HStack(spacing: 8) {
                    Button(action: { viewModel.cycleToPreviousPowerMode() }) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.leftArrow, modifiers: [])

                    // Icon + Name
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(viewModel.currentPowerMode.iconColor.color.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: viewModel.currentPowerMode.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(viewModel.currentPowerMode.iconColor.color)
                        }

                        Text(viewModel.currentPowerMode.name)
                            .font(.headline)
                    }

                    Button(action: { viewModel.cycleToNextPowerMode() }) {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
            } else {
                // Static icon + name (no cycling)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(viewModel.currentPowerMode.iconColor.color.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: viewModel.currentPowerMode.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(viewModel.currentPowerMode.iconColor.color)
                    }

                    Text(viewModel.currentPowerMode.name)
                        .font(.headline)
                }
            }

            Spacer()

            // State indicator
            Text(stateDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .contextPreview:
            contextPreviewView
        case .recording:
            recordingView
        case .processing:
            processingView
        case .aiQuestion:
            questionView
        case .result:
            resultView
        case .actionComplete:
            completeView
        }
    }

    // MARK: - Context Preview View

    private var contextPreviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // INPUT SECTION
                inputSection

                Divider()
                    .padding(.horizontal, 16)

                // OUTPUT SECTION
                outputSection

                Divider()
                    .padding(.horizontal, 16)

                // Input method selection
                Text("Start")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button(action: { Task { await viewModel.startRecording() } }) {
                        Label("Voice Input", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { /* Type input not implemented yet */ }) {
                        Label("Type", systemImage: "keyboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Input")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

            // Show ALL configured sources (with status indicator)
            VStack(spacing: 4) {
                let inputConfig = viewModel.currentPowerMode.inputConfig

                // Selected Text
                if inputConfig.includeSelectedText {
                    let text = viewModel.windowContext?.selectedText
                    compactInputRow(
                        icon: "text.cursor",
                        iconColor: .orange,
                        title: "Selected Text",
                        content: text,
                        emptyMessage: "No text selected"
                    )
                }

                // Active App Text
                if inputConfig.includeActiveAppText {
                    let text = viewModel.windowContext?.visibleText
                    compactInputRow(
                        icon: "macwindow",
                        iconColor: .cyan,
                        title: "Window Text",
                        content: text,
                        emptyMessage: "No window text"
                    )
                }

                // Clipboard
                if inputConfig.includeClipboard {
                    compactInputRow(
                        icon: "doc.on.clipboard",
                        iconColor: .indigo,
                        title: "Clipboard",
                        content: viewModel.clipboardContent.isEmpty ? nil : viewModel.clipboardContent,
                        emptyMessage: "Empty"
                    )
                }

                // Memory (Global + PowerMode)
                if inputConfig.includeGlobalMemory || inputConfig.includePowerModeMemory {
                    compactInputRow(
                        icon: "brain",
                        iconColor: .purple,
                        title: "Memory",
                        content: viewModel.memoryContext.isEmpty ? nil : viewModel.memoryContext,
                        emptyMessage: "No memory"
                    )
                }

                // Obsidian
                if inputConfig.includeObsidianVaults && !viewModel.currentPowerMode.obsidianVaultIds.isEmpty {
                    compactObsidianRow()
                }

                // No sources configured
                if !hasAnyConfiguredSource {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("No input sources configured")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var hasAnyConfiguredSource: Bool {
        let cfg = viewModel.currentPowerMode.inputConfig
        return cfg.includeSelectedText || cfg.includeActiveAppText || cfg.includeClipboard ||
               cfg.includeGlobalMemory || cfg.includePowerModeMemory ||
               (cfg.includeObsidianVaults && !viewModel.currentPowerMode.obsidianVaultIds.isEmpty)
    }

    private func compactInputRow(icon: String, iconColor: Color, title: String, content: String?, emptyMessage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(content != nil ? iconColor : .secondary)
                .frame(width: 16)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(content != nil ? .primary : .secondary)

            if let content = content, !content.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(content.replacingOccurrences(of: "\n", with: " ").prefix(80) + (content.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Spacer()

            Image(systemName: content != nil ? "checkmark.circle.fill" : "circle.dashed")
                .font(.caption2)
                .foregroundStyle(content != nil ? .green : .secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func compactObsidianRow() -> some View {
        let hasResults = !viewModel.obsidianResults.isEmpty
        return HStack(spacing: 8) {
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .opacity(hasResults ? 1.0 : 0.5)

            Text("Obsidian")
                .font(.caption.weight(.medium))
                .foregroundStyle(hasResults ? .primary : .secondary)

            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if hasResults {
                Text("\(viewModel.obsidianResults.count) notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No matching notes")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Spacer()

            Image(systemName: hasResults ? "checkmark.circle.fill" : "circle.dashed")
                .font(.caption2)
                .foregroundStyle(hasResults ? .green : .secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Output")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

            VStack(spacing: 4) {
                let outputConfig = viewModel.currentPowerMode.outputConfig

                // Primary action
                compactOutputRow(
                    icon: outputConfig.primaryAction.icon,
                    iconColor: .orange,
                    title: outputConfig.primaryAction.displayName
                )

                // Auto-send
                if outputConfig.autoSendAfterInsert {
                    compactOutputRow(
                        icon: "paperplane.fill",
                        iconColor: .blue,
                        title: "Auto-Send (press Enter)"
                    )
                }

                // Obsidian save
                if let obsidianAction = outputConfig.obsidianAction,
                   obsidianAction.action != .none {
                    compactObsidianOutputRow(action: obsidianAction)
                }

                // Webhooks
                if outputConfig.webhookEnabled && !outputConfig.webhookIds.isEmpty {
                    compactOutputRow(
                        icon: "link",
                        iconColor: .green,
                        title: "\(outputConfig.webhookIds.count) Webhook(s)"
                    )
                }
            }
        }
    }

    private func compactOutputRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func compactObsidianOutputRow(action: ObsidianActionConfig) -> some View {
        HStack(spacing: 8) {
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)

            Text("Obsidian: \(action.action.displayName)")
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Recording indicator
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)

                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
            }

            Text("Recording...")
                .font(.title3.weight(.medium))

            // Duration
            Text(formattedDuration(viewModel.recordingDuration))
                .font(.system(.title, design: .monospaced).weight(.semibold))

            // Audio level indicator
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.audioLevel > Float(index) / 12.0 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 4, height: CGFloat(20 + index * 2))
                }
            }
            .frame(height: 40)

            Spacer()

            // Stop button
            Button(action: { Task { await viewModel.stopRecording() } }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop & Process")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)

            Button("Cancel", action: viewModel.cancelRecording)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Brain icon with animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(viewModel.state == .processing ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: viewModel.state)
            }

            Text("Processing...")
                .font(.title3.weight(.medium))

            Text("Analyzing context and generating response")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI question
            if let question = viewModel.aiQuestion {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI has a question:", systemImage: "questionmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text(question)
                        .font(.body)
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
            }

            // Answer input
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Answer:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Type your answer...", text: $viewModel.questionAnswer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Submit button
            Button(action: { Task { await viewModel.answerQuestion(viewModel.questionAnswer) } }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Submit Answer")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.questionAnswer.isEmpty)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 16) {
            // AI response
            ScrollView {
                Text(viewModel.aiResponse)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
            }
            .frame(maxHeight: 300)

            // Refine input (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Refine (optional):")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Add refinements...", text: $viewModel.userInput)
                        .textFieldStyle(.roundedBorder)

                    Button(action: { Task { await viewModel.refineResult(viewModel.userInput) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.userInput.isEmpty)
                }
            }
            .padding(.horizontal, 16)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: viewModel.copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: { Task { await viewModel.insertAtCursor() } }) {
                    Label("Insert", systemImage: "arrow.up.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // Obsidian save button
                obsidianSaveButton
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }

            Text("Complete!")
                .font(.title3.weight(.medium))

            Text("Action completed successfully")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 16)
        .onAppear {
            // Auto-close after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onClose()
            }
        }
    }

    // MARK: - Context Source Card

    /// Read-only context source display (configured in Power Mode editor)
    private func contextSourceDisplay(
        icon: String,
        title: String,
        description: String,
        isEnabled: Bool,
        hasContent: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isEnabled && hasContent ? .orange : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isEnabled {
                Image(systemName: hasContent ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(hasContent ? .orange : .secondary.opacity(0.5))
            } else {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isEnabled && hasContent ? Color.orange.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    /// Obsidian-specific context source display using custom icon
    private func obsidianContextSourceDisplay(
        title: String,
        description: String,
        isEnabled: Bool,
        hasContent: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .opacity(isEnabled && hasContent ? 1.0 : 0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isEnabled {
                Image(systemName: hasContent ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(hasContent ? .purple : .secondary.opacity(0.5))
            } else {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isEnabled && hasContent ? Color.purple.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    /// Legacy interactive context source card (kept for compatibility)
    private func contextSourceCard(
        icon: String,
        title: String,
        description: String,
        isEnabled: Binding<Bool>,
        hasContent: Bool
    ) -> some View {
        Button(action: { isEnabled.wrappedValue.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isEnabled.wrappedValue ? .orange : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isEnabled.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isEnabled.wrappedValue ? .orange : .secondary.opacity(0.3))
            }
            .padding(12)
            .background(isEnabled.wrappedValue ? Color.orange.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled.wrappedValue ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .disabled(!hasContent)
        .opacity(hasContent ? 1.0 : 0.5)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Keyboard hints
            if viewModel.state == .contextPreview {
                HStack(spacing: 12) {
                    keyboardHint(key: "↑↓ / ←→", action: "Switch Mode")
                    keyboardHint(key: "↩︎", action: "Start")
                    keyboardHint(key: "Esc", action: "Cancel")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if viewModel.state == .recording {
                HStack(spacing: 12) {
                    keyboardHint(key: "Space", action: "Stop")
                    keyboardHint(key: "Esc", action: "Cancel")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // State-specific actions
            if viewModel.state == .contextPreview {
                Button("Close", action: onClose)
                    .keyboardShortcut(.escape)
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func keyboardHint(key: String, action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(action)
        }
    }

    private var stateDescription: String {
        switch viewModel.state {
        case .contextPreview:
            return "Configure context and input"
        case .recording:
            return "Recording your voice..."
        case .processing:
            return "AI is thinking..."
        case .aiQuestion:
            return "Needs clarification"
        case .result:
            return "Review and refine"
        case .actionComplete:
            return "Complete!"
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Obsidian Save Button

    @ViewBuilder
    private var obsidianSaveButton: some View {
        if let actionConfig = viewModel.currentPowerMode.obsidianAction,
           actionConfig.action != .none,
           let vault = viewModel.settings.obsidianVaults.first(where: { $0.id == actionConfig.targetVaultId }) {
            // Configured action - show destination
            Menu {
                // Show configured action
                Button(action: { Task { await viewModel.saveToObsidian() } }) {
                    Label(saveButtonLabel(action: actionConfig.action, vault: vault),
                          systemImage: actionConfig.action.icon)
                }

                Divider()

                // Quick actions to other vaults
                ForEach(viewModel.settings.obsidianVaults.filter { $0.id != vault.id }) { otherVault in
                    Menu(otherVault.name) {
                        Button("Append to Daily Note") {
                            Task { await viewModel.saveToObsidian(vault: otherVault, action: .appendToDaily) }
                        }
                        Button("Create New Note") {
                            Task { await viewModel.saveToObsidian(vault: otherVault, action: .create) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image("ObsidianIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(shortSaveLabel(action: actionConfig.action))
                }
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)
        } else if !viewModel.settings.obsidianVaults.isEmpty {
            // No configured action but vaults exist - show menu
            Menu {
                ForEach(viewModel.settings.obsidianVaults) { vault in
                    Menu(vault.name) {
                        Button("Append to Daily Note") {
                            Task { await viewModel.saveToObsidian(vault: vault, action: .appendToDaily) }
                        }
                        Button("Create New Note") {
                            Task { await viewModel.saveToObsidian(vault: vault, action: .create) }
                        }
                    }
                }
            } label: {
                Label("Save", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)
        } else {
            // No vaults - disabled button
            Button(action: {}) {
                Label("Save", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(true)
            .help("Add an Obsidian vault in Settings to enable saving")
        }
    }

    private func saveButtonLabel(action: ObsidianAction, vault: ObsidianVault) -> String {
        switch action {
        case .appendToDaily:
            return "Add to Daily Note (\(vault.name))"
        case .appendToNote:
            return "Append to Note (\(vault.name))"
        case .createNote:
            return "Create Note (\(vault.name))"
        case .none:
            return "Save"
        }
    }

    private func shortSaveLabel(action: ObsidianAction) -> String {
        switch action {
        case .appendToDaily:
            return "Daily"
        case .appendToNote:
            return "Append"
        case .createNote:
            return "New"
        case .none:
            return "Save"
        }
    }

    private var overlayBackground: some View {
        Color(NSColor.windowBackgroundColor)
    }
}

// MARK: - Preview

#Preview("Context Preview") {
    let settings = MacSettings.shared
    let viewModel = MacPowerModeOverlayViewModel(
        powerMode: PowerMode.presets[0],
        allPowerModes: PowerMode.presets,
        settings: settings,
        windowContextService: MacWindowContextService(),
        audioRecorder: MacAudioRecorder()
    )

    return MacPowerModeOverlayView(
        viewModel: viewModel,
        onClose: {}
    )
}

#Preview("Recording") {
    let settings = MacSettings.shared
    let viewModel = MacPowerModeOverlayViewModel(
        powerMode: PowerMode.presets[0],
        allPowerModes: PowerMode.presets,
        settings: settings,
        windowContextService: MacWindowContextService(),
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .recording

    return MacPowerModeOverlayView(
        viewModel: viewModel,
        onClose: {}
    )
}

#Preview("Result") {
    let settings = MacSettings.shared
    let viewModel = MacPowerModeOverlayViewModel(
        powerMode: PowerMode.presets[0],
        allPowerModes: PowerMode.presets,
        settings: settings,
        windowContextService: MacWindowContextService(),
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .result
    viewModel.aiResponse = "Here's the meeting summary:\n\n1. Discussed Q4 goals\n2. Reviewed budget\n3. Next meeting: Friday"

    return MacPowerModeOverlayView(
        viewModel: viewModel,
        onClose: {}
    )
}
