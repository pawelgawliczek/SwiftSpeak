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
    let onDismiss: () -> Void

    @State private var executionState: PowerModeExecutionState = .idle
    @State private var session: PowerModeSession = PowerModeSession()
    @State private var transcribedText: String = ""
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?

    // Mock waveform data
    @State private var waveformHeights: [CGFloat] = Array(repeating: 10, count: 12)

    var body: some View {
        ZStack {
            AppTheme.darkBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                Spacer()

                // Main content based on state
                mainContent

                Spacer()

                // Bottom action button
                bottomAction
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: {
                HapticManager.lightTap()
                cleanup()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Options menu (when complete)
            if case .complete = executionState {
                Menu {
                    Button(action: { copyResult() }) {
                        Label("Copy", systemImage: "doc.on.doc")
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
        switch executionState {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .transcribing:
            transcribingView
        case .thinking:
            thinkingView
        case .usingCapability(let capability):
            usingCapabilityView(capability)
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
                onCopy: copyResult,
                onInsert: insertResult,
                onRegenerate: regenerate
            )
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            // Mode icon and name
            Image(systemName: powerMode.icon)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)

            Text(powerMode.name)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            // Enabled capabilities
            if !powerMode.enabledCapabilities.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(powerMode.enabledCapabilities), id: \.self) { capability in
                        HStack(spacing: 4) {
                            Image(systemName: capability.icon)
                                .font(.caption)
                            Text(capability.displayName)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
            }

            Text("Tools enabled")
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

    // MARK: - Using Capability View

    private func usingCapabilityView(_ capability: PowerModeCapability) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.powerGradient)

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
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: 280)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            // Tools activity
            VStack(alignment: .leading, spacing: 12) {
                Text("TOOLS ACTIVITY")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(powerMode.enabledCapabilities), id: \.self) { cap in
                    HStack(spacing: 10) {
                        Image(systemName: cap.icon)
                            .font(.body)
                            .foregroundStyle(cap == capability ? AppTheme.powerAccent : .secondary)

                        Text(cap.displayName)
                            .font(.subheadline)
                            .foregroundStyle(cap == capability ? .primary : .secondary)

                        Spacer()

                        if cap == capability {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.green)
                        }
                    }
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
                ForEach(Array(powerMode.enabledCapabilities), id: \.self) { capability in
                    completedStepRow("\(capability.displayName) complete", isComplete: true)
                }
                completedStepRow("Formatting output...", isComplete: false, isLoading: true)
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

        // Simulate processing flow
        executionState = .transcribing
        transcribedText = "Find me the latest news about artificial intelligence and summarize the key points"

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            executionState = .thinking

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let firstCapability = powerMode.enabledCapabilities.first {
                    executionState = .usingCapability(firstCapability)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        // Show question (for demo)
                        executionState = .askingQuestion(PowerModeQuestion.sample)
                    }
                } else {
                    executionState = .generating
                    finishWithResult()
                }
            }
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

    private func copyResult() {
        if let result = session.currentResult {
            UIPasteboard.general.string = result.markdownOutput
            HapticManager.success()
        }
    }

    private func insertResult() {
        // Would insert to text field via URL scheme
        HapticManager.success()
        onDismiss()
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
                capabilitiesUsed: [.webSearch],
                processingDuration: 5.8,
                versionNumber: session.results.count + 1
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

#Preview("Idle") {
    PowerModeExecutionView(
        powerMode: PowerMode.presets.first!,
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
