//
//  ShareImportView.swift
//  SwiftSpeak
//
//  UI for importing shared content and processing through Power Mode
//  Supports: Audio, Text, Images (OCR), URLs (web fetch), PDFs
//  Called from Share Extension via URL scheme
//

import SwiftUI
import SwiftSpeakCore

struct ShareImportView: View {
    @StateObject private var viewModel: ShareImportViewModel
    @EnvironmentObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss

    init(shareId: String, contentType: SharedContentType? = nil) {
        _viewModel = StateObject(wrappedValue: ShareImportViewModel(shareId: shareId, contentType: contentType))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            viewModel.cleanup()
                            dismiss()
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    private var navigationTitle: String {
        switch viewModel.contentType {
        case .audio: return "Import Audio"
        case .text: return "Import Text"
        case .image: return "Import Image"
        case .url: return "Import URL"
        case .pdf: return "Import PDF"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingView

        case .ready:
            powerModeSelectionView

        case .extracting:
            extractingView

        case .transcribing:
            transcribingView

        case .selectOutput:
            outputSelectionView

        case .processing:
            processingView

        case .complete:
            completeView

        case .error(let message):
            errorView(message: message)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading content...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    // MARK: - Power Mode Selection View

    private var powerModeSelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Content info card
                contentInfoCard

                // Context selection (optional)
                contextSection

                // Power Mode selection
                powerModeSection

                // Diarization toggle (when AssemblyAI is selected for audio)
                if viewModel.supportsDiarization {
                    diarizationSection
                }

                // Extract/Transcribe button
                if viewModel.selectedPowerMode != nil {
                    extractButton
                }
            }
            .padding()
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    private var contentInfoCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.contentType.icon)
                    .font(.title2)
                    .foregroundStyle(contentTypeColor)
                    .frame(width: 44, height: 44)
                    .background(contentTypeColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.contentFileName)
                        .font(.headline)
                        .lineLimit(1)

                    // Content-type specific info
                    if viewModel.contentType == .audio && viewModel.audioDuration > 0 {
                        Text("Duration: \(viewModel.formattedDuration)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let preview = viewModel.contentPreview {
                        Text(preview)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(AppTheme.darkElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private var contentTypeColor: Color {
        switch viewModel.contentType {
        case .audio: return .red
        case .text: return .blue
        case .image: return .purple
        case .url: return .green
        case .pdf: return .orange
        }
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Context")
                    .font(.headline)

                Spacer()

                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if viewModel.availableContexts.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                    Text("No contexts configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.darkElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            } else {
                Menu {
                    Button(action: {
                        viewModel.selectedContextId = nil
                    }) {
                        Label("None", systemImage: "minus.circle")
                    }

                    Divider()

                    ForEach(viewModel.availableContexts) { context in
                        Button(action: {
                            viewModel.selectedContextId = context.id
                        }) {
                            Label {
                                Text(context.name)
                            } icon: {
                                Text(context.icon)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let context = viewModel.selectedContext {
                            Text(context.icon)
                                .font(.title3)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(context.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                if let language = context.defaultInputLanguage {
                                    Text("Language: \(language.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        } else {
                            Image(systemName: "text.bubble")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36)

                            Text("No context selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(AppTheme.darkElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .buttonStyle(.plain)
            }

            if let context = viewModel.selectedContext {
                // Show context info
                VStack(alignment: .leading, spacing: 4) {
                    if context.domainJargon != .none {
                        HStack(spacing: 6) {
                            Image(systemName: context.domainJargon.icon)
                                .font(.caption)
                            Text(context.domainJargon.displayName)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    if !context.customJargon.isEmpty {
                        Text("\(context.customJargon.count) custom vocabulary terms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Diarization Section

    private var diarizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $viewModel.enableDiarization) {
                HStack(spacing: 12) {
                    Image(systemName: "person.2.wave.2")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speaker Diarization")
                            .font(.subheadline.weight(.medium))

                        Text("Identify different speakers in the audio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .padding()
            .background(AppTheme.darkElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

            if viewModel.enableDiarization {
                HStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 36)

                    Text("Expected speakers")
                        .font(.subheadline)

                    Spacer()

                    Picker("Speakers", selection: Binding(
                        get: { viewModel.expectedSpeakerCount ?? 0 },
                        set: { viewModel.expectedSpeakerCount = $0 == 0 ? nil : $0 }
                    )) {
                        Text("Auto").tag(0)
                        ForEach(2...10, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding()
                .background(AppTheme.darkElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
    }

    private var powerModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Power Mode")
                    .font(.headline)

                Spacer()

                // Show info if filtering by content type
                if !viewModel.availablePowerModes.isEmpty &&
                   viewModel.availablePowerModes.count < settings.activePowerModes.count {
                    Text("Showing \(viewModel.availablePowerModes.count) with \(viewModel.contentType.displayName) import")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if viewModel.availablePowerModes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Power Modes configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.availablePowerModes) { mode in
                        PowerModeSelectionRow(
                            powerMode: mode,
                            isSelected: viewModel.selectedPowerMode?.id == mode.id,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedPowerMode = mode
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var extractButton: some View {
        Button(action: {
            Task {
                await viewModel.startExtraction()
            }
        }) {
            HStack {
                Image(systemName: viewModel.extractButtonIcon)
                Text(viewModel.extractButtonText)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(contentTypeColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }

    // MARK: - Extracting View (for Image, URL, PDF)

    private var extractingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(contentTypeColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(contentTypeColor.opacity(0.2))
                    .frame(width: 90, height: 90)

                Image(systemName: viewModel.extractButtonIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(contentTypeColor)
                    .symbolEffect(.pulse, options: .repeating)
            }

            // Status
            VStack(spacing: 8) {
                Text(viewModel.extractionStatus)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                if let modeName = viewModel.selectedPowerMode?.name {
                    Text("Power Mode: \(modeName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress indicator
            ProgressView()
                .scaleEffect(1.2)

            // Content info
            VStack(spacing: 4) {
                Text(viewModel.contentFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(viewModel.contentType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.darkElevated.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    // MARK: - Transcribing View (for Audio)

    private var transcribingView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated waveform icon
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 90, height: 90)

                Image(systemName: viewModel.transcriptionPhase.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            }

            // Phase status
            VStack(spacing: 8) {
                Text(viewModel.transcriptionPhase.displayText)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)

                if let modeName = viewModel.selectedPowerMode?.name {
                    Text("Power Mode: \(modeName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress indicator
            VStack(spacing: 12) {
                if let progress = viewModel.transcriptionPhase.progress {
                    // Determinate progress
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(AppTheme.accent)
                        .frame(width: 200)

                    if viewModel.totalChunks > 1 {
                        Text("Chunk \(viewModel.currentChunk) of \(viewModel.totalChunks)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    // Indeterminate progress
                    ProgressView()
                        .scaleEffect(1.2)
                }

                // Elapsed time
                if let startTime = viewModel.transcriptionStartTime {
                    TimelineView(.periodic(from: Date(), by: 1)) { context in
                        let elapsed = context.date.timeIntervalSince(startTime)
                        Text(formatElapsedTime(elapsed))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }

            // Audio file info
            VStack(spacing: 4) {
                Text(viewModel.contentFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Duration: \(viewModel.formattedDuration)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(AppTheme.darkElevated.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "Elapsed: %d:%02d", minutes, seconds)
    }

    // MARK: - Output Selection View

    private var outputSelectionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Extracted content preview
                extractedContentPreview

                // Output actions selection
                outputActionsSection

                // Process button
                processButton
            }
            .padding()
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    private var extractedContentPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(viewModel.contentType == .audio ? "Transcription" : "Extracted Text")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.extractedText.split(separator: " ").count) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(viewModel.extractedText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.darkElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }

    private var outputActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Actions")
                .font(.headline)

            if viewModel.availableOutputActions.isEmpty {
                Text("No output actions configured for this Power Mode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.availableOutputActions) { action in
                        OutputActionRow(
                            action: action,
                            isSelected: viewModel.selectedOutputActions.contains(action.id),
                            onToggle: {
                                viewModel.toggleOutputAction(action.id)
                            }
                        )
                    }
                }
            }
        }
    }

    private var processButton: some View {
        Button(action: {
            Task {
                await viewModel.processWithPowerMode()
            }
        }) {
            HStack {
                Image(systemName: "bolt.fill")
                Text("Process with Power Mode")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.powerGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(2)

            Text("Processing...")
                .font(.title3)
                .foregroundStyle(.secondary)

            if let modeName = viewModel.selectedPowerMode?.name {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.selectedPowerMode?.icon ?? "bolt.fill")
                    Text(modeName)
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.powerAccent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    // MARK: - Complete View

    private var completeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Success indicator
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)

                    Text("Complete!")
                        .font(.title2.weight(.semibold))
                }
                .padding(.top, 32)

                // Result preview
                if let result = viewModel.result {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Result")
                            .font(.headline)

                        Text(result.markdownOutput)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(AppTheme.darkElevated)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    }
                }

                // Copy and Done buttons
                HStack(spacing: 12) {
                    Button(action: {
                        if let result = viewModel.result {
                            UIPasteboard.general.string = result.markdownOutput
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.headline)
                        .foregroundStyle(AppTheme.powerAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.powerAccent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    }

                    Button(action: {
                        viewModel.cleanup()
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.powerGradient)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.darkBase.ignoresSafeArea())
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Error")
                .font(.title2.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                viewModel.cleanup()
                dismiss()
            }) {
                Text("Dismiss")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 50)
                    .background(AppTheme.darkElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.darkBase.ignoresSafeArea())
    }
}

// MARK: - Power Mode Selection Row

private struct PowerModeSelectionRow: View {
    let powerMode: PowerMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: powerMode.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.powerAccent : .secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(powerMode.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)

                    if !powerMode.instruction.isEmpty {
                        Text(powerMode.instruction.prefix(60) + (powerMode.instruction.count > 60 ? "..." : ""))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.powerAccent)
                }
            }
            .padding()
            .background(isSelected ? AppTheme.powerAccent.opacity(0.1) : AppTheme.darkElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .strokeBorder(isSelected ? AppTheme.powerAccent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Output Action Row

private struct OutputActionRow: View {
    let action: OutputAction
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? AppTheme.powerAccent : .secondary)

                Image(systemName: action.type.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.label)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text(action.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding()
            .background(AppTheme.darkElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ShareImportView(shareId: "test-id", contentType: .text)
        .environmentObject(SharedSettings.shared)
}
