//
//  MacContextsView.swift
//  SwiftSpeakMac
//
//  macOS version of Contexts list and editor
//  Contexts affect transcription, translation, and Power Mode behavior
//

import SwiftUI

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
            // Header row (always visible)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(context.color.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Text(context.icon)
                            .font(.system(size: 18))
                    }

                    // Name and description
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

                    Spacer()

                    // Feature badges
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

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 16) {
                    // Settings Grid
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

                        settingBadge(
                            title: "Insertion",
                            value: context.textInsertionMethod == .auto ? "Auto" : context.textInsertionMethod.displayName.components(separatedBy: " ").first ?? "Custom",
                            icon: context.textInsertionMethod.icon,
                            color: .orange
                        )
                    }

                    // Formatting instructions chips
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

                    // Custom instructions
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

                    // Memory content
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

                    // Action buttons
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
                .padding(12)
            }
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? context.color.color.opacity(0.5) : Color.clear, lineWidth: 2)
        )
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

    private let emojiOptions = ["💼", "😊", "✨", "🎯", "📝", "💡", "🔥", "🚀", "💬", "📚", "🎨", "⚡️"]

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
                            examples: context.examples,
                            selectedInstructions: context.selectedInstructions,
                            customInstructions: context.customInstructions,
                            useGlobalMemory: context.useGlobalMemory,
                            useContextMemory: context.useContextMemory,
                            memoryLimit: context.memoryLimit,
                            autoSendAfterInsert: context.autoSendAfterInsert,
                            enterKeyBehavior: context.enterKeyBehavior,
                            textInsertionMethod: context.textInsertionMethod,
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
                // Basic Info
                Section("Basic Information") {
                    TextField("Name", text: $context.name)
                    TextField("Description", text: $context.description)

                    HStack {
                        Text("Icon")
                        Spacer()
                        Picker("", selection: $context.icon) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Text(emoji).tag(emoji)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Picker("Color", selection: $context.color) {
                        ForEach(PowerModeColorPreset.allCases) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 12, height: 12)
                                Text(color.displayName)
                            }
                            .tag(color)
                        }
                    }
                }

                // Transcription Settings
                Section("Transcription") {
                    Picker("Domain Jargon", selection: $context.domainJargon) {
                        ForEach(DomainJargon.allCases) { jargon in
                            HStack {
                                Image(systemName: jargon.icon)
                                Text(jargon.displayName)
                            }
                            .tag(jargon)
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

                // Text Insertion
                Section {
                    Picker("Text Insertion Method", selection: $context.textInsertionMethod) {
                        ForEach(TextInsertionMethod.allCases) { method in
                            HStack {
                                Image(systemName: method.icon)
                                Text(method.displayName)
                            }
                            .tag(method)
                        }
                    }

                    Text(context.textInsertionMethod.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Text Insertion")
                } footer: {
                    Text("Choose how transcribed text is inserted into the focused application.")
                }

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
