//
//  MemoryUpdateScheduler.swift
//  SwiftSpeak
//
//  Batch memory update scheduler.
//  Handles scheduled memory updates on app start with 12h-24h intervals.
//

import Foundation
import SwiftSpeakCore
import Combine

/// Scheduling intervals for memory updates
enum MemoryUpdateInterval {
    /// Minimum time between updates (12 hours = twice a day max)
    static let minimumInterval: TimeInterval = 12 * 60 * 60
    /// Maximum time before forced update (24 hours = at least once a day)
    static let maximumInterval: TimeInterval = 24 * 60 * 60
    /// Default maximum characters for memory (can be overridden per-tier)
    static let defaultMaxMemoryLength = 2000
    /// Minimum allowed memory limit
    static let minMemoryLength = 500
    /// Maximum allowed memory limit
    static let maxMemoryLength = 2000
}

/// Result of a scheduled memory update
struct ScheduledMemoryUpdateResult: Equatable {
    static func == (lhs: ScheduledMemoryUpdateResult, rhs: ScheduledMemoryUpdateResult) -> Bool {
        lhs.tier == rhs.tier &&
        lhs.tierId == rhs.tierId &&
        lhs.recordsProcessed == rhs.recordsProcessed &&
        lhs.previousMemoryLength == rhs.previousMemoryLength &&
        lhs.newMemoryLength == rhs.newMemoryLength &&
        lhs.success == rhs.success &&
        lhs.skippedReason == rhs.skippedReason
        // Note: Error is not compared since Error doesn't conform to Equatable
    }

    let tier: MemoryTier
    let tierId: UUID? // nil for global
    let recordsProcessed: Int
    let previousMemoryLength: Int
    let newMemoryLength: Int
    let success: Bool
    let error: Error?
    let skippedReason: SkipReason?

    enum SkipReason {
        case noNewRecords
        case tooSoon // Less than 12h since last update
        case memoryDisabled
    }
}

/// Schedules and executes batch memory updates
/// Updates memory on app start, respecting 12h-24h intervals
@MainActor
final class MemoryUpdateScheduler: ObservableObject {

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let providerFactory: ProviderFactory

    // MARK: - State

    @Published private(set) var isUpdating = false
    @Published private(set) var lastUpdateResults: [ScheduledMemoryUpdateResult] = []

    // MARK: - Initialization

    init(settings: SharedSettings? = nil, providerFactory: ProviderFactory? = nil) {
        let resolvedSettings = settings ?? SharedSettings.shared
        self.settings = resolvedSettings
        self.providerFactory = providerFactory ?? ProviderFactory(settings: resolvedSettings)
    }

    // MARK: - Public API

    /// Check if any memory tier needs updating and perform updates
    /// Called on app start
    func performScheduledUpdates() async -> [ScheduledMemoryUpdateResult] {
        guard !isUpdating else { return [] }

        isUpdating = true
        defer { isUpdating = false }

        var results: [ScheduledMemoryUpdateResult] = []

        // 1. Check and update global memory
        if settings.globalMemoryEnabled {
            let result = await updateGlobalMemoryIfNeeded()
            results.append(result)
        }

        // 2. Check and update each context's memory
        for context in settings.contexts where context.useContextMemory {
            let result = await updateContextMemoryIfNeeded(context: context)
            results.append(result)
        }

        // 3. Check and update each power mode's memory
        for powerMode in settings.powerModes where powerMode.memoryEnabled {
            let result = await updatePowerModeMemoryIfNeeded(powerMode: powerMode)
            results.append(result)
        }

        lastUpdateResults = results
        return results
    }

    /// Force update all memory tiers regardless of schedule
    func forceUpdateAll() async -> [ScheduledMemoryUpdateResult] {
        guard !isUpdating else { return [] }

        isUpdating = true
        defer { isUpdating = false }

        var results: [ScheduledMemoryUpdateResult] = []

        // Global memory
        if settings.globalMemoryEnabled {
            let result = await updateGlobalMemory()
            results.append(result)
        }

        // Each context
        for context in settings.contexts where context.useContextMemory {
            let result = await updateContextMemory(context: context)
            results.append(result)
        }

        // Each power mode
        for powerMode in settings.powerModes where powerMode.memoryEnabled {
            let result = await updatePowerModeMemory(powerMode: powerMode)
            results.append(result)
        }

        lastUpdateResults = results
        return results
    }

    // MARK: - Global Memory

    private func updateGlobalMemoryIfNeeded() async -> ScheduledMemoryUpdateResult {
        // Check if update is needed based on timing
        if let lastUpdate = settings.lastGlobalMemoryUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

            // If less than minimum interval, check if we have new records
            if timeSinceLastUpdate < MemoryUpdateInterval.minimumInterval {
                return ScheduledMemoryUpdateResult(
                    tier: .global,
                    tierId: nil,
                    recordsProcessed: 0,
                    previousMemoryLength: settings.globalMemory?.count ?? 0,
                    newMemoryLength: settings.globalMemory?.count ?? 0,
                    success: true,
                    error: nil,
                    skippedReason: .tooSoon
                )
            }

            // If between min and max, only update if there are new records
            if timeSinceLastUpdate < MemoryUpdateInterval.maximumInterval {
                let unprocessedRecords = settings.getUnprocessedRecordsForMemory(tier: .global)
                if unprocessedRecords.isEmpty {
                    return ScheduledMemoryUpdateResult(
                        tier: .global,
                        tierId: nil,
                        recordsProcessed: 0,
                        previousMemoryLength: settings.globalMemory?.count ?? 0,
                        newMemoryLength: settings.globalMemory?.count ?? 0,
                        success: true,
                        error: nil,
                        skippedReason: .noNewRecords
                    )
                }
            }
            // If > 24h, always update (even if no new records, for consistency)
        }

        return await updateGlobalMemory()
    }

    private func updateGlobalMemory() async -> ScheduledMemoryUpdateResult {
        let previousLength = settings.globalMemory?.count ?? 0
        let unprocessedRecords = settings.getUnprocessedRecordsForMemory(tier: .global)

        // If no new records, just return success
        if unprocessedRecords.isEmpty {
            settings.recordGlobalMemoryUpdate()
            return ScheduledMemoryUpdateResult(
                tier: .global,
                tierId: nil,
                recordsProcessed: 0,
                previousMemoryLength: previousLength,
                newMemoryLength: previousLength,
                success: true,
                error: nil,
                skippedReason: .noNewRecords
            )
        }

        do {
            // Generate new memory from existing + new messages
            let newMemory = try await generateMemory(
                existingMemory: settings.globalMemory,
                newMessages: unprocessedRecords.map { $0.text },
                tier: .global,
                maxLength: settings.globalMemoryLimit
            )

            // Save the new memory
            settings.globalMemory = newMemory
            settings.recordGlobalMemoryUpdate()

            // Mark records as processed
            settings.markRecordsAsUsedForMemory(
                recordIds: unprocessedRecords.map { $0.id },
                tier: .global
            )

            return ScheduledMemoryUpdateResult(
                tier: .global,
                tierId: nil,
                recordsProcessed: unprocessedRecords.count,
                previousMemoryLength: previousLength,
                newMemoryLength: newMemory.count,
                success: true,
                error: nil,
                skippedReason: nil
            )
        } catch {
            return ScheduledMemoryUpdateResult(
                tier: .global,
                tierId: nil,
                recordsProcessed: 0,
                previousMemoryLength: previousLength,
                newMemoryLength: previousLength,
                success: false,
                error: error,
                skippedReason: nil
            )
        }
    }

    // MARK: - Context Memory

    private func updateContextMemoryIfNeeded(context: ConversationContext) async -> ScheduledMemoryUpdateResult {
        let lastUpdate = settings.lastContextMemoryUpdates[context.id]

        if let lastUpdate = lastUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

            if timeSinceLastUpdate < MemoryUpdateInterval.minimumInterval {
                return ScheduledMemoryUpdateResult(
                    tier: .context,
                    tierId: context.id,
                    recordsProcessed: 0,
                    previousMemoryLength: context.contextMemory?.count ?? 0,
                    newMemoryLength: context.contextMemory?.count ?? 0,
                    success: true,
                    error: nil,
                    skippedReason: .tooSoon
                )
            }

            if timeSinceLastUpdate < MemoryUpdateInterval.maximumInterval {
                let unprocessedRecords = settings.getUnprocessedRecordsForMemory(
                    tier: .context,
                    contextId: context.id
                )
                if unprocessedRecords.isEmpty {
                    return ScheduledMemoryUpdateResult(
                        tier: .context,
                        tierId: context.id,
                        recordsProcessed: 0,
                        previousMemoryLength: context.contextMemory?.count ?? 0,
                        newMemoryLength: context.contextMemory?.count ?? 0,
                        success: true,
                        error: nil,
                        skippedReason: .noNewRecords
                    )
                }
            }
        }

        return await updateContextMemory(context: context)
    }

    private func updateContextMemory(context: ConversationContext) async -> ScheduledMemoryUpdateResult {
        let previousLength = context.contextMemory?.count ?? 0
        let unprocessedRecords = settings.getUnprocessedRecordsForMemory(
            tier: .context,
            contextId: context.id
        )

        if unprocessedRecords.isEmpty {
            settings.recordContextMemoryUpdate(contextId: context.id)
            return ScheduledMemoryUpdateResult(
                tier: .context,
                tierId: context.id,
                recordsProcessed: 0,
                previousMemoryLength: previousLength,
                newMemoryLength: previousLength,
                success: true,
                error: nil,
                skippedReason: .noNewRecords
            )
        }

        do {
            let newMemory = try await generateMemory(
                existingMemory: context.contextMemory,
                newMessages: unprocessedRecords.map { $0.text },
                tier: .context,
                maxLength: context.memoryLimit,
                contextName: context.name,
                contextDescription: context.description  // Use description for context purpose
            )

            settings.updateContextMemory(id: context.id, memory: newMemory)
            settings.recordContextMemoryUpdate(contextId: context.id)
            settings.markRecordsAsUsedForMemory(
                recordIds: unprocessedRecords.map { $0.id },
                tier: .context
            )

            return ScheduledMemoryUpdateResult(
                tier: .context,
                tierId: context.id,
                recordsProcessed: unprocessedRecords.count,
                previousMemoryLength: previousLength,
                newMemoryLength: newMemory.count,
                success: true,
                error: nil,
                skippedReason: nil
            )
        } catch {
            return ScheduledMemoryUpdateResult(
                tier: .context,
                tierId: context.id,
                recordsProcessed: 0,
                previousMemoryLength: previousLength,
                newMemoryLength: previousLength,
                success: false,
                error: error,
                skippedReason: nil
            )
        }
    }

    // MARK: - Power Mode Memory

    private func updatePowerModeMemoryIfNeeded(powerMode: PowerMode) async -> ScheduledMemoryUpdateResult {
        let lastUpdate = settings.lastPowerModeMemoryUpdates[powerMode.id]

        if let lastUpdate = lastUpdate {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdate)

            if timeSinceLastUpdate < MemoryUpdateInterval.minimumInterval {
                return ScheduledMemoryUpdateResult(
                    tier: .powerMode,
                    tierId: powerMode.id,
                    recordsProcessed: 0,
                    previousMemoryLength: powerMode.memory?.count ?? 0,
                    newMemoryLength: powerMode.memory?.count ?? 0,
                    success: true,
                    error: nil,
                    skippedReason: .tooSoon
                )
            }

            if timeSinceLastUpdate < MemoryUpdateInterval.maximumInterval {
                let unprocessedRecords = settings.getUnprocessedRecordsForMemory(
                    tier: .powerMode,
                    powerModeId: powerMode.id
                )
                if unprocessedRecords.isEmpty {
                    return ScheduledMemoryUpdateResult(
                        tier: .powerMode,
                        tierId: powerMode.id,
                        recordsProcessed: 0,
                        previousMemoryLength: powerMode.memory?.count ?? 0,
                        newMemoryLength: powerMode.memory?.count ?? 0,
                        success: true,
                        error: nil,
                        skippedReason: .noNewRecords
                    )
                }
            }
        }

        return await updatePowerModeMemory(powerMode: powerMode)
    }

    private func updatePowerModeMemory(powerMode: PowerMode) async -> ScheduledMemoryUpdateResult {
        let previousLength = powerMode.memory?.count ?? 0
        let unprocessedRecords = settings.getUnprocessedRecordsForMemory(
            tier: .powerMode,
            powerModeId: powerMode.id
        )

        if unprocessedRecords.isEmpty {
            settings.recordPowerModeMemoryUpdate(powerModeId: powerMode.id)
            return ScheduledMemoryUpdateResult(
                tier: .powerMode,
                tierId: powerMode.id,
                recordsProcessed: 0,
                previousMemoryLength: previousLength,
                newMemoryLength: previousLength,
                success: true,
                error: nil,
                skippedReason: .noNewRecords
            )
        }

        do {
            let newMemory = try await generateMemory(
                existingMemory: powerMode.memory,
                newMessages: unprocessedRecords.map { $0.text },
                tier: .powerMode,
                maxLength: powerMode.memoryLimit,
                powerModeName: powerMode.name,
                powerModeDescription: powerMode.instruction  // Use instruction as power mode description
            )

            var updatedPowerMode = powerMode
            updatedPowerMode.memory = newMemory
            updatedPowerMode.lastMemoryUpdate = Date()
            settings.updatePowerMode(updatedPowerMode)

            settings.recordPowerModeMemoryUpdate(powerModeId: powerMode.id)
            settings.markRecordsAsUsedForMemory(
                recordIds: unprocessedRecords.map { $0.id },
                tier: .powerMode
            )

            return ScheduledMemoryUpdateResult(
                tier: .powerMode,
                tierId: powerMode.id,
                recordsProcessed: unprocessedRecords.count,
                previousMemoryLength: previousLength,
                newMemoryLength: newMemory.count,
                success: true,
                error: nil,
                skippedReason: nil
            )
        } catch {
            return ScheduledMemoryUpdateResult(
                tier: .powerMode,
                tierId: powerMode.id,
                recordsProcessed: 0,
                previousMemoryLength: previousLength,
                newMemoryLength: previousLength,
                success: false,
                error: error,
                skippedReason: nil
            )
        }
    }

    // MARK: - Memory Generation

    /// Generate memory from existing memory and new messages
    /// Calls LLM to synthesize a coherent memory
    /// - Parameter maxLength: Maximum character limit for the generated memory (defaults to 2000)
    private func generateMemory(
        existingMemory: String?,
        newMessages: [String],
        tier: MemoryTier,
        maxLength: Int = MemoryUpdateInterval.defaultMaxMemoryLength,
        contextName: String? = nil,
        contextDescription: String? = nil,
        powerModeName: String? = nil,
        powerModeDescription: String? = nil
    ) async throws -> String {
        guard let provider = providerFactory.createSelectedFormattingProvider() else {
            throw MemoryError.noProviderAvailable
        }

        // Clamp the max length to valid range
        let clampedMaxLength = min(max(maxLength, MemoryUpdateInterval.minMemoryLength), MemoryUpdateInterval.maxMemoryLength)

        // Build the prompt
        let prompt = buildMemoryGenerationPrompt(
            existingMemory: existingMemory,
            newMessages: newMessages,
            tier: tier,
            maxLength: clampedMaxLength,
            contextName: contextName,
            contextDescription: contextDescription,
            powerModeName: powerModeName,
            powerModeDescription: powerModeDescription
        )

        // Build the input text (existing memory + new messages)
        var inputParts: [String] = []

        if let existing = existingMemory, !existing.isEmpty {
            inputParts.append("=== EXISTING MEMORY ===\n\(existing)")
        }

        if !newMessages.isEmpty {
            let messagesText = newMessages.enumerated().map { index, msg in
                "[\(index + 1)] \(msg)"
            }.joined(separator: "\n\n")
            inputParts.append("=== NEW MESSAGES ===\n\(messagesText)")
        }

        let inputText = inputParts.joined(separator: "\n\n")

        // Call the LLM
        let result = try await provider.format(
            text: inputText,
            mode: .raw,
            customPrompt: prompt,
            context: nil
        )

        // Ensure we don't exceed the max length
        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedResult.count > clampedMaxLength {
            return String(trimmedResult.prefix(clampedMaxLength))
        }

        return trimmedResult
    }

    /// Build the prompt for memory generation
    private func buildMemoryGenerationPrompt(
        existingMemory: String?,
        newMessages: [String],
        tier: MemoryTier,
        maxLength: Int,
        contextName: String? = nil,
        contextDescription: String? = nil,
        powerModeName: String? = nil,
        powerModeDescription: String? = nil
    ) -> String {
        let tierDescription: String
        let focusGuidance: String

        switch tier {
        case .global:
            tierDescription = "This is global memory that applies across all conversations."
            focusGuidance = """
            Focus on information that is universally useful across all contexts:
            - User's general communication style and preferences
            - Commonly used vocabulary and jargon across domains
            - Important people, places, and companies frequently mentioned
            - General facts about the user's work and interests
            """

        case .context:
            tierDescription = "This is context-specific memory for the '\(contextName ?? "unknown")' context."
            let contextPurpose = contextDescription ?? "general use"
            focusGuidance = """
            This context is used for: \(contextPurpose)

            Focus specifically on information relevant to this context's purpose:
            - Vocabulary and terminology specific to this context
            - People and entities relevant to this context
            - Patterns and preferences when using this context
            - Facts and details that help with this specific use case
            """

        case .powerMode:
            tierDescription = "This is workflow memory for the '\(powerModeName ?? "unknown")' Power Mode."
            let powerModePurpose = powerModeDescription ?? "specialized workflow"
            focusGuidance = """
            This Power Mode is used for: \(powerModePurpose)

            Focus specifically on information that improves this workflow:
            - Workflow-specific vocabulary and terminology
            - Common patterns when using this Power Mode
            - Preferences and customizations for this workflow
            - Facts that help the AI provide better results for this specific task
            """
        }

        let hasExisting = existingMemory != nil && !(existingMemory?.isEmpty ?? true)

        return """
        You are a memory synthesis assistant for a voice dictation and text management app. \
        Your task is to create a concise, useful memory that helps the app provide better dictation \
        and voice command experiences for the user.

        \(tierDescription)

        \(hasExisting ? "You have existing memory that should be preserved and updated with new information." : "This is the first time creating memory for this tier.")

        \(focusGuidance)

        PRIORITY INFORMATION TO PRESERVE:
        - Personal names (people, places, companies the user mentions)
        - Vocabulary and jargon specific to the user's domain
        - How the user uses specific terms and phrases
        - User preferences and patterns
        - Facts about the user's work, projects, and interests
        - Action items and recurring tasks
        - Communication style preferences
        - Language-specific terms, names, and phrases in their original language/script

        MULTILINGUAL HANDLING:
        - Preserve text in its original language and script (e.g., Chinese 中文, Japanese 日本語, Arabic العربية, Korean 한국어)
        - Keep proper nouns, names, and technical terms in their original form
        - Note which languages the user commonly uses
        - Maintain any language-specific punctuation or formatting

        Instructions:
        1. Synthesize the existing memory (if any) with the new messages
        2. Preserve as much personal and contextual information as possible
        3. Remove truly redundant entries but keep variations of usage
        4. Prioritize recent information but don't discard older important facts
        5. Keep the memory under \(maxLength) characters
        6. Write in a factual, third-person style (e.g., "User works at...", "Frequently mentions...")
        7. Organize by category: Names, Vocabulary, Preferences, Facts, Tasks
        8. Keep non-English names and terms in their original script alongside any transliteration

        Output ONLY the synthesized memory. No explanations or meta-commentary.
        Use UTF-8 encoding. Preserve all original Unicode characters.
        """
    }
}

// MARK: - Memory Errors

extension MemoryUpdateScheduler {
    enum MemoryError: LocalizedError {
        case noProviderAvailable
        case generationFailed

        var errorDescription: String? {
            switch self {
            case .noProviderAvailable:
                return "No AI provider available for memory generation"
            case .generationFailed:
                return "Failed to generate memory"
            }
        }
    }
}
