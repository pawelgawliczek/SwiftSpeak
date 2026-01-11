//
//  ContextPickerRow.swift
//  SwiftSpeak
//
//  Shared SwiftUI component for selecting a default context
//  Used by both iOS and macOS in the Default Providers view
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakMac targets
//

import SwiftUI

// MARK: - Context Picker Row

/// A row component for selecting a default context from available contexts
/// Used in Default Selection settings to set a fallback context
public struct ContextPickerRow: View {
    @Binding public var selection: UUID?
    public let contexts: [ConversationContext]
    public let hiddenContextIds: Set<UUID>
    @Environment(\.colorScheme) private var colorScheme

    public init(
        selection: Binding<UUID?>,
        contexts: [ConversationContext],
        hiddenContextIds: Set<UUID> = []
    ) {
        self._selection = selection
        self.contexts = contexts
        self.hiddenContextIds = hiddenContextIds
    }

    private var selectedContext: ConversationContext? {
        guard let id = selection else { return nil }
        return contexts.first { $0.id == id }
    }

    private var visibleContexts: [ConversationContext] {
        contexts.filter { !hiddenContextIds.contains($0.id) }
    }

    private var rowBackground: Color {
        #if os(iOS)
        colorScheme == .dark ? Color.white.opacity(0.08) : Color(.systemGray6)
        #else
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.gray.opacity(0.1)
        #endif
    }

    public var body: some View {
        if visibleContexts.isEmpty {
            // No contexts available
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "exclamationmark.triangle")
                        .font(.body)
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("No contexts available")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Create a context to use as default")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            Menu {
                // None option (no default context)
                Button(action: {
                    selection = nil
                }) {
                    Label {
                        Text("None")
                    } icon: {
                        Image(systemName: "minus.circle")
                    }
                }

                Divider()

                // Available contexts
                ForEach(visibleContexts) { context in
                    Button(action: {
                        selection = context.id
                    }) {
                        Label {
                            Text(context.name)
                        } icon: {
                            Image(systemName: context.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Context icon with colored background
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.teal.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: selectedContext?.icon ?? "text.bubble")
                            .font(.body)
                            .foregroundStyle(.teal)
                    }

                    // Context info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedContext?.name ?? "None")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)

                        if let context = selectedContext {
                            Text(context.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No default context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Dropdown indicator pill
                    HStack(spacing: 4) {
                        Text(selectedContext?.name ?? "None")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(selection != nil ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selection != nil ? Color.teal : rowBackground)
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ContextPickerRow_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            Section("Default Context") {
                ContextPickerRow(
                    selection: .constant(nil),
                    contexts: ConversationContext.presets
                )
            }

            Section("With Selection") {
                ContextPickerRow(
                    selection: .constant(ConversationContext.presets.first?.id),
                    contexts: ConversationContext.presets
                )
            }
        }
    }
}
#endif
