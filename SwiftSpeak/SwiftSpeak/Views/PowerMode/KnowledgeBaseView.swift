//
//  KnowledgeBaseView.swift
//  SwiftSpeak
//
//  Phase 4e: Manage documents attached to a Power Mode for RAG
//  Documents are indexed and searched to provide relevant context
//

import SwiftUI

struct KnowledgeBaseView: View {
    let powerMode: PowerMode
    @Binding var documentIds: [UUID]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    @StateObject private var ragOrchestrator = RAGOrchestrator()

    @State private var showingPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var documentToDelete: KnowledgeDocument?
    @State private var showingPrivacySheet = false
    @State private var errorMessage: String?

    // Get documents from settings that match our IDs
    private var documents: [KnowledgeDocument] {
        settings.knowledgeDocuments.filter { documentIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Privacy banner (always visible)
                    RAGPrivacyBanner()
                        .onTapGesture {
                            showingPrivacySheet = true
                        }

                    // Header
                    headerSection

                    // Error message
                    if let error = errorMessage {
                        ErrorBanner(message: error) {
                            errorMessage = nil
                        }
                    }

                    // Document list
                    if documents.isEmpty {
                        emptyState
                    } else {
                        ForEach(documents) { document in
                            DocumentRowView(
                                document: document,
                                onDelete: { confirmDelete(document) }
                            )
                        }
                    }

                    // Help text
                    if !documents.isEmpty {
                        Text("Tap trash icon to delete. Tap banner above for privacy details.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Knowledge Base")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingPicker = true }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                DocumentPickerSheet(
                    powerMode: powerMode,
                    onAdd: { document in
                        addDocument(document)
                    }
                )
                .environmentObject(settings)
            }
            .sheet(isPresented: $showingPrivacySheet) {
                RAGPrivacySheet(isPresented: $showingPrivacySheet) {
                    // User acknowledged
                }
            }
            .confirmationDialog("Delete Document", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let doc = documentToDelete {
                        deleteDocument(doc)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let doc = documentToDelete {
                    Text("Delete \"\(doc.name)\"? The indexed chunks will be removed.")
                }
            }
            .onAppear {
                configureRAG()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documents attached to this Power Mode will be searched to provide relevant context.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(documents.count) document\(documents.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if documents.count > 0 {
                    let totalChunks = documents.reduce(0) { $0 + $1.chunkCount }
                    Text("• \(totalChunks) chunks indexed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)

            Text("No Documents")
                .font(.headline)

            Text("Add PDFs, text files, or URLs to give this Power Mode context from your documents.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showingPicker = true }) {
                Text("Add Document")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.powerGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(32)
    }

    // MARK: - Actions

    private func configureRAG() {
        // Try to configure RAG with OpenAI key
        if let openAIKey = settings.openAIAPIKey,
           !openAIKey.isEmpty {
            do {
                try ragOrchestrator.configure(openAIApiKey: openAIKey)
            } catch {
                errorMessage = "Failed to configure RAG: \(error.localizedDescription)"
            }
        }
    }

    private func addDocument(_ document: KnowledgeDocument) {
        // Add to settings
        settings.addKnowledgeDocument(document)

        // Add ID to power mode
        if !documentIds.contains(document.id) {
            documentIds.append(document.id)
        }

        HapticManager.success()
    }

    private func confirmDelete(_ document: KnowledgeDocument) {
        documentToDelete = document
        showingDeleteConfirmation = true
    }

    private func deleteDocument(_ document: KnowledgeDocument) {
        // Remove from vector store
        do {
            try ragOrchestrator.deleteDocument(document.id)
        } catch {
            print("Failed to delete from vector store: \(error)")
        }

        // Remove from settings
        settings.removeKnowledgeDocument(document.id)

        // Remove from power mode
        documentIds.removeAll { $0 == document.id }

        HapticManager.lightTap()
    }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - Document Row View

struct DocumentRowView: View {
    let document: KnowledgeDocument
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(document.type == .remoteURL ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: document.type == .remoteURL ? "globe" : "doc.fill")
                    .font(.title3)
                    .foregroundStyle(document.type == .remoteURL ? .green : .blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(document.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if document.isIndexed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }

                if document.type == .remoteURL, let url = document.sourceURL {
                    Text(url.host ?? url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text("\(document.chunkCount) chunks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(document.fileSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let interval = document.autoUpdateInterval, interval != .never {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 2) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                            Text(interval.displayName)
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    KnowledgeBaseView(
        powerMode: PowerMode.presets[0],
        documentIds: .constant([])
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}
