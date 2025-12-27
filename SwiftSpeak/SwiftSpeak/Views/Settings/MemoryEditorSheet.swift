//
//  MemoryEditorSheet.swift
//  SwiftSpeak
//
//  Phase 4: Edit memory content for History, Workflow, or Context memory
//

import SwiftUI

struct MemoryEditorSheet: View {
    let title: String
    @Binding var content: String
    let lastUpdated: Date?
    let onSave: () -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false
    @FocusState private var isFocused: Bool

    private let maxCharacters = 2000

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Title
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .padding(.top, 8)

                        // Text editor
                        TextEditor(text: $content)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 250)
                            .focused($isFocused)
                            .padding(12)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                        // Metadata
                        HStack {
                            if let updated = lastUpdated {
                                Text("Last updated: \(formatDate(updated))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Text("\(content.count) / \(maxCharacters)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(content.count > maxCharacters ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                        }

                        // Clear button
                        if !content.isEmpty {
                            Button(action: {
                                HapticManager.warning()
                                showingClearConfirmation = true
                            }) {
                                Text("Clear Memory")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(16)
                }
                .background(AppTheme.darkBase.ignoresSafeArea())
            }
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticManager.success()
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(content.count > maxCharacters)
                }
            }
            .confirmationDialog("Clear Memory", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    onClear()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the stored memory. This action cannot be undone.")
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    MemoryEditorSheet(
        title: "Fatma - Context Memory",
        content: .constant("Fatma mentioned she has a meeting on Tuesday afternoon. We're planning dinner for Friday. She prefers Italian food lately."),
        lastUpdated: Date().addingTimeInterval(-3600),
        onSave: {},
        onClear: {}
    )
    .preferredColorScheme(.dark)
}
