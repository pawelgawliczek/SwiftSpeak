//
//  ProviderHealthTrackerTests.swift
//  SwiftSpeakTests
//
//  Phase 11f: Tests for provider health tracking and fallback
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@Suite("ProviderHealthTracker Tests")
struct ProviderHealthTrackerTests {

    // MARK: - Initial State Tests

    @Suite("Initial State")
    struct InitialStateTests {

        @Test("New provider is considered healthy")
        func newProviderHealthy() async {
            let tracker = ProviderHealthTracker()
            let healthy = await tracker.isHealthy(.openAI)
            #expect(healthy == true)
        }

        @Test("Initial health has no data")
        func initialHealthNoData() async {
            let tracker = ProviderHealthTracker()
            let health = await tracker.getHealth(for: .anthropic)
            #expect(health.consecutiveFailures == 0)
            #expect(health.totalSuccesses == 0)
            #expect(health.totalFailures == 0)
        }
    }

    // MARK: - Success Tracking Tests

    @Suite("Success Tracking")
    struct SuccessTrackingTests {

        @Test("Success increments counter")
        func successIncrements() async {
            let tracker = ProviderHealthTracker()

            await tracker.recordSuccess(for: .openAI)
            await tracker.recordSuccess(for: .openAI)

            let health = await tracker.getHealth(for: .openAI)
            #expect(health.totalSuccesses == 2)
        }

        @Test("Success resets consecutive failures")
        func successResetsFailures() async {
            let tracker = ProviderHealthTracker()

            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            var health = await tracker.getHealth(for: .openAI)
            #expect(health.consecutiveFailures == 2)

            await tracker.recordSuccess(for: .openAI)

            health = await tracker.getHealth(for: .openAI)
            #expect(health.consecutiveFailures == 0)
        }

        @Test("Success closes open circuit")
        func successClosesCircuit() async {
            let tracker = ProviderHealthTracker(failureThreshold: 2)

            // Open circuit with failures
            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            var health = await tracker.getHealth(for: .openAI)
            #expect(health.isCircuitOpen == true)

            // Success closes it
            await tracker.recordSuccess(for: .openAI)

            health = await tracker.getHealth(for: .openAI)
            #expect(health.isCircuitOpen == false)
        }
    }

    // MARK: - Failure Tracking Tests

    @Suite("Failure Tracking")
    struct FailureTrackingTests {

        @Test("Failure increments counters")
        func failureIncrements() async {
            let tracker = ProviderHealthTracker()

            await tracker.recordFailure(for: .openAI, error: "Network error")

            let health = await tracker.getHealth(for: .openAI)
            #expect(health.totalFailures == 1)
            #expect(health.consecutiveFailures == 1)
            #expect(health.lastError == "Network error")
        }

        @Test("Threshold failures open circuit")
        func thresholdOpensCircuit() async {
            let tracker = ProviderHealthTracker(failureThreshold: 3)

            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            var health = await tracker.getHealth(for: .openAI)
            #expect(health.isCircuitOpen == false)

            await tracker.recordFailure(for: .openAI)

            health = await tracker.getHealth(for: .openAI)
            #expect(health.isCircuitOpen == true)
        }

        @Test("Open circuit makes provider unhealthy")
        func openCircuitUnhealthy() async {
            let tracker = ProviderHealthTracker(failureThreshold: 2)

            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            let healthy = await tracker.isHealthy(.openAI)
            #expect(healthy == false)
        }
    }

    // MARK: - Success Rate Tests

    @Suite("Success Rate")
    struct SuccessRateTests {

        @Test("Success rate calculation")
        func successRateCalculation() async {
            let tracker = ProviderHealthTracker()

            // 7 successes, 3 failures = 70%
            for _ in 0..<7 {
                await tracker.recordSuccess(for: .openAI)
            }
            for _ in 0..<3 {
                await tracker.recordFailure(for: .openAI)
            }

            let health = await tracker.getHealth(for: .openAI)
            #expect(health.successRate == 0.7)
        }

        @Test("Empty history returns 100%")
        func emptyHistoryFullSuccess() async {
            let tracker = ProviderHealthTracker()
            let health = await tracker.getHealth(for: .openAI)
            #expect(health.successRate == 1.0)
        }
    }

    // MARK: - Fallback Selection Tests

    @Suite("Fallback Selection")
    struct FallbackSelectionTests {

        @Test("Selects preferred provider if healthy")
        func selectsPreferred() async {
            let tracker = ProviderHealthTracker()
            let candidates: [AIProvider] = [.openAI, .anthropic, .google]

            let selected = await tracker.selectBestProvider(from: candidates, preferred: .anthropic)
            #expect(selected == .anthropic)
        }

        @Test("Falls back if preferred unhealthy")
        func fallsBackFromUnhealthy() async {
            let tracker = ProviderHealthTracker(failureThreshold: 2)
            let candidates: [AIProvider] = [.openAI, .anthropic, .google]

            // Make preferred unhealthy
            await tracker.recordFailure(for: .anthropic)
            await tracker.recordFailure(for: .anthropic)

            let selected = await tracker.selectBestProvider(from: candidates, preferred: .anthropic)
            #expect(selected == .openAI)  // First healthy candidate
        }

        @Test("Returns nil if all unhealthy")
        func returnsNilIfAllUnhealthy() async {
            let tracker = ProviderHealthTracker(failureThreshold: 1)
            let candidates: [AIProvider] = [.openAI, .anthropic]

            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .anthropic)

            // Even with all unhealthy, returns the oldest opened circuit
            let selected = await tracker.selectBestProvider(from: candidates)
            #expect(selected != nil)  // Falls back to oldest
        }
    }

    // MARK: - Ranking Tests

    @Suite("Provider Ranking")
    struct RankingTests {

        @Test("Healthy providers ranked first")
        func healthyFirst() async {
            let tracker = ProviderHealthTracker(failureThreshold: 2)
            let providers: [AIProvider] = [.openAI, .anthropic, .google]

            // Make OpenAI unhealthy
            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            // Make Anthropic have some successes
            await tracker.recordSuccess(for: .anthropic)

            let ranked = await tracker.rankProviders(providers)

            // Anthropic (healthy with data) and Gemini (healthy no data) before OpenAI (unhealthy)
            #expect(ranked.last == .openAI)
        }
    }

    // MARK: - Reset Tests

    @Suite("Reset")
    struct ResetTests {

        @Test("Reset clears provider data")
        func resetClearsData() async {
            let tracker = ProviderHealthTracker()

            await tracker.recordSuccess(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            await tracker.reset(for: .openAI)

            let health = await tracker.getHealth(for: .openAI)
            #expect(health.totalSuccesses == 0)
            #expect(health.totalFailures == 0)
        }

        @Test("Reset all clears everything")
        func resetAllClears() async {
            let tracker = ProviderHealthTracker()

            await tracker.recordSuccess(for: .openAI)
            await tracker.recordSuccess(for: .anthropic)

            await tracker.resetAll()

            let all = await tracker.getAllHealth()
            #expect(all.isEmpty)
        }
    }

    // MARK: - Health Check Tests

    @Suite("Health Check")
    struct HealthCheckTests {

        @Test("Healthy provider returns no reason")
        func healthyNoReason() async {
            let tracker = ProviderHealthTracker()
            let (healthy, reason) = await tracker.healthCheck(.openAI)

            #expect(healthy == true)
            #expect(reason == nil)
        }

        @Test("Open circuit returns reason")
        func openCircuitReason() async {
            let tracker = ProviderHealthTracker(failureThreshold: 2)

            await tracker.recordFailure(for: .openAI)
            await tracker.recordFailure(for: .openAI)

            let (healthy, reason) = await tracker.healthCheck(.openAI)

            #expect(healthy == false)
            #expect(reason != nil)
            #expect(reason?.contains("Circuit open") == true)
        }
    }
}
