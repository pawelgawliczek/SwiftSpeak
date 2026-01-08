//
//  ContextEditorSheet.swift
//  SwiftSpeak
//
//  Create or edit a Conversation Context
//  Configure formatting chips, examples, memory, and keyboard behavior
//

import SwiftUI
import SwiftSpeakCore

struct ContextEditorSheet: View {
    let context: ConversationContext
    let isNew: Bool
    let onSave: (ConversationContext) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    // MARK: - Identity State
    @State private var name: String = ""
    @State private var icon: String = "person.circle"
    @State private var color: PowerModeColorPreset = .blue
    @State private var description: String = ""

    // MARK: - Transcription State
    @State private var domainJargon: DomainJargon = .none
    @State private var customJargon: [String] = []
    @State private var showingAddJargon = false
    @State private var newJargonText: String = ""
    @State private var inputLanguage: Language? = nil
    @State private var useCustomInputLanguage: Bool = false

    // MARK: - Formatting State
    @State private var examples: [String] = []
    @State private var selectedInstructions: Set<String> = []
    @State private var customInstructions: String = ""

    // MARK: - Memory State
    @State private var useGlobalMemory: Bool = true
    @State private var useContextMemory: Bool = false
    @State private var contextMemory: String = ""
    @State private var memoryLimit: Int = 2000

    // MARK: - Keyboard Behavior State
    @State private var autoSendAfterInsert: Bool = false
    @State private var enterKeyBehavior: EnterKeyBehavior = .defaultNewLine

    // MARK: - System State
    @State private var appAssignment: AppAssignment = AppAssignment()

    // MARK: - UI State
    @State private var showingIconPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAddExample = false
    @State private var newExampleText: String = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(context: ConversationContext, isNew: Bool, onSave: @escaping (ConversationContext) -> Void, onDelete: @escaping () -> Void) {
        self.context = context
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete

        // Initialize state from context
        _name = State(initialValue: context.name)
        _icon = State(initialValue: context.icon)
        _color = State(initialValue: context.color)
        _description = State(initialValue: context.description)
        _domainJargon = State(initialValue: context.domainJargon)
        _customJargon = State(initialValue: context.customJargon)
        _inputLanguage = State(initialValue: context.defaultInputLanguage)
        _useCustomInputLanguage = State(initialValue: context.defaultInputLanguage != nil)
        _examples = State(initialValue: context.examples)
        _selectedInstructions = State(initialValue: context.selectedInstructions)
        _customInstructions = State(initialValue: context.customInstructions ?? "")
        _useGlobalMemory = State(initialValue: context.useGlobalMemory)
        _useContextMemory = State(initialValue: context.useContextMemory)
        _contextMemory = State(initialValue: context.contextMemory ?? "")
        _memoryLimit = State(initialValue: context.memoryLimit)
        _autoSendAfterInsert = State(initialValue: context.autoSendAfterInsert)
        _enterKeyBehavior = State(initialValue: context.enterKeyBehavior)
        _appAssignment = State(initialValue: context.appAssignment)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    iconAndColorSection
                    nameSection
                    descriptionSection

                    sectionHeader("TRANSCRIPTION")
                    inputLanguageSection
                    domainJargonSection
                    customJargonSection

                    sectionHeader("EXAMPLES")
                    examplesSection

                    sectionHeader("FORMATTING")
                    formattingSection

                    sectionHeader("MEMORY")
                    memorySection

                    sectionHeader("KEYBOARD BEHAVIOR")
                    keyboardBehaviorSection

                    sectionHeader("APP ASSIGNMENT")
                    appAssignmentSection

                    if !isNew && !context.isPreset {
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
            .sheet(isPresented: $showingAddExample) {
                addExampleSheet
            }
            .sheet(isPresented: $showingAddJargon) {
                addJargonSheet
            }
            .confirmationDialog("Delete Context", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the context and its memory.")
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 8)
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

                        if icon.contains(".") {
                            Image(systemName: icon)
                                .font(.system(size: 40))
                                .foregroundStyle(color.gradient)
                        } else {
                            Text(icon)
                                .font(.system(size: 40))
                        }
                    }

                    Text("Tap to change icon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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

            TextField("Brief description", text: $description)
                .font(.body)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Input Language Section

    private var inputLanguageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(useCustomInputLanguage ? color.color : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Custom input language")
                        .font(.subheadline.weight(.medium))
                    Text("Override the default transcription language")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $useCustomInputLanguage)
                    .labelsHidden()
                    .tint(color.color)
                    .onChange(of: useCustomInputLanguage) { _, enabled in
                        if enabled && inputLanguage == nil {
                            inputLanguage = .english
                        }
                    }
            }

            if useCustomInputLanguage {
                HStack {
                    Text("Language")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("", selection: Binding(
                        get: { inputLanguage ?? .english },
                        set: { inputLanguage = $0 }
                    )) {
                        ForEach(Language.allCases) { lang in
                            HStack {
                                Text(lang.flag)
                                Text(lang.displayName)
                            }
                            .tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(color.color)
                }
                .padding(.leading, 52)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(color.color)
                        .font(.caption)
                    Text("This language will be sent to transcription services when this context is active. Leave off to use the global setting or auto-detect.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 52)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Domain Jargon Section

    private var domainJargonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Domain vocabulary")
                .font(.subheadline.weight(.medium))

            HStack {
                Picker("Domain", selection: $domainJargon) {
                    ForEach(DomainJargon.allCases) { jargon in
                        HStack {
                            Image(systemName: jargon.icon)
                            Text(jargon.displayName)
                        }
                        .tag(jargon)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Fixed height hint area to prevent layout jumping
            Group {
                if domainJargon != .none, let hint = domainJargon.transcriptionHint {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(color.color)
                            .font(.caption)
                        Text("Helps recognize: \(hint.replacingOccurrences(of: "\(domainJargon.displayName) terminology: ", with: ""))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    // Empty placeholder with same height
                    Text(" ")
                        .font(.caption)
                        .opacity(0)
                }
            }
            .frame(minHeight: 16)
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Custom Jargon Section

    private var customJargonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom jargon")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(customJargon.count) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Add specific terms, acronyms, names, or technical words that may be misrecognized")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Display existing jargon words as chips
            if !customJargon.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(customJargon.indices, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(customJargon[index])
                                .font(.subheadline)

                            Button(action: {
                                HapticManager.lightTap()
                                customJargon.remove(at: index)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(color.color.opacity(0.15))
                        .foregroundStyle(color.color)
                        .clipShape(Capsule())
                    }
                }
            }

            Button(action: {
                HapticManager.selection()
                newJargonText = ""
                showingAddJargon = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add jargon")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color.color)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(color.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(color.color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Add Jargon Sheet

    private var addJargonSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Add terms, acronyms, names, or technical words that might be misrecognized during transcription")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Enter jargon (comma-separated for multiple)", text: $newJargonText, axis: .vertical)
                    .font(.body)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                Text("Examples: API, OAuth, Kubernetes, Dr. Smith, HIPAA")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(16)
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Add Jargon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddJargon = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // Split by comma and add each word
                        let words = newJargonText
                            .components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty && !customJargon.contains($0) }
                        customJargon.append(contentsOf: words)
                        showingAddJargon = false
                    }
                    .disabled(newJargonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Examples Section

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Show the AI how you want your messages to look")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(examples.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text(examples[index])
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        HapticManager.lightTap()
                        examples.remove(at: index)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            Button(action: {
                HapticManager.selection()
                newExampleText = ""
                showingAddExample = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add example")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color.color)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(color.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(color.color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    // MARK: - Add Example Sheet

    private var addExampleSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Type an example of how you want your messages formatted")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextEditor(text: $newExampleText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                Spacer()
            }
            .padding(16)
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Add Example")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddExample = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = newExampleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            examples.append(trimmed)
                        }
                        showingAddExample = false
                    }
                    .disabled(newExampleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Formatting Section

    private var formattingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Light touch group
            instructionGroup(.lightTouch)

            // Grammar group
            instructionGroup(.grammar)

            // Style group
            instructionGroup(.style)

            // Emoji group (mutually exclusive)
            emojiGroup

            // Custom instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom instructions")
                    .font(.subheadline.weight(.medium))

                TextEditor(text: $customInstructions)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .padding(12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    private func instructionGroup(_ group: FormattingInstruction.InstructionGroup) -> some View {
        let info = FormattingInstruction.groupInfo(group)
        let instructions = FormattingInstruction.instructions(for: group)

        // Use a grid with fixed columns based on group
        let columns: [GridItem] = {
            switch group {
            case .lightTouch:
                // 3 items: punctuation, capitals, spelling - fit all on one row
                return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            case .grammar:
                // 1 item - full width
                return [GridItem(.flexible())]
            case .style:
                // 4 items - 2x2 grid
                return [GridItem(.flexible()), GridItem(.flexible())]
            case .emoji:
                // Handled separately
                return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(info.icon)
                Text(info.title)
                    .font(.subheadline.weight(.medium))
                Text("(\(info.subtitle))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(instructions) { instruction in
                    instructionChip(instruction)
                }
            }
        }
    }

    private func instructionChip(_ instruction: FormattingInstruction) -> some View {
        let isSelected = selectedInstructions.contains(instruction.id)

        return Button(action: {
            HapticManager.selection()
            if isSelected {
                selectedInstructions.remove(instruction.id)
            } else {
                selectedInstructions.insert(instruction.id)
            }
        }) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.semibold))
                }
                Text(instruction.displayName)
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? color.color.opacity(0.2) : Color.primary.opacity(0.08))
            .foregroundStyle(isSelected ? color.color : .secondary)
            .clipShape(Capsule())
        }
    }

    private var emojiGroup: some View {
        let info = FormattingInstruction.groupInfo(.emoji)
        let emojiInstructions = FormattingInstruction.instructions(for: .emoji)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(info.icon)
                Text(info.title)
                    .font(.subheadline.weight(.medium))
            }

            HStack(spacing: 8) {
                ForEach(emojiInstructions) { instruction in
                    emojiChip(instruction)
                }
            }
        }
    }

    private func emojiChip(_ instruction: FormattingInstruction) -> some View {
        let isSelected = selectedInstructions.contains(instruction.id)
        let emojiIds = ["emoji_never", "emoji_few", "emoji_lots"]

        return Button(action: {
            HapticManager.selection()
            // Remove other emoji options (mutually exclusive)
            for id in emojiIds {
                selectedInstructions.remove(id)
            }
            selectedInstructions.insert(instruction.id)
        }) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                }
                Text(instruction.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color.color.opacity(0.2) : Color.primary.opacity(0.08))
            .foregroundStyle(isSelected ? color.color : .secondary)
            .clipShape(Capsule())
        }
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Global memory toggle
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(useGlobalMemory ? color.color : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use global memory")
                        .font(.subheadline.weight(.medium))
                    Text("AI remembers info across all contexts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $useGlobalMemory)
                    .labelsHidden()
                    .tint(color.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Context memory toggle
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(useContextMemory ? color.color : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Use context memory")
                        .font(.subheadline.weight(.medium))
                    Text("AI remembers info specific to this context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $useContextMemory)
                    .labelsHidden()
                    .tint(color.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Memory limit slider (when context memory enabled)
            if useContextMemory {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Size Limit")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(memoryLimit) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: Binding(
                            get: { Double(memoryLimit) },
                            set: { memoryLimit = Int($0) }
                        ),
                        in: 500...2000,
                        step: 100
                    )
                    .tint(color.color)

                    Text("Smaller limits save API costs, larger limits preserve more context")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // Memory content editor (when enabled)
            if useContextMemory {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(color.color)
                        Text("Memory Content")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(contextMemory.count)/\(memoryLimit)")
                            .font(.caption2)
                            .foregroundStyle(contextMemory.count > memoryLimit ? Color.red : Color.secondary)
                            .monospacedDigit()
                    }

                    TextEditor(text: $contextMemory)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .padding(10)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                    Text("AI will reference this memory when formatting text in this context")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(color.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
        }
    }

    // MARK: - Keyboard Behavior Section

    private var keyboardBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Auto-send toggle
            HStack(spacing: 12) {
                Image(systemName: "paperplane")
                    .font(.title2)
                    .foregroundStyle(autoSendAfterInsert ? color.color : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-send after voice input")
                        .font(.subheadline.weight(.medium))
                    Text("Automatically tap send after text is inserted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $autoSendAfterInsert)
                    .labelsHidden()
                    .tint(color.color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Enter key behavior
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter key behavior")
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 4)

                ForEach(EnterKeyBehavior.allCases) { behavior in
                    Button(action: {
                        HapticManager.selection()
                        enterKeyBehavior = behavior
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: behavior.icon)
                                .font(.title3)
                                .foregroundStyle(enterKeyBehavior == behavior ? color.color : .secondary)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(behavior.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(behavior.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: enterKeyBehavior == behavior ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(enterKeyBehavior == behavior ? color.color : Color.secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(enterKeyBehavior == behavior ? color.color.opacity(0.1) : Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - App Assignment Section

    private var appAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto-enable this context in specific apps")
                .font(.caption)
                .foregroundStyle(.secondary)

            AppAssignmentSection(appAssignment: $appAssignment)
                .environmentObject(settings)
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

    // MARK: - Save Action

    private func saveAndDismiss() {
        let savedContext = ConversationContext(
            id: context.id,
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            color: color,
            description: description.trimmingCharacters(in: .whitespaces),
            domainJargon: domainJargon,
            customJargon: customJargon,
            examples: examples,
            selectedInstructions: selectedInstructions,
            customInstructions: customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customInstructions.trimmingCharacters(in: .whitespacesAndNewlines),
            useGlobalMemory: useGlobalMemory,
            useContextMemory: useContextMemory,
            contextMemory: contextMemory.isEmpty ? nil : contextMemory,
            memoryLimit: memoryLimit,
            lastMemoryUpdate: context.lastMemoryUpdate,
            autoSendAfterInsert: autoSendAfterInsert,
            enterKeyBehavior: enterKeyBehavior,
            defaultInputLanguage: useCustomInputLanguage ? inputLanguage : nil,
            isActive: context.isActive,
            appAssignment: appAssignment,
            isPreset: context.isPreset,
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
