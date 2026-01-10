//
//  PowerModeEditorView.swift
//  SwiftSpeak
//
//  Create or edit a Power Mode with all configuration options
//  Phase 4: Removed capabilities, added Memory and Knowledge Base sections
//

import SwiftUI
import SwiftSpeakCore

struct PowerModeEditorView: View {
    let powerMode: PowerMode?
    let onSave: (PowerMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SharedSettings

    // Form state
    @State private var name: String = ""
    @State private var icon: String = "bolt.fill"
    @State private var iconColor: PowerModeColorPreset = .orange
    @State private var iconBackgroundColor: PowerModeColorPreset = .orange
    @State private var instruction: String = ""
    @State private var outputFormat: String = ""

    // Phase 4: Memory
    @State private var memoryEnabled: Bool = false
    @State private var memoryContent: String = ""
    @State private var memoryLimit: Int = 2000

    // App assignment
    @State private var appAssignment: AppAssignment = AppAssignment()

    // Phase 4e: RAG Knowledge Documents
    @State private var knowledgeDocumentIds: [UUID] = []

    // Phase 4f: Webhooks
    @State private var enabledWebhookIds: [UUID] = []

    // Phase 10: Provider override
    @State private var providerOverride: ProviderSelection?

    // Phase 13.11: AI Autocorrect
    @State private var aiAutocorrectEnabled: Bool = false

    // Phase 13.11: Enter key behavior
    @State private var enterSendsMessage: Bool = true
    @State private var enterRunsContext: Bool = false

    // Phase 3: Obsidian Integration
    @State private var obsidianVaultIds: [UUID] = []
    @State private var includeWindowContext: Bool = false
    @State private var maxObsidianChunks: Int = 3
    @State private var obsidianAction: ObsidianActionConfig? = nil
    @State private var defaultObsidianSearchQuery: String = ""

    // Phase 17: Input/Output Actions (unified system replaces Phase 16 config)
    @State private var inputActions: [InputAction] = []
    @State private var outputActions: [OutputAction] = []

    // UI state
    @State private var showingIconPicker = false
    @State private var showingKnowledgeBase = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !instruction.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Creates a temporary PowerMode with current editor values for KnowledgeBaseView
    private var currentPowerModeForKnowledgeBase: PowerMode {
        PowerMode(
            id: powerMode?.id ?? UUID(),
            name: name,
            icon: icon,
            iconColor: iconColor,
            iconBackgroundColor: iconBackgroundColor,
            instruction: instruction,
            outputFormat: outputFormat,
            memoryEnabled: memoryEnabled,
            memory: memoryContent.isEmpty ? nil : memoryContent,
            knowledgeDocumentIds: knowledgeDocumentIds,
            appAssignment: appAssignment,
            enabledWebhookIds: enabledWebhookIds,
            providerOverride: providerOverride,
            aiAutocorrectEnabled: aiAutocorrectEnabled,
            enterSendsMessage: enterSendsMessage,
            enterRunsContext: enterRunsContext,
            obsidianVaultIds: obsidianVaultIds,
            includeWindowContext: includeWindowContext,
            maxObsidianChunks: maxObsidianChunks,
            obsidianAction: obsidianAction,
            defaultObsidianSearchQuery: defaultObsidianSearchQuery,
            inputActions: inputActions,
            outputActions: outputActions
        )
    }

    init(powerMode: PowerMode?, onSave: @escaping (PowerMode) -> Void) {
        self.powerMode = powerMode
        self.onSave = onSave

        // Initialize state from powerMode if editing
        if let mode = powerMode {
            _name = State(initialValue: mode.name)
            _icon = State(initialValue: mode.icon)
            _iconColor = State(initialValue: mode.iconColor)
            _iconBackgroundColor = State(initialValue: mode.iconBackgroundColor)
            _instruction = State(initialValue: mode.instruction)
            _outputFormat = State(initialValue: mode.outputFormat)
            _memoryEnabled = State(initialValue: mode.memoryEnabled)
            _memoryContent = State(initialValue: mode.memory ?? "")
            _memoryLimit = State(initialValue: mode.memoryLimit)
            _appAssignment = State(initialValue: mode.appAssignment)
            _knowledgeDocumentIds = State(initialValue: mode.knowledgeDocumentIds)
            _enabledWebhookIds = State(initialValue: mode.enabledWebhookIds)
            _providerOverride = State(initialValue: mode.providerOverride)
            _aiAutocorrectEnabled = State(initialValue: mode.aiAutocorrectEnabled)
            _enterSendsMessage = State(initialValue: mode.enterSendsMessage)
            _enterRunsContext = State(initialValue: mode.enterRunsContext)
            _obsidianVaultIds = State(initialValue: mode.obsidianVaultIds)
            _includeWindowContext = State(initialValue: mode.includeWindowContext)
            _maxObsidianChunks = State(initialValue: mode.maxObsidianChunks)
            _obsidianAction = State(initialValue: mode.obsidianAction)
            _defaultObsidianSearchQuery = State(initialValue: mode.defaultObsidianSearchQuery)
            // Migrate legacy config to actions if needed, then load actions
            _inputActions = State(initialValue: mode.migratedInputActions)
            _outputActions = State(initialValue: mode.migratedOutputActions)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon and name section
                    iconAndNameSection

                    // Instruction section
                    instructionSection

                    // Output format section
                    outputFormatSection

                    // CONTEXT SOURCES section (Phase 17 - unified)
                    InputActionsEditor(actions: $inputActions)

                    // DELIVERY ACTIONS section (Phase 17 - unified)
                    OutputActionsEditor(actions: $outputActions)

                    // Provider override section (Phase 10)
                    providerOverrideSection

                    // AI Autocorrect section (Phase 13.11)
                    aiAutocorrectSection

                    // App assignment section
                    appAssignmentSection
                }
                .padding(16)
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle(powerMode == nil ? "New Power Mode" : "Edit Power Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPicker(
                    selectedIcon: $icon,
                    iconColor: $iconColor,
                    iconBackgroundColor: $iconBackgroundColor
                )
            }
            .sheet(isPresented: $showingKnowledgeBase) {
                KnowledgeBaseView(
                    powerMode: currentPowerModeForKnowledgeBase,
                    documentIds: $knowledgeDocumentIds
                )
            }
        }
    }

    // MARK: - Icon and Name Section

    private var iconAndNameSection: some View {
        VStack(spacing: 20) {
            // Icon button
            Button(action: {
                HapticManager.selection()
                showingIconPicker = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(iconColor.gradient)
                        .frame(width: 80, height: 80)
                        .background(iconBackgroundColor.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

                    Text("Tap to change icon & colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Name field
            VStack(spacing: 8) {
                TextField("Mode Name", text: $name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                Text("The name defines the AI's role (e.g., \"Email Writer\" → AI becomes an Email Writer assistant)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Instruction Section

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSTRUCTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $instruction)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("What the AI should do with your voice input")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Output Format Section

    private var outputFormatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUTPUT FORMAT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $outputFormat)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            Text("How to format the response (markdown)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }


    // MARK: - Memory Section (Phase 4)

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKFLOW MEMORY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            // Memory toggle
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(memoryEnabled ? AppTheme.powerAccent : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Memory")
                        .font(.subheadline.weight(.medium))

                    Text("Remember context from previous sessions with this mode")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $memoryEnabled)
                    .labelsHidden()
                    .tint(AppTheme.powerAccent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Memory limit slider (when memory enabled)
            if memoryEnabled {
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
                    .tint(AppTheme.powerAccent)

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
            if memoryEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("Memory Content")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(memoryContent.count)/\(memoryLimit)")
                            .font(.caption2)
                            .foregroundStyle(memoryContent.count > memoryLimit ? Color.red : Color.secondary)
                            .monospacedDigit()
                    }

                    TextEditor(text: $memoryContent)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .padding(10)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                    HStack {
                        Text("AI will reference this memory when using this Power Mode")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer()

                        if let lastUpdate = powerMode?.lastMemoryUpdate {
                            Text("Updated \(lastUpdate.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(12)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // History link (if editing existing mode)
            if let mode = powerMode, mode.usageCount > 0 {
                NavigationLink(destination: HistoryView(filterPowerModeId: mode.id, showFilterBar: false)
                    .navigationTitle("\(mode.name) History")) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(AppTheme.powerAccent)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Usage History")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("\(mode.usageCount) transcription\(mode.usageCount == 1 ? "" : "s") with this mode")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Knowledge Base Section (Phase 4)

    private var knowledgeBaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KNOWLEDGE BASE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: {
                HapticManager.selection()
                showingKnowledgeBase = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(AppTheme.powerAccent)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Documents")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        let docCount = powerMode?.knowledgeDocumentIds.count ?? 0
                        Text(docCount == 0 ? "No documents attached" : "\(docCount) document\(docCount == 1 ? "" : "s") attached")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())

            Text("Upload PDFs, text files, or URLs to give this mode context")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Webhooks Section (Phase 4f)

    private var webhooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WEBHOOKS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink(destination: WebhooksView()) {
                    HStack(spacing: 4) {
                        Text("Configure")
                            .font(.caption.weight(.medium))
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(AppTheme.powerAccent)
                }
            }

            if settings.webhooks.isEmpty {
                // No webhooks configured
                HStack(spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Webhooks")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Text("Configure webhooks in Settings to connect to external services")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            } else {
                // Show webhooks grouped by type
                VStack(spacing: 8) {
                    webhookTypeGroup(type: .contextSource, icon: "arrow.down.doc", label: "Context Sources")
                    webhookTypeGroup(type: .outputDestination, icon: "arrow.up.doc", label: "Output Destinations")
                    webhookTypeGroup(type: .automationTrigger, icon: "bolt.horizontal", label: "Automation Triggers")
                }
            }

            let enabledCount = enabledWebhookIds.count
            if enabledCount > 0 {
                Text("\(enabledCount) webhook\(enabledCount == 1 ? "" : "s") enabled for this mode")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Enable webhooks to fetch context or send output to external services")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func webhookTypeGroup(type: WebhookType, icon: String, label: String) -> some View {
        let webhooksOfType = settings.webhooks.filter { $0.type == type }

        if !webhooksOfType.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)

                ForEach(webhooksOfType) { webhook in
                    webhookToggleRow(webhook: webhook)
                }
            }
        }
    }

    private func webhookToggleRow(webhook: Webhook) -> some View {
        let isEnabled = enabledWebhookIds.contains(webhook.id)

        return Button(action: {
            HapticManager.selection()
            if isEnabled {
                enabledWebhookIds.removeAll { $0 == webhook.id }
            } else {
                enabledWebhookIds.append(webhook.id)
            }
        }) {
            HStack(spacing: 12) {
                // Template icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(webhookTemplateColor(webhook.template).opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: webhook.template.icon)
                        .font(.caption)
                        .foregroundStyle(webhookTemplateColor(webhook.template))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(webhook.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(webhook.url.host ?? "")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Toggle indicator
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isEnabled ? AppTheme.powerAccent : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isEnabled ? AppTheme.powerAccent.opacity(0.1) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func webhookTemplateColor(_ template: WebhookTemplate) -> Color {
        switch template {
        case .slack: return .purple
        case .notion: return .gray
        case .todoist: return .red
        case .make: return .purple
        case .zapier: return .orange
        case .custom: return .blue
        }
    }

    // MARK: - Obsidian Vaults Section (Phase 3)

    private var obsidianVaultsSection: some View {
        PowerModeVaultSection(
            selectedVaultIds: $obsidianVaultIds,
            maxChunks: $maxObsidianChunks,
            includeWindowContext: $includeWindowContext
        )
    }

    // MARK: - Obsidian Action Section (Phase 3)

    private var obsidianActionSection: some View {
        PowerModeActionSection(
            action: $obsidianAction,
            availableVaults: settings.obsidianVaults
        )
    }

    // MARK: - Provider Override Section (Phase 10)

    private var providerOverrideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI PROVIDER")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                // Default option
                Button(action: {
                    HapticManager.selection()
                    providerOverride = nil
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                            .foregroundStyle(providerOverride == nil ? AppTheme.powerAccent : .secondary)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Default Provider")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Text("Uses the global default from Settings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: providerOverride == nil ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(providerOverride == nil ? AppTheme.powerAccent : Color.secondary.opacity(0.3))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(providerOverride == nil ? AppTheme.powerAccent.opacity(0.1) : Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                // Available providers
                ForEach(availableProviderSelections, id: \.self) { selection in
                    Button(action: {
                        HapticManager.selection()
                        providerOverride = selection
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: selection.icon)
                                .font(.title3)
                                .foregroundStyle(providerOverride == selection ? .white : (selection.isLocal ? .green : AppTheme.powerAccent))
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(providerOverride == selection
                                              ? AppTheme.powerAccent
                                              : (selection.isLocal ? Color.green.opacity(0.15) : AppTheme.powerAccent.opacity(0.15)))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(selection.displayName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)

                                    if selection.isLocal {
                                        Text("ON-DEVICE")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(.green)
                                            .clipShape(Capsule())
                                    }
                                }

                                if let model = selection.model {
                                    Text(model)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: providerOverride == selection ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(providerOverride == selection ? AppTheme.powerAccent : Color.secondary.opacity(0.3))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(providerOverride == selection ? AppTheme.powerAccent.opacity(0.1) : Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Override the default provider for this Power Mode. On-device providers keep your data private.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var availableProviderSelections: [ProviderSelection] {
        var selections: [ProviderSelection] = []

        // Add configured cloud providers with Power Mode capability
        for config in settings.configuredAIProviders {
            if config.usageCategories.contains(.powerMode) {
                selections.append(ProviderSelection(
                    providerType: .cloud(config.provider),
                    model: config.powerModeModel
                ))
            }
        }

        // Add Apple Intelligence if available
        if settings.isAppleIntelligenceReady {
            selections.append(ProviderSelection(providerType: .local(.appleIntelligence)))
        }

        // Add Ollama/LM Studio if configured for Power Mode
        if let localConfig = settings.getAIProviderConfig(for: .local),
           localConfig.usageCategories.contains(.powerMode) {
            let localType: LocalModelType = localConfig.localConfig?.type == .lmStudio ? .lmStudio : .ollama
            selections.append(ProviderSelection(
                providerType: .local(localType),
                model: localConfig.powerModeModel
            ))
        }

        return selections
    }

    // MARK: - AI Autocorrect Section (Phase 13.11)

    private var aiAutocorrectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI GRAMMAR FIX")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "text.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(aiAutocorrectEnabled ? AppTheme.powerAccent : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fix Grammar & Punctuation")
                        .font(.subheadline.weight(.medium))

                    Text("AI will fix grammar and punctuation without changing your words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $aiAutocorrectEnabled)
                    .labelsHidden()
                    .tint(AppTheme.powerAccent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Enter Key Section (Phase 13.11)

    private var enterKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ENTER KEY BEHAVIOR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                // Run Power Mode toggle
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(enterRunsContext ? AppTheme.powerAccent : .secondary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Run Power Mode on Enter")
                            .font(.subheadline.weight(.medium))

                        Text("Automatically apply this power mode when pressing Enter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $enterRunsContext)
                        .labelsHidden()
                        .tint(AppTheme.powerAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                // Auto-send toggle
                HStack(spacing: 12) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(enterSendsMessage ? AppTheme.powerAccent : .secondary)
                        .frame(width: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Send Message")
                            .font(.subheadline.weight(.medium))

                        Text("Submit the message after inserting text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $enterSendsMessage)
                        .labelsHidden()
                        .tint(AppTheme.powerAccent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            Text("Use the AI button for manual processing, or enable Enter key to automate it")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - App Assignment Section

    private var appAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APP AUTO-ENABLE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            AppAssignmentSection(appAssignment: $appAssignment)
                .environmentObject(settings)
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        // Determine if memory was updated
        let memoryWasUpdated = memoryContent != (powerMode?.memory ?? "")
        let newMemoryUpdate: Date? = memoryWasUpdated ? Date() : powerMode?.lastMemoryUpdate

        let savedMode = PowerMode(
            id: powerMode?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            icon: icon,
            iconColor: iconColor,
            iconBackgroundColor: iconBackgroundColor,
            instruction: instruction.trimmingCharacters(in: .whitespaces),
            outputFormat: outputFormat.trimmingCharacters(in: .whitespaces),
            createdAt: powerMode?.createdAt ?? Date(),
            updatedAt: Date(),
            usageCount: powerMode?.usageCount ?? 0,
            memoryEnabled: memoryEnabled,
            memory: memoryContent.isEmpty ? nil : memoryContent,
            memoryLimit: memoryLimit,
            lastMemoryUpdate: newMemoryUpdate,
            knowledgeDocumentIds: knowledgeDocumentIds,
            isArchived: powerMode?.isArchived ?? false,
            appAssignment: appAssignment,
            enabledWebhookIds: enabledWebhookIds,
            providerOverride: providerOverride,
            aiAutocorrectEnabled: aiAutocorrectEnabled,
            enterSendsMessage: enterSendsMessage,
            enterRunsContext: enterRunsContext,
            obsidianVaultIds: obsidianVaultIds,
            includeWindowContext: includeWindowContext,
            maxObsidianChunks: maxObsidianChunks,
            obsidianAction: obsidianAction,
            defaultObsidianSearchQuery: defaultObsidianSearchQuery,
            inputActions: inputActions,
            outputActions: outputActions
        )
        HapticManager.success()
        onSave(savedMode)
        dismiss()
    }
}

// MARK: - Color Picker Row

struct ColorPickerRow: View {
    let label: String
    @Binding var selectedColor: PowerModeColorPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PowerModeColorPreset.allCases) { colorPreset in
                        Button(action: {
                            HapticManager.selection()
                            selectedColor = colorPreset
                        }) {
                            Circle()
                                .fill(colorPreset.gradient)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == colorPreset ? Color.white : Color.clear, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == colorPreset ? colorPreset.color : Color.clear, lineWidth: 4)
                                        .scaleEffect(1.25)
                                )
                                .scaleEffect(selectedColor == colorPreset ? 1.1 : 1.0)
                                .animation(AppTheme.quickSpring, value: selectedColor)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview("New Mode") {
    PowerModeEditorView(powerMode: nil) { _ in }
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Edit Mode") {
    PowerModeEditorView(powerMode: PowerMode.presets.first!) { _ in }
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}

