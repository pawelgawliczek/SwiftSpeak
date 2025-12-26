//
//  RecordingView.swift
//  SwiftSpeak
//
//  Full-screen recording interface with waveform animation
//

import SwiftUI

struct RecordingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var settings: SharedSettings

    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0

    var body: some View {
        ZStack {
            // Blurred background
            AppTheme.darkBase.opacity(0.95)
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
                onTap: handleCardTap,
                onCancel: cancelRecording
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
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
    let onTap: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Mode badge
            ModeBadge(icon: mode.icon, text: mode.displayName)

            // Waveform or status indicator
            ZStack {
                switch state {
                case .idle, .recording:
                    WaveformView(isActive: state == .recording)
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
            Text(state.statusText)
                .font(.headline)
                .foregroundStyle(.primary)

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
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(width: 280)
        .glassBackground(cornerRadius: AppTheme.cornerRadiusXL)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
}

#Preview {
    RecordingView(isPresented: .constant(true))
        .environmentObject(SharedSettings.shared)
}
