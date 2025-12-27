//
//  ContextEditorSheet.swift
//  SwiftSpeak
//
//  Phase 4: Create or edit a Conversation Context
//  Configure name, icon, tone, language hints, and memory settings
//

import SwiftUI

struct ContextEditorSheet: View {
    let context: ConversationContext
    let isNew: Bool
    let onSave: (ConversationContext) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    // Form state
    @State private var name: String = ""
    @State private var icon: String = "person.circle"
    @State private var color: PowerModeColorPreset = .blue
    @State private var description: String = ""
    @State private var toneDescription: String = ""
    @State private var formality: ContextFormality = .auto
    @State private var selectedLanguages: Set<Language> = []
    @State private var customInstructions: String = ""
    @State private var memoryEnabled: Bool = false
    @State private var memory: String = ""

    // UI state
    @State private var showingIconPicker = false
    @State private var showingMemoryEditor = false
    @State private var showingDeleteConfirmation = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Languages supported by the current transcription provider (at least "limited" level)
    private var supportedLanguages: [Language] {
        ProviderLanguageDatabase.languages(
            supportedBy: settings.selectedTranscriptionProvider,
            for: .transcription,
            minimumLevel: .limited
        ).sorted { $0.displayName < $1.displayName }
    }

    /// Whether DeepL is the selected translation provider
    private var isDeepLSelected: Bool {
        settings.selectedTranslationProvider == .deepL
    }

    init(context: ConversationContext, isNew: Bool, onSave: @escaping (ConversationContext) -> Void, onDelete: @escaping () -> Void) {
        self.context = context
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state
        _name = State(initialValue: context.name)
        _icon = State(initialValue: context.icon)
        _color = State(initialValue: context.color)
        _description = State(initialValue: context.description)
        _toneDescription = State(initialValue: context.toneDescription)
        _formality = State(initialValue: context.formality)
        _selectedLanguages = State(initialValue: Set(context.languageHints))
        _customInstructions = State(initialValue: context.customInstructions)
        _memoryEnabled = State(initialValue: context.memoryEnabled)
        _memory = State(initialValue: context.memory ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and color section
                    iconAndColorSection

                    // Name field
                    nameSection

                    // Short description
                    descriptionSection

                    // Tone & Style
                    toneSection

                    // Formality (explicit for DeepL)
                    formalitySection

                    // Expected languages
                    languagesSection

                    // Custom instructions
                    instructionsSection

                    // Memory section
                    memorySection

                    // Delete button (if editing)
                    if !isNew {
                        deleteSection
                    }
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle(isNew ? "New Context" : "Edit Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                UnifiedIconPicker(
                    selectedIcon: $icon,
                    selectedColor: $color,
                    showBackgroundColorPicker: false,
                    backgroundColor: $color
                )
                .presentationDetents([.large])
            }
            .confirmationDialog("Delete Context", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the context and its memory. This action cannot be undone.")
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Icon and Color Section

    private var iconAndColorSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                HapticManager.selection()
                showingIconPicker = true
            }) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(color.color.opacity(0.15))
                            .frame(width: 80, height: 80)

                        // Show SF Symbol if contains ".", otherwise show emoji
                        if icon.contains(".") {
                            Image(systemName: icon)
                                .font(.system(size: 40))
                                .foregroundStyle(color.gradient)
                        } else {
                            Text(icon)
                                .font(.system(size: 40))
                        }
                    }

                    Text("Tap to change icon & color")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Color picker - wrapped in ScrollView for horizontal scrolling on small screens
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PowerModeColorPreset.allCases) { colorPreset in
                        Button(action: {
                            HapticManager.selection()
                            color = colorPreset
                        }) {
                            Circle()
                                .fill(colorPreset.gradient)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(color == colorPreset ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .scaleEffect(color == colorPreset ? 1.1 : 1.0)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Context name", text: $name)
                .font(.body)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHORT DESCRIPTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Brief description for the list", text: $description)
                .font(.body)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Tone Section

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TONE & STYLE (DETAILED)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $toneDescription)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("Describe the tone, style, and personality for this context")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Formality Section

    private var formalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FORMALITY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // DeepL badge if applicable
                if isDeepLSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.caption2)
                        Text("DeepL")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }
            }

            // Formality picker
            HStack(spacing: 8) {
                ForEach(ContextFormality.allCases) { formalityOption in
                    Button(action: {
                        HapticManager.selection()
                        formality = formalityOption
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: formalityOption.icon)
                                .font(.title3)
                            Text(formalityOption.displayName)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(formality == formalityOption ? color.color.opacity(0.2) : Color.primary.opacity(0.05))
                        .foregroundStyle(formality == formalityOption ? color.color : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(formality == formalityOption ? color.color : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // DeepL-specific note
            if isDeepLSelected {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.subheadline)

                    Text("DeepL uses only this formality setting for translation. Your detailed tone description is used by other providers (OpenAI, Claude, Gemini).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // Description of selected formality
            Text(formality.description)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Languages Section

    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EXPECTED LANGUAGES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Show which provider is being used
                Text(settings.selectedTranscriptionProvider.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            if supportedLanguages.isEmpty {
                Text("No languages available for selected provider")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(supportedLanguages) { language in
                        Button(action: {
                            HapticManager.selection()
                            if selectedLanguages.contains(language) {
                                selectedLanguages.remove(language)
                            } else {
                                selectedLanguages.insert(language)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if selectedLanguages.contains(language) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                }
                                Text(language.displayName)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedLanguages.contains(language) ? color.color.opacity(0.2) : Color.primary.opacity(0.08))
                            .foregroundStyle(selectedLanguages.contains(language) ? color.color : .secondary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            Text("Languages supported by \(settings.selectedTranscriptionProvider.displayName)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CUSTOM INSTRUCTIONS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $customInstructions)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("These instructions are injected into all AI prompts when this context is active")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CONTEXT MEMORY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("", isOn: $memoryEnabled)
                    .labelsHidden()
                    .tint(color.color)
            }

            Text("Remember details from conversations in this context")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if memoryEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    if !memory.isEmpty {
                        Text(memory)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            HapticManager.selection()
                            showingMemoryEditor = true
                        }) {
                            Text(memory.isEmpty ? "Add Memory" : "Edit")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(color.color)
                        }

                        if !memory.isEmpty {
                            Button(action: {
                                HapticManager.lightTap()
                                memory = ""
                            }) {
                                Text("Clear")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(action: {
            HapticManager.warning()
            showingDeleteConfirmation = true
        }) {
            Text("Delete Context")
                .font(.body.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        let savedContext = ConversationContext(
            id: context.id,
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            color: color,
            description: description.trimmingCharacters(in: .whitespaces),
            toneDescription: toneDescription.trimmingCharacters(in: .whitespaces),
            formality: formality,
            languageHints: Array(selectedLanguages),
            customInstructions: customInstructions.trimmingCharacters(in: .whitespaces),
            memoryEnabled: memoryEnabled,
            memory: memory.isEmpty ? nil : memory,
            lastMemoryUpdate: context.lastMemoryUpdate,
            isActive: context.isActive,
            createdAt: context.createdAt,
            updatedAt: Date()
        )
        HapticManager.success()
        onSave(savedContext)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Preview

#Preview("New Context") {
    ContextEditorSheet(
        context: ConversationContext.empty,
        isNew: true,
        onSave: { _ in },
        onDelete: {}
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}

#Preview("Edit Context") {
    ContextEditorSheet(
        context: ConversationContext.samples.first!,
        isNew: false,
        onSave: { _ in },
        onDelete: {}
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}

#Preview("With DeepL Selected") {
    let settings = SharedSettings.shared
    settings.selectedTranslationProvider = .deepL
    return ContextEditorSheet(
        context: ConversationContext.samples[1], // Work context (formal)
        isNew: false,
        onSave: { _ in },
        onDelete: {}
    )
    .environmentObject(settings)
    .preferredColorScheme(.dark)
}
