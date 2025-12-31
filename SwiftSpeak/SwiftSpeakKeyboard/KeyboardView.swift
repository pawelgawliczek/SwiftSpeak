//
//  KeyboardView.swift
//  SwiftSpeakKeyboard
//
//  SwiftUI keyboard interface - Modern, clean design with wheel pickers
//

import SwiftUI
import UIKit
import Combine

// MARK: - Picker Mode
enum KeyboardPickerMode {
    case none
    case translation  // Combined translate + language picker
    case context
    case powerMode
    case swiftLink
}

// MARK: - Keyboard Display Mode
enum KeyboardDisplayMode {
    case voice   // Main SwiftSpeak voice interface
    case typing  // Standard typing keyboard
}

// MARK: - Keyboard View
struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onNextKeyboard: () -> Void

    @State private var activePicker: KeyboardPickerMode = .none
    @State private var displayMode: KeyboardDisplayMode = .voice
    @State private var dragOffset: CGFloat = 0

    private var shouldShowStatusBanner: Bool {
        let step = viewModel.processingStatus.currentStep
        return step == "streaming" || step == "transcribing" || step == "formatting" ||
               step == "translating" || step == "retrying" ||
               step == "complete" || step == "failed"
    }

    var body: some View {
        ZStack {
            // Voice keyboard (main)
            mainKeyboardContent
                .opacity(activePicker == .none && displayMode == .voice ? 1 : 0)
                .offset(x: displayMode == .voice ? dragOffset : -UIScreen.main.bounds.width + dragOffset)

            // Typing keyboard
            TypingKeyboardView(viewModel: viewModel, onNextKeyboard: onNextKeyboard) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    displayMode = .voice
                }
            }
            .opacity(displayMode == .typing ? 1 : 0)
            .offset(x: displayMode == .typing ? dragOffset : UIScreen.main.bounds.width + dragOffset)

            // Full-screen pickers
            if activePicker == .translation {
                TranslationWheelPicker(
                    isTranslationEnabled: viewModel.isTranslationEnabled,
                    selectedLanguage: viewModel.selectedLanguage,
                    onSelect: { enabled, lang in
                        viewModel.isTranslationEnabled = enabled
                        if let lang = lang {
                            viewModel.selectedLanguage = lang
                        }
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                    }
                )
                .transition(.opacity)
            }

            if activePicker == .context {
                ContextWheelPicker(
                    contexts: viewModel.contexts,
                    activeContextId: viewModel.activeContext?.id,
                    onSelect: { context in
                        viewModel.selectContext(context)
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                    }
                )
                .transition(.opacity)
            }

            if activePicker == .powerMode {
                PowerModeWheelPicker(
                    powerModes: viewModel.powerModes,
                    onSelect: { mode in
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                        viewModel.startPowerMode(mode)
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                    }
                )
                .transition(.opacity)
            }

            if activePicker == .swiftLink {
                SwiftLinkAppPicker(
                    apps: viewModel.swiftLinkApps,
                    onSelect: { app in
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                        viewModel.startSwiftLinkSession(with: app)
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .none
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .frame(height: 235)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow horizontal swipes when no picker is active
                    guard activePicker == .none else { return }

                    // Track horizontal drag
                    if abs(value.translation.width) > abs(value.translation.height) {
                        dragOffset = value.translation.width * 0.3
                    }
                }
                .onEnded { value in
                    guard activePicker == .none else { return }

                    let threshold: CGFloat = 50
                    let velocity = value.predictedEndTranslation.width

                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if displayMode == .voice && (value.translation.width < -threshold || velocity < -200) {
                            // Swipe left: go to typing keyboard
                            displayMode = .typing
                            KeyboardHaptics.selection()
                        } else if displayMode == .typing && (value.translation.width > threshold || velocity > 200) {
                            // Swipe right: go back to voice keyboard
                            displayMode = .voice
                            KeyboardHaptics.selection()
                        }
                        dragOffset = 0
                    }
                }
        )
        .clipped()
    }

    // MARK: - Main Keyboard Content
    private var mainKeyboardContent: some View {
        ZStack {
            // Status Banner (Phase 11) - at top
            VStack {
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
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }

            // Corner buttons - top row
            VStack {
                HStack {
                    // Left corner: Insert/Pending
                    if viewModel.pendingAudioCount > 0 {
                        PendingBadge(count: viewModel.pendingAudioCount) {
                            if let url = URL(string: "swiftspeak://pending") {
                                viewModel.openAppURL(url)
                            }
                        }
                    } else if let lastText = viewModel.lastTranscription, !lastText.isEmpty {
                        InsertLastButton {
                            viewModel.insertLastTranscription()
                        }
                    } else {
                        Color.clear.frame(width: 70, height: 34)
                    }

                    Spacer()

                    // Right corner: Switch to typing keyboard (within SwiftSpeak)
                    KeyboardSwitchButton {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            displayMode = .typing
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, shouldShowStatusBanner ? 48 : 12)

                Spacer()

                // Bottom corners
                HStack {
                    // Left corner: SwiftLink
                    if viewModel.isSwiftLinkSessionActive {
                        // Active: Green icon only
                        Button(action: {
                            KeyboardHaptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                activePicker = .swiftLink
                            }
                        }) {
                            Image(systemName: "link")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.green)
                                .frame(width: 32, height: 32)
                                .background(Color.green.opacity(0.15), in: Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Inactive: Orange with "Link" text
                        SwiftLinkCornerButton {
                            KeyboardHaptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                activePicker = .swiftLink
                            }
                        }
                    }

                    Spacer()

                    // Right corner: Empty or future use
                    Color.clear.frame(width: 60, height: 30)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            // Center: Main record button with arch mode buttons
            VStack(spacing: 0) {
                Spacer()

                // Arch layout container
                ZStack {
                    // Power Mode button - directly above (12 o'clock)
                    ArchModeButton(
                        icon: "⚡️",
                        label: "Power",
                        isLocked: !viewModel.isPower,
                        accentColor: .orange
                    ) {
                        if viewModel.isPower {
                            KeyboardHaptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                activePicker = .powerMode
                            }
                        }
                    }
                    .offset(y: -85)

                    // Translate button - 45° lower-left (10:30 position)
                    ArchModeButton(
                        icon: viewModel.isTranslationEnabled ? viewModel.selectedLanguage.flag : "🌐",
                        label: "Translate",
                        isActive: viewModel.isTranslationEnabled,
                        isLocked: !viewModel.isPro,
                        accentColor: .pink
                    ) {
                        if viewModel.isPro {
                            KeyboardHaptics.selection()
                            withAnimation(.spring(response: 0.3)) {
                                activePicker = .translation
                            }
                        }
                    }
                    .offset(x: -85, y: -42)

                    // Context button - 45° lower-right (1:30 position)
                    ArchModeButton(
                        icon: viewModel.activeContext?.icon ?? "👤",
                        label: "Context",
                        isActive: viewModel.activeContext != nil,
                        accentColor: .purple
                    ) {
                        KeyboardHaptics.selection()
                        withAnimation(.spring(response: 0.3)) {
                            activePicker = .context
                        }
                    }
                    .offset(x: 85, y: -42)

                    // Clear button - only visible when there's text (left side)
                    if viewModel.hasTextInField {
                        ClearButton {
                            viewModel.clearAllText()
                        }
                        .offset(x: -60, y: 25)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Main record button at center
                    MainActionButton(
                        isConfigured: viewModel.isProviderConfigured,
                        isSwiftLinkActive: viewModel.isSwiftLinkSessionActive,
                        isSwiftLinkRecording: viewModel.isSwiftLinkRecording,
                        isEditMode: viewModel.hasTextInField && viewModel.isPro,  // Phase 12: Edit mode (Pro only)
                        action: { viewModel.startTranscription() }
                    )

                    // Enter/Send button - only visible when there's text (right side)
                    if viewModel.hasTextInField {
                        EnterButton(returnKeyType: viewModel.textDocumentProxy?.returnKeyType ?? .default) {
                            viewModel.textDocumentProxy?.insertText("\n")
                            KeyboardHaptics.mediumTap()
                        }
                        .offset(x: 60, y: 25)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer()
                    .frame(height: 25)
            }

            // SwiftLink Streaming Overlay
            if viewModel.isSwiftLinkStreaming || viewModel.swiftLinkProcessingStatus == "streaming" {
                SwiftLinkStreamingOverlay(
                    transcript: viewModel.swiftLinkStreamingTranscript,
                    onStop: {
                        KeyboardHaptics.mediumTap()
                        viewModel.stopSwiftLinkRecording()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - SwiftLink Streaming Overlay
struct SwiftLinkStreamingOverlay: View {
    let transcript: String
    let onStop: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Semi-transparent green background
            Color.green.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // LIVE indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                            value: pulseScale
                        )

                    Text("LIVE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2), in: Capsule())

                // Transcript text
                ScrollView {
                    Text(transcript.isEmpty ? "Listening..." : transcript)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 120)

                // Stop button
                Button(action: onStop) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Stop & Insert")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            pulseScale = 1.3
        }
    }
}

// MARK: - Arch Mode Button
struct ArchModeButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var isLocked: Bool = false
    var accentColor: Color = .white

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isActive ? accentColor.opacity(0.25) : Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)

                    if icon.count <= 2 {
                        Text(icon)
                            .font(.system(size: 18))
                            .opacity(isLocked ? 0.4 : 1.0)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(isLocked ? 0.4 : 0.9))
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.5))
                            .offset(x: 14, y: 14)
                    }
                }

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SwiftSpeak Logo View (with fallback)
struct SwiftSpeakLogoView: View {
    var body: some View {
        if let uiImage = UIImage(named: "SwiftSpeakLogo") {
            // Use actual logo (rendered as template for tinting)
            Image(uiImage: uiImage)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback to mic icon
            Image(systemName: "mic.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

// MARK: - Keyboard Switch Button (styled like Insert)
struct KeyboardSwitchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11))
                Text("Keyboard")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(KeyboardTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(KeyboardTheme.accent.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SwiftLink Corner Button
struct SwiftLinkCornerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
                Text("Link")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.orange.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Enter Button
struct EnterButton: View {
    let returnKeyType: UIReturnKeyType
    let action: () -> Void

    @State private var isPressed = false

    private var isSendType: Bool {
        switch returnKeyType {
        case .send, .go, .done, .search, .join, .route:
            return true
        default:
            return false
        }
    }

    private var iconName: String {
        isSendType ? "arrow.up" : "return"
    }

    private var buttonColor: Color {
        isSendType ? .green : .blue
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSendType ? buttonColor : buttonColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSendType ? .white : buttonColor)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Clear Button
struct ClearButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = false
    var isLocked: Bool = false
    var accentColor: Color = .white

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? accentColor.opacity(0.25) : Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)

                if icon.count <= 2 {
                    Text(icon)
                        .font(.system(size: 16))
                        .opacity(isLocked ? 0.4 : 1.0)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(isLocked ? 0.4 : 0.9))
                }

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.white.opacity(0.5))
                        .offset(x: 12, y: 12)
                }
            }
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Main Action Button (Hero Mic Button)
struct MainActionButton: View {
    let isConfigured: Bool
    var isSwiftLinkActive: Bool = false
    var isSwiftLinkRecording: Bool = false
    var isEditMode: Bool = false  // Phase 12: Edit mode when text exists in field
    let action: () -> Void

    @State private var isPressed = false
    @State private var wavePhase: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0.6

    private var buttonColor: LinearGradient {
        if isSwiftLinkRecording {
            // Red pulsing for recording
            return LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isEditMode && isSwiftLinkActive {
            // Green for edit mode during SwiftLink
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isSwiftLinkActive {
            // Orange for SwiftLink session active
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isEditMode {
            // Green for edit mode (text in field)
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if isConfigured {
            return LinearGradient(colors: [KeyboardTheme.accent, KeyboardTheme.accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var glowColor: Color {
        if isSwiftLinkRecording {
            return .red
        } else if isEditMode {
            return .green
        } else if isSwiftLinkActive {
            return .orange
        } else if isConfigured {
            return KeyboardTheme.accent
        } else {
            return .orange
        }
    }

    var body: some View {
        Button(action: {
            KeyboardHaptics.mediumTap()
            action()
        }) {
            ZStack {
                // Animated expanding rings (recording only)
                if isSwiftLinkRecording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(ringOpacity - Double(i) * 0.15), lineWidth: 2)
                            .frame(width: 80 + CGFloat(i) * 22, height: 80 + CGFloat(i) * 22)
                            .scaleEffect(ringScale + CGFloat(i) * 0.1)
                    }
                }

                // Glow effect - pulsing when recording
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [glowColor.opacity(isSwiftLinkRecording ? 0.6 : 0.4), .clear],
                            center: .center,
                            startRadius: 25,
                            endRadius: isSwiftLinkRecording ? 85 : 60
                        )
                    )
                    .frame(width: isSwiftLinkRecording ? 145 : 110, height: isSwiftLinkRecording ? 145 : 110)
                    .scaleEffect(isSwiftLinkRecording ? pulseScale : 1.0)

                // Main button with logo
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: glowColor.opacity(isSwiftLinkRecording ? 0.8 : 0.5), radius: isSwiftLinkRecording ? 15 : 8, y: 2)

                // Content - SwiftSpeak logo or status icons
                if isSwiftLinkRecording {
                    // Animated voice waveform when recording
                    RecordingWaveform(phase: wavePhase)
                } else if !isConfigured {
                    // Warning icon when not configured
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                } else if isEditMode {
                    // Pencil icon for edit mode (Phase 12)
                    Image(systemName: "pencil")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    // SwiftSpeak logo with mic fallback - fills circle, maintains aspect ratio
                    SwiftSpeakLogoView()
                        .frame(width: 105, height: 105)
                        .foregroundStyle(.white)
                }

                // SwiftLink indicator badge (top-right) - only when active
                if isSwiftLinkActive && !isSwiftLinkRecording {
                    Circle()
                        .fill(.orange)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 28, y: -28)
                }

                // Label below button
                if isSwiftLinkRecording {
                    Text("Tap to stop")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red.opacity(0.9))
                        .offset(y: 56)
                } else if isEditMode && !isSwiftLinkRecording {
                    // Edit mode label (Phase 12)
                    Text("Edit text")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green.opacity(0.9))
                        .offset(y: 56)
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onChange(of: isSwiftLinkRecording) { _, isRecording in
            if isRecording {
                startRecordingAnimation()
            } else {
                stopRecordingAnimation()
            }
        }
        .onAppear {
            if isSwiftLinkRecording {
                startRecordingAnimation()
            }
        }
    }

    private func startRecordingAnimation() {
        // Continuous wave animation
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }

        // Ring expansion animation
        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            ringScale = 1.5
            ringOpacity = 0
        }
    }

    private func stopRecordingAnimation() {
        wavePhase = 0
        pulseScale = 1.0
        ringScale = 0.8
        ringOpacity = 0.6
    }
}

// MARK: - Recording Waveform Animation
struct RecordingWaveform: View {
    let phase: Double
    private let barCount = 7

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 3, height: barHeight(for: i))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Create a flowing wave effect
        let normalizedIndex = Double(index) / Double(barCount - 1)
        let waveOffset = phase + normalizedIndex * .pi * 2

        // Sine wave for smooth animation
        let sineValue = sin(waveOffset)

        // Map sine (-1 to 1) to height range (8 to 28)
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 28
        let height = minHeight + (maxHeight - minHeight) * CGFloat((sineValue + 1) / 2)

        return height
    }
}

// MARK: - Typing Keyboard View (iOS Standard Layout)
struct TypingKeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onNextKeyboard: () -> Void
    let onSwitchToVoice: () -> Void

    @State private var isShiftActive = false
    @State private var isCapsLock = false
    @State private var isNumberMode = false
    @State private var isSymbolMode = false

    // Standard iOS keyboard layout
    private let letterRows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    private let numberRows = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"]
    ]

    private let symbolRows = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
        [".", ",", "?", "!", "'"]
    ]

    private let keySpacing: CGFloat = 6
    private let rowSpacing: CGFloat = 11
    private let keyHeight: CGFloat = 42
    private let horizontalPadding: CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            // Swipe hint bar
            HStack {
                Button(action: onSwitchToVoice) {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Voice")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(KeyboardTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KeyboardTheme.accent.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text("← swipe for voice")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))

                Spacer()

                Button(action: onNextKeyboard) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Keyboard rows
            VStack(spacing: rowSpacing) {
                if isNumberMode || isSymbolMode {
                    // Number/Symbol mode
                    let rows = isSymbolMode ? symbolRows : numberRows

                    // Row 1: Numbers or symbols (10 keys)
                    HStack(spacing: keySpacing) {
                        ForEach(rows[0], id: \.self) { key in
                            StandardKey(letter: key, height: keyHeight) {
                                viewModel.textDocumentProxy?.insertText(key)
                                KeyboardHaptics.lightTap()
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                    // Row 2: More characters (10 keys)
                    HStack(spacing: keySpacing) {
                        ForEach(rows[1], id: \.self) { key in
                            StandardKey(letter: key, height: keyHeight) {
                                viewModel.textDocumentProxy?.insertText(key)
                                KeyboardHaptics.lightTap()
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                    // Row 3: Symbol toggle + punctuation + backspace
                    HStack(spacing: keySpacing) {
                        // Symbol/Number toggle
                        StandardActionKey(
                            text: isSymbolMode ? "123" : "#+="
                        ) {
                            isSymbolMode.toggle()
                            KeyboardHaptics.lightTap()
                        }
                        .frame(width: 42)

                        ForEach(rows[2], id: \.self) { key in
                            StandardKey(letter: key, height: keyHeight) {
                                viewModel.textDocumentProxy?.insertText(key)
                                KeyboardHaptics.lightTap()
                            }
                        }

                        // Backspace
                        StandardActionKey(icon: "delete.left") {
                            viewModel.textDocumentProxy?.deleteBackward()
                            KeyboardHaptics.lightTap()
                        }
                        .frame(width: 42)
                    }
                    .padding(.horizontal, horizontalPadding)

                } else {
                    // Letter mode

                    // Row 1: Q W E R T Y U I O P (10 keys)
                    HStack(spacing: keySpacing) {
                        ForEach(letterRows[0], id: \.self) { key in
                            let displayKey = (isShiftActive || isCapsLock) ? key : key.lowercased()
                            StandardKey(letter: displayKey, height: keyHeight) {
                                viewModel.textDocumentProxy?.insertText(displayKey)
                                KeyboardHaptics.lightTap()
                                if isShiftActive && !isCapsLock {
                                    isShiftActive = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                    // Row 2: A S D F G H J K L (9 keys, centered)
                    HStack(spacing: keySpacing) {
                        ForEach(letterRows[1], id: \.self) { key in
                            let displayKey = (isShiftActive || isCapsLock) ? key : key.lowercased()
                            StandardKey(letter: displayKey, height: keyHeight) {
                                viewModel.textDocumentProxy?.insertText(displayKey)
                                KeyboardHaptics.lightTap()
                                if isShiftActive && !isCapsLock {
                                    isShiftActive = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding + 18) // Extra padding for centering

                    // Row 3: Shift + Z X C V B N M + Backspace
                    HStack(spacing: keySpacing) {
                        // Shift key
                        StandardActionKey(
                            icon: isCapsLock ? "capslock.fill" : (isShiftActive ? "shift.fill" : "shift"),
                            isHighlighted: isShiftActive || isCapsLock
                        ) {
                            if isShiftActive {
                                // Double tap for caps lock
                                isCapsLock = true
                                isShiftActive = false
                            } else if isCapsLock {
                                isCapsLock = false
                            } else {
                                isShiftActive = true
                            }
                            KeyboardHaptics.lightTap()
                        }
                        .frame(width: 42)

                        ForEach(letterRows[2], id: \.self) { key in
                            let displayKey = (isShiftActive || isCapsLock) ? key : key.lowercased()
                            StandardKey(letter: displayKey, height: keyHeight) {
                                viewModel.textDocumentProxy?.insertText(displayKey)
                                KeyboardHaptics.lightTap()
                                if isShiftActive && !isCapsLock {
                                    isShiftActive = false
                                }
                            }
                        }

                        // Backspace key
                        StandardActionKey(icon: "delete.left") {
                            viewModel.textDocumentProxy?.deleteBackward()
                            KeyboardHaptics.lightTap()
                        }
                        .frame(width: 42)
                    }
                    .padding(.horizontal, horizontalPadding)
                }

                // Row 4: 123/ABC + space + return
                HStack(spacing: keySpacing) {
                    // Number/Letter toggle
                    StandardActionKey(text: isNumberMode ? "ABC" : "123") {
                        isNumberMode.toggle()
                        isSymbolMode = false
                        KeyboardHaptics.lightTap()
                    }
                    .frame(width: 87)

                    // Space bar
                    Button(action: {
                        viewModel.textDocumentProxy?.insertText(" ")
                        KeyboardHaptics.lightTap()
                    }) {
                        Text("space")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: keyHeight)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
                            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)

                    // Return key
                    StandardActionKey(text: "return") {
                        viewModel.textDocumentProxy?.insertText("\n")
                        KeyboardHaptics.mediumTap()
                    }
                    .frame(width: 87)
                }
                .padding(.horizontal, horizontalPadding)
            }
            .padding(.bottom, 4)
        }
        .background(Color(white: 0.82))
    }
}

// MARK: - Standard Key (Letter/Number)
struct StandardKey: View {
    let letter: String
    let height: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isPressed ? Color(white: 0.75) : .white)
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Standard Action Key (Shift, Backspace, etc.)
struct StandardActionKey: View {
    var icon: String? = nil
    var text: String? = nil
    var isHighlighted: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    private var backgroundColor: Color {
        if isHighlighted {
            return .white
        }
        return Color(white: 0.67)
    }

    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 15, weight: .regular))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isPressed ? Color(white: 0.55) : backgroundColor)
                    .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Compact Button
struct CompactButton: View {
    let icon: String
    let title: String
    var isLocked: Bool = false
    var accentColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isLocked ? Color.white.opacity(0.08) : accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if icon.count <= 2 {
                        Text(icon)
                            .font(.system(size: 18))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(isLocked ? 0.5 : 0.9))
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.6))
                            .offset(x: 14, y: 14)
                    }
                }

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary Action Button
struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var isLocked: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(isLocked ? .white.opacity(0.5) : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isLocked ? Color.gray.opacity(0.3) : color.opacity(0.85))
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Insert Last Button
struct InsertLastButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11))
                Text("Insert")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(KeyboardTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(KeyboardTheme.accent.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Badge
struct PendingBadge: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: {
            KeyboardHaptics.warning()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.system(size: 11))
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SwiftLink Start Button
struct SwiftLinkStartButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 11))
                Text("SwiftLink")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Banner
struct StatusBanner: View {
    let status: KeyboardProcessingStatus
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if status.currentStep == "streaming" {
                // Animated waveform icon for streaming
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .symbolEffect(.pulse, options: .repeating)
            } else if status.currentStep == "transcribing" || status.currentStep == "formatting" ||
               status.currentStep == "translating" || status.currentStep == "retrying" {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 12, weight: .semibold))
            }

            Text(status.displayText)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer()

            if status.currentStep == "failed" {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue, in: Capsule())
                }
            }

            if status.currentStep == "complete" || status.currentStep == "failed" {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(status.color.opacity(0.9), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Language Wheel Picker
struct LanguageWheelPicker: View {
    let selectedLanguage: Language
    let onSelect: (Language) -> Void
    let onCancel: () -> Void

    @State private var selection: Language = .english

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Text("Language")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: { onSelect(selection) }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeyboardTheme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // Wheel picker
            Picker("Language", selection: $selection) {
                ForEach(Language.allCases, id: \.self) { language in
                    HStack(spacing: 10) {
                        Text(language.flag)
                        Text(language.displayName)
                    }
                    .foregroundStyle(.white)
                    .tag(language)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            selection = selectedLanguage
        }
    }
}

// MARK: - Translation Wheel Picker
struct TranslationWheelPicker: View {
    let isTranslationEnabled: Bool
    let selectedLanguage: Language
    let onSelect: (Bool, Language?) -> Void  // (enabled, language)
    let onCancel: () -> Void

    @State private var selection: String = "none"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .foregroundStyle(.pink)
                    Text("Translation")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: {
                    if selection == "none" {
                        onSelect(false, nil)
                    } else if let lang = Language(rawValue: selection) {
                        onSelect(true, lang)
                    }
                }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.pink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // Wheel picker with "No Translation" + languages
            Picker("Translation", selection: $selection) {
                // No translation option
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                    Text("No Translation")
                }
                .foregroundStyle(.white)
                .tag("none")

                // Language options
                ForEach(Language.allCases, id: \.self) { language in
                    HStack(spacing: 10) {
                        Text(language.flag)
                        Text("→ \(language.displayName)")
                    }
                    .foregroundStyle(.white)
                    .tag(language.rawValue)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            selection = isTranslationEnabled ? selectedLanguage.rawValue : "none"
        }
    }
}

// MARK: - Context Wheel Picker
struct ContextWheelPicker: View {
    let contexts: [KeyboardContext]
    let activeContextId: UUID?
    let onSelect: (KeyboardContext?) -> Void
    let onCancel: () -> Void

    @State private var selection: String = "none"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Text("Context")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(action: {
                    if selection == "none" {
                        onSelect(nil)
                    } else if let context = contexts.first(where: { $0.id.uuidString == selection }) {
                        onSelect(context)
                    }
                }) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // Wheel picker
            Picker("Context", selection: $selection) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.slash")
                    Text("No Context")
                }
                .foregroundStyle(.white)
                .tag("none")

                ForEach(contexts) { context in
                    HStack(spacing: 10) {
                        Text(context.icon)
                        Text(context.name)
                    }
                    .foregroundStyle(.white)
                    .tag(context.id.uuidString)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            selection = activeContextId?.uuidString ?? "none"
        }
    }
}

// MARK: - Power Mode Wheel Picker
struct PowerModeWheelPicker: View {
    let powerModes: [KeyboardPowerMode]
    let onSelect: (KeyboardPowerMode) -> Void
    let onCancel: () -> Void

    @State private var selection: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                    Text("Power Mode")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: {
                    if let mode = powerModes.first(where: { $0.id.uuidString == selection }) {
                        onSelect(mode)
                    }
                }) {
                    Text("Run")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // Wheel picker
            Picker("Power Mode", selection: $selection) {
                ForEach(powerModes) { mode in
                    HStack(spacing: 10) {
                        Image(systemName: mode.icon)
                            .foregroundStyle(.orange)
                        Text(mode.name)
                    }
                    .foregroundStyle(.white)
                    .tag(mode.id.uuidString)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            selection = powerModes.first?.id.uuidString ?? ""
        }
    }
}

// MARK: - SwiftLink App Picker
struct SwiftLinkAppPicker: View {
    let apps: [KeyboardSwiftLinkApp]
    let onSelect: (KeyboardSwiftLinkApp) -> Void
    let onCancel: () -> Void

    @State private var selection: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "link.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Start SwiftLink")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: {
                    if let app = apps.first(where: { $0.bundleId == selection }) {
                        onSelect(app)
                    }
                }) {
                    Text("Start")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // App list picker
            Picker("App", selection: $selection) {
                ForEach(apps) { app in
                    HStack(spacing: 10) {
                        if let iconName = app.iconName {
                            Image(systemName: iconName)
                                .foregroundStyle(.orange)
                        }
                        Text(app.name)
                    }
                    .foregroundStyle(.white)
                    .tag(app.bundleId)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            selection = apps.first?.bundleId ?? ""
        }
    }
}

// MARK: - Supporting Types

struct KeyboardPowerMode: Identifiable {
    let id: UUID
    let name: String
    let icon: String
}

struct KeyboardAIProviderInfo {
    let name: String
    let model: String?
    let isConfigured: Bool
}

struct KeyboardCustomTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
}

struct KeyboardContext: Identifiable {
    let id: UUID
    let name: String
    let icon: String
}

struct KeyboardSwiftLinkApp: Identifiable, Codable {
    var id: String { bundleId }
    let bundleId: String
    let name: String
    let urlScheme: String?
    let iconName: String?
}

// MARK: - Processing Status
struct KeyboardProcessingStatus: Codable, Equatable {
    var isProcessing: Bool = false
    var currentStep: String = "idle"
    var retryAttempt: Int = 0
    var maxRetries: Int = 3
    var errorMessage: String?
    var pendingAutoInsert: Bool = false
    var lastCompletedText: String?
    /// Live streaming transcript (partial/interim results)
    var streamingTranscript: String?

    var displayText: String {
        switch currentStep {
        case "streaming":
            // Show live transcript or placeholder
            if let transcript = streamingTranscript, !transcript.isEmpty {
                // Truncate if too long for banner
                let maxLength = 50
                if transcript.count > maxLength {
                    return "..." + String(transcript.suffix(maxLength))
                }
                return transcript
            }
            return "Listening..."
        case "transcribing": return "Transcribing..."
        case "formatting": return "Formatting..."
        case "translating": return "Translating..."
        case "retrying": return "Retry \(retryAttempt)/\(maxRetries)..."
        case "complete": return "Done!"
        case "failed": return errorMessage ?? "Failed"
        default: return ""
        }
    }

    var icon: String {
        switch currentStep {
        case "streaming": return "waveform"
        case "complete": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        default: return "circle.dotted"
        }
    }

    var color: Color {
        switch currentStep {
        case "streaming": return .orange
        case "transcribing", "formatting", "translating", "retrying": return .blue
        case "complete": return .green
        case "failed": return .red
        default: return .clear
        }
    }
}

// MARK: - ViewModel
class KeyboardViewModel: ObservableObject {
    @Published var selectedMode: FormattingMode = .raw
    @Published var selectedCustomTemplateId: UUID?
    @Published var selectedLanguage: Language = .spanish
    @Published var isTranslationEnabled: Bool = false
    @Published var lastTranscription: String?
    @Published var isPro: Bool = false
    @Published var isPower: Bool = false
    @Published var powerModes: [KeyboardPowerMode] = []
    @Published var customTemplates: [KeyboardCustomTemplate] = []
    @Published var transcriptionProvider: KeyboardAIProviderInfo?
    @Published var contexts: [KeyboardContext] = []
    @Published var activeContext: KeyboardContext?
    @Published var processingStatus: KeyboardProcessingStatus = KeyboardProcessingStatus()
    @Published var pendingAudioCount: Int = 0

    // SwiftLink state
    @Published var isSwiftLinkSessionActive: Bool = false
    @Published var isSwiftLinkRecording: Bool = false
    @Published var swiftLinkProcessingStatus: String = ""
    @Published var swiftLinkApps: [KeyboardSwiftLinkApp] = []
    /// Whether SwiftLink is currently streaming (live transcription)
    @Published var isSwiftLinkStreaming: Bool = false
    /// Live streaming transcript from SwiftLink
    @Published var swiftLinkStreamingTranscript: String = ""

    weak var textDocumentProxy: UITextDocumentProxy?
    weak var hostViewController: UIViewController?

    private let darwinManager = DarwinNotificationManager.shared

    // SwiftLink timeout handling
    private var swiftLinkTimeoutTimer: Timer?
    private var swiftLinkStatusCheckTimer: Timer?
    private static let swiftLinkTimeoutSeconds: TimeInterval = 5.0
    private static let swiftLinkMaxSessionAge: TimeInterval = 600.0  // 10 minutes max session age
    private static let swiftLinkStatusCheckInterval: TimeInterval = 30.0  // Check every 30 seconds

    /// Returns true if there's any text in the current text field
    var hasTextInField: Bool {
        guard let proxy = textDocumentProxy else { return false }
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        return !before.isEmpty || !after.isEmpty
    }

    /// Returns the existing text in the text field (Phase 12)
    var existingTextInField: String? {
        guard let proxy = textDocumentProxy else { return nil }
        let before = proxy.documentContextBeforeInput ?? ""
        let after = proxy.documentContextAfterInput ?? ""
        let combined = before + after
        return combined.isEmpty ? nil : combined
    }

    init() {
        loadSettings()
        setupSwiftLinkObservers()
    }

    private func setupSwiftLinkObservers() {
        // Check initial SwiftLink session state
        checkSwiftLinkSession()

        // Observe session started
        darwinManager.observeSessionStarted { [weak self] in
            DispatchQueue.main.async {
                self?.isSwiftLinkSessionActive = true
                self?.checkSwiftLinkSession()
                keyboardLog("SwiftLink session started notification received", category: "SwiftLink")
            }
        }

        // Observe session ended
        darwinManager.observeSessionEnded { [weak self] in
            DispatchQueue.main.async {
                self?.isSwiftLinkSessionActive = false
                self?.isSwiftLinkRecording = false
                keyboardLog("SwiftLink session ended notification received", category: "SwiftLink")
            }
        }

        // Observe result ready
        darwinManager.observeResultReady { [weak self] in
            DispatchQueue.main.async {
                self?.handleSwiftLinkResult()
            }
        }

        // Observe streaming updates
        darwinManager.observeStreamingUpdate { [weak self] in
            DispatchQueue.main.async {
                self?.handleStreamingUpdate()
            }
        }
    }

    /// Handle streaming transcript update from main app
    private func handleStreamingUpdate() {
        // Cancel timeout - we're receiving streaming updates, so main app is responsive
        cancelSwiftLinkTimeout()

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        let status = defaults?.string(forKey: Constants.Keys.swiftLinkProcessingStatus) ?? ""
        let transcript = defaults?.string(forKey: Constants.Keys.swiftLinkStreamingTranscript) ?? ""

        if status == "streaming" {
            // Only log when transcript actually changes
            if transcript != swiftLinkStreamingTranscript {
                keyboardLog("Streaming transcript: \(transcript.count) chars", category: "SwiftLink")
            }
            isSwiftLinkStreaming = true
            swiftLinkStreamingTranscript = transcript
            swiftLinkProcessingStatus = "streaming"
        } else {
            // Streaming ended
            if isSwiftLinkStreaming {
                keyboardLog("Streaming ended (status: \(status))", category: "SwiftLink")
            }
            isSwiftLinkStreaming = false
        }
    }

    private func checkSwiftLinkSession() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        isSwiftLinkSessionActive = defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) ?? false
    }

    private func handleSwiftLinkResult() {
        // Cancel any pending timeout - we got a response
        cancelSwiftLinkTimeout()

        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Force sync to ensure we have latest data from main app
        defaults?.synchronize()

        let status = defaults?.string(forKey: Constants.Keys.swiftLinkProcessingStatus) ?? ""
        let wasEdit = defaults?.bool(forKey: Constants.EditMode.lastResultWasEdit) ?? false

        keyboardLog("SwiftLink result received (status: \(status), wasEdit: \(wasEdit))", category: "SwiftLink")

        swiftLinkProcessingStatus = status
        isSwiftLinkRecording = false
        isSwiftLinkStreaming = false
        swiftLinkStreamingTranscript = ""

        if status == "complete", let result = defaults?.string(forKey: Constants.Keys.swiftLinkTranscriptionResult) {
            keyboardLog("SwiftLink result received (\(result.count) chars, edit: \(wasEdit))", category: "SwiftLink")

            // Phase 12: If this was an edit, clear existing text first
            if wasEdit {
                keyboardLog("Clearing existing text for edit replacement", category: "SwiftLink")
                deleteAllTextInField()
            }

            // Insert the result
            keyboardLog("Inserting result text", category: "SwiftLink")
            textDocumentProxy?.insertText(result)

            // Clear the result and edit flag
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkTranscriptionResult)
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkProcessingStatus)
            defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
            defaults?.removeObject(forKey: Constants.EditMode.swiftLinkEditOriginalText)
            defaults?.synchronize()

            // Update last transcription
            lastTranscription = result
        } else if status == "error" {
            let errorMsg = defaults?.string(forKey: Constants.Keys.swiftLinkTranscriptionResult) ?? "Unknown error"
            keyboardLog("SwiftLink error: \(errorMsg)", category: "SwiftLink", level: .error)

            // Check if session expired - mark SwiftLink as inactive and fall back to app
            if errorMsg.contains("expired") || errorMsg.contains("not active") || errorMsg.contains("Session") {
                keyboardLog("SwiftLink session is invalid - marking as inactive", category: "SwiftLink", level: .warning)
                isSwiftLinkSessionActive = false

                // Clear the stale session flag in App Groups
                defaults?.set(false, forKey: Constants.Keys.swiftLinkSessionActive)
            }

            // Clear error state
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkTranscriptionResult)
            defaults?.removeObject(forKey: Constants.Keys.swiftLinkProcessingStatus)
            defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
            defaults?.removeObject(forKey: Constants.EditMode.swiftLinkEditOriginalText)
            defaults?.synchronize()
        } else {
            keyboardLog("SwiftLink result not ready yet (status: '\(status)')", category: "SwiftLink", level: .warning)
        }
    }

    /// Delete all text in the current text field (Phase 12: for edit mode replacement)
    private func deleteAllTextInField() {
        guard let proxy = textDocumentProxy else {
            keyboardLog("No textDocumentProxy available for deletion", category: "Action", level: .error)
            return
        }

        // Get the total length of text in the field
        let beforeCount = (proxy.documentContextBeforeInput ?? "").count
        let afterCount = (proxy.documentContextAfterInput ?? "").count
        let totalCount = beforeCount + afterCount

        keyboardLog("Deleting \(totalCount) chars (before: \(beforeCount), after: \(afterCount))", category: "Action")

        guard totalCount > 0 else { return }

        // Move to end of text first
        if afterCount > 0 {
            proxy.adjustTextPosition(byCharacterOffset: afterCount)
        }

        // Now delete all text (we're at the end, so delete backward)
        for _ in 0..<totalCount {
            proxy.deleteBackward()
        }

        keyboardLog("Cleared existing text for edit replacement", category: "Action")
    }

    /// Public method to clear all text in the field
    func clearAllText() {
        KeyboardHaptics.mediumTap()
        deleteAllTextInField()
        // Force view to re-check hasTextInField by sending objectWillChange
        objectWillChange.send()
    }

    func toggleSwiftLinkRecording() {
        if isSwiftLinkRecording {
            stopSwiftLinkRecording()
        } else {
            // Start recording
            isSwiftLinkRecording = true
            darwinManager.postDictationStart()
            swiftLinkProcessingStatus = "recording"
            startSwiftLinkTimeout()  // Start timeout to detect stale session
            keyboardLog("SwiftLink dictation started", category: "SwiftLink")
        }
    }

    /// Stop SwiftLink recording and trigger processing
    func stopSwiftLinkRecording() {
        guard isSwiftLinkRecording || isSwiftLinkStreaming else { return }

        isSwiftLinkRecording = false
        isSwiftLinkStreaming = false
        cancelSwiftLinkTimeout()
        darwinManager.postDictationStop()
        swiftLinkProcessingStatus = "processing"
        startSwiftLinkTimeout()  // Start timeout for processing phase
        keyboardLog("SwiftLink dictation stopped", category: "SwiftLink")
    }

    // MARK: - SwiftLink Timeout Handling

    private func startSwiftLinkTimeout() {
        cancelSwiftLinkTimeout()

        keyboardLog("SwiftLink timeout started (\(Self.swiftLinkTimeoutSeconds)s)", category: "SwiftLink")

        swiftLinkTimeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.swiftLinkTimeoutSeconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleSwiftLinkTimeout()
            }
        }
    }

    private func cancelSwiftLinkTimeout() {
        if swiftLinkTimeoutTimer != nil {
            keyboardLog("SwiftLink timeout cancelled", category: "SwiftLink")
        }
        swiftLinkTimeoutTimer?.invalidate()
        swiftLinkTimeoutTimer = nil
    }

    private func handleSwiftLinkTimeout() {
        keyboardLog("SwiftLink TIMEOUT - no response from main app after \(Self.swiftLinkTimeoutSeconds)s", category: "SwiftLink", level: .warning)
        keyboardLog("Session state before timeout: active=\(isSwiftLinkSessionActive), recording=\(isSwiftLinkRecording)", category: "SwiftLink", level: .warning)

        // Mark session as inactive
        markSwiftLinkAsStale(reason: "Timeout - no response from main app")
    }

    /// Verify SwiftLink session is still valid before using it.
    /// Returns true if session is valid, false if stale (and marks it inactive).
    private func verifySwiftLinkSession() -> Bool {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        // Check if session is marked active
        guard defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) == true else {
            keyboardLog("SwiftLink verify: session not marked active", category: "SwiftLink")
            isSwiftLinkSessionActive = false
            return false
        }

        // Check session start timestamp
        let sessionStartTime = defaults?.double(forKey: Constants.Keys.swiftLinkSessionStartTime) ?? 0
        guard sessionStartTime > 0 else {
            keyboardLog("SwiftLink verify: no session start timestamp", category: "SwiftLink", level: .warning)
            markSwiftLinkAsStale(reason: "No session timestamp")
            return false
        }

        // Check if session is too old
        let sessionAge = Date().timeIntervalSince1970 - sessionStartTime
        if sessionAge > Self.swiftLinkMaxSessionAge {
            keyboardLog("SwiftLink verify: session too old (\(Int(sessionAge))s > \(Int(Self.swiftLinkMaxSessionAge))s)", category: "SwiftLink", level: .warning)
            markSwiftLinkAsStale(reason: "Session expired (\(Int(sessionAge/60)) minutes old)")
            return false
        }

        keyboardLog("SwiftLink verify: session valid (age: \(Int(sessionAge))s)", category: "SwiftLink")
        return true
    }

    /// Mark SwiftLink session as stale and clean up
    private func markSwiftLinkAsStale(reason: String) {
        keyboardLog("SwiftLink marked as stale: \(reason)", category: "SwiftLink", level: .warning)

        isSwiftLinkSessionActive = false
        isSwiftLinkRecording = false
        swiftLinkProcessingStatus = ""

        // Clear the stale session flag in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(false, forKey: Constants.Keys.swiftLinkSessionActive)
        defaults?.removeObject(forKey: Constants.Keys.swiftLinkSessionStartTime)
        defaults?.removeObject(forKey: Constants.EditMode.swiftLinkEditOriginalText)
        defaults?.removeObject(forKey: Constants.EditMode.lastResultWasEdit)
        defaults?.synchronize()

        // Provide haptic feedback
        KeyboardHaptics.warning()
    }

    // MARK: - SwiftLink Periodic Status Check

    /// Start periodic SwiftLink status checks
    private func startSwiftLinkStatusChecks() {
        stopSwiftLinkStatusChecks()

        // Immediate check
        performSwiftLinkStatusCheck()

        // Schedule periodic checks
        swiftLinkStatusCheckTimer = Timer.scheduledTimer(withTimeInterval: Self.swiftLinkStatusCheckInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.performSwiftLinkStatusCheck()
            }
        }

        keyboardLog("SwiftLink status checks started (every \(Int(Self.swiftLinkStatusCheckInterval))s)", category: "SwiftLink")
    }

    /// Stop periodic SwiftLink status checks
    private func stopSwiftLinkStatusChecks() {
        swiftLinkStatusCheckTimer?.invalidate()
        swiftLinkStatusCheckTimer = nil
    }

    /// Perform a SwiftLink status check and update UI
    private func performSwiftLinkStatusCheck() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.synchronize()

        let wasActive = isSwiftLinkSessionActive

        // Check if session is still valid
        if defaults?.bool(forKey: Constants.Keys.swiftLinkSessionActive) == true {
            let sessionStartTime = defaults?.double(forKey: Constants.Keys.swiftLinkSessionStartTime) ?? 0

            if sessionStartTime > 0 {
                let sessionAge = Date().timeIntervalSince1970 - sessionStartTime

                if sessionAge > Self.swiftLinkMaxSessionAge {
                    // Session is too old
                    keyboardLog("SwiftLink status check: session expired (\(Int(sessionAge))s old)", category: "SwiftLink", level: .warning)
                    markSwiftLinkAsStale(reason: "Session expired during status check")
                } else {
                    // Session is valid
                    if !wasActive {
                        keyboardLog("SwiftLink status check: session now active (age: \(Int(sessionAge))s)", category: "SwiftLink")
                    }
                    isSwiftLinkSessionActive = true
                }
            } else {
                // No timestamp but marked active - stale
                if wasActive {
                    keyboardLog("SwiftLink status check: no timestamp, marking stale", category: "SwiftLink", level: .warning)
                    markSwiftLinkAsStale(reason: "No session timestamp")
                }
                isSwiftLinkSessionActive = false
            }
        } else {
            // Not marked active
            if wasActive {
                keyboardLog("SwiftLink status check: session no longer active", category: "SwiftLink")
            }
            isSwiftLinkSessionActive = false
        }
    }

    func checkAutoInsert() {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        if let data = defaults?.data(forKey: "processingStatus"),
           let status = try? JSONDecoder().decode(KeyboardProcessingStatus.self, from: data) {
            processingStatus = status

            if status.pendingAutoInsert, let text = status.lastCompletedText, !text.isEmpty {
                keyboardLog("Auto-inserting text (\(text.count) chars)", category: "Action")
                textDocumentProxy?.insertText(text)

                var updatedStatus = status
                updatedStatus.pendingAutoInsert = false
                updatedStatus.lastCompletedText = nil
                saveProcessingStatus(updatedStatus)
                processingStatus = updatedStatus

                // Auto-dismiss "Done" banner after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.dismissStatus()
                }
            }
        }
    }

    private func saveProcessingStatus(_ status: KeyboardProcessingStatus) {
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let data = try? JSONEncoder().encode(status) {
            defaults?.set(data, forKey: "processingStatus")
        }
    }

    func dismissError() {
        var updatedStatus = processingStatus
        updatedStatus.isProcessing = false
        updatedStatus.currentStep = "idle"
        updatedStatus.errorMessage = nil
        saveProcessingStatus(updatedStatus)
        processingStatus = updatedStatus
    }

    func dismissStatus() {
        var updatedStatus = processingStatus
        updatedStatus.isProcessing = false
        updatedStatus.currentStep = "idle"
        updatedStatus.errorMessage = nil
        saveProcessingStatus(updatedStatus)
        processingStatus = updatedStatus
        keyboardLog("Status banner auto-dismissed", category: "Action")
    }

    var modeOptions: [(icon: String, title: String, value: String)] {
        var options = FormattingMode.allCases.map { mode in
            (mode.icon, mode.displayName, mode.rawValue)
        }

        if isPro && !customTemplates.isEmpty {
            for template in customTemplates {
                options.append((template.icon, template.name, "custom:\(template.id.uuidString)"))
            }
        }

        return options
    }

    var currentModeDisplayName: String {
        if let templateId = selectedCustomTemplateId,
           let template = customTemplates.first(where: { $0.id == templateId }) {
            return template.name
        }
        return selectedMode.displayName
    }

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

        loadAIProviders(from: defaults)
        loadCustomTemplates(from: defaults)

        powerModes = [
            KeyboardPowerMode(id: UUID(), name: "Research", icon: "magnifyingglass"),
            KeyboardPowerMode(id: UUID(), name: "Email", icon: "envelope.fill"),
            KeyboardPowerMode(id: UUID(), name: "Planner", icon: "calendar"),
            KeyboardPowerMode(id: UUID(), name: "Ideas", icon: "lightbulb.fill")
        ]

        // Load contexts for all users (presets available to everyone)
        loadContexts(from: defaults)

        loadPendingAudioCount(from: defaults)
        loadSwiftLinkApps(from: defaults)

        // Refresh SwiftLink session state
        checkSwiftLinkSession()
    }

    private func loadSwiftLinkApps(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: Constants.Keys.swiftLinkApps) else {
            // Load default popular apps if none configured
            swiftLinkApps = defaultSwiftLinkApps
            return
        }

        do {
            let apps = try JSONDecoder().decode([KeyboardSwiftLinkApp].self, from: data)
            swiftLinkApps = apps.isEmpty ? defaultSwiftLinkApps : apps
        } catch {
            swiftLinkApps = defaultSwiftLinkApps
        }
    }

    private var defaultSwiftLinkApps: [KeyboardSwiftLinkApp] {
        [
            KeyboardSwiftLinkApp(bundleId: "net.whatsapp.WhatsApp", name: "WhatsApp", urlScheme: "whatsapp://", iconName: "message.fill"),
            KeyboardSwiftLinkApp(bundleId: "com.apple.MobileSMS", name: "Messages", urlScheme: "sms://", iconName: "message.fill"),
            KeyboardSwiftLinkApp(bundleId: "com.apple.mobilemail", name: "Mail", urlScheme: "mailto://", iconName: "envelope.fill"),
            KeyboardSwiftLinkApp(bundleId: "com.slack.Slack", name: "Slack", urlScheme: "slack://", iconName: "number"),
            KeyboardSwiftLinkApp(bundleId: "org.telegram.Telegram", name: "Telegram", urlScheme: "telegram://", iconName: "paperplane.fill"),
        ]
    }

    /// Called when keyboard appears to refresh all state
    func refreshState() {
        loadSettings()
        checkSwiftLinkSession()
        startSwiftLinkStatusChecks()  // Start periodic status checks
    }

    /// Called when keyboard disappears to clean up
    func cleanup() {
        stopSwiftLinkStatusChecks()
        cancelSwiftLinkTimeout()
    }

    private func loadPendingAudioCount(from defaults: UserDefaults?) {
        guard let data = defaults?.data(forKey: "pendingAudioQueue") else {
            pendingAudioCount = 0
            return
        }

        struct SimplePendingAudio: Codable { let id: UUID }

        do {
            let queue = try JSONDecoder().decode([SimplePendingAudio].self, from: data)
            pendingAudioCount = queue.count
        } catch {
            pendingAudioCount = 0
        }
    }

    private func loadContexts(from defaults: UserDefaults?) {
        // Start with preset contexts (available to all users)
        let presetContexts: [KeyboardContext] = [
            KeyboardContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Work",
                icon: "💼"
            ),
            KeyboardContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Personal",
                icon: "😊"
            ),
            KeyboardContext(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Creative",
                icon: "✨"
            )
        ]

        // Load custom contexts from shared defaults
        var customContexts: [KeyboardContext] = []
        if let data = defaults?.data(forKey: Constants.Keys.contexts) {
            struct SimpleContext: Codable {
                let id: UUID
                let name: String
                let icon: String
                let isPreset: Bool?
            }

            do {
                let loadedContexts = try JSONDecoder().decode([SimpleContext].self, from: data)
                // Filter out presets (they're hardcoded above)
                customContexts = loadedContexts
                    .filter { $0.isPreset != true }
                    .map { KeyboardContext(id: $0.id, name: $0.name, icon: $0.icon) }
            } catch {
                customContexts = []
            }
        }

        // Combine presets + custom
        contexts = presetContexts + customContexts

        // Set active context if one is selected
        if let activeIdString = defaults?.string(forKey: Constants.Keys.activeContextId),
           let activeId = UUID(uuidString: activeIdString),
           let context = contexts.first(where: { $0.id == activeId }) {
            activeContext = context
        } else {
            activeContext = nil
        }
    }

    func selectContext(_ context: KeyboardContext?) {
        activeContext = context
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        if let context = context {
            defaults?.set(context.id.uuidString, forKey: Constants.Keys.activeContextId)
        } else {
            defaults?.removeObject(forKey: Constants.Keys.activeContextId)
        }
    }

    private func loadCustomTemplates(from defaults: UserDefaults?) {
        guard isPro, let data = defaults?.data(forKey: Constants.Keys.customTemplates) else {
            customTemplates = []
            return
        }

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

        struct SimpleAIProviderConfig: Codable {
            let provider: String
            let apiKey: String
            let transcriptionModel: String?
            let usageCategories: [String]
        }

        do {
            let configs = try JSONDecoder().decode([SimpleAIProviderConfig].self, from: data)

            if let config = configs.first(where: { $0.usageCategories.contains("transcription") }) {
                transcriptionProvider = KeyboardAIProviderInfo(
                    name: config.provider.capitalized,
                    model: config.transcriptionModel,
                    isConfigured: !config.apiKey.isEmpty
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

    func selectMode(value: String) {
        if value.hasPrefix("custom:") {
            let uuidString = String(value.dropFirst(7))
            if let uuid = UUID(uuidString: uuidString) {
                selectedCustomTemplateId = uuid
                selectedMode = .raw
            }
        } else {
            selectedCustomTemplateId = nil
            if let mode = FormattingMode(rawValue: value) {
                selectedMode = mode
            }
        }
    }

    func startTranscription() {
        // If no provider configured, open setup instead
        guard isProviderConfigured else {
            keyboardLog("No provider configured, opening setup", category: "Action")
            if let url = URL(string: "swiftspeak://setup") {
                openURL(url)
            }
            return
        }

        // Phase 12: Check for edit mode (existing text in field)
        // Edit mode is Pro-only feature - free users always do normal transcription
        let isEditMode = hasTextInField && isPro

        if hasTextInField && !isPro {
            keyboardLog("Edit mode requires Pro - using normal transcription", category: "Action")
        }

        // Check for active SwiftLink session - use inline dictation
        if isSwiftLinkSessionActive {
            // If already recording, stop it (regardless of edit mode)
            if isSwiftLinkRecording {
                keyboardLog("Stopping SwiftLink recording", category: "SwiftLink")
                toggleSwiftLinkRecording()
                return
            }

            // Verify session is still valid before starting new recording
            guard verifySwiftLinkSession() else {
                keyboardLog("SwiftLink session invalid - falling back to app workflow", category: "SwiftLink", level: .warning)
                // Session is stale, continue to normal app workflow below
                saveSettings()
                startNormalTranscription(isEditMode: isEditMode)
                return
            }

            // Start new recording
            if isEditMode {
                keyboardLog("Using SwiftLink inline edit mode", category: "SwiftLink")
                startSwiftLinkEdit()
            } else {
                keyboardLog("Using SwiftLink inline dictation", category: "SwiftLink")
                toggleSwiftLinkRecording()
            }
            return
        }

        saveSettings()
        startNormalTranscription(isEditMode: isEditMode)
    }

    /// Start normal transcription flow via main app (non-SwiftLink)
    private func startNormalTranscription(isEditMode: Bool) {
        // Phase 12: Edit mode via URL scheme
        if isEditMode {
            startEditModeViaURL()
            return
        }

        // Normal transcription flow
        let translate = isTranslationEnabled && isPro
        keyboardLog("Transcription requested via app (translate: \(translate))", category: "Action")

        var urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=\(translate)"
        if translate {
            urlString += "&target=\(selectedLanguage.rawValue)"
        }
        if let templateId = selectedCustomTemplateId {
            urlString += "&template=\(templateId.uuidString)"
        }

        if let url = URL(string: urlString) { openURL(url) }
    }

    // MARK: - Phase 12: Edit Mode

    /// Start edit mode by opening main app with original text (non-SwiftLink flow)
    private func startEditModeViaURL() {
        guard let originalText = existingTextInField else { return }

        // Store original text in App Groups (URL encoding large text is problematic)
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(originalText, forKey: Constants.EditMode.pendingEditText)

        keyboardLog("Edit mode requested (\(originalText.count) chars)", category: "Action")

        // Open main app in edit mode
        if let url = URL(string: "swiftspeak://\(Constants.URLHosts.edit)") {
            openURL(url)
        }
    }

    /// Start edit mode via SwiftLink (stays in keyboard)
    private func startSwiftLinkEdit() {
        guard let originalText = existingTextInField else { return }

        // Store original text in App Groups
        let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        defaults?.set(originalText, forKey: Constants.EditMode.swiftLinkEditOriginalText)
        defaults?.set(true, forKey: Constants.EditMode.lastResultWasEdit)
        defaults?.synchronize()

        // Update UI state
        isSwiftLinkRecording = true
        swiftLinkProcessingStatus = "recording"

        // Start timeout to detect stale session
        startSwiftLinkTimeout()

        // Send startEdit notification (different from startDictation)
        darwinManager.post(name: Constants.SwiftLinkNotifications.startEdit)

        keyboardLog("SwiftLink edit started (\(originalText.count) chars)", category: "SwiftLink")
    }

    // Keep for backward compatibility
    func startTranslation() {
        guard isPro else { return }
        isTranslationEnabled = true
        saveSettings()
        keyboardLog("Translation requested", category: "Action")

        var urlString = "swiftspeak://record?mode=\(selectedMode.rawValue)&translate=true&target=\(selectedLanguage.rawValue)"
        if let templateId = selectedCustomTemplateId {
            urlString += "&template=\(templateId.uuidString)"
        }

        if let url = URL(string: urlString) { openURL(url) }
    }

    func startPowerMode(_ powerMode: KeyboardPowerMode) {
        guard isPower else { return }
        keyboardLog("Power Mode: \(powerMode.name)", category: "Action")

        let urlString = "swiftspeak://powermode?id=\(powerMode.id.uuidString)&autostart=true"
        if let url = URL(string: urlString) { openURL(url) }
    }

    func startSwiftLinkSession(with app: KeyboardSwiftLinkApp) {
        keyboardLog("Starting SwiftLink session for \(app.name)", category: "SwiftLink")

        // Open main app with SwiftLink start request
        // URL encode parameters properly
        let encodedName = app.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? app.name
        var urlString = "swiftspeak://swiftlink?action=start&bundleId=\(app.bundleId)&app=\(encodedName)"
        if let scheme = app.urlScheme {
            // URL encode the scheme parameter since it contains :// which can confuse URL parsing
            let encodedScheme = scheme.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scheme
            urlString += "&scheme=\(encodedScheme)"
        }

        keyboardLog("SwiftLink URL: \(urlString)", category: "SwiftLink")
        if let url = URL(string: urlString) { openURL(url) }
    }

    func insertLastTranscription() {
        if let text = lastTranscription {
            keyboardLog("Insert last (\(text.count) chars)", category: "Action")
            textDocumentProxy?.insertText(text)
        }
    }

    func deleteBackward() {
        textDocumentProxy?.deleteBackward()
    }

    func openAppURL(_ url: URL) {
        openURL(url)
    }

    private func openURL(_ url: URL) {
        // Method 1: Try to get UIApplication.shared via KVC (works in extensions)
        guard let application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication else {
            keyboardLog("Could not get shared application", category: "Action", level: .error)
            return
        }

        application.open(url, options: [:]) { success in
            if success {
                keyboardLog("URL opened successfully", category: "Action")
            } else {
                keyboardLog("Failed to open URL", category: "Action", level: .error)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    KeyboardView(viewModel: KeyboardViewModel(), onNextKeyboard: {})
        .preferredColorScheme(.dark)
}
