//
//  MemoryManager.swift
//  SwiftSpeak
//
//  Phase 4b: Three-tier memory system management.
//  Handles memory updates, compression, and LLM-based summarization.
//

import Combine
import Foundation

/// Memory tier for targeting specific memory stores
enum MemoryTierTarget {
    case global
    case context(UUID)
    case powerMode(UUID)
}

/// Result of a memory update operation
struct MemoryUpdateResult {
    let tier: MemoryTierTarget
    let previousLength: Int
    let newLength: Int
    let wasCompressed: Bool
    let success: Bool
    let error: Error?
}

/// Manages the three-tier memory system
/// - Global memory: Always active, updated after every conversation
/// - Context memory: Per-context, updated when context is active
/// - Power Mode memory: Per-workflow, updated after Power Mode executions
@MainActor
final class MemoryManager: ObservableObject {

    // MARK: - Configuration

    /// Maximum memory length before compression is triggered
    static let compressionThreshold = 2000

    /// Target length after compression
    static let compressionTarget = 1500

    /// Maximum memory entries to keep before summarization
    static let maxRecentEntries = 10

    // MARK: - Dependencies

    private let settings: SharedSettings
    private let providerFactory: ProviderFactory

    // MARK: - State

    /// Whether a memory operation is in progress
    @Published private(set) var isUpdating = false

    /// Last error if any
    @Published private(set) var lastError: Error?

    // MARK: - Initialization

    init(settings: SharedSettings? = nil, providerFactory: ProviderFactory? = nil) {
        let resolvedSettings = settings ?? SharedSettings.shared
        self.settings = resolvedSettings
        self.providerFactory = providerFactory ?? ProviderFactory(settings: resolvedSettings)
    }

    // MARK: - Memory Update

    /// Update memory after a conversation completes
    /// - Parameters:
    ///   - transcription: The transcribed/formatted text from the conversation
    ///   - context: Active conversation context (if any)
    ///   - powerMode: Active power mode (if in Power Mode)
    /// - Returns: Results for each tier that was updated
    func updateMemory(
        from transcription: String,
        context: ConversationContext?,
        powerMode: PowerMode?
    ) async -> [MemoryUpdateResult] {
        guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        isUpdating = true
        lastError = nil
        defer { isUpdating = false }

        var results: [MemoryUpdateResult] = []

        // Generate summary of the conversation
        let summary = await generateSummary(from: transcription)

        // 1. Always update global memory (if enabled)
        if settings.globalMemoryEnabled {
            let result = await updateGlobalMemory(with: summary)
            results.append(result)
        }

        // 2. Update context memory (if context is active and memory enabled)
        if let ctx = context, ctx.memoryEnabled {
            let result = await updateContextMemory(contextId: ctx.id, with: summary)
            results.append(result)
        }

        // 3. Update power mode memory (if in power mode and memory enabled)
        if let pm = powerMode, pm.memoryEnabled {
            let result = await updatePowerModeMemory(powerModeId: pm.id, with: summary)
            results.append(result)
        }

        return results
    }

    // MARK: - Global Memory

    /// Update global memory with new summary
    private func updateGlobalMemory(with summary: String) async -> MemoryUpdateResult {
        let previousMemory = settings.globalMemory ?? ""
        let previousLength = previousMemory.count

        do {
            // Combine existing memory with new summary
            let combined = combineMemory(existing: previousMemory, new: summary)

            // Check if compression is needed
            var finalMemory = combined
            var wasCompressed = false

            if combined.count > Self.compressionThreshold {
                finalMemory = try await compressMemory(combined)
                wasCompressed = true
            }

            // Save updated memory
            settings.globalMemory = finalMemory

            return MemoryUpdateResult(
                tier: .global,
                previousLength: previousLength,
                newLength: finalMemory.count,
                wasCompressed: wasCompressed,
                success: true,
                error: nil
            )
        } catch {
            lastError = error
            return MemoryUpdateResult(
                tier: .global,
                previousLength: previousLength,
                newLength: previousLength,
                wasCompressed: false,
                success: false,
                error: error
            )
        }
    }

    // MARK: - Context Memory

    /// Update context-specific memory
    private func updateContextMemory(contextId: UUID, with summary: String) async -> MemoryUpdateResult {
        guard var context = settings.contexts.first(where: { $0.id == contextId }) else {
            return MemoryUpdateResult(
                tier: .context(contextId),
                previousLength: 0,
                newLength: 0,
                wasCompressed: false,
                success: false,
                error: MemoryError.contextNotFound
            )
        }

        let previousMemory = context.memory ?? ""
        let previousLength = previousMemory.count

        do {
            // Combine existing memory with new summary
            let combined = combineMemory(existing: previousMemory, new: summary)

            // Check if compression is needed
            var finalMemory = combined
            var wasCompressed = false

            if combined.count > Self.compressionThreshold {
                finalMemory = try await compressMemory(combined)
                wasCompressed = true
            }

            // Update context
            context.memory = finalMemory
            context.lastMemoryUpdate = Date()
            context.updatedAt = Date()
            settings.updateContext(context)

            return MemoryUpdateResult(
                tier: .context(contextId),
                previousLength: previousLength,
                newLength: finalMemory.count,
                wasCompressed: wasCompressed,
                success: true,
                error: nil
            )
        } catch {
            lastError = error
            return MemoryUpdateResult(
                tier: .context(contextId),
                previousLength: previousLength,
                newLength: previousLength,
                wasCompressed: false,
                success: false,
                error: error
            )
        }
    }

    // MARK: - Power Mode Memory

    /// Update power mode workflow memory
    private func updatePowerModeMemory(powerModeId: UUID, with summary: String) async -> MemoryUpdateResult {
        guard var powerMode = settings.powerModes.first(where: { $0.id == powerModeId }) else {
            return MemoryUpdateResult(
                tier: .powerMode(powerModeId),
                previousLength: 0,
                newLength: 0,
                wasCompressed: false,
                success: false,
                error: MemoryError.powerModeNotFound
            )
        }

        let previousMemory = powerMode.memory ?? ""
        let previousLength = previousMemory.count

        do {
            // Combine existing memory with new summary
            let combined = combineMemory(existing: previousMemory, new: summary)

            // Check if compression is needed
            var finalMemory = combined
            var wasCompressed = false

            if combined.count > Self.compressionThreshold {
                finalMemory = try await compressMemory(combined)
                wasCompressed = true
            }

            // Update power mode
            powerMode.memory = finalMemory
            powerMode.lastMemoryUpdate = Date()
            settings.updatePowerMode(powerMode)

            return MemoryUpdateResult(
                tier: .powerMode(powerModeId),
                previousLength: previousLength,
                newLength: finalMemory.count,
                wasCompressed: wasCompressed,
                success: true,
                error: nil
            )
        } catch {
            lastError = error
            return MemoryUpdateResult(
                tier: .powerMode(powerModeId),
                previousLength: previousLength,
                newLength: previousLength,
                wasCompressed: false,
                success: false,
                error: error
            )
        }
    }

    // MARK: - Clear Memory

    /// Clear memory for a specific tier
    func clearMemory(tier: MemoryTierTarget) {
        switch tier {
        case .global:
            settings.globalMemory = nil

        case .context(let id):
            if var context = settings.contexts.first(where: { $0.id == id }) {
                context.memory = nil
                context.lastMemoryUpdate = nil
                context.updatedAt = Date()
                settings.updateContext(context)
            }

        case .powerMode(let id):
            if var powerMode = settings.powerModes.first(where: { $0.id == id }) {
                powerMode.memory = nil
                powerMode.lastMemoryUpdate = nil
                settings.updatePowerMode(powerMode)
            }
        }
    }

    // MARK: - Memory Helpers

    /// Combine existing memory with new summary
    private func combineMemory(existing: String, new: String) -> String {
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = new.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedExisting.isEmpty {
            return trimmedNew
        }

        if trimmedNew.isEmpty {
            return trimmedExisting
        }

        // Add timestamp for the new entry
        let timestamp = Self.formatDate(Date())
        return "\(trimmedExisting)\n\n[\(timestamp)] \(trimmedNew)"
    }

    /// Format date for memory entries
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - LLM Operations

    /// Generate a concise summary from transcription text
    private func generateSummary(from text: String) async -> String {
        // If text is already short, use it directly
        if text.count < 200 {
            return text
        }

        // Try to use LLM for summarization
        guard let provider = providerFactory.createSelectedFormattingProvider() else {
            // Fallback: truncate to first 200 chars
            return String(text.prefix(200)) + "..."
        }

        let prompt = """
        Summarize the following conversation in 1-2 concise sentences for future context.
        Focus on key facts, decisions, or action items mentioned.
        Keep the summary under 150 characters.
        Output only the summary, nothing else.
        """

        do {
            let summary = try await provider.format(
                text: text,
                mode: .raw,
                customPrompt: prompt,
                context: nil
            )
            return summary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // Fallback: truncate
            return String(text.prefix(200)) + "..."
        }
    }

    /// Compress memory when it exceeds the threshold
    private func compressMemory(_ memory: String) async throws -> String {
        guard let provider = providerFactory.createSelectedFormattingProvider() else {
            throw MemoryError.noProviderAvailable
        }

        let prompt = """
        Compress the following memory log to under \(Self.compressionTarget) characters.
        Preserve the most important and recent information.
        Merge redundant entries and remove outdated details.
        Maintain chronological context where relevant.
        Output only the compressed memory, nothing else.
        """

        let compressed = try await provider.format(
            text: memory,
            mode: .raw,
            customPrompt: prompt,
            context: nil
        )

        let result = compressed.trimmingCharacters(in: .whitespacesAndNewlines)

        // Verify compression worked
        if result.count > Self.compressionThreshold {
            // Hard truncate if LLM didn't compress enough
            return String(result.prefix(Self.compressionTarget))
        }

        return result
    }
}

// MARK: - Memory Errors

enum MemoryError: LocalizedError {
    case contextNotFound
    case powerModeNotFound
    case noProviderAvailable
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .contextNotFound:
            return "Context not found"
        case .powerModeNotFound:
            return "Power Mode not found"
        case .noProviderAvailable:
            return "No AI provider available for memory operations"
        case .compressionFailed:
            return "Failed to compress memory"
        }
    }
}

// MARK: - Convenience Extensions

extension MemoryManager {
    /// Get the current memory for a tier
    func getMemory(for tier: MemoryTierTarget) -> String? {
        switch tier {
        case .global:
            return settings.globalMemory

        case .context(let id):
            return settings.contexts.first(where: { $0.id == id })?.memory

        case .powerMode(let id):
            return settings.powerModes.first(where: { $0.id == id })?.memory
        }
    }

    /// Check if memory is enabled for a tier
    func isMemoryEnabled(for tier: MemoryTierTarget) -> Bool {
        switch tier {
        case .global:
            return settings.globalMemoryEnabled

        case .context(let id):
            return settings.contexts.first(where: { $0.id == id })?.memoryEnabled ?? false

        case .powerMode(let id):
            return settings.powerModes.first(where: { $0.id == id })?.memoryEnabled ?? false
        }
    }

    /// Get memory stats for display
    func getMemoryStats(for tier: MemoryTierTarget) -> (length: Int, lastUpdate: Date?) {
        switch tier {
        case .global:
            return (settings.globalMemory?.count ?? 0, nil)

        case .context(let id):
            if let ctx = settings.contexts.first(where: { $0.id == id }) {
                return (ctx.memory?.count ?? 0, ctx.lastMemoryUpdate)
            }
            return (0, nil)

        case .powerMode(let id):
            if let pm = settings.powerModes.first(where: { $0.id == id }) {
                return (pm.memory?.count ?? 0, pm.lastMemoryUpdate)
            }
            return (0, nil)
        }
    }
}
