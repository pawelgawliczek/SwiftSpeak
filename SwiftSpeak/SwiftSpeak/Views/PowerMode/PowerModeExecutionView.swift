//
//  PowerModeExecutionView.swift
//  SwiftSpeak
//
//  Full execution flow with all states: idle, recording, transcribing,
//  thinking, asking question, generating, complete, error
//  Uses PowerModeOrchestrator for real AI execution
//

import SwiftUI
import SwiftSpeakCore

struct PowerModeExecutionView: View {
    let powerMode: PowerMode
    let isFromKeyboard: Bool
    let onDismiss: () -> Void
    let onAcceptAndInsert: ((String) -> Void)?

    // Use the real orchestrator
    @StateObject private var orchestrator: PowerModeOrchestrator

    // Edit mode
    @State private var isEditing = false
    @State private var editedText: String = ""
    @FocusState private var isEditFocused: Bool

    // Refine mode - record additional input to combine with current result
    @State private var isRefining = false

    // Focus state for Obsidian search field
    @FocusState private var isObsidianSearchFocused: Bool

    @EnvironmentObject var settings: SharedSettings

    init(powerMode: PowerMode, isFromKeyboard: Bool = false, onDismiss: @escaping () -> Void, onAcceptAndInsert: ((String) -> Void)? = nil) {
        self.powerMode = powerMode
        self.isFromKeyboard = isFromKeyboard
        self.onDismiss = onDismiss
        self.onAcceptAndInsert = onAcceptAndInsert
        _orchestrator = StateObject(wrappedValue: PowerModeOrchestrator(powerMode: powerMode))
    }

    var body: some View {
        ZStack {
            AppTheme.darkBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header - always show (has Save button when editing)
                header

                Spacer()

                // Main content based on state
                mainContent

                Spacer()

                // Bottom action button (hide when editing)
                if !isEditing {
                    bottomAction
                }
            }
        }
        .onAppear {
            orchestrator.isFromKeyboard = isFromKeyboard
            // Auto-start recording when launched from keyboard
            if isFromKeyboard && orchestrator.isIdle {
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await orchestrator.startRecording()
                }
            }
        }
        .onDisappear {
            orchestrator.cancel()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: {
                HapticManager.lightTap()
                if isEditing {
                    // Cancel editing
                    isEditing = false
                    isEditFocused = false
                } else {
                    orchestrator.cancel()
                    onDismiss()
                }
            }) {
                Image(systemName: isEditing ? "xmark" : "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Context indicator
            if orchestrator.hasActiveContext {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.caption)
                    Text(orchestrator.activeContextName ?? "")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.15))
                .clipShape(Capsule())
            }

            // Save button when editing
            if isEditing {
                Button(action: { saveEditedText() }) {
                    Text("Save")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.powerAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }

            // Options menu (when complete and not editing)
            if orchestrator.isComplete, !isEditing {
                Menu {
                    Button(action: { startEditing() }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: { shareResult() }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if isEditing {
            editView
        } else {
            switch orchestrator.state {
            case .idle:
                idleView
            case .obsidianSearch:
                obsidianSearchView
            case .recording:
                if isRefining {
                    refiningRecordingView
                } else {
                    recordingView
                }
            case .transcribing:
                transcribingView
            case .thinking:
                thinkingView
            case .queryingKnowledge:
                queryingKnowledgeView
            case .askingQuestion(let question):
                PowerModeQuestionView(
                    question: question,
                    onAnswer: { answer in
                        Task {
                            await orchestrator.handleQuestionAnswer(answer)
                        }
                    },
                    onVoiceAnswer: {
                        Task {
                            await orchestrator.startRecording()
                        }
                    }
                )
            case .generating:
                generatingView
            case .streaming(let partialText):
                streamingView(text: partialText)
            case .complete(let session):
                PowerModeResultView(
                    session: session,
                    isFromKeyboard: isFromKeyboard,
                    onCopyAndDone: copyAndDone,
                    onRefine: startRefining,
                    onRegenerate: {
                        Task {
                            await orchestrator.regenerate()
                        }
                    },
                    onAccept: acceptAndInsert,
                    orchestrator: orchestrator,
                    settings: settings
                )
            case .error(let message):
                errorView(message)

            // macOS-specific states - fallback to idle view on iOS
            case .contextPreview, .processing, .aiQuestion, .result, .actionComplete:
                idleView
            }
        }
    }

    // MARK: - Obsidian Search View

    private var obsidianSearchView: some View {
        VStack(spacing: 16) {
            // Header with Obsidian icon
            HStack(spacing: 10) {
                Image("ObsidianIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Search Obsidian Notes")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if !orchestrator.manualObsidianResults.isEmpty {
                    Text("\(orchestrator.selectedObsidianResultIds.count)/\(orchestrator.manualObsidianResults.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            // Search input with voice button
            HStack(spacing: 8) {
                TextField("Search notes...", text: $orchestrator.obsidianSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .focused($isObsidianSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await orchestrator.searchObsidian() }
                    }

                // Voice dictation button
                Button(action: {
                    Task {
                        if orchestrator.isDictatingSearchQuery {
                            await orchestrator.stopSearchDictation()
                        } else {
                            await orchestrator.startSearchDictation()
                        }
                    }
                }) {
                    Image(systemName: orchestrator.isDictatingSearchQuery ? "mic.fill" : "mic")
                        .font(.body)
                        .foregroundStyle(orchestrator.isDictatingSearchQuery ? .red : .primary)
                        .frame(width: 44, height: 44)
                        .background(orchestrator.isDictatingSearchQuery ? Color.red.opacity(0.15) : Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }

                // Search button
                Button(action: { Task { await orchestrator.searchObsidian() } }) {
                    Image(systemName: "magnifyingglass")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(orchestrator.isSearchingObsidian)
            }
            .padding(.horizontal, 16)

            // Results list with checkboxes
            if orchestrator.isSearchingObsidian {
                Spacer()
                ProgressView("Searching...")
                    .foregroundStyle(.secondary)
                Spacer()
            } else if orchestrator.manualObsidianResults.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Enter a search query or leave empty to load all notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(orchestrator.manualObsidianResults.enumerated()), id: \.element.id) { index, result in
                            obsidianSearchResultRow(result, index: index + 1)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Selection controls
            if !orchestrator.manualObsidianResults.isEmpty {
                HStack(spacing: 12) {
                    Button(action: { orchestrator.selectAllResults() }) {
                        Text("Select All")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)

                    Button(action: { orchestrator.deselectAllResults() }) {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.lightTap()
                    orchestrator.reset()
                }) {
                    Text("Cancel")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }

                Button(action: {
                    HapticManager.mediumTap()
                    Task { await orchestrator.proceedFromObsidianSearch() }
                }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                        if !orchestrator.selectedObsidianResultIds.isEmpty {
                            Text("(\(orchestrator.selectedObsidianResultIds.count))")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Image(systemName: "mic.fill")
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.powerGradient)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 16)
        .onAppear {
            isObsidianSearchFocused = true
            // Auto-search or load all if no results yet
            if orchestrator.manualObsidianResults.isEmpty {
                Task {
                    if orchestrator.obsidianSearchQuery.isEmpty {
                        await orchestrator.loadAllObsidianNotes()
                    } else {
                        await orchestrator.searchObsidian()
                    }
                }
            }
        }
    }

    /// Obsidian search result row with checkbox
    private func obsidianSearchResultRow(_ result: ObsidianSearchResult, index: Int) -> some View {
        let isSelected = orchestrator.selectedObsidianResultIds.contains(result.id)

        return Button(action: {
            HapticManager.selection()
            orchestrator.toggleResultSelection(result.id)
        }) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .purple : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image("ObsidianIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text(result.noteTitle)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text("\(result.similarityPercentage)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(result.chunkContent.prefix(80)) + (result.chunkContent.count > 80 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            // Mode icon and name - uses custom colors
            Image(systemName: powerMode.icon)
                .font(.system(size: 48))
                .foregroundStyle(powerMode.iconColor.gradient)
                .frame(width: 80, height: 80)
                .background(powerMode.iconBackgroundColor.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

            Text(powerMode.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            // Show memory and knowledge base status
            HStack(spacing: 12) {
                // Active memory sources
                ForEach(orchestrator.activeMemorySources, id: \.self) { source in
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                        Text(source)
                            .font(.caption)
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(Capsule())
                }

                if !powerMode.knowledgeDocumentIds.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.caption)
                        Text("\(powerMode.knowledgeDocumentIds.count) docs")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            // Token counter
            tokenCounterRow

            Text("Ready to listen")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Token Counter Row

    private var tokenCounterRow: some View {
        let tokens = orchestrator.contextTokens

        return HStack(spacing: 8) {
            Image(systemName: "number.circle.fill")
                .font(.caption)
                .foregroundStyle(tokenLevelColor(tokens.total))

            Text("Context:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(tokens.formattedTotal)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tokenLevelColor(tokens.total))

            // Show breakdown if available
            if !tokens.breakdown.isEmpty {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                ForEach(tokens.breakdown.prefix(2), id: \.name) { item in
                    Text("\(item.name): \(TokenCounter.formatTokenCount(item.tokens))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
    }

    /// Color based on token count level
    private func tokenLevelColor(_ count: Int) -> Color {
        switch TokenCounter.TokenLevel.from(count) {
        case .low:
            return .green
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 24) {
            // Waveform from orchestrator
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.powerGradient)
                        .frame(width: 4, height: CGFloat(orchestrator.audioLevels[index] * 50 + 10))
                        .animation(.spring(dampingFraction: 0.5), value: orchestrator.audioLevels[index])
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 32)

            Text("Listening...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(formatDuration(orchestrator.recordingDuration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)

            // Mode indicator
            HStack(spacing: 6) {
                Image(systemName: powerMode.icon)
                    .font(.footnote)
                Text(powerMode.name)
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Edit View

    private var editView: some View {
        VStack(spacing: 16) {
            // Header
            Text("Edit Result")
                .font(.headline)
                .foregroundStyle(.primary)

            // Text editor
            TextEditor(text: $editedText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($isEditFocused)
                .padding(12)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
        }
        .onAppear {
            isEditFocused = true
        }
    }

    // MARK: - Refining Recording View

    private var refiningRecordingView: some View {
        VStack(spacing: 24) {
            // Current result preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Current result:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(orchestrator.session.currentResult?.markdownOutput.prefix(100) ?? "")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: 280)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            // Waveform
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.powerGradient)
                        .frame(width: 4, height: CGFloat(orchestrator.audioLevels[index] * 50 + 10))
                        .animation(.spring(dampingFraction: 0.5), value: orchestrator.audioLevels[index])
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 32)

            Text("Add refinement...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(formatDuration(orchestrator.recordingDuration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Your voice input will refine the current result")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Transcribing View

    private var transcribingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppTheme.powerAccent)

            Text("Transcribing...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            if !orchestrator.transcribedText.isEmpty {
                Text("\"\(orchestrator.transcribedText)\"")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(3)
            }

            // Mode indicator
            HStack(spacing: 6) {
                Image(systemName: powerMode.icon)
                    .font(.footnote)
                Text(powerMode.name)
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Thinking View

    private var thinkingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)
                .symbolEffect(.pulse, options: .repeating)

            Text("Thinking...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            // User request
            if !orchestrator.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your request:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(orchestrator.transcribedText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .frame(maxWidth: 300)
            }

            // Memory indicator
            if !orchestrator.activeMemorySources.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .font(.caption)
                    Text("Using \(orchestrator.activeMemorySources.joined(separator: ", ")) memory")
                        .font(.caption)
                }
                .foregroundStyle(.purple)
            }
        }
    }

    // MARK: - Querying Knowledge View (Phase 4 RAG)

    private var queryingKnowledgeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)
                .symbolEffect(.pulse, options: .repeating)

            Text("Searching Knowledge Base...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            // User request
            if !orchestrator.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your request:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(orchestrator.transcribedText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: 280)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // RAG activity indicator
            VStack(alignment: .leading, spacing: 12) {
                Text("KNOWLEDGE RETRIEVAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.body)
                        .foregroundStyle(AppTheme.powerAccent)

                    Text("Searching \(powerMode.knowledgeDocumentIds.count) documents")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(16)
            .frame(maxWidth: 280)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppTheme.powerAccent)

            Text("Generating...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text("Preparing your results")
                .font(.body)
                .foregroundStyle(.secondary)

            // Completed steps
            VStack(alignment: .leading, spacing: 8) {
                completedStepRow("Transcribed", isComplete: true)
                if !powerMode.knowledgeDocumentIds.isEmpty {
                    completedStepRow("Knowledge retrieved", isComplete: true)
                }
                if !orchestrator.activeMemorySources.isEmpty {
                    completedStepRow("Context loaded", isComplete: true)
                }
                completedStepRow("Generating response...", isComplete: false, isLoading: true)
            }
            .padding(16)
            .frame(maxWidth: 280)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        }
    }

    private func completedStepRow(_ text: String, isComplete: Bool, isLoading: Bool = false) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isComplete ? .green : .secondary.opacity(0.3))
            }

            Text(text)
                .font(.subheadline)
                .foregroundStyle(isComplete || isLoading ? .primary : .secondary)

            Spacer()
        }
    }

    // MARK: - Streaming View (Progressive Text Rendering)

    @ViewBuilder
    private func streamingView(text: String) -> some View {
        VStack(spacing: 0) {
            // Streaming header with stop button
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.body)
                        .foregroundStyle(AppTheme.powerAccent)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Generating...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button(action: {
                    HapticManager.lightTap()
                    orchestrator.cancelGeneration()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.caption2)
                        Text("Stop")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.05))

            // Progressive text content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)

                        // Anchor for auto-scroll
                        Color.clear
                            .frame(height: 1)
                            .id("streamingBottom")
                    }
                }
                .onChange(of: text) { _, _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("streamingBottom", anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Typing indicator with continuous animation
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(AppTheme.powerAccent)
                            .frame(width: 6, height: 6)
                            .opacity(typingDotOpacity(for: i, phase: phase))
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func typingDotOpacity(for index: Int, phase: Double) -> Double {
        let adjustedPhase = (phase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * sin(adjustedPhase * .pi)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Something went wrong")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                Task {
                    await orchestrator.retry()
                }
            }) {
                Text("Try Again")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(AppTheme.powerGradient)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Bottom Action

    @ViewBuilder
    private var bottomAction: some View {
        switch orchestrator.state {
        case .idle:
            recordButton(title: "Tap to Speak", icon: "mic.fill", isRecording: false)
        case .recording:
            recordButton(title: "Tap to Finish", icon: "stop.fill", isRecording: true)
        case .complete:
            // Actions shown in result view
            EmptyView()
        default:
            // Processing states - no button
            EmptyView()
        }
    }

    private func recordButton(title: String, icon: String, isRecording: Bool) -> some View {
        Button(action: {
            HapticManager.mediumTap()
            Task {
                if isRecording {
                    await orchestrator.stopRecording()
                    if isRefining {
                        isRefining = false
                    }
                } else {
                    await orchestrator.startRecording()
                }
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isRecording ? AnyShapeStyle(Color.red) : AnyShapeStyle(AppTheme.powerGradient))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }

    // MARK: - Actions

    private func copyAndDone() {
        if let result = orchestrator.session.currentResult {
            UIPasteboard.general.string = result.markdownOutput
            HapticManager.success()
            orchestrator.reset()
            onDismiss()
        }
    }

    private func startEditing() {
        if let result = orchestrator.session.currentResult {
            editedText = result.markdownOutput
            isEditing = true
            HapticManager.selection()
        }
    }

    private func saveEditedText() {
        // Update the current result with edited text via orchestrator
        orchestrator.updateCurrentResultText(editedText)
        isEditing = false
        isEditFocused = false
        HapticManager.success()
    }

    private func startRefining() {
        isRefining = true
        Task {
            await orchestrator.startRecording()
        }
        HapticManager.mediumTap()
    }

    private func acceptAndInsert() {
        if let result = orchestrator.session.currentResult {
            // Copy to clipboard for insertion
            UIPasteboard.general.string = result.markdownOutput
            HapticManager.success()
            // Call the callback if provided
            onAcceptAndInsert?(result.markdownOutput)
            orchestrator.reset()
            onDismiss()
        }
    }

    private func shareResult() {
        // Would show share sheet
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Preview

#Preview("Standard Flow") {
    PowerModeExecutionView(
        powerMode: PowerMode.presets.first!,
        isFromKeyboard: false,
        onDismiss: {}
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}

#Preview("Keyboard Flow") {
    PowerModeExecutionView(
        powerMode: PowerMode.presets.first!,
        isFromKeyboard: true,
        onDismiss: {},
        onAcceptAndInsert: { _ in }
    )
    .environmentObject(SharedSettings.shared)
    .preferredColorScheme(.dark)
}
