//
//  SubscriptionError.swift
//  SwiftSpeak
//
//  Phase 7: Subscription error types for RevenueCat integration
//

import Foundation

/// Errors that can occur during subscription operations
enum SubscriptionError: LocalizedError {
    case notConfigured
    case purchaseFailed(underlying: Error?)
    case purchaseCancelled
    case restoreFailed(underlying: Error?)
    case noProductsAvailable
    case productNotFound(identifier: String)
    case networkError
    case receiptValidationFailed
    case alreadySubscribed
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscription service is not configured"
        case .purchaseFailed(let error):
            if let error = error {
                return "Purchase failed: \(error.localizedDescription)"
            }
            return "Purchase failed. Please try again."
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .restoreFailed(let error):
            if let error = error {
                return "Restore failed: \(error.localizedDescription)"
            }
            return "Failed to restore purchases. Please try again."
        case .noProductsAvailable:
            return "No subscription products available"
        case .productNotFound(let identifier):
            return "Product not found: \(identifier)"
        case .networkError:
            return "Network error. Please check your connection."
        case .receiptValidationFailed:
            return "Failed to validate purchase receipt"
        case .alreadySubscribed:
            return "You already have an active subscription"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Please contact support."
        case .purchaseFailed, .restoreFailed:
            return "Check your payment method and try again."
        case .purchaseCancelled:
            return nil
        case .noProductsAvailable, .productNotFound:
            return "Please try again later or contact support."
        case .networkError:
            return "Check your internet connection and try again."
        case .receiptValidationFailed:
            return "Try restoring purchases or contact support."
        case .alreadySubscribed:
            return "Manage your subscription in Settings."
        case .unknown:
            return "Please try again or contact support."
        }
    }

    /// Whether the user can retry the operation
    var isRetryable: Bool {
        switch self {
        case .purchaseFailed, .restoreFailed, .networkError:
            return true
        case .notConfigured, .purchaseCancelled, .noProductsAvailable,
             .productNotFound, .receiptValidationFailed, .alreadySubscribed, .unknown:
            return false
        }
    }
}
