//
//  MacContextsView.swift
//  SwiftSpeakMac
//
//  macOS version of Contexts list and editor
//  Contexts affect transcription, translation, and Power Mode behavior
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Contexts View

struct MacContextsView: View {
    @ObservedObject var settings: MacSettings
    @State private var showingNewEditor = false
    @State private var editingContext: ConversationContext?
    @State private var expandedContextId: UUID?
    @State private var showingDeleteConfirmation = false
    @State private var contextToDelete: ConversationContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contexts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Customize transcription behavior for different scenarios")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showingNewEditor = true }) {
                        Label("New Context", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 8)

                // Presets Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Presets")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(ConversationContext.presets) { context in
                        ContextCard(
                            context: context,
                            isExpanded: expandedContextId == context.id,
                            isActive: settings.activeContextId == context.id,
                            isPreset: true,
                            onTap: { toggleExpanded(context.id) },
                            onSetActive: { toggleActive(context) },
                            onEdit: nil,
                            onDelete: nil
                        )
                    }
                }

                // Custom Contexts Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    let customContexts = settings.contexts.filter { !$0.isPreset }
                    if customContexts.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text("No custom contexts yet")
                                    .foregroundStyle(.secondary)
                                Button("Create Context") {
                                    showingNewEditor = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                        .background(Color.primary.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        ForEach(customContexts) { context in
                            ContextCard(
                                context: context,
                                isExpanded: expandedContextId == context.id,
                                isActive: settings.activeContextId == context.id,
                                isPreset: false,
                                onTap: { toggleExpanded(context.id) },
                                onSetActive: { toggleActive(context) },
                                onEdit: { editingContext = context },
                                onDelete: {
                                    contextToDelete = context
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingNewEditor) {
            MacContextEditorSheet(
                context: ConversationContext.empty,
                isNew: true,
                settings: settings,
                onSave: { savedContext in
                    settings.addContext(savedContext)
                    expandedContextId = savedContext.id
                    showingNewEditor = false
                },
                onCancel: { showingNewEditor = false }
            )
        }
        .sheet(item: $editingContext) { context in
            MacContextEditorSheet(
                context: context,
                isNew: false,
                settings: settings,
                onSave: { savedContext in
                    settings.updateContext(savedContext)
                    editingContext = nil
                },
                onCancel: { editingContext = nil }
            )
        }
        .alert("Delete Context?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                contextToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let context = contextToDelete {
                    settings.deleteContext(id: context.id)
                    if expandedContextId == context.id {
                        expandedContextId = nil
                    }
                }
                contextToDelete = nil
            }
        } message: {
            if let context = contextToDelete {
                Text("Are you sure you want to delete \"\(context.name)\"? This action cannot be undone.")
            }
        }
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedContextId == id {
                expandedContextId = nil
            } else {
                expandedContextId = id
            }
        }
    }

    private func toggleActive(_ context: ConversationContext) {
        if settings.activeContextId == context.id {
            settings.setActiveContext(nil)
        } else {
            settings.setActiveContext(context)
        }
    }
}

// MARK: - Context Card

private struct ContextCard: View {
    let context: ConversationContext
    let isExpanded: Bool
    let isActive: Bool
    let isPreset: Bool
    let onTap: () -> Void
    let onSetActive: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            expandedContent
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isActive ? context.color.color : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var headerButton: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                contextIcon
                nameAndDescription
                Spacer()
                featureBadges
                expandIndicator
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var contextIcon: some View {
        ZStack {
            Circle()
                .fill(context.color.color.opacity(0.2))
                .frame(width: 40, height: 40)

            if context.icon.contains(".") {
                Image(systemName: context.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(context.color.gradient)
            } else {
                Text(context.icon)
                    .font(.system(size: 18))
            }
        }
    }

    private var nameAndDescription: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(context.name)
                    .font(.headline)

                if isActive {
                    Text("Active")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(context.color.color)
                        .clipShape(Capsule())
                }

                if isPreset {
                    Text("Preset")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if !context.description.isEmpty {
                Text(context.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
            }
        }
    }

    private var featureBadges: some View {
        HStack(spacing: 6) {
            if context.useContextMemory {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
            if !context.selectedInstructions.isEmpty {
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }

    private var expandIndicator: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundStyle(.tertiary)
            .font(.caption)
    }

    @ViewBuilder
    private var expandedContent: some View {
        if isExpanded {
            Divider()
                .padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 16) {
                settingsGrid
                formattingChips
                actionButtons
            }
            .padding(12)
        }
    }

    private var settingsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            settingBadge(
                title: "Domain",
                value: context.domainJargon.displayName,
                icon: context.domainJargon.icon,
                color: .blue
            )

            settingBadge(
                title: "Custom Jargon",
                value: "\(context.customJargon.count) words",
                icon: "text.word.spacing",
                color: .orange
            )

            settingBadge(
                title: "Formatting",
                value: "\(context.selectedInstructions.count) rules",
                icon: "textformat",
                color: .green
            )

            settingBadge(
                title: "Memory",
                value: context.useContextMemory ? "On" : "Off",
                icon: "brain",
                color: .purple
            )
        }
    }

    @ViewBuilder
    private var formattingChips: some View {
        if !context.formattingInstructions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Formatting Instructions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(context.formattingInstructions, id: \.id) { instruction in
                        HStack(spacing: 4) {
                            if let icon = instruction.icon {
                                Image(systemName: icon)
                                    .font(.caption2)
                            }
                            Text(instruction.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }

        if let customInstructions = context.customInstructions, !customInstructions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Instructions")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(customInstructions)
                    .font(.callout)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }

        if !context.customJargon.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Jargon")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(context.customJargon.prefix(15), id: \.self) { word in
                        Text(word)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if context.customJargon.count > 15 {
                        Text("+\(context.customJargon.count - 15) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                }
            }
        }

        if context.useContextMemory {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Context Memory")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastUpdate = context.lastMemoryUpdate {
                        Spacer()
                        Text("Updated \(lastUpdate, style: .relative)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(context.contextMemory ?? "No memory stored yet")
                    .font(.callout)
                    .foregroundStyle(context.contextMemory == nil ? .tertiary : .primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onSetActive) {
                if isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                } else {
                    Label("Set Active", systemImage: "circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? context.color.color : .accentColor)

            if let onEdit = onEdit {
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
        }
    }

    private func settingBadge(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Context Editor Sheet

struct MacContextEditorSheet: View {
    @State var context: ConversationContext
    let isNew: Bool
    @ObservedObject var settings: MacSettings
    let onSave: (ConversationContext) -> Void
    let onCancel: () -> Void

    @State private var showingIconPicker = false
    @State private var newJargonInput: String = ""

    private func addJargonWords() {
        let words = newJargonInput
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !context.customJargon.contains($0) }
        context.customJargon.append(contentsOf: words)
        newJargonInput = ""
    }

    private func appName(for bundleId: String) -> String {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            return app.localizedName ?? bundleId.components(separatedBy: ".").last ?? bundleId
        }
        // Extract app name from bundle ID (e.g., "com.slack.Slack" -> "Slack")
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Text(isNew ? "New Context" : "Edit Context")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    var finalContext = context
                    if isNew {
                        finalContext = ConversationContext(
                            id: UUID(),
                            name: context.name,
                            icon: context.icon,
                            color: context.color,
                            description: context.description,
                            domainJargon: context.domainJargon,
                            customJargon: context.customJargon,
                            examples: context.examples,
                            selectedInstructions: context.selectedInstructions,
                            customInstructions: context.customInstructions,
                            useGlobalMemory: context.useGlobalMemory,
                            useContextMemory: context.useContextMemory,
                            memoryLimit: context.memoryLimit,
                            autoSendAfterInsert: context.autoSendAfterInsert,
                            enterKeyBehavior: context.enterKeyBehavior,
                            defaultInputLanguage: context.defaultInputLanguage,
                            transcriptionProviderOverride: context.transcriptionProviderOverride,
                            translationProviderOverride: context.translationProviderOverride,
                            aiProviderOverride: context.aiProviderOverride,
                            appAssignment: context.appAssignment,
                            isPreset: false
                        )
                    }
                    onSave(finalContext)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(context.name.isEmpty)
            }
            .padding()

            Divider()

            // Form
            Form {
                // Icon and Color Section
                Section {
                    HStack {
                        Spacer()
                        Button(action: { showingIconPicker = true }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(context.color.color.opacity(0.15))
                                        .frame(width: 80, height: 80)

                                    if context.icon.contains(".") {
                                        Image(systemName: context.icon)
                                            .font(.system(size: 36))
                                            .foregroundStyle(context.color.gradient)
                                    } else {
                                        Text(context.icon)
                                            .font(.system(size: 36))
                                    }
                                }

                                Text("Click to change icon")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    // Color picker row
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(PowerModeColorPreset.allCases) { colorPreset in
                                Button(action: { context.color = colorPreset }) {
                                    Circle()
                                        .fill(colorPreset.gradient)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(context.color == colorPreset ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                        .scaleEffect(context.color == colorPreset ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: context.color)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Basic Info
                Section("Basic Information") {
                    TextField("Name", text: $context.name)
                    TextField("Description", text: $context.description)
                }

                // Transcription Settings
                Section {
                    // Input Language Override
                    Toggle("Custom Input Language", isOn: Binding(
                        get: { context.defaultInputLanguage != nil },
                        set: { enabled in
                            if enabled {
                                context.defaultInputLanguage = .english
                            } else {
                                context.defaultInputLanguage = nil
                            }
                        }
                    ))

                    if context.defaultInputLanguage != nil {
                        Picker("Language", selection: Binding(
                            get: { context.defaultInputLanguage ?? .english },
                            set: { context.defaultInputLanguage = $0 }
                        )) {
                            ForEach(Language.allCases) { lang in
                                HStack {
                                    Text(lang.flag)
                                    Text(lang.displayName)
                                }
                                .tag(lang)
                            }
                        }
                    }

                    Picker("Domain Jargon", selection: $context.domainJargon) {
                        ForEach(DomainJargon.allCases) { jargon in
                            HStack {
                                Image(systemName: jargon.icon)
                                Text(jargon.displayName)
                            }
                            .tag(jargon)
                        }
                    }

                    // Custom Jargon
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Custom Jargon")
                                .font(.callout)
                            Spacer()
                            Text("\(context.customJargon.count) words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Add specific terms, acronyms, or names that may be misrecognized")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Display existing jargon
                        if !context.customJargon.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(context.customJargon.indices, id: \.self) { index in
                                    HStack(spacing: 4) {
                                        Text(context.customJargon[index])
                                            .font(.caption)
                                        Button(action: {
                                            context.customJargon.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(context.color.color.opacity(0.15))
                                    .foregroundStyle(context.color.color)
                                    .clipShape(Capsule())
                                }
                            }
                        }

                        // Add jargon text field
                        HStack {
                            TextField("Add jargon (comma-separated)", text: $newJargonInput)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addJargonWords()
                                }
                            Button("Add") {
                                addJargonWords()
                            }
                            .disabled(newJargonInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                } header: {
                    Text("Transcription")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if context.defaultInputLanguage != nil {
                            Text("Custom language will be sent to transcription services when this context is active.")
                        }
                        if context.domainJargon != .none {
                            Text("Domain jargon helps recognize industry-specific terminology.")
                        }
                    }
                }

                // Formatting Instructions
                Section("Formatting Instructions") {
                    ForEach(FormattingInstruction.InstructionGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 8) {
                                ForEach(FormattingInstruction.all.filter { $0.group == group }, id: \.id) { instruction in
                                    Toggle(isOn: Binding(
                                        get: { context.selectedInstructions.contains(instruction.id) },
                                        set: { isOn in
                                            if isOn {
                                                context.selectedInstructions.insert(instruction.id)
                                            } else {
                                                context.selectedInstructions.remove(instruction.id)
                                            }
                                        }
                                    )) {
                                        HStack(spacing: 4) {
                                            if let icon = instruction.icon {
                                                Image(systemName: icon)
                                                    .font(.caption)
                                            }
                                            Text(instruction.displayName)
                                                .font(.callout)
                                        }
                                    }
                                    .toggleStyle(.button)
                                }
                            }
                        }
                    }

                    TextField("Custom Instructions", text: Binding(
                        get: { context.customInstructions ?? "" },
                        set: { context.customInstructions = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                // Memory Settings
                Section("Memory") {
                    Toggle("Use Global Memory", isOn: $context.useGlobalMemory)
                    Toggle("Use Context-Specific Memory", isOn: $context.useContextMemory)

                    if context.useContextMemory {
                        Stepper("Memory Limit: \(context.memoryLimit) characters",
                                value: $context.memoryLimit,
                                in: 500...2000,
                                step: 100)
                    }
                }

                // Keyboard Behavior
                Section("Keyboard Behavior") {
                    Toggle("Auto-send after insert", isOn: $context.autoSendAfterInsert)

                    Picker("Enter Key Behavior", selection: $context.enterKeyBehavior) {
                        ForEach(EnterKeyBehavior.allCases) { behavior in
                            HStack {
                                Image(systemName: behavior.icon)
                                Text(behavior.displayName)
                            }
                            .tag(behavior)
                        }
                    }
                }

                // Provider Overrides
                Section {
                    ProviderOverridesSection(
                        transcriptionOverride: $context.transcriptionProviderOverride,
                        translationOverride: $context.translationProviderOverride,
                        aiOverride: $context.aiProviderOverride,
                        transcriptionProviders: settings.configuredAIProviders.map(\.provider).filter { $0.supportsTranscription },
                        translationProviders: settings.configuredAIProviders.map(\.provider).filter { $0.supportsTranslation },
                        aiProviders: settings.configuredAIProviders.map(\.provider).filter { $0.supportsPowerMode },
                        globalTranscription: settings.selectedTranscriptionProvider,
                        globalTranslation: settings.selectedTranslationProvider,
                        globalAI: settings.selectedPowerModeProvider,
                        isStreamingEnabled: settings.transcriptionStreamingEnabled
                    )
                } header: {
                    Text("Provider Overrides")
                }

                // TODO: Text Insertion Method - macOS-specific feature to be added to shared model
                // This feature allows choosing how text is inserted:
                // .auto, .accessibility, .clipboard, .typeCharacters

                // App Auto-Enable
                Section {
                    // Summary
                    if context.appAssignment.hasAssignments {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-enabled for:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(context.appAssignment.summary)
                                .font(.callout)
                        }
                    }

                    // Specific apps
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Specific Apps:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            RunningAppsMenu(selectedBundleIds: $context.appAssignment.assignedAppIds)
                        }

                        if !context.appAssignment.assignedAppIds.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(Array(context.appAssignment.assignedAppIds).sorted(), id: \.self) { bundleId in
                                    HStack(spacing: 4) {
                                        AppIconView(bundleId: bundleId, size: 14)
                                        Text(appName(for: bundleId))
                                            .font(.caption)
                                        Button(action: {
                                            context.appAssignment.assignedAppIds.remove(bundleId)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Categories:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        FlowLayout(spacing: 8) {
                            ForEach(AppCategory.allCases) { category in
                                Toggle(isOn: Binding(
                                    get: { context.appAssignment.assignedCategories.contains(category) },
                                    set: { isOn in
                                        if isOn {
                                            context.appAssignment.assignedCategories.insert(category)
                                        } else {
                                            context.appAssignment.assignedCategories.remove(category)
                                        }
                                    }
                                )) {
                                    HStack(spacing: 4) {
                                        Image(systemName: category.icon)
                                            .font(.caption)
                                        Text(category.displayName)
                                            .font(.callout)
                                    }
                                }
                                .toggleStyle(.button)
                            }
                        }
                    }
                } header: {
                    Text("App Auto-Enable")
                } footer: {
                    Text("Automatically switch to this context when the frontmost app matches. Specific apps take priority over categories.")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 550, height: 750)
        .sheet(isPresented: $showingIconPicker) {
            MacIconPicker(
                selectedIcon: $context.icon,
                selectedColor: $context.color,
                showBackgroundColorPicker: false,
                backgroundColor: $context.color
            )
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}

// MARK: - Running Apps Menu

struct RunningAppsMenu: View {
    @Binding var selectedBundleIds: Set<String>

    private var runningApps: [(name: String, bundleId: String, icon: NSImage?)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .compactMap { app in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return (name: name, bundleId: bundleId, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Menu {
            ForEach(runningApps, id: \.bundleId) { app in
                Button(action: {
                    if selectedBundleIds.contains(app.bundleId) {
                        selectedBundleIds.remove(app.bundleId)
                    } else {
                        selectedBundleIds.insert(app.bundleId)
                    }
                }) {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 16, height: 16)
                        }
                        Text(app.name)
                        Spacer()
                        if selectedBundleIds.contains(app.bundleId) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if runningApps.isEmpty {
                Text("No apps running")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Add App", systemImage: "plus.app")
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - App Icon Helper

struct AppIconView: View {
    let bundleId: String
    var size: CGFloat = 16

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.8))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            loadIcon()
        }
    }

    private func loadIcon() {
        // Try to get icon from running app
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            icon = app.icon
            return
        }

        // Try to get icon from app path
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        }
    }
}

// MARK: - Preview

#Preview {
    MacContextsView(settings: MacSettings.shared)
        .frame(width: 600, height: 700)
}
