//
//  EmojiGIFPanel.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.9: Tab container for emoji and GIF panels
//

import SwiftUI

struct EmojiGIFPanel: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @State private var selectedTab: Tab = .emoji
    let onDismiss: () -> Void

    enum Tab {
        case emoji
        case gif
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab header
            HStack(spacing: 0) {
                TabButton(title: "😀 Emoji", isSelected: selectedTab == .emoji) {
                    selectedTab = .emoji
                }
                TabButton(title: "🎬 GIF", isSelected: selectedTab == .gif) {
                    selectedTab = .gif
                }

                Spacer()

                Button(action: onDismiss) {
                    Text("ABC")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))

            // Content
            switch selectedTab {
            case .emoji:
                EmojiKeyboard(viewModel: viewModel)
            case .gif:
                GIFSearchView(viewModel: viewModel)
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            KeyboardHaptics.lightTap()
            onTap()
        }) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    EmojiGIFPanel(viewModel: KeyboardViewModel(), onDismiss: {})
        .preferredColorScheme(.dark)
}
