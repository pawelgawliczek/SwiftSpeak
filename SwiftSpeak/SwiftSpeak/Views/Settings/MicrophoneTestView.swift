//
//  MicrophoneTestView.swift
//  SwiftSpeak
//
//  Microphone test view with real-time level meter and record/playback (iOS)
//

import SwiftUI
import AVFoundation
import Combine
import SwiftSpeakCore

struct MicrophoneTestView: View {
    @ObservedObject var audioDeviceManager: AudioDeviceManager
    @StateObject private var tester = MicrophoneTester()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Device info
                    if let device = audioDeviceManager.selectedDevice {
                        HStack(spacing: 12) {
                            Image(systemName: device.deviceType.iconName)
                                .font(.title2)
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.isSystemDefault ? "System Default" : device.deviceType.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Real-time level meter
                    VStack(spacing: 12) {
                        Text("Input Level")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Level bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.secondary.opacity(0.2))

                                // Level indicator
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(levelGradient)
                                    .frame(width: max(4, geometry.size.width * CGFloat(tester.normalizedLevel)))
                                    .animation(.easeOut(duration: 0.05), value: tester.normalizedLevel)

                                // Peak indicator
                                if tester.peakLevel > 0.1 {
                                    Rectangle()
                                        .fill(.white.opacity(0.8))
                                        .frame(width: 3)
                                        .offset(x: geometry.size.width * CGFloat(tester.peakLevel) - 1.5)
                                        .animation(.easeOut(duration: 0.1), value: tester.peakLevel)
                                }
                            }
                        }
                        .frame(height: 28)

                        // Level labels
                        HStack {
                            Text("Silent")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.0f dB", tester.decibelLevel))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Loud")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Waveform visualization
                    VStack(spacing: 12) {
                        Text("Waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            ForEach(0..<25, id: \.self) { index in
                                let level = tester.waveformLevels.indices.contains(index)
                                    ? tester.waveformLevels[index]
                                    : 0.05
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(barColor(for: level))
                                    .frame(height: max(6, 60 * CGFloat(level)))
                                    .animation(.easeOut(duration: 0.08), value: level)
                            }
                        }
                        .frame(height: 60)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(tester.isMonitoring ? .green : .secondary)
                            .frame(width: 10, height: 10)
                        Text(tester.statusText)
                            .font(.callout)
                            .foregroundStyle(tester.isMonitoring ? .primary : .secondary)
                    }

                    // Controls
                    VStack(spacing: 16) {
                        // Monitor toggle
                        Button {
                            if tester.isMonitoring {
                                tester.stopMonitoring()
                            } else {
                                tester.startMonitoring()
                            }
                        } label: {
                            Label(
                                tester.isMonitoring ? "Stop Monitor" : "Start Monitor",
                                systemImage: tester.isMonitoring ? "stop.fill" : "waveform"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(tester.isMonitoring ? .orange : .blue)

                        HStack(spacing: 16) {
                            // Record button
                            Button {
                                if tester.isRecording {
                                    tester.stopRecording()
                                } else {
                                    tester.startRecording()
                                }
                            } label: {
                                Label(
                                    tester.isRecording ? "Stop" : "Record",
                                    systemImage: tester.isRecording ? "stop.circle.fill" : "record.circle"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .disabled(tester.isPlaying)

                            // Playback button
                            Button {
                                if tester.isPlaying {
                                    tester.stopPlayback()
                                } else {
                                    tester.playRecording()
                                }
                            } label: {
                                Label(
                                    tester.isPlaying ? "Stop" : "Play",
                                    systemImage: tester.isPlaying ? "stop.fill" : "play.fill"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!tester.hasRecording || tester.isRecording)
                        }
                    }

                    // Recording info
                    if tester.hasRecording {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Recording saved (\(tester.recordingDuration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .navigationTitle("Test Microphone")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tester.startMonitoring()
        }
        .onDisappear {
            tester.cleanup()
        }
    }

    private var levelGradient: LinearGradient {
        LinearGradient(
            colors: [.green, .yellow, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func barColor(for level: Double) -> Color {
        if level < 0.3 { return .green }
        if level < 0.6 { return .yellow }
        if level < 0.8 { return .orange }
        return .red
    }
}

// MARK: - iOS Microphone Tester

@MainActor
class MicrophoneTester: ObservableObject {
    @Published var isMonitoring = false
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var normalizedLevel: Double = 0
    @Published var peakLevel: Double = 0
    @Published var decibelLevel: Double = -60
    @Published var waveformLevels: [Double] = Array(repeating: 0.05, count: 25)
    @Published var recordingDuration: String = "0s"

    var statusText: String {
        if isPlaying { return "Playing back..." }
        if isRecording { return "Recording... speak now" }
        if isMonitoring { return "Monitoring input level" }
        return "Not monitoring"
    }

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var levelTimer: Timer?
    private var peakHoldTimer: Timer?
    private var recordingStartTime: Date?
    private var monitoringURL: URL?
    private var recordingURL: URL?

    init() {
        // Create temp directory for recordings
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftSpeakMicTest")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        monitoringURL = tempDir.appendingPathComponent("monitoring.m4a")
        recordingURL = tempDir.appendingPathComponent("test_recording.m4a")
    }

    func startMonitoring() {
        guard !isMonitoring, !isRecording else { return }

        configureAudioSession()

        guard let url = monitoringURL else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isMonitoring = true

            // Start level metering
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateLevels()
                }
            }

            startPeakHoldTimer()
            appLog("Started audio monitoring", category: "MicTest")
        } catch {
            appLog("Failed to start monitoring: \(error)", category: "MicTest", level: .error)
        }
    }

    func stopMonitoring() {
        audioRecorder?.stop()
        audioRecorder = nil
        isMonitoring = false
        levelTimer?.invalidate()
        levelTimer = nil
        peakHoldTimer?.invalidate()
        peakHoldTimer = nil

        // Reset levels
        normalizedLevel = 0
        peakLevel = 0
        decibelLevel = -60
        waveformLevels = Array(repeating: 0.05, count: 25)

        // Clean up monitoring file
        if let url = monitoringURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func startRecording() {
        // Stop monitoring first
        stopMonitoring()

        guard let url = recordingURL else { return }

        configureAudioSession()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            hasRecording = false

            // Start level metering
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateLevels()
                }
            }

            appLog("Started test recording", category: "MicTest")
        } catch {
            appLog("Failed to start recording: \(error)", category: "MicTest", level: .error)
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        levelTimer?.invalidate()
        levelTimer = nil

        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            recordingDuration = String(format: "%.1fs", duration)
        }

        hasRecording = FileManager.default.fileExists(atPath: recordingURL?.path ?? "")

        // Reset levels
        normalizedLevel = 0
        decibelLevel = -60
        waveformLevels = Array(repeating: 0.05, count: 25)

        // Restart monitoring
        startMonitoring()

        appLog("Stopped test recording", category: "MicTest")
    }

    func playRecording() {
        guard let url = recordingURL, FileManager.default.fileExists(atPath: url.path) else { return }

        // Stop monitoring during playback
        stopMonitoring()

        // Configure for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            appLog("Failed to configure playback session: \(error)", category: "MicTest", level: .error)
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = iOSPlaybackDelegate { [weak self] in
                Task { @MainActor in
                    self?.playbackFinished()
                }
            }
            audioPlayer?.play()
            isPlaying = true
            appLog("Started test playback", category: "MicTest")
        } catch {
            appLog("Failed to play recording: \(error)", category: "MicTest", level: .error)
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false

        // Restart monitoring
        startMonitoring()
    }

    private func playbackFinished() {
        isPlaying = false
        startMonitoring()
    }

    func cleanup() {
        stopMonitoring()
        if isRecording {
            audioRecorder?.stop()
            audioRecorder = nil
            isRecording = false
        }
        stopPlayback()
        levelTimer?.invalidate()
        peakHoldTimer?.invalidate()

        // Clean up temp files
        if let url = monitoringURL {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            appLog("Failed to configure audio session: \(error)", category: "MicTest", level: .error)
        }
    }

    private func updateLevels() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()

        let db = recorder.averagePower(forChannel: 0)
        let normalized = Double(max(0, min(1, (db + 60) / 60)))

        normalizedLevel = normalized
        decibelLevel = Double(db)

        // Update peak
        if normalized > peakLevel {
            peakLevel = normalized
        }

        // Update waveform (shift left, add new value)
        waveformLevels.removeFirst()
        waveformLevels.append(normalized)
    }

    private func startPeakHoldTimer() {
        peakHoldTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.peakLevel = max(0, (self?.peakLevel ?? 0) - 0.1)
            }
        }
    }
}

// MARK: - iOS Playback Delegate

private class iOSPlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinished()
    }
}

#Preview {
    NavigationStack {
        MicrophoneTestView(audioDeviceManager: AudioDeviceManager())
    }
}
