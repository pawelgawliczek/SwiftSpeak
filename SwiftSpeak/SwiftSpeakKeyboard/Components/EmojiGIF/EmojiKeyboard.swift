//
//  EmojiKeyboard.swift
//  SwiftSpeakKeyboard
//
//  Phase 13.9: Emoji keyboard with categories, search, and recent
//

import SwiftUI

struct EmojiKeyboard: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @State private var selectedCategory: EmojiData.Category = .smileys
    @State private var recentEmojis: [String] = []
    @State private var searchText = ""
    @State private var showSearchKeyboard = false

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            // Search bar - tap to show inline keyboard
            Button(action: {
                showSearchKeyboard = true
                KeyboardHaptics.lightTap()
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Search emoji" : searchText)
                        .foregroundColor(searchText.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            KeyboardHaptics.lightTap()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 8)

            if showSearchKeyboard {
                // Inline search keyboard
                InlineSearchKeyboard(
                    text: $searchText,
                    onDismiss: { showSearchKeyboard = false },
                    onSearch: { } // Search happens automatically as text changes
                )
            } else {
                // Emoji grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(currentEmojis, id: \.self) { emoji in
                            Button(action: {
                                insertEmoji(emoji)
                            }) {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(EmojiData.Category.allCases, id: \.self) { category in
                            CategoryTab(
                                category: category,
                                isSelected: selectedCategory == category,
                                onTap: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 44)
                .background(Color.primary.opacity(0.05))
            }
        }
        .onAppear { loadRecentEmojis() }
    }

    private var currentEmojis: [String] {
        if !searchText.isEmpty {
            return EmojiData.search(searchText)
        }
        if selectedCategory == .recent {
            return recentEmojis
        }
        return EmojiData.emojis(for: selectedCategory)
    }

    private func insertEmoji(_ emoji: String) {
        viewModel.textDocumentProxy?.insertText(emoji)
        saveToRecent(emoji)
        KeyboardHaptics.lightTap()
    }

    private func saveToRecent(_ emoji: String) {
        var recent = recentEmojis
        recent.removeAll { $0 == emoji }
        recent.insert(emoji, at: 0)
        recent = Array(recent.prefix(30))
        recentEmojis = recent

        UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")?.set(recent, forKey: "recentEmojis")
    }

    private func loadRecentEmojis() {
        recentEmojis = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")?.stringArray(forKey: "recentEmojis") ?? []
    }
}

struct CategoryTab: View {
    let category: EmojiData.Category
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if category.icon.count <= 2 {
                    // Emoji icon
                    Text(category.icon)
                        .font(.title3)
                } else {
                    // SF Symbol icon
                    Image(systemName: category.icon)
                        .font(.title3)
                }
            }
            .frame(width: 44, height: 44)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    EmojiKeyboard(viewModel: KeyboardViewModel())
        .preferredColorScheme(.dark)
}
