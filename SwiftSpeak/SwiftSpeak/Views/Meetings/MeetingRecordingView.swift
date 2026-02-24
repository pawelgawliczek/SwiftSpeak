//
//  MeetingRecordingView.swift
//  SwiftSpeak
//
//  Meeting recording interface with speaker diarization support
//  iOS version - shares core logic with macOS via MeetingRecordingOrchestrator
//

import SwiftUI
import SwiftSpeakCore

struct MeetingRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var settings: SharedSettings

    @StateObject private var orchestrator = MeetingRecordingOrchestrator()

    // Audio recorder (retained for stats monitoring)
    @State private var audioRecorder: MeetingAudioRecorderImpl?

    // State
    @State private var showingSettings = false
    @State private var showingResult = false
    @State private var meetingTitle = ""
    @State private var configurationError: String?
    @State private var selectedContextId: UUID?

    // Recording health stats
    @State private var recordingFileSizeMB: Double = 0
    @State private var recordingWriteErrors: Int = 0
    @State private var statsTimer: Timer?

    // Animation
    @State private var pulseAnimation = false

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Timer display
                    timerView

                    // Audio waveform visualization
                    waveformView
                        .frame(height: 80)
                        .padding(.horizontal)

                    // Cost estimate
                    costEstimateView

                    Spacer()

                    // Status indicator
                    statusView

                    // Recording controls
                    controlsView
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle("Meeting Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if orchestrator.isProcessing {
                        // During transcription, offer to continue in background
                        Button("Background") {
                            continueInBackground()
                        }
                    } else {
                        Button("Cancel") {
                            Task {
                                await orchestrator.cancelRecording()
                            }
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .disabled(orchestrator.isRecording)
                }
            }
            .sheet(isPresented: $showingSettings) {
                MeetingSettingsSheet(
                    settings: $orchestrator.settings,
                    contexts: settings.contexts
                )
            }
            .sheet(isPresented: $showingResult) {
                if case .complete(let record) = orchestrator.state {
                    MeetingResultView(record: record, onDismiss: {
                        showingResult = false
                        dismiss()
                    })
                }
            }
            .onChange(of: orchestrator.state) { _, newState in
                handleStateChange(newState)
            }
            .onDisappear {
                stopStatsTimer()
            }
            .onAppear {
                configureOrchestrator()
            }
        }
    }

    // MARK: - Subviews

    private var timerView: some View {
        Text(orchestrator.formattedDuration)
            .font(.system(size: 72, weight: .thin, design: .monospaced))
            .foregroundStyle(orchestrator.isRecording ? .primary : .secondary)
            .contentTransition(.numericText())
            .animation(.default, value: orchestrator.duration)
    }

    private var waveformView: some View {
        GeometryReader { geometry in
            let barCount = 20
            let spacing: CGFloat = 4
            let totalSpacing = spacing * CGFloat(barCount - 1)
            let availableWidth = max(0, geometry.size.width - totalSpacing)
            let barWidth = max(2, availableWidth / CGFloat(barCount))
            let barMaxHeight = max(4, geometry.size.height)

            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let level = audioLevelForBar(index)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barGradient)
                        .frame(width: barWidth, height: max(4, level * barMaxHeight))
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(orchestrator.isRecording ? 1 : 0.3)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [AppTheme.accent, AppTheme.accent.opacity(0.6)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var costEstimateView: some View {
        Group {
            if orchestrator.isRecording || orchestrator.duration > 0 {
                HStack(spacing: 12) {
                    // Cost estimate
                    VStack(spacing: 2) {
                        Text("Cost")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(orchestrator.formattedCost)
                            .font(.callout.monospacedDigit().bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())

                    // File size indicator (recording health)
                    HStack(spacing: 4) {
                        Image(systemName: recordingWriteErrors > 0 ? "exclamationmark.triangle.fill" : "doc.fill")
                            .font(.caption)
                            .foregroundStyle(recordingWriteErrors > 0 ? .orange : .secondary)
                        Text(String(format: "%.1f MB", recordingFileSizeMB))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
        }
    }

    private var statusView: some View {
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
                    Text("Ready to record")
                        .foregroundStyle(.secondary)

            case .recording(_, let isPaused):
                if isPaused {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(.orange)
                    Text("Paused")
                        .foregroundStyle(.orange)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                        .onDisappear { pulseAnimation = false }
                    Text("Recording")
                        .foregroundStyle(.primary)
                }

            case .stopping, .chunking, .transcribing, .mergingTranscripts, .generatingNotes, .savingToObsidian:
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(orchestrator.state.statusText)
                            .foregroundStyle(.secondary)
                    }
                    Text("Tap 'Background' to continue in background")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

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
        .padding(.horizontal)
    }

    private var controlsView: some View {
        HStack(spacing: 40) {
            // Pause/Resume button (only during recording)
            if orchestrator.isRecording {
                Button {
                    Task {
                        await orchestrator.togglePause()
                    }
                    HapticManager.selection()
                } label: {
                    Image(systemName: orchestrator.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(.secondary.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
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
    }

    private var mainButtonContent: some View {
        ZStack {
            Circle()
                .stroke(Color.red, lineWidth: 4)
                .frame(width: 80, height: 80)

            if orchestrator.isRecording {
                // Stop icon
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red)
                    .frame(width: 28, height: 28)
            } else if orchestrator.isProcessing {
                // Processing indicator
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                // Record icon
                Circle()
                    .fill(Color.red)
                    .frame(width: 64, height: 64)
            }
        }
    }

    // MARK: - Actions

    private func handleMainButtonTap() {
        HapticManager.mediumTap()

        Task {
            if orchestrator.isRecording {
                await orchestrator.stopRecording()
            } else if case .idle = orchestrator.state {
                do {
                    try await orchestrator.startRecording()
                } catch {
                    appLog("Failed to start meeting recording: \(error)", category: "Meeting", level: .error)
                }
            } else if case .error = orchestrator.state {
                orchestrator.reset()
            }
        }
    }

    /// Hand off transcription to background manager and dismiss
    private func continueInBackground() {
        guard let meetingId = orchestrator.currentMeetingId else {
            appLog("Cannot continue in background: no meeting ID", category: "Meeting", level: .error)
            return
        }

        HapticManager.lightTap()
        appLog("Continuing transcription in background for meeting: \(meetingId)", category: "Meeting")

        // Hand off to background manager
        BackgroundMeetingTranscriptionManager.shared.takeOverTranscription(
            orchestrator: orchestrator,
            meetingId: meetingId
        )

        // Dismiss the view
        dismiss()
    }

    private func configureOrchestrator() {
        appLog("Configuring meeting orchestrator", category: "Meeting")

        // Create audio recorder (shared implementation from Core)
        let recorder = MeetingAudioRecorderImpl()
        self.audioRecorder = recorder

        // Determine which provider to use based on context override
        let providerFactory = ProviderFactory(settings: settings)
        var transcriptionService: MeetingTranscriptionService?
        var providerName = "Default"
        var hasDiarization = false

        // Get selected context if any
        let selectedContext: ConversationContext? = {
            if let contextId = selectedContextId ?? orchestrator.settings.contextId {
                return settings.contexts.first(where: { $0.id == contextId })
            }
            return nil
        }()

        // Check if context has a transcription provider override
        if let context = selectedContext,
           let override = context.transcriptionProviderOverride {

            switch override.providerType {
            case .cloud(let provider):
                providerName = provider.displayName

                // AssemblyAI and Google have dedicated meeting services with diarization
                if provider == .assemblyAI {
                    if let config = settings.configuredAIProviders.first(where: { $0.provider == .assemblyAI && !$0.apiKey.isEmpty }),
                       let service = AssemblyAIMeetingService(config: config) {
                        transcriptionService = service
                        hasDiarization = true
                    }
                } else if provider == .google {
                    if let config = settings.configuredAIProviders.first(where: { $0.provider == .google && !$0.apiKey.isEmpty }),
                       let service = GoogleMeetingService(config: config) {
                        transcriptionService = service
                        hasDiarization = true
                    }
                } else {
                    // Use adapter for other providers (no diarization)
                    if let underlyingProvider = providerFactory.createTranscriptionProvider(for: provider) {
                        transcriptionService = TranscriptionProviderMeetingAdapter(provider: underlyingProvider)
                        hasDiarization = false
                    }
                }

            case .local(let localProvider):
                providerName = localProvider.displayName

                // Use adapter for local providers (no diarization)
                if let underlyingProvider = providerFactory.createTranscriptionProvider(for: override) {
                    transcriptionService = TranscriptionProviderMeetingAdapter(provider: underlyingProvider)
                    hasDiarization = false
                }
            }
        }

        // Fallback to diarization-capable providers (AssemblyAI, Google) if no context override
        if transcriptionService == nil {
            // Try AssemblyAI first (best diarization)
            if let assemblyConfig = settings.configuredAIProviders.first(where: { $0.provider == .assemblyAI && !$0.apiKey.isEmpty }),
               let service = AssemblyAIMeetingService(config: assemblyConfig) {
                transcriptionService = service
                providerName = "AssemblyAI"
                hasDiarization = true
            }
            // Try Google Cloud STT (also supports diarization)
            else if let googleConfig = settings.configuredAIProviders.first(where: { $0.provider == .google && !$0.apiKey.isEmpty }),
                    let service = GoogleMeetingService(config: googleConfig) {
                transcriptionService = service
                providerName = "Google Cloud"
                hasDiarization = true
            }
            // Try any configured transcription provider as last resort (no diarization)
            else {
                for config in settings.configuredAIProviders where config.isConfiguredForTranscription {
                    if let underlyingProvider = providerFactory.createTranscriptionProvider(for: config.provider) {
                        transcriptionService = TranscriptionProviderMeetingAdapter(provider: underlyingProvider)
                        providerName = config.provider.displayName
                        hasDiarization = false
                        break
                    }
                }
            }
        }

        // Check if we have a transcription service
        guard let service = transcriptionService else {
            configurationError = "No transcription provider configured. Please add an API key in Settings → Providers."
            appLog("Meeting recording: No transcription provider available", category: "Meeting", level: .error)
            return
        }

        // Configure orchestrator
        orchestrator.configure(
            audioRecorder: recorder,
            transcriptionService: service,
            notesGenerator: nil
        )

        // iOS always uses microphone-only (no system audio capture)
        orchestrator.settings.audioSource = .microphoneOnly

        // ALWAYS apply context settings if a context is selected (language, vocabulary)
        // This must happen regardless of whether provider override is set
        if let context = selectedContext {
            applyContextSettings(context)
        }

        // Disable diarization if provider doesn't support it
        if !hasDiarization {
            orchestrator.settings.requireDiarization = false
        }

        let diarizationStatus = hasDiarization ? "with diarization" : "without diarization"
        let languageInfo = orchestrator.settings.language ?? "auto"
        appLog("Meeting recording configured with \(providerName) (\(diarizationStatus)), language: \(languageInfo)", category: "Meeting")
    }

    /// Apply context settings to the meeting orchestrator
    /// Includes language, vocabulary, jargon, and other context-specific settings
    private func applyContextSettings(_ context: ConversationContext) {
        // Set language from context
        if context.autoDetectInputLanguage {
            orchestrator.settings.language = nil
        } else if let language = context.defaultInputLanguage {
            orchestrator.settings.language = language.rawValue
        }

        // Apply vocabulary/jargon from context
        let vocabulary = context.transcriptionVocabulary
        if !vocabulary.isEmpty {
            var wordBoost = Set(orchestrator.settings.wordBoost)
            wordBoost.formUnion(vocabulary)
            orchestrator.settings.wordBoost = Array(wordBoost)
        }

        // Set context ID for the meeting
        orchestrator.settings.contextId = context.id

        let langDesc = context.autoDetectInputLanguage ? "auto-detect" : (context.defaultInputLanguage?.rawValue ?? "auto")
        appLog("Applied context settings: language=\(langDesc), vocabulary=\(vocabulary.count) words", category: "Meeting")
    }

    // MARK: - Recording Stats Timer

    private func startStatsTimer() {
        stopStatsTimer()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard let recorder = audioRecorder else { return }
                let stats = await recorder.getRecordingStats()
                recordingFileSizeMB = Double(stats.fileSize) / (1024 * 1024)
                recordingWriteErrors = stats.errors
            }
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func handleStateChange(_ newState: MeetingRecordingState) {
        switch newState {
        case .recording(_, let isPaused):
            startStatsTimer()
            // Manage lock screen presence
            if !MeetingLockScreenPresenceManager.shared.isActive {
                MeetingLockScreenPresenceManager.shared.startPresence(title: meetingTitle.isEmpty ? "Meeting Recording" : meetingTitle)
            }
            if isPaused {
                MeetingLockScreenPresenceManager.shared.pausePresence()
            } else {
                MeetingLockScreenPresenceManager.shared.resumePresence()
            }
        case .stopping, .chunking, .transcribing, .mergingTranscripts, .generatingNotes, .savingToObsidian:
            stopStatsTimer()
            MeetingLockScreenPresenceManager.shared.stopPresence()
        case .complete(let record):
            stopStatsTimer()
            MeetingLockScreenPresenceManager.shared.stopPresence()
            HapticManager.success()
            showingResult = true
            // Save to Core Data for iCloud sync
            saveMeetingToCoreData(record)
        case .error:
            stopStatsTimer()
            MeetingLockScreenPresenceManager.shared.stopPresence()
            HapticManager.error()
        case .idle:
            stopStatsTimer()
            MeetingLockScreenPresenceManager.shared.stopPresence()
            recordingFileSizeMB = 0
            recordingWriteErrors = 0
        }
    }

    /// Save completed meeting to Core Data for iCloud sync across devices
    private func saveMeetingToCoreData(_ record: MeetingRecord) {
        CoreDataManager.shared.updateMeetingRecord(record)
        appLog("Meeting saved to Core Data for iCloud sync: \(record.title)", category: "Meeting")
    }

    private func audioLevelForBar(_ index: Int) -> CGFloat {
        let baseLevel = CGFloat(orchestrator.audioLevel)
        let variance = sin(Double(index) * 0.5 + Date().timeIntervalSinceReferenceDate * 2) * 0.3
        return max(0.05, min(1.0, baseLevel + variance * baseLevel))
    }
}

// MARK: - Meeting Settings Sheet

struct MeetingSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: MeetingSettings
    var contexts: [ConversationContext] = []

    // Selected context for UI binding
    @State private var selectedContextId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                // Context picker for vocabulary hints
                Section("Context") {
                    Picker("Use Context", selection: $selectedContextId) {
                        Text("None")
                            .tag(nil as UUID?)

                        ForEach(contexts) { context in
                            // Concatenate emoji + name for proper picker display
                            Text("\(context.icon) \(context.name)\(context.domainJargon != .none ? " • \(context.domainJargon.displayName)" : "")")
                                .tag(context.id as UUID?)
                        }
                    }
                    .onChange(of: selectedContextId) { _, newValue in
                        settings.setContext(id: newValue, from: contexts)
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

                Section("Recording") {
                    Stepper("Max Duration: \(settings.maxDurationMinutes) min",
                            value: $settings.maxDurationMinutes,
                            in: 15...180,
                            step: 15)

                    Toggle("Require Speaker Diarization", isOn: $settings.requireDiarization)

                    if settings.requireDiarization {
                        Picker("Expected Speakers", selection: Binding(
                            get: { settings.expectedSpeakerCount },
                            set: { settings.expectedSpeakerCount = $0 }
                        )) {
                            Text("Auto").tag(nil as Int?)
                            ForEach(1...10, id: \.self) { count in
                                Text("\(count)").tag(count as Int?)
                            }
                        }
                    }
                }

                Section("Output") {
                    Toggle("Include Timestamps", isOn: $settings.includeTimestamps)
                    Toggle("Auto-save to Obsidian", isOn: $settings.autoSaveToObsidian)
                }

                Section {
                    Text("Speaker diarization identifies who said what in the recording. Works with AssemblyAI and Google Cloud Speech-to-Text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Meeting Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                selectedContextId = settings.contextId
            }
        }
    }
}

// MARK: - Meeting Result View

struct MeetingResultView: View {
    let record: MeetingRecord
    let onDismiss: () -> Void

    @State private var selectedTab = 0
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    Text("Notes").tag(0)
                    Text("Transcript").tag(1)
                    if record.diarizedTranscript != nil {
                        Text("Speakers").tag(2)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                ScrollView {
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
            }
            .navigationTitle(record.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                MeetingShareSheet(items: [shareText])
            }
        }
    }

    private var notesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let notes = record.generatedNotes {
                Text(notes)
                    .font(.body)
            } else {
                ContentUnavailableView(
                    "No Notes Generated",
                    systemImage: "doc.text",
                    description: Text("Meeting notes will appear here after processing")
                )
            }
        }
        .padding()
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(record.bestTranscript)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
    }

    private var speakersView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let diarized = record.diarizedTranscript {
                ForEach(diarized.speakers, id: \.self) { speaker in
                    speakerSection(for: speaker, in: diarized)
                }
            }
        }
        .padding()
    }

    private func speakerSection(for speaker: String, in transcript: DiarizedTranscript) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.teal)
                Text(transcript.displayName(for: speaker))
                    .font(.headline)
            }

            let speakerSegments = transcript.segments.filter { $0.speaker == speaker }
            Text("\(speakerSegments.count) segments")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
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

// MARK: - Share Sheet

private struct MeetingShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    MeetingRecordingView()
        .environmentObject(SharedSettings.shared)
}
