//
//  RecordingBar.swift
//  SwiftSpeakKeyboard
//
//  Transforms SwiftSpeak bar during recording to show status, waveform, and streaming preview
//

import SwiftUI

struct RecordingBar: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onStop: () -> Void

    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?

    private var displayStatus: RecordingStatus {
        if viewModel.isSwiftLinkRecording {
            return .recording
        } else if viewModel.processingStatus.currentStep == "transcribing" ||
                  viewModel.processingStatus.currentStep == "formatting" ||
                  viewModel.processingStatus.currentStep == "translating" ||
                  viewModel.swiftLinkProcessingStatus == "processing" {
            return .processing
        } else if viewModel.processingStatus.currentStep == "complete" {
            return .complete
        } else {
            return .idle
        }
    }

    private var previewText: String {
        // Show streaming transcript if available
        if viewModel.isSwiftLinkStreaming, !viewModel.swiftLinkStreamingTranscript.isEmpty {
            return viewModel.swiftLinkStreamingTranscript
        }
        // Show processing status text
        if !viewModel.processingStatus.displayText.isEmpty {
            return viewModel.processingStatus.displayText
        }
        return ""
    }

    var body: some View {
        HStack(spacing: 8) {
            // Recording indicator with timer
            RecordingIndicator(
                status: displayStatus,
                duration: recordingDuration
            )

            // Waveform or spinner
            if displayStatus == .recording {
                MiniWaveform(isActive: true)
                    .frame(width: 60, height: 24)
            } else if displayStatus == .processing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.7)
            } else if displayStatus == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.green)
            }

            // Streaming preview text
            if !previewText.isEmpty {
                Text(previewText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            // Stop button
            if displayStatus == .recording || displayStatus == .processing {
                StopButton(action: onStop)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.15))
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var statusColor: Color {
        switch displayStatus {
        case .recording: return .red
        case .processing: return .blue
        case .complete: return .green
        case .idle: return .gray
        }
    }

    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Recording Status
private enum RecordingStatus {
    case idle
    case recording
    case processing
    case complete
}

// MARK: - Recording Indicator
private struct RecordingIndicator: View {
    let status: RecordingStatus
    let duration: TimeInterval

    @State private var pulseScale: CGFloat = 1.0

    private var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 6) {
            // Pulsing dot
            if status == .recording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseScale = 1.3
                        }
                    }
                    .onDisappear {
                        pulseScale = 1.0
                    }
            }

            // Timer
            Text(durationString)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
        }
    }
}

// MARK: - Mini Waveform
private struct MiniWaveform: View {
    let isActive: Bool

    @State private var heights: [CGFloat] = []
    @State private var timer: Timer?

    private let barCount = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [KeyboardTheme.accent, KeyboardTheme.accent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: heights.indices.contains(index) ? heights[index] : 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: heights)
            }
        }
        .onAppear {
            heights = Array(repeating: 4, count: barCount)
            if isActive {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            heights = (0..<barCount).map { _ in CGFloat.random(in: 4...20) }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        heights = Array(repeating: 4, count: barCount)
    }
}

// MARK: - Stop Button
private struct StopButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.mediumTap()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Stop")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.8), in: Capsule())
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        // Recording state
        RecordingBar(
            viewModel: {
                let vm = KeyboardViewModel()
                vm.isSwiftLinkRecording = true
                vm.isSwiftLinkStreaming = true
                vm.swiftLinkStreamingTranscript = "Hello, I wanted to..."
                return vm
            }(),
            onStop: { }
        )

        // Processing state
        RecordingBar(
            viewModel: {
                let vm = KeyboardViewModel()
                var status = KeyboardProcessingStatus()
                status.currentStep = "formatting"
                vm.processingStatus = status
                return vm
            }(),
            onStop: { }
        )

        // Complete state
        RecordingBar(
            viewModel: {
                let vm = KeyboardViewModel()
                var status = KeyboardProcessingStatus()
                status.currentStep = "complete"
                vm.processingStatus = status
                return vm
            }(),
            onStop: { }
        )
    }
    .preferredColorScheme(.dark)
}
