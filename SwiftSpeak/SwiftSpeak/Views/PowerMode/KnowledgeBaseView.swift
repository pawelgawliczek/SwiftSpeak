//
//  KnowledgeBaseView.swift
//  SwiftSpeak
//
//  Phase 4: Manage documents attached to a Power Mode for RAG
//  Documents are indexed and searched to provide relevant context
//

import SwiftUI

struct KnowledgeBaseView: View {
    let powerModeId: UUID
    @Binding var documentIds: [UUID]

    @Environment(\.dismiss) private var dismiss

    // Mock data - will be replaced with actual document storage
    @State private var documents: [KnowledgeDocument] = KnowledgeDocument.samples
    @State private var showingPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var documentToDelete: KnowledgeDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerSection

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
                    Text("Swipe left to delete. Tap to view details.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
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
                DocumentPickerSheet(onAdd: { document in
                    addDocument(document)
                })
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
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documents attached to this Power Mode will be searched to provide relevant context.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

    private func addDocument(_ document: KnowledgeDocument) {
        documents.append(document)
        documentIds.append(document.id)
        HapticManager.success()
    }

    private func confirmDelete(_ document: KnowledgeDocument) {
        documentToDelete = document
        showingDeleteConfirmation = true
    }

    private func deleteDocument(_ document: KnowledgeDocument) {
        documents.removeAll { $0.id == document.id }
        documentIds.removeAll { $0 == document.id }
        HapticManager.lightTap()
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
                    .fill(document.type == .localFile ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: document.type == .localFile ? "doc.fill" : "globe")
                    .font(.title3)
                    .foregroundStyle(document.type == .localFile ? .blue : .green)
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
        powerModeId: UUID(),
        documentIds: .constant([])
    )
    .preferredColorScheme(.dark)
}
