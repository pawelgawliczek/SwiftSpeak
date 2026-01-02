// LEGACY: This file is deprecated and kept for reference only
// Replaced by: SwiftLinkStreamingOverlay in KeyboardView.swift on 2025-01-02
// Reason: New WhatsApp-style overlay with integrated transcript display
// DO NOT USE - Will be removed in future cleanup
//
//  StreamingTranscriptRow.swift
//  SwiftSpeakKeyboard
//
//  [LEGACY] Shows live streaming transcript text during recording (Phase 13.10)
//

import SwiftUI

struct StreamingTranscriptRow: View {
    @ObservedObject var viewModel: KeyboardViewModel

    @State private var displayedText: String = ""
    @State private var dotCount: Int = 0
    @State private var dotTimer: Timer?

    private var streamingText: String {
        viewModel.swiftLinkStreamingTranscript
    }

    private var isStreaming: Bool {
        viewModel.isSwiftLinkStreaming
    }

    private var processingStep: String {
        viewModel.processingStatus.currentStep
    }

    var body: some View {
        HStack(spacing: 8) {
            // Streaming indicator
            if isStreaming || viewModel.isSwiftLinkRecording {
                StreamingIndicator()
                    .frame(width: 24, height: 24)
            }

            // Main text content
            Group {
                if !streamingText.isEmpty {
                    // Show streaming transcript
                    Text(streamingText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.head)
                } else if processingStep == "transcribing" {
                    Text("Transcribing\(String(repeating: ".", count: dotCount))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                } else if processingStep == "formatting" {
                    Text("Formatting\(String(repeating: ".", count: dotCount))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                } else if processingStep == "translating" {
                    Text("Translating\(String(repeating: ".", count: dotCount))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                } else if viewModel.isSwiftLinkRecording {
                    Text("Listening\(String(repeating: ".", count: dotCount))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("Processing\(String(repeating: ".", count: dotCount))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: streamingText)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(white: 0.08))
        .onAppear {
            startDotAnimation()
        }
        .onDisappear {
            stopDotAnimation()
        }
    }

    private func startDotAnimation() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }

    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }
}

// MARK: - Streaming Indicator
private struct StreamingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(KeyboardTheme.accent)
                    .frame(width: 4, height: 4)
                    .offset(y: isAnimating ? -3 : 3)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        // Listening state
        StreamingTranscriptRow(
            viewModel: {
                let vm = KeyboardViewModel()
                vm.isSwiftLinkRecording = true
                return vm
            }()
        )

        // Streaming with text
        StreamingTranscriptRow(
            viewModel: {
                let vm = KeyboardViewModel()
                vm.isSwiftLinkStreaming = true
                vm.swiftLinkStreamingTranscript = "Hello, I wanted to ask you about the meeting tomorrow..."
                return vm
            }()
        )

        // Processing state
        StreamingTranscriptRow(
            viewModel: {
                let vm = KeyboardViewModel()
                var status = KeyboardProcessingStatus()
                status.currentStep = "formatting"
                vm.processingStatus = status
                return vm
            }()
        )
    }
    .preferredColorScheme(.dark)
}
