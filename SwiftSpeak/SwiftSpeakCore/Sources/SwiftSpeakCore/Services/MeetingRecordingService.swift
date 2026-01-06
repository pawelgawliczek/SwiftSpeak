//
//  MeetingRecordingService.swift
//  SwiftSpeakCore
//
//  Shared meeting recording orchestration service
//  Used by both iOS and macOS for meeting recording logic
//

import Foundation
import Combine

// MARK: - Meeting Recording Delegate

/// Protocol for receiving meeting recording events
/// Implemented by platform-specific ViewModels
public protocol MeetingRecordingDelegate: AnyObject, Sendable {
    /// Called when recording state changes
    func meetingRecordingStateDidChange(_ state: MeetingRecordingState) async

    /// Called when recording duration updates
    func meetingRecordingDurationDidUpdate(_ duration: TimeInterval) async

    /// Called when audio levels update (for visualization)
    func meetingRecordingAudioLevelDidUpdate(_ level: Float) async

    /// Called when estimated cost updates
    func meetingRecordingCostDidUpdate(_ cost: Double) async
}

// MARK: - Audio Recorder Protocol

/// Protocol for platform-specific audio recording
public protocol MeetingAudioRecorder: Sendable {
    /// Whether recording is currently active
    var isRecording: Bool { get async }

    /// Whether recording is paused
    var isPaused: Bool { get async }

    /// Current recording duration
    var currentDuration: TimeInterval { get async }

    /// Start recording to the specified URL
    func startRecording(to url: URL) async throws

    /// Pause the current recording
    func pauseRecording() async

    /// Resume a paused recording
    func resumeRecording() async

    /// Stop recording and return the final audio URL
    func stopRecording() async throws -> URL

    /// Get current audio level (0.0 - 1.0) for visualization
    func getCurrentLevel() async -> Float
}

// MARK: - Dual-Source Audio Recorder Protocol

/// Result from dual-source recording containing separate audio tracks
public struct DualSourceRecordingResult: Sendable {
    /// Audio from microphone (user's voice)
    public let microphoneURL: URL

    /// Audio from system/app (remote participants)
    public let systemAudioURL: URL?

    /// Combined audio file (for processing as single source fallback)
    public let combinedURL: URL

    public init(microphoneURL: URL, systemAudioURL: URL?, combinedURL: URL) {
        self.microphoneURL = microphoneURL
        self.systemAudioURL = systemAudioURL
        self.combinedURL = combinedURL
    }
}

/// Extended protocol for recorders that support dual-source recording (macOS)
public protocol DualSourceMeetingAudioRecorder: MeetingAudioRecorder {
    /// Whether dual-source recording is available
    var isDualSourceAvailable: Bool { get async }

    /// List available audio applications for system audio capture
    func listAudioApplications() async throws -> [AudioApplication]

    /// Start dual-source recording
    /// - Parameters:
    ///   - microphoneURL: Where to save microphone audio
    ///   - systemAudioURL: Where to save system audio
    ///   - combinedURL: Where to save combined audio
    ///   - targetApp: Optional specific app to capture (nil = all system audio)
    func startDualSourceRecording(
        microphoneURL: URL,
        systemAudioURL: URL,
        combinedURL: URL,
        targetApp: AudioApplication?
    ) async throws

    /// Stop dual-source recording and return both tracks
    func stopDualSourceRecording() async throws -> DualSourceRecordingResult

    /// Get current microphone level (user's voice)
    func getMicrophoneLevel() async -> Float

    /// Get current system audio level (remote participants)
    func getSystemAudioLevel() async -> Float
}

/// Represents an application that can be captured for audio
public struct AudioApplication: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String
    public let icon: Data?  // PNG data for app icon

    public init(id: String, name: String, bundleIdentifier: String, icon: Data? = nil) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
    }

    /// Common meeting apps
    public static let commonMeetingApps: [String] = [
        "us.zoom.xos",           // Zoom
        "com.microsoft.teams",   // Microsoft Teams
        "com.google.Chrome",     // Google Meet (via Chrome)
        "com.apple.Safari",      // Google Meet (via Safari)
        "com.slack.Slack",       // Slack huddles
        "com.webex.meetingmanager", // Webex
        "com.discord.Discord"    // Discord
    ]
}

// MARK: - Meeting Transcription Provider

/// Protocol for transcription services with optional diarization
public protocol MeetingTranscriptionService: Sendable {
    /// Whether this service supports speaker diarization
    var supportsDiarization: Bool { get }

    /// Transcribe audio with optional diarization
    /// - Parameters:
    ///   - audioURL: URL to the audio file
    ///   - withDiarization: Whether to enable speaker diarization
    ///   - language: Language code (e.g., "en")
    ///   - speakerCount: Expected number of speakers (helps accuracy)
    ///   - wordBoost: Custom vocabulary words to boost (improves recognition of jargon/names)
    func transcribe(
        audioURL: URL,
        withDiarization: Bool,
        language: String?,
        speakerCount: Int?,
        wordBoost: [String]?
    ) async throws -> DiarizedTranscriptionResult
}

// MARK: - Meeting Notes Generator

/// Protocol for AI-powered meeting notes generation
public protocol MeetingNotesGenerator: Sendable {
    /// Generate meeting notes from transcript
    func generateNotes(
        from transcript: String,
        diarization: DiarizedTranscript?,
        powerModeInstruction: String?
    ) async throws -> String
}

// MARK: - Meeting Recording Service

/// Shared orchestration service for meeting recording
/// Coordinates audio recording, transcription, and note generation
@MainActor
public final class MeetingRecordingOrchestrator: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var state: MeetingRecordingState = .idle
    @Published public private(set) var duration: TimeInterval = 0
    @Published public private(set) var audioLevel: Float = 0
    @Published public private(set) var estimatedCost: Double = 0

    // MARK: - Configuration

    @Published public var settings: MeetingSettings = .default
    public var powerModeInstruction: String?

    // MARK: - Dependencies

    private let audioChunker: AudioChunker

    // Injected services (platform-specific)
    private var audioRecorder: MeetingAudioRecorder?
    private var transcriptionService: MeetingTranscriptionService?
    private var notesGenerator: MeetingNotesGenerator?

    // MARK: - Internal State

    private var recordingURL: URL?
    private var durationTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    private var pausedDuration: TimeInterval = 0

    // Dual-source recording state
    private var isDualSourceRecording = false
    private var microphoneURL: URL?
    private var systemAudioURL: URL?
    private var combinedURL: URL?

    // Meeting history tracking
    private var currentMeetingId: UUID?
    private var meetingTitle: String = "Meeting"

    // Cost estimation constants (AssemblyAI Universal rate)
    private let costPerMinute: Double = 0.0025

    // MARK: - Initialization

    public init(audioChunker: AudioChunker = AudioChunker()) {
        self.audioChunker = audioChunker
    }

    /// Configure the service with platform-specific implementations
    public func configure(
        audioRecorder: MeetingAudioRecorder,
        transcriptionService: MeetingTranscriptionService,
        notesGenerator: MeetingNotesGenerator? = nil
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.notesGenerator = notesGenerator
    }

    // MARK: - Recording Control

    /// Start a new meeting recording
    /// - Parameter title: Optional meeting title (defaults to "Meeting YYYY-MM-DD HH:MM")
    public func startRecording(title: String? = nil) async throws {
        guard let audioRecorder = audioRecorder else {
            throw MeetingRecordingError.recordingFailed("Audio recorder not configured")
        }

        // Generate meeting title
        meetingTitle = title ?? "Meeting \(formattedDate(Date()))"

        // Create meeting record in history manager - this gives us a permanent audio URL
        // CRITICAL: This ensures audio is saved immediately and never lost
        let (meetingId, audioURL) = MeetingHistoryManager.shared.createMeeting(
            title: meetingTitle,
            settings: settings
        )
        currentMeetingId = meetingId

        let timestamp = Date().timeIntervalSince1970

        // Check if dual-source recording is available and requested
        if settings.audioSource == .microphoneAndSystemAudio,
           let dualRecorder = audioRecorder as? DualSourceMeetingAudioRecorder,
           await dualRecorder.isDualSourceAvailable {
            // Dual-source mode
            isDualSourceRecording = true

            // Use temp files for mic and system, but permanent URL for combined
            microphoneURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("meeting_mic_\(timestamp).m4a")
            systemAudioURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("meeting_sys_\(timestamp).m4a")
            combinedURL = audioURL  // Permanent location from history manager
            recordingURL = combinedURL

            try await dualRecorder.startDualSourceRecording(
                microphoneURL: microphoneURL!,
                systemAudioURL: systemAudioURL!,
                combinedURL: combinedURL!,
                targetApp: nil  // Capture all system audio for now
            )
        } else {
            // Single-source mode (microphone only)
            isDualSourceRecording = false
            recordingURL = audioURL  // Permanent location from history manager

            try await audioRecorder.startRecording(to: audioURL)
        }

        // Update state
        recordingStartTime = Date()
        pausedDuration = 0
        duration = 0
        state = .recording(duration: 0, isPaused: false)

        // Start timers
        startTimers()
    }

    /// Pause the current recording
    public func pauseRecording() async {
        guard let audioRecorder = audioRecorder else { return }
        await audioRecorder.pauseRecording()
        state = .recording(duration: duration, isPaused: true)
    }

    /// Resume a paused recording
    public func resumeRecording() async {
        guard let audioRecorder = audioRecorder else { return }
        await audioRecorder.resumeRecording()
        state = .recording(duration: duration, isPaused: false)
    }

    /// Toggle pause state
    public func togglePause() async {
        if case .recording(_, let isPaused) = state {
            if isPaused {
                await resumeRecording()
            } else {
                await pauseRecording()
            }
        }
    }

    /// Stop recording and process the meeting
    public func stopRecording() async {
        guard let audioRecorder = audioRecorder else {
            return
        }

        // Stop timers
        stopTimers()

        // Stop recording
        state = .stopping
        do {
            if isDualSourceRecording,
               let dualRecorder = audioRecorder as? DualSourceMeetingAudioRecorder {
                // Dual-source: get both tracks
                let result = try await dualRecorder.stopDualSourceRecording()

                // Update history: recording completed, pending transcription
                if let meetingId = currentMeetingId {
                    MeetingHistoryManager.shared.recordingCompleted(
                        id: meetingId,
                        duration: duration,
                        estimatedCost: estimatedCost
                    )
                }

                await processDualSourceRecording(result: result)
            } else {
                // Single-source
                let finalURL = try await audioRecorder.stopRecording()

                // Update history: recording completed, pending transcription
                if let meetingId = currentMeetingId {
                    MeetingHistoryManager.shared.recordingCompleted(
                        id: meetingId,
                        duration: duration,
                        estimatedCost: estimatedCost
                    )
                }

                await processRecording(url: finalURL)
            }
        } catch {
            // Recording failed - mark as failed in history
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionFailed(
                    id: meetingId,
                    error: "Recording failed: \(error.localizedDescription)"
                )
            }
            state = .error(.recordingFailed(error.localizedDescription))
        }
    }

    /// Cancel the current recording
    /// - Parameter deleteAudio: Whether to delete the audio file (default: false to preserve for potential recovery)
    public func cancelRecording(deleteAudio: Bool = false) async {
        stopTimers()

        if let audioRecorder = audioRecorder {
            _ = try? await audioRecorder.stopRecording()
        }

        // Update history: cancelled
        if let meetingId = currentMeetingId {
            MeetingHistoryManager.shared.cancelMeeting(id: meetingId, deleteAudio: deleteAudio)
        }

        // Clean up temp files only (not the permanent audio)
        if isDualSourceRecording {
            if let micURL = microphoneURL {
                try? FileManager.default.removeItem(at: micURL)
            }
            if let sysURL = systemAudioURL {
                try? FileManager.default.removeItem(at: sysURL)
            }
        }

        recordingURL = nil
        currentMeetingId = nil
        state = .error(.cancelled)
        resetState()
    }

    /// Reset to idle state
    public func reset() {
        stopTimers()
        resetState()
        state = .idle
    }

    // MARK: - Processing Pipeline

    /// Process dual-source recording (microphone + system audio)
    private func processDualSourceRecording(result: DualSourceRecordingResult) async {
        guard let transcriptionService = transcriptionService else {
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionFailed(
                    id: meetingId,
                    error: "Transcription service not configured"
                )
            }
            state = .error(.transcriptionFailed("Transcription service not configured"))
            return
        }

        // Update history: transcription started
        if let meetingId = currentMeetingId {
            MeetingHistoryManager.shared.transcriptionStarted(id: meetingId, provider: "AssemblyAI")
        }

        do {
            // Step 1: Transcribe microphone (user's voice) - no diarization needed
            state = .transcribing(chunkIndex: 0, totalChunks: 2)

            let microphoneResult = try await transcriptionService.transcribe(
                audioURL: result.microphoneURL,
                withDiarization: false,  // User is single speaker
                language: settings.language,
                speakerCount: 1,
                wordBoost: settings.wordBoost.isEmpty ? nil : settings.wordBoost
            )

            // Step 2: Transcribe system audio (remote participants) - with diarization
            state = .transcribing(chunkIndex: 1, totalChunks: 2)

            var systemResult: DiarizedTranscriptionResult?
            if let systemURL = result.systemAudioURL,
               FileManager.default.fileExists(atPath: systemURL.path) {
                // Only transcribe if system audio has content
                let attributes = try? FileManager.default.attributesOfItem(atPath: systemURL.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0

                if fileSize > 1000 {
                    systemResult = try await transcriptionService.transcribe(
                        audioURL: systemURL,
                        withDiarization: settings.requireDiarization && transcriptionService.supportsDiarization,
                        language: settings.language,
                        speakerCount: settings.expectedSpeakerCount.map { max(1, $0 - 1) },  // Minus the user
                        wordBoost: settings.wordBoost.isEmpty ? nil : settings.wordBoost
                    )
                }
            }

            // Step 3: Merge transcripts
            state = .mergingTranscripts

            let finalTranscript = mergeDualSourceTranscripts(
                userTranscript: microphoneResult,
                remoteTranscript: systemResult
            )

            // Step 4: Generate meeting notes (optional)
            var generatedNotes: String?
            if let generator = notesGenerator, powerModeInstruction != nil {
                state = .generatingNotes
                generatedNotes = try await generator.generateNotes(
                    from: finalTranscript.text,
                    diarization: finalTranscript.diarization,
                    powerModeInstruction: powerModeInstruction
                )
            }

            // Step 5: Update history with transcription success
            // CRITICAL: This is when audio can be deleted (handled by history manager)
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionCompleted(
                    id: meetingId,
                    plainTranscript: finalTranscript.text,
                    diarizedTranscript: finalTranscript.diarization,
                    generatedNotes: generatedNotes
                )
            }

            // Clean up temp files (mic/system - not combined, which is permanent)
            try? FileManager.default.removeItem(at: result.microphoneURL)
            if let sysURL = result.systemAudioURL {
                try? FileManager.default.removeItem(at: sysURL)
            }

            // Get the updated meeting record from history
            let record: MeetingRecord
            if let meetingId = currentMeetingId,
               let historyRecord = MeetingHistoryManager.shared.meeting(id: meetingId) {
                record = historyRecord
            } else {
                // Fallback: create record manually (shouldn't happen)
                record = MeetingRecord(
                    title: meetingTitle,
                    duration: duration,
                    status: .completed,
                    diarizedTranscript: finalTranscript.diarization,
                    plainTranscript: finalTranscript.text,
                    generatedNotes: generatedNotes,
                    estimatedCost: estimatedCost,
                    provider: "AssemblyAI",
                    settings: settings
                )
            }

            currentMeetingId = nil
            state = .complete(record)

        } catch {
            // Update history: transcription failed
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionFailed(
                    id: meetingId,
                    error: error.localizedDescription
                )
            }
            state = .error(.transcriptionFailed(error.localizedDescription))
        }
    }

    /// Merge user (microphone) and remote (system audio) transcripts
    private func mergeDualSourceTranscripts(
        userTranscript: DiarizedTranscriptionResult,
        remoteTranscript: DiarizedTranscriptionResult?
    ) -> DiarizedTranscriptionResult {
        let userName = settings.userDisplayName

        // If no remote transcript or no diarization, just tag user segments
        guard let remote = remoteTranscript else {
            // Create simple diarized transcript with user only
            let userSegments = [SpeakerSegment(
                speaker: "USER",
                text: userTranscript.text,
                startMs: 0,
                endMs: Int(userTranscript.duration * 1000),
                confidence: 1.0
            )]

            let diarization = DiarizedTranscript(
                segments: userSegments,
                speakerNames: ["USER": userName]
            )

            return DiarizedTranscriptionResult(
                text: "[\(userName)]: \(userTranscript.text)",
                language: userTranscript.language,
                duration: userTranscript.duration,
                diarization: diarization
            )
        }

        // Merge user segments with remote segments
        var allSegments: [SpeakerSegment] = []
        var speakerNames: [String: String] = ["USER": userName]

        // Add user segments (tagged as USER)
        // For now, treat entire user transcript as one segment
        // In the future, could use VAD to split into multiple segments
        if !userTranscript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            allSegments.append(SpeakerSegment(
                speaker: "USER",
                text: userTranscript.text,
                startMs: 0,
                endMs: Int(userTranscript.duration * 1000),
                confidence: 1.0
            ))
        }

        // Add remote segments (from diarization)
        if let remoteDiarization = remote.diarization {
            // Rename remote speakers to avoid collision with USER
            for segment in remoteDiarization.segments {
                let remoteId = "REMOTE_\(segment.speaker)"
                allSegments.append(SpeakerSegment(
                    speaker: remoteId,
                    text: segment.text,
                    startMs: segment.startMs,
                    endMs: segment.endMs,
                    confidence: segment.confidence
                ))

                // Copy speaker names
                if let name = remoteDiarization.speakerNames[segment.speaker] {
                    speakerNames[remoteId] = name
                } else {
                    speakerNames[remoteId] = "Participant \(segment.speaker)"
                }
            }
        } else if !remote.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // No diarization, just add as single participant
            allSegments.append(SpeakerSegment(
                speaker: "REMOTE_A",
                text: remote.text,
                startMs: 0,
                endMs: Int(remote.duration * 1000),
                confidence: 1.0
            ))
            speakerNames["REMOTE_A"] = "Participant"
        }

        // Sort by start time
        allSegments.sort { $0.startMs < $1.startMs }

        // Create merged diarized transcript
        let mergedDiarization = DiarizedTranscript(
            segments: allSegments,
            speakerNames: speakerNames
        )

        // Create formatted text
        let formattedText = mergedDiarization.formattedText

        return DiarizedTranscriptionResult(
            text: formattedText,
            language: userTranscript.language ?? remote.language,
            duration: max(userTranscript.duration, remote.duration),
            diarization: mergedDiarization
        )
    }

    private func processRecording(url: URL) async {
        guard let transcriptionService = transcriptionService else {
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionFailed(
                    id: meetingId,
                    error: "Transcription service not configured"
                )
            }
            state = .error(.transcriptionFailed("Transcription service not configured"))
            return
        }

        // Update history: transcription started
        if let meetingId = currentMeetingId {
            MeetingHistoryManager.shared.transcriptionStarted(id: meetingId, provider: "AssemblyAI")
        }

        do {
            // Step 1: Check if chunking is needed
            let chunks: [URL]
            if try await audioChunker.needsChunking(audioURL: url) {
                state = .chunking(progress: 0)
                chunks = try await audioChunker.chunkIfNeeded(audioURL: url) { [weak self] progress in
                    await MainActor.run {
                        self?.state = .chunking(progress: progress)
                    }
                }
            } else {
                chunks = [url]
            }

            // Step 2: Transcribe each chunk
            var transcripts: [DiarizedTranscriptionResult] = []
            let useDiarization = settings.requireDiarization && transcriptionService.supportsDiarization

            for (index, chunkURL) in chunks.enumerated() {
                state = .transcribing(chunkIndex: index, totalChunks: chunks.count)

                let result = try await transcriptionService.transcribe(
                    audioURL: chunkURL,
                    withDiarization: useDiarization,
                    language: settings.language,
                    speakerCount: settings.expectedSpeakerCount,
                    wordBoost: settings.wordBoost.isEmpty ? nil : settings.wordBoost
                )
                transcripts.append(result)
            }

            // Step 3: Merge transcripts if multiple chunks
            state = .mergingTranscripts
            let finalTranscript: DiarizedTranscriptionResult
            if transcripts.count > 1 {
                let mergedText = await audioChunker.mergeTexts(transcripts.map { $0.text })
                let mergedDiarization: DiarizedTranscript?
                if useDiarization {
                    let diarizations = transcripts.compactMap { $0.diarization }
                    mergedDiarization = await audioChunker.mergeTranscripts(diarizations)
                } else {
                    mergedDiarization = nil
                }

                finalTranscript = DiarizedTranscriptionResult(
                    text: mergedText,
                    language: transcripts.first?.language,
                    duration: duration,
                    diarization: mergedDiarization
                )
            } else {
                finalTranscript = transcripts[0]
            }

            // Step 4: Generate meeting notes (optional)
            var generatedNotes: String?
            if let generator = notesGenerator, powerModeInstruction != nil {
                state = .generatingNotes
                generatedNotes = try await generator.generateNotes(
                    from: finalTranscript.text,
                    diarization: finalTranscript.diarization,
                    powerModeInstruction: powerModeInstruction
                )
            }

            // Step 5: Update history with transcription success
            // CRITICAL: This is when audio can be deleted (handled by history manager)
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionCompleted(
                    id: meetingId,
                    plainTranscript: finalTranscript.text,
                    diarizedTranscript: finalTranscript.diarization,
                    generatedNotes: generatedNotes
                )
            }

            // Clean up chunks (but not original - that's now managed by history manager)
            if chunks.count > 1 {
                await audioChunker.cleanupChunks(chunks)
            }

            // Get the updated meeting record from history
            let record: MeetingRecord
            if let meetingId = currentMeetingId,
               let historyRecord = MeetingHistoryManager.shared.meeting(id: meetingId) {
                record = historyRecord
            } else {
                // Fallback: create record manually (shouldn't happen)
                record = MeetingRecord(
                    title: meetingTitle,
                    duration: duration,
                    status: .completed,
                    diarizedTranscript: finalTranscript.diarization,
                    plainTranscript: finalTranscript.text,
                    generatedNotes: generatedNotes,
                    estimatedCost: estimatedCost,
                    provider: "AssemblyAI",
                    settings: settings
                )
            }

            currentMeetingId = nil
            state = .complete(record)

        } catch {
            // Update history: transcription failed
            if let meetingId = currentMeetingId {
                MeetingHistoryManager.shared.transcriptionFailed(
                    id: meetingId,
                    error: error.localizedDescription
                )
            }
            state = .error(.transcriptionFailed(error.localizedDescription))
        }
    }

    // MARK: - Timer Management

    private func startTimers() {
        // Duration timer - update every second
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateDuration()
            }
        }

        // Audio level timer - update frequently for smooth visualization
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateAudioLevel()
            }
        }
    }

    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateDuration() async {
        guard let audioRecorder = audioRecorder else { return }

        // Check if we're paused
        if case .recording(_, let isPaused) = state, isPaused {
            return
        }

        let currentDuration = await audioRecorder.currentDuration
        duration = currentDuration

        // Update estimated cost
        let minutes = duration / 60.0
        estimatedCost = minutes * costPerMinute

        // Update state with new duration
        if case .recording(_, let isPaused) = state {
            state = .recording(duration: duration, isPaused: isPaused)
        }

        // Check max duration
        let maxSeconds = TimeInterval(settings.maxDurationMinutes * 60)
        if duration >= maxSeconds {
            await stopRecording()
            state = .error(.maxDurationExceeded)
        }
    }

    private func updateAudioLevel() async {
        guard let audioRecorder = audioRecorder else { return }
        audioLevel = await audioRecorder.getCurrentLevel()
    }

    private func resetState() {
        duration = 0
        audioLevel = 0
        estimatedCost = 0
        recordingURL = nil
        recordingStartTime = nil
        pausedDuration = 0
        isDualSourceRecording = false
        microphoneURL = nil
        systemAudioURL = nil
        combinedURL = nil
        meetingTitle = "Meeting"
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Computed Properties

    /// Formatted duration string (HH:MM:SS or MM:SS)
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Formatted estimated cost string
    public var formattedCost: String {
        String(format: "$%.4f", estimatedCost)
    }

    /// Whether recording is active (including paused)
    public var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    /// Whether recording is paused
    public var isPaused: Bool {
        if case .recording(_, let paused) = state { return paused }
        return false
    }

    /// Whether any processing is happening
    public var isProcessing: Bool {
        state.isProcessing
    }

    /// Current meeting ID being recorded/processed
    public var currentMeeting: UUID? {
        currentMeetingId
    }

    // MARK: - Retry Support

    /// Retry transcription for a failed meeting
    /// - Parameter meetingId: The ID of the meeting to retry
    public func retryTranscription(meetingId: UUID) async throws {
        guard let meeting = MeetingHistoryManager.shared.meeting(id: meetingId),
              meeting.status.canRetry else {
            throw MeetingRecordingError.transcriptionFailed("Meeting cannot be retried")
        }

        guard let audioURL = MeetingHistoryManager.shared.audioURL(for: meeting) else {
            throw MeetingRecordingError.transcriptionFailed("Audio file not found")
        }

        // Set up for retry
        currentMeetingId = meetingId
        meetingTitle = meeting.title
        settings = meeting.settings
        duration = meeting.duration
        estimatedCost = meeting.estimatedCost ?? 0

        // Process the recording
        await processRecording(url: audioURL)
    }
}
