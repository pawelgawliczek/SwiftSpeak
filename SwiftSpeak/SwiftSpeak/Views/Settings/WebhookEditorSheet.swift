//
//  WebhookEditorSheet.swift
//  SwiftSpeak
//
//  Phase 4: Create or edit a webhook configuration
//

import SwiftUI
import SwiftSpeakCore

struct WebhookEditorSheet: View {
    let webhook: Webhook
    let isNew: Bool
    let onSave: (Webhook) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    // Form state
    @State private var name: String = ""
    @State private var type: WebhookType = .outputDestination
    @State private var template: WebhookTemplate = .custom
    @State private var urlString: String = ""
    @State private var authType: WebhookAuthType = .none
    @State private var authToken: String = ""
    @State private var includeInput: Bool = true
    @State private var includeOutput: Bool = true
    @State private var includeModeName: Bool = true
    @State private var includeContext: Bool = true
    @State private var includeTimestamp: Bool = true

    @State private var showingDeleteConfirmation = false
    @State private var testStatus: TestStatus = .idle

    enum TestStatus: Equatable {
        case idle
        case testing
        case success
        case failed(String)

        var isIdle: Bool {
            if case .idle = self { return true }
            return false
        }

        var isTesting: Bool {
            if case .testing = self { return true }
            return false
        }

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        URL(string: urlString) != nil
    }

    init(webhook: Webhook, isNew: Bool, onSave: @escaping (Webhook) -> Void, onDelete: @escaping () -> Void) {
        self.webhook = webhook
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete

        _name = State(initialValue: webhook.name)
        _type = State(initialValue: webhook.type)
        _template = State(initialValue: webhook.template)
        _urlString = State(initialValue: webhook.url.absoluteString)
        _authType = State(initialValue: webhook.authType)
        _authToken = State(initialValue: webhook.authToken ?? "")
        _includeInput = State(initialValue: webhook.includeInput)
        _includeOutput = State(initialValue: webhook.includeOutput)
        _includeModeName = State(initialValue: webhook.includeModeName)
        _includeContext = State(initialValue: webhook.includeContext)
        _includeTimestamp = State(initialValue: webhook.includeTimestamp)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Template selector
                    templateSection

                    // Name field
                    nameSection

                    // Type selector
                    typeSection

                    // URL field
                    urlSection

                    // Authentication
                    authSection

                    // Payload options (for POST types)
                    if type != .contextSource {
                        payloadSection
                    }

                    // Test button
                    testSection

                    // Delete button (if editing)
                    if !isNew {
                        deleteSection
                    }
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle(isNew ? "Add Webhook" : "Edit Webhook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("Delete Webhook", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the webhook configuration.")
            }
        }
    }

    // MARK: - Template Section

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEMPLATE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                ForEach(WebhookTemplate.allCases, id: \.self) { t in
                    Button(action: {
                        HapticManager.selection()
                        template = t
                        applyTemplate(t)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: t.icon)
                                .font(.title3)
                            Text(t.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(template == t ? AppTheme.accent.opacity(0.2) : Color.primary.opacity(0.05))
                        .foregroundStyle(template == t ? AppTheme.accent : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("My Webhook", text: $name)
                .font(.body)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEBHOOK TYPE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(WebhookType.allCases, id: \.self) { t in
                    Button(action: {
                        HapticManager.selection()
                        type = t
                    }) {
                        Text(t.displayName)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(type == t ? AppTheme.accent.opacity(0.2) : Color.primary.opacity(0.08))
                            .foregroundStyle(type == t ? AppTheme.accent : .secondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - URL Section

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("URL")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("https://api.example.com/webhook", text: $urlString)
                .font(.body)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUTHENTICATION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(WebhookAuthType.allCases, id: \.self) { auth in
                    Button(action: {
                        HapticManager.selection()
                        authType = auth
                    }) {
                        Text(auth.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(authType == auth ? AppTheme.accent.opacity(0.2) : Color.primary.opacity(0.08))
                            .foregroundStyle(authType == auth ? AppTheme.accent : .secondary)
                            .clipShape(Capsule())
                    }
                }
            }

            if authType != .none {
                SecureField(authType == .bearerToken ? "Bearer Token" : "API Key / Token", text: $authToken)
                    .font(.body)
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
        }
    }

    // MARK: - Payload Section

    private var payloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAYLOAD (WHAT TO INCLUDE)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                PayloadToggle(title: "Input Text", isOn: $includeInput)
                PayloadToggle(title: "Output Result", isOn: $includeOutput)
                PayloadToggle(title: "Power Mode Name", isOn: $includeModeName)
                PayloadToggle(title: "Active Context", isOn: $includeContext)
                PayloadToggle(title: "Timestamp", isOn: $includeTimestamp)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Button(action: { testWebhook() }) {
            HStack {
                switch testStatus {
                case .idle:
                    Text("Test Webhook")
                case .testing:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Testing...")
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Success!")
                case .failed(let message):
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                }
            }
            .font(.callout.weight(.medium))
            .foregroundStyle(testStatus.isSuccess ? .green : (testStatus.isIdle ? AppTheme.accent : .primary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .disabled(testStatus.isTesting || !isValid)
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(action: {
            HapticManager.warning()
            showingDeleteConfirmation = true
        }) {
            Text("Delete Webhook")
                .font(.body.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Actions

    /// Default names for each template - used to detect if user has customized the name
    private static let templateDefaultNames: Set<String> = [
        "Slack Channel", "Notion Database", "Todoist Tasks",
        "Make.com Scenario", "Zapier Webhook"
    ]

    /// Check if the current name is a template default (not customized by user)
    private var isDefaultTemplateName: Bool {
        name.isEmpty || Self.templateDefaultNames.contains(name)
    }

    private func applyTemplate(_ template: WebhookTemplate) {
        switch template {
        case .slack:
            if isDefaultTemplateName { name = "Slack Channel" }
            urlString = "https://hooks.slack.com/services/"
        case .notion:
            if isDefaultTemplateName { name = "Notion Database" }
            urlString = "https://api.notion.com/v1/pages"
            authType = .bearerToken
        case .todoist:
            if isDefaultTemplateName { name = "Todoist Tasks" }
            urlString = "https://api.todoist.com/rest/v2/tasks"
            authType = .bearerToken
        case .make:
            if isDefaultTemplateName { name = "Make.com Scenario" }
            urlString = "https://hook.make.com/"
            type = .automationTrigger
        case .zapier:
            if isDefaultTemplateName { name = "Zapier Webhook" }
            urlString = "https://hooks.zapier.com/hooks/catch/"
            type = .automationTrigger
        case .custom:
            break
        }
    }

    private func testWebhook() {
        guard let url = URL(string: urlString) else {
            testStatus = .failed("Invalid URL")
            return
        }

        testStatus = .testing
        HapticManager.lightTap()

        // Build webhook from current form state
        let testWebhookConfig = Webhook(
            id: webhook.id,
            name: name,
            type: type,
            template: template,
            url: url,
            isEnabled: true,
            authType: authType,
            authToken: authToken.isEmpty ? nil : authToken,
            includeInput: includeInput,
            includeOutput: includeOutput,
            includeModeName: includeModeName,
            includeContext: includeContext,
            includeTimestamp: includeTimestamp
        )

        // Execute real test
        Task {
            let executor = WebhookExecutor(settings: settings)
            let result = await executor.testWebhook(testWebhookConfig)

            if result.success {
                testStatus = .success
                HapticManager.success()
            } else {
                testStatus = .failed(result.error ?? "Unknown error")
                HapticManager.error()
            }

            // Reset after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            testStatus = .idle
        }
    }

    private func saveAndDismiss() {
        guard let url = URL(string: urlString) else { return }

        let savedWebhook = Webhook(
            id: webhook.id,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            template: template,
            url: url,
            isEnabled: webhook.isEnabled,
            authType: authType,
            authToken: authToken.isEmpty ? nil : authToken,
            includeInput: includeInput,
            includeOutput: includeOutput,
            includeModeName: includeModeName,
            includeContext: includeContext,
            includeTimestamp: includeTimestamp,
            lastTriggered: webhook.lastTriggered,
            lastStatus: webhook.lastStatus,
            createdAt: webhook.createdAt,
            updatedAt: Date()
        )

        HapticManager.success()
        onSave(savedWebhook)
        dismiss()
    }
}

// MARK: - Payload Toggle

private struct PayloadToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
    }
}

// MARK: - Preview

#Preview("New Webhook") {
    WebhookEditorSheet(
        webhook: Webhook(name: "", type: .outputDestination, url: URL(string: "https://")!),
        isNew: true,
        onSave: { _ in },
        onDelete: {}
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}

#Preview("Edit Webhook") {
    WebhookEditorSheet(
        webhook: Webhook.samples.first!,
        isNew: false,
        onSave: { _ in },
        onDelete: {}
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}
