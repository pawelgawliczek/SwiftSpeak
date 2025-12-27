//
//  WebhooksView.swift
//  SwiftSpeak
//
//  Phase 4: Manage webhooks for Power Mode workflows
//  - Context Sources: Fetch data before processing
//  - Output Destinations: Send results after completion
//  - Automation Triggers: Trigger Make/Zapier workflows
//

import SwiftUI

struct WebhooksView: View {
    // Mock data - will be replaced with @ObservedObject settings
    @State private var webhooks: [Webhook] = Webhook.samples
    @State private var showingEditor = false
    @State private var editingWebhook: Webhook?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Context Sources
                webhookSection(
                    title: "CONTEXT SOURCES",
                    subtitle: "Fetch before processing",
                    type: .contextSource
                )

                // Output Destinations
                webhookSection(
                    title: "OUTPUT DESTINATIONS",
                    subtitle: "Send after completion",
                    type: .outputDestination
                )

                // Automation Triggers
                webhookSection(
                    title: "AUTOMATION TRIGGERS",
                    subtitle: "Trigger Make/Zapier workflows",
                    type: .automationTrigger
                )

                Spacer(minLength: 80)
            }
            .padding(16)
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
        .navigationTitle("Webhooks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { addNewWebhook() }) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let webhook = editingWebhook {
                WebhookEditorSheet(
                    webhook: webhook,
                    isNew: webhook.name.isEmpty,
                    onSave: { savedWebhook in
                        saveWebhook(savedWebhook)
                    },
                    onDelete: {
                        deleteWebhook(webhook)
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Webhooks run during Power Mode workflows. All connections are outbound only.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Webhook Section

    private func webhookSection(title: String, subtitle: String, type: WebhookType) -> some View {
        let sectionWebhooks = webhooks.filter { $0.type == type }

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if sectionWebhooks.isEmpty {
                emptyCard(type: type)
            } else {
                ForEach(sectionWebhooks) { webhook in
                    WebhookRowView(
                        webhook: webhook,
                        onToggle: { toggleWebhook(webhook) },
                        onTap: { editWebhook(webhook) }
                    )
                }
            }
        }
    }

    // MARK: - Empty Card

    private func emptyCard(type: WebhookType) -> some View {
        Button(action: { addNewWebhookOfType(type) }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)

                Text("Add \(type.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(16)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func addNewWebhook() {
        HapticManager.lightTap()
        editingWebhook = Webhook(
            name: "",
            type: .outputDestination,
            url: URL(string: "https://")!
        )
        showingEditor = true
    }

    private func addNewWebhookOfType(_ type: WebhookType) {
        HapticManager.lightTap()
        editingWebhook = Webhook(
            name: "",
            type: type,
            url: URL(string: "https://")!
        )
        showingEditor = true
    }

    private func editWebhook(_ webhook: Webhook) {
        HapticManager.lightTap()
        editingWebhook = webhook
        showingEditor = true
    }

    private func toggleWebhook(_ webhook: Webhook) {
        HapticManager.selection()
        if let index = webhooks.firstIndex(where: { $0.id == webhook.id }) {
            webhooks[index].isEnabled.toggle()
        }
    }

    private func saveWebhook(_ webhook: Webhook) {
        if let index = webhooks.firstIndex(where: { $0.id == webhook.id }) {
            webhooks[index] = webhook
        } else {
            webhooks.append(webhook)
        }
        showingEditor = false
        editingWebhook = nil
    }

    private func deleteWebhook(_ webhook: Webhook) {
        webhooks.removeAll { $0.id == webhook.id }
        showingEditor = false
        editingWebhook = nil
    }
}

// MARK: - Webhook Row View

struct WebhookRowView: View {
    let webhook: Webhook
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(templateColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: webhook.template.icon)
                        .font(.body)
                        .foregroundStyle(templateColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(webhook.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(webhook.type == .contextSource ? "GET \(webhook.url.host ?? "")" : "POST \(webhook.url.host ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let lastTriggered = webhook.lastTriggered {
                        Text("Last: \(timeAgo(lastTriggered))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Never triggered")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Toggle
                Toggle("", isOn: Binding(
                    get: { webhook.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(AppTheme.accent)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var templateColor: Color {
        switch webhook.template {
        case .slack: return .purple
        case .notion: return .gray
        case .todoist: return .red
        case .make: return .purple
        case .zapier: return .orange
        case .custom: return .blue
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WebhooksView()
    }
    .preferredColorScheme(.dark)
}
