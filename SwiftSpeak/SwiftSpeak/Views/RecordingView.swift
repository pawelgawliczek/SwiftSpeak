//
//  RecordingView.swift
//  SwiftSpeak
//
//  Full-screen recording interface with waveform animation
//

import SwiftUI

// Enum for available waveform types
enum WaveformType: CaseIterable {
    case bars
    case circular
    case linear
    case mirrored
    case blob
    case soundBars
    case spectrum
}

struct RecordingView: View {
    @Binding var isPresented: Bool
    var translateAfterRecording: Bool = false
    var editModeOriginalText: String? = nil  // Phase 12: Edit mode
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) private var openURL

    // Use real orchestrator for actual transcription
    @StateObject private var orchestrator = TranscriptionOrchestrator()
    @StateObject private var streamingOrchestrator = StreamingTranscriptionOrchestrator()
    @StateObject private var swiftLinkManager = SwiftLinkSessionManager.shared

    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var selectedWaveform: WaveformType = .bars
    @State private var showingContextPicker = false
    @State private var showingSwiftLinkQuickStart = false
    @State private var showingOriginalText = false  // Phase 12: Toggle for original text preview

    /// Captured streaming mode - set once on appear to prevent mid-session switching
    /// Using Optional to prevent any rendering until mode is determined
    @State private var isStreamingSession: Bool? = nil

    /// Current streaming transcript for display
    private var streamingTranscript: String {
        if !streamingOrchestrator.partialTranscript.isEmpty {
            return streamingOrchestrator.partialTranscript
        }
        return streamingOrchestrator.fullTranscript
    }

    /// Phase 12: Whether we're in edit mode (modifying existing text)
    private var isEditMode: Bool {
        editModeOriginalText != nil && !(editModeOriginalText?.isEmpty ?? true)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    /// Convert streaming state to RecordingState for RecordingCard compatibility
    private var streamingStateToRecordingState: RecordingState {
        switch streamingOrchestrator.state {
        case .idle: return .idle
        case .connecting: return .processing
        case .streaming: return .recording
        case .processing: return .formatting
        case .complete: return .complete(streamingOrchestrator.fullTranscript)
        case .error: return .error(streamingOrchestrator.error?.errorDescription ?? "Unknown error")
        }
    }

    /// Get audio levels for streaming mode
    private var streamingAudioLevels: [Float] {
        let level = streamingOrchestrator.audioLevel
        return (0..<12).map { index in
            let variance = Float.random(in: -0.15...0.15)
            let phase = sin(Float(index) * 0.5)
            return max(0, min(1, level + variance * phase * level))
        }
    }

    /// Safe accessor for streaming mode - returns false until mode is determined
    private var isStreaming: Bool {
        isStreamingSession ?? false
    }

    var body: some View {
        ZStack {
            // Blurred background
            backgroundColor.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    // Handle background tap for both streaming and non-streaming modes
                    guard isStreamingSession != nil else { return }
                    if isStreaming {
                        if streamingOrchestrator.state == .streaming {
                            appLog("Background tap - stopping streaming", category: "Streaming")
                            stopRecording()
                        }
                    } else {
                        if orchestrator.state == .recording {
                            appLog("Background tap - stopping recording", category: "Recording")
                            stopRecording()
                        }
                    }
                }

            // Only show content after streaming mode is determined
            if isStreamingSession != nil {
                VStack(spacing: 0) {
                    Spacer()

                    // Recording card
                    RecordingCard(
                        state: isStreaming ? streamingStateToRecordingState : orchestrator.state,
                        duration: isStreaming ? 0 : orchestrator.recordingDuration,
                        mode: settings.selectedMode,
                        isTranslationEnabled: translateAfterRecording,
                        targetLanguage: settings.selectedTargetLanguage,
                        transcriptionProvider: settings.selectedTranscriptionProvider,
                        modeProvider: settings.selectedPowerModeProvider,
                        translationProvider: settings.selectedTranslationProvider,
                        waveformType: selectedWaveform,
                        audioLevels: isStreaming ? streamingAudioLevels : orchestrator.audioLevels,
                        colorScheme: colorScheme,
                        activeContext: settings.activeContext,
                        isEditMode: isEditMode,
                        editOriginalText: editModeOriginalText,
                        showingOriginalText: $showingOriginalText,
                        isStreamingMode: isStreaming,
                        streamingTranscript: isStreaming ? streamingTranscript : nil,
                        onTap: handleCardTap,
                        onCancel: cancelRecording,
                        onChangeContext: {
                            HapticManager.selection()
                            showingContextPicker = true
                        }
                    )
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)

                    Spacer()

                    // SwiftLink quick start banner (only when no session active)
                    if !swiftLinkManager.isSessionActive {
                        swiftLinkBanner
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showingContextPicker) {
            RecordingContextPicker(
                contexts: settings.contexts,
                activeContextId: settings.activeContextId,
                onSelect: { context in
                    settings.setActiveContext(context)
                    orchestrator.activeContext = context  // Update orchestrator too
                    showingContextPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSwiftLinkQuickStart) {
            SwiftLinkQuickStartSheet(onSessionStarted: { urlScheme in
                // Open the target app after session starts
                if let scheme = urlScheme, let url = URL(string: scheme) {
                    openURL(url)
                }
            })
            .environmentObject(settings)
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            // Reset both orchestrators for fresh start
            orchestrator.reset()
            streamingOrchestrator.reset()

            // Refresh context from UserDefaults in case keyboard changed it
            settings.refreshActiveContextFromDefaults()

            // Capture streaming mode ONCE at start - prevents mode switching mid-session
            let shouldUseStreaming = settings.transcriptionStreamingEnabled && streamingOrchestrator.isStreamingAvailable
            isStreamingSession = shouldUseStreaming

            // Log streaming mode state
            appLog("RecordingView onAppear - streamingEnabled: \(settings.transcriptionStreamingEnabled), isStreamingAvailable: \(streamingOrchestrator.isStreamingAvailable), isStreamingSession: \(shouldUseStreaming)", category: "Streaming")
            appLog("Selected provider: \(settings.selectedTranscriptionProvider.displayName)", category: "Streaming")

            // Configure orchestrator with current settings (for non-streaming mode)
            if !shouldUseStreaming {
                orchestrator.mode = settings.selectedMode
                orchestrator.customTemplate = settings.selectedCustomTemplate
                orchestrator.translateEnabled = translateAfterRecording
                orchestrator.targetLanguage = settings.selectedTargetLanguage
                orchestrator.sourceLanguage = settings.selectedDictationLanguage

                // Apply selected context with debug logging
                let contextFromSettings = settings.activeContext
                orchestrator.activeContext = contextFromSettings
                appLog("RecordingView.onAppear: activeContext='\(contextFromSettings?.name ?? "nil")'", category: "Context", level: .debug)

                // Phase 12: Configure edit mode if active
                orchestrator.editOriginalText = editModeOriginalText
            } else {
                // Streaming mode: log context state
                appLog("RecordingView.onAppear (streaming): activeContext='\(settings.activeContext?.name ?? "nil")'", category: "Context", level: .debug)
            }

            // Clear the selected custom template after configuring orchestrator
            settings.selectedCustomTemplate = nil

            // Randomly select a waveform type
            selectedWaveform = WaveformType.allCases.randomElement() ?? .bars

            // Reset card animation state
            cardScale = 0.8
            cardOpacity = 0

            showCard()
            startRecording()
        }
        .onDisappear {
            appLog("RecordingView onDisappear - cancelling orchestrators", category: "Streaming")
            if isStreaming {
                streamingOrchestrator.cancel()
            } else {
                orchestrator.cancel()
            }
        }
        // Phase 10f: Enable on-device translation via Apple Translation framework
        .localTranslationHandlerIfAvailable()
    }

    private func showCard() {
        withAnimation(AppTheme.smoothSpring) {
            cardScale = 1.0
            cardOpacity = 1.0
        }
    }

    private func hideCard(completion: @escaping () -> Void) {
        withAnimation(AppTheme.quickSpring) {
            cardScale = 0.8
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion()
        }
    }

    private func startRecording() {
        HapticManager.lightTap()
        appLog("startRecording called - isStreaming: \(isStreaming)", category: "Streaming")

        Task {
            if isStreaming {
                appLog("Starting streaming transcription...", category: "Streaming")
                appLog("Streaming orchestrator state before: \(String(describing: streamingOrchestrator.state))", category: "Streaming")
                do {
                    try await streamingOrchestrator.startStreaming()
                    appLog("Streaming started successfully, state: \(String(describing: streamingOrchestrator.state))", category: "Streaming")
                } catch {
                    appLog("Streaming failed to start: \(error.localizedDescription)", category: "Streaming", level: .error)
                    HapticManager.error()
                }
            } else {
                appLog("Starting non-streaming recording...", category: "Recording")
                await orchestrator.startRecording()
                appLog("Non-streaming recording started, state: \(String(describing: orchestrator.state))", category: "Recording")
            }
        }
    }

    private func stopRecording() {
        HapticManager.mediumTap()
        appLog("stopRecording called - isStreaming: \(isStreaming)", category: "Streaming")

        Task {
            if isStreaming {
                appLog("Stopping streaming, current state: \(String(describing: streamingOrchestrator.state))", category: "Streaming")
                let result = await streamingOrchestrator.stopStreaming()
                appLog("Streaming stopped, result: \(result != nil ? "\(result!.count) chars" : "nil")", category: "Streaming")
                if let text = result {
                    HapticManager.success()
                    // Copy to clipboard and save to history
                    UIPasteboard.general.string = text
                    settings.lastTranscription = text
                    appLog("Copied to clipboard and saved lastTranscription", category: "Streaming")

                    // Calculate cost for streaming transcription
                    let costCalculator = CostCalculator()
                    let transcriptionProvider = settings.selectedTranscriptionProvider
                    let transcriptionConfig = settings.selectedTranscriptionProviderConfig
                    let transcriptionModel = transcriptionConfig?.transcriptionModel ?? transcriptionProvider.defaultSTTModel ?? "streaming"

                    let costBreakdown = costCalculator.calculateCostBreakdown(
                        transcriptionProvider: transcriptionProvider,
                        transcriptionModel: transcriptionModel,
                        formattingProvider: settings.selectedMode != .raw ? settings.selectedTranslationProvider : nil,
                        formattingModel: settings.selectedMode != .raw ? settings.selectedTranslationProvider.defaultLLMModel : nil,
                        translationProvider: settings.isTranslationEnabled ? settings.selectedTranslationProvider : nil,
                        translationModel: settings.isTranslationEnabled ? settings.selectedTranslationProvider.defaultLLMModel : nil,
                        durationSeconds: 0,  // Streaming doesn't track duration the same way
                        textLength: text.count,
                        text: text
                    )

                    // Save to history
                    let currentContext = settings.activeContext

                    let record = TranscriptionRecord(
                        id: UUID(),
                        rawTranscribedText: streamingOrchestrator.fullTranscript,
                        text: text,
                        mode: settings.selectedMode,
                        provider: settings.selectedTranscriptionProvider,
                        timestamp: Date(),
                        duration: 0,  // Streaming doesn't track duration the same way
                        translated: settings.isTranslationEnabled,
                        targetLanguage: settings.isTranslationEnabled ? settings.selectedTargetLanguage : nil,
                        powerModeId: nil,
                        powerModeName: nil,
                        contextId: currentContext?.id,
                        contextName: currentContext?.name,
                        contextIcon: currentContext?.icon,
                        estimatedCost: costBreakdown.total,
                        costBreakdown: costBreakdown,
                        processingMetadata: nil
                    )
                    settings.addTranscription(record)
                    appLog("Saved to history", category: "Streaming")

                    // Auto-dismiss after short delay to show completion
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    hideCard {
                        isPresented = false
                    }
                } else if streamingOrchestrator.error != nil {
                    appLog("Streaming error: \(streamingOrchestrator.error?.errorDescription ?? "unknown")", category: "Streaming", level: .error)
                    HapticManager.error()
                } else {
                    appLog("Streaming returned nil result but no error", category: "Streaming", level: .warning)
                    // No result - dismiss anyway
                    hideCard {
                        isPresented = false
                    }
                }
            } else {
                await orchestrator.stopRecording()

                // Check if completed successfully
                if orchestrator.isComplete {
                    HapticManager.success()
                    // Stay on completion screen - user uses Return button to go back
                } else if orchestrator.hasError {
                    HapticManager.error()
                }
            }
        }
    }

    private func cancelRecording() {
        if isStreaming {
            streamingOrchestrator.cancel()
        } else {
            orchestrator.cancel()
        }
        hideCard {
            isPresented = false
        }
    }

    private func handleCardTap() {
        appLog("handleCardTap - isStreaming: \(isStreaming)", category: "Streaming")

        if isStreaming {
            appLog("Streaming state: \(String(describing: streamingOrchestrator.state))", category: "Streaming")
            switch streamingOrchestrator.state {
            case .idle:
                appLog("Streaming idle -> starting recording", category: "Streaming")
                startRecording()
            case .connecting:
                appLog("Streaming connecting -> ignoring tap (wait for connection)", category: "Streaming")
                // Do nothing while connecting
                break
            case .streaming:
                appLog("Streaming active -> stopping recording", category: "Streaming")
                stopRecording()
            case .processing:
                appLog("Streaming processing -> ignoring tap (wait for completion)", category: "Streaming")
                // Do nothing while processing
                break
            case .complete:
                appLog("Streaming complete -> hiding card", category: "Streaming")
                hideCard {
                    isPresented = false
                }
            case .error:
                appLog("Streaming error -> retrying", category: "Streaming")
                // Tap to retry on error
                streamingOrchestrator.reset()
                startRecording()
            }
        } else {
            appLog("Non-streaming state: \(String(describing: orchestrator.state))", category: "Recording")
            switch orchestrator.state {
            case .idle:
                appLog("Idle -> starting recording", category: "Recording")
                startRecording()
            case .recording:
                appLog("Recording -> stopping recording", category: "Recording")
                stopRecording()
            case .complete:
                appLog("Complete -> hiding card", category: "Recording")
                hideCard {
                    isPresented = false
                }
            case .error:
                appLog("Error -> retrying", category: "Recording")
                // Tap to retry on error
                Task {
                    await orchestrator.retry()
                }
            default:
                appLog("Other state (\(String(describing: orchestrator.state))) -> ignoring tap", category: "Recording")
                break
            }
        }
    }

    // MARK: - SwiftLink Quick Start Banner

    private var swiftLinkBanner: some View {
        Button(action: {
            HapticManager.selection()
            showingSwiftLinkQuickStart = true
        }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "link.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable SwiftLink")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Dictate without leaving apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - iOS Version Compatibility

extension View {
    /// Applies localTranslationHandler only on iOS 18.0+
    /// On older iOS versions, the view is returned unchanged (Apple Translation unavailable)
    @ViewBuilder
    func localTranslationHandlerIfAvailable() -> some View {
        if #available(iOS 18.0, *) {
            self.localTranslationHandler()
        } else {
            self
        }
    }
}

// MARK: - Recording Card
struct RecordingCard: View {
    let state: RecordingState
    let duration: TimeInterval
    let mode: FormattingMode
    let isTranslationEnabled: Bool
    let targetLanguage: Language
    let transcriptionProvider: AIProvider
    let modeProvider: AIProvider
    let translationProvider: AIProvider
    let waveformType: WaveformType
    let audioLevels: [Float]
    let colorScheme: ColorScheme
    let activeContext: ConversationContext?
    // Phase 12: Edit mode
    var isEditMode: Bool = false
    var editOriginalText: String? = nil
    @Binding var showingOriginalText: Bool
    /// Whether this is a streaming transcription session
    var isStreamingMode: Bool = false
    /// Live streaming transcript (shown while recording in streaming mode)
    var streamingTranscript: String? = nil
    let onTap: () -> Void
    let onCancel: () -> Void
    let onChangeContext: () -> Void

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white
    }

    private var cardShadow: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.15)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Status badges row
            HStack(spacing: 8) {
                // Streaming mode badge
                if isStreamingMode {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.9))
                    .clipShape(Capsule())
                }

                // Phase 12: Edit mode badge
                if isEditMode {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.semibold))
                        Text("Edit")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .clipShape(Capsule())
                }

                // Context badge (if active)
                if let context = activeContext {
                    Button(action: onChangeContext) {
                        HStack(spacing: 4) {
                            Text(context.icon)
                                .font(.subheadline)
                            Text(context.name)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(context.color.color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                // Mode badge (if not raw and not in edit mode)
                if mode != .raw && !isEditMode {
                    ModeBadge(icon: mode.icon, text: mode.displayName)
                }

                // Translation badge (if enabled and not in edit mode)
                if isTranslationEnabled && !isEditMode {
                    HStack(spacing: 4) {
                        Text(targetLanguage.flag)
                            .font(.subheadline)
                        Text(targetLanguage.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // Phase 12: Original text preview (only in edit mode, while recording)
            if isEditMode, let originalText = editOriginalText, case .recording = state {
                VStack(spacing: 8) {
                    Button(action: {
                        withAnimation(AppTheme.quickSpring) {
                            showingOriginalText.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("Original text")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)

                            Image(systemName: showingOriginalText ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showingOriginalText {
                        Text(originalText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }

            // Waveform or status indicator
            ZStack {
                switch state {
                case .idle, .recording:
                    waveformForType(waveformType, isActive: state == .recording)
                        .frame(height: 60)

                case .processing, .formatting, .translating:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accent))
                        .scaleEffect(1.5)

                case .retrying:
                    // Retry spinner with orange tint
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(1.5)

                case .complete:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))

                case .error:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 60)

            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Live streaming transcript (only while recording with streaming enabled)
            if case .recording = state, let transcript = streamingTranscript, !transcript.isEmpty {
                ScrollView {
                    Text(transcript)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxHeight: 80)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Duration (only while recording, not in streaming mode)
            if case .recording = state, streamingTranscript == nil {
                Text(formattedDuration)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }

            // Result text preview (only when complete)
            if case .complete(let text) = state {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Return instructions
                VStack(spacing: 16) {
                    // Arrow pointing to top-left status bar
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tap \"← Back\" in status bar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Text copied & ready to paste")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Stay in app button
                    Button(action: {
                        HapticManager.lightTap()
                        onTap() // Dismiss overlay, stay in SwiftSpeak
                    }) {
                        Text("Stay in SwiftSpeak")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            }

            // Action hint
            if case .recording = state {
                Text("Tap to finish")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Provider info (small gray text)
            if case .recording = state {
                VStack(spacing: 2) {
                    Text("Transcription: \(transcriptionProvider.shortName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if mode != .raw {
                        Text("Mode: \(modeProvider.shortName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if isTranslationEnabled {
                        Text("Translation: \(translationProvider.shortName)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(width: 280)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL, style: .continuous))
        .shadow(color: cardShadow, radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        // Cancel button
        .overlay(alignment: .topTrailing) {
            if case .recording = state {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(12)
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    private var statusText: String {
        switch state {
        case .idle:
            return isEditMode ? "Describe your changes" : "Tap to start"
        case .recording:
            // Phase 12: Edit mode has special status
            if isEditMode {
                return "Describe your changes..."
            } else if isTranslationEnabled && mode != .raw {
                // Translate button + Mode selected
                return "Transcribing & Translating\nwith \(mode.displayName) mode"
            } else if isTranslationEnabled {
                // Translate button + Raw mode
                return "Transcribing & Translating"
            } else if mode != .raw {
                // Transcribe button + Mode selected
                return "Transcribing\nwith \(mode.displayName) mode"
            } else {
                // Transcribe button + Raw mode
                return "Transcribing"
            }
        case .processing:
            // Phase 12: Edit mode processing status
            if isEditMode {
                return "Transcribing instructions..."
            } else if isTranslationEnabled && mode != .raw {
                return "Processing transcription,\ntranslation & \(mode.displayName) mode..."
            } else if isTranslationEnabled {
                return "Processing transcription\n& translation..."
            } else if mode != .raw {
                return "Processing transcription\n& \(mode.displayName) mode..."
            }
            return "Processing transcription..."
        case .formatting:
            // Phase 12: Edit mode formatting status
            if isEditMode {
                return "Applying your edits..."
            }
            return "Applying \(mode.displayName) mode..."
        case .translating:
            return "Translating to \(targetLanguage.displayName)..."
        case .retrying(let attempt, let maxAttempts, let reason):
            return "Retrying (\(attempt)/\(maxAttempts))...\n\(reason)"
        case .complete:
            return isEditMode ? "Text edited!" : "Done!"
        case .error(let message):
            return message
        }
    }

    @ViewBuilder
    private func waveformForType(_ type: WaveformType, isActive: Bool) -> some View {
        switch type {
        case .bars:
            WaveformView(isActive: isActive, audioLevels: audioLevels)
        case .circular:
            CircularWaveformView(isActive: isActive, audioLevels: audioLevels)
                .frame(width: 60, height: 60)
        case .linear:
            LinearWaveView(audioLevels: audioLevels)
                .frame(width: 200)
        case .mirrored:
            MirroredBarWaveformView(isActive: isActive, audioLevels: audioLevels)
                .frame(width: 200)
        case .blob:
            BlobWaveformView(isActive: isActive, audioLevels: audioLevels)
                .frame(width: 80, height: 60)
        case .soundBars:
            SoundBarsWaveformView(barCount: 7, isActive: isActive, audioLevels: audioLevels)
                .frame(width: 80)
        case .spectrum:
            SpectrumWaveformView(isActive: isActive, audioLevels: audioLevels)
                .frame(width: 200)
        }
    }
}

// MARK: - Recording Context Picker

struct RecordingContextPicker: View {
    let contexts: [ConversationContext]
    let activeContextId: UUID?
    let onSelect: (ConversationContext?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // No Context option
                Button(action: { onSelect(nil) }) {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 40)

                        Text("No Context")
                            .foregroundStyle(.primary)

                        Spacer()

                        if activeContextId == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
                .listRowBackground(Color.primary.opacity(0.05))

                // Context options
                ForEach(contexts) { context in
                    Button(action: { onSelect(context) }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(context.color.color.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Text(context.icon)
                                    .font(.title3)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(context.name)
                                    .foregroundStyle(.primary)

                                if !context.description.isEmpty {
                                    Text(context.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if activeContextId == context.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(context.color.color)
                            }
                        }
                    }
                    .listRowBackground(Color.primary.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.darkBase)
            .navigationTitle("Select Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview("Dark") {
    RecordingView(isPresented: .constant(true))
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    RecordingView(isPresented: .constant(true))
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.light)
}
