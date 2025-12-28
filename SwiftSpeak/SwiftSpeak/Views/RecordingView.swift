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
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme

    // Use real orchestrator for actual transcription
    @StateObject private var orchestrator = TranscriptionOrchestrator()

    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var selectedWaveform: WaveformType = .bars
    @State private var showingContextPicker = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ZStack {
            // Blurred background
            backgroundColor.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    if orchestrator.state == .recording {
                        stopRecording()
                    }
                }

            // Recording card
            RecordingCard(
                state: orchestrator.state,
                duration: orchestrator.recordingDuration,
                mode: settings.selectedMode,
                isTranslationEnabled: translateAfterRecording,
                targetLanguage: settings.selectedTargetLanguage,
                transcriptionProvider: settings.selectedTranscriptionProvider,
                modeProvider: settings.selectedPowerModeProvider,
                translationProvider: settings.selectedTranslationProvider,
                waveformType: selectedWaveform,
                audioLevels: orchestrator.audioLevels,
                colorScheme: colorScheme,
                activeContext: settings.activeContext,
                onTap: handleCardTap,
                onCancel: cancelRecording,
                onChangeContext: {
                    HapticManager.selection()
                    showingContextPicker = true
                }
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .sheet(isPresented: $showingContextPicker) {
            RecordingContextPicker(
                contexts: settings.contexts,
                activeContextId: settings.activeContextId,
                onSelect: { context in
                    settings.setActiveContext(context)
                    showingContextPicker = false
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            // Configure orchestrator with current settings
            orchestrator.mode = settings.selectedMode
            orchestrator.customTemplate = settings.selectedCustomTemplate
            orchestrator.translateEnabled = translateAfterRecording
            orchestrator.targetLanguage = settings.selectedTargetLanguage

            // Clear the selected custom template after configuring orchestrator
            settings.selectedCustomTemplate = nil

            // Randomly select a waveform type
            selectedWaveform = WaveformType.allCases.randomElement() ?? .bars
            showCard()
            startRecording()
        }
        .onDisappear {
            orchestrator.cancel()
        }
        // Phase 10f: Enable on-device translation via Apple Translation framework
        .localTranslationHandler()
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

        Task {
            await orchestrator.startRecording()
        }
    }

    private func stopRecording() {
        HapticManager.mediumTap()

        Task {
            await orchestrator.stopRecording()

            // Check if completed successfully
            if orchestrator.isComplete {
                HapticManager.success()

                // Auto-dismiss after showing result (if enabled in settings)
                if settings.autoReturnEnabled {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    hideCard {
                        isPresented = false
                    }
                }
            } else if orchestrator.hasError {
                HapticManager.error()
            }
        }
    }

    private func cancelRecording() {
        orchestrator.cancel()
        hideCard {
            isPresented = false
        }
    }

    private func handleCardTap() {
        switch orchestrator.state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .complete:
            hideCard {
                isPresented = false
            }
        case .error:
            // Tap to retry on error
            Task {
                await orchestrator.retry()
            }
        default:
            break
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

                // Mode badge (if not raw)
                if mode != .raw {
                    ModeBadge(icon: mode.icon, text: mode.displayName)
                }

                // Translation badge (if enabled)
                if isTranslationEnabled {
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

            // Duration (only while recording)
            if case .recording = state {
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
            return "Tap to start"
        case .recording:
            if isTranslationEnabled && mode != .raw {
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
            if isTranslationEnabled && mode != .raw {
                return "Processing transcription,\ntranslation & \(mode.displayName) mode..."
            } else if isTranslationEnabled {
                return "Processing transcription\n& translation..."
            } else if mode != .raw {
                return "Processing transcription\n& \(mode.displayName) mode..."
            }
            return "Processing transcription..."
        case .formatting:
            return "Applying \(mode.displayName) mode..."
        case .translating:
            return "Translating to \(targetLanguage.displayName)..."
        case .complete:
            return "Done!"
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
