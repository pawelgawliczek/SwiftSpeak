//
//  MacTranscribeOverlayView.swift
//  SwiftSpeakMac
//
//  Floating overlay for voice transcription
//  Supports toggle mode and push-to-talk mode
//

import SwiftUI
import SwiftSpeakCore
import Combine

// MARK: - Main Overlay View

struct MacTranscribeOverlayView: View {
    @ObservedObject var viewModel: MacTranscribeOverlayViewModel
    let onClose: () -> Void
    let onFinish: () -> Void

    @State private var logoScale: CGFloat = 1.0
    @State private var logoGlow: Double = 0.3
    @State private var processingElapsed: TimeInterval = 0
    @State private var processingStartTime: Date = Date()
    @State private var isViewActive = false
    @State private var processingTimerCancellable: AnyCancellable?

    // Timer that doesn't autoconnect - controlled via state
    private let processingTimer = Timer.publish(every: 1, on: .main, in: .common)

    var body: some View {
        VStack(spacing: 16) {
            if case .error(let message) = viewModel.state {
                errorView(message: message)
            } else if viewModel.state.isProcessing {
                processingView
            } else if viewModel.state == .complete {
                completeView
            } else {
                recordingView
            }
        }
        .padding(20)
        .background(overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
        .onAppear {
            isViewActive = true
            startLogoAnimation()
            // Connect timer only when view appears
            processingTimerCancellable = processingTimer.connect() as? AnyCancellable
        }
        .onDisappear {
            isViewActive = false
            stopLogoAnimation()
            // Disconnect timer when view disappears
            processingTimerCancellable?.cancel()
            processingTimerCancellable = nil
        }
        .onReceive(processingTimer) { _ in
            if viewModel.state.isProcessing {
                processingElapsed = Date().timeIntervalSince(processingStartTime)
            }
        }
        .onChange(of: viewModel.state) { newState in
            guard isViewActive else { return }
            if newState.isProcessing {
                processingStartTime = Date()
                processingElapsed = 0
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
    }

    // MARK: - Processing View

    private var processingView: some View {
        HStack(spacing: 20) {
            // Brain icon with orange glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40
                        )
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)

                Circle()
                    .strokeBorder(Color.orange.opacity(0.5), lineWidth: 2)
                    .frame(width: 50, height: 50)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(viewModel.state.statusText.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .tracking(2)

                    Text("(\(formattedProcessingTime))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.7))
                }

                TranscribeProcessingAnimationView()
                    .frame(height: 20)
            }

            Spacer()
        }
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TRANSCRIPTION COMPLETE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .tracking(2)

                    Text(viewModel.transcribedText.prefix(80) + (viewModel.transcribedText.count > 80 ? "..." : ""))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: viewModel.copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("c", modifiers: .command)

                Button(action: { Task { await viewModel.insertText() } }) {
                    Label("Insert", systemImage: "arrow.up.doc")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])

                Button("Done", action: onFinish)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("TRANSCRIPTION FAILED")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .tracking(2)

                    ScrollView(.vertical, showsIndicators: true) {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 150)
                }

                Spacer(minLength: 0)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Retry processing the existing recording (not start new recording)
                    Task {
                        await viewModel.retryProcessing()
                    }
                }) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.return, modifiers: [])

                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
            }
        }
        .frame(minWidth: 400)
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 16) {
            // Toggle circles row
            toggleCirclesRow

            // Main recording content
            HStack(spacing: 16) {
                pulsingLogo

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(statusColor)
                                .tracking(2)

                            Text(formattedDuration)
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        // Show loading animation during initialization, waveform during recording
                        if viewModel.state == .initializing {
                            TranscribeProcessingAnimationView()
                                .frame(width: 100, height: 32)
                        } else {
                            TranscribeWaveformView(viewModel: viewModel)
                                .frame(width: 100, height: 32)
                        }
                    }

                    // Active indicators
                    activeIndicatorsRow
                }
            }
            .padding(.horizontal, 4)

            // Transcribed text preview during streaming
            // Always show during recording state for streaming feedback
            transcriptView

            // Keyboard hints
            keyboardHintsRow
        }
    }

    // MARK: - Toggle Circles Row

    private var toggleCirclesRow: some View {
        HStack(spacing: 24) {
            // Translation toggle
            TranscribeTranslationToggle(
                isEnabled: $viewModel.isTranslationEnabled,
                selectedLanguage: $viewModel.targetLanguage
            )

            // Context picker
            TranscribeContextToggle(
                activeContext: $viewModel.activeContext,
                contexts: viewModel.settings.contexts
            )
        }
        .padding(.bottom, 8)
    }

    // MARK: - Pulsing Logo

    private var pulsingLogo: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [logoGlowColor.opacity(logoGlow), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(logoScale)

            Image("SwiftSpeakLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Active Indicators Row

    private var activeIndicatorsRow: some View {
        HStack(spacing: 8) {
            if let ctx = viewModel.activeContext {
                TranscribeIndicatorPill(icon: ctx.icon, text: ctx.name, color: .purple, isEmoji: true)
            }

            if viewModel.isTranslationEnabled {
                TranscribeIndicatorPill(
                    icon: "globe",
                    text: "-> \(viewModel.targetLanguage.displayName)",
                    color: .blue
                )
            }

            if let lang = viewModel.inputLanguage {
                TranscribeIndicatorPill(icon: "waveform", text: lang.displayName, color: .green)
            }

            // Show audio quality indicator (always show when recording to inform user)
            if viewModel.state == .recording || viewModel.state == .initializing {
                audioQualityIndicator
            }

            Spacer()
        }
    }

    private var audioQualityIndicator: some View {
        let quality = viewModel.effectiveAudioQuality
        let (icon, color): (String, Color) = {
            switch quality {
            case .high:
                return ("wifi", .green)
            case .standard:
                return ("wifi", .yellow)
            case .lowBandwidth:
                return ("wifi.exclamationmark", .orange)
            case .auto:
                return ("wifi", .green) // Should be resolved, but fallback
            }
        }()

        return TranscribeIndicatorPill(
            icon: icon,
            text: quality == .high ? "HQ" : quality.displayName,
            color: color
        )
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        // Always show - display "Listening..." or transcript content
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.liveTranscript.isEmpty {
                Text("🎤 Listening...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .italic()
            } else {
                // Use ScrollViewReader to auto-scroll to bottom
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(viewModel.liveTranscript)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .id("transcriptEnd")
                    }
                    .onChange(of: viewModel.liveTranscript) { _ in
                        // Scroll to bottom when text changes
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("transcriptEnd", anchor: .bottom)
                        }
                    }
                }
                .frame(maxHeight: 80)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Keyboard Hints Row

    private var keyboardHintsRow: some View {
        HStack(spacing: 16) {
            if viewModel.mode == .pushToTalk {
                TranscribeKeyboardHint(key: "T", action: "translation")
                TranscribeKeyboardHint(key: "C", action: "context")
                TranscribeKeyboardHint(key: "release", action: "finish")
                TranscribeKeyboardHint(key: "Esc", action: "cancel")
            } else {
                TranscribeKeyboardHint(key: "T", action: "translation")
                TranscribeKeyboardHint(key: "C", action: "context")
                TranscribeKeyboardHint(key: "Enter", action: "finish")
                TranscribeKeyboardHint(key: "Esc", action: "cancel")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    // MARK: - Background

    private var overlayBackground: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Computed Properties

    private var statusText: String {
        switch viewModel.state {
        case .recording: return "RECORDING"
        case .ready: return "READY"
        case .initializing: return "PREPARING..."
        default: return viewModel.state.statusText.uppercased()
        }
    }

    private var statusColor: Color {
        switch viewModel.state {
        case .recording: return .red
        case .ready: return .green
        case .initializing: return .orange
        default: return .orange
        }
    }

    private var logoGlowColor: Color {
        switch viewModel.state {
        case .recording: return .red
        case .initializing: return .orange
        default: return .green
        }
    }

    private var formattedDuration: String {
        let duration = viewModel.recordingDuration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedProcessingTime: String {
        let seconds = Int(processingElapsed)
        return "\(seconds)s"
    }

    // MARK: - Animations

    private func startLogoAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            logoScale = 1.1
            logoGlow = 0.6
        }
    }

    private func stopLogoAnimation() {
        // Stop animation by setting values without animation
        withAnimation(nil) {
            logoScale = 1.0
            logoGlow = 0.3
        }
    }
}

// MARK: - Translation Toggle Circle

struct TranscribeTranslationToggle: View {
    @Binding var isEnabled: Bool
    @Binding var selectedLanguage: Language

    @State private var isHovering = false

    var body: some View {
        Menu {
            Button(action: { isEnabled.toggle() }) {
                Label(isEnabled ? "Disable Translation" : "Enable Translation",
                      systemImage: isEnabled ? "xmark.circle" : "checkmark.circle")
            }

            Divider()

            ForEach(Language.allCases) { language in
                Button(action: {
                    selectedLanguage = language
                    isEnabled = true
                }) {
                    HStack {
                        Text("\(language.flag) \(language.displayName)")
                        Spacer()
                        if isEnabled && selectedLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Circle()
                        .strokeBorder(isEnabled ? Color.blue : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 48, height: 48)

                    if isEnabled {
                        Text(selectedLanguage.flag)
                            .font(.system(size: 24))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text("T")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .offset(x: 18, y: -18)
                }

                Text(isEnabled ? selectedLanguage.displayName : "Trans")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isEnabled ? .blue : .secondary)
                    .lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Context Toggle Circle

struct TranscribeContextToggle: View {
    @Binding var activeContext: ConversationContext?
    let contexts: [ConversationContext]

    @State private var isHovering = false

    private var isActive: Bool { activeContext != nil }
    private var currentIcon: String { activeContext?.icon ?? "person.circle" }
    private var isEmoji: Bool { activeContext?.icon.first?.isEmoji ?? false }

    var body: some View {
        Menu {
            Button(action: { activeContext = nil }) {
                HStack {
                    Text("None")
                    Spacer()
                    if activeContext == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Preset contexts
            ForEach(ConversationContext.presets) { context in
                Button(action: { activeContext = context }) {
                    HStack {
                        Text("\(context.icon) \(context.name)")
                        Spacer()
                        if activeContext?.id == context.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Custom contexts
            let customContexts = contexts.filter { !$0.isPreset }
            if !customContexts.isEmpty {
                Divider()
                ForEach(customContexts) { context in
                    Button(action: { activeContext = context }) {
                        HStack {
                            Text("\(context.icon) \(context.name)")
                            Spacer()
                            if activeContext?.id == context.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.purple.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Circle()
                        .strokeBorder(isActive ? Color.purple : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 48, height: 48)

                    if isEmoji {
                        Text(currentIcon)
                            .font(.system(size: isActive ? 24 : 20))
                    } else {
                        Image(systemName: currentIcon)
                            .font(.system(size: isActive ? 22 : 18, weight: .medium))
                            .foregroundStyle(isActive ? .purple : .white.opacity(0.8))
                    }

                    Text("C")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .offset(x: 18, y: -18)
                }

                Text(activeContext?.name ?? "Context")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isActive ? .purple : .secondary)
                    .lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Indicator Pill

struct TranscribeIndicatorPill: View {
    let icon: String
    let text: String
    let color: Color
    var isEmoji: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if isEmoji {
                Text(icon)
                    .font(.caption2)
            } else {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Keyboard Hint

struct TranscribeKeyboardHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(action)
        }
    }
}

// MARK: - Waveform View

struct TranscribeWaveformView: View {
    @ObservedObject var viewModel: MacTranscribeOverlayViewModel

    private let barCount = 20

    @State private var waveformLevels: [Double] = Array(repeating: 0.08, count: 20)
    @State private var lastLevel: Float = 0

    private var isRecording: Bool {
        viewModel.state == .recording
    }

    var body: some View {
        // Use TimelineView for guaranteed updates during recording
        TimelineView(.animation(minimumInterval: 0.05, paused: !isRecording)) { timeline in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let barLevel = waveformLevels.indices.contains(index) ? waveformLevels[index] : 0.08
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(for: barLevel))
                        .frame(width: 4, height: max(4, CGFloat(barLevel) * 36))
                }
            }
            .onChange(of: timeline.date) { _ in
                // Update waveform on each timeline tick - read latest level from viewModel
                guard isRecording else { return }
                let currentLevel = viewModel.audioLevel
                if currentLevel != lastLevel {
                    var newLevels = waveformLevels
                    newLevels.removeFirst()
                    let normalizedLevel = Double(max(0.08, min(1.0, currentLevel)))
                    newLevels.append(normalizedLevel)
                    waveformLevels = newLevels
                    lastLevel = currentLevel
                }
            }
        }
        .onChange(of: viewModel.audioLevel) { newLevel in
            // Also update on level change for immediate response
            guard isRecording else { return }
            var newLevels = waveformLevels
            newLevels.removeFirst()
            let normalizedLevel = Double(max(0.08, min(1.0, newLevel)))
            newLevels.append(normalizedLevel)
            waveformLevels = newLevels
        }
    }

    private func barColor(for level: Double) -> Color {
        guard isRecording else { return Color.gray.opacity(0.4) }

        if level < 0.25 { return .green }
        if level < 0.45 { return .yellow }
        if level < 0.65 { return .orange }
        return .red
    }
}

// MARK: - Processing Animation View

struct TranscribeProcessingAnimationView: View {
    private let barCount = 8

    var body: some View {
        // Use TimelineView for efficient animation that only runs when visible
        TimelineView(.animation(minimumInterval: 0.08, paused: false)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 1.875 // ~0.15 per 0.08s
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    TranscribeProcessingBar(index: index, phase: phase)
                }
            }
        }
    }
}

struct TranscribeProcessingBar: View {
    let index: Int
    let phase: Double

    var body: some View {
        let normalizedPhase = (phase + Double(index) * 0.3).truncatingRemainder(dividingBy: 2 * .pi)
        let heightFactor = (sin(normalizedPhase) + 1) / 2
        let height = 4 + heightFactor * 16

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.orange, Color.orange.opacity(0.6)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: height)
            .animation(.easeInOut(duration: 0.08), value: phase)
    }
}

// Note: Language.flag is defined in RecordingOverlayView.swift

// MARK: - Preview

#Preview("Recording") {
    let settings = MacSettings.shared
    let viewModel = MacTranscribeOverlayViewModel(
        settings: settings,
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .recording
    viewModel.mode = .toggle

    return MacTranscribeOverlayView(
        viewModel: viewModel,
        onClose: {},
        onFinish: {}
    )
    .frame(width: 380, height: 280)
    .background(Color.gray.opacity(0.3))
}

#Preview("Processing") {
    let settings = MacSettings.shared
    let viewModel = MacTranscribeOverlayViewModel(
        settings: settings,
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .transcribing

    return MacTranscribeOverlayView(
        viewModel: viewModel,
        onClose: {},
        onFinish: {}
    )
    .frame(width: 380, height: 120)
    .background(Color.gray.opacity(0.3))
}

#Preview("Complete") {
    let settings = MacSettings.shared
    let viewModel = MacTranscribeOverlayViewModel(
        settings: settings,
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .complete
    viewModel.transcribedText = "This is a test transcription that was successfully completed."

    return MacTranscribeOverlayView(
        viewModel: viewModel,
        onClose: {},
        onFinish: {}
    )
    .frame(width: 380, height: 180)
    .background(Color.gray.opacity(0.3))
}
