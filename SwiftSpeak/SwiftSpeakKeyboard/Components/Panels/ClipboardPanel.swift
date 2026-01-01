//
//  ClipboardPanel.swift
//  SwiftSpeakKeyboard
//
//  Clipboard panel with history items from transcriptions and pinned custom text
//

import SwiftUI

// MARK: - Clipboard Panel Picker Mode
enum ClipboardPickerMode {
    case none
    case addCustom
}

// MARK: - Clipboard Panel
struct ClipboardPanel: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onDismiss: () -> Void

    @State private var pickerMode: ClipboardPickerMode = .none
    @State private var customText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.blue)
                    Text("Clipboard")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button(action: {
                    pickerMode = .addCustom
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // Content
            if pickerMode == .addCustom {
                addCustomView
            } else {
                clipboardListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(white: 0.12), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            viewModel.loadClipboardItems()
        }
    }

    // MARK: - Clipboard List View
    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Pinned Section
                if !viewModel.pinnedClipboardItems.isEmpty {
                    Section {
                        ForEach(viewModel.pinnedClipboardItems) { item in
                            ClipboardItemRow(
                                item: item,
                                onTap: {
                                    viewModel.insertClipboardItem(item)
                                    onDismiss()
                                },
                                onPin: nil,  // Already pinned
                                onUnpin: { viewModel.unpinClipboardItem(item) },
                                onDelete: { viewModel.deletePinnedItem(item) }
                            )
                        }
                    } header: {
                        HStack {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                            Text("PINNED")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }

                // History Section
                if !viewModel.clipboardItems.isEmpty {
                    Section {
                        ForEach(viewModel.clipboardItems) { item in
                            ClipboardItemRow(
                                item: item,
                                onTap: {
                                    viewModel.insertClipboardItem(item)
                                    onDismiss()
                                },
                                onPin: { viewModel.pinClipboardItem(item) },
                                onUnpin: nil,
                                onDelete: nil
                            )
                        }
                    } header: {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("RECENT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }

                // Empty State
                if viewModel.clipboardItems.isEmpty && viewModel.pinnedClipboardItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))

                        Text("No clipboard items")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("Your transcription history will appear here.\nTap + to add custom text.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Add Custom View
    private var addCustomView: some View {
        VStack(spacing: 16) {
            Text("Add Custom Text")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 16)

            // Text field
            TextField("Enter text to save...", text: $customText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($isTextFieldFocused)
                .lineLimit(1...5)
                .padding(.horizontal, 16)

            // Buttons
            HStack(spacing: 12) {
                Button(action: {
                    customText = ""
                    pickerMode = .none
                }) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button(action: {
                    viewModel.addCustomClipboardItem(text: customText)
                    customText = ""
                    pickerMode = .none
                }) {
                    Text("Save")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(customText.isEmpty)
                .opacity(customText.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Clipboard Item Row
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let onTap: () -> Void
    let onPin: (() -> Void)?
    let onUnpin: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36)

                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.preview)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(item.timeAgo)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    if let onPin = onPin {
                        Button(action: onPin) {
                            Image(systemName: "pin")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    if let onUnpin = onUnpin {
                        Button(action: onUnpin) {
                            Image(systemName: "pin.slash")
                                .font(.system(size: 14))
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                    }

                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPressed ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var iconName: String {
        switch item.source {
        case .transcription: return "waveform"
        case .custom: return "text.quote"
        case .system: return "doc.on.clipboard"
        }
    }

    private var iconColor: Color {
        switch item.source {
        case .transcription: return .blue
        case .custom: return .purple
        case .system: return .green
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.2)
    }
}

#Preview {
    ClipboardPanel(viewModel: KeyboardViewModel(), onDismiss: {})
        .preferredColorScheme(.dark)
}
