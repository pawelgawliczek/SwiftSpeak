//
//  KeyboardPreviewView.swift
//  SwiftSpeak
//
//  Preview of keyboard UI for development/testing
//

import SwiftUI

struct KeyboardPreviewView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var selectedMode: FormattingMode = .raw
    @State private var selectedLanguage: Language = .spanish
    @State private var mockText = "Type here to test..."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Mock text field area
                VStack {
                    Text("Keyboard Preview")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 20)

                    TextEditor(text: $mockText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .frame(maxHeight: .infinity)
                }

                // Keyboard preview
                ModernKeyboardPreview(
                    selectedMode: $selectedMode,
                    selectedLanguage: $selectedLanguage,
                    isPro: settings.subscriptionTier != .free,
                    contexts: settings.contexts,
                    activeContext: settings.activeContext,
                    onContextChange: { context in
                        settings.setActiveContext(context)
                    }
                )
            }
        }
        .navigationTitle("Keyboard Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Modern Keyboard Preview
struct ModernKeyboardPreview: View {
    @Binding var selectedMode: FormattingMode
    @Binding var selectedLanguage: Language
    let isPro: Bool
    let contexts: [ConversationContext]
    let activeContext: ConversationContext?
    let onContextChange: (ConversationContext?) -> Void

    @State private var showModeDropdown = false
    @State private var showLanguageDropdown = false
    @State private var showContextPicker = false
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 16) {
            // Top row: Dropdowns + Context
            HStack(spacing: 12) {
                // Mode dropdown
                ModernDropdown(
                    label: "Mode",
                    icon: selectedMode.icon,
                    value: selectedMode.displayName,
                    isExpanded: $showModeDropdown,
                    options: FormattingMode.allCases.map { ($0.icon, $0.displayName, $0.rawValue) }
                ) { value in
                    if let mode = FormattingMode(rawValue: value) {
                        selectedMode = mode
                    }
                }
                .zIndex(showModeDropdown ? 2 : 1)

                // Context button (Pro only)
                if isPro {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONTEXT")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.4))
                            .tracking(0.5)

                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showContextPicker.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(activeContext?.icon ?? "👤")
                                    .font(.system(size: 14))

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .rotationEffect(.degrees(showContextPicker ? 180 : 0))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(activeContext != nil ? activeContext!.color.color.opacity(0.2) : Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .overlay(
                        Group {
                            if showContextPicker {
                                contextPickerOverlay
                                    .offset(y: 75)
                            }
                        },
                        alignment: .top
                    )
                    .zIndex(showContextPicker ? 3 : 0)
                }

                // Language dropdown
                ModernDropdown(
                    label: "Language",
                    icon: nil,
                    value: "\(selectedLanguage.flag) \(selectedLanguage.displayName)",
                    isExpanded: $showLanguageDropdown,
                    options: Language.allCases.map { ($0.flag, $0.displayName, $0.rawValue) }
                ) { value in
                    if let language = Language(rawValue: value) {
                        selectedLanguage = language
                    }
                }
                .zIndex(showLanguageDropdown ? 2 : 1)
            }
            .padding(.horizontal, 16)

            Spacer()
                .frame(height: 8)

            // Bottom row: Translate button + Transcribe button
            HStack(alignment: .bottom, spacing: 16) {
                // Translate button (smaller, left side)
                TranslateButton(isPro: isPro, isLocked: !isPro) {
                    // Mock action
                }

                Spacer()

                // Transcribe button (large, circular, center-right)
                TranscribeButton(isRecording: $isRecording) {
                    isRecording.toggle()
                }

                Spacer()

                // Backspace button (right side)
                IconButton(icon: "delete.left") {
                    // Mock action
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.10),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .top
        )
    }

    // MARK: - Context Picker Overlay

    @ViewBuilder
    private var contextPickerOverlay: some View {
        VStack(spacing: 0) {
            // No context option
            Button(action: {
                onContextChange(nil)
                withAnimation(.easeOut(duration: 0.2)) {
                    showContextPicker = false
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.slash")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("No Context")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    if activeContext == nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())

            if !contexts.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
            }

            // Context options
            ForEach(Array(contexts.enumerated()), id: \.element.id) { index, context in
                Button(action: {
                    onContextChange(context)
                    withAnimation(.easeOut(duration: 0.2)) {
                        showContextPicker = false
                    }
                }) {
                    HStack(spacing: 10) {
                        Text(context.icon)
                            .font(.system(size: 14))

                        Text(context.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        if activeContext?.id == context.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(context.color.color)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())

                if index < contexts.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 160)
    }
}

// MARK: - Modern Dropdown
struct ModernDropdown: View {
    let label: String
    let icon: String?
    let value: String
    @Binding var isExpanded: Bool
    let options: [(icon: String, title: String, value: String)]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.4))
                .tracking(0.5)

            // Dropdown button
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Group {
                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(options.indices, id: \.self) { index in
                            Button(action: {
                                onSelect(options[index].value)
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isExpanded = false
                                }
                            }) {
                                HStack(spacing: 10) {
                                    if options[index].icon.count <= 2 {
                                        Text(options[index].icon)
                                            .font(.system(size: 14))
                                    } else {
                                        Image(systemName: options[index].icon)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                    }

                                    Text(options[index].title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)

                                    Spacer()

                                    if options[index].value == value || options[index].title == value.replacingOccurrences(of: options[index].icon + " ", with: "") {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                            }
                            .buttonStyle(PlainButtonStyle())

                            if index < options.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .offset(y: 75)
                }
            },
            alignment: .top
        )
    }
}

// MARK: - Transcribe Button (Large Circular)
struct TranscribeButton: View {
    @Binding var isRecording: Bool
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            ZStack {
                // Outer glow when recording
                if isRecording {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseScale)
                }

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isRecording ?
                                [Color.red, Color.red.opacity(0.8)] :
                                [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: isRecording ? Color.red.opacity(0.4) : Color.blue.opacity(0.4), radius: 12, y: 4)

                // Icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

// MARK: - Translate Button
struct TranslateButton: View {
    let isPro: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLocked {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            isLocked ?
                                LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 48, height: 48)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                Text("Translate")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isLocked ? .gray : .white.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        KeyboardPreviewView()
            .environmentObject(SharedSettings.shared)
    }
}
