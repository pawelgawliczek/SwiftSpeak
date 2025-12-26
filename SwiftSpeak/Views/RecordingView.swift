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

    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var selectedWaveform: WaveformType = .bars

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ZStack {
            // Blurred background
            backgroundColor.opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    if recordingState == .recording {
                        stopRecording()
                    }
                }

            // Recording card
            RecordingCard(
                state: recordingState,
                duration: recordingDuration,
                mode: settings.selectedMode,
                isTranslationEnabled: translateAfterRecording,
                targetLanguage: settings.selectedTargetLanguage,
                sttProvider: settings.selectedProvider,
                modeProvider: settings.selectedModeProvider,
                translationProvider: settings.selectedTranslationProvider,
                waveformType: selectedWaveform,
                colorScheme: colorScheme,
                onTap: handleCardTap,
                onCancel: cancelRecording
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            // Randomly select a waveform type
            selectedWaveform = WaveformType.allCases.randomElement() ?? .bars
            showCard()
            startRecording()
        }
        .onDisappear {
            timer?.invalidate()
        }
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

        recordingState = .recording
        recordingDuration = 0

        // Start timer for duration tracking
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        HapticManager.mediumTap()

        // Transition to processing
        withAnimation(AppTheme.quickSpring) {
            recordingState = .processing
        }

        // Simulate transcription (mock)
        simulateTranscription()
    }

    private func simulateTranscription() {
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Transition to formatting if mode is not raw
            if settings.selectedMode != .raw {
                withAnimation(AppTheme.quickSpring) {
                    recordingState = .formatting
                }

                // Simulate formatting delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    completeTranscription()
                }
            } else {
                completeTranscription()
            }
        }
    }

    private func completeTranscription() {
        // Mock transcription result
        let mockText = "This is a mock transcription. In the real app, this would be the text transcribed from your voice using OpenAI Whisper."

        HapticManager.success()

        withAnimation(AppTheme.quickSpring) {
            recordingState = .complete(mockText)
        }

        // Save to history (mock)
        let record = TranscriptionRecord(
            text: mockText,
            mode: settings.selectedMode,
            provider: settings.selectedProvider,
            duration: recordingDuration
        )
        settings.addTranscription(record)

        // Auto-dismiss after showing result
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            hideCard {
                isPresented = false
            }
        }
    }

    private func cancelRecording() {
        timer?.invalidate()
        hideCard {
            isPresented = false
        }
    }

    private func handleCardTap() {
        switch recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .complete:
            hideCard {
                isPresented = false
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
    let sttProvider: STTProvider
    let modeProvider: LLMProvider
    let translationProvider: LLMProvider
    let waveformType: WaveformType
    let colorScheme: ColorScheme
    let onTap: () -> Void
    let onCancel: () -> Void

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

                case .processing, .formatting:
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
                    Text("Transcription: \(sttProvider.shortName)")
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
            if isTranslationEnabled {
                return "Applying \(mode.displayName) mode & translation..."
            }
            return "Applying \(mode.displayName) mode..."
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
            WaveformView(isActive: isActive)
        case .circular:
            CircularWaveformView(isActive: isActive)
                .frame(width: 60, height: 60)
        case .linear:
            LinearWaveView()
                .frame(width: 200)
        case .mirrored:
            MirroredBarWaveformView(isActive: isActive)
                .frame(width: 200)
        case .blob:
            BlobWaveformView(isActive: isActive)
                .frame(width: 80, height: 60)
        case .soundBars:
            SoundBarsWaveformView(barCount: 7, isActive: isActive)
                .frame(width: 80)
        case .spectrum:
            SpectrumWaveformView(isActive: isActive)
                .frame(width: 200)
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
