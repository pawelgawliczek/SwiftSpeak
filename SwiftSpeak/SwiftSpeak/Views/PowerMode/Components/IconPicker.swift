//
//  IconPicker.swift
//  SwiftSpeak
//
//  Unified icon picker with SF Symbols and emojis - used for Power Modes and Contexts
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Unified Icon Picker (supports both SF Symbols and emojis)

struct UnifiedIconPicker: View {
    @Binding var selectedIcon: String
    @Binding var selectedColor: PowerModeColorPreset

    /// Optional background color (for Power Modes)
    var showBackgroundColorPicker: Bool = false
    @Binding var backgroundColor: PowerModeColorPreset

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedTab: IconTab = .symbols

    enum IconTab: String, CaseIterable {
        case symbols = "Symbols"
        case emojis = "Emojis"
    }

    // SF Symbol categories
    private let symbolCategories: [(name: String, icons: [String])] = [
        ("Suggested", [
            "bolt.fill", "magnifyingglass.circle.fill", "lightbulb.fill",
            "target", "doc.text.fill", "envelope.fill", "calendar",
            "person.circle", "heart.fill", "star.fill"
        ]),
        ("Productivity", [
            "doc.fill", "folder.fill", "tray.fill", "archivebox.fill",
            "chart.bar.fill", "chart.line.uptrend.xyaxis", "list.bullet.clipboard.fill",
            "checkmark.circle.fill", "flag.fill", "bookmark.fill"
        ]),
        ("Communication", [
            "bubble.left.fill", "bubble.left.and.bubble.right.fill", "quote.bubble.fill",
            "megaphone.fill", "bell.fill", "phone.fill", "video.fill", "envelope.open.fill"
        ]),
        ("Coding & Tech", [
            "chevron.left.forwardslash.chevron.right", "terminal.fill", "cpu.fill",
            "memorychip.fill", "network", "server.rack", "externaldrive.fill",
            "wrench.and.screwdriver.fill", "gearshape.fill", "command"
        ]),
        ("Creativity", [
            "paintbrush.fill", "pencil.tip", "wand.and.stars", "theatermasks.fill",
            "film.fill", "music.note", "camera.fill", "photo.fill", "paintpalette.fill"
        ]),
        ("Nature & Places", [
            "globe", "house.fill", "building.2.fill", "mountain.2.fill",
            "leaf.fill", "sun.max.fill", "moon.fill", "cloud.fill", "drop.fill",
            "airplane", "car.fill"
        ]),
        ("Symbols", [
            "star.fill", "heart.fill", "checkmark.seal.fill", "xmark.circle.fill",
            "exclamationmark.triangle.fill", "info.circle.fill", "questionmark.circle.fill",
            "hand.thumbsup.fill", "sparkles", "flame.fill"
        ]),
        ("People & Activity", [
            "person.fill", "person.2.fill", "figure.run", "figure.mind.and.body",
            "brain.head.profile", "eye.fill", "hand.raised.fill", "sportscourt.fill",
            "dumbbell.fill", "trophy.fill", "graduationcap.fill"
        ]),
        ("Media & Controls", [
            "play.fill", "pause.fill", "stop.fill", "forward.fill",
            "speaker.wave.3.fill", "mic.fill", "waveform", "record.circle.fill"
        ]),
        ("Finance & Shopping", [
            "creditcard.fill", "banknote.fill", "cart.fill", "bag.fill",
            "gift.fill", "tag.fill", "percent"
        ])
    ]

    // Emoji categories
    private let emojiCategories: [(name: String, emojis: [String])] = [
        ("Faces & People", [
            "😀", "😊", "🥰", "😎", "🤔", "🙄", "😴", "🤗",
            "👤", "👥", "👨‍💼", "👩‍💻", "👨‍🎨", "👩‍🔬", "👨‍🏫", "👩‍⚕️"
        ]),
        ("Hearts & Love", [
            "❤️", "💕", "💖", "💗", "💓", "💝", "🖤", "💜"
        ]),
        ("Activities", [
            "🏆", "⚽", "🏀", "🎾", "🏃", "💪", "🧘", "🎮"
        ]),
        ("Nature", [
            "🌟", "⭐", "🔥", "💧", "🌈", "☀️", "🌙", "⚡",
            "🌸", "🌺", "🌻", "🌴", "🍀", "🌿", "🪴", "🌵"
        ]),
        ("Objects", [
            "💼", "📚", "📝", "✏️", "🔧", "💡", "🎁", "💳",
            "📱", "💻", "🖥️", "⌨️", "🎧", "📷", "🎬", "🎵"
        ]),
        ("Travel & Places", [
            "🏠", "🏢", "🏫", "🏥", "✈️", "🚗", "🚀", "⛵",
            "🗺️", "🏔️", "🏖️", "🌆", "🌃", "🎡", "🎢", "⛺"
        ]),
        ("Food & Drink", [
            "🍽️", "☕", "🍕", "🍔", "🍣", "🍰", "🍎", "🥗"
        ]),
        ("Symbols", [
            "✨", "💫", "🎯", "🔮", "🎪", "🎭", "🎨", "🎬",
            "✅", "❌", "⚠️", "ℹ️", "❓", "❗", "💯", "🔒"
        ])
    ]

    private var filteredSymbolCategories: [(name: String, icons: [String])] {
        if searchText.isEmpty {
            return symbolCategories
        }
        return symbolCategories.compactMap { category in
            let filteredIcons = category.icons.filter { icon in
                icon.localizedCaseInsensitiveContains(searchText)
            }
            if filteredIcons.isEmpty {
                return nil
            }
            return (category.name, filteredIcons)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Icon preview
                    iconPreviewSection

                    // Tab picker (Symbols / Emojis)
                    Picker("", selection: $selectedTab) {
                        ForEach(IconTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    // Search bar (only for symbols)
                    if selectedTab == .symbols {
                        searchBar
                    }

                    // Content based on tab
                    switch selectedTab {
                    case .symbols:
                        symbolsGrid
                    case .emojis:
                        emojisGrid
                    }
                }
                .padding(.vertical, 16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Icon Preview Section

    private var iconPreviewSection: some View {
        VStack(spacing: 16) {
            // Large icon preview
            ZStack {
                if showBackgroundColorPicker {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .fill(backgroundColor.color.opacity(0.15))
                        .frame(width: 100, height: 100)
                } else {
                    Circle()
                        .fill(selectedColor.color.opacity(0.15))
                        .frame(width: 100, height: 100)
                }

                if selectedIcon.contains(".") {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(selectedColor.gradient)
                } else {
                    Text(selectedIcon)
                        .font(.system(size: 48))
                }
            }

            // Color pickers
            VStack(spacing: 12) {
                ColorPickerRow(
                    label: showBackgroundColorPicker ? "Icon Color" : "Color",
                    selectedColor: $selectedColor
                )

                if showBackgroundColorPicker {
                    Divider()
                        .padding(.horizontal, 8)

                    ColorPickerRow(
                        label: "Background",
                        selectedColor: $backgroundColor
                    )
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search symbols...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Symbols Grid

    private var symbolsGrid: some View {
        ForEach(filteredSymbolCategories, id: \.name) { category in
            VStack(alignment: .leading, spacing: 12) {
                Text(category.name.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(category.icons, id: \.self) { icon in
                        IconPickerButton(
                            icon: icon,
                            isEmoji: false,
                            isSelected: selectedIcon == icon,
                            accentColor: selectedColor.color
                        ) {
                            HapticManager.selection()
                            selectedIcon = icon
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Emojis Grid

    private var emojisGrid: some View {
        ForEach(emojiCategories, id: \.name) { category in
            VStack(alignment: .leading, spacing: 12) {
                Text(category.name.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(category.emojis, id: \.self) { emoji in
                        IconPickerButton(
                            icon: emoji,
                            isEmoji: true,
                            isSelected: selectedIcon == emoji,
                            accentColor: selectedColor.color
                        ) {
                            HapticManager.selection()
                            selectedIcon = emoji
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Legacy IconPicker (wrapper for backward compatibility)

struct IconPicker: View {
    @Binding var selectedIcon: String
    @Binding var iconColor: PowerModeColorPreset
    @Binding var iconBackgroundColor: PowerModeColorPreset

    var body: some View {
        UnifiedIconPicker(
            selectedIcon: $selectedIcon,
            selectedColor: $iconColor,
            showBackgroundColorPicker: true,
            backgroundColor: $iconBackgroundColor
        )
    }
}

// MARK: - Icon Picker Button

private struct IconPickerButton: View {
    let icon: String
    let isEmoji: Bool
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Group {
                if isEmoji {
                    Text(icon)
                        .font(.title2)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
            }
            .frame(width: 44, height: 44)
            .background(
                isSelected
                    ? AnyShapeStyle(accentColor.gradient)
                    : AnyShapeStyle(Color.primary.opacity(0.08))
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#Preview("Power Mode (with background)") {
    IconPicker(
        selectedIcon: .constant("bolt.fill"),
        iconColor: .constant(.orange),
        iconBackgroundColor: .constant(.orange)
    )
    .preferredColorScheme(.dark)
}

#Preview("Context (simple)") {
    UnifiedIconPicker(
        selectedIcon: .constant("❤️"),
        selectedColor: .constant(.purple),
        showBackgroundColorPicker: false,
        backgroundColor: .constant(.purple)
    )
    .preferredColorScheme(.dark)
}
