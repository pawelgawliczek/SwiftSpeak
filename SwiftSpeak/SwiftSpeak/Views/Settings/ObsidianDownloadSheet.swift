//
//  ObsidianDownloadSheet.swift
//  SwiftSpeak
//
//  Sheet showing progress while downloading Obsidian vault from iCloud
//

import SwiftUI
import SwiftSpeakCore
import CoreData

struct ObsidianDownloadSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Properties

    let manifest: ObsidianVaultManifest
    let syncService: ObsidianSyncService
    let vectorStore: ObsidianVectorStore

    // MARK: - State

    @State private var progress: SyncProgress = .starting
    @State private var isComplete = false
    @State private var downloadError: Error?
    @State private var downloadTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                iconView
                    .font(.system(size: 60))
                    .foregroundStyle(iconColor)

                // Title
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.semibold)

                // Subtitle
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Progress Bar
                if !isComplete && downloadError == nil {
                    ProgressView(value: progress.progressPercentage, total: 1.0)
                        .tint(.blue)
                        .padding(.horizontal, 40)

                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Action Button
                actionButton
                    .padding(.horizontal, 40)
            }
            .padding()
            .navigationTitle("Download Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isComplete && downloadError == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            downloadTask?.cancel()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await startDownload()
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var iconView: some View {
        switch progress {
        case .starting, .downloading, .processing:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
        case .complete:
            Image(systemName: "checkmark.circle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        case .uploading:
            Image(systemName: "icloud.and.arrow.up")
        }
    }

    private var iconColor: Color {
        switch progress {
        case .complete:
            return .green
        case .error:
            return .red
        default:
            return .blue
        }
    }

    private var titleText: String {
        if isComplete {
            return "Download Complete"
        } else if downloadError != nil {
            return "Download Failed"
        } else {
            switch progress {
            case .starting:
                return "Starting Download..."
            case .downloading:
                return "Downloading..."
            case .processing:
                return "Processing..."
            case .complete:
                return "Complete"
            case .error:
                return "Error"
            case .uploading:
                return "Uploading..."
            }
        }
    }

    private var subtitleText: String {
        if isComplete {
            return "Vault is now available for use with Power Modes"
        } else if let error = downloadError {
            return error.localizedDescription
        } else {
            return "\(manifest.noteCount) notes • \(manifest.chunkCount) chunks"
        }
    }

    private var progressText: String {
        switch progress {
        case .starting:
            return "Preparing..."
        case .downloading(let index, let total, let fileName):
            return "Downloading \(fileName) (\(index)/\(total))"
        case .processing(let message):
            return message
        case .uploading(let index, let total, let fileName):
            return "Uploading \(fileName) (\(index)/\(total))"
        case .complete, .error:
            return ""
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isComplete {
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        } else if downloadError != nil {
            VStack(spacing: 12) {
                Button {
                    // Retry download
                    downloadError = nil
                    isComplete = false
                    Task {
                        await startDownload()
                    }
                } label: {
                    Text("Retry")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Download Logic

    private func startDownload() async {
        // Ensure vector store is open
        do {
            try await MainActor.run {
                try vectorStore.open()
            }
        } catch {
            downloadError = error
            appLog("Failed to open vector store: \(error)", category: "Obsidian", level: .error)
            return
        }

        // Create vault model from manifest
        let vault = ObsidianVault(
            id: manifest.vaultId,
            name: manifest.notes.first?.title ?? "Untitled Vault",
            iCloudPath: "vaults/\(manifest.vaultId.uuidString)/",
            lastIndexed: manifest.indexedAt,
            noteCount: manifest.noteCount,
            chunkCount: manifest.chunkCount,
            status: .downloading
        )

        // Start download with progress tracking
        downloadTask = Task {
            for await progressUpdate in await syncService.downloadVault(vault, to: vectorStore) {
                await MainActor.run {
                    progress = progressUpdate

                    switch progressUpdate {
                    case .complete(let completedVault):
                        isComplete = true
                        saveToCoreData(completedVault)
                        appLog("Download complete: \(completedVault.name)", category: "Obsidian")

                    case .error(let error):
                        downloadError = error
                        appLog("Download error: \(error)", category: "Obsidian", level: .error)

                    default:
                        break
                    }
                }
            }
        }

        await downloadTask?.value
    }

    private func saveToCoreData(_ vault: ObsidianVault) {
        let entity = ObsidianVaultEntity(context: viewContext)
        entity.id = vault.id
        entity.name = vault.name
        entity.iCloudPath = vault.iCloudPath
        entity.lastIndexed = vault.lastIndexed
        entity.lastSynced = Date()
        entity.noteCount = Int32(vault.noteCount)
        entity.chunkCount = Int32(vault.chunkCount)
        entity.status = vault.status.rawValue
        entity.embeddingModel = manifest.embeddingModel

        do {
            try viewContext.save()
            appLog("Saved vault to Core Data: \(vault.name)", category: "Obsidian")
        } catch {
            appLog("Failed to save vault to Core Data: \(error)", category: "Obsidian", level: .error)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ObsidianDownloadSheet_Previews: PreviewProvider {
    static var previews: some View {
        ObsidianDownloadSheet(
            manifest: ObsidianVaultManifest(
                vaultId: UUID(),
                indexedAt: Date(),
                embeddingModel: "text-embedding-3-small",
                noteCount: 234,
                chunkCount: 1567,
                embeddingBatchCount: 2,
                notes: []
            ),
            syncService: ObsidianSyncService(),
            vectorStore: ObsidianVectorStore()
        )
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
#endif
