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

    // State
    @State private var showingSettings = false
    @State private var showingResult = false
    @State private var meetingTitle = ""

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
                    Button("Cancel") {
                        Task {
                            await orchestrator.cancelRecording()
                        }
                        dismiss()
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
                if case .complete = newState {
                    HapticManager.success()
                    showingResult = true
                } else if case .error = newState {
                    HapticManager.error()
                }
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
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    let level = audioLevelForBar(index)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barGradient)
                        .frame(width: (geometry.size.width - 76) / 20, height: max(4, level * geometry.size.height))
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(orchestrator.isRecording ? 1 : 0.3)
    }

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryColor.opacity(0.6)],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var costEstimateView: some View {
        Group {
            if orchestrator.isRecording || orchestrator.duration > 0 {
                VStack(spacing: 4) {
                    Text("Estimated Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(orchestrator.formattedCost)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var statusView: some View {
        HStack(spacing: 8) {
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
                ProgressView()
                    .scaleEffect(0.8)
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
            .disabled(orchestrator.isProcessing)
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
        HapticManager.impact(style: .medium)

        Task {
            if orchestrator.isRecording {
                await orchestrator.stopRecording()
            } else if case .idle = orchestrator.state {
                do {
                    try await orchestrator.startRecording()
                } catch {
                    appLog("Failed to start meeting recording: \(error)", level: .error, category: "Meeting")
                }
            } else if case .error = orchestrator.state {
                orchestrator.reset()
            }
        }
    }

    private func configureOrchestrator() {
        // TODO: Configure with actual audio recorder and transcription service
        // This will be done when integrating with the app's service layer
        appLog("Meeting recording view appeared", category: "Meeting")
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
                        Stepper("Expected Speakers: \(settings.expectedSpeakerCount ?? 2)",
                                value: Binding(
                                    get: { settings.expectedSpeakerCount ?? 2 },
                                    set: { settings.expectedSpeakerCount = $0 }
                                ),
                                in: 2...10)
                    }
                }

                Section("Output") {
                    Toggle("Include Timestamps", isOn: $settings.includeTimestamps)
                    Toggle("Auto-save to Obsidian", isOn: $settings.autoSaveToObsidian)
                }

                Section {
                    Text("Speaker diarization identifies who said what in the recording. It works best with AssemblyAI.")
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
                ShareSheet(items: [shareText])
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    MeetingRecordingView()
        .environmentObject(SharedSettings())
}
