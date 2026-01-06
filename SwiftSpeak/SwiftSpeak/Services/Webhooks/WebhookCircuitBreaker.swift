//
//  WebhookCircuitBreaker.swift
//  SwiftSpeak
//
//  Phase 11g: Circuit breaker for webhook execution
//  Prevents slow/failing webhooks from blocking the main flow
//

import Foundation
import SwiftSpeakCore

/// Circuit breaker pattern for webhook execution
/// Automatically skips webhooks that are failing or timing out
actor WebhookCircuitBreaker {

    // MARK: - Types

    /// State of a webhook circuit
    enum CircuitState {
        case closed      // Normal operation
        case open        // Failing, skip requests
        case halfOpen    // Testing if recovered
    }

    /// Stats for a webhook
    struct WebhookStats: Codable {
        var failures: Int = 0
        var successes: Int = 0
        var lastFailure: Date?
        var lastSuccess: Date?
        var lastError: String?
        var averageLatency: TimeInterval = 0
        var state: String = "closed"  // Codable-friendly

        var circuitState: CircuitState {
            switch state {
            case "open": return .open
            case "halfOpen": return .halfOpen
            default: return .closed
            }
        }

        mutating func setCircuitState(_ newState: CircuitState) {
            switch newState {
            case .closed: state = "closed"
            case .open: state = "open"
            case .halfOpen: state = "halfOpen"
            }
        }
    }

    // MARK: - Configuration

    /// Number of failures before circuit opens
    private let failureThreshold: Int

    /// Time before circuit moves to half-open (seconds)
    private let resetTimeout: TimeInterval

    /// Maximum latency before considering slow (seconds)
    private let slowThreshold: TimeInterval

    /// Number of slow responses to count as failure
    private let slowToleranceCount: Int

    // MARK: - State

    /// Stats per webhook ID
    private var stats: [UUID: WebhookStats] = [:]

    /// When circuit was opened per webhook
    private var circuitOpenedAt: [UUID: Date] = [:]

    /// Count of consecutive slow responses
    private var slowCounts: [UUID: Int] = [:]

    // MARK: - Initialization

    init(
        failureThreshold: Int = 3,
        resetTimeout: TimeInterval = 300,   // 5 minutes
        slowThreshold: TimeInterval = 5.0,  // 5 seconds
        slowToleranceCount: Int = 3
    ) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
        self.slowThreshold = slowThreshold
        self.slowToleranceCount = slowToleranceCount
    }

    // MARK: - Circuit Breaker Logic

    /// Check if webhook should be executed
    /// - Parameter webhookId: The webhook UUID
    /// - Returns: True if webhook should be executed
    func shouldExecute(_ webhookId: UUID) -> Bool {
        guard var webhookStats = stats[webhookId] else {
            return true  // No stats = allow execution
        }

        switch webhookStats.circuitState {
        case .closed:
            return true

        case .open:
            // Check if reset timeout has passed
            if let openedAt = circuitOpenedAt[webhookId],
               Date().timeIntervalSince(openedAt) >= resetTimeout {
                // Move to half-open state
                webhookStats.setCircuitState(.halfOpen)
                stats[webhookId] = webhookStats
                return true
            }
            return false

        case .halfOpen:
            // Allow one test request
            return true
        }
    }

    /// Record a successful webhook execution
    /// - Parameters:
    ///   - webhookId: The webhook UUID
    ///   - latency: Execution time in seconds
    func recordSuccess(_ webhookId: UUID, latency: TimeInterval) {
        var webhookStats = stats[webhookId] ?? WebhookStats()

        webhookStats.successes += 1
        webhookStats.lastSuccess = Date()
        webhookStats.failures = 0  // Reset consecutive failures

        // Update average latency
        let totalCalls = webhookStats.successes + webhookStats.failures
        if totalCalls > 0 {
            webhookStats.averageLatency = (webhookStats.averageLatency * Double(totalCalls - 1) + latency) / Double(totalCalls)
        }

        // Check for slow response
        if latency > slowThreshold {
            slowCounts[webhookId, default: 0] += 1
            if slowCounts[webhookId, default: 0] >= slowToleranceCount {
                // Too many slow responses, open circuit
                webhookStats.setCircuitState(.open)
                circuitOpenedAt[webhookId] = Date()
                webhookStats.lastError = "Too slow (\(Int(latency))s)"
            }
        } else {
            slowCounts[webhookId] = 0
        }

        // If was half-open, success means close circuit
        if webhookStats.circuitState == .halfOpen {
            webhookStats.setCircuitState(.closed)
            circuitOpenedAt.removeValue(forKey: webhookId)
            slowCounts[webhookId] = 0
        }

        stats[webhookId] = webhookStats
    }

    /// Record a failed webhook execution
    /// - Parameters:
    ///   - webhookId: The webhook UUID
    ///   - error: Error description
    func recordFailure(_ webhookId: UUID, error: String? = nil) {
        var webhookStats = stats[webhookId] ?? WebhookStats()

        webhookStats.failures += 1
        webhookStats.lastFailure = Date()
        webhookStats.lastError = error

        // If half-open, failure means back to open
        if webhookStats.circuitState == .halfOpen {
            webhookStats.setCircuitState(.open)
            circuitOpenedAt[webhookId] = Date()
        }
        // If closed and threshold reached, open circuit
        else if webhookStats.failures >= failureThreshold {
            webhookStats.setCircuitState(.open)
            circuitOpenedAt[webhookId] = Date()
        }

        stats[webhookId] = webhookStats
    }

    /// Record a timeout (treated as failure)
    func recordTimeout(_ webhookId: UUID) {
        recordFailure(webhookId, error: "Timeout")
    }

    // MARK: - Query Methods

    /// Get current state for a webhook
    func getState(_ webhookId: UUID) -> CircuitState {
        stats[webhookId]?.circuitState ?? .closed
    }

    /// Get stats for a webhook
    func getStats(_ webhookId: UUID) -> WebhookStats {
        stats[webhookId] ?? WebhookStats()
    }

    /// Get all webhook stats
    func getAllStats() -> [UUID: WebhookStats] {
        stats
    }

    /// Check if any webhooks are in open state
    func hasOpenCircuits() -> Bool {
        stats.values.contains { $0.circuitState == .open }
    }

    /// Get list of open circuit webhook IDs
    func openCircuitIds() -> [UUID] {
        stats.filter { $0.value.circuitState == .open }.map { $0.key }
    }

    // MARK: - Management

    /// Reset a specific webhook's circuit
    func reset(_ webhookId: UUID) {
        stats.removeValue(forKey: webhookId)
        circuitOpenedAt.removeValue(forKey: webhookId)
        slowCounts.removeValue(forKey: webhookId)
    }

    /// Reset all circuits
    func resetAll() {
        stats.removeAll()
        circuitOpenedAt.removeAll()
        slowCounts.removeAll()
    }

    /// Force close a circuit (allow execution)
    func forceClose(_ webhookId: UUID) {
        if var webhookStats = stats[webhookId] {
            webhookStats.setCircuitState(.closed)
            webhookStats.failures = 0
            stats[webhookId] = webhookStats
            circuitOpenedAt.removeValue(forKey: webhookId)
            slowCounts.removeValue(forKey: webhookId)
        }
    }

    /// Force open a circuit (block execution)
    func forceOpen(_ webhookId: UUID) {
        var webhookStats = stats[webhookId] ?? WebhookStats()
        webhookStats.setCircuitState(.open)
        stats[webhookId] = webhookStats
        circuitOpenedAt[webhookId] = Date()
    }
}

// MARK: - Parallel Execution Helper

extension WebhookCircuitBreaker {
    /// Execute webhooks in parallel with circuit breaker protection
    /// - Parameters:
    ///   - webhooks: List of webhooks to execute
    ///   - timeout: Maximum time per webhook
    ///   - execute: Async closure to execute each webhook
    /// - Returns: Results for each webhook
    func executeParallel<T>(
        webhooks: [(id: UUID, webhook: T)],
        timeout: TimeInterval,
        execute: @escaping (T) async throws -> Void
    ) async -> [(id: UUID, success: Bool, error: String?)] {
        await withTaskGroup(of: (UUID, Bool, String?).self) { group in
            for (id, webhook) in webhooks {
                // Skip if circuit is open
                guard shouldExecute(id) else {
                    continue
                }

                group.addTask {
                    let start = Date()

                    do {
                        // Execute with timeout
                        try await withThrowingTaskGroup(of: Void.self) { inner in
                            inner.addTask {
                                try await execute(webhook)
                            }

                            inner.addTask {
                                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                                throw WebhookError.timeout
                            }

                            // Wait for first to complete
                            try await inner.next()
                            inner.cancelAll()
                        }

                        let latency = Date().timeIntervalSince(start)
                        await self.recordSuccess(id, latency: latency)
                        return (id, true, nil)

                    } catch is CancellationError {
                        return (id, false, "Cancelled")
                    } catch WebhookError.timeout {
                        await self.recordTimeout(id)
                        return (id, false, "Timeout")
                    } catch {
                        await self.recordFailure(id, error: error.localizedDescription)
                        return (id, false, error.localizedDescription)
                    }
                }
            }

            var results: [(id: UUID, success: Bool, error: String?)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}

// MARK: - Webhook Error

enum WebhookError: LocalizedError {
    case timeout
    case circuitOpen
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .timeout: return "Webhook timed out"
        case .circuitOpen: return "Webhook circuit is open"
        case .invalidResponse: return "Invalid webhook response"
        }
    }
}

// MARK: - Shared Instance

extension WebhookCircuitBreaker {
    /// Shared instance for app-wide webhook tracking
    static let shared = WebhookCircuitBreaker()
}
