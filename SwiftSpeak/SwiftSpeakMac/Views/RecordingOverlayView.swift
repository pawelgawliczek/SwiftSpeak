//
//  RecordingOverlayView.swift
//  SwiftSpeakMac
//
//  Floating recording overlay with toggle circles, waveform, and live transcript
//

import SwiftUI
import SwiftSpeakCore
import AppKit
import Combine

// MARK: - Overlay View Model

@MainActor
class OverlayViewModel: ObservableObject {
    @Published var isTranslationEnabled: Bool = false
    @Published var targetLanguage: Language = .english
    @Published var isProcessing: Bool = false {
        didSet {
            if isProcessing {
                processingStartTime = Date()
            }
        }
    }
    @Published var liveTranscript: String = ""
    @Published var showToggleCircles: Bool = false
    @Published var processingStartTime: Date = Date()
}

// MARK: - Overlay Wrapper View

struct OverlayWrapperView: View {
    @ObservedObject var audioRecorder: MacAudioRecorder
    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject var settings: MacSettings
    let onStop: () -> Void
    let onCancel: () -> Void

    var body: some View {
        RecordingOverlayView(
            audioRecorder: audioRecorder,
            settings: settings,
            viewModel: viewModel,
            onStop: onStop,
            onCancel: onCancel
        )
    }
}

// MARK: - Recording Overlay View

struct RecordingOverlayView: View {
    @ObservedObject var audioRecorder: MacAudioRecorder
    @ObservedObject var settings: MacSettings
    @ObservedObject var viewModel: OverlayViewModel
    let onStop: () -> Void
    let onCancel: () -> Void

    @State private var logoScale: CGFloat = 1.0
    @State private var logoGlow: Double = 0.3
    @State private var processingElapsed: TimeInterval = 0

    private let processingTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isProcessing {
                // Processing state - compact view
                processingView
            } else {
                // Recording state - full view
                recordingView
            }
        }
        .padding(20)
        .background(overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 20, x: 0, y: 8)
        .onAppear {
            startLogoAnimation()
        }
        .onReceive(processingTimer) { _ in
            if viewModel.isProcessing {
                processingElapsed = Date().timeIntervalSince(viewModel.processingStartTime)
            }
        }
        .onChange(of: viewModel.isProcessing) { isProcessing in
            if isProcessing {
                processingElapsed = 0
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showToggleCircles)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isProcessing)
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
                // Processing label with time
                HStack(spacing: 8) {
                    Text("PROCESSING")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .tracking(2)

                    Text("(\(formattedProcessingTime))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.7))
                }

                // Animated loading bars
                ProcessingAnimationView()
                    .frame(height: 20)
            }

            Spacer()
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 16) {
            // Top row - Toggle circles (shown when holding hotkey)
            if viewModel.showToggleCircles {
                toggleCirclesRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main recording content
            HStack(spacing: 16) {
                // Left - Pulsing logo
                pulsingLogo

                // Middle - Recording status + Timer + Waveform
                VStack(alignment: .leading, spacing: 8) {
                    // Recording label and timer row
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

                        // Waveform on the right
                        LiveWaveformView(level: audioRecorder.currentLevel, isPastMinimum: audioRecorder.duration >= 0.5)
                            .frame(width: 100, height: 32)
                    }

                    // Active mode indicators
                    activeIndicatorsRow
                }
            }
            .padding(.horizontal, 4)

            // Transcribed partial text
            if !viewModel.liveTranscript.isEmpty {
                transcriptView
            }

            // Bottom - Keyboard shortcuts
            keyboardHintsRow
        }
    }

    // MARK: - Toggle Circles Row

    private var toggleCirclesRow: some View {
        HStack(spacing: 24) {
            // Translation toggle with language picker
            TranslationToggleCircle(
                isEnabled: $viewModel.isTranslationEnabled,
                selectedLanguage: $viewModel.targetLanguage
            )

            // Context picker
            ContextToggleCircle(settings: settings)

            // Power Mode picker
            PowerModeToggleCircle(settings: settings)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Pulsing Logo

    private var pulsingLogo: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(logoGlow), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(logoScale)

            // Logo
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
            if let ctx = settings.activeContext {
                ActiveIndicatorPill(icon: ctx.icon, text: ctx.name, color: .purple, isEmoji: true)
            }

            if let pm = settings.activePowerMode {
                ActiveIndicatorPill(icon: pm.icon, text: pm.name, color: .orange)
            }

            if viewModel.isTranslationEnabled {
                ActiveIndicatorPill(icon: "globe", text: "→ \(viewModel.targetLanguage.displayName)", color: .blue)
            }

            Spacer()
        }
    }

    // MARK: - Transcript View

    private var transcriptView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(viewModel.liveTranscript)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .frame(maxHeight: 80)
        .padding(.horizontal, 4)
    }

    // MARK: - Keyboard Hints Row

    private var keyboardHintsRow: some View {
        HStack(spacing: 16) {
            KeyboardHint(key: "↵", action: "finish")
            KeyboardHint(key: "⌥Space", action: "finish")
            KeyboardHint(key: "Esc", action: "cancel")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    // MARK: - Background

    private var overlayBackground: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            // Subtle gradient overlay
            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Border
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
        if viewModel.isProcessing {
            return "PROCESSING"
        } else if audioRecorder.isRecording {
            return "RECORDING"
        } else {
            return "READY"
        }
    }

    private var statusColor: Color {
        if viewModel.isProcessing {
            return .orange
        } else if audioRecorder.isRecording {
            return .red
        } else {
            return .green
        }
    }

    private var formattedDuration: String {
        let duration = audioRecorder.duration
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

    // MARK: - Actions

    private func cycleContext() {
        let contexts = settings.contexts
        if let current = settings.activeContext,
           let index = contexts.firstIndex(where: { $0.id == current.id }) {
            let nextIndex = (index + 1) % contexts.count
            settings.setActiveContext(contexts[nextIndex])
        } else if let first = contexts.first {
            settings.setActiveContext(first)
        }
    }

    private func cyclePowerMode() {
        let modes = settings.activePowerModes
        if let current = settings.activePowerMode,
           let index = modes.firstIndex(where: { $0.id == current.id }) {
            if index + 1 < modes.count {
                settings.setActivePowerMode(modes[index + 1])
            } else {
                settings.setActivePowerMode(nil) // Turn off
            }
        } else if let first = modes.first {
            settings.setActivePowerMode(first)
        }
    }
}

// MARK: - Language Flag Helper

extension Language {
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .russian: return "🇷🇺"
        case .polish: return "🇵🇱"
        case .arabic: return "🇸🇦"
        case .egyptianArabic: return "🇪🇬"
        }
    }
}

// MARK: - Translation Toggle Circle with Dropdown

struct TranslationToggleCircle: View {
    @Binding var isEnabled: Bool
    @Binding var selectedLanguage: Language

    @State private var isHovering = false

    var body: some View {
        Menu {
            // Toggle translation on/off
            Button(action: { isEnabled.toggle() }) {
                Label(isEnabled ? "Disable Translation" : "Enable Translation",
                      systemImage: isEnabled ? "xmark.circle" : "checkmark.circle")
            }

            Divider()

            // Language options
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

                    // Show flag when enabled, globe when disabled
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

// MARK: - Context Toggle Circle with Dropdown

struct ContextToggleCircle: View {
    @ObservedObject var settings: MacSettings

    @State private var isHovering = false

    private var isActive: Bool { settings.activeContext != nil }
    private var currentIcon: String { settings.activeContext?.icon ?? "person.circle" }
    private var isEmoji: Bool { settings.activeContext?.icon.first?.isEmoji ?? false }

    var body: some View {
        Menu {
            // None option
            Button(action: { settings.setActiveContext(nil) }) {
                HStack {
                    Text("None")
                    Spacer()
                    if settings.activeContext == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Preset contexts
            ForEach(ConversationContext.presets) { context in
                Button(action: { settings.setActiveContext(context) }) {
                    HStack {
                        Text("\(context.icon) \(context.name)")
                        Spacer()
                        if settings.activeContextId == context.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            // Custom contexts
            let customContexts = settings.contexts.filter { !$0.isPreset }
            if !customContexts.isEmpty {
                Divider()
                ForEach(customContexts) { context in
                    Button(action: { settings.setActiveContext(context) }) {
                        HStack {
                            Text("\(context.icon) \(context.name)")
                            Spacer()
                            if settings.activeContextId == context.id {
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

                    // Show context icon (larger when active)
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

                Text(settings.activeContext?.name ?? "Context")
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

// MARK: - Power Mode Toggle Circle with Dropdown

struct PowerModeToggleCircle: View {
    @ObservedObject var settings: MacSettings

    @State private var isHovering = false

    private var isActive: Bool { settings.activePowerMode != nil }
    private var currentIcon: String { settings.activePowerMode?.icon ?? "bolt.fill" }

    var body: some View {
        Menu {
            // None option
            Button(action: { settings.setActivePowerMode(nil) }) {
                HStack {
                    Text("None")
                    Spacer()
                    if settings.activePowerMode == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            if !settings.activePowerModes.isEmpty {
                Divider()

                ForEach(settings.activePowerModes) { powerMode in
                    Button(action: { settings.setActivePowerMode(powerMode) }) {
                        HStack {
                            Label(powerMode.name, systemImage: powerMode.icon)
                            Spacer()
                            if settings.activePowerModeId == powerMode.id {
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
                        .fill(isActive ? Color.orange.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Circle()
                        .strokeBorder(isActive ? Color.orange : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 48, height: 48)

                    // Show power mode icon (larger when active)
                    Image(systemName: currentIcon)
                        .font(.system(size: isActive ? 22 : 18, weight: .medium))
                        .foregroundStyle(isActive ? .orange : .white.opacity(0.8))

                    Text("P")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .offset(x: 18, y: -18)
                }

                Text(settings.activePowerMode?.name ?? "Power")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isActive ? .orange : .secondary)
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

// MARK: - Active Indicator Pill

struct ActiveIndicatorPill: View {
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

struct KeyboardHint: View {
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

// MARK: - Live Waveform View

struct LiveWaveformView: View {
    let level: Float
    var isPastMinimum: Bool = false

    private let barCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    index: index,
                    level: level,
                    isPastMinimum: isPastMinimum
                )
            }
        }
    }
}

struct WaveformBar: View {
    let index: Int
    let level: Float
    var isPastMinimum: Bool = false

    @State private var animatedHeight: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isPastMinimum
                        ? [Color.green, Color.green.opacity(0.6)]
                        : [Color.red, Color.orange],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: animatedHeight)
            .onChange(of: level) { newLevel in
                updateHeight(for: newLevel)
            }
            .onAppear {
                // Initial random height for visual interest
                animatedHeight = CGFloat.random(in: 4...12)
                // Start animation
                updateHeight(for: level)
            }
    }

    private func updateHeight(for level: Float) {
        // Create variation based on index for organic look
        let baseHeight = CGFloat(level) * 28
        let variation = sin(Double(index) * 0.8 + Date().timeIntervalSince1970 * 10) * 6
        let targetHeight = max(4, min(32, baseHeight + CGFloat(variation)))

        withAnimation(.easeInOut(duration: 0.1)) {
            animatedHeight = targetHeight
        }
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Processing Animation View

struct ProcessingAnimationView: View {
    @State private var animationPhase: Double = 0

    private let barCount = 8
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                ProcessingBar(index: index, phase: animationPhase)
            }
        }
        .onReceive(timer) { _ in
            animationPhase += 0.15
        }
    }
}

struct ProcessingBar: View {
    let index: Int
    let phase: Double

    var body: some View {
        let normalizedPhase = (phase + Double(index) * 0.3).truncatingRemainder(dividingBy: 2 * .pi)
        let heightFactor = (sin(normalizedPhase) + 1) / 2 // 0 to 1
        let height = 4 + heightFactor * 16 // 4 to 20

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

// MARK: - Character Extension

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

// MARK: - Preview

#Preview("Recording") {
    let viewModel = OverlayViewModel()
    viewModel.showToggleCircles = true
    viewModel.liveTranscript = "Hello, this is a test transcription..."

    return RecordingOverlayView(
        audioRecorder: MacAudioRecorder(),
        settings: MacSettings.shared,
        viewModel: viewModel,
        onStop: {},
        onCancel: {}
    )
    .frame(width: 380, height: 300)
    .background(Color.gray.opacity(0.3))
}

#Preview("Minimal") {
    let viewModel = OverlayViewModel()
    viewModel.showToggleCircles = false

    return RecordingOverlayView(
        audioRecorder: MacAudioRecorder(),
        settings: MacSettings.shared,
        viewModel: viewModel,
        onStop: {},
        onCancel: {}
    )
    .frame(width: 380, height: 180)
    .background(Color.gray.opacity(0.3))
}

#Preview("Processing") {
    let viewModel = OverlayViewModel()
    viewModel.isProcessing = true

    return RecordingOverlayView(
        audioRecorder: MacAudioRecorder(),
        settings: MacSettings.shared,
        viewModel: viewModel,
        onStop: {},
        onCancel: {}
    )
    .frame(width: 380, height: 120)
    .background(Color.gray.opacity(0.3))
}
