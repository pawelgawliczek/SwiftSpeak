//
//  WebhookCircuitBreakerTests.swift
//  SwiftSpeakTests
//
//  Phase 11g: Tests for webhook circuit breaker
//

import Testing
import Foundation
@testable import SwiftSpeak

@Suite("WebhookCircuitBreaker Tests")
struct WebhookCircuitBreakerTests {

    // MARK: - Initial State Tests

    @Suite("Initial State")
    struct InitialStateTests {

        @Test("New webhook is allowed")
        func newWebhookAllowed() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            let shouldExecute = await breaker.shouldExecute(webhookId)
            #expect(shouldExecute == true)
        }

        @Test("Initial state is closed")
        func initialStateClosed() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            let state = await breaker.getState(webhookId)
            #expect(state == .closed)
        }

        @Test("Initial stats are empty")
        func initialStatsEmpty() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            let stats = await breaker.getStats(webhookId)
            #expect(stats.successes == 0)
            #expect(stats.failures == 0)
        }
    }

    // MARK: - Success Recording Tests

    @Suite("Success Recording")
    struct SuccessRecordingTests {

        @Test("Success increments counter")
        func successIncrements() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            await breaker.recordSuccess(webhookId, latency: 0.5)
            await breaker.recordSuccess(webhookId, latency: 0.3)

            let stats = await breaker.getStats(webhookId)
            #expect(stats.successes == 2)
        }

        @Test("Success resets failure count")
        func successResetsFailures() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            var stats = await breaker.getStats(webhookId)
            #expect(stats.failures == 2)

            await breaker.recordSuccess(webhookId, latency: 0.5)

            stats = await breaker.getStats(webhookId)
            #expect(stats.failures == 0)
        }

        @Test("Average latency is calculated")
        func averageLatency() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            await breaker.recordSuccess(webhookId, latency: 1.0)
            await breaker.recordSuccess(webhookId, latency: 3.0)

            let stats = await breaker.getStats(webhookId)
            // Average of 1.0 and 3.0 should be around 2.0
            #expect(stats.averageLatency > 1.5)
            #expect(stats.averageLatency < 2.5)
        }
    }

    // MARK: - Failure Recording Tests

    @Suite("Failure Recording")
    struct FailureRecordingTests {

        @Test("Failure increments counter")
        func failureIncrements() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            await breaker.recordFailure(webhookId, error: "Network error")

            let stats = await breaker.getStats(webhookId)
            #expect(stats.failures == 1)
            #expect(stats.lastError == "Network error")
        }

        @Test("Threshold failures open circuit")
        func thresholdOpensCircuit() async {
            let breaker = WebhookCircuitBreaker(failureThreshold: 3)
            let webhookId = UUID()

            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            var state = await breaker.getState(webhookId)
            #expect(state == .closed)

            await breaker.recordFailure(webhookId)

            state = await breaker.getState(webhookId)
            #expect(state == .open)
        }

        @Test("Open circuit blocks execution")
        func openCircuitBlocks() async {
            let breaker = WebhookCircuitBreaker(failureThreshold: 2)
            let webhookId = UUID()

            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            let shouldExecute = await breaker.shouldExecute(webhookId)
            #expect(shouldExecute == false)
        }
    }

    // MARK: - Timeout Tests

    @Suite("Timeout")
    struct TimeoutTests {

        @Test("Timeout is recorded as failure")
        func timeoutAsFailure() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            await breaker.recordTimeout(webhookId)

            let stats = await breaker.getStats(webhookId)
            #expect(stats.failures == 1)
            #expect(stats.lastError == "Timeout")
        }
    }

    // MARK: - Slow Response Tests

    @Suite("Slow Response")
    struct SlowResponseTests {

        @Test("Slow responses trigger circuit open")
        func slowOpensCircuit() async {
            let breaker = WebhookCircuitBreaker(
                failureThreshold: 10,  // High so failures alone won't open
                slowThreshold: 1.0,    // 1 second is slow
                slowToleranceCount: 2  // 2 slow responses opens circuit
            )
            let webhookId = UUID()

            await breaker.recordSuccess(webhookId, latency: 2.0)  // Slow
            await breaker.recordSuccess(webhookId, latency: 3.0)  // Slow again

            let state = await breaker.getState(webhookId)
            #expect(state == .open)
        }

        @Test("Fast response after slow resets counter")
        func fastResetsSlowCount() async {
            let breaker = WebhookCircuitBreaker(
                slowThreshold: 1.0,
                slowToleranceCount: 3
            )
            let webhookId = UUID()

            await breaker.recordSuccess(webhookId, latency: 2.0)  // Slow
            await breaker.recordSuccess(webhookId, latency: 0.1)  // Fast - resets

            // Now 2 more slow responses shouldn't open circuit
            await breaker.recordSuccess(webhookId, latency: 2.0)  // Slow
            await breaker.recordSuccess(webhookId, latency: 2.0)  // Slow

            let state = await breaker.getState(webhookId)
            #expect(state == .closed)
        }
    }

    // MARK: - Circuit State Tests

    @Suite("Circuit States")
    struct CircuitStateTests {

        @Test("Half-open allows test request")
        func halfOpenAllowsTest() async {
            let breaker = WebhookCircuitBreaker(
                failureThreshold: 2,
                resetTimeout: 0.1  // Very short for testing
            )
            let webhookId = UUID()

            // Open circuit
            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            // Wait for half-open
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

            let shouldExecute = await breaker.shouldExecute(webhookId)
            #expect(shouldExecute == true)

            let state = await breaker.getState(webhookId)
            #expect(state == .halfOpen)
        }

        @Test("Success in half-open closes circuit")
        func halfOpenSuccessCloses() async {
            let breaker = WebhookCircuitBreaker(
                failureThreshold: 2,
                resetTimeout: 0.1
            )
            let webhookId = UUID()

            // Open circuit
            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            // Wait for half-open
            try? await Task.sleep(nanoseconds: 100_000_000)

            // Trigger half-open state
            _ = await breaker.shouldExecute(webhookId)

            // Success should close
            await breaker.recordSuccess(webhookId, latency: 0.1)

            let state = await breaker.getState(webhookId)
            #expect(state == .closed)
        }

        @Test("Failure in half-open reopens circuit")
        func halfOpenFailureReopens() async {
            let breaker = WebhookCircuitBreaker(
                failureThreshold: 2,
                resetTimeout: 0.1
            )
            let webhookId = UUID()

            // Open circuit
            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            // Wait for half-open
            try? await Task.sleep(nanoseconds: 100_000_000)

            // Trigger half-open state
            _ = await breaker.shouldExecute(webhookId)

            // Failure should reopen
            await breaker.recordFailure(webhookId)

            let state = await breaker.getState(webhookId)
            #expect(state == .open)
        }
    }

    // MARK: - Force Controls Tests

    @Suite("Force Controls")
    struct ForceControlsTests {

        @Test("Force close allows execution")
        func forceCloseAllows() async {
            let breaker = WebhookCircuitBreaker(failureThreshold: 2)
            let webhookId = UUID()

            // Open circuit
            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            // Force close
            await breaker.forceClose(webhookId)

            let shouldExecute = await breaker.shouldExecute(webhookId)
            #expect(shouldExecute == true)
        }

        @Test("Force open blocks execution")
        func forceOpenBlocks() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            // Force open
            await breaker.forceOpen(webhookId)

            let shouldExecute = await breaker.shouldExecute(webhookId)
            #expect(shouldExecute == false)
        }
    }

    // MARK: - Reset Tests

    @Suite("Reset")
    struct ResetTests {

        @Test("Reset clears webhook data")
        func resetClears() async {
            let breaker = WebhookCircuitBreaker()
            let webhookId = UUID()

            await breaker.recordSuccess(webhookId, latency: 0.5)
            await breaker.recordFailure(webhookId)

            await breaker.reset(webhookId)

            let stats = await breaker.getStats(webhookId)
            #expect(stats.successes == 0)
            #expect(stats.failures == 0)
        }

        @Test("Reset all clears everything")
        func resetAllClears() async {
            let breaker = WebhookCircuitBreaker()
            let id1 = UUID()
            let id2 = UUID()

            await breaker.recordSuccess(id1, latency: 0.5)
            await breaker.recordSuccess(id2, latency: 0.5)

            await breaker.resetAll()

            let all = await breaker.getAllStats()
            #expect(all.isEmpty)
        }
    }

    // MARK: - Query Tests

    @Suite("Queries")
    struct QueryTests {

        @Test("Has open circuits detection")
        func hasOpenCircuits() async {
            let breaker = WebhookCircuitBreaker(failureThreshold: 2)
            let webhookId = UUID()

            var hasOpen = await breaker.hasOpenCircuits()
            #expect(hasOpen == false)

            await breaker.recordFailure(webhookId)
            await breaker.recordFailure(webhookId)

            hasOpen = await breaker.hasOpenCircuits()
            #expect(hasOpen == true)
        }

        @Test("Open circuit IDs list")
        func openCircuitIds() async {
            let breaker = WebhookCircuitBreaker(failureThreshold: 2)
            let id1 = UUID()
            let id2 = UUID()

            await breaker.recordFailure(id1)
            await breaker.recordFailure(id1)

            let openIds = await breaker.openCircuitIds()
            #expect(openIds.contains(id1))
            #expect(!openIds.contains(id2))
        }
    }
}
