//
//  ContextQuickSwitcher.swift
//  SwiftSpeak
//
//  Phase 4: Floating overlay to quickly switch between Conversation Contexts
//  Accessible from keyboard and recording views
//

import SwiftUI
import SwiftSpeakCore

struct ContextQuickSwitcher: View {
    @Binding var isPresented: Bool
    @Binding var contexts: [ConversationContext]
    let onSelect: (ConversationContext?) -> Void

    private var activeContext: ConversationContext? {
        contexts.first(where: { $0.isActive })
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AppTheme.quickSpring) {
                        isPresented = false
                    }
                }

            // Switcher card
            VStack(spacing: 20) {
                // Header
                Text("Switch Context")
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Context grid
                HStack(spacing: 16) {
                    ForEach(contexts.prefix(3)) { context in
                        ContextButton(
                            context: context,
                            isActive: context.isActive,
                            onTap: {
                                selectContext(context)
                            }
                        )
                    }

                    // None option
                    NoneContextButton(
                        isActive: activeContext == nil,
                        onTap: {
                            selectNone()
                        }
                    )
                }

                // Current context indicator
                if let active = activeContext {
                    Text("Currently: \(active.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No context active")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 24)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
        }
    }

    // MARK: - Actions

    private func selectContext(_ context: ConversationContext) {
        HapticManager.selection()
        onSelect(context)
        withAnimation(AppTheme.quickSpring) {
            isPresented = false
        }
    }

    private func selectNone() {
        HapticManager.selection()
        onSelect(nil)
        withAnimation(AppTheme.quickSpring) {
            isPresented = false
        }
    }
}

// MARK: - Context Button

private struct ContextButton: View {
    let context: ConversationContext
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(context.color.color.opacity(isActive ? 0.3 : 0.15))
                        .frame(width: 56, height: 56)

                    Text(context.icon)
                        .font(.title)
                }
                .overlay(
                    Circle()
                        .strokeBorder(isActive ? context.color.color : Color.clear, lineWidth: 2)
                )

                Text(context.name)
                    .font(.caption)
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(context.color.color)
                } else {
                    Color.clear
                        .frame(height: 14)
                }
            }
            .frame(width: 70)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - None Context Button

private struct NoneContextButton: View {
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(isActive ? 0.2 : 0.08))
                        .frame(width: 56, height: 56)

                    Image(systemName: "circle.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .overlay(
                    Circle()
                        .strokeBorder(isActive ? Color.secondary : Color.clear, lineWidth: 2)
                )

                Text("None")
                    .font(.caption)
                    .foregroundStyle(isActive ? .primary : .secondary)

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                } else {
                    Color.clear
                        .frame(height: 14)
                }
            }
            .frame(width: 70)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AppTheme.darkBase.ignoresSafeArea()

        ContextQuickSwitcher(
            isPresented: .constant(true),
            contexts: .constant(ConversationContext.samples),
            onSelect: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
