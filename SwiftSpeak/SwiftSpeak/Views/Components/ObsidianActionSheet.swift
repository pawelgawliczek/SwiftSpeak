//
//  ObsidianActionSheet.swift
//  SwiftSpeak
//
//  Confirmation sheet before saving Power Mode output to Obsidian
//  Shows action description, target info, and content preview
//

import SwiftUI
import SwiftSpeakCore

struct ObsidianActionSheet: View {
    let action: ObsidianActionConfig
    let targetVault: ObsidianVault
    let content: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Action Description
                    actionHeader

                    // Target Information
                    targetInfo

                    // Content Preview
                    contentPreview

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Save to Obsidian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Action Header

    private var actionHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: action.action.icon)
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 48, height: 48)
                .background(Color.purple.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(action.action.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(action.action.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Target Information

    private var targetInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Destination")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                // Vault name
                HStack {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundStyle(.purple)
                    Text("Vault:")
                        .foregroundStyle(.secondary)
                    Text(targetVault.name)
                        .fontWeight(.medium)
                }
                .font(.callout)

                Divider()

                // Note path
                HStack(alignment: .top) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.purple)
                    Text("Note:")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(targetNoteName)
                            .fontWeight(.medium)

                        if action.action == .appendToDaily {
                            Text("Today's daily note")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .font(.callout)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var targetNoteName: String {
        switch action.action {
        case .appendToDaily:
            // Calculate daily note path synchronously using the same logic as ObsidianNoteWriter
            return dailyNotePath(for: targetVault)

        case .appendToNote:
            return action.targetNoteName ?? "Unknown"

        case .createNote:
            return action.targetNoteName ?? "New Note.md"

        case .none:
            return "N/A"
        }
    }

    /// Calculate daily note path (mirrors ObsidianNoteWriter.dailyNotePath)
    private func dailyNotePath(for vault: ObsidianVault, date: Date = Date()) -> String {
        var path = vault.dailyNotePath

        // Replace date placeholders
        let formatter = DateFormatter()

        // YYYY
        formatter.dateFormat = "yyyy"
        path = path.replacingOccurrences(of: "YYYY", with: formatter.string(from: date))
        path = path.replacingOccurrences(of: "{YYYY}", with: formatter.string(from: date))

        // MM
        formatter.dateFormat = "MM"
        path = path.replacingOccurrences(of: "MM", with: formatter.string(from: date))
        path = path.replacingOccurrences(of: "{MM}", with: formatter.string(from: date))

        // DD
        formatter.dateFormat = "dd"
        path = path.replacingOccurrences(of: "DD", with: formatter.string(from: date))
        path = path.replacingOccurrences(of: "{DD}", with: formatter.string(from: date))

        // {date} replacement (YYYY-MM-DD format)
        if path.contains("{date}") {
            formatter.dateFormat = "yyyy-MM-dd"
            path = path.replacingOccurrences(of: "{date}", with: formatter.string(from: date))
        }

        return path
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                Text(previewText)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(10)

                if content.count > 300 {
                    Text("... (\(content.count - 300) more characters)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var previewText: String {
        if content.count > 300 {
            return String(content.prefix(300))
        }
        return content
    }
}

// MARK: - Preview

#Preview {
    let sampleVault = ObsidianVault(
        name: "Personal Vault",
        localPath: "/Users/john/Documents/PersonalVault",
        iCloudPath: "vaults/PersonalVault/",
        lastIndexed: Date(),
        noteCount: 234,
        chunkCount: 1567,
        status: .synced,
        autoRefreshEnabled: true
    )

    let sampleAction = ObsidianActionConfig(
        action: .appendToDaily,
        targetVaultId: sampleVault.id,
        autoExecute: false
    )

    let sampleContent = """
    # Research Summary

    Here are the key findings from today's research:

    - Finding 1: Important discovery about AI
    - Finding 2: New breakthrough in machine learning
    - Finding 3: Emerging trends in the field

    ## Recommendations

    Based on this research, I recommend the following next steps...
    """

    return ObsidianActionSheet(
        action: sampleAction,
        targetVault: sampleVault,
        content: sampleContent,
        onConfirm: { print("Confirmed") },
        onCancel: { print("Cancelled") }
    )
    .preferredColorScheme(.dark)
}
