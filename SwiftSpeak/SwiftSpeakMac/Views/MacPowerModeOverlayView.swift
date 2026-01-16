//
//  MacPowerModeOverlayView.swift
//  SwiftSpeakMac
//
//  Floating overlay panel for Power Mode execution with 6 states
//  Phase 5: Context preview → Recording → Processing → Question → Result → Complete
//

import SwiftUI
import SwiftSpeakCore

// MARK: - Main Overlay View

struct MacPowerModeOverlayView: View {
    @ObservedObject var viewModel: MacPowerModeOverlayViewModel
    let onClose: () -> Void

    /// Focus state for the Obsidian search text field
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content (changes based on state)
            contentView
                .frame(minHeight: 250, maxHeight: 800)  // Increased to accommodate expanded suggestions
                .animation(.easeInOut(duration: 0.3), value: viewModel.state)

            // Error banner (if any)
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            Divider()

            // Footer (actions)
            footerView
        }
        .frame(width: 580)
        .background(overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        // Note: loadContext() is called from MacPowerModeOverlayController.showOverlay()
        // Keyboard event handling via NSEvent monitor
        .background(
            KeyboardEventMonitor(
                onArrowUp: { viewModel.handleArrowUp() },
                onArrowDown: { viewModel.handleArrowDown() },
                onArrowLeft: { viewModel.handleArrowLeft() },
                onArrowRight: { viewModel.handleArrowRight() },
                onReturn: {
                    if viewModel.selectedSuggestionIndex != nil {
                        Task {
                            let success = await viewModel.insertSelectedSuggestion()
                            if success {
                                onClose()
                            }
                        }
                        return true
                    }
                    return false
                },
                onKeyR: {
                    if viewModel.quickSuggestionsEnabled {
                        Task {
                            await viewModel.regenerateQuickSuggestions()
                        }
                        return true
                    }
                    return false
                },
                isActive: viewModel.state == .contextPreview
            )
        )
    }

    // MARK: - Keyboard Event Monitor (NSEvent-based)

    private struct KeyboardEventMonitor: NSViewRepresentable {
        let onArrowUp: () -> Void
        let onArrowDown: () -> Void
        let onArrowLeft: () -> Void
        let onArrowRight: () -> Void
        let onReturn: () -> Bool  // Returns true if handled
        let onKeyR: () -> Bool    // Returns true if handled
        let isActive: Bool

        func makeNSView(context: Context) -> NSView {
            let view = KeyboardCaptureView()
            view.coordinator = context.coordinator
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            // Update all callbacks and state when view updates
            context.coordinator.onArrowUp = onArrowUp
            context.coordinator.onArrowDown = onArrowDown
            context.coordinator.onArrowLeft = onArrowLeft
            context.coordinator.onArrowRight = onArrowRight
            context.coordinator.onReturn = onReturn
            context.coordinator.onKeyR = onKeyR
            context.coordinator.isActive = isActive
        }

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator {
            var onArrowUp: () -> Void = {}
            var onArrowDown: () -> Void = {}
            var onArrowLeft: () -> Void = {}
            var onArrowRight: () -> Void = {}
            var onReturn: () -> Bool = { false }
            var onKeyR: () -> Bool = { false }
            var isActive: Bool = false
        }

        class KeyboardCaptureView: NSView {
            var coordinator: Coordinator?
            private var eventMonitor: Any?

            override var acceptsFirstResponder: Bool { true }

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                if window != nil {
                    setupEventMonitor()
                } else {
                    removeEventMonitor()
                }
            }

            private func setupEventMonitor() {
                removeEventMonitor()
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self = self, let coordinator = self.coordinator, coordinator.isActive else {
                        return event
                    }

                    switch event.keyCode {
                    case 126: // Up Arrow
                        coordinator.onArrowUp()
                        return nil
                    case 125: // Down Arrow
                        coordinator.onArrowDown()
                        return nil
                    case 123: // Left Arrow
                        coordinator.onArrowLeft()
                        return nil
                    case 124: // Right Arrow
                        coordinator.onArrowRight()
                        return nil
                    case 36: // Return
                        if coordinator.onReturn() {
                            return nil
                        }
                    case 15: // R key
                        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                            if coordinator.onKeyR() {
                                return nil
                            }
                        }
                    default:
                        break
                    }
                    return event
                }
            }

            private func removeEventMonitor() {
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                    eventMonitor = nil
                }
            }

            deinit {
                removeEventMonitor()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Power Mode selector with icon and name
            if viewModel.state == .contextPreview && viewModel.availablePowerModes.count > 1 {
                HStack(spacing: 8) {
                    Button(action: { viewModel.handleArrowLeft() }) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(viewModel.navigationMode == .powerMode ? .primary : .tertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    // Icon + Name
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(viewModel.currentPowerMode.iconColor.color.opacity(0.2))
                                .frame(width: 32, height: 32)
                            Image(systemName: viewModel.currentPowerMode.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(viewModel.currentPowerMode.iconColor.color)
                        }

                        Text(viewModel.currentPowerMode.name)
                            .font(.headline)
                    }

                    Button(action: { viewModel.handleArrowRight() }) {
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(viewModel.navigationMode == .powerMode ? .primary : .tertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.navigationMode == .powerMode ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.navigationMode == .powerMode ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.15), value: viewModel.navigationMode)
            } else {
                // Static icon + name (no cycling)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(viewModel.currentPowerMode.iconColor.color.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: viewModel.currentPowerMode.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(viewModel.currentPowerMode.iconColor.color)
                    }

                    Text(viewModel.currentPowerMode.name)
                        .font(.headline)
                }
            }

            Spacer()

            // SwiftSpeak Context selector (click or press C to cycle)
            if viewModel.state == .contextPreview {
                Button(action: { viewModel.cycleToNextContext() }) {
                    HStack(spacing: 6) {
                        if let ctx = viewModel.activeContext {
                            // Show context icon (emoji or SF Symbol)
                            if ctx.icon.first?.isEmoji == true {
                                Text(ctx.icon)
                                    .font(.caption)
                            } else {
                                Image(systemName: ctx.icon)
                                    .font(.caption)
                            }
                            Text(ctx.name)
                                .font(.caption)
                        } else {
                            Image(systemName: "person.circle")
                                .font(.caption)
                            Text("Context")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(viewModel.activeContext != nil ? .purple : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(viewModel.activeContext != nil ? Color.purple.opacity(0.15) : Color.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Press C to cycle through contexts")
            } else {
                // State indicator for non-contextPreview states
                Text(stateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .contextPreview:
            contextPreviewView
        case .obsidianSearch:
            obsidianSearchView
        case .recording:
            recordingView
        case .processing, .transcribing, .thinking, .queryingKnowledge, .generating, .streaming:
            processingView
        case .aiQuestion, .askingQuestion:
            questionView
        case .result:
            resultView
        case .actionComplete, .complete:
            completeView
        case .idle, .error:
            // These states are not used in macOS overlay, show context preview as fallback
            contextPreviewView
        }
    }

    // MARK: - Context Preview View

    private var contextPreviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // QUICK SUGGESTIONS (shown at top when available)
                if viewModel.quickSuggestionsEnabled {
                    quickSuggestionsSection
                }

                // INPUT SECTION
                inputSection

                Divider()
                    .padding(.horizontal, 16)

                // OUTPUT SECTION
                outputSection

                Divider()
                    .padding(.horizontal, 16)

                // TOKEN COUNTER
                tokenCounterSection
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Quick Suggestions Section

    private var quickSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.cyan)
                    .font(.caption)
                Text("Quick Replies")
                    .font(.caption.weight(.semibold))

                Spacer()

                if !viewModel.quickSuggestions.isEmpty {
                    Text("↑↓ to select, ↩︎ to send")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

            // Prediction input field
            predictionInputField
                .padding(.horizontal, 16)

            if viewModel.isGeneratingSuggestions || viewModel.isRegeneratingSuggestion {
                // Currently generating suggestions
                HStack {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Analyzing conversation...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            } else if let error = viewModel.suggestionsError {
                // Error generating suggestions (e.g., model refused)
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") {
                        Task { await viewModel.regenerateQuickSuggestions() }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            } else if viewModel.quickSuggestions.isEmpty {
                // No suggestions available (no context text captured)
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.tertiary)
                    Text("Select text for suggestions, or press R to generate")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(viewModel.quickSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                        quickSuggestionRow(suggestion: suggestion, index: index)
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
    }

    // MARK: - Prediction Input Field

    /// Text field for steering predictions
    /// - Empty: normal predictions
    /// - Starts with "CMD ": instruction mode (e.g., "CMD summarize and decline")
    /// - Otherwise: use as prefix/start of response
    private var predictionInputField: some View {
        HStack(spacing: 8) {
            // Mode indicator
            if viewModel.isCommandMode {
                Text("CMD")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if !viewModel.predictionInputText.isEmpty {
                Image(systemName: "text.cursor")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }

            // Text field with space handler
            PredictionTextField(
                placeholder: viewModel.isCommandMode ? "Enter instruction..." : "Start typing or CMD to instruct...",
                text: $viewModel.predictionInputText,
                isFocused: $viewModel.isInputFieldFocused,
                onSpacePressed: {
                    viewModel.handlePredictionInputSpace()
                }
            )
            .font(.callout)

            // Clear button
            if !viewModel.predictionInputText.isEmpty {
                Button(action: {
                    viewModel.clearPredictionInput()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.isCommandMode ? Color.orange.opacity(0.1) :
                          viewModel.navigationMode == .inputField ? Color.cyan.opacity(0.1) :
                          Color.primary.opacity(0.05))
                if viewModel.isCommandMode {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                } else if viewModel.navigationMode == .inputField {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1)
                }
            }
        )
    }

    /// Custom text field that triggers callback on space press
    private struct PredictionTextField: View {
        let placeholder: String
        @Binding var text: String
        @Binding var isFocused: Bool
        let onSpacePressed: () -> Void

        @State private var previousText: String = ""
        @FocusState private var fieldFocused: Bool

        var body: some View {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onChange(of: isFocused) { shouldFocus in
                    fieldFocused = shouldFocus
                }
                .onChange(of: fieldFocused) { nowFocused in
                    // Sync back to viewModel when user clicks in/out
                    if isFocused != nowFocused {
                        isFocused = nowFocused
                    }
                }
                .onChange(of: text) { newValue in
                    // Trigger regeneration on space press (if we added a space)
                    if newValue.hasSuffix(" ") && !previousText.hasSuffix(" ") && newValue.count > previousText.count {
                        onSpacePressed()
                    }
                    previousText = newValue
                }
                .onAppear {
                    previousText = text
                }
        }
    }

    private func quickSuggestionRow(suggestion: QuickSuggestion, index: Int) -> some View {
        let isSelected = viewModel.selectedSuggestionIndex == index
        let isRegenerating = isSelected && viewModel.isRegeneratingSuggestion

        return Button(action: {
            viewModel.selectSuggestion(at: index)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    // Type indicator
                    Image(systemName: suggestion.type.icon)
                        .font(.caption)
                        .foregroundStyle(suggestion.type.color)
                        .frame(width: 20)

                    // Suggestion text (or loading indicator)
                    if isRegenerating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Regenerating...")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Show full text when selected, truncated when not
                        Text(suggestion.text)
                            .font(.callout)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .lineLimit(isSelected ? nil : 2)  // Expand when selected
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: isSelected)  // Allow vertical expansion
                    }

                    Spacer(minLength: 8)

                    // Hints when selected (compact, on same line)
                    if isSelected && !isRegenerating {
                        HStack(spacing: 8) {
                            Text("← shorter")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text("longer →")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            Image(systemName: "return")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                        }
                        .layoutPriority(1)  // Prevent hints from being compressed
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.cyan.opacity(0.15) : Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Input")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

            // Show ALL configured sources (with status indicator)
            VStack(spacing: 4) {
                let inputConfig = viewModel.currentPowerMode.inputConfig

                // Selected Text
                if inputConfig.includeSelectedText {
                    let text = viewModel.windowContext?.selectedText
                    compactInputRow(
                        icon: "text.cursor",
                        iconColor: .orange,
                        title: "Selected Text",
                        content: text,
                        emptyMessage: "No text selected"
                    )
                }

                // Clipboard
                if inputConfig.includeClipboard {
                    compactInputRow(
                        icon: "doc.on.clipboard",
                        iconColor: .indigo,
                        title: "Clipboard",
                        content: viewModel.clipboardContent.isEmpty ? nil : viewModel.clipboardContent,
                        emptyMessage: "Empty"
                    )
                }

                // Memory (Global + PowerMode)
                if inputConfig.includeGlobalMemory || inputConfig.includePowerModeMemory {
                    compactInputRow(
                        icon: "brain",
                        iconColor: .purple,
                        title: "Memory",
                        content: viewModel.memoryContext.isEmpty ? nil : viewModel.memoryContext,
                        emptyMessage: "No memory"
                    )
                }

                // Obsidian
                if inputConfig.includeObsidianVaults && !viewModel.currentPowerMode.obsidianVaultIds.isEmpty {
                    compactObsidianRow()
                }

                // No sources configured
                if !hasAnyConfiguredSource {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("No input sources configured")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var hasAnyConfiguredSource: Bool {
        let cfg = viewModel.currentPowerMode.inputConfig
        return cfg.includeSelectedText || cfg.includeActiveAppText || cfg.includeClipboard ||
               cfg.includeGlobalMemory || cfg.includePowerModeMemory ||
               (cfg.includeObsidianVaults && !viewModel.currentPowerMode.obsidianVaultIds.isEmpty)
    }

    private func compactInputRow(icon: String, iconColor: Color, title: String, content: String?, emptyMessage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(content != nil ? iconColor : .secondary)
                .frame(width: 16)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(content != nil ? .primary : .secondary)

            if let content = content, !content.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(content.replacingOccurrences(of: "\n", with: " ").prefix(80) + (content.count > 80 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Spacer()

            Image(systemName: content != nil ? "checkmark.circle.fill" : "circle.dashed")
                .font(.caption2)
                .foregroundStyle(content != nil ? .green : .secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func compactObsidianRow() -> some View {
        let hasDefaultSearch = !viewModel.currentPowerMode.defaultObsidianSearchQuery.isEmpty
        let isLoading = viewModel.isLoadingObsidianContext
        let count = viewModel.obsidianResults.count

        return HStack(spacing: 8) {
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .opacity(isLoading ? 0.5 : (count > 0 ? 1.0 : 0.5))

            Text("Obsidian")
                .font(.caption.weight(.medium))
                .foregroundStyle(isLoading ? .secondary : (count > 0 ? .primary : .secondary))

            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if isLoading {
                // Loading indicator
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text(hasDefaultSearch ? "Searching..." : "Loading...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            } else if hasDefaultSearch {
                // Has search query configured - show match count
                Text("\(count) note\(count == 1 ? "" : "s") found")
                    .font(.caption)
                    .foregroundStyle(count > 0 ? .secondary : .tertiary)
            } else {
                // No search query = all notes included
                Text("\(count) note\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.caption2)
                    .foregroundStyle(count > 0 ? .green : .secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Obsidian Search View

    private var obsidianSearchView: some View {
        VStack(spacing: 16) {
            // Header with selection count
            HStack {
                Image("ObsidianIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Search Obsidian Notes")
                    .font(.headline)
                Spacer()
                if !viewModel.manualObsidianResults.isEmpty {
                    Text("\(viewModel.selectedObsidianResultIds.count)/\(viewModel.manualObsidianResults.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            // Search input with voice button
            HStack(spacing: 8) {
                TextField("Search for...", text: $viewModel.obsidianSearchQuery)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        Task { await viewModel.searchObsidian() }
                    }

                // Voice dictation button
                Button(action: {
                    Task {
                        if viewModel.isDictatingSearchQuery {
                            await viewModel.stopSearchDictation()
                        } else {
                            await viewModel.startSearchDictation()
                        }
                    }
                }) {
                    Image(systemName: viewModel.isDictatingSearchQuery ? "mic.fill" : "mic")
                        .foregroundStyle(viewModel.isDictatingSearchQuery ? .red : .primary)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("d", modifiers: .command)

                // Search button (empty query = load all notes)
                Button(action: { Task { await viewModel.searchObsidian() } }) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSearchingObsidian)
            }
            .padding(.horizontal, 16)

            // Results list with checkboxes
            if viewModel.isSearchingObsidian {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if viewModel.manualObsidianResults.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No notes found. Try a different search or clear to load all.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(viewModel.manualObsidianResults.enumerated()), id: \.element.id) { index, result in
                            obsidianSearchResultRow(result, index: index + 1)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Token counter (updates as user selects/deselects notes)
            obsidianSearchTokenCounter

            // Action buttons
            HStack {
                Button("Back") {
                    viewModel.state = .contextPreview
                }
                .buttonStyle(.bordered)

                Spacer()

                // Select all / deselect all
                if !viewModel.manualObsidianResults.isEmpty {
                    Button("All") { viewModel.selectAllResults() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("a", modifiers: .command)

                    Button("None") { viewModel.deselectAllResults() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("a", modifiers: [.command, .shift])
                }

                Button(action: { Task { await viewModel.proceedFromObsidianSearch() } }) {
                    HStack(spacing: 4) {
                        Text("Continue")
                        if !viewModel.selectedObsidianResultIds.isEmpty {
                            Text("(\(viewModel.selectedObsidianResultIds.count))")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedObsidianResultIds.isEmpty && !viewModel.manualObsidianResults.isEmpty)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .onAppear {
            // Focus the search field when this view appears
            isSearchFieldFocused = true
            // Only load if no results were carried over from contextPreview
            // Results are reused from the first screen to avoid duplicate searches
            if viewModel.manualObsidianResults.isEmpty {
                Task {
                    if viewModel.obsidianSearchQuery.isEmpty {
                        await viewModel.loadAllObsidianNotes()
                    } else {
                        await viewModel.searchObsidian()
                    }
                }
            }
        }
    }

    /// Obsidian search result row with checkbox
    private func obsidianSearchResultRow(_ result: ObsidianSearchResult, index: Int) -> some View {
        let isSelected = viewModel.selectedObsidianResultIds.contains(result.id)

        return Button(action: { viewModel.toggleResultSelection(result.id) }) {
            HStack(spacing: 10) {
                // Index number (for keyboard shortcut reference)
                Text("\(index)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .purple : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image("ObsidianIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text(result.noteTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text("\(result.similarityPercentage)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(String(result.content.prefix(100)) + (result.content.count > 100 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .background(isSelected ? Color.purple.opacity(0.1) : Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Output")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

            VStack(spacing: 4) {
                let outputConfig = viewModel.currentPowerMode.outputConfig

                // Primary action
                compactOutputRow(
                    icon: outputConfig.primaryAction.icon,
                    iconColor: .orange,
                    title: outputConfig.primaryAction.displayName
                )

                // Auto-send
                if outputConfig.autoSendAfterInsert {
                    compactOutputRow(
                        icon: "paperplane.fill",
                        iconColor: .blue,
                        title: "Auto-Send (press Enter)"
                    )
                }

                // Obsidian save
                if let obsidianAction = outputConfig.obsidianAction,
                   obsidianAction.action != .none {
                    compactObsidianOutputRow(action: obsidianAction)
                }

                // Webhooks
                if outputConfig.webhookEnabled && !outputConfig.webhookIds.isEmpty {
                    compactOutputRow(
                        icon: "link",
                        iconColor: .green,
                        title: "\(outputConfig.webhookIds.count) Webhook(s)"
                    )
                }
            }
        }
    }

    private func compactOutputRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func compactObsidianOutputRow(action: ObsidianActionConfig) -> some View {
        HStack(spacing: 8) {
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)

            Text("Obsidian: \(action.action.displayName)")
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Token Counter Section

    private var tokenCounterSection: some View {
        let tokens = viewModel.contextTokens

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "number.circle.fill")
                    .foregroundStyle(tokenLevelColor(tokens.total))
                    .font(.caption)
                Text("Context Size")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(tokens.formattedTotal)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tokenLevelColor(tokens.total))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

            // Breakdown of token sources
            if !tokens.breakdown.isEmpty {
                HStack(spacing: 8) {
                    ForEach(tokens.breakdown.prefix(4), id: \.name) { item in
                        HStack(spacing: 4) {
                            Text(item.name)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(TokenCounter.formatTokenCount(item.tokens))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
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

    /// Token counter for Obsidian search screen (shows selected notes impact)
    private var obsidianSearchTokenCounter: some View {
        let tokens = viewModel.contextTokens

        return HStack(spacing: 12) {
            // Total tokens
            HStack(spacing: 6) {
                Image(systemName: "number.circle.fill")
                    .foregroundStyle(tokenLevelColor(tokens.total))
                    .font(.caption)
                Text("Context:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tokens.formattedTotal)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tokenLevelColor(tokens.total))
            }

            // Obsidian contribution
            if tokens.obsidianNotes > 0 {
                Text("•")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    Image("ObsidianIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                    Text(TokenCounter.formatTokenCount(tokens.obsidianNotes))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.purple)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Recording indicator
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)

                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
            }

            Text("Recording...")
                .font(.title3.weight(.medium))

            // Duration
            Text(formattedDuration(viewModel.recordingDuration))
                .font(.system(.title, design: .monospaced).weight(.semibold))

            // Audio level indicator
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(viewModel.audioLevel > Float(index) / 12.0 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 4, height: CGFloat(20 + index * 2))
                }
            }
            .frame(height: 40)

            Spacer()

            // Stop button
            Button(action: { Task { await viewModel.stopRecording() } }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Stop & Process")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)

            Button("Cancel", action: viewModel.cancelRecording)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Brain icon with animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.4), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(viewModel.state.isProcessing ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: viewModel.state.isProcessing)
            }

            Text("Processing...")
                .font(.title3.weight(.medium))

            Text("Analyzing context and generating response")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI question
            if let question = viewModel.aiQuestion {
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI has a question:", systemImage: "questionmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Text(question)
                        .font(.body)
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
            }

            // Answer input
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Answer:")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Type your answer...", text: $viewModel.questionAnswer, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Submit button
            Button(action: { Task { await viewModel.answerQuestion(viewModel.questionAnswer) } }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Submit Answer")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.questionAnswer.isEmpty)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Result View

    private var resultView: some View {
        VStack(spacing: 16) {
            // AI response
            ScrollView {
                Text(viewModel.aiResponse)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
            }
            .frame(maxHeight: 300)

            // Refine input (optional) - same style as Obsidian search
            VStack(alignment: .leading, spacing: 8) {
                Text("Refine (optional):")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("Add comments or ask for changes...", text: $viewModel.userInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if !viewModel.userInput.isEmpty {
                                Task { await viewModel.refineResult(viewModel.userInput) }
                            }
                        }

                    // Voice dictation button
                    Button(action: {
                        Task {
                            if viewModel.isDictatingSearchQuery {
                                await viewModel.stopSearchDictation()
                            } else {
                                await viewModel.startSearchDictation()
                            }
                        }
                    }) {
                        Image(systemName: viewModel.isDictatingSearchQuery ? "mic.fill" : "mic")
                            .foregroundStyle(viewModel.isDictatingSearchQuery ? .red : .primary)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("d", modifiers: .command)

                    Button(action: { Task { await viewModel.refineResult(viewModel.userInput) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.userInput.isEmpty)
                }
            }
            .padding(.horizontal, 16)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: viewModel.copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: { Task { await viewModel.insertAtCursor() } }) {
                    Label("Insert", systemImage: "arrow.up.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // Obsidian save button
                obsidianSaveButton
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }

            Text("Complete!")
                .font(.title3.weight(.medium))

            Text("Action completed successfully")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 16)
        .onAppear {
            // Auto-close after 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onClose()
            }
        }
    }

    // MARK: - Context Source Card

    /// Read-only context source display (configured in Power Mode editor)
    private func contextSourceDisplay(
        icon: String,
        title: String,
        description: String,
        isEnabled: Bool,
        hasContent: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isEnabled && hasContent ? .orange : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isEnabled {
                Image(systemName: hasContent ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(hasContent ? .orange : .secondary.opacity(0.5))
            } else {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isEnabled && hasContent ? Color.orange.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    /// Obsidian-specific context source display using custom icon
    private func obsidianContextSourceDisplay(
        title: String,
        description: String,
        isEnabled: Bool,
        hasContent: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image("ObsidianIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .opacity(isEnabled && hasContent ? 1.0 : 0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isEnabled {
                Image(systemName: hasContent ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(hasContent ? .purple : .secondary.opacity(0.5))
            } else {
                Image(systemName: "minus.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isEnabled && hasContent ? Color.purple.opacity(0.1) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .opacity(isEnabled ? 1.0 : 0.5)
    }

    /// Legacy interactive context source card (kept for compatibility)
    private func contextSourceCard(
        icon: String,
        title: String,
        description: String,
        isEnabled: Binding<Bool>,
        hasContent: Bool
    ) -> some View {
        Button(action: { isEnabled.wrappedValue.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isEnabled.wrappedValue ? .orange : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isEnabled.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isEnabled.wrappedValue ? .orange : .secondary.opacity(0.3))
            }
            .padding(12)
            .background(isEnabled.wrappedValue ? Color.orange.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled.wrappedValue ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .disabled(!hasContent)
        .opacity(hasContent ? 1.0 : 0.5)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Keyboard hints
            if viewModel.state == .contextPreview {
                HStack(spacing: 12) {
                    if viewModel.quickSuggestionsEnabled && !viewModel.quickSuggestions.isEmpty {
                        keyboardHint(key: "↑↓", action: "Suggestions")
                        keyboardHint(key: "←→", action: viewModel.navigationMode == .powerMode ? "Mode" : "Size")
                        if viewModel.navigationMode == .powerMode {
                            keyboardHint(key: "C", action: "Context")
                        }
                        keyboardHint(key: "↩︎", action: viewModel.selectedSuggestionIndex != nil ? "Send" : "Record")
                    } else {
                        keyboardHint(key: "←→", action: "Switch Mode")
                        keyboardHint(key: "C", action: "Context")
                        keyboardHint(key: "↩︎", action: "Start")
                    }
                    keyboardHint(key: "Esc", action: "Cancel")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if viewModel.state == .obsidianSearch {
                HStack(spacing: 12) {
                    keyboardHint(key: "↩︎", action: "Search")
                    keyboardHint(key: "⇧↩︎", action: "Continue")
                    keyboardHint(key: "1-9", action: "Toggle")
                    keyboardHint(key: "Esc", action: "Back")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if viewModel.state == .recording {
                HStack(spacing: 12) {
                    keyboardHint(key: "⇧↩︎", action: "Stop & Process")
                    keyboardHint(key: "Space", action: "Stop")
                    keyboardHint(key: "Esc", action: "Cancel")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if viewModel.state == .result {
                HStack(spacing: 12) {
                    keyboardHint(key: "↩︎", action: "Refine")
                    keyboardHint(key: "⌘D", action: "Dictate")
                    keyboardHint(key: "Esc", action: "Close")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // State-specific actions
            if viewModel.state == .contextPreview {
                Button("Close", action: onClose)
                    .keyboardShortcut(.escape)
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private func keyboardHint(key: String, action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(action)
        }
    }

    private var stateDescription: String {
        // Use the shared statusText from the enum
        viewModel.state.statusText
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Obsidian Save Button

    @ViewBuilder
    private var obsidianSaveButton: some View {
        if let actionConfig = viewModel.currentPowerMode.obsidianAction,
           actionConfig.action != .none,
           let vault = viewModel.settings.obsidianVaults.first(where: { $0.id == actionConfig.targetVaultId }) {
            // Configured action - show destination
            Menu {
                // Show configured action
                Button(action: { Task { await viewModel.saveToObsidian() } }) {
                    Label(saveButtonLabel(action: actionConfig.action, vault: vault),
                          systemImage: actionConfig.action.icon)
                }

                Divider()

                // Quick actions to other vaults
                ForEach(viewModel.settings.obsidianVaults.filter { $0.id != vault.id }) { otherVault in
                    Menu(otherVault.name) {
                        Button("Append to Daily Note") {
                            Task { await viewModel.saveToObsidian(vault: otherVault, action: .appendToDaily) }
                        }
                        Button("Create New Note") {
                            Task { await viewModel.saveToObsidian(vault: otherVault, action: .create) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image("ObsidianIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(shortSaveLabel(action: actionConfig.action))
                }
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)
        } else if !viewModel.settings.obsidianVaults.isEmpty {
            // No configured action but vaults exist - show menu
            Menu {
                ForEach(viewModel.settings.obsidianVaults) { vault in
                    Menu(vault.name) {
                        Button("Append to Daily Note") {
                            Task { await viewModel.saveToObsidian(vault: vault, action: .appendToDaily) }
                        }
                        Button("Create New Note") {
                            Task { await viewModel.saveToObsidian(vault: vault, action: .create) }
                        }
                    }
                }
            } label: {
                Label("Save", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.bordered)
        } else {
            // No vaults - disabled button
            Button(action: {}) {
                Label("Save", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(true)
            .help("Add an Obsidian vault in Settings to enable saving")
        }
    }

    private func saveButtonLabel(action: ObsidianAction, vault: ObsidianVault) -> String {
        switch action {
        case .appendToDaily:
            return "Add to Daily Note (\(vault.name))"
        case .appendToNote:
            return "Append to Note (\(vault.name))"
        case .createNote:
            return "Create Note (\(vault.name))"
        case .none:
            return "Save"
        }
    }

    private func shortSaveLabel(action: ObsidianAction) -> String {
        switch action {
        case .appendToDaily:
            return "Daily"
        case .appendToNote:
            return "Append"
        case .createNote:
            return "New"
        case .none:
            return "Save"
        }
    }

    private var overlayBackground: some View {
        Color(NSColor.windowBackgroundColor)
    }
}

// MARK: - Preview

#Preview("Context Preview") {
    let settings = MacSettings.shared
    let viewModel = MacPowerModeOverlayViewModel(
        powerMode: PowerMode.presets[0],
        allPowerModes: PowerMode.presets,
        settings: settings,
        windowContextService: MacWindowContextService(),
        audioRecorder: MacAudioRecorder()
    )

    return MacPowerModeOverlayView(
        viewModel: viewModel,
        onClose: {}
    )
}

#Preview("Recording") {
    let settings = MacSettings.shared
    let viewModel = MacPowerModeOverlayViewModel(
        powerMode: PowerMode.presets[0],
        allPowerModes: PowerMode.presets,
        settings: settings,
        windowContextService: MacWindowContextService(),
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .recording

    return MacPowerModeOverlayView(
        viewModel: viewModel,
        onClose: {}
    )
}

#Preview("Result") {
    let settings = MacSettings.shared
    let viewModel = MacPowerModeOverlayViewModel(
        powerMode: PowerMode.presets[0],
        allPowerModes: PowerMode.presets,
        settings: settings,
        windowContextService: MacWindowContextService(),
        audioRecorder: MacAudioRecorder()
    )
    viewModel.state = .result
    viewModel.aiResponse = "Here's the meeting summary:\n\n1. Discussed Q4 goals\n2. Reviewed budget\n3. Next meeting: Friday"

    return MacPowerModeOverlayView(
        viewModel: viewModel,
        onClose: {}
    )
}
