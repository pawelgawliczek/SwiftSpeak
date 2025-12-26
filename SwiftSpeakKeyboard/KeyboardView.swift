//
//  KeyboardView.swift
//  SwiftSpeakKeyboard
//
//  SwiftUI keyboard interface
//

import SwiftUI
import UIKit
import Combine

// MARK: - Models (duplicated for keyboard extension since it can't share with main app)
enum KeyboardFormattingMode: String, CaseIterable, Identifiable {
    case raw = "raw"
    case email = "email"
    case formal = "formal"
    case casual = "casual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: return "Raw"
        case .email: return "Email"
        case .formal: return "Formal"
        case .casual: return "Casual"
        }
    }

    var icon: String {
        switch self {
        case .raw: return "text.alignleft"
        case .email: return "envelope.fill"
        case .formal: return "briefcase.fill"
        case .casual: return "face.smiling.fill"
        }
    }
}

enum KeyboardLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case polish = "pl"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .polish: return "Polish"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .polish: return "🇵🇱"
        }
    }
}

// MARK: - Keyboard View
struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onNextKeyboard: () -> Void

    @State private var showPowerModePicker = false

    var body: some View {
        VStack(spacing: 12) {
            // Main action buttons
            HStack(spacing: 8) {
                // Transcribe button
                ActionButton(
                    icon: "mic.fill",
                    title: "Transcribe",
                    gradient: KeyboardTheme.accentGradient
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

            // Mode and Language selectors
            HStack(spacing: 12) {
                // Mode dropdown
                DropdownButton(
                    icon: viewModel.selectedMode.icon,
                    title: viewModel.selectedMode.displayName,
                    options: KeyboardFormattingMode.allCases.map { ($0.icon, $0.displayName, $0.rawValue) }
                ) { value in
                    if let mode = KeyboardFormattingMode(rawValue: value) {
                        viewModel.selectedMode = mode
                    }
                }

                // Language dropdown (for translation)
                DropdownButton(
                    icon: "globe",
                    title: viewModel.selectedLanguage.flag,
                    options: KeyboardLanguage.allCases.map { ($0.flag, $0.displayName, $0.rawValue) }
                ) { value in
                    if let language = KeyboardLanguage(rawValue: value) {
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

                // Quick insert last transcription
                if let lastText = viewModel.lastTranscription, !lastText.isEmpty {
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

// MARK: - Keyboard ViewModel
class KeyboardViewModel: ObservableObject {
    @Published var selectedMode: KeyboardFormattingMode = .raw
    @Published var selectedLanguage: KeyboardLanguage = .spanish
    @Published var lastTranscription: String?
    @Published var isPro: Bool = false
    @Published var isPower: Bool = false
    @Published var powerModes: [KeyboardPowerMode] = []

    weak var textDocumentProxy: UITextDocumentProxy?
    weak var hostViewController: UIViewController?

    private let appGroupID = "group.pawelgawliczek.swiftspeak"

    init() {
        loadSettings()
    }

    func loadSettings() {
        let defaults = UserDefaults(suiteName: appGroupID)

        if let modeRaw = defaults?.string(forKey: "selectedMode"),
           let mode = KeyboardFormattingMode(rawValue: modeRaw) {
            selectedMode = mode
        }

        if let langRaw = defaults?.string(forKey: "selectedTargetLanguage"),
           let lang = KeyboardLanguage(rawValue: langRaw) {
            selectedLanguage = lang
        }

        lastTranscription = defaults?.string(forKey: "lastTranscription")

        if let tierRaw = defaults?.string(forKey: "subscriptionTier") {
            isPro = tierRaw == "pro" || tierRaw == "power"
            isPower = tierRaw == "power"
        }

        // Load power modes (mock data for now)
        powerModes = [
            KeyboardPowerMode(id: UUID(), name: "Research Assistant", icon: "magnifyingglass.circle.fill"),
            KeyboardPowerMode(id: UUID(), name: "Email Composer", icon: "envelope.fill"),
            KeyboardPowerMode(id: UUID(), name: "Daily Planner", icon: "calendar"),
            KeyboardPowerMode(id: UUID(), name: "Idea Expander", icon: "lightbulb.fill")
        ]
    }

    func saveSettings() {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(selectedMode.rawValue, forKey: "selectedMode")
        defaults?.set(selectedLanguage.rawValue, forKey: "selectedTargetLanguage")
    }

    func startTranscription() {
        saveSettings()
        let urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=false"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    func startTranslation() {
        guard isPro else { return }
        saveSettings()
        let urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=true&target=\(selectedLanguage.rawValue)"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    func startPowerMode(_ powerMode: KeyboardPowerMode) {
        guard isPower else { return }
        let urlString = "swiftspeak://powermode?id=\(powerMode.id.uuidString)&autostart=true"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    func insertLastTranscription() {
        if let text = lastTranscription {
            textDocumentProxy?.insertText(text)
        }
    }

    func deleteBackward() {
        textDocumentProxy?.deleteBackward()
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
