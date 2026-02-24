//
//  ShareImportViewModel.swift
//  SwiftSpeak
//
//  ViewModel for handling shared content from Share Extension
//  Supports: Audio, Text, Images (OCR), URLs (web fetch), PDFs
//  Processes content through selected Power Mode
//

import Combine
import Foundation
import SwiftUI
import AVFoundation
import SwiftSpeakCore

/// State for share import flow
enum ShareImportState: Equatable {
    case loading           // Loading content info
    case ready             // Ready to select Power Mode
    case extracting        // Extracting text from content (OCR, URL, PDF)
    case transcribing      // Transcribing audio
    case selectOutput      // Let user select output actions
    case processing        // Processing through Power Mode
    case complete          // Done - show result
    case error(String)     // Error occurred

    static func == (lhs: ShareImportState, rhs: ShareImportState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.ready, .ready),
             (.extracting, .extracting),
             (.transcribing, .transcribing),
             (.selectOutput, .selectOutput),
             (.processing, .processing),
             (.complete, .complete):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

/// ViewModel for share import flow
@MainActor
final class ShareImportViewModel: ObservableObject {

    // MARK: - Published State

    @Published var state: ShareImportState = .loading
    @Published var selectedPowerMode: PowerMode?
    @Published var extractedText: String = ""
    @Published var result: PowerModeResult?
    @Published var streamingText: String = ""

    // Content info
    @Published var contentType: SharedContentType = .audio
    @Published var contentFileName: String = ""
    @Published var contentPreview: String? = nil

    // Audio-specific
    @Published var audioDuration: TimeInterval = 0

    // Output action selection
    @Published var selectedOutputActions: Set<UUID> = []

    // Context selection (for transcription hints, vocabulary, language, formatting)
    @Published var selectedContextId: UUID?

    // Diarization toggle (for AssemblyAI audio)
    @Published var enableDiarization: Bool = false
    @Published var expectedSpeakerCount: Int? = nil

    // Progress tracking for transcription
    @Published var transcriptionPhase: TranscriptionPhase = .preparing
    @Published var currentChunk: Int = 0
    @Published var totalChunks: Int = 0
    @Published var transcriptionStartTime: Date?

    // Extraction progress
    @Published var extractionStatus: String = ""

    // Track the saved raw transcription record ID (for potential updates after Power Mode processing)
    private var rawTranscriptionRecordId: UUID?

    enum TranscriptionPhase: Equatable {
        case preparing
        case compressing
        case splitting
        case transcribing(chunk: Int, total: Int)
        case combining
        case complete

        var displayText: String {
            switch self {
            case .preparing: return "Preparing audio..."
            case .compressing: return "Optimizing for upload..."
            case .splitting: return "Splitting into chunks..."
            case .transcribing(let chunk, let total):
                if total > 1 {
                    return "Transcribing chunk \(chunk)/\(total)..."
                } else {
                    return "Transcribing audio..."
                }
            case .combining: return "Combining results..."
            case .complete: return "Transcription complete"
            }
        }

        var icon: String {
            switch self {
            case .preparing: return "doc.badge.gearshape"
            case .compressing: return "arrow.down.right.and.arrow.up.left"
            case .splitting: return "scissors"
            case .transcribing: return "waveform"
            case .combining: return "text.justify.left"
            case .complete: return "checkmark.circle.fill"
            }
        }

        var progress: Double? {
            switch self {
            case .preparing: return nil
            case .compressing: return nil
            case .splitting: return nil
            case .transcribing(let chunk, let total):
                return Double(chunk - 1) / Double(total)
            case .combining: return 0.95
            case .complete: return 1.0
            }
        }
    }

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let providerFactory: ProviderFactoryProtocol
    private var orchestrator: PowerModeOrchestrator?

    // MARK: - File Info

    private var contentFileURL: URL?
    private var sourceURL: URL?  // For URL type
    private let shareId: String

    // MARK: - Initialization

    init(shareId: String, contentType: SharedContentType? = nil, settings: SharedSettings = .shared) {
        self.shareId = shareId
        self.settings = settings
        self.providerFactory = ProviderFactory(settings: settings)

        // Content type can be passed or read from UserDefaults
        if let type = contentType {
            self.contentType = type
        }

        loadContent()
    }

    // MARK: - Content Loading

    private func loadContent() {
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Get content type from UserDefaults if not set
        if let typeString = userDefaults?.string(forKey: ShareContentConstants.contentTypeKey),
           let type = SharedContentType(rawValue: typeString) {
            contentType = type
        }

        // Load based on content type
        switch contentType {
        case .audio:
            loadAudioContent()
        case .text:
            loadTextContent()
        case .image:
            loadImageContent()
        case .url:
            loadURLContent()
        case .pdf:
            loadPDFContent()
        }
    }

    private func loadAudioContent() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            state = .error("Cannot access App Group container")
            return
        }

        let sharedDir = containerURL.appendingPathComponent(ShareContentConstants.sharedContentDirectory)

        // Find the audio file with matching ID
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: sharedDir, includingPropertiesForKeys: nil) else {
            state = .error("Cannot read shared content directory")
            return
        }

        guard let audioFile = files.first(where: { $0.lastPathComponent.hasPrefix(shareId) }) else {
            state = .error("Audio file not found")
            return
        }

        contentFileURL = audioFile

        // Get original filename from UserDefaults
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        contentFileName = userDefaults?.string(forKey: ShareContentConstants.originalFilenameKey) ?? audioFile.lastPathComponent

        // Get audio duration
        let asset = AVURLAsset(url: audioFile)
        Task {
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    self.audioDuration = duration.seconds
                    self.state = .ready
                }
            } catch {
                await MainActor.run {
                    self.audioDuration = 0
                    self.state = .ready // Continue even if duration unavailable
                }
            }
        }
    }

    private func loadTextContent() {
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        // Check if text was stored inline in UserDefaults
        if let text = userDefaults?.string(forKey: ShareContentConstants.textContentKey), !text.isEmpty {
            extractedText = text
            contentFileName = "Shared Text"
            contentPreview = String(text.prefix(200)) + (text.count > 200 ? "..." : "")
            state = .ready
            return
        }

        // Otherwise, look for file
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            state = .error("Cannot access App Group container")
            return
        }

        let sharedDir = containerURL.appendingPathComponent(ShareContentConstants.sharedContentDirectory)
        let fileURL = sharedDir.appendingPathComponent("\(shareId).txt")

        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            extractedText = text
            contentFileName = userDefaults?.string(forKey: ShareContentConstants.originalFilenameKey) ?? "Shared Text"
            contentPreview = String(text.prefix(200)) + (text.count > 200 ? "..." : "")
            state = .ready
        } catch {
            state = .error("Failed to load text: \(error.localizedDescription)")
        }
    }

    private func loadImageContent() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            state = .error("Cannot access App Group container")
            return
        }

        let sharedDir = containerURL.appendingPathComponent(ShareContentConstants.sharedContentDirectory)

        // Find the image file with matching ID
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: sharedDir, includingPropertiesForKeys: nil) else {
            state = .error("Cannot read shared content directory")
            return
        }

        guard let imageFile = files.first(where: { $0.lastPathComponent.hasPrefix(shareId) }) else {
            state = .error("Image file not found")
            return
        }

        contentFileURL = imageFile
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        contentFileName = userDefaults?.string(forKey: ShareContentConstants.originalFilenameKey) ?? imageFile.lastPathComponent
        state = .ready
    }

    private func loadURLContent() {
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)

        guard let urlString = userDefaults?.string(forKey: ShareContentConstants.sourceURLKey),
              let url = URL(string: urlString) else {
            state = .error("URL not found")
            return
        }

        sourceURL = url
        contentFileName = url.host ?? url.absoluteString
        contentPreview = urlString
        state = .ready
    }

    private func loadPDFContent() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            state = .error("Cannot access App Group container")
            return
        }

        let sharedDir = containerURL.appendingPathComponent(ShareContentConstants.sharedContentDirectory)

        // Find the PDF file with matching ID
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: sharedDir, includingPropertiesForKeys: nil) else {
            state = .error("Cannot read shared content directory")
            return
        }

        guard let pdfFile = files.first(where: { $0.lastPathComponent.hasPrefix(shareId) }) else {
            state = .error("PDF file not found")
            return
        }

        contentFileURL = pdfFile
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        contentFileName = userDefaults?.string(forKey: ShareContentConstants.originalFilenameKey) ?? pdfFile.lastPathComponent

        // Get PDF page count
        let extractor = PDFTextExtractor()
        if let metadata = extractor.metadata(from: pdfFile) {
            contentPreview = "\(metadata.pageCount) pages"
            if let title = metadata.title {
                contentFileName = title
            }
        }

        state = .ready
    }

    // MARK: - Content Extraction

    func startExtraction() async {
        guard selectedPowerMode != nil else {
            state = .error("Please select a Power Mode")
            return
        }

        switch contentType {
        case .audio:
            await startTranscription()
        case .text:
            // Text is already extracted, go directly to output selection
            state = .selectOutput
            if let powerMode = selectedPowerMode {
                selectedOutputActions = Set(powerMode.outputActions.filter { $0.isEnabled }.map { $0.id })
            }
        case .image:
            await extractFromImage()
        case .url:
            await extractFromURL()
        case .pdf:
            await extractFromPDF()
        }
    }

    private func extractFromImage() async {
        guard let imageURL = contentFileURL else {
            state = .error("No image file loaded")
            return
        }

        state = .extracting
        extractionStatus = "Extracting text via OCR..."

        do {
            let ocrService = ImageOCRService(languages: [.english])  // TODO: Use context language
            extractedText = try await ocrService.extractText(from: imageURL)

            if extractedText.isEmpty {
                state = .error("No text found in image")
            } else {
                state = .selectOutput
                if let powerMode = selectedPowerMode {
                    selectedOutputActions = Set(powerMode.outputActions.filter { $0.isEnabled }.map { $0.id })
                }
            }
        } catch {
            state = .error("OCR failed: \(error.localizedDescription)")
        }
    }

    private func extractFromURL() async {
        guard let url = sourceURL else {
            state = .error("No URL loaded")
            return
        }

        state = .extracting
        extractionStatus = "Fetching web content..."

        do {
            let fetcher = URLContentFetcher()
            let (text, title) = try await fetcher.fetchContent(from: url)
            extractedText = text
            if let title = title {
                contentFileName = title
            }

            if extractedText.isEmpty {
                state = .error("No content found at URL")
            } else {
                state = .selectOutput
                if let powerMode = selectedPowerMode {
                    selectedOutputActions = Set(powerMode.outputActions.filter { $0.isEnabled }.map { $0.id })
                }
            }
        } catch {
            state = .error("Failed to fetch URL: \(error.localizedDescription)")
        }
    }

    private func extractFromPDF() async {
        guard let pdfURL = contentFileURL else {
            state = .error("No PDF file loaded")
            return
        }

        state = .extracting
        extractionStatus = "Extracting text from PDF..."

        do {
            let extractor = PDFTextExtractor()
            extractedText = try extractor.extractText(from: pdfURL)

            if extractedText.isEmpty {
                state = .error("No text found in PDF")
            } else {
                state = .selectOutput
                if let powerMode = selectedPowerMode {
                    selectedOutputActions = Set(powerMode.outputActions.filter { $0.isEnabled }.map { $0.id })
                }
            }
        } catch {
            state = .error("PDF extraction failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Transcription

    func startTranscription() async {
        guard let audioURL = contentFileURL else {
            state = .error("No audio file loaded")
            return
        }

        guard selectedPowerMode != nil else {
            state = .error("Please select a Power Mode")
            return
        }

        state = .transcribing
        transcriptionPhase = .preparing
        transcriptionStartTime = Date()
        currentChunk = 0
        totalChunks = 0

        do {
            // Determine which transcription provider will be used
            let transcriptionOverride = selectedPowerMode?.transcriptionProviderOverride
            let isGoogleProvider: Bool
            let isAssemblyAIProvider: Bool
            if let override = transcriptionOverride {
                isGoogleProvider = override.providerType == .cloud(.google)
                isAssemblyAIProvider = override.providerType == .cloud(.assemblyAI)
            } else {
                // Check if default provider is Google or AssemblyAI
                isGoogleProvider = settings.selectedTranscriptionProvider == .google
                isAssemblyAIProvider = settings.selectedTranscriptionProvider == .assemblyAI
            }

            // Get the transcription provider
            let provider: TranscriptionProvider?
            if let override = transcriptionOverride {
                provider = providerFactory.createTranscriptionProvider(for: override)
            } else {
                provider = providerFactory.createSelectedTranscriptionProvider()
            }

            guard let provider = provider else {
                state = .error("No transcription provider configured")
                return
            }

            // Prepare audio for transcription
            var processedURL = audioURL

            // Step 1: Compress if beneficial (skip for Google - encoding issues)
            if !isGoogleProvider && AudioUtils.shouldCompress(url: audioURL) {
                transcriptionPhase = .compressing
                processedURL = try await AudioUtils.compressForTranscription(sourceURL: audioURL)
            }

            // Build prompt hint from power mode instruction + context vocabulary
            var promptHintParts: [String] = []
            if let instruction = selectedPowerMode?.instruction, !instruction.isEmpty {
                promptHintParts.append(instruction)
            }
            // Add context vocabulary hints
            if let context = selectedContext {
                let vocabularyHints = context.transcriptionVocabulary
                if !vocabularyHints.isEmpty {
                    promptHintParts.append(vocabularyHints.joined(separator: ", "))
                }
            }
            let promptHint = promptHintParts.isEmpty ? nil : promptHintParts.joined(separator: ". ")

            // Get language: context override > settings default
            let language: Language?
            if let ctx = selectedContext, ctx.autoDetectInputLanguage {
                language = nil
            } else if let contextLanguage = selectedContext?.defaultInputLanguage {
                language = contextLanguage
            } else {
                language = settings.selectedDictationLanguage
            }

            // Step 2: Check if diarization is enabled for AssemblyAI
            if isAssemblyAIProvider && enableDiarization,
               let diarizationProvider = provider as? DiarizationProvider {
                // Use diarization transcription for AssemblyAI
                totalChunks = 1
                currentChunk = 1
                transcriptionPhase = .transcribing(chunk: 1, total: 1)
                print("📝 Transcribing with diarization... (language: \(language?.rawValue ?? "auto"))")
                let result = try await diarizationProvider.transcribeWithDiarization(
                    audioURL: processedURL,
                    language: language,
                    promptHint: promptHint,
                    speakerCount: expectedSpeakerCount
                )

                // Format diarized output with speaker labels
                if let diarization = result.diarization {
                    extractedText = formatDiarizedTranscript(diarization)
                } else {
                    extractedText = result.text
                }
                transcriptionPhase = .complete
            }
            // Step 3: Check if chunking is needed
            else if AudioUtils.needsChunking(url: processedURL) ||
                    (isGoogleProvider && audioDuration > AudioUtils.maxGoogleChunkDuration) {
                // Split into chunks and transcribe each
                transcriptionPhase = .splitting
                let maxDuration: Double? = isGoogleProvider ? AudioUtils.maxGoogleChunkDuration : nil
                let chunks = try await AudioUtils.splitIntoChunks(
                    sourceURL: processedURL,
                    asWAV: isGoogleProvider,
                    maxDuration: maxDuration
                )
                var transcriptions: [String] = []
                totalChunks = chunks.count

                for (index, chunkURL) in chunks.enumerated() {
                    currentChunk = index + 1
                    transcriptionPhase = .transcribing(chunk: currentChunk, total: totalChunks)
                    print("📝 Transcribing chunk \(index + 1)/\(chunks.count)... (language: \(language?.rawValue ?? "auto"))")
                    let chunkText = try await provider.transcribe(
                        audioURL: chunkURL,
                        language: language,
                        promptHint: promptHint
                    )
                    transcriptions.append(chunkText)
                }

                // Clean up chunk files
                let chunksToClean = chunks.filter { $0 != processedURL && $0 != audioURL }
                AudioUtils.cleanupChunks(chunksToClean)

                // Combine transcriptions
                transcriptionPhase = .combining
                extractedText = transcriptions.joined(separator: " ")
                transcriptionPhase = .complete
            } else if isGoogleProvider {
                // Google with short audio: convert to WAV but no chunking
                totalChunks = 1
                currentChunk = 1
                transcriptionPhase = .transcribing(chunk: 1, total: 1)

                let wavURL = try await AudioUtils.convertToWAV(sourceURL: processedURL)
                extractedText = try await provider.transcribe(
                    audioURL: wavURL,
                    language: language,
                    promptHint: promptHint
                )
                try? FileManager.default.removeItem(at: wavURL)
                transcriptionPhase = .complete
            } else {
                // Single file transcription
                totalChunks = 1
                currentChunk = 1
                transcriptionPhase = .transcribing(chunk: 1, total: 1)
                extractedText = try await provider.transcribe(
                    audioURL: processedURL,
                    language: language,
                    promptHint: promptHint
                )
                transcriptionPhase = .complete
            }

            // Apply vocabulary replacements
            extractedText = settings.applyVocabulary(to: extractedText)

            // Save raw transcription to history IMMEDIATELY
            saveRawTranscriptionToHistory()

            // Move to output selection
            state = .selectOutput

            // Pre-select all enabled output actions
            if let powerMode = selectedPowerMode {
                selectedOutputActions = Set(powerMode.outputActions.filter { $0.isEnabled }.map { $0.id })
            }

        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
    }

    /// Save raw transcription to history immediately
    private func saveRawTranscriptionToHistory() {
        guard let powerMode = selectedPowerMode else { return }

        let elapsedTime = transcriptionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        let costCalculator = CostCalculator()

        let transcriptionProvider: AIProvider
        if let override = powerMode.transcriptionProviderOverride,
           case .cloud(let provider) = override.providerType {
            transcriptionProvider = provider
        } else {
            transcriptionProvider = settings.selectedTranscriptionProvider
        }

        let transcriptionModel = powerMode.transcriptionProviderOverride?.model
            ?? transcriptionProvider.defaultSTTModel
            ?? "default"

        let costBreakdown = costCalculator.calculateCostBreakdown(
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            formattingProvider: nil,
            formattingModel: nil,
            translationProvider: nil,
            translationModel: nil,
            durationSeconds: audioDuration,
            textLength: extractedText.count,
            text: extractedText
        )

        let record = TranscriptionRecord(
            id: UUID(),
            rawTranscribedText: extractedText,
            text: extractedText,
            mode: .raw,
            provider: transcriptionProvider,
            timestamp: Date(),
            duration: audioDuration,
            translated: false,
            targetLanguage: nil,
            powerModeId: powerMode.id,
            powerModeName: "\(powerMode.name) (Transcription Only)",
            contextId: selectedContext?.id,
            contextName: selectedContext?.name,
            contextIcon: selectedContext?.icon,
            estimatedCost: costBreakdown.total,
            costBreakdown: costBreakdown,
            processingMetadata: ProcessingMetadata(
                steps: [],
                totalProcessingTime: elapsedTime,
                sourceLanguageHint: (selectedContext?.autoDetectInputLanguage == true) ? nil : (selectedContext?.defaultInputLanguage ?? settings.selectedDictationLanguage),
                vocabularyApplied: nil,
                memorySourcesUsed: nil,
                ragDocumentsQueried: nil,
                webhooksExecuted: nil
            ),
            editContext: nil,
            source: .app,
            globalMemoryEnabled: false,
            contextMemoryEnabled: selectedContext?.useContextMemory ?? false,
            powerModeMemoryEnabled: powerMode.memoryEnabled,
            usedForGlobalMemory: false,
            usedForContextMemory: false,
            usedForPowerModeMemory: false
        )

        settings.addTranscription(record)
        rawTranscriptionRecordId = record.id
        appLog("Raw transcription saved to history (id: \(record.id), cost: $\(String(format: "%.4f", costBreakdown.total)))", category: "ShareImport")
    }

    // MARK: - Diarization Helpers

    private func formatDiarizedTranscript(_ diarization: DiarizedTranscript) -> String {
        var formattedLines: [String] = []
        var currentSpeaker: String? = nil

        for segment in diarization.segments {
            if segment.speaker != currentSpeaker {
                currentSpeaker = segment.speaker
                formattedLines.append("\n**Speaker \(segment.speaker):**")
            }
            formattedLines.append(segment.text)
        }

        return formattedLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Power Mode Processing

    func processWithPowerMode() async {
        guard let powerMode = selectedPowerMode else {
            state = .error("No Power Mode selected")
            return
        }

        guard !extractedText.isEmpty else {
            state = .error("No extracted text")
            return
        }

        state = .processing

        do {
            // Create orchestrator with selected Power Mode
            orchestrator = PowerModeOrchestrator(
                powerMode: powerMode,
                settings: settings
            )

            // Process the extracted text through the Power Mode
            await orchestrator?.processExistingText(
                extractedText,
                selectedOutputActionIds: selectedOutputActions
            )

            // Check result
            if let session = orchestrator?.session,
               let currentResult = session.currentResult {
                result = currentResult

                // Create TranscriptionRecord for history and cost tracking
                saveToHistory(powerMode: powerMode, result: currentResult)

                state = .complete
            } else if let error = orchestrator?.errorMessage {
                state = .error(error)
            } else {
                state = .error("Processing failed - no result returned")
            }
        } catch {
            appLog("Power Mode processing crashed: \(error.localizedDescription)", category: "ShareImport", level: .error)
            state = .error("Processing failed: \(error.localizedDescription)")
        }
    }

    /// Save the Power Mode result to history for cost tracking
    private func saveToHistory(powerMode: PowerMode, result: PowerModeResult) {
        let costCalculator = CostCalculator()

        // Extract transcription provider from override or default
        let transcriptionProvider: AIProvider
        if let override = powerMode.transcriptionProviderOverride,
           case .cloud(let provider) = override.providerType {
            transcriptionProvider = provider
        } else {
            transcriptionProvider = settings.selectedTranscriptionProvider
        }

        let transcriptionModel = powerMode.transcriptionProviderOverride?.model
            ?? transcriptionProvider.defaultSTTModel
            ?? "default"

        // Extract LLM provider from override or default
        let formattingProvider: AIProvider?
        let formattingModel: String?
        if let override = powerMode.providerOverride,
           case .cloud(let provider) = override.providerType {
            formattingProvider = provider
            formattingModel = override.model ?? provider.defaultLLMModel
        } else {
            formattingProvider = settings.selectedFormattingProvider
            formattingModel = settings.selectedFormattingProvider.defaultLLMModel
        }

        let costBreakdown = costCalculator.calculateCostBreakdown(
            transcriptionProvider: transcriptionProvider,
            transcriptionModel: transcriptionModel,
            formattingProvider: formattingProvider,
            formattingModel: formattingModel,
            translationProvider: nil,
            translationModel: nil,
            durationSeconds: audioDuration,
            textLength: result.markdownOutput.count,
            text: result.markdownOutput
        )

        let record = TranscriptionRecord(
            id: UUID(),
            rawTranscribedText: extractedText,
            text: result.markdownOutput,
            mode: .raw,
            provider: transcriptionProvider,
            timestamp: Date(),
            duration: audioDuration,
            translated: false,
            targetLanguage: nil,
            powerModeId: powerMode.id,
            powerModeName: powerMode.name,
            contextId: selectedContext?.id,
            contextName: selectedContext?.name,
            contextIcon: selectedContext?.icon,
            estimatedCost: costBreakdown.total,
            costBreakdown: costBreakdown,
            processingMetadata: ProcessingMetadata(
                steps: [],
                totalProcessingTime: result.processingDuration,
                sourceLanguageHint: (selectedContext?.autoDetectInputLanguage == true) ? nil : (selectedContext?.defaultInputLanguage ?? settings.selectedDictationLanguage),
                vocabularyApplied: nil,
                memorySourcesUsed: nil,
                ragDocumentsQueried: nil,
                webhooksExecuted: nil
            ),
            editContext: nil,
            source: .app,
            globalMemoryEnabled: result.globalMemoryEnabled,
            contextMemoryEnabled: result.contextMemoryEnabled,
            powerModeMemoryEnabled: result.powerModeMemoryEnabled,
            usedForGlobalMemory: false,
            usedForContextMemory: false,
            usedForPowerModeMemory: false
        )

        // Remove the raw transcription record since we now have the full Power Mode result
        if let rawId = rawTranscriptionRecordId {
            settings.removeTranscription(id: rawId)
        }

        settings.addTranscription(record)
        appLog("Power Mode result saved to history (cost: $\(String(format: "%.4f", costBreakdown.total)))", category: "ShareImport")
    }

    // MARK: - Power Mode Helpers

    /// Power Modes that accept the current content type
    var availablePowerModes: [PowerMode] {
        let acceptingModes = settings.activePowerModes.filter { $0.acceptsContentType(contentType) }
        // If no Power Modes have this content type enabled, show all active Power Modes
        return acceptingModes.isEmpty ? settings.activePowerModes : acceptingModes
    }

    // MARK: - Output Action Helpers

    var availableOutputActions: [OutputAction] {
        selectedPowerMode?.outputActions ?? []
    }

    func toggleOutputAction(_ actionId: UUID) {
        if selectedOutputActions.contains(actionId) {
            selectedOutputActions.remove(actionId)
        } else {
            selectedOutputActions.insert(actionId)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        // Remove the shared content file
        if let contentURL = contentFileURL {
            try? FileManager.default.removeItem(at: contentURL)
        }

        // Clear pending share from UserDefaults
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        userDefaults?.removeObject(forKey: ShareContentConstants.pendingShareKey)
        userDefaults?.removeObject(forKey: ShareContentConstants.contentTypeKey)
        userDefaults?.removeObject(forKey: ShareContentConstants.originalFilenameKey)
        userDefaults?.removeObject(forKey: ShareContentConstants.timestampKey)
        userDefaults?.removeObject(forKey: ShareContentConstants.sourceURLKey)
        userDefaults?.removeObject(forKey: ShareContentConstants.textContentKey)
    }

    // MARK: - Computed Properties

    var formattedDuration: String {
        let minutes = Int(audioDuration) / 60
        let seconds = Int(audioDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var isTranscribing: Bool {
        state == .transcribing
    }

    var isExtracting: Bool {
        state == .extracting
    }

    var isProcessing: Bool {
        state == .processing
    }

    var canProcess: Bool {
        selectedPowerMode != nil && !extractedText.isEmpty
    }

    // Button text based on content type
    var extractButtonText: String {
        switch contentType {
        case .audio: return "Transcribe Audio"
        case .text: return "Process Text"
        case .image: return "Extract Text (OCR)"
        case .url: return "Fetch & Extract"
        case .pdf: return "Extract from PDF"
        }
    }

    var extractButtonIcon: String {
        switch contentType {
        case .audio: return "waveform.badge.mic"
        case .text: return "doc.text"
        case .image: return "text.viewfinder"
        case .url: return "globe"
        case .pdf: return "doc.richtext"
        }
    }

    // MARK: - Context Helpers

    var selectedContext: ConversationContext? {
        guard let id = selectedContextId else { return nil }
        return settings.contexts.first { $0.id == id }
    }

    var availableContexts: [ConversationContext] {
        settings.contexts
    }

    /// Whether the selected transcription provider supports diarization (audio only)
    var supportsDiarization: Bool {
        guard contentType == .audio else { return false }
        let transcriptionOverride = selectedPowerMode?.transcriptionProviderOverride
        if let override = transcriptionOverride {
            return override.providerType == .cloud(.assemblyAI)
        }
        return settings.selectedTranscriptionProvider == .assemblyAI
    }
}
