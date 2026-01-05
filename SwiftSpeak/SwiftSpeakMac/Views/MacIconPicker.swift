//
//  MacIconPicker.swift
//  SwiftSpeakMac
//
//  macOS version of the unified icon picker with SF Symbols and emojis
//  Mirrors iOS UnifiedIconPicker for platform consistency
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Mac Icon Picker

struct MacIconPicker: View {
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

    // SF Symbol categories (same as iOS)
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

    // Emoji categories (same as iOS)
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Text("Choose Icon")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

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
        }
        .frame(width: 500, height: 600)
    }

    // MARK: - Icon Preview Section

    private var iconPreviewSection: some View {
        VStack(spacing: 16) {
            // Large icon preview
            ZStack {
                if showBackgroundColorPicker {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                MacColorPickerRow(
                    label: showBackgroundColorPicker ? "Icon Color" : "Color",
                    selectedColor: $selectedColor
                )

                if showBackgroundColorPicker {
                    Divider()
                        .padding(.horizontal, 8)

                    MacColorPickerRow(
                        label: "Background",
                        selectedColor: $backgroundColor
                    )
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(category.icons, id: \.self) { icon in
                        MacIconPickerButton(
                            icon: icon,
                            isEmoji: false,
                            isSelected: selectedIcon == icon,
                            accentColor: selectedColor.color
                        ) {
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

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(category.emojis, id: \.self) { emoji in
                        MacIconPickerButton(
                            icon: emoji,
                            isEmoji: true,
                            isSelected: selectedIcon == emoji,
                            accentColor: selectedColor.color
                        ) {
                            selectedIcon = emoji
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Mac Icon Picker Button

private struct MacIconPickerButton: View {
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Mac Color Picker Row

struct MacColorPickerRow: View {
    let label: String
    @Binding var selectedColor: PowerModeColorPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(PowerModeColorPreset.allCases) { colorPreset in
                    Button(action: {
                        selectedColor = colorPreset
                    }) {
                        Circle()
                            .fill(colorPreset.gradient)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedColor == colorPreset ? Color.white : Color.clear, lineWidth: 2)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedColor == colorPreset ? colorPreset.color : Color.clear, lineWidth: 3)
                                    .scaleEffect(1.25)
                            )
                            .scaleEffect(selectedColor == colorPreset ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Context (simple)") {
    MacIconPicker(
        selectedIcon: .constant("person.circle"),
        selectedColor: .constant(.blue),
        showBackgroundColorPicker: false,
        backgroundColor: .constant(.blue)
    )
}

#Preview("Power Mode (with background)") {
    MacIconPicker(
        selectedIcon: .constant("bolt.fill"),
        selectedColor: .constant(.orange),
        showBackgroundColorPicker: true,
        backgroundColor: .constant(.orange)
    )
}
