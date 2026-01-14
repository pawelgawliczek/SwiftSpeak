//
//  BroadcastPickerView.swift
//  SwiftSpeak
//
//  SwiftUI wrapper for RPSystemBroadcastPickerView
//  Shows the system broadcast picker for starting context capture.
//

import SwiftUI
import UIKit
import ReplayKit

/// SwiftUI wrapper for the system broadcast picker
struct BroadcastPickerView: UIViewRepresentable {

    /// Bundle identifier of the broadcast extension
    let broadcastExtensionBundleId: String

    /// Size of the picker button
    let buttonSize: CGFloat

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize))

        // Set the preferred extension
        picker.preferredExtension = broadcastExtensionBundleId

        // Hide the default microphone button (we don't need audio)
        picker.showsMicrophoneButton = false

        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        // No updates needed
    }
}

/// A tappable view that triggers the broadcast picker when tapped
struct TappableBroadcastPicker: View {
    let broadcastExtensionBundleId: String

    @State private var pickerView: RPSystemBroadcastPickerView?

    var body: some View {
        Color.clear
            .background(
                BroadcastPickerRepresentable(
                    broadcastExtensionBundleId: broadcastExtensionBundleId,
                    onPickerCreated: { picker in
                        pickerView = picker
                    }
                )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                triggerBroadcastPicker()
            }
    }

    private func triggerBroadcastPicker() {
        guard let picker = pickerView else { return }

        // Find and tap the internal button
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.sendActions(for: .touchUpInside)
                return
            }
        }
    }
}

/// UIViewRepresentable that exposes the picker view
struct BroadcastPickerRepresentable: UIViewRepresentable {
    let broadcastExtensionBundleId: String
    let onPickerCreated: (RPSystemBroadcastPickerView) -> Void

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        picker.preferredExtension = broadcastExtensionBundleId
        picker.showsMicrophoneButton = false
        // Make it invisible but keep it in the view hierarchy
        picker.alpha = 0.01

        DispatchQueue.main.async {
            onPickerCreated(picker)
        }

        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

/// A styled button that wraps the broadcast picker
struct ContextCaptureButton: View {

    @ObservedObject var captureManager = ContextCaptureManager.shared
    let onStarted: (() -> Void)?

    init(onStarted: (() -> Void)? = nil) {
        self.onStarted = onStarted
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .fill(captureManager.isCapturing ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)

                // The actual broadcast picker (invisible, but tappable)
                BroadcastPickerView(
                    broadcastExtensionBundleId: "pawelgawliczek.SwiftSpeak.SwiftSpeakBroadcast",
                    buttonSize: 80
                )
                .frame(width: 80, height: 80)

                // Overlay icon (not tappable, just visual)
                Image(systemName: captureManager.isCapturing ? "record.circle.fill" : "video.fill")
                    .font(.system(size: 32))
                    .foregroundColor(captureManager.isCapturing ? .red : .blue)
                    .allowsHitTesting(false)
            }

            Text(captureManager.isCapturing ? "Capturing..." : "Start Context Capture")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onChange(of: captureManager.isCapturing) { _, isCapturing in
            if isCapturing {
                onStarted?()
            }
        }
    }
}

/// Sheet view shown during SwiftLink start to enable context capture
struct ContextCaptureSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var captureManager = ContextCaptureManager.shared
    @State private var hasStartedCapture = false

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Context Capture")
                    .font(.title2.bold())

                Text("Capture screen text for smarter transcription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Status indicator
            if captureManager.isCapturing {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text("Context capture is active")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(20)
            }

            Spacer()

            // Broadcast picker button
            ContextCaptureButton {
                hasStartedCapture = true
                // Auto-dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete()
                    dismiss()
                }
            }

            Spacer()

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(number: "1", text: "Tap the button above")
                instructionRow(number: "2", text: "Select \"Start Broadcast\"")
                instructionRow(number: "3", text: "Return to your app")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Skip button
            Button("Skip for now") {
                onComplete()
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .onAppear {
            captureManager.refreshState()
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    ContextCaptureSheet {
        print("Complete")
    }
}
