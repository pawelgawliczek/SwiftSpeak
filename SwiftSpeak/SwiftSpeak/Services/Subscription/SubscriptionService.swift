//
//  SubscriptionService.swift
//  SwiftSpeak
//
//  Phase 7: Subscription management service with RevenueCat integration
//

import Foundation
import SwiftSpeakCore
import StoreKit
import Combine
import RevenueCat

/// Product identifiers for SwiftSpeak subscriptions
enum SubscriptionProduct: String, CaseIterable {
    // Pro tier
    case proMonthly = "swiftspeak.pro.monthly"
    case proYearly = "swiftspeak.pro.yearly"
    case proLifetime = "swiftspeak.pro.lifetime"

    // Power tier
    case powerMonthly = "swiftspeak.power.monthly"
    case powerYearly = "swiftspeak.power.yearly"
    case powerLifetime = "swiftspeak.power.lifetime"

    var tier: SubscriptionTier {
        switch self {
        case .proMonthly, .proYearly, .proLifetime:
            return .pro
        case .powerMonthly, .powerYearly, .powerLifetime:
            return .power
        }
    }

    var isLifetime: Bool {
        switch self {
        case .proLifetime, .powerLifetime:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .proMonthly: return "Pro Monthly"
        case .proYearly: return "Pro Yearly"
        case .proLifetime: return "Pro Lifetime"
        case .powerMonthly: return "Power Monthly"
        case .powerYearly: return "Power Yearly"
        case .powerLifetime: return "Power Lifetime"
        }
    }

    /// Package identifier used in RevenueCat
    var packageIdentifier: String {
        switch self {
        case .proMonthly: return "pro_monthly"
        case .proYearly: return "pro_yearly"
        case .proLifetime: return "pro_lifetime"
        case .powerMonthly: return "power_monthly"
        case .powerYearly: return "power_yearly"
        case .powerLifetime: return "power_lifetime"
        }
    }

    /// Initialize from RevenueCat package identifier
    init?(packageIdentifier: String) {
        switch packageIdentifier {
        case "pro_monthly", "$rc_monthly": self = .proMonthly
        case "pro_yearly", "$rc_annual": self = .proYearly
        case "pro_lifetime", "$rc_lifetime": self = .proLifetime
        case "power_monthly": self = .powerMonthly
        case "power_yearly": self = .powerYearly
        case "power_lifetime": self = .powerLifetime
        default: return nil
        }
    }

    var mockPrice: String {
        switch self {
        case .proMonthly: return "$6.99"
        case .proYearly: return "$59.99"
        case .proLifetime: return "$99.00"
        case .powerMonthly: return "$12.99"
        case .powerYearly: return "$99.99"
        case .powerLifetime: return "$199.00"
        }
    }
}

/// Represents a purchasable package
struct SubscriptionPackage: Identifiable {
    let id: String
    let product: SubscriptionProduct
    let localizedPrice: String
    let hasFreeTrial: Bool
    let freeTrialDuration: String?
    let rcPackage: Package? // RevenueCat package reference

    /// Initialize from RevenueCat package
    init?(rcPackage: Package) {
        guard let product = SubscriptionProduct(packageIdentifier: rcPackage.identifier) ??
              SubscriptionProduct(rawValue: rcPackage.storeProduct.productIdentifier) else {
            return nil
        }

        self.id = rcPackage.identifier
        self.product = product
        self.localizedPrice = rcPackage.localizedPriceString
        self.rcPackage = rcPackage

        // Check for introductory offer (free trial)
        if let intro = rcPackage.storeProduct.introductoryDiscount,
           intro.paymentMode == .freeTrial {
            self.hasFreeTrial = true
            let days = intro.subscriptionPeriod.value
            let unit = intro.subscriptionPeriod.unit
            switch unit {
            case .day:
                self.freeTrialDuration = "\(days)-day free trial"
            case .week:
                self.freeTrialDuration = "\(days)-week free trial"
            case .month:
                self.freeTrialDuration = "\(days)-month free trial"
            default:
                self.freeTrialDuration = "Free trial"
            }
        } else {
            self.hasFreeTrial = false
            self.freeTrialDuration = nil
        }
    }

    /// Initialize for mock mode
    init(product: SubscriptionProduct, hasFreeTrial: Bool = false) {
        self.id = product.rawValue
        self.product = product
        self.localizedPrice = product.mockPrice
        self.hasFreeTrial = hasFreeTrial
        self.freeTrialDuration = hasFreeTrial ? "7-day free trial" : nil
        self.rcPackage = nil
    }
}

/// Main subscription service with RevenueCat integration
@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    // MARK: - Published Properties

    /// Current subscription tier
    @Published private(set) var currentTier: SubscriptionTier = .free

    /// Whether a purchase/restore is in progress
    @Published private(set) var isLoading = false

    /// Available packages for purchase
    @Published private(set) var availablePackages: [SubscriptionPackage] = []

    /// Whether the service has been configured
    @Published private(set) var isConfigured = false

    /// Error message to display
    @Published var errorMessage: String?

    // MARK: - Private Properties

    /// Whether we're running in mock mode (for development without RevenueCat)
    /// Set to false to use real RevenueCat SDK
    private var isMockMode: Bool {
        // Use mock mode if API key is the test key or empty
        let apiKey = Constants.RevenueCat.apiKey
        return apiKey.isEmpty || apiKey.hasPrefix("test_")
    }

    /// RevenueCat delegate wrapper
    private var delegateWrapper: PurchasesDelegateWrapper?

    // MARK: - Initialization

    private init() {
        // Packages will be loaded after configuration
    }

    // MARK: - Configuration

    /// Configure the subscription service. Call at app launch.
    func configure(apiKey: String? = nil) {
        guard !isConfigured else { return }

        let key = apiKey ?? Constants.RevenueCat.apiKey

        if isMockMode {
            appLog("Running in MOCK MODE (test API key detected)", category: "Subscription")
            setupMockPackages()
            isConfigured = true
            // Sync from SharedSettings in mock mode
            currentTier = SharedSettings.shared.subscriptionTier
        } else {
            appLog("Configuring RevenueCat with production key", category: "Subscription")

            // Configure RevenueCat
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: key)

            // Set up delegate
            delegateWrapper = PurchasesDelegateWrapper { [weak self] customerInfo in
                Task { @MainActor in
                    self?.updateTierFromCustomerInfo(customerInfo)
                }
            }
            Purchases.shared.delegate = delegateWrapper

            isConfigured = true

            // Fetch initial offerings and customer info
            Task {
                await fetchOfferings()
                await refreshCustomerInfo()
            }
        }
    }

    private func setupMockPackages() {
        availablePackages = [
            SubscriptionPackage(product: .proMonthly, hasFreeTrial: true),
            SubscriptionPackage(product: .proYearly, hasFreeTrial: true),
            SubscriptionPackage(product: .proLifetime),
            SubscriptionPackage(product: .powerMonthly, hasFreeTrial: true),
            SubscriptionPackage(product: .powerYearly, hasFreeTrial: true),
            SubscriptionPackage(product: .powerLifetime)
        ]
    }

    // MARK: - RevenueCat Operations

    /// Fetch offerings from RevenueCat
    func fetchOfferings() async {
        guard !isMockMode else { return }

        do {
            let offerings = try await Purchases.shared.offerings()

            if let defaultOffering = offerings.current {
                let packages = defaultOffering.availablePackages.compactMap { rcPackage in
                    SubscriptionPackage(rcPackage: rcPackage)
                }

                await MainActor.run {
                    self.availablePackages = packages
                    appLog("Loaded \(packages.count) packages from RevenueCat", category: "Subscription")
                }
            } else {
                appLog("No current offering found", category: "Subscription", level: .warning)
                // Fall back to mock packages if no offerings
                await MainActor.run {
                    self.setupMockPackages()
                }
            }
        } catch {
            appLog("Failed to fetch offerings: \(LogSanitizer.sanitizeError(error))", category: "Subscription", level: .error)
            errorMessage = "Failed to load subscription options"
            // Fall back to mock packages on error
            await MainActor.run {
                self.setupMockPackages()
            }
        }
    }

    /// Refresh customer info from RevenueCat
    func refreshCustomerInfo() async {
        guard !isMockMode else { return }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateTierFromCustomerInfo(customerInfo)
        } catch {
            appLog("Failed to refresh customer info: \(LogSanitizer.sanitizeError(error))", category: "Subscription", level: .error)
        }
    }

    /// Update tier based on RevenueCat customer info
    private func updateTierFromCustomerInfo(_ info: CustomerInfo) {
        let powerEntitlement = Constants.RevenueCat.powerEntitlement
        let proEntitlement = Constants.RevenueCat.proEntitlement

        if info.entitlements[powerEntitlement]?.isActive == true {
            currentTier = .power
            appLog("User has Power tier", category: "Subscription")
        } else if info.entitlements[proEntitlement]?.isActive == true {
            currentTier = .pro
            appLog("User has Pro tier", category: "Subscription")
        } else {
            currentTier = .free
            appLog("User has Free tier", category: "Subscription")
        }

        // Sync to SharedSettings
        SharedSettings.shared.subscriptionTier = currentTier
    }

    // MARK: - Package Helpers

    /// Get packages for a specific tier
    func packages(for tier: SubscriptionTier) -> [SubscriptionPackage] {
        availablePackages.filter { $0.product.tier == tier }
    }

    /// Get Pro tier packages
    var proPackages: [SubscriptionPackage] {
        packages(for: .pro)
    }

    /// Get Power tier packages
    var powerPackages: [SubscriptionPackage] {
        packages(for: .power)
    }

    // MARK: - Purchase

    /// Purchase a subscription package
    @discardableResult
    func purchase(_ package: SubscriptionPackage) async throws -> Bool {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        if isMockMode {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Mock success - update tier
            currentTier = package.product.tier
            SharedSettings.shared.subscriptionTier = currentTier

            appLog("Mock purchase success: \(package.product.displayName)", category: "Subscription")
            return true
        } else {
            guard let rcPackage = package.rcPackage else {
                throw SubscriptionError.productNotFound(identifier: package.id)
            }

            do {
                let result = try await Purchases.shared.purchase(package: rcPackage)

                if result.userCancelled {
                    throw SubscriptionError.purchaseCancelled
                }

                updateTierFromCustomerInfo(result.customerInfo)
                appLog("Purchase success: \(package.product.displayName)", category: "Subscription")
                return true
            } catch let error as SubscriptionError {
                throw error
            } catch {
                appLog("Purchase failed: \(LogSanitizer.sanitizeError(error))", category: "Subscription", level: .error)
                throw SubscriptionError.purchaseFailed(underlying: error)
            }
        }
    }

    /// Purchase a specific product
    @discardableResult
    func purchase(product: SubscriptionProduct) async throws -> Bool {
        guard let package = availablePackages.first(where: { $0.product == product }) else {
            throw SubscriptionError.productNotFound(identifier: product.rawValue)
        }
        return try await purchase(package)
    }

    // MARK: - Restore

    /// Restore previous purchases
    @discardableResult
    func restorePurchases() async throws -> Bool {
        guard isConfigured else {
            throw SubscriptionError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        if isMockMode {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            appLog("Mock restore completed", category: "Subscription")
            return true
        } else {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                updateTierFromCustomerInfo(customerInfo)

                let hasSubscription = currentTier != .free
                appLog("Restore completed. Has subscription: \(hasSubscription)", category: "Subscription")
                return hasSubscription
            } catch {
                appLog("Restore failed: \(LogSanitizer.sanitizeError(error))", category: "Subscription", level: .error)
                throw SubscriptionError.restoreFailed(underlying: error)
            }
        }
    }

    // MARK: - Subscription Status

    /// Check if user has active subscription
    var hasActiveSubscription: Bool {
        currentTier != .free
    }

    /// Check if user has specific tier or higher
    func hasTier(_ tier: SubscriptionTier) -> Bool {
        switch tier {
        case .free:
            return true
        case .pro:
            return currentTier == .pro || currentTier == .power
        case .power:
            return currentTier == .power
        }
    }

    // MARK: - Mock Helpers (Development Only)

    /// Set tier directly (for testing/development)
    func setMockTier(_ tier: SubscriptionTier) {
        guard isMockMode else { return }
        currentTier = tier
        SharedSettings.shared.subscriptionTier = tier
    }

    /// Reset to free tier (for testing)
    func resetMockSubscription() {
        guard isMockMode else { return }
        currentTier = .free
        SharedSettings.shared.subscriptionTier = .free
    }
}

// MARK: - RevenueCat Delegate Wrapper

/// Wrapper class to handle RevenueCat delegate callbacks
private class PurchasesDelegateWrapper: NSObject, PurchasesDelegate {
    private let onCustomerInfoUpdate: (CustomerInfo) -> Void

    init(onCustomerInfoUpdate: @escaping (CustomerInfo) -> Void) {
        self.onCustomerInfoUpdate = onCustomerInfoUpdate
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onCustomerInfoUpdate(customerInfo)
    }
}
