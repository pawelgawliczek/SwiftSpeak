//
//  ProviderHealthTracker.swift
//  SwiftSpeak
//
//  Phase 11f: Track provider health for automatic failover
//

import Foundation

/// Tracks the health status of AI providers for automatic fallback
public actor ProviderHealthTracker {

    // MARK: - Types

    /// Health status of a provider
    public struct ProviderHealth: Codable {
        var consecutiveFailures: Int = 0
        var totalFailures: Int = 0
        var totalSuccesses: Int = 0
        var lastFailure: Date?
        var lastSuccess: Date?
        var lastError: String?
        var isCircuitOpen: Bool = false
        var circuitOpenedAt: Date?

        /// Success rate (0-1)
        var successRate: Double {
            let total = totalFailures + totalSuccesses
            guard total > 0 else { return 1.0 }  // Assume healthy if no data
            return Double(totalSuccesses) / Double(total)
        }

        /// Whether provider is currently healthy
        var isHealthy: Bool {
            !isCircuitOpen && consecutiveFailures < 3
        }
    }

    // MARK: - Configuration

    /// Number of consecutive failures before circuit opens
    private let failureThreshold: Int

    /// Time before closed circuit resets (seconds)
    private let cooldownPeriod: TimeInterval

    /// Time before half-open state allows test request
    private let halfOpenDelay: TimeInterval

    // MARK: - State

    /// Health status per provider
    private var healthStatus: [AIProvider: ProviderHealth] = [:]

    /// Providers currently in half-open state (testing)
    private var halfOpenProviders: Set<AIProvider> = []

    // MARK: - Initialization

    public init(
        failureThreshold: Int = 3,
        cooldownPeriod: TimeInterval = 300,  // 5 minutes
        halfOpenDelay: TimeInterval = 60     // 1 minute
    ) {
        self.failureThreshold = failureThreshold
        self.cooldownPeriod = cooldownPeriod
        self.halfOpenDelay = halfOpenDelay
    }

    // MARK: - Health Tracking

    /// Record a successful request
    public func recordSuccess(for provider: AIProvider) {
        var health = healthStatus[provider] ?? ProviderHealth()

        health.consecutiveFailures = 0
        health.totalSuccesses += 1
        health.lastSuccess = Date()

        // If was in circuit open state, close it
        if health.isCircuitOpen {
            health.isCircuitOpen = false
            health.circuitOpenedAt = nil
        }

        halfOpenProviders.remove(provider)
        healthStatus[provider] = health
    }

    /// Record a failed request
    public func recordFailure(for provider: AIProvider, error: String? = nil) {
        var health = healthStatus[provider] ?? ProviderHealth()

        health.consecutiveFailures += 1
        health.totalFailures += 1
        health.lastFailure = Date()
        health.lastError = error

        // Open circuit if threshold reached
        if health.consecutiveFailures >= failureThreshold && !health.isCircuitOpen {
            health.isCircuitOpen = true
            health.circuitOpenedAt = Date()
        }

        halfOpenProviders.remove(provider)
        healthStatus[provider] = health
    }

    /// Check if a provider is currently healthy
    public func isHealthy(_ provider: AIProvider) -> Bool {
        guard let health = healthStatus[provider] else {
            return true  // Assume healthy if no data
        }

        // If circuit is closed, provider is healthy
        if !health.isCircuitOpen {
            return health.consecutiveFailures < failureThreshold
        }

        // If circuit is open, check if cooldown has passed
        if let openedAt = health.circuitOpenedAt {
            let timeSinceOpen = Date().timeIntervalSince(openedAt)

            // Allow half-open test after halfOpenDelay
            if timeSinceOpen >= halfOpenDelay && !halfOpenProviders.contains(provider) {
                halfOpenProviders.insert(provider)
                return true  // Allow one test request
            }

            // Full reset after cooldown
            if timeSinceOpen >= cooldownPeriod {
                var updatedHealth = health
                updatedHealth.isCircuitOpen = false
                updatedHealth.circuitOpenedAt = nil
                updatedHealth.consecutiveFailures = 0
                healthStatus[provider] = updatedHealth
                return true
            }
        }

        return false
    }

    /// Get health status for a provider
    public func getHealth(for provider: AIProvider) -> ProviderHealth {
        healthStatus[provider] ?? ProviderHealth()
    }

    /// Get all provider health statuses
    public func getAllHealth() -> [AIProvider: ProviderHealth] {
        healthStatus
    }

    /// Reset health tracking for a provider
    public func reset(for provider: AIProvider) {
        healthStatus.removeValue(forKey: provider)
        halfOpenProviders.remove(provider)
    }

    /// Reset all health tracking
    public func resetAll() {
        healthStatus.removeAll()
        halfOpenProviders.removeAll()
    }

    // MARK: - Fallback Selection

    /// Select the best available provider from candidates
    /// - Parameters:
    ///   - candidates: List of potential providers in priority order
    ///   - preferred: The user's preferred provider
    /// - Returns: Best available provider, or nil if all unhealthy
    public func selectBestProvider(
        from candidates: [AIProvider],
        preferred: AIProvider? = nil
    ) -> AIProvider? {
        // First, try the preferred provider if healthy
        if let preferred = preferred, candidates.contains(preferred), isHealthy(preferred) {
            return preferred
        }

        // Otherwise, find the first healthy candidate
        for candidate in candidates {
            if isHealthy(candidate) {
                return candidate
            }
        }

        // All unhealthy - return the one with oldest circuit open time
        // (most likely to have recovered)
        return candidates.min { a, b in
            let healthA = healthStatus[a]
            let healthB = healthStatus[b]

            let timeA = healthA?.circuitOpenedAt ?? .distantPast
            let timeB = healthB?.circuitOpenedAt ?? .distantPast

            return timeA < timeB
        }
    }

    /// Get a sorted list of providers by health
    public func rankProviders(_ providers: [AIProvider]) -> [AIProvider] {
        providers.sorted { a, b in
            let healthA = healthStatus[a] ?? ProviderHealth()
            let healthB = healthStatus[b] ?? ProviderHealth()

            // Healthy providers first
            if healthA.isHealthy != healthB.isHealthy {
                return healthA.isHealthy
            }

            // Then by success rate
            if healthA.successRate != healthB.successRate {
                return healthA.successRate > healthB.successRate
            }

            // Then by recency of last success
            let lastA = healthA.lastSuccess ?? .distantPast
            let lastB = healthB.lastSuccess ?? .distantPast
            return lastA > lastB
        }
    }
}

// MARK: - Convenience Extensions

public extension ProviderHealthTracker {
    /// Check health and return reason if unhealthy
    public func healthCheck(_ provider: AIProvider) -> (healthy: Bool, reason: String?) {
        let health = getHealth(for: provider)

        if health.isCircuitOpen {
            if let openedAt = health.circuitOpenedAt {
                let remaining = max(0, cooldownPeriod - Date().timeIntervalSince(openedAt))
                return (false, "Circuit open, \(Int(remaining))s until retry")
            }
            return (false, "Circuit open")
        }

        if health.consecutiveFailures >= failureThreshold {
            return (false, "\(health.consecutiveFailures) consecutive failures")
        }

        if health.successRate < 0.5 && (health.totalFailures + health.totalSuccesses) >= 10 {
            return (false, "Low success rate (\(Int(health.successRate * 100))%)")
        }

        return (true, nil)
    }

    /// Get a summary of all provider health
    public func healthSummary() -> String {
        var lines: [String] = []

        for (provider, health) in healthStatus {
            let status = health.isHealthy ? "✓" : "✗"
            let rate = Int(health.successRate * 100)
            lines.append("\(status) \(provider.displayName): \(rate)% success")
        }

        return lines.isEmpty ? "No health data" : lines.joined(separator: "\n")
    }
}

// MARK: - Shared Instance

public extension ProviderHealthTracker {
    /// Shared instance for app-wide health tracking
    public static let shared = ProviderHealthTracker()
}
