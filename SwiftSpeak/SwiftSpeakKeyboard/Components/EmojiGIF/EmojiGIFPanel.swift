//
//  EmojiGIFPanel.swift
//  SwiftSpeakKeyboard
//
//  Emoji panel with category tabs and search
//

import SwiftUI

struct EmojiGIFPanel: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with dismiss button
            HStack {
                Text("😀 Emoji")
                    .font(.subheadline.weight(.semibold))

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

            // Emoji keyboard
            EmojiKeyboard(viewModel: viewModel)
        }
    }
}

// MARK: - Preview
#Preview {
    EmojiGIFPanel(viewModel: KeyboardViewModel(), onDismiss: {})
        .preferredColorScheme(.dark)
}
