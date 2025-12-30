//
//  KeyboardView.swift
//  SwiftSpeakKeyboard
//
//  SwiftUI keyboard interface
//
//  NOTE: This file uses shared types from Shared/ directory:
//  - FormattingMode, Language (from Models.swift)
//  - KeyboardTheme, KeyboardHaptics (typealiases from Theme.swift)
//  - Constants (from Constants.swift)
//

import SwiftUI
import UIKit
import Combine

// MARK: - Status Banner (Phase 11)
struct StatusBanner: View {
    let status: KeyboardProcessingStatus
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Icon with animation for processing states
            if status.currentStep == "transcribing" || status.currentStep == "formatting" ||
               status.currentStep == "translating" || status.currentStep == "retrying" {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: status.color))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: status.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(status.color)
            }

            Text(status.displayText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            // Action buttons
            if status.currentStep == "failed" {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            } else if status.currentStep == "complete" {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(status.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Keyboard View
struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onNextKeyboard: () -> Void

    @State private var showPowerModePicker = false
    @State private var showContextPicker = false

    private var shouldShowStatusBanner: Bool {
        let step = viewModel.processingStatus.currentStep
        return step == "transcribing" || step == "formatting" ||
               step == "translating" || step == "retrying" ||
               step == "complete" || step == "failed"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Phase 11: Status Banner
            if shouldShowStatusBanner {
                StatusBanner(
                    status: viewModel.processingStatus,
                    onDismiss: {
                        KeyboardHaptics.lightTap()
                        viewModel.dismissError()
                    },
                    onRetry: {
                        KeyboardHaptics.mediumTap()
                        viewModel.startTranscription()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Provider indicator (if configured)
            if let provider = viewModel.transcriptionProvider, provider.isConfigured {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(provider.model ?? provider.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
            }

            // Main action buttons
            HStack(spacing: 8) {
                // Transcribe button
                ActionButton(
                    icon: viewModel.isProviderConfigured ? "mic.fill" : "exclamationmark.triangle.fill",
                    title: viewModel.isProviderConfigured ? "Transcribe" : "Setup Required",
                    gradient: viewModel.isProviderConfigured ? KeyboardTheme.accentGradient : LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                    isLocked: !viewModel.isProviderConfigured
                ) {
                    viewModel.startTranscription()
                }

                // Translate button
                ActionButton(
                    icon: "globe",
                    title: "Translate",
                    gradient: KeyboardTheme.proGradient,
                    isPro: true,
                    isLocked: !viewModel.isPro
                ) {
                    viewModel.startTranslation()
                }

                // Power button
                ActionButton(
                    icon: "bolt.fill",
                    title: "Power",
                    gradient: KeyboardTheme.powerGradient,
                    isPro: true,
                    isLocked: !viewModel.isPower
                ) {
                    showPowerModePicker = true
                }
            }
            .padding(.horizontal, 16)

            // Mode, Context, and Language selectors
            HStack(spacing: 8) {
                // Mode dropdown (includes custom templates for Pro)
                DropdownButton(
                    icon: viewModel.currentModeIcon,
                    title: viewModel.currentModeDisplayName,
                    options: viewModel.modeOptions
                ) { value in
                    viewModel.selectMode(value: value)
                }

                // Context button (Pro+ only)
                if viewModel.isPro {
                    ContextSelectorButton(
                        activeContext: viewModel.activeContext,
                        onTap: {
                            KeyboardHaptics.selection()
                            withAnimation(KeyboardTheme.quickSpring) {
                                showContextPicker = true
                            }
                        }
                    )
                }

                // Language dropdown (for translation)
                DropdownButton(
                    icon: "globe",
                    title: viewModel.selectedLanguage.flag,
                    options: Language.allCases.map { ($0.flag, $0.displayName, $0.rawValue) }
                ) { value in
                    if let language = Language(rawValue: value) {
                        viewModel.selectedLanguage = language
                    }
                }
            }
            .padding(.horizontal, 16)

            // Bottom row with globe button
            HStack {
                // Next keyboard button
                Button(action: {
                    KeyboardHaptics.lightTap()
                    onNextKeyboard()
                }) {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusSmall, style: .continuous))
                }

                Spacer()

                // Phase 11: Pending audio indicator OR Insert Last button
                if viewModel.pendingAudioCount > 0 {
                    Button(action: {
                        KeyboardHaptics.warning()
                        // Open main app to pending recordings
                        if let url = URL(string: "swiftspeak://pending") {
                            viewModel.openAppURL(url)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "waveform.badge.exclamationmark")
                                .font(.footnote)
                            Text("\(viewModel.pendingAudioCount) pending")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                    }
                } else if let lastText = viewModel.lastTranscription, !lastText.isEmpty {
                    Button(action: {
                        KeyboardHaptics.lightTap()
                        viewModel.insertLastTranscription()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.footnote)
                            Text("Insert Last")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(KeyboardTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(KeyboardTheme.accent.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                // Backspace button
                Button(action: {
                    KeyboardHaptics.lightTap()
                    viewModel.deleteBackward()
                }) {
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusSmall, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .background(KeyboardTheme.darkBase.opacity(0.95))
        .overlay {
            if showPowerModePicker {
                PowerModePickerOverlay(
                    powerModes: viewModel.powerModes,
                    onSelect: { mode in
                        showPowerModePicker = false
                        viewModel.startPowerMode(mode)
                    },
                    onDismiss: {
                        showPowerModePicker = false
                    }
                )
            }

            if showContextPicker {
                ContextPickerOverlay(
                    contexts: viewModel.contexts,
                    activeContextId: viewModel.activeContext?.id,
                    onSelect: { context in
                        showContextPicker = false
                        viewModel.selectContext(context)
                    },
                    onDismiss: {
                        showContextPicker = false
                    }
                )
            }
        }
    }
}

// MARK: - Power Mode Picker Overlay
struct PowerModePickerOverlay: View {
    let powerModes: [KeyboardPowerMode]
    let onSelect: (KeyboardPowerMode) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.orange)
                    Text("Select Power Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button(action: {
                    KeyboardHaptics.lightTap()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Power modes list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(powerModes) { mode in
                        Button(action: {
                            KeyboardHaptics.mediumTap()
                            onSelect(mode)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: mode.icon)
                                    .font(.body)
                                    .foregroundStyle(Color.orange)
                                    .frame(width: 28)

                                Text(mode.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)
                        }

                        if mode.id != powerModes.last?.id {
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusMedium, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 15)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(KeyboardTheme.quickSpring, value: true)
    }
}

// MARK: - Context Selector Button
struct ContextSelectorButton: View {
    let activeContext: KeyboardContext?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(activeContext?.icon ?? "👤")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(activeContext != nil ? Color.purple.opacity(0.2) : Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(activeContext != nil ? Color.purple.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Picker Overlay
struct ContextPickerOverlay: View {
    let contexts: [KeyboardContext]
    let activeContextId: UUID?
    let onSelect: (KeyboardContext?) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.purple)
                    Text("Select Context")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button(action: {
                    KeyboardHaptics.lightTap()
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Context list
            ScrollView {
                VStack(spacing: 0) {
                    // No Context option
                    Button(action: {
                        KeyboardHaptics.selection()
                        onSelect(nil)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.slash")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            Text("No Context")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            if activeContextId == nil {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.purple)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                    }

                    Divider()
                        .padding(.leading, 54)

                    // Context options
                    ForEach(contexts) { context in
                        Button(action: {
                            KeyboardHaptics.mediumTap()
                            onSelect(context)
                        }) {
                            HStack(spacing: 12) {
                                Text(context.icon)
                                    .font(.body)
                                    .frame(width: 28)

                                Text(context.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if activeContextId == context.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.purple)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)
                        }

                        if context.id != contexts.last?.id {
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusMedium, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 15)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(KeyboardTheme.quickSpring, value: true)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let gradient: LinearGradient
    var isPro: Bool = false
    var isLocked: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            if !isLocked {
                KeyboardHaptics.mediumTap()
                action()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))

                Text(title)
                    .font(.callout.weight(.semibold))

                if isPro && isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 4)
            .background(isLocked ? LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing) : gradient)
            .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusMedium, style: .continuous))
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(KeyboardTheme.quickSpring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Dropdown Button
struct DropdownButton: View {
    let icon: String
    let title: String
    let options: [(icon: String, title: String, value: String)]
    let onSelect: (String) -> Void

    @State private var showingOptions = false

    var body: some View {
        Button(action: {
            KeyboardHaptics.selection()
            withAnimation(KeyboardTheme.quickSpring) {
                showingOptions.toggle()
            }
        }) {
            HStack(spacing: 8) {
                if icon.count <= 2 {
                    Text(icon)
                        .font(.callout)
                } else {
                    Image(systemName: icon)
                        .font(.footnote)
                }

                Text(title)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)

                Image(systemName: showingOptions ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .overlay(
            Group {
                if showingOptions {
                    VStack(spacing: 0) {
                        ForEach(options.indices, id: \.self) { index in
                            Button(action: {
                                KeyboardHaptics.selection()
                                onSelect(options[index].value)
                                withAnimation(KeyboardTheme.quickSpring) {
                                    showingOptions = false
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if options[index].icon.count <= 2 {
                                        Text(options[index].icon)
                                            .font(.footnote)
                                    } else {
                                        Image(systemName: options[index].icon)
                                            .font(.caption)
                                    }

                                    Text(options[index].title)
                                        .font(.footnote)

                                    Spacer()
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                            }

                            if index < options.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: KeyboardTheme.cornerRadiusSmall, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 10)
                    .offset(y: -CGFloat(options.count * 44 + 10))
                }
            }
            , alignment: .top
        )
        .zIndex(showingOptions ? 1 : 0)
    }
}

// MARK: - Power Mode (minimal for keyboard)
struct KeyboardPowerMode: Identifiable {
    let id: UUID
    let name: String
    let icon: String
}

// MARK: - Keyboard AI Provider (minimal representation)
struct KeyboardAIProviderInfo {
    let name: String
    let model: String?
    let isConfigured: Bool
}

// MARK: - Custom Template (for keyboard)
struct KeyboardCustomTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
}

// MARK: - Keyboard Context (minimal for keyboard)
struct KeyboardContext: Identifiable {
    let id: UUID
    let name: String
    let icon: String
}

// MARK: - Keyboard Processing Status (Phase 11)
struct KeyboardProcessingStatus: Codable, Equatable {
    var isProcessing: Bool = false
    var currentStep: String = "idle"  // idle, recording, transcribing, formatting, translating, retrying, complete, failed
    var retryAttempt: Int = 0
    var maxRetries: Int = 3
    var errorMessage: String?
    var pendingAutoInsert: Bool = false
    var lastCompletedText: String?

    var displayText: String {
        switch currentStep {
        case "transcribing": return "Transcribing..."
        case "formatting": return "Formatting..."
        case "translating": return "Translating..."
        case "retrying": return "Retrying (\(retryAttempt)/\(maxRetries))..."
        case "complete": return "Done!"
        case "failed": return errorMessage ?? "Failed"
        default: return ""
        }
    }

    var icon: String {
        switch currentStep {
        case "transcribing", "formatting", "translating": return "circle.dotted"
        case "retrying": return "arrow.clockwise"
        case "complete": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        default: return ""
        }
    }

    var color: Color {
        switch currentStep {
        case "transcribing", "formatting", "translating", "retrying": return .blue
        case "complete": return .green
        case "failed": return .red
        default: return .clear
        }
    }
}

// MARK: - Keyboard ViewModel
class KeyboardViewModel: ObservableObject {
    @Published var selectedMode: FormattingMode = .raw
    @Published var selectedCustomTemplateId: UUID?
    @Published var selectedLanguage: Language = .spanish
    @Published var lastTranscription: String?
    @Published var isPro: Bool = false
    @Published var isPower: Bool = false
    @Published var powerModes: [KeyboardPowerMode] = []
    @Published var customTemplates: [KeyboardCustomTemplate] = []
    @Published var transcriptionProvider: KeyboardAIProviderInfo?
    @Published var contexts: [KeyboardContext] = []
    @Published var activeContext: KeyboardContext?

    // Phase 11: Processing status and pending audio
    @Published var processingStatus: KeyboardProcessingStatus = KeyboardProcessingStatus()
    @Published var pendingAudioCount: Int = 0

    weak var textDocumentProxy: UITextDocumentProxy?
    weak var hostViewController: UIViewController?

    init() {
        loadSettings()
    }

    /// Check for auto-insert when keyboard appears (Phase 11)
    func checkAutoInsert() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Load processing status
        if let data = defaults?.data(forKey: "processingStatus"),
           let status = try? JSONDecoder().decode(KeyboardProcessingStatus.self, from: data) {
            processingStatus = status

            // Auto-insert if pending
            if status.pendingAutoInsert, let text = status.lastCompletedText, !text.isEmpty {
                keyboardLog("Auto-inserting text (\(text.count) chars)", category: "Action")
                textDocumentProxy?.insertText(text)

                // Clear the auto-insert flag
                var updatedStatus = status
                updatedStatus.pendingAutoInsert = false
                updatedStatus.lastCompletedText = nil
                saveProcessingStatus(updatedStatus)
                processingStatus = updatedStatus
            }
        }
    }

    private func saveProcessingStatus(_ status: KeyboardProcessingStatus) {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let data = try? JSONEncoder().encode(status) {
            defaults?.set(data, forKey: "processingStatus")
        }
    }

    /// Dismiss error banner
    func dismissError() {
        var updatedStatus = processingStatus
        updatedStatus.isProcessing = false
        updatedStatus.currentStep = "idle"
        updatedStatus.errorMessage = nil
        saveProcessingStatus(updatedStatus)
        processingStatus = updatedStatus
    }

    /// All mode options for dropdown (built-in modes + custom templates for Pro users)
    var modeOptions: [(icon: String, title: String, value: String)] {
        var options = FormattingMode.allCases.map { mode in
            (mode.icon, mode.displayName, mode.rawValue)
        }

        // Add custom templates only for Pro users
        if isPro && !customTemplates.isEmpty {
            for template in customTemplates {
                options.append((template.icon, template.name, "custom:\(template.id.uuidString)"))
            }
        }

        return options
    }

    /// Current display name for mode selector
    var currentModeDisplayName: String {
        if let templateId = selectedCustomTemplateId,
           let template = customTemplates.first(where: { $0.id == templateId }) {
            return template.name
        }
        return selectedMode.displayName
    }

    /// Current icon for mode selector
    var currentModeIcon: String {
        if let templateId = selectedCustomTemplateId,
           let template = customTemplates.first(where: { $0.id == templateId }) {
            return template.icon
        }
        return selectedMode.icon
    }

    func loadSettings() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        if let modeRaw = defaults?.string(forKey: Constants.Keys.selectedMode),
           let mode = FormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = defaults?.string(forKey: Constants.Keys.selectedTargetLanguage),
           let lang = Language(rawValue: langRaw) {
            selectedLanguage = lang
        }

        lastTranscription = defaults?.string(forKey: Constants.Keys.lastTranscription)

        if let tierRaw = defaults?.string(forKey: Constants.Keys.subscriptionTier) {
            isPro = tierRaw == "pro" || tierRaw == "power"
            isPower = tierRaw == "power"
        }

        // Load configured AI providers for transcription
        loadAIProviders(from: defaults)

        // Load custom templates (Pro only)
        loadCustomTemplates(from: defaults)

        // Load power modes (mock data for now)
        powerModes = [
            KeyboardPowerMode(id: UUID(), name: "Research Assistant", icon: "magnifyingglass.circle.fill"),
            KeyboardPowerMode(id: UUID(), name: "Email Composer", icon: "envelope.fill"),
            KeyboardPowerMode(id: UUID(), name: "Daily Planner", icon: "calendar"),
            KeyboardPowerMode(id: UUID(), name: "Idea Expander", icon: "lightbulb.fill")
        ]

        // Load contexts (Pro only)
        if isPro {
            loadContexts(from: defaults)
        }

        // Phase 11: Load pending audio count
        loadPendingAudioCount(from: defaults)
    }

    private func loadPendingAudioCount(from defaults: UserDefaults?) {
        // Decode pending audio queue to get count
        guard let data = defaults?.data(forKey: "pendingAudioQueue") else {
            pendingAudioCount = 0
            return
        }

        // Simple struct just to decode the array
        struct SimplePendingAudio: Codable {
            let id: UUID
        }

        do {
            let queue = try JSONDecoder().decode([SimplePendingAudio].self, from: data)
            pendingAudioCount = queue.count
        } catch {
            pendingAudioCount = 0
        }
    }

    private func loadContexts(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: Constants.Keys.contexts) else {
            contexts = []
            activeContext = nil
            return
        }

        // Decode contexts (simplified struct for keyboard)
        struct SimpleContext: Codable {
            let id: UUID
            let name: String
            let icon: String
        }

        do {
            let loadedContexts = try JSONDecoder().decode([SimpleContext].self, from: data)
            contexts = loadedContexts.map { KeyboardContext(id: $0.id, name: $0.name, icon: $0.icon) }

            // Load active context ID
            if let activeIdString = defaults?.string(forKey: Constants.Keys.activeContextId),
               let activeId = UUID(uuidString: activeIdString),
               let context = contexts.first(where: { $0.id == activeId }) {
                activeContext = context
            } else {
                activeContext = nil
            }
        } catch {
            contexts = []
            activeContext = nil
        }
    }

    func selectContext(_ context: KeyboardContext?) {
        activeContext = context

        // Save to UserDefaults
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let context = context {
            defaults?.set(context.id.uuidString, forKey: Constants.Keys.activeContextId)
        } else {
            defaults?.removeObject(forKey: Constants.Keys.activeContextId)
        }
    }

    private func loadCustomTemplates(from defaults: UserDefaults?) {
        guard isPro else {
            customTemplates = []
            return
        }

        guard let data = defaults?.data(forKey: Constants.Keys.customTemplates) else {
            customTemplates = []
            return
        }

        // Decode custom templates (use same struct as main app)
        struct SimpleCustomTemplate: Codable {
            let id: UUID
            let name: String
            let icon: String
        }

        do {
            let templates = try JSONDecoder().decode([SimpleCustomTemplate].self, from: data)
            customTemplates = templates.map { KeyboardCustomTemplate(id: $0.id, name: $0.name, icon: $0.icon) }
        } catch {
            customTemplates = []
        }
    }

    private func loadAIProviders(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: Constants.Keys.configuredAIProviders) else {
            transcriptionProvider = nil
            return
        }

        // Decode the AI provider configs to find transcription provider
        // Using a simplified struct to decode just what we need
        struct SimpleAIProviderConfig: Codable {
            let provider: String
            let apiKey: String
            let transcriptionModel: String?
            let usageCategories: [String]
        }

        do {
            let configs = try JSONDecoder().decode([SimpleAIProviderConfig].self, from: data)

            // Find first provider configured for transcription
            if let transcriptionConfig = configs.first(where: { $0.usageCategories.contains("transcription") }) {
                let isConfigured = !transcriptionConfig.apiKey.isEmpty
                let providerName = transcriptionConfig.provider.capitalized
                transcriptionProvider = KeyboardAIProviderInfo(
                    name: providerName,
                    model: transcriptionConfig.transcriptionModel,
                    isConfigured: isConfigured
                )
            } else {
                transcriptionProvider = nil
            }
        } catch {
            transcriptionProvider = nil
        }
    }

    var isProviderConfigured: Bool {
        transcriptionProvider?.isConfigured == true
    }

    func saveSettings() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(selectedMode.rawValue, forKey: Constants.Keys.selectedMode)
        defaults?.set(selectedLanguage.rawValue, forKey: Constants.Keys.selectedTargetLanguage)
    }

    /// Select mode from dropdown (handles both built-in modes and custom templates)
    func selectMode(value: String) {
        if value.hasPrefix("custom:") {
            // Custom template selected
            let uuidString = String(value.dropFirst(7))  // Remove "custom:" prefix
            if let uuid = UUID(uuidString: uuidString) {
                selectedCustomTemplateId = uuid
                selectedMode = .raw  // Use raw as base mode
            }
        } else {
            // Built-in mode selected
            selectedCustomTemplateId = nil
            if let mode = FormattingMode(rawValue: value) {
                selectedMode = mode
            }
        }
    }

    func startTranscription() {
        saveSettings()
        keyboardLog("Transcription requested (mode: \(selectedMode.rawValue))", category: "Action")

        var urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=false"

        // Add custom template ID if selected
        if let templateId = selectedCustomTemplateId {
            urlString += "&template=\(templateId.uuidString)"
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    func startTranslation() {
        guard isPro else { return }
        saveSettings()
        keyboardLog("Translation requested (mode: \(selectedMode.rawValue), target: \(selectedLanguage.rawValue))", category: "Action")

        var urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=true&target=\(selectedLanguage.rawValue)"

        // Add custom template ID if selected
        if let templateId = selectedCustomTemplateId {
            urlString += "&template=\(templateId.uuidString)"
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    func startPowerMode(_ powerMode: KeyboardPowerMode) {
        guard isPower else { return }
        keyboardLog("Power Mode requested: \(powerMode.name)", category: "Action")

        let urlString = "swiftspeak://powermode?id=\(powerMode.id.uuidString)&autostart=true"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    func insertLastTranscription() {
        if let text = lastTranscription {
            keyboardLog("Inserting last transcription (\(text.count) chars)", category: "Action")
            textDocumentProxy?.insertText(text)
        }
    }

    func deleteBackward() {
        textDocumentProxy?.deleteBackward()
    }

    /// Open a URL from the keyboard (used for pending recordings, main app, etc)
    func openAppURL(_ url: URL) {
        openURL(url)
    }

    private func openURL(_ url: URL) {
        // Keyboard extensions must use the extensionContext to open URLs
        guard let hostVC = hostViewController else { return }

        // Use the responder chain to find a way to open URLs
        // This is the standard approach for keyboard extensions
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = hostVC
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                return
            }
            responder = responder?.next
        }
    }
}

// MARK: - Preview
#Preview {
    KeyboardView(viewModel: KeyboardViewModel(), onNextKeyboard: {})
        .frame(height: 220)
        .preferredColorScheme(.dark)
}
