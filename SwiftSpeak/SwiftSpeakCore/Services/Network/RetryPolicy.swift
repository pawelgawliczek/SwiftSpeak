//
//  RetryPolicy.swift
//  SwiftSpeak
//
//  Phase 11e: Retry logic with exponential backoff
//

import Foundation

/// Configuration for retry behavior
public struct RetryPolicy: Codable, Equatable {

    // MARK: - Configuration

    /// Maximum number of retry attempts
    public let maxAttempts: Int

    /// Initial delay before first retry (seconds)
    public let initialDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let backoffMultiplier: Double

    /// Maximum delay between retries (seconds)
    public let maxDelay: TimeInterval

    /// Whether to add jitter to prevent thundering herd
    public let jitterEnabled: Bool

    /// Maximum jitter range (0-1, percentage of delay)
    public let jitterRange: Double

    // MARK: - Initialization

    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 16.0,
        jitterEnabled: Bool = true,
        jitterRange: Double = 0.25
    ) {
        // Allow 0 for "no retries" policy, but clamp negative values
        self.maxAttempts = max(0, maxAttempts)
        self.initialDelay = max(0.1, initialDelay)
        self.backoffMultiplier = max(1.0, backoffMultiplier)
        self.maxDelay = max(initialDelay, maxDelay)
        self.jitterEnabled = jitterEnabled
        self.jitterRange = min(1.0, max(0.0, jitterRange))
    }

    // MARK: - Delay Calculation

    /// Calculate delay for a specific attempt (1-indexed)
    /// - Parameter attempt: Attempt number (1 = first retry, 2 = second retry, etc.)
    /// - Returns: Delay in seconds before attempting
    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }

        // Calculate base delay with exponential backoff
        let exponentialDelay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
        var delay = min(exponentialDelay, maxDelay)

        // Add jitter if enabled
        if jitterEnabled && jitterRange > 0 {
            let jitterAmount = delay * jitterRange
            let jitter = Double.random(in: -jitterAmount...jitterAmount)
            delay = max(0.1, delay + jitter)
        }

        return delay
    }

    /// Check if more retries are available
    /// - Parameter currentAttempt: Current attempt number (0 = initial, 1 = first retry)
    /// - Returns: True if more retries available
    public func shouldRetry(currentAttempt: Int) -> Bool {
        currentAttempt < maxAttempts
    }

    // MARK: - Presets

    /// Default policy for network operations
    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        maxDelay: 16.0
    )

    /// Aggressive retry for critical operations
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 8.0
    )

    /// Conservative retry for rate-limited APIs
    public static let conservative = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 2.0,
        backoffMultiplier: 3.0,
        maxDelay: 30.0
    )

    /// Single retry for fast-fail scenarios
    public static let minimal = RetryPolicy(
        maxAttempts: 1,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        maxDelay: 1.0
    )

    /// No retries
    public static let none = RetryPolicy(
        maxAttempts: 0,
        initialDelay: 0,
        backoffMultiplier: 1.0,
        maxDelay: 0
    )
}

// MARK: - Retry Executor

/// Execute an async operation with retry logic
/// - Parameters:
///   - policy: Retry configuration
///   - isRetryable: Closure to determine if an error should be retried
///   - onRetry: Optional callback before each retry attempt
///   - operation: The async operation to execute
/// - Returns: Result of the operation
/// - Throws: Last error if all retries exhausted
func withRetry<T>(
    policy: RetryPolicy,
    isRetryable: (Error) -> Bool,
    onRetry: ((Int, TimeInterval, Error) async -> Void)? = nil,
    operation: () async throws -> T
) async throws -> T {
    public var lastError: Error?
    public var attempt = 0

    while attempt <= policy.maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error

            // Check if we should retry BEFORE incrementing
            // (attempt represents completed retries, not upcoming)
            guard policy.shouldRetry(currentAttempt: attempt),
                  isRetryable(error) else {
                throw error
            }

            attempt += 1

            // Calculate and wait for delay
            let delay = policy.delay(for: attempt)

            // Notify about retry
            await onRetry?(attempt, delay, error)

            // Wait before retry
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    throw lastError ?? RetryError.exhausted
}

/// Execute with retry, providing attempt context
/// - Parameters:
///   - policy: Retry configuration
///   - isRetryable: Closure to determine if an error should be retried
///   - operation: Operation that receives current attempt number
/// - Returns: Result of the operation
func withRetryContext<T>(
    policy: RetryPolicy,
    isRetryable: (Error) -> Bool,
    operation: (_ attempt: Int) async throws -> T
) async throws -> T {
    public var lastError: Error?
    public var attempt = 0

    while attempt <= policy.maxAttempts {
        do {
            return try await operation(attempt)
        } catch {
            lastError = error

            // Check if we should retry BEFORE incrementing
            guard policy.shouldRetry(currentAttempt: attempt),
                  isRetryable(error) else {
                throw error
            }

            attempt += 1
            let delay = policy.delay(for: attempt)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    throw lastError ?? RetryError.exhausted
}

// MARK: - Retry Error

public enum RetryError: LocalizedError {
    case exhausted
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .exhausted:
            return "All retry attempts exhausted"
        case .cancelled:
            return "Retry was cancelled"
        }
    }
}

// MARK: - Retry State

/// Tracks the state of a retry operation
public struct RetryState: Codable, Equatable {
    public var attempt: Int
    public var maxAttempts: Int
    public var lastError: String?
    public var nextRetryAt: Date?
    public var isRetrying: Bool

    public static var initial: RetryState {
        RetryState(
            attempt: 0,
            maxAttempts: 3,
            lastError: nil,
            nextRetryAt: nil,
            isRetrying: false
        )
    }

    public var isExhausted: Bool {
        attempt >= maxAttempts
    }

    public var remainingAttempts: Int {
        max(0, maxAttempts - attempt)
    }

    public var progress: Double {
        guard maxAttempts > 0 else { return 1.0 }
        return Double(attempt) / Double(maxAttempts)
    }
}
