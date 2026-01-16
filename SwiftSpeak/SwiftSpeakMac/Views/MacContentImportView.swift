//
//  MacContentImportView.swift
//  SwiftSpeakMac
//
//  SwiftUI view for importing and processing shared content on macOS.
//  Displays content preview, extraction options, and Power Mode selection.
//

import SwiftUI
import SwiftSpeakCore

struct MacContentImportView: View {

    @ObservedObject var viewModel: MacContentImportViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            switch viewModel.viewState {
            case .loading:
                loadingView

            case .error(let message):
                errorView(message)

            case .preview:
                ScrollView {
                    VStack(spacing: 20) {
                        // Hide content preview once text is extracted to save space
                        if viewModel.extractedText.isEmpty {
                            contentPreview
                        }
                        extractionSection
                        if !viewModel.extractedText.isEmpty {
                            powerModeSection
                        }
                    }
                    .padding()
                }

            case .processing:
                processingView

            case .result:
                resultView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 500, height: 600)
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.contentType.icon)
                .font(.title2)
                .foregroundStyle(contentTypeColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Process \(viewModel.contentType.displayName)")
                    .font(.headline)
                if let filename = viewModel.originalFilename ?? viewModel.sourceTitle {
                    Text(filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading content...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Failed to Load")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Processing with \(viewModel.selectedPowerMode?.name ?? "Power Mode")...")
                    .font(.headline)

                Text("This may take a moment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Result View

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Success header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("Processing Complete")
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let powerMode = viewModel.selectedPowerMode {
                        Text("Processed with \(powerMode.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 20)

                // Result content
                GroupBox("Result") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let result = viewModel.processedResult {
                            ScrollView {
                                Text(result)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 250)
                            .padding(12)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            HStack {
                                Text("\(result.count) characters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    viewModel.copyResultToClipboard()
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }

                                Button {
                                    Task {
                                        await viewModel.insertResultAtCursor()
                                    }
                                } label: {
                                    Label("Insert", systemImage: "text.cursor")
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Output action results (if any)
                if !viewModel.outputActionResults.isEmpty {
                    GroupBox("Output Actions") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.outputActionResults) { result in
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.success ? .green : .red)
                                    Text(result.label)
                                        .font(.subheadline)
                                    Spacer()
                                    if !result.success, let error = result.error {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Error message (if any)
                if let error = viewModel.processError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        GroupBox("Content Preview") {
            VStack(alignment: .leading, spacing: 12) {
                switch viewModel.contentType {
                case .audio:
                    audioPreview

                case .text:
                    textPreview

                case .image:
                    imagePreview

                case .url:
                    urlPreview

                case .pdf:
                    pdfPreview
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var audioPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title)
                .foregroundStyle(.purple)

            VStack(alignment: .leading) {
                Text(viewModel.originalFilename ?? "Audio File")
                    .font(.headline)
                Text("Ready for transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Content")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.extractedText.prefix(500))
                .font(.body)
                .lineLimit(10)

            if viewModel.extractedText.count > 500 {
                Text("... (\(viewModel.extractedText.count) characters total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var imagePreview: some View {
        VStack(spacing: 12) {
            if let image = viewModel.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 150)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }

            if let filename = viewModel.originalFilename {
                Text(filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var urlPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.title)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text(viewModel.sourceTitle ?? "Web Page")
                    .font(.headline)
                    .lineLimit(2)
                Text("Ready to fetch content")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var pdfPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.title)
                .foregroundStyle(.red)

            VStack(alignment: .leading) {
                Text(viewModel.originalFilename ?? "PDF Document")
                    .font(.headline)
                if let title = viewModel.sourceTitle, title != viewModel.originalFilename {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Extraction Section

    @ViewBuilder
    private var extractionSection: some View {
        GroupBox("Extracted Text") {
            VStack(alignment: .leading, spacing: 8) {
                if viewModel.isExtracting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(viewModel.extractionProgress)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.extractedText.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Extracting text...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Ready")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(viewModel.extractedText.count) characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        Text(viewModel.extractedText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 80)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Power Mode Section

    @ViewBuilder
    private var powerModeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Section header with instructions
                VStack(alignment: .leading, spacing: 4) {
                    Text("Process with AI")
                        .font(.headline)
                    Text("Select a Power Mode and click Process to transform your content")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.availablePowerModes.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("No Power Modes configured for \(viewModel.contentType.displayName.lowercased()) content")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Step 1: Power Mode Picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(viewModel.selectedPowerMode == nil ? Color.accentColor : Color.green)
                                .clipShape(Circle())
                            Text("Choose Power Mode")
                                .font(.subheadline.bold())
                        }

                        Picker("Power Mode", selection: $viewModel.selectedPowerMode) {
                            Text("Select a Power Mode...").tag(nil as PowerMode?)
                            ForEach(viewModel.availablePowerModes) { mode in
                                HStack {
                                    Image(systemName: mode.icon)
                                    Text(mode.name)
                                }
                                .tag(mode as PowerMode?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    // Step 2: Process button (only shown when Power Mode selected)
                    if let mode = viewModel.selectedPowerMode {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("2")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                Text("Process Content")
                                    .font(.subheadline.bold())
                            }

                            Text(mode.instruction)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .padding(.leading, 28)

                            Button {
                                Task {
                                    await viewModel.processThroughPowerMode()
                                }
                            } label: {
                                if viewModel.isProcessing {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Processing...")
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bolt.fill")
                                        Text("Process with \(mode.name)")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(viewModel.isProcessing)
                        }
                    }
                }

                // Show error message if any
                if let error = viewModel.processError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Cancel/Close button
            Button {
                viewModel.cleanup()
                onDismiss()
            } label: {
                if case .result = viewModel.viewState {
                    Text("Close")
                } else {
                    Text("Cancel")
                }
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            // Context-sensitive actions based on state
            switch viewModel.viewState {
            case .preview:
                // Show copy button for extracted text
                if !viewModel.extractedText.isEmpty {
                    Button("Copy Text") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.extractedText, forType: .string)
                    }
                }

                // Show helpful hint when Power Mode selected but not processed
                if viewModel.selectedPowerMode != nil {
                    Text("Click the blue Process button above")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

            case .result:
                Button("Process Again") {
                    viewModel.processedResult = nil
                    viewModel.outputActionResults = []
                    viewModel.viewState = .preview
                }

                Button("Done") {
                    viewModel.cleanup()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)

            case .processing:
                // Show progress indicator in footer during processing
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Processing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            default:
                // Done button for loading/error states
                Button("Done") {
                    viewModel.cleanup()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var contentTypeColor: Color {
        switch viewModel.contentType {
        case .audio: return .purple
        case .text: return .blue
        case .image: return .green
        case .url: return .orange
        case .pdf: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    MacContentImportView(
        viewModel: MacContentImportViewModel(
            contentType: .text,
            fileId: nil,
            sourceURLString: nil,
            settings: MacSettings.shared
        ),
        onDismiss: {}
    )
}
