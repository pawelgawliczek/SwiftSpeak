//
//  MacAddVaultSheet.swift
//  SwiftSpeakMac
//
//  Sheet for adding/editing Obsidian vaults
//  Includes folder picker, cost estimation, and indexing initiation
//

import SwiftUI
import SwiftSpeakCore
import AppKit

// MARK: - Add Vault Sheet

struct MacAddVaultSheet: View {
    @State private var vault: ObsidianVault
    @State private var selectedFolderURL: URL?
    @State private var isIndexing = false
    @State private var indexingProgress: ObsidianIndexingProgress?
    @State private var costEstimate: (noteCount: Int, chunkCount: Int, estimatedCost: Double)?
    @State private var showingEstimationError = false
    @State private var estimationError: String?

    let isNew: Bool
    let onAdd: (ObsidianVault) -> Void
    let onCancel: () -> Void

    init(vault: ObsidianVault? = nil, onAdd: @escaping (ObsidianVault) -> Void, onCancel: @escaping () -> Void) {
        if let vault = vault {
            _vault = State(initialValue: vault)
            _selectedFolderURL = State(initialValue: vault.localPath.flatMap { URL(fileURLWithPath: $0) })
            self.isNew = false
        } else {
            _vault = State(initialValue: ObsidianVault(
                name: "",
                iCloudPath: ""
            ))
            self.isNew = true
        }
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                    .disabled(isIndexing)
                Spacer()
                Text(isNew ? "Add Obsidian Vault" : "Edit Vault")
                    .font(.headline)
                Spacer()
                Button(isIndexing ? "Indexing..." : (isNew ? "Index & Add" : "Save")) {
                    if isNew {
                        startIndexing()
                    } else {
                        saveChanges()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canProceed || isIndexing)
            }
            .padding()

            Divider()

            // Form
            Form {
                // Basic Info
                Section("Basic Information") {
                    TextField("Vault Name", text: $vault.name)
                        .disabled(isIndexing)

                    // Folder Picker
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let folderURL = selectedFolderURL {
                                Text("Folder: \(folderURL.lastPathComponent)")
                                    .font(.callout)
                                Text(folderURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No folder selected")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Button("Choose Folder...") {
                            selectFolder()
                        }
                        .disabled(isIndexing)
                    }

                    // Auto-generate iCloud path from vault name
                    if !vault.name.isEmpty {
                        HStack {
                            Text("iCloud Path:")
                            Spacer()
                            Text("vaults/\(vault.name.replacingOccurrences(of: " ", with: ""))/")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Cost Estimate
                if let estimate = costEstimate {
                    Section("Indexing Estimate") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(estimate.noteCount) notes")
                                    .font(.callout)
                                Text("\(estimate.chunkCount) chunks (estimated)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("$\(String(format: "%.4f", estimate.estimatedCost))")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Text("embedding cost")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Vault Settings
                Section("Vault Settings") {
                    TextField("Daily Notes Path", text: $vault.dailyNotePath)
                        .disabled(isIndexing)
                    Text("Use {date} for today's date (e.g., Daily Notes/{date}.md)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("New Notes Folder", text: $vault.newNotesFolder)
                        .disabled(isIndexing)
                    Text("Where new notes created via voice will be saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Auto-refresh daily", isOn: $vault.autoRefreshEnabled)
                        .disabled(isIndexing)
                }

                // Indexing Settings
                Section("Indexing Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chunk Size")
                            Spacer()
                            Text("\(vault.chunkSize) chars")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vault.chunkSize) },
                                set: { vault.chunkSize = Int($0) }
                            ),
                            in: 200...1000,
                            step: 50
                        )
                        .disabled(isIndexing)
                        Text("Larger chunks = more context but higher cost")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chunk Overlap")
                            Spacer()
                            Text("\(vault.chunkOverlap) chars")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vault.chunkOverlap) },
                                set: { vault.chunkOverlap = Int($0) }
                            ),
                            in: 0...200,
                            step: 10
                        )
                        .disabled(isIndexing)
                        Text("Overlap helps maintain context between chunks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Similarity Threshold")
                            Spacer()
                            Text(String(format: "%.1f", vault.similarityThreshold))
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(vault.similarityThreshold) },
                                set: { vault.similarityThreshold = Float($0) }
                            ),
                            in: 0.5...0.95,
                            step: 0.05
                        )
                        .disabled(isIndexing)
                        Text("Higher = more precise matches, lower = more results")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Indexing Progress
                if let progress = indexingProgress {
                    Section("Indexing Progress") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(progress.phase.rawValue)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(progress.notesProcessed)/\(progress.totalNotes)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: progress.progress)

                            if let currentNote = progress.currentNote {
                                Text("Processing: \(currentNote)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Text("\(progress.chunksGenerated) chunks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("$\(String(format: "%.4f", progress.estimatedCost))")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 550, height: isIndexing ? 750 : 700)
        .animation(.easeInOut, value: isIndexing)
        .alert("Estimation Error", isPresented: $showingEstimationError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = estimationError {
                Text(error)
            }
        }
        .onChange(of: selectedFolderURL) { _ in
            estimateCost()
        }
    }

    // MARK: - Computed Properties

    private var canProceed: Bool {
        !vault.name.isEmpty && selectedFolderURL != nil
    }

    // MARK: - Actions

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Obsidian Vault Folder"
        panel.message = "Choose the folder containing your Obsidian vault"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            // Start accessing security-scoped resource
            let didStart = url.startAccessingSecurityScopedResource()
            if didStart {
                macLog("Started accessing security-scoped resource: \(url.path)", category: "Vault")
            }

            selectedFolderURL = url
            vault.localPath = url.path

            // Auto-fill vault name if empty
            if vault.name.isEmpty {
                vault.name = url.lastPathComponent
            }

            // Set iCloud path (for embedding sync)
            vault.iCloudPath = "vaults/\(vault.name.replacingOccurrences(of: " ", with: ""))/"

            // Check if vault is in iCloud Drive (iOS can write directly)
            if url.path.contains("/Library/Mobile Documents/com~apple~CloudDocs/") {
                // Extract relative path from iCloud Drive root
                if let range = url.path.range(of: "/Library/Mobile Documents/com~apple~CloudDocs/") {
                    let relativePath = String(url.path[range.upperBound...])
                    vault.iCloudDrivePath = relativePath
                    macLog("Vault is in iCloud Drive: \(relativePath)", category: "Vault")
                }
            } else {
                vault.iCloudDrivePath = nil
                macLog("Vault is local (not in iCloud Drive)", category: "Vault")
            }
        }
    }

    private func estimateCost() {
        guard let folderURL = selectedFolderURL else { return }

        Task {
            // Ensure we have access to the folder
            let didStart = folderURL.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    folderURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                // Get OpenAI API key from settings
                guard let apiKey = MacSettings.shared.apiKey(for: .openAI) else {
                    await MainActor.run {
                        estimationError = "OpenAI API key not configured. Go to Settings → Transcription & AI to add your OpenAI key."
                        showingEstimationError = true
                    }
                    return
                }

                let indexer = MacObsidianIndexer(apiKey: apiKey)
                let estimate = try await indexer.estimateCost(for: folderURL.path)

                await MainActor.run {
                    costEstimate = estimate
                }
            } catch {
                await MainActor.run {
                    estimationError = error.localizedDescription
                    showingEstimationError = true
                }
            }
        }
    }

    private func startIndexing() {
        macLog("========== startIndexing() called ==========", category: "Vault")

        guard let folderURL = selectedFolderURL else {
            macLog("ERROR: No folder URL selected", category: "Vault", level: .error)
            estimationError = "No folder selected. Please choose a vault folder first."
            showingEstimationError = true
            isIndexing = false
            return
        }

        macLog("Folder selected: \(folderURL.path)", category: "Vault")

        // Find an embedding-capable provider (OpenAI is required for embeddings)
        let apiKey = MacSettings.shared.apiKey(for: .openAI)
        let keyStatus = apiKey != nil ? "found (length: \(apiKey!.count))" : "NOT FOUND"
        macLog("OpenAI API key: \(keyStatus)", category: "Vault")

        guard let apiKey = apiKey, !apiKey.isEmpty else {
            macLog("ERROR: No embedding provider configured", category: "Vault", level: .error)
            estimationError = "No embedding provider configured.\n\nOpenAI is required for generating embeddings.\n\nGo to Settings → Transcription & AI to add your OpenAI API key."
            showingEstimationError = true
            isIndexing = false
            return
        }

        macLog("Starting indexing for: \(folderURL.path)", category: "Vault")
        isIndexing = true

        Task { @MainActor in
            macLog("Task started", category: "Vault")

            // Start security-scoped access
            let didStartAccess = folderURL.startAccessingSecurityScopedResource()
            macLog("Security-scoped access: \(didStartAccess ? "YES" : "NO (using implicit access)")", category: "Vault")

            defer {
                if didStartAccess {
                    folderURL.stopAccessingSecurityScopedResource()
                    macLog("Security-scoped access released", category: "Vault")
                }
            }

            do {
                // Create security-scoped bookmark for persistent access
                macLog("Creating bookmark...", category: "Vault")
                let bookmarkManager = MacFileBookmarkManager.shared
                try bookmarkManager.createBookmark(for: folderURL, vaultId: vault.id)
                macLog("Bookmark created for vault: \(vault.id.uuidString)", category: "Vault")

                // Start indexing with Mac-specific indexer
                macLog("Creating MacObsidianIndexer...", category: "Vault")
                let indexer = MacObsidianIndexer(apiKey: apiKey)
                macLog("Indexer created, calling indexVault()...", category: "Vault")

                let progressStream = indexer.indexVault(
                    at: folderURL.path,
                    vaultId: vault.id,
                    chunkSize: vault.chunkSize,
                    chunkOverlap: vault.chunkOverlap
                )
                macLog("indexVault() returned, starting iteration...", category: "Vault")

                // Monitor progress
                var didComplete = false
                var didError = false
                var finalError: String?

                for await progress in progressStream {
                    macLog("Progress: \(progress.phase.rawValue) - \(progress.notesProcessed)/\(progress.totalNotes) notes, \(progress.chunksGenerated) chunks", category: "Vault")

                    indexingProgress = progress

                    // Handle error phase
                    if progress.phase == .error {
                        macLog("========== INDEXING ERROR ==========", category: "Vault", level: .error)
                        didError = true
                        let errorMsg = progress.currentNote ?? "Unknown error occurred"
                        macLog("Error message: \(errorMsg)", category: "Vault", level: .error)
                        finalError = errorMsg
                        break
                    }

                    // Update vault when complete
                    if progress.phase == .complete {
                        macLog("========== INDEXING COMPLETE ==========", category: "Vault")
                        didComplete = true
                        var updatedVault = vault
                        updatedVault.noteCount = progress.notesProcessed
                        updatedVault.chunkCount = progress.chunksGenerated
                        updatedVault.lastIndexed = Date()
                        updatedVault.status = .synced

                        // Upload to iCloud for iOS access
                        Task {
                            do {
                                let cloudSync = MacObsidianCloudSync()
                                try await cloudSync.uploadVault(updatedVault.id)
                                macLog("Vault uploaded to iCloud", category: "Vault")
                            } catch {
                                macLog("iCloud upload failed: \(error)", category: "Vault", level: .warning)
                            }
                        }

                        onAdd(updatedVault)
                    }
                }

                macLog("Progress stream ended (didComplete: \(didComplete), didError: \(didError))", category: "Vault")

                // Handle results after stream completes
                if didError, let errorMsg = finalError {
                    estimationError = errorMsg
                    showingEstimationError = true
                    isIndexing = false
                } else if !didComplete {
                    macLog("Stream ended unexpectedly - indexing failed", category: "Vault", level: .warning)
                    estimationError = "Indexing failed unexpectedly. Check the logs for more details."
                    showingEstimationError = true
                    isIndexing = false
                }
            } catch {
                macLog("ERROR: \(error.localizedDescription)", category: "Vault", level: .error)
                estimationError = error.localizedDescription
                showingEstimationError = true
                isIndexing = false
            }
        }
    }

    private func saveChanges() {
        // For editing existing vault (not re-indexing)
        onAdd(vault)
    }
}

// MARK: - Preview

#Preview {
    MacAddVaultSheet(
        onAdd: { _ in },
        onCancel: { }
    )
}
