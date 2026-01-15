//
//  ShareImportViewModel.swift
//  SwiftSpeak
//
//  ViewModel for handling shared audio files from Share Extension
//  Transcribes audio and processes through selected Power Mode
//

import Combine
import Foundation
import SwiftUI
import AVFoundation
import SwiftSpeakCore

/// State for share import flow
enum ShareImportState: Equatable {
    case loading           // Loading audio file info
    case ready             // Ready to select Power Mode
    case transcribing      // Transcribing audio
    case selectOutput      // Let user select output actions
    case processing        // Processing through Power Mode
    case complete          // Done - show result
    case error(String)     // Error occurred

    static func == (lhs: ShareImportState, rhs: ShareImportState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading),
             (.ready, .ready),
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
    @Published var transcribedText: String = ""
    @Published var result: PowerModeResult?
    @Published var streamingText: String = ""

    // Audio file info
    @Published var audioFileName: String = ""
    @Published var audioDuration: TimeInterval = 0

    // Output action selection
    @Published var selectedOutputActions: Set<UUID> = []

    // Context selection (for transcription hints, vocabulary, language, formatting)
    @Published var selectedContextId: UUID?

    // Diarization toggle (for AssemblyAI)
    @Published var enableDiarization: Bool = false
    @Published var expectedSpeakerCount: Int? = nil

    // Progress tracking for transcription
    @Published var transcriptionPhase: TranscriptionPhase = .preparing
    @Published var currentChunk: Int = 0
    @Published var totalChunks: Int = 0
    @Published var transcriptionStartTime: Date?

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

    private var audioFileURL: URL?
    private let shareId: String

    // MARK: - Initialization

    init(shareId: String, settings: SharedSettings = .shared) {
        self.shareId = shareId
        self.settings = settings
        self.providerFactory = ProviderFactory(settings: settings)

        loadAudioFile()
    }

    // MARK: - Audio File Loading

    private func loadAudioFile() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            state = .error("Cannot access App Group container")
            return
        }

        let sharedDir = containerURL.appendingPathComponent(Constants.ShareExtension.sharedAudioDirectory)

        // Find the audio file with matching ID
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: sharedDir, includingPropertiesForKeys: nil) else {
            state = .error("Cannot read shared audio directory")
            return
        }

        guard let audioFile = files.first(where: { $0.lastPathComponent.hasPrefix(shareId) }) else {
            state = .error("Audio file not found")
            return
        }

        audioFileURL = audioFile

        // Get original filename from UserDefaults
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        audioFileName = userDefaults?.string(forKey: Constants.ShareExtension.originalFilenameKey) ?? audioFile.lastPathComponent

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

    // MARK: - Transcription

    func startTranscription() async {
        guard let audioURL = audioFileURL else {
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
            // For non-Google providers: compress large files for faster upload
            // For all providers: chunk files that exceed size limits (9MB for Google)
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
            if let contextLanguage = selectedContext?.defaultInputLanguage {
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
                    transcribedText = formatDiarizedTranscript(diarization)
                } else {
                    transcribedText = result.text
                }
                transcriptionPhase = .complete
            }
            // Step 3: Check if chunking is needed
            // For Google: only chunk if duration exceeds 55s (sync API has 60s limit)
            // For others: chunk if file > 5MB
            // Note: Only split when truly necessary as chunking degrades transcription quality
            else if AudioUtils.needsChunking(url: processedURL) ||
                    (isGoogleProvider && audioDuration > AudioUtils.maxGoogleChunkDuration) {
                // Split into chunks and transcribe each
                transcriptionPhase = .splitting
                // Use WAV for Google (they don't support M4A), enforce 55s max duration
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

                // Clean up chunk files (except if it was the original)
                let chunksToClean = chunks.filter { $0 != processedURL && $0 != audioURL }
                AudioUtils.cleanupChunks(chunksToClean)

                // Combine transcriptions
                transcriptionPhase = .combining
                transcribedText = transcriptions.joined(separator: " ")
                transcriptionPhase = .complete
            } else if isGoogleProvider {
                // Google with short audio: convert to WAV but no chunking
                totalChunks = 1
                currentChunk = 1
                transcriptionPhase = .transcribing(chunk: 1, total: 1)

                // Convert to WAV for Google compatibility
                let wavURL = try await AudioUtils.convertToWAV(sourceURL: processedURL)
                transcribedText = try await provider.transcribe(
                    audioURL: wavURL,
                    language: language,
                    promptHint: promptHint
                )
                // Clean up WAV file
                try? FileManager.default.removeItem(at: wavURL)
                transcriptionPhase = .complete
            } else {
                // Single file transcription (non-Google, no chunking needed)
                totalChunks = 1
                currentChunk = 1
                transcriptionPhase = .transcribing(chunk: 1, total: 1)
                transcribedText = try await provider.transcribe(
                    audioURL: processedURL,
                    language: language,
                    promptHint: promptHint
                )
                transcriptionPhase = .complete
            }

            // Apply vocabulary replacements from settings and context
            transcribedText = settings.applyVocabulary(to: transcribedText)

            // Save raw transcription to history IMMEDIATELY so user doesn't lose work
            // This ensures even if Power Mode processing fails, the transcription is saved
            saveRawTranscriptionToHistory()

            // Move to output selection (let user choose which output actions to run)
            state = .selectOutput

            // Pre-select all enabled output actions
            if let powerMode = selectedPowerMode {
                selectedOutputActions = Set(powerMode.outputActions.filter { $0.isEnabled }.map { $0.id })
            }

        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
    }

    /// Save raw transcription to history immediately (before Power Mode processing)
    /// This ensures user never loses their transcription even if processing crashes
    private func saveRawTranscriptionToHistory() {
        guard let powerMode = selectedPowerMode else { return }

        let elapsedTime = transcriptionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Calculate transcription cost
        let costCalculator = CostCalculator()

        // Extract cloud provider from override or use default
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
            textLength: transcribedText.count,
            text: transcribedText
        )

        let record = TranscriptionRecord(
            id: UUID(),
            rawTranscribedText: transcribedText,
            text: transcribedText,  // Raw text before Power Mode processing
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
                sourceLanguageHint: selectedContext?.defaultInputLanguage ?? settings.selectedDictationLanguage,
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

    /// Format diarized transcript with speaker labels
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

        guard !transcribedText.isEmpty else {
            state = .error("No transcribed text")
            return
        }

        state = .processing

        do {
            // Create orchestrator with selected Power Mode
            orchestrator = PowerModeOrchestrator(
                powerMode: powerMode,
                settings: settings
            )

            // Process the transcribed text through the Power Mode
            await orchestrator?.processExistingText(
                transcribedText,
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
        // Calculate costs for transcription + LLM processing
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
            rawTranscribedText: transcribedText,
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
                sourceLanguageHint: selectedContext?.defaultInputLanguage ?? settings.selectedDictationLanguage,
                vocabularyApplied: nil,
                memorySourcesUsed: nil,
                ragDocumentsQueried: nil,
                webhooksExecuted: nil
            ),
            editContext: nil,
            source: .app,  // Share extension uses app source type
            globalMemoryEnabled: result.globalMemoryEnabled,
            contextMemoryEnabled: result.contextMemoryEnabled,
            powerModeMemoryEnabled: result.powerModeMemoryEnabled,
            usedForGlobalMemory: false,
            usedForContextMemory: false,
            usedForPowerModeMemory: false
        )

        // Remove the raw transcription record since we now have the full Power Mode result
        // This prevents duplicate history entries
        if let rawId = rawTranscriptionRecordId {
            settings.removeTranscription(id: rawId)
        }

        settings.addTranscription(record)
        appLog("Power Mode result saved to history (cost: $\(String(format: "%.4f", costBreakdown.total)))", category: "ShareImport")
    }

    // MARK: - Power Mode Helpers

    /// Power Modes that accept shared audio files
    /// Only shows Power Modes with the shareAudioImport input action enabled
    /// Falls back to all active Power Modes if none have shareAudioImport
    var availablePowerModes: [PowerMode] {
        let sharingModes = settings.activePowerModes.filter { $0.acceptsSharedAudio }
        // If no Power Modes have shareAudioImport enabled, show all active Power Modes
        return sharingModes.isEmpty ? settings.activePowerModes : sharingModes
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
        // Remove the shared audio file
        if let audioURL = audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
        }

        // Clear pending share from UserDefaults
        let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier)
        userDefaults?.removeObject(forKey: Constants.ShareExtension.pendingShareKey)
        userDefaults?.removeObject(forKey: Constants.ShareExtension.originalFilenameKey)
        userDefaults?.removeObject(forKey: Constants.ShareExtension.timestampKey)
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

    var isProcessing: Bool {
        state == .processing
    }

    var canProcess: Bool {
        selectedPowerMode != nil && !transcribedText.isEmpty
    }

    // MARK: - Context Helpers

    /// The currently selected context (nil = no context)
    var selectedContext: ConversationContext? {
        guard let id = selectedContextId else { return nil }
        return settings.contexts.first { $0.id == id }
    }

    /// Available contexts for the picker
    var availableContexts: [ConversationContext] {
        settings.contexts
    }

    /// Whether the selected transcription provider supports diarization
    var supportsDiarization: Bool {
        // Check if AssemblyAI is the selected provider
        let transcriptionOverride = selectedPowerMode?.transcriptionProviderOverride
        if let override = transcriptionOverride {
            return override.providerType == .cloud(.assemblyAI)
        }
        return settings.selectedTranscriptionProvider == .assemblyAI
    }
}
