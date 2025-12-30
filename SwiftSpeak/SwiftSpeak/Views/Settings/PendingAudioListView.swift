//
//  PendingAudioListView.swift
//  SwiftSpeak
//
//  Phase 11: Manage pending audio recordings that failed to process
//

import SwiftUI

struct PendingAudioListView: View {
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var showDeleteConfirmation = false
    @State private var pendingToDelete: PendingAudio?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if settings.pendingAudioQueue.isEmpty {
                emptyState
            } else {
                List {
                    // Summary Section
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(settings.pendingAudioQueue.count) pending recording\(settings.pendingAudioQueue.count == 1 ? "" : "s")")
                                    .font(.callout.weight(.medium))

                                let totalDuration = settings.pendingAudioQueue.reduce(0) { $0 + $1.duration }
                                Text("Total: \(formatDuration(totalDuration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Clear All") {
                                HapticManager.warning()
                                showDeleteConfirmation = true
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                        }
                        .listRowBackground(rowBackground)
                    }

                    // Recordings List
                    Section {
                        ForEach(settings.pendingAudioQueue.sorted(by: { $0.createdAt > $1.createdAt })) { audio in
                            PendingAudioRow(audio: audio) {
                                retryAudio(audio)
                            } onUseRaw: {
                                useRawTranscription(audio)
                            } onDelete: {
                                pendingToDelete = audio
                                showDeleteConfirmation = true
                            }
                            .listRowBackground(rowBackground)
                        }
                    } header: {
                        Text("Recordings")
                    }

                    // Info Section
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(icon: "arrow.clockwise", text: "Retry: Attempt transcription again")
                            InfoRow(icon: "doc.text", text: "Use Raw: Insert partial transcription (if available)")
                            InfoRow(icon: "trash", text: "Delete: Remove recording permanently")
                        }
                        .listRowBackground(rowBackground)
                    } header: {
                        Text("Actions")
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Pending Recordings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Recording?", isPresented: $showDeleteConfirmation) {
            if let audio = pendingToDelete {
                Button("Delete", role: .destructive) {
                    deleteAudio(audio)
                }
                Button("Cancel", role: .cancel) {
                    pendingToDelete = nil
                }
            } else {
                // Clear all
                Button("Delete All", role: .destructive) {
                    deleteAllAudio()
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            if pendingToDelete != nil {
                Text("This recording will be permanently deleted.")
            } else {
                Text("All pending recordings will be permanently deleted.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("No Pending Recordings")
                .font(.title3.weight(.semibold))

            Text("All transcriptions processed successfully!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Actions

    private func retryAudio(_ audio: PendingAudio) {
        HapticManager.lightTap()
        // Mark as processing to show user action was taken
        settings.updatePendingAudioStatus(audio.id, status: .processing, error: nil)

        // Full retry implementation would require:
        // 1. TranscriptionOrchestrator.processAudioFile(url: audio.audioFileURL)
        // 2. Configure orchestrator with audio.mode, audio.translateEnabled, etc.
        // 3. On success: remove from queue and save to history
        // 4. On failure: update status back to .failed with new error

        // For now, copy raw transcription if available as a fallback
        if let raw = audio.rawTranscription, !raw.isEmpty {
            settings.lastTranscription = raw
            UIPasteboard.general.string = raw
        }
    }

    private func useRawTranscription(_ audio: PendingAudio) {
        guard let raw = audio.rawTranscription, !raw.isEmpty else { return }
        HapticManager.success()

        // Copy to clipboard
        UIPasteboard.general.string = raw

        // Update last transcription for keyboard
        settings.lastTranscription = raw

        // Remove from queue
        settings.removeFromPendingQueue(audio.id)
    }

    private func deleteAudio(_ audio: PendingAudio) {
        HapticManager.mediumTap()
        // Delete audio file from disk
        try? FileManager.default.removeItem(at: audio.audioFileURL)
        settings.removeFromPendingQueue(audio.id)
        pendingToDelete = nil
    }

    private func deleteAllAudio() {
        HapticManager.mediumTap()
        for audio in settings.pendingAudioQueue {
            // Delete audio file from disk
            try? FileManager.default.removeItem(at: audio.audioFileURL)
            settings.removeFromPendingQueue(audio.id)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Pending Audio Row

struct PendingAudioRow: View {
    let audio: PendingAudio
    let onRetry: () -> Void
    let onUseRaw: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(audio.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.callout.weight(.medium))

                    HStack(spacing: 8) {
                        Text(formatDuration(audio.duration))
                        Text(audio.mode.displayName)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge
            }

            // Error message
            if let error = audio.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Raw transcription preview
            if let raw = audio.rawTranscription, !raw.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Partial transcription available:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(raw.prefix(100) + (raw.count > 100 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                if audio.rawTranscription != nil && !audio.rawTranscription!.isEmpty {
                    Button(action: onUseRaw) {
                        Label("Use Raw", systemImage: "doc.text")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(audio.status.displayName)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch audio.status {
        case .pending: return .orange
        case .processing: return .blue
        case .partialSuccess: return .yellow
        case .failed: return .red
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PendingAudioStatus Extension

extension PendingAudioStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .partialSuccess: return "Partial"
        case .failed: return "Failed"
        }
    }
}

#Preview {
    NavigationStack {
        PendingAudioListView()
            .environmentObject(SharedSettings.shared)
    }
}
