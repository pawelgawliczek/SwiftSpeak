//
//  RetryPolicyTests.swift
//  SwiftSpeakTests
//
//  Phase 11e: Tests for retry logic and exponential backoff
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

@Suite("RetryPolicy Tests")
struct RetryPolicyTests {

    // MARK: - Configuration Tests

    @Suite("Configuration")
    struct ConfigurationTests {

        @Test("Default policy has sensible values")
        func defaultPolicy() {
            let policy = RetryPolicy.default
            #expect(policy.maxAttempts == 3)
            #expect(policy.initialDelay == 1.0)
            #expect(policy.backoffMultiplier == 2.0)
            #expect(policy.maxDelay == 16.0)
        }

        @Test("Custom policy accepts values")
        func customPolicy() {
            let policy = RetryPolicy(
                maxAttempts: 5,
                initialDelay: 0.5,
                backoffMultiplier: 3.0,
                maxDelay: 30.0
            )
            #expect(policy.maxAttempts == 5)
            #expect(policy.initialDelay == 0.5)
            #expect(policy.backoffMultiplier == 3.0)
            #expect(policy.maxDelay == 30.0)
        }

        @Test("Policy enforces minimum values")
        func minimumValues() {
            let policy = RetryPolicy(
                maxAttempts: -1,  // Test negative value gets clamped to 0
                initialDelay: 0,
                backoffMultiplier: 0,
                maxDelay: 0
            )
            #expect(policy.maxAttempts >= 0)  // 0 is valid for "no retries"
            #expect(policy.initialDelay >= 0.1)
            #expect(policy.backoffMultiplier >= 1.0)
        }

        @Test("Jitter range is bounded")
        func jitterBounded() {
            let policy = RetryPolicy(jitterRange: 2.0)
            #expect(policy.jitterRange <= 1.0)

            let policy2 = RetryPolicy(jitterRange: -1.0)
            #expect(policy2.jitterRange >= 0.0)
        }
    }

    // MARK: - Delay Calculation Tests

    @Suite("Delay Calculation")
    struct DelayCalculationTests {

        @Test("First attempt uses initial delay")
        func firstAttempt() {
            let policy = RetryPolicy(
                initialDelay: 1.0,
                backoffMultiplier: 2.0,
                maxDelay: 100.0,
                jitterEnabled: false
            )
            let delay = policy.delay(for: 1)
            #expect(delay == 1.0)
        }

        @Test("Exponential backoff increases delay")
        func exponentialBackoff() {
            let policy = RetryPolicy(
                initialDelay: 1.0,
                backoffMultiplier: 2.0,
                maxDelay: 100.0,
                jitterEnabled: false
            )

            let delay1 = policy.delay(for: 1)
            let delay2 = policy.delay(for: 2)
            let delay3 = policy.delay(for: 3)

            #expect(delay1 == 1.0)  // 1 * 2^0 = 1
            #expect(delay2 == 2.0)  // 1 * 2^1 = 2
            #expect(delay3 == 4.0)  // 1 * 2^2 = 4
        }

        @Test("Delay is capped at maxDelay")
        func maxDelayCap() {
            let policy = RetryPolicy(
                initialDelay: 1.0,
                backoffMultiplier: 2.0,
                maxDelay: 5.0,
                jitterEnabled: false
            )

            let delay5 = policy.delay(for: 5)  // Would be 16 without cap
            #expect(delay5 == 5.0)
        }

        @Test("Zero attempt returns zero")
        func zeroAttempt() {
            let policy = RetryPolicy.default
            let delay = policy.delay(for: 0)
            #expect(delay == 0)
        }

        @Test("Jitter adds variation")
        func jitterAddsVariation() {
            let policy = RetryPolicy(
                initialDelay: 10.0,
                jitterEnabled: true,
                jitterRange: 0.5  // +/- 50%
            )

            var delays: Set<Double> = []
            for _ in 0..<10 {
                delays.insert(policy.delay(for: 1))
            }

            // With jitter, we should get some variation
            // (unlikely to get exactly the same value 10 times)
            #expect(delays.count > 1)
        }
    }

    // MARK: - Retry Decision Tests

    @Suite("Retry Decisions")
    struct RetryDecisionTests {

        @Test("Should retry when under max attempts")
        func shouldRetryUnderMax() {
            let policy = RetryPolicy(maxAttempts: 3)

            #expect(policy.shouldRetry(currentAttempt: 0) == true)
            #expect(policy.shouldRetry(currentAttempt: 1) == true)
            #expect(policy.shouldRetry(currentAttempt: 2) == true)
        }

        @Test("Should not retry at max attempts")
        func shouldNotRetryAtMax() {
            let policy = RetryPolicy(maxAttempts: 3)
            #expect(policy.shouldRetry(currentAttempt: 3) == false)
            #expect(policy.shouldRetry(currentAttempt: 4) == false)
        }

        @Test("No retry policy always returns false")
        func noRetryPolicy() {
            let policy = RetryPolicy.none
            #expect(policy.shouldRetry(currentAttempt: 0) == false)
        }
    }

    // MARK: - Presets Tests

    @Suite("Presets")
    struct PresetsTests {

        @Test("Aggressive preset has more attempts")
        func aggressivePreset() {
            let aggressive = RetryPolicy.aggressive
            let standard = RetryPolicy.default

            #expect(aggressive.maxAttempts > standard.maxAttempts)
        }

        @Test("Conservative preset has longer delays")
        func conservativePreset() {
            let conservative = RetryPolicy.conservative
            let standard = RetryPolicy.default

            #expect(conservative.initialDelay > standard.initialDelay)
        }

        @Test("Minimal preset has single retry")
        func minimalPreset() {
            let minimal = RetryPolicy.minimal
            #expect(minimal.maxAttempts == 1)
        }

        @Test("None preset has zero retries")
        func nonePreset() {
            let none = RetryPolicy.none
            #expect(none.maxAttempts == 0)
        }
    }

    // MARK: - Retry State Tests

    @Suite("Retry State")
    struct RetryStateTests {

        @Test("Initial state is zero attempts")
        func initialState() {
            let state = RetryState.initial
            #expect(state.attempt == 0)
            #expect(state.isRetrying == false)
            #expect(state.isExhausted == false)
        }

        @Test("Exhausted when at max attempts")
        func exhausted() {
            var state = RetryState.initial
            state.attempt = 3
            state.maxAttempts = 3
            #expect(state.isExhausted == true)
        }

        @Test("Remaining attempts calculation")
        func remainingAttempts() {
            var state = RetryState.initial
            state.maxAttempts = 5
            state.attempt = 2
            #expect(state.remainingAttempts == 3)
        }

        @Test("Progress calculation")
        func progress() {
            var state = RetryState.initial
            state.maxAttempts = 4
            state.attempt = 2
            #expect(state.progress == 0.5)
        }
    }

    // MARK: - Codable Tests

    @Suite("Codable")
    struct CodableTests {

        @Test("RetryPolicy is codable")
        func policyCodable() throws {
            let policy = RetryPolicy(
                maxAttempts: 5,
                initialDelay: 2.0,
                backoffMultiplier: 3.0,
                maxDelay: 30.0
            )

            let encoded = try JSONEncoder().encode(policy)
            let decoded = try JSONDecoder().decode(RetryPolicy.self, from: encoded)

            #expect(decoded == policy)
        }

        @Test("RetryState is codable")
        func stateCodable() throws {
            var state = RetryState.initial
            state.attempt = 2
            state.lastError = "Network timeout"
            state.isRetrying = true

            let encoded = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(RetryState.self, from: encoded)

            #expect(decoded.attempt == 2)
            #expect(decoded.lastError == "Network timeout")
            #expect(decoded.isRetrying == true)
        }
    }

    // MARK: - With Retry Function Tests

    @Suite("withRetry Function")
    struct WithRetryTests {

        @Test("Succeeds on first try")
        func successFirstTry() async throws {
            var attempts = 0

            let result = try await withRetry(
                policy: .default,
                isRetryable: { _ in true }
            ) {
                attempts += 1
                return "success"
            }

            #expect(result == "success")
            #expect(attempts == 1)
        }

        @Test("Retries on failure")
        func retriesOnFailure() async throws {
            var attempts = 0

            let result = try await withRetry(
                policy: RetryPolicy(maxAttempts: 3, initialDelay: 0.01),
                isRetryable: { _ in true }
            ) {
                attempts += 1
                if attempts < 3 {
                    throw RetryTestError.temporary
                }
                return "success after retries"
            }

            #expect(result == "success after retries")
            #expect(attempts == 3)
        }

        @Test("Respects max attempts")
        func respectsMaxAttempts() async {
            var attempts = 0

            do {
                _ = try await withRetry(
                    policy: RetryPolicy(maxAttempts: 2, initialDelay: 0.01),
                    isRetryable: { _ in true }
                ) {
                    attempts += 1
                    throw RetryTestError.permanent
                }
                Issue.record("Should have thrown")
            } catch {
                #expect(attempts == 3)  // Initial + 2 retries
            }
        }

        @Test("Non-retryable errors fail immediately")
        func nonRetryableErrors() async {
            var attempts = 0

            do {
                _ = try await withRetry(
                    policy: RetryPolicy(maxAttempts: 5),
                    isRetryable: { error in
                        if case RetryTestError.permanent = error { return false }
                        return true
                    }
                ) {
                    attempts += 1
                    throw RetryTestError.permanent
                }
                Issue.record("Should have thrown")
            } catch {
                #expect(attempts == 1)  // No retries for non-retryable
            }
        }

        @Test("Calls onRetry callback")
        func callsOnRetry() async throws {
            var retryCallbacks: [(Int, TimeInterval)] = []

            _ = try await withRetry(
                policy: RetryPolicy(maxAttempts: 2, initialDelay: 0.01),
                isRetryable: { _ in true },
                onRetry: { attempt, delay, _ in
                    retryCallbacks.append((attempt, delay))
                }
            ) {
                if retryCallbacks.count < 2 {
                    throw RetryTestError.temporary
                }
                return "done"
            }

            #expect(retryCallbacks.count == 2)
            #expect(retryCallbacks[0].0 == 1)  // First retry
            #expect(retryCallbacks[1].0 == 2)  // Second retry
        }
    }
}

// MARK: - Test Helpers

private enum RetryTestError: Error {
    case temporary
    case permanent
}
