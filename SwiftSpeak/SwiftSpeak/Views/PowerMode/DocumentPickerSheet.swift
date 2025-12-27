//
//  DocumentPickerSheet.swift
//  SwiftSpeak
//
//  Phase 4: Add documents to the knowledge base
//  Supports file upload (PDF, TXT, MD) and remote URLs
//

import SwiftUI

struct DocumentPickerSheet: View {
    let onAdd: (KnowledgeDocument) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: DocumentSourceTab = .file
    @State private var urlString: String = ""
    @State private var documentName: String = ""
    @State private var updateInterval: UpdateInterval = .weekly
    @State private var showingFilePicker = false

    enum DocumentSourceTab {
        case file
        case url
    }

    private var isURLValid: Bool {
        guard !urlString.isEmpty else { return false }
        return URL(string: urlString) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Tab selector
                    tabSelector

                    // Content based on tab
                    if selectedTab == .file {
                        fileContent
                    } else {
                        urlContent
                    }
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 12) {
            TabButton(
                icon: "doc.fill",
                title: "Upload File",
                isSelected: selectedTab == .file,
                onTap: { selectedTab = .file }
            )

            TabButton(
                icon: "globe",
                title: "Add URL",
                isSelected: selectedTab == .url,
                onTap: { selectedTab = .url }
            )
        }
    }

    // MARK: - File Content

    private var fileContent: some View {
        VStack(spacing: 20) {
            Text("Supported formats: PDF, TXT, MD")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // File picker button
            Button(action: { showingFilePicker = true }) {
                VStack(spacing: 16) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.powerGradient)

                    Text("Choose File")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Tap to select a document")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .foregroundStyle(Color.primary.opacity(0.2))
                )
            }

            // Mock: In real app, this would trigger document picker
            Text("(Mock: File picker would open here)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            // Demo add button
            Button(action: { addMockFile() }) {
                Text("Add Sample PDF")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.powerGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
        }
    }

    // MARK: - URL Content

    private var urlContent: some View {
        VStack(spacing: 20) {
            // URL field
            VStack(alignment: .leading, spacing: 8) {
                Text("URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("https://docs.example.com/api", text: $urlString)
                    .font(.body)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("NAME (OPTIONAL)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("API Documentation", text: $documentName)
                    .font(.body)
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // Update interval
            VStack(alignment: .leading, spacing: 12) {
                Text("AUTO-UPDATE INTERVAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(UpdateInterval.allCases, id: \.self) { interval in
                        Button(action: {
                            HapticManager.selection()
                            updateInterval = interval
                        }) {
                            Text(interval.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(updateInterval == interval ? AppTheme.powerAccent.opacity(0.2) : Color.primary.opacity(0.08))
                                .foregroundStyle(updateInterval == interval ? AppTheme.powerAccent : .secondary)
                                .clipShape(Capsule())
                        }
                    }
                }

                if updateInterval == .always {
                    Text("\"Always\" checks for updates before each query")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 20)

            // Add button
            Button(action: { addURL() }) {
                Text("Add Document")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isURLValid ? AnyShapeStyle(AppTheme.powerGradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
            .disabled(!isURLValid)
        }
    }

    // MARK: - Actions

    private func addMockFile() {
        let document = KnowledgeDocument(
            name: "Sample Document.pdf",
            type: .localFile,
            localPath: "/documents/sample.pdf",
            chunkCount: 0,
            fileSizeBytes: 500_000,
            isIndexed: false
        )
        onAdd(document)
        dismiss()
    }

    private func addURL() {
        guard let url = URL(string: urlString) else { return }

        let name = documentName.isEmpty ? (url.host ?? "Web Document") : documentName
        let document = KnowledgeDocument(
            name: name,
            type: .remoteURL,
            sourceURL: url,
            chunkCount: 0,
            isIndexed: false,
            autoUpdateInterval: updateInterval
        )
        onAdd(document)
        dismiss()
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? AnyShapeStyle(AppTheme.powerGradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }
}

// MARK: - Preview

#Preview {
    DocumentPickerSheet(onAdd: { _ in })
        .preferredColorScheme(.dark)
}
