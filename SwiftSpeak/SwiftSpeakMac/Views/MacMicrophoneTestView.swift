//
//  MacMicrophoneTestView.swift
//  SwiftSpeakMac
//
//  Microphone test view with real-time level meter and record/playback
//

import SwiftUI
import AVFoundation
import Combine
import SwiftSpeakCore

struct MacMicrophoneTestView: View {
    @ObservedObject var audioDeviceManager: MacAudioDeviceManager
    @StateObject private var tester = MacMicrophoneTester()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Test Microphone")
                        .font(.title2.bold())
                    Text("Check your audio input before recording")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            // Device info
            if let device = audioDeviceManager.selectedDevice {
                HStack(spacing: 10) {
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
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
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
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quaternary)

                        // Level indicator
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(levelGradient)
                            .frame(width: max(4, geometry.size.width * CGFloat(tester.normalizedLevel)))
                            .animation(.easeOut(duration: 0.05), value: tester.normalizedLevel)

                        // Peak indicator
                        if tester.peakLevel > 0.1 {
                            Rectangle()
                                .fill(.white.opacity(0.8))
                                .frame(width: 2)
                                .offset(x: geometry.size.width * CGFloat(tester.peakLevel) - 1)
                                .animation(.easeOut(duration: 0.1), value: tester.peakLevel)
                        }
                    }
                }
                .frame(height: 24)

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
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

            // Waveform visualization
            VStack(spacing: 8) {
                Text("Waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    ForEach(0..<30, id: \.self) { index in
                        let level = tester.waveformLevels.indices.contains(index)
                            ? tester.waveformLevels[index]
                            : 0.05
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(barColor(for: level))
                            .frame(width: 8, height: max(4, 50 * CGFloat(level)))
                            .animation(.easeOut(duration: 0.08), value: level)
                    }
                }
                .frame(height: 50)
            }
            .padding()
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(tester.isMonitoring ? .green : .secondary)
                    .frame(width: 8, height: 8)
                Text(tester.statusText)
                    .font(.callout)
                    .foregroundStyle(tester.isMonitoring ? .primary : .secondary)
            }

            Spacer()

            // Controls
            HStack(spacing: 16) {
                // Monitor toggle
                Button {
                    if tester.isMonitoring {
                        tester.stopMonitoring()
                    } else {
                        tester.startMonitoring(deviceID: getSelectedDeviceID())
                    }
                } label: {
                    Label(
                        tester.isMonitoring ? "Stop Monitor" : "Start Monitor",
                        systemImage: tester.isMonitoring ? "stop.fill" : "waveform"
                    )
                    .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .tint(tester.isMonitoring ? .orange : .blue)

                Divider()
                    .frame(height: 30)

                // Record button
                Button {
                    if tester.isRecording {
                        tester.stopRecording()
                    } else {
                        tester.startRecording(deviceID: getSelectedDeviceID())
                    }
                } label: {
                    Label(
                        tester.isRecording ? "Stop" : "Record",
                        systemImage: tester.isRecording ? "stop.circle.fill" : "record.circle"
                    )
                    .frame(minWidth: 80)
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
                    .frame(minWidth: 80)
                }
                .buttonStyle(.bordered)
                .disabled(!tester.hasRecording || tester.isRecording)
            }

            // Recording info
            if tester.hasRecording {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Recording saved (\(tester.recordingDuration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 450, height: 580)
        .onAppear {
            // Auto-start monitoring
            tester.startMonitoring(deviceID: getSelectedDeviceID())
        }
        .onDisappear {
            tester.cleanup()
        }
        .onChange(of: audioDeviceManager.selectedDevice) { newDevice in
            // Restart monitoring with new device
            if tester.isMonitoring {
                tester.stopMonitoring()
                tester.startMonitoring(deviceID: getSelectedDeviceID())
            }
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

    private func getSelectedDeviceID() -> AudioDeviceID? {
        guard let device = audioDeviceManager.selectedDevice,
              !device.isSystemDefault,
              let deviceID = UInt32(device.id) else {
            return nil
        }
        return deviceID
    }
}

// MARK: - Microphone Tester

@MainActor
class MacMicrophoneTester: ObservableObject {
    @Published var isMonitoring = false
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var normalizedLevel: Double = 0
    @Published var peakLevel: Double = 0
    @Published var decibelLevel: Double = -60
    @Published var waveformLevels: [Double] = Array(repeating: 0.05, count: 30)
    @Published var recordingDuration: String = "0s"

    var statusText: String {
        if isPlaying { return "Playing back..." }
        if isRecording { return "Recording... speak now" }
        if isMonitoring { return "Monitoring input level" }
        return "Not monitoring"
    }

    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var peakHoldTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingURL: URL?

    init() {
        // Create temp directory for recordings
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftSpeakMicTest")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        recordingURL = tempDir.appendingPathComponent("test_recording.m4a")
    }

    func startMonitoring(deviceID: AudioDeviceID?) {
        guard !isMonitoring else { return }

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let inputNode = engine.inputNode

        // Set device if specified
        if let deviceID = deviceID {
            var mutableDeviceID = deviceID
            let status = AudioUnitSetProperty(
                inputNode.audioUnit!,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableDeviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
            if status != noErr {
                macLog("Failed to set audio device: \(status)", category: "MicTest", level: .warning)
            }
        }

        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        do {
            try engine.start()
            isMonitoring = true
            startPeakHoldTimer()
            macLog("Started audio monitoring", category: "MicTest")
        } catch {
            macLog("Failed to start audio engine: \(error)", category: "MicTest", level: .error)
        }
    }

    func stopMonitoring() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isMonitoring = false
        peakHoldTimer?.invalidate()
        peakHoldTimer = nil

        // Reset levels
        normalizedLevel = 0
        peakLevel = 0
        decibelLevel = -60
        waveformLevels = Array(repeating: 0.05, count: 30)
    }

    func startRecording(deviceID: AudioDeviceID?) {
        guard let url = recordingURL else { return }

        // Stop monitoring during recording
        if isMonitoring {
            stopMonitoring()
        }

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
                    self?.updateRecordingLevels()
                }
            }

            macLog("Started test recording", category: "MicTest")
        } catch {
            macLog("Failed to start recording: \(error)", category: "MicTest", level: .error)
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
        waveformLevels = Array(repeating: 0.05, count: 30)

        // Restart monitoring
        startMonitoring(deviceID: nil)

        macLog("Stopped test recording", category: "MicTest")
    }

    func playRecording() {
        guard let url = recordingURL, FileManager.default.fileExists(atPath: url.path) else { return }

        // Stop monitoring during playback
        if isMonitoring {
            stopMonitoring()
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = PlaybackDelegate { [weak self] in
                Task { @MainActor in
                    self?.playbackFinished()
                }
            }
            audioPlayer?.play()
            isPlaying = true
            macLog("Started test playback", category: "MicTest")
        } catch {
            macLog("Failed to play recording: \(error)", category: "MicTest", level: .error)
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false

        // Restart monitoring
        startMonitoring(deviceID: nil)
    }

    private func playbackFinished() {
        isPlaying = false
        startMonitoring(deviceID: nil)
    }

    func cleanup() {
        stopMonitoring()
        stopRecording()
        stopPlayback()

        // Clean up temp file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }

        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 0.000001))

        // Normalize to 0-1 range (assuming -60 to 0 dB range)
        let normalized = Double(max(0, min(1, (db + 60) / 60)))

        Task { @MainActor in
            self.normalizedLevel = normalized
            self.decibelLevel = Double(db)

            // Update peak
            if normalized > self.peakLevel {
                self.peakLevel = normalized
            }

            // Update waveform (shift left, add new value)
            self.waveformLevels.removeFirst()
            self.waveformLevels.append(normalized)
        }
    }

    private func updateRecordingLevels() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()

        let db = recorder.averagePower(forChannel: 0)
        let normalized = Double(max(0, min(1, (db + 60) / 60)))

        normalizedLevel = normalized
        decibelLevel = Double(db)

        // Update waveform
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

// MARK: - Playback Delegate

private class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinished: () -> Void

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinished()
    }
}
