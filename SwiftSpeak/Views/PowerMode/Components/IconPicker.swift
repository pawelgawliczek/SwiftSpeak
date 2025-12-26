//
//  IconPicker.swift
//  SwiftSpeak
//
//  Rich SF Symbol picker with categories
//

import SwiftUI

struct IconPicker: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    // Icon categories with SF Symbols
    private let categories: [(name: String, icons: [String])] = [
        ("Suggested", [
            "bolt.fill", "magnifyingglass.circle.fill", "lightbulb.fill",
            "target", "doc.text.fill", "envelope.fill", "calendar"
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
            "leaf.fill", "sun.max.fill", "moon.fill", "cloud.fill", "drop.fill"
        ]),
        ("Symbols", [
            "star.fill", "heart.fill", "checkmark.seal.fill", "xmark.circle.fill",
            "exclamationmark.triangle.fill", "info.circle.fill", "questionmark.circle.fill",
            "hand.thumbsup.fill", "sparkles", "flame.fill"
        ]),
        ("People & Activity", [
            "person.fill", "person.2.fill", "figure.run", "figure.mind.and.body",
            "brain.head.profile", "eye.fill", "hand.raised.fill", "sportscourt.fill"
        ]),
        ("Media & Controls", [
            "play.fill", "pause.fill", "stop.fill", "forward.fill",
            "speaker.wave.3.fill", "mic.fill", "waveform", "record.circle.fill"
        ])
    ]

    private var filteredCategories: [(name: String, icons: [String])] {
        if searchText.isEmpty {
            return categories
        }
        return categories.compactMap { category in
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
                VStack(spacing: 24) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search icons...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    .padding(.horizontal, 16)

                    // Categories
                    ForEach(filteredCategories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.name.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            // Icon grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                                ForEach(category.icons, id: \.self) { icon in
                                    IconPickerButton(
                                        icon: icon,
                                        isSelected: selectedIcon == icon,
                                        onTap: {
                                            HapticManager.selection()
                                            selectedIcon = icon
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
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
}

// MARK: - Icon Picker Button

private struct IconPickerButton: View {
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    isSelected
                        ? AnyShapeStyle(AppTheme.powerGradient)
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

// MARK: - Preview

#Preview {
    IconPicker(selectedIcon: .constant("bolt.fill"))
        .preferredColorScheme(.dark)
}
