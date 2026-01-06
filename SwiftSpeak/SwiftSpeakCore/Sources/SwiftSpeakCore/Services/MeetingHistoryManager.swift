//
//  MeetingHistoryManager.swift
//  SwiftSpeakCore
//
//  Persistent storage for meeting recordings
//  CRITICAL: Audio files are preserved until transcription succeeds
//  Supports retry for failed transcriptions
//

import Foundation

// MARK: - Meeting History Manager

/// Manages persistent storage of meeting recordings
/// Audio files are NEVER deleted until transcription succeeds
@MainActor
public final class MeetingHistoryManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = MeetingHistoryManager()

    // MARK: - Published State

    @Published public private(set) var meetings: [MeetingRecord] = []
    @Published public private(set) var isLoading = false

    // MARK: - Directories

    /// Base directory for all meeting data
    private var meetingsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SwiftSpeak/Meetings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Directory for audio files
    private var audioDirectory: URL {
        let dir = meetingsDirectory.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Path to meetings index file
    private var indexPath: URL {
        meetingsDirectory.appendingPathComponent("meetings.json")
    }

    // MARK: - Initialization

    private init() {
        loadMeetings()
    }

    // MARK: - Public API

    /// Create a new meeting record when recording starts
    /// Returns the meeting ID and audio file URL to record to
    public func createMeeting(title: String, settings: MeetingSettings) -> (id: UUID, audioURL: URL) {
        let id = UUID()
        let audioFileName = "\(id.uuidString).m4a"
        let audioURL = audioDirectory.appendingPathComponent(audioFileName)

        let meeting = MeetingRecord(
            id: id,
            title: title,
            status: .recording,
            settings: settings,
            audioFileName: audioFileName
        )

        meetings.insert(meeting, at: 0)
        saveMeetings()

        return (id, audioURL)
    }

    /// Update meeting when recording stops (before transcription)
    public func recordingCompleted(id: UUID, duration: TimeInterval, estimatedCost: Double?) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }

        meetings[index].duration = duration
        meetings[index].estimatedCost = estimatedCost
        meetings[index].status = .pendingTranscription
        saveMeetings()
    }

    /// Update meeting when transcription starts
    public func transcriptionStarted(id: UUID, provider: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }

        meetings[index].status = .transcribing
        meetings[index].provider = provider
        meetings[index].transcriptionAttempts += 1
        meetings[index].errorMessage = nil
        saveMeetings()
    }

    /// Update meeting when transcription succeeds
    /// CRITICAL: Only now can audio be deleted
    public func transcriptionCompleted(
        id: UUID,
        plainTranscript: String,
        diarizedTranscript: DiarizedTranscript?,
        generatedNotes: String?
    ) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }

        meetings[index].status = .completed
        meetings[index].plainTranscript = plainTranscript
        meetings[index].diarizedTranscript = diarizedTranscript
        meetings[index].generatedNotes = generatedNotes
        meetings[index].errorMessage = nil
        saveMeetings()

        // Now safe to delete audio file
        deleteAudioFile(for: meetings[index])
    }

    /// Update meeting when transcription fails
    /// Audio is preserved for retry
    public func transcriptionFailed(id: UUID, error: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }

        meetings[index].status = .transcriptionFailed
        meetings[index].errorMessage = error
        saveMeetings()
        // Audio file is NOT deleted - can retry later
    }

    /// Cancel a meeting recording
    public func cancelMeeting(id: UUID, deleteAudio: Bool = false) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }

        meetings[index].status = .cancelled
        saveMeetings()

        if deleteAudio {
            deleteAudioFile(for: meetings[index])
        }
    }

    /// Delete a meeting record
    /// Only allowed if status permits deletion
    public func deleteMeeting(id: UUID) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }

        let meeting = meetings[index]
        guard meeting.status.canDelete else { return }

        // Delete audio file if exists
        deleteAudioFile(for: meeting)

        // Remove from list
        meetings.remove(at: index)
        saveMeetings()
    }

    /// Get the audio URL for a meeting
    public func audioURL(for meeting: MeetingRecord) -> URL? {
        guard let fileName = meeting.audioFileName else { return nil }
        let url = audioDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Get meeting by ID
    public func meeting(id: UUID) -> MeetingRecord? {
        meetings.first { $0.id == id }
    }

    /// Get meetings that need transcription (pending or failed)
    public var pendingMeetings: [MeetingRecord] {
        meetings.filter { $0.status.canRetry }
    }

    /// Update meeting title
    public func updateTitle(id: UUID, title: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        meetings[index].title = title
        saveMeetings()
    }

    /// Update meeting with Obsidian path
    public func savedToObsidian(id: UUID, path: String) {
        guard let index = meetings.firstIndex(where: { $0.id == id }) else { return }
        meetings[index].obsidianNotePath = path
        saveMeetings()
    }

    // MARK: - Persistence

    private func loadMeetings() {
        isLoading = true
        defer { isLoading = false }

        guard FileManager.default.fileExists(atPath: indexPath.path) else {
            meetings = []
            return
        }

        do {
            let data = try Data(contentsOf: indexPath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            meetings = try decoder.decode([MeetingRecord].self, from: data)

            // Sort by date, newest first
            meetings.sort { $0.recordedAt > $1.recordedAt }
        } catch {
            print("Failed to load meetings: \(error)")
            meetings = []
        }
    }

    private func saveMeetings() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(meetings)
            try data.write(to: indexPath, options: .atomic)
        } catch {
            print("Failed to save meetings: \(error)")
        }
    }

    private func deleteAudioFile(for meeting: MeetingRecord) {
        guard let fileName = meeting.audioFileName else { return }
        let url = audioDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Cleanup

    /// Remove old completed meetings (optional cleanup)
    public func cleanupOldMeetings(olderThan days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        meetings.removeAll { meeting in
            meeting.status == .completed &&
            meeting.recordedAt < cutoffDate
        }
        saveMeetings()
    }

    /// Check for orphaned audio files (audio without meeting record)
    public func cleanupOrphanedAudio() {
        let audioFiles = (try? FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)) ?? []
        let validFileNames = Set(meetings.compactMap { $0.audioFileName })

        for audioFile in audioFiles {
            let fileName = audioFile.lastPathComponent
            if !validFileNames.contains(fileName) && fileName != ".DS_Store" {
                try? FileManager.default.removeItem(at: audioFile)
            }
        }
    }

    // MARK: - Statistics

    public var totalMeetings: Int { meetings.count }
    public var completedMeetings: Int { meetings.filter { $0.status == .completed }.count }
    public var pendingCount: Int { pendingMeetings.count }
    public var totalDuration: TimeInterval { meetings.reduce(0) { $0 + $1.duration } }
}
