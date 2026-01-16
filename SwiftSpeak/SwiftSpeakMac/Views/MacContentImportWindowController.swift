//
//  MacContentImportWindowController.swift
//  SwiftSpeakMac
//
//  Window controller for handling shared content imports on macOS.
//  Opens when content is received via Share Extension or drag-and-drop.
//

import AppKit
import SwiftUI
import Combine
import SwiftSpeakCore

// MARK: - Window Controller

@MainActor
final class MacContentImportWindowController {

    private var window: NSWindow?
    private var viewModel: MacContentImportViewModel?

    func showWindow(contentType: SharedContentType, fileId: String?, sourceURL: String?, settings: MacSettings, providerFactory: ProviderFactory?) {
        print("[ImportWindow] showWindow called - type: \(contentType.rawValue), fileId: \(fileId ?? "nil")")

        // Create view model
        let vm = MacContentImportViewModel(
            contentType: contentType,
            fileId: fileId,
            sourceURLString: sourceURL,
            settings: settings
        )
        vm.providerFactory = providerFactory
        self.viewModel = vm

        // Create SwiftUI view
        let contentView = MacContentImportView(viewModel: vm, onDismiss: { [weak self] in
            self?.closeWindow()
        })

        // Create or reuse window
        if window == nil {
            print("[ImportWindow] Creating new window")
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            newWindow.title = "Process Content"
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.level = .floating
            self.window = newWindow
        }

        print("[ImportWindow] Setting content view and showing window")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("[ImportWindow] Window should now be visible")

        // Start loading content
        Task {
            await vm.loadContent()
        }
    }

    func closeWindow() {
        window?.close()
        viewModel = nil
    }
}

// MARK: - Import View State

enum ImportViewState {
    case loading
    case preview
    case processing
    case result
    case error(String)
}

// MARK: - View Model

final class MacContentImportViewModel: ObservableObject {

    // MARK: - Properties

    let contentType: SharedContentType
    let fileId: String?
    let sourceURLString: String?
    let settings: MacSettings

    @Published var viewState: ImportViewState = .loading
    @Published var loadError: String?
    @Published var extractedText: String = ""
    @Published var originalFilename: String?
    @Published var previewImage: NSImage?
    @Published var sourceTitle: String?

    @Published var isExtracting = false
    @Published var extractionProgress: String = ""

    @Published var selectedPowerMode: PowerMode?
    @Published var isProcessing = false
    @Published var processedResult: String?
    @Published var processError: String?

    /// Output action results after processing
    @Published var outputActionResults: [OutputActionResult] = []

    /// Provider factory for LLM access
    var providerFactory: ProviderFactory?

    private let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    // Convenience computed for backwards compatibility
    var isLoading: Bool {
        if case .loading = viewState { return true }
        return false
    }

    // MARK: - Computed

    var availablePowerModes: [PowerMode] {
        settings.activePowerModes.filter { $0.acceptsContentType(contentType) }
    }

    var extractButtonText: String {
        switch contentType {
        case .audio: return "Transcribe"
        case .text: return "Use Text"
        case .image: return "Extract Text (OCR)"
        case .url: return "Fetch Content"
        case .pdf: return "Extract Text"
        }
    }

    var extractButtonIcon: String {
        switch contentType {
        case .audio: return "waveform"
        case .text: return "doc.text"
        case .image: return "eye"
        case .url: return "globe"
        case .pdf: return "doc.richtext"
        }
    }

    // MARK: - Init

    init(contentType: SharedContentType, fileId: String?, sourceURLString: String?, settings: MacSettings) {
        self.contentType = contentType
        self.fileId = fileId
        self.sourceURLString = sourceURLString
        self.settings = settings
    }

    // MARK: - Loading

    @MainActor
    func loadContent() async {
        viewState = .loading
        loadError = nil

        do {
            switch contentType {
            case .audio:
                try await loadAudioContent()
            case .text:
                try await loadTextContent()
            case .image:
                try await loadImageContent()
            case .url:
                try await loadURLContent()
            case .pdf:
                try await loadPDFContent()
            }
            viewState = .preview
        } catch {
            loadError = error.localizedDescription
            viewState = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func loadAudioContent() async throws {
        guard let fileId = fileId else {
            throw ContentLoadError.missingFileId
        }

        let url = try fileURL(for: fileId)
        originalFilename = url.lastPathComponent
        // Audio will be handled by transcription service
    }

    private func debugLog(_ message: String) {
        let logFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("swiftspeak_import_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }

    @MainActor
    private func loadTextContent() async throws {
        debugLog("loadTextContent called, fileId: \(fileId ?? "nil")")
        print("[ImportVM] loadTextContent called, fileId: \(fileId ?? "nil")")

        // Check UserDefaults first for small text and filename
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            // Force sync to ensure we have latest data
            userDefaults.synchronize()

            // Debug: print all keys
            let allKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.contains("share") || $0.contains("pending") }
            debugLog("Share-related UserDefaults keys: \(Array(allKeys))")
            print("[ImportVM] Share-related UserDefaults keys: \(allKeys)")

            // Get original filename if stored
            if let filename = userDefaults.string(forKey: "shareOriginalFilename") {
                print("[ImportVM] Found filename in UserDefaults: \(filename)")
                originalFilename = filename
            }

            // Get text content
            if let text = userDefaults.string(forKey: "shareTextContent"), !text.isEmpty {
                print("[ImportVM] Found text in UserDefaults, length: \(text.count)")
                extractedText = text
                return
            } else {
                print("[ImportVM] No shareTextContent found in UserDefaults")
            }
        } else {
            print("[ImportVM] Could not create UserDefaults with suite: \(appGroupIdentifier)")
        }

        // Otherwise load from file
        guard let fileId = fileId else {
            print("[ImportVM] No fileId provided, throwing missingFileId")
            throw ContentLoadError.missingFileId
        }

        print("[ImportVM] Attempting to load from file with fileId: \(fileId)")
        let url = try fileURL(for: fileId)
        extractedText = try String(contentsOf: url, encoding: .utf8)
        if originalFilename == nil {
            originalFilename = url.lastPathComponent
        }
    }

    @MainActor
    private func loadImageContent() async throws {
        guard let fileId = fileId else {
            throw ContentLoadError.missingFileId
        }

        let url = try fileURL(for: fileId)
        originalFilename = url.lastPathComponent

        // Load preview image
        if let image = NSImage(contentsOf: url) {
            previewImage = image
        }
    }

    @MainActor
    private func loadURLContent() async throws {
        // URL stored in UserDefaults
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let urlString = userDefaults.string(forKey: "shareSourceURL") {
            sourceTitle = urlString
        } else if let urlString = sourceURLString {
            sourceTitle = urlString
        } else {
            throw ContentLoadError.missingURL
        }
    }

    @MainActor
    private func loadPDFContent() async throws {
        guard let fileId = fileId else {
            throw ContentLoadError.missingFileId
        }

        let url = try fileURL(for: fileId)
        originalFilename = url.lastPathComponent

        // Get PDF metadata
        let extractor = PDFTextExtractor()
        if let metadata = extractor.metadata(from: url) {
            sourceTitle = metadata.title ?? originalFilename
        }
    }

    private func fileURL(for fileId: String) throws -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw ContentLoadError.appGroupUnavailable
        }

        let sharedDir = containerURL.appendingPathComponent("shared_content")

        // Find file with matching ID (extension may vary)
        let contents = try FileManager.default.contentsOfDirectory(at: sharedDir, includingPropertiesForKeys: nil)
        if let file = contents.first(where: { $0.deletingPathExtension().lastPathComponent == fileId }) {
            return file
        }

        throw ContentLoadError.fileNotFound
    }

    // MARK: - Extraction

    @MainActor
    func startExtraction() async {
        isExtracting = true
        extractionProgress = "Starting..."

        do {
            switch contentType {
            case .audio:
                extractionProgress = "Audio transcription not yet implemented"
                // TODO: Integrate with MacOrchestrationManager for transcription

            case .text:
                // Text is already loaded
                extractionProgress = "Text ready"

            case .image:
                try await extractFromImage()

            case .url:
                try await extractFromURL()

            case .pdf:
                try await extractFromPDF()
            }
        } catch {
            loadError = error.localizedDescription
        }

        isExtracting = false
    }

    @MainActor
    private func extractFromImage() async throws {
        guard let fileId = fileId else {
            throw ContentLoadError.missingFileId
        }

        extractionProgress = "Running OCR..."
        let url = try fileURL(for: fileId)
        let ocrService = ImageOCRService()
        extractedText = try await ocrService.extractText(from: url)
    }

    @MainActor
    private func extractFromURL() async throws {
        guard let urlString = sourceTitle ?? sourceURLString,
              let url = URL(string: urlString) else {
            throw ContentLoadError.missingURL
        }

        extractionProgress = "Fetching content..."
        let fetcher = URLContentFetcher()
        let result = try await fetcher.fetchContent(from: url)
        extractedText = result.text
        if let title = result.title {
            sourceTitle = title
        }
    }

    @MainActor
    private func extractFromPDF() async throws {
        guard let fileId = fileId else {
            throw ContentLoadError.missingFileId
        }

        extractionProgress = "Extracting text..."
        let url = try fileURL(for: fileId)
        let extractor = PDFTextExtractor()
        extractedText = try extractor.extractText(from: url)
    }

    // MARK: - Power Mode Processing

    @MainActor
    func processThroughPowerMode() async {
        guard let powerMode = selectedPowerMode else {
            print("[ImportVM] processThroughPowerMode: No power mode selected")
            return
        }
        guard !extractedText.isEmpty else {
            print("[ImportVM] processThroughPowerMode: No text to process")
            processError = "No text to process"
            return
        }

        print("[ImportVM] Starting processing with Power Mode: \(powerMode.name)")
        isProcessing = true
        viewState = .processing
        processError = nil
        outputActionResults = []

        do {
            print("[ImportVM] Building prompt input...")
            // Build prompt input for the Power Mode
            let promptInput = PowerModePromptInput(
                powerMode: powerMode,
                userInput: extractedText,
                globalMemory: powerMode.inputConfig.includeGlobalMemory ? settings.globalMemory : nil,
                contextMemory: nil,
                powerModeMemory: powerMode.inputConfig.includePowerModeMemory ? powerMode.memory : nil,
                ragChunks: [],
                obsidianChunks: []  // Could add Obsidian search in the future
            )

            // Build system and user prompts
            print("[ImportVM] Building prompts...")
            let (systemPrompt, userMessage) = PowerModePromptBuilder.buildPrompt(for: promptInput)

            // Get LLM provider
            print("[ImportVM] Getting LLM provider for: \(settings.selectedPowerModeProvider.displayName)")
            guard let provider = providerFactory else {
                print("[ImportVM] ERROR: No provider factory")
                throw NSError(domain: "PowerMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "Provider factory not available"])
            }

            guard let llmService = provider.createFormattingProvider(for: settings.selectedPowerModeProvider) else {
                print("[ImportVM] ERROR: Could not create LLM service for \(settings.selectedPowerModeProvider.displayName)")
                throw NSError(domain: "PowerMode", code: 2, userInfo: [NSLocalizedDescriptionKey: "LLM provider not configured. Please set up an LLM provider in Settings."])
            }

            // Call LLM with streaming disabled for now
            print("[ImportVM] Calling LLM service...")
            processedResult = try await llmService.format(
                text: userMessage,
                mode: .raw,
                customPrompt: systemPrompt,
                context: nil
            )
            print("[ImportVM] LLM returned result: \(processedResult?.prefix(100) ?? "nil")...")

            // Execute output actions
            await executeOutputActions(powerMode: powerMode)

            print("[ImportVM] Setting viewState to .result")
            viewState = .result

        } catch {
            print("[ImportVM] ERROR: \(error.localizedDescription)")
            processError = error.localizedDescription
            viewState = .preview  // Go back to preview on error
        }

        isProcessing = false
    }

    /// Execute output actions after LLM processing
    private func executeOutputActions(powerMode: PowerMode) async {
        guard !powerMode.outputActions.isEmpty,
              let result = processedResult else { return }

        let enabledActions = powerMode.outputActions.filter { $0.isEnabled }
        guard !enabledActions.isEmpty else { return }

        // Create output action executor
        let executor = MacOutputActionExecutor(settings: settings)

        do {
            outputActionResults = try await executor.execute(
                actions: enabledActions,
                output: result,
                powerMode: powerMode
            )
        } catch {
            // Don't fail the whole operation - user still has the result
            processError = "Some output actions failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Result Actions

    /// Copy result to clipboard
    func copyResultToClipboard() {
        guard let result = processedResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

    /// Insert result at cursor position
    func insertResultAtCursor() async {
        guard let result = processedResult else { return }
        let textInsertion = MacTextInsertionService()
        _ = await textInsertion.insertText(result, replaceSelection: false)
    }

    // MARK: - Cleanup

    func cleanup() {
        // Only clear share data if it matches our fileId (avoid clearing newer share data)
        if let userDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let pendingId = userDefaults.string(forKey: "pendingShareContentId")
            if pendingId == nil || pendingId == fileId {
                // Safe to clear - either no pending share or it's our share
                userDefaults.removeObject(forKey: "pendingShareContentId")
                userDefaults.removeObject(forKey: "shareContentType")
                userDefaults.removeObject(forKey: "shareTextContent")
                userDefaults.removeObject(forKey: "shareSourceURL")
                userDefaults.removeObject(forKey: "shareOriginalFilename")
                userDefaults.removeObject(forKey: "shareTimestamp")
                userDefaults.synchronize()
            }
            // If pendingId != fileId, a newer share has arrived - don't clear it
        }

        // Delete temp file if exists
        if let fileId = fileId,
           let url = try? fileURL(for: fileId) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Errors

enum ContentLoadError: LocalizedError {
    case missingFileId
    case missingURL
    case appGroupUnavailable
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .missingFileId: return "Missing file reference"
        case .missingURL: return "Missing URL"
        case .appGroupUnavailable: return "Cannot access shared storage"
        case .fileNotFound: return "File not found in shared storage"
        }
    }
}
