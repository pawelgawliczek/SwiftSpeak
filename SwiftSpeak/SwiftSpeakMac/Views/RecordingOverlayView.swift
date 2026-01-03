//
//  RecordingOverlayView.swift
//  SwiftSpeakMac
//
//  SwiftUI view for the floating recording overlay
//

import SwiftUI
import SwiftSpeakCore

struct RecordingOverlayView: View {
    @ObservedObject var audioRecorder: MacAudioRecorder
    let currentMode: FormattingMode
    let isProcessing: Bool
    let onStop: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 14))

                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                // Mode badge
                Text(currentMode.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }

            // Waveform visualization
            WaveformView(levels: waveformLevels)
                .frame(height: 60)

            // Duration
            Text(formattedDuration)
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .foregroundStyle(.primary)

            // Controls
            HStack(spacing: 24) {
                // Cancel button
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                // Stop/Record button
                Button(action: onStop) {
                    ZStack {
                        Circle()
                            .fill(buttonColor)
                            .frame(width: 64, height: 64)

                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(1.2)
                        } else if audioRecorder.isRecording {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                // Placeholder for symmetry
                Color.clear
                    .frame(width: 40, height: 40)
            }
        }
        .padding(20)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        if isProcessing {
            return "arrow.clockwise"
        } else if audioRecorder.isRecording {
            return "record.circle"
        } else {
            return "mic.fill"
        }
    }

    private var statusText: String {
        if isProcessing {
            return "Processing..."
        } else if audioRecorder.isRecording {
            return "Recording"
        } else {
            return "Ready"
        }
    }

    private var statusColor: Color {
        if isProcessing {
            return .orange
        } else if audioRecorder.isRecording {
            return .red
        } else {
            return .green
        }
    }

    private var buttonColor: Color {
        if isProcessing {
            return .gray
        } else if audioRecorder.isRecording {
            return .red
        } else {
            return .accentColor
        }
    }

    private var formattedDuration: String {
        let duration = audioRecorder.duration
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    private var waveformLevels: [Float] {
        // Generate 12 levels from current audio level
        let level = audioRecorder.currentLevel
        return (0..<12).map { i in
            // Add some variation to make it look more natural
            let variation = sin(Double(i) * 0.5 + Date().timeIntervalSince1970 * 8) * 0.2
            return max(0.1, min(1.0, level + Float(variation)))
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 6, height: CGFloat(levels[index]) * 50 + 4)
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
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
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#Preview {
    RecordingOverlayView(
        audioRecorder: MacAudioRecorder(),
        currentMode: .email,
        isProcessing: false,
        onStop: {},
        onCancel: {}
    )
    .frame(width: 320, height: 220)
}
