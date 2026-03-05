//
//  ConfigUpdateSheet.swift
//  SwiftSpeak
//
//  Created by SwiftSpeak on 2024-12-28.
//

import SwiftUI
import SwiftSpeakCore

/// Modal sheet that displays config changes to the user
struct ConfigUpdateSheet: View {
    let changes: [ConfigChange]
    @Binding var isPresented: Bool

    @StateObject private var configManager = RemoteConfigManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView

                    // Changes grouped by category
                    ForEach(groupedChanges, id: \.category) { group in
                        changeCategorySection(group)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") {
                        configManager.markChangesAsSeen()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentGradient)

            Text("Provider updates available")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(changes.count) change\(changes.count == 1 ? "" : "s") for your providers")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Grouped Changes

    private var groupedChanges: [(category: ConfigChangeCategory, changes: [ConfigChange])] {
        let grouped = Dictionary(grouping: changes) { $0.category }
        return ConfigChangeCategory.allCases.compactMap { category in
            guard let categoryChanges = grouped[category], !categoryChanges.isEmpty else {
                return nil
            }
            return (category: category, changes: categoryChanges)
        }
    }

    // MARK: - Category Section

    private func changeCategorySection(_ group: (category: ConfigChangeCategory, changes: [ConfigChange])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: group.category.iconName)
                    .foregroundStyle(AppTheme.accent)
                Text(group.category.rawValue)
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            // Change cards
            VStack(spacing: 8) {
                ForEach(group.changes) { change in
                    changeCard(change)
                }
            }
        }
    }

    // MARK: - Change Card

    private func changeCard(_ change: ConfigChange) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: change.iconName)
                .font(.title3)
                .foregroundStyle(change.isPositive ? .green : .orange)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(change.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(change.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Indicator for pricing changes
            if case .pricingDecrease = change {
                Text("Savings")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15), in: Capsule())
            } else if case .pricingIncrease = change {
                Text("Higher")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Config Update Sheet") {
    ConfigUpdateSheet(
        changes: [
            .newLanguage(provider: .openAI, language: .polish, capability: "Transcription", quality: .excellent),
            .languageQualityImproved(provider: .deepgram, language: .japanese, capability: "Transcription", oldTier: .good, newTier: .excellent),
            .pricingDecrease(provider: .openAI, model: "gpt-4o", oldCost: 0.0035, newCost: 0.0025),
            .newModel(provider: .anthropic, model: ModelRemoteConfig(id: "claude-3-5-haiku", name: "Claude 3.5 Haiku", isDefault: false), capability: "Power Mode"),
            .statusChange(provider: .deepgram, oldStatus: .degraded, newStatus: .operational)
        ],
        isPresented: .constant(true)
    )
}

// MARK: - Empty State Preview

#Preview("Empty Changes") {
    ConfigUpdateSheet(
        changes: [],
        isPresented: .constant(true)
    )
}
