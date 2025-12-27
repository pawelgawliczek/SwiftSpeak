//
//  PowerModeExecutionView.swift
//  SwiftSpeak
//
//  Full execution flow with all states: idle, recording, transcribing,
//  thinking, asking question, generating, complete, error
//

import SwiftUI

struct PowerModeExecutionView: View {
    let powerMode: PowerMode
    let isFromKeyboard: Bool
    let onDismiss: () -> Void
    let onAcceptAndInsert: ((String) -> Void)?

    @State private var executionState: PowerModeExecutionState = .idle
    @State private var session: PowerModeSession = PowerModeSession()
    @State private var transcribedText: String = ""
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?

    // Edit mode
    @State private var isEditing = false
    @State private var editedText: String = ""
    @FocusState private var isEditFocused: Bool

    // Refine mode - record additional input to combine with current result
    @State private var isRefining = false
    @State private var refinementText: String = ""

    // Mock waveform data
    @State private var waveformHeights: [CGFloat] = Array(repeating: 10, count: 12)

    init(powerMode: PowerMode, isFromKeyboard: Bool = false, onDismiss: @escaping () -> Void, onAcceptAndInsert: ((String) -> Void)? = nil) {
        self.powerMode = powerMode
        self.isFromKeyboard = isFromKeyboard
        self.onDismiss = onDismiss
        self.onAcceptAndInsert = onAcceptAndInsert
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
            // Auto-start recording when launched from keyboard
            if isFromKeyboard && executionState == .idle {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    startRecording()
                }
            }
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
                    cleanup()
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
            if case .complete = executionState, !isEditing {
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
            switch executionState {
            case .idle:
                idleView
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
                        handleQuestionAnswer(answer)
                    },
                    onVoiceAnswer: {
                        // Start voice recording for answer
                        startRecordingAnswer()
                    }
                )
            case .generating:
                generatingView
            case .complete(let session):
                PowerModeResultView(
                    session: session,
                    isFromKeyboard: isFromKeyboard,
                    onCopyAndDone: copyAndDone,
                    onRefine: startRefining,
                    onRegenerate: regenerate,
                    onAccept: acceptAndInsert
                )
            case .error(let message):
                errorView(message)
            }
        }
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

            // Phase 4: Show memory and knowledge base status
            HStack(spacing: 12) {
                if powerMode.memoryEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                        Text("Memory")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
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

            Text("Ready to listen")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 24) {
            // Waveform
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.powerGradient)
                        .frame(width: 4, height: waveformHeights[index])
                        .animation(.spring(dampingFraction: 0.5), value: waveformHeights[index])
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 32)

            Text("Listening...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(formatDuration(recordingDuration))
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
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
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

                Text(session.currentResult?.markdownOutput.prefix(100) ?? "")
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
                        .frame(width: 4, height: waveformHeights[index])
                        .animation(.spring(dampingFraction: 0.5), value: waveformHeights[index])
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 32)

            Text("Add refinement...")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text(formatDuration(recordingDuration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Your voice input will be combined with the current result")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            stopWaveformAnimation()
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

            if !transcribedText.isEmpty {
                Text("\"\(transcribedText)\"")
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
            if !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your request:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(transcribedText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .frame(maxWidth: 300)
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
            if !transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your request:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(transcribedText)
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
                if powerMode.memoryEnabled {
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

            Button(action: { retry() }) {
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
        switch executionState {
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
            if isRecording {
                stopRecording()
            } else {
                startRecording()
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

    // MARK: - Mock Actions

    private func startRecording() {
        executionState = .recording
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil

        if isRefining {
            // Handle refinement flow
            refinementText = "Make it more concise and add bullet points for key takeaways"
            executionState = .transcribing

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                executionState = .thinking

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    executionState = .generating
                    finishWithRefinedResult()
                }
            }
        } else {
            // Normal flow
            executionState = .transcribing
            transcribedText = "Find me the latest news about artificial intelligence and summarize the key points"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                executionState = .thinking

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Phase 4: Check for knowledge base documents (RAG)
                    if !powerMode.knowledgeDocumentIds.isEmpty {
                        executionState = .queryingKnowledge

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Show question (for demo) - skip if from keyboard for faster flow
                            if isFromKeyboard {
                                executionState = .generating
                                finishWithResult()
                            } else {
                                executionState = .askingQuestion(PowerModeQuestion.sample)
                            }
                        }
                    } else {
                        executionState = .generating
                        finishWithResult()
                    }
                }
            }
        }
    }

    private func finishWithRefinedResult() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Create refined version
            let refinedResult = PowerModeResult(
                powerModeId: powerMode.id,
                powerModeName: powerMode.name,
                userInput: "\(transcribedText)\n\nRefinement: \(refinementText)",
                markdownOutput: """
                # AI News Summary - December 2024 (Refined)

                ## Key Takeaways
                - OpenAI improved reasoning models for complex tasks
                - DeepMind achieved 97% accuracy in protein folding
                - Anthropic released new safety guidelines
                - Meta open-sourced Llama 3 with multilingual support

                ## Industry Trends
                - AI safety and alignment focus increasing
                - Enterprise adoption growing rapidly
                - Global regulatory frameworks emerging
                - Open-source AI momentum building

                ## Sources
                - TechCrunch, MIT Technology Review, The Verge, Wired
                """,
                processingDuration: 4.2,
                versionNumber: session.results.count + 1,
                usedRAG: !powerMode.knowledgeDocumentIds.isEmpty,
                ragDocumentIds: powerMode.knowledgeDocumentIds
            )

            session.addResult(refinedResult)
            isRefining = false
            refinementText = ""
            executionState = .complete(session)
            HapticManager.success()
        }
    }

    private func handleQuestionAnswer(_ answer: String) {
        executionState = .generating
        finishWithResult()
    }

    private func startRecordingAnswer() {
        // Would start voice recording for answer
        executionState = .recording
    }

    private func finishWithResult() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            var newSession = PowerModeSession()
            newSession.addResult(PowerModeResult.sample)
            session = newSession
            executionState = .complete(newSession)
            HapticManager.success()
        }
    }

    private func copyAndDone() {
        if let result = session.currentResult {
            UIPasteboard.general.string = result.markdownOutput
            HapticManager.success()
            cleanup()
            onDismiss()
        }
    }

    private func startEditing() {
        if let result = session.currentResult {
            editedText = result.markdownOutput
            isEditing = true
            HapticManager.selection()
        }
    }

    private func saveEditedText() {
        // Update the current result with edited text
        if let currentResult = session.currentResult {
            let updatedResult = PowerModeResult(
                powerModeId: currentResult.powerModeId,
                powerModeName: currentResult.powerModeName,
                userInput: currentResult.userInput,
                markdownOutput: editedText,
                processingDuration: currentResult.processingDuration,
                versionNumber: currentResult.versionNumber,
                usedRAG: currentResult.usedRAG,
                ragDocumentIds: currentResult.ragDocumentIds
            )
            // Replace the current result
            if session.currentVersionIndex < session.results.count {
                session.results[session.currentVersionIndex] = updatedResult
            }
            executionState = .complete(session)
        }
        isEditing = false
        isEditFocused = false
        HapticManager.success()
    }

    private func startRefining() {
        isRefining = true
        executionState = .recording
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
        HapticManager.mediumTap()
    }

    private func acceptAndInsert() {
        if let result = session.currentResult {
            // Copy to clipboard for insertion
            UIPasteboard.general.string = result.markdownOutput
            HapticManager.success()
            // Call the callback if provided
            onAcceptAndInsert?(result.markdownOutput)
            onDismiss()
        }
    }

    private func regenerate() {
        executionState = .generating

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Create new version with slightly different content
            let newResult = PowerModeResult(
                powerModeId: powerMode.id,
                powerModeName: powerMode.name,
                userInput: transcribedText,
                markdownOutput: """
                # AI News Summary - December 2024

                ## Key Developments

                - **OpenAI's Latest Release**: The company announced significant improvements to their reasoning models with enhanced capabilities for complex tasks and multi-step reasoning.

                - **Google DeepMind**: New breakthroughs in protein folding prediction showing 97% accuracy in lab trials.

                - **Anthropic Claude**: Released updated safety guidelines and constitutional AI improvements.

                - **Meta AI**: Open-sourced new Llama 3 models with improved multilingual support.

                ## Industry Trends

                1. Increased focus on AI safety and alignment
                2. Growing adoption in enterprise applications
                3. Regulatory frameworks taking shape globally
                4. Open-source AI gaining momentum

                ## Sources

                - TechCrunch: AI Weekly Roundup
                - MIT Technology Review
                - The Verge: AI Coverage
                - Wired: AI Section
                """,
                processingDuration: 5.8,
                versionNumber: session.results.count + 1,
                usedRAG: !powerMode.knowledgeDocumentIds.isEmpty,
                ragDocumentIds: powerMode.knowledgeDocumentIds
            )

            session.addResult(newResult)
            executionState = .complete(session)
            HapticManager.success()
        }
    }

    private func shareResult() {
        // Would show share sheet
    }

    private func retry() {
        executionState = .idle
        transcribedText = ""
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Waveform Animation

    private func startWaveformAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            guard case .recording = executionState else {
                timer.invalidate()
                return
            }
            withAnimation {
                waveformHeights = (0..<12).map { _ in
                    CGFloat.random(in: 10...50)
                }
            }
        }
    }

    private func stopWaveformAnimation() {
        waveformHeights = Array(repeating: 10, count: 12)
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
    .preferredColorScheme(.dark)
}

#Preview("Keyboard Flow") {
    PowerModeExecutionView(
        powerMode: PowerMode.presets.first!,
        isFromKeyboard: true,
        onDismiss: {},
        onAcceptAndInsert: { _ in }
    )
    .preferredColorScheme(.dark)
}
