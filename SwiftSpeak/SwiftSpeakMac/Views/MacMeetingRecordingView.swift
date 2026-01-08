//
//  MacMeetingRecordingView.swift
//  SwiftSpeakMac
//
//  Meeting recording interface with speaker diarization support
//  macOS version - shares core logic with iOS via MeetingRecordingOrchestrator
//

import SwiftUI
import SwiftSpeakCore

struct MacMeetingRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: MacSettings
    @ObservedObject private var notificationManager = MeetingNotificationManager.shared

    @StateObject private var orchestrator = MeetingRecordingOrchestrator()
    @StateObject private var deviceManager = MacAudioDeviceManager()

    // Services (created once and retained)
    // Use dual-source recorder for both single and dual modes
    private let audioRecorder = MacDualSourceAudioRecorder()

    // State
    @State private var showingSettings = false
    @State private var showingResult = false
    @State private var meetingTitle = ""
    @State private var configurationError: String?
    @State private var isDualSourceAvailable = false
    @State private var selectedContextId: UUID?
    @State private var isProcessingInBackground = false
    @State private var windowClosed = false

    // Animation
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background with logo
            backgroundView

            VStack(spacing: 20) {
                // Quick settings card (context + speakers)
                if !orchestrator.isRecording && !orchestrator.isProcessing {
                    quickSettingsCard
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                Spacer(minLength: 8)

                // Timer display
                timerView

                // Audio waveform visualization
                waveformView
                    .frame(height: 60)
                    .padding(.horizontal, 40)

                // Cost estimate (no dual mode indicator)
                if orchestrator.isRecording || orchestrator.duration > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(orchestrator.formattedCost)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                }

                Spacer(minLength: 12)

                // Status indicator
                statusView

                // Recording controls
                controlsView
                    .padding(.bottom, 40)

                // Background processing hint
                if orchestrator.isProcessing {
                    Text("You can close this window. You'll be notified when processing completes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }
            }
            .padding(.top, 16)
        }
        .frame(minWidth: 480, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(orchestrator.isProcessing ? "Close" : "Cancel") {
                    handleClose()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .disabled(orchestrator.isRecording)
            }
        }
        .sheet(isPresented: $showingSettings) {
            MacMeetingSettingsSheet(
                settings: $orchestrator.settings,
                isDualSourceAvailable: isDualSourceAvailable,
                contexts: settings.contexts,
                deviceManager: deviceManager
            )
        }
        .sheet(isPresented: $showingResult) {
            if case .complete(let record) = orchestrator.state {
                MacMeetingResultView(record: record, onDismiss: {
                    showingResult = false
                    dismiss()
                })
            }
        }
        .onChange(of: orchestrator.state) { newState in
            handleStateChange(newState)
        }
        .onChange(of: selectedContextId) { newValue in
            orchestrator.settings.setContext(id: newValue, from: settings.contexts)
        }
        .onChange(of: deviceManager.selectedDevice) { newDevice in
            // Update the audio recorder with the selected device
            Task {
                if let device = newDevice, !device.isSystemDefault {
                    if let deviceID = UInt32(device.id) {
                        await audioRecorder.setSelectedDeviceID(deviceID)
                        macLog("Selected microphone: \(device.name)", category: "Meeting")
                    }
                } else {
                    await audioRecorder.setSelectedDeviceID(nil)
                    macLog("Using system default microphone", category: "Meeting")
                }
            }
        }
        .onAppear {
            configureOrchestrator()
            selectedContextId = orchestrator.settings.contextId
        }
        .task {
            // Check dual-source availability
            isDualSourceAvailable = await audioRecorder.isDualSourceAvailable
        }
        .onDisappear {
            windowClosed = true
            // Clean up audio recorder when view disappears (only if not processing)
            if !orchestrator.isProcessing {
                Task {
                    await audioRecorder.cleanup()
                }
            }
        }
    }

    // MARK: - Actions

    private func handleClose() {
        if orchestrator.isRecording {
            // Cancel if still recording
            Task {
                await orchestrator.cancelRecording()
                await audioRecorder.cleanup()
            }
            dismiss()
        } else if orchestrator.isProcessing {
            // Allow closing during processing - will notify when done
            isProcessingInBackground = true
            dismiss()
            macLog("User closed window during processing - will notify on completion", category: "Meeting")
        } else {
            // Just close
            Task {
                await audioRecorder.cleanup()
            }
            dismiss()
        }
    }

    private func handleStateChange(_ newState: MeetingRecordingState) {
        if case .complete(let record) = newState {
            if windowClosed || isProcessingInBackground {
                // Window was closed - show notification instead
                notificationManager.notifyMeetingComplete(record: record)
                Task {
                    await audioRecorder.cleanup()
                }
            } else {
                // Window is open - show result sheet
                showingResult = true
            }
        } else if case .error = newState {
            if windowClosed || isProcessingInBackground {
                // Could show error notification here if needed
                Task {
                    await audioRecorder.cleanup()
                }
            }
        }
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.5),
                    Color.teal.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // SwiftSpeak logo watermark
            Image("SwiftSpeakLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .opacity(0.18)
                .offset(y: 40)
        }
        .ignoresSafeArea()
    }

    private var quickSettingsCard: some View {
        HStack(spacing: 16) {
            // Microphone picker (compact)
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Picker("Microphone", selection: $deviceManager.selectedDevice) {
                    ForEach(deviceManager.availableDevices) { device in
                        HStack(spacing: 6) {
                            Image(systemName: device.deviceType.iconName)
                            Text(device.name)
                            if device.deviceType == .continuity {
                                Text("iPhone")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(device as AudioInputDevice?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Divider()
                .frame(height: 24)

            // Context picker (compact)
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)

                Picker("Context", selection: $selectedContextId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(settings.contexts) { context in
                        Label {
                            Text(context.name)
                        } icon: {
                            Text(context.icon)
                        }
                        .tag(context.id as UUID?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Divider()
                .frame(height: 24)

            // Speaker count (compact)
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)

                Text("\(orchestrator.settings.expectedSpeakerCount ?? 2)")
                    .font(.callout.weight(.medium).monospacedDigit())

                Stepper(
                    "",
                    value: Binding(
                        get: { orchestrator.settings.expectedSpeakerCount ?? 2 },
                        set: { orchestrator.settings.expectedSpeakerCount = $0 }
                    ),
                    in: 2...10
                )
                .labelsHidden()
            }

            // Word boost indicator (if any)
            if !orchestrator.settings.wordBoost.isEmpty {
                Divider()
                    .frame(height: 24)

                HStack(spacing: 4) {
                    Image(systemName: "text.badge.plus")
                        .font(.caption)
                    Text("\(orchestrator.settings.wordBoost.count)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.teal)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timerView: some View {
        VStack(spacing: 8) {
            Text(orchestrator.formattedDuration)
                .font(.system(size: 72, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(orchestrator.isRecording ? .primary : .tertiary)
                .contentTransition(.numericText())
                .animation(.default, value: orchestrator.duration)
        }
    }

    private var waveformView: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<25, id: \.self) { index in
                    let level = audioLevelForBar(index)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barGradient)
                        .frame(width: (geometry.size.width - 96) / 25, height: max(4, level * geometry.size.height))
                        .animation(.easeInOut(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(orchestrator.isRecording ? 1 : 0.25)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [.teal, .cyan.opacity(0.7)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var statusView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Check for configuration error first
                if let error = configurationError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                } else {
                    switch orchestrator.state {
                    case .idle:
                        Image(systemName: "waveform.circle")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                        Text("Ready to record")
                            .foregroundStyle(.secondary)

                    case .recording(_, let isPaused):
                        if isPaused {
                            Image(systemName: "pause.circle.fill")
                                .font(.body)
                                .foregroundStyle(.orange)
                            Text("Paused")
                                .foregroundStyle(.orange)
                        } else {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulseAnimation)
                                .onAppear { pulseAnimation = true }
                                .onDisappear { pulseAnimation = false }
                            Text("Recording")
                                .foregroundStyle(.primary)
                                .fontWeight(.medium)
                        }

                    case .stopping, .chunking, .transcribing, .mergingTranscripts, .generatingNotes, .savingToObsidian:
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(orchestrator.state.statusText)
                            .foregroundStyle(.secondary)

                    case .complete:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Complete")
                            .foregroundStyle(.green)

                    case .error(let error):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .font(.caption)
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private var controlsView: some View {
        HStack(spacing: 24) {
            // Pause/Resume button (only during recording)
            if orchestrator.isRecording {
                Button {
                    Task {
                        await orchestrator.togglePause()
                    }
                } label: {
                    Image(systemName: orchestrator.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 52, height: 52)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Main record/stop button
            Button {
                handleMainButtonTap()
            } label: {
                mainButtonContent
            }
            .buttonStyle(.plain)
            .disabled(orchestrator.isProcessing || configurationError != nil)
            .opacity(configurationError != nil ? 0.5 : 1.0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: orchestrator.isRecording)
    }

    private var mainButtonContent: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    orchestrator.isRecording ? Color.red : Color.red.opacity(0.8),
                    lineWidth: orchestrator.isRecording ? 3 : 4
                )
                .frame(width: 76, height: 76)

            // Glow effect when idle
            if !orchestrator.isRecording && !orchestrator.isProcessing {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 72, height: 72)
            }

            if orchestrator.isRecording {
                // Stop icon (rounded square)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.red)
                    .frame(width: 26, height: 26)
            } else if orchestrator.isProcessing {
                // Processing indicator
                ProgressView()
                    .scaleEffect(1.1)
            } else {
                // Record icon
                Circle()
                    .fill(Color.red)
                    .frame(width: 58, height: 58)
            }
        }
        .contentShape(Circle())
    }

    // MARK: - Actions

    private func handleMainButtonTap() {
        Task {
            if orchestrator.isRecording {
                await orchestrator.stopRecording()
            } else if case .idle = orchestrator.state {
                do {
                    try await orchestrator.startRecording()
                } catch {
                    macLog("Failed to start meeting recording: \(error)", category: "Meeting", level: .error)
                }
            } else if case .error = orchestrator.state {
                orchestrator.reset()
            }
        }
    }

    private func configureOrchestrator() {
        macLog("Configuring meeting orchestrator", category: "Meeting")

        // Get AssemblyAI configuration from settings
        guard let assemblyAIConfig = settings.configuredAIProviders.first(where: { $0.provider == .assemblyAI }),
              !assemblyAIConfig.apiKey.isEmpty else {
            configurationError = "AssemblyAI not configured. Please add your AssemblyAI API key in Settings → Providers."
            macLog("Meeting recording: AssemblyAI not configured", category: "Meeting", level: .error)
            return
        }

        // Create transcription service from shared Core package
        let transcriptionService = AssemblyAIMeetingService(
            apiKey: assemblyAIConfig.apiKey,
            model: assemblyAIConfig.transcriptionModel ?? "best"
        )

        // Configure orchestrator with services
        orchestrator.configure(
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            notesGenerator: nil  // Optional: could add LLM-based notes generation later
        )

        macLog("Meeting orchestrator configured with AssemblyAI", category: "Meeting")
    }

    private func audioLevelForBar(_ index: Int) -> CGFloat {
        let baseLevel = CGFloat(orchestrator.audioLevel)
        let variance = sin(Double(index) * 0.4 + Date().timeIntervalSinceReferenceDate * 2) * 0.25
        return max(0.05, min(1.0, baseLevel + variance * baseLevel))
    }
}

// MARK: - Meeting Settings Sheet (macOS)

struct MacMeetingSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: MeetingSettings
    var isDualSourceAvailable: Bool = false
    var contexts: [ConversationContext] = []
    @ObservedObject var deviceManager: MacAudioDeviceManager

    // Selected context for UI binding
    @State private var selectedContextId: UUID?

    var body: some View {
        VStack(spacing: 20) {
            Text("Meeting Settings")
                .font(.title2.bold())

            Form {
                // Microphone selection
                Section("Microphone") {
                    Picker("Input Device", selection: $deviceManager.selectedDevice) {
                        ForEach(deviceManager.availableDevices) { device in
                            HStack(spacing: 8) {
                                Image(systemName: device.deviceType.iconName)
                                    .foregroundStyle(device.deviceType == .continuity ? .blue : .primary)
                                Text(device.name)
                                if device.isDefault && !device.isSystemDefault {
                                    Text("(Default)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if device.deviceType == .continuity {
                                    Text("iPhone")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .tag(device as AudioInputDevice?)
                        }
                    }
                    .pickerStyle(.menu)

                    // Continuity hint for older macOS
                    if #unavailable(macOS 13.0) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("iPhone as microphone requires macOS Ventura or later")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Show current selection summary
                    if let selected = deviceManager.selectedDevice {
                        HStack(spacing: 6) {
                            Image(systemName: selected.deviceType.iconName)
                                .foregroundStyle(.teal)
                            Text("Recording from: \(selected.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Context picker for vocabulary hints
                Section("Context") {
                    Picker("Use Context", selection: $selectedContextId) {
                        Text("None")
                            .tag(nil as UUID?)

                        ForEach(contexts) { context in
                            HStack {
                                Text(context.icon)
                                Text(context.name)
                                if context.domainJargon != .none {
                                    Text("• \(context.domainJargon.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(context.id as UUID?)
                        }
                    }
                    .onChange(of: selectedContextId) { newValue in
                        updateContextVocabulary(contextId: newValue)
                    }

                    if let contextId = selectedContextId,
                       let context = contexts.first(where: { $0.id == contextId }),
                       context.domainJargon != .none {
                        HStack(spacing: 8) {
                            Image(systemName: context.domainJargon.icon)
                                .foregroundStyle(.teal)
                            Text(context.domainJargon.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !settings.wordBoost.isEmpty {
                        Text("Vocabulary boost: \(settings.wordBoost.count) terms")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }
                }

                Section("Audio Source") {
                    Picker("Recording Mode", selection: $settings.audioSource) {
                        ForEach(MeetingAudioSource.allCases, id: \.self) { source in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.displayName)
                            }
                            .tag(source)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    if settings.audioSource == .microphoneAndSystemAudio {
                        if isDualSourceAvailable {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("System audio capture available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            TextField("Your Name", text: $settings.userDisplayName)
                                .textFieldStyle(.roundedBorder)

                            Text("Your segments will be labeled with this name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Screen recording permission required")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            Button("Open System Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Recording") {
                    HStack {
                        Text("Max Duration")
                        Spacer()
                        Stepper("\(settings.maxDurationMinutes) min",
                                value: $settings.maxDurationMinutes,
                                in: 15...180,
                                step: 15)
                    }

                    Toggle("Require Speaker Diarization", isOn: $settings.requireDiarization)

                    if settings.requireDiarization {
                        HStack {
                            Text("Expected Speakers")
                            Spacer()
                            Stepper("\(settings.expectedSpeakerCount ?? 2)",
                                    value: Binding(
                                        get: { settings.expectedSpeakerCount ?? 2 },
                                        set: { settings.expectedSpeakerCount = $0 }
                                    ),
                                    in: 2...10)
                        }
                    }
                }

                Section("Output") {
                    Toggle("Include Timestamps", isOn: $settings.includeTimestamps)
                    Toggle("Auto-save to Obsidian", isOn: $settings.autoSaveToObsidian)
                }
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 8) {
                if settings.audioSource == .microphoneAndSystemAudio {
                    Text("Dual Source mode records your microphone separately from meeting app audio. Your voice is automatically tagged as '\(settings.userDisplayName)', while remote participants go through speaker diarization.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Microphone Only mode records all audio through your microphone. Speaker diarization will attempt to identify different voices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450)
        .onAppear {
            // Initialize from settings
            selectedContextId = settings.contextId
        }
    }

    // MARK: - Helpers

    /// Update settings with vocabulary from selected context
    private func updateContextVocabulary(contextId: UUID?) {
        // Use shared helper from MeetingSettings
        settings.setContext(id: contextId, from: contexts)
    }
}

// MARK: - Meeting Result View (macOS)

struct MacMeetingResultView: View {
    let record: MeetingRecord
    let onDismiss: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(record.title)
                    .font(.title2.bold())
                Spacer()
                Text(record.formattedDuration)
                    .foregroundStyle(.secondary)
            }

            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Notes").tag(0)
                Text("Transcript").tag(1)
                if record.diarizedTranscript != nil {
                    Text("Speakers").tag(2)
                }
            }
            .pickerStyle(.segmented)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0:
                        notesView
                    case 1:
                        transcriptView
                    case 2:
                        speakersView
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            // Footer buttons
            HStack {
                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shareText, forType: .string)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    private var notesView: some View {
        Group {
            if let notes = record.generatedNotes {
                Text(notes)
                    .font(.body)
                    .textSelection(.enabled)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Notes Generated")
                        .font(.headline)
                    Text("Meeting notes will appear here after processing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }

    private var transcriptView: some View {
        Text(record.bestTranscript)
            .font(.body)
            .textSelection(.enabled)
    }

    private var speakersView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let diarized = record.diarizedTranscript {
                ForEach(diarized.speakers, id: \.self) { speaker in
                    speakerSection(for: speaker, in: diarized)
                }
            }
        }
    }

    private func speakerSection(for speaker: String, in transcript: DiarizedTranscript) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.teal)

            VStack(alignment: .leading, spacing: 2) {
                Text(transcript.displayName(for: speaker))
                    .font(.headline)

                let speakerSegments = transcript.segments.filter { $0.speaker == speaker }
                Text("\(speakerSegments.count) segments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var shareText: String {
        var text = "# \(record.title)\n\n"
        text += "Duration: \(record.formattedDuration)\n"
        text += "Recorded: \(record.recordedAt.formatted())\n\n"

        if let notes = record.generatedNotes {
            text += notes
        } else {
            text += record.bestTranscript
        }

        return text
    }
}

// MARK: - Preview

#Preview {
    MacMeetingRecordingView()
        .environmentObject(MacSettings.shared)
}
