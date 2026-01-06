//
//  DocumentPickerSheet.swift
//  SwiftSpeak
//
//  Phase 4e: Add documents to the knowledge base
//  Supports file upload (PDF, TXT, MD) and remote URLs with real RAG ingestion
//

import SwiftUI
import SwiftSpeakCore
import UniformTypeIdentifiers

struct DocumentPickerSheet: View {
    let powerMode: PowerMode
    let onAdd: (KnowledgeDocument) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    @StateObject private var ragOrchestrator = RAGOrchestrator()

    @State private var selectedTab: DocumentSourceTab = .file
    @State private var urlString: String = ""
    @State private var documentName: String = ""
    @State private var updateInterval: UpdateInterval = .weekly
    @State private var showingFilePicker = false

    // Ingestion state
    @State private var isIngesting = false
    @State private var ingestionProgress: IngestionProgress?
    @State private var errorMessage: String?
    @State private var urlValidationError: String?

    // Privacy
    @State private var hasShownPrivacyPopup = false

    enum DocumentSourceTab {
        case file
        case url
    }

    private var isURLValid: Bool {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              url.scheme == "https" else {
            return false
        }
        return true
    }

    private var isURLWhitelisted: Bool {
        guard let url = URL(string: urlString) else { return false }
        return RAGSecurityManager.shared.isDomainWhitelisted(url.host ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Privacy warning (always visible)
                        RAGPrivacyCompactWarning()

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
                .disabled(isIngesting)
                .opacity(isIngesting ? 0.5 : 1)

                // Ingestion overlay
                if isIngesting {
                    ingestionOverlay
                }
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isIngesting)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf, .plainText, .init(filenameExtension: "md")!],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .onAppear {
                configureRAG()
                checkFirstDocumentPrivacy()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Ingestion Overlay

    private var ingestionOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            if let progress = ingestionProgress {
                VStack(spacing: 8) {
                    Text(progress.message)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ProgressView(value: progress.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text("\(Int(progress.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Processing document...")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(.ultraThinMaterial)
        )
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

            // Size limit note
            Text("Maximum file size: \(ByteCountFormatter.string(fromByteCount: RAGLimits.maxDocumentSize, countStyle: .file))")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                    .onChange(of: urlString) { _, _ in
                        validateURL()
                    }

                // URL validation feedback
                if urlValidationError != nil {
                    RAGURLWarning(domain: URL(string: urlString)?.host ?? "unknown")
                } else if isURLValid && isURLWhitelisted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Domain is trusted")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
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
            Button(action: { Task { await addURL() } }) {
                Text("Add Document")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canAddURL ? AnyShapeStyle(AppTheme.powerGradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
            .disabled(!canAddURL)
        }
    }

    private var canAddURL: Bool {
        isURLValid && isURLWhitelisted && !isIngesting
    }

    // MARK: - Actions

    private func configureRAG() {
        if let openAIKey = settings.openAIAPIKey,
           !openAIKey.isEmpty {
            do {
                try ragOrchestrator.configure(openAIApiKey: openAIKey)
            } catch {
                errorMessage = "Failed to configure: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "OpenAI API key required for document indexing"
        }
    }

    private func checkFirstDocumentPrivacy() {
        // Check if this is the user's first document
        if settings.knowledgeDocuments.isEmpty && !hasShownPrivacyPopup {
            // First document - privacy popup will be shown by KnowledgeBaseView
            hasShownPrivacyPopup = true
        }
    }

    private func validateURL() {
        urlValidationError = nil

        guard !urlString.isEmpty else { return }

        guard let url = URL(string: urlString) else {
            urlValidationError = "Invalid URL format"
            return
        }

        guard url.scheme == "https" else {
            urlValidationError = "Only HTTPS URLs are allowed"
            return
        }

        if !RAGSecurityManager.shared.isDomainWhitelisted(url.host ?? "") {
            urlValidationError = "Domain not in whitelist"
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access selected file"
                return
            }

            Task {
                await ingestLocalFile(url)
                url.stopAccessingSecurityScopedResource()
            }

        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }

    private func ingestLocalFile(_ url: URL) async {
        guard ragOrchestrator.isConfigured else {
            errorMessage = "RAG not configured. Please add OpenAI API key."
            return
        }

        isIngesting = true

        do {
            let document = try await ragOrchestrator.ingestLocalFile(
                at: url,
                powerMode: powerMode
            ) { progress in
                Task { @MainActor in
                    self.ingestionProgress = progress
                }
            }

            await MainActor.run {
                isIngesting = false
                ingestionProgress = nil
                onAdd(document)
                HapticManager.success()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isIngesting = false
                ingestionProgress = nil
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
        }
    }

    private func addURL() async {
        guard ragOrchestrator.isConfigured else {
            errorMessage = "RAG not configured. Please add OpenAI API key."
            return
        }

        isIngesting = true

        do {
            let document = try await ragOrchestrator.ingestRemoteURL(
                urlString,
                powerMode: powerMode,
                refreshInterval: updateInterval
            ) { progress in
                Task { @MainActor in
                    self.ingestionProgress = progress
                }
            }

            await MainActor.run {
                isIngesting = false
                ingestionProgress = nil
                onAdd(document)
                HapticManager.success()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isIngesting = false
                ingestionProgress = nil
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
        }
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
    DocumentPickerSheet(
        powerMode: PowerMode.presets[0],
        onAdd: { _ in }
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}
