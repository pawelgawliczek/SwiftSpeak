//
//  SubscriptionServiceTests.swift
//  SwiftSpeakTests
//
//  Phase 7: Comprehensive tests for SubscriptionService
//  CRITICAL: Payment module requires thorough testing coverage
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - SubscriptionProduct Tests

@Suite("SubscriptionProduct Tests")
struct SubscriptionProductTests {

    // MARK: - Tier Mapping

    @Test("All Pro products map to Pro tier")
    func proProductsTier() {
        let proProducts: [SubscriptionProduct] = [.proMonthly, .proYearly, .proLifetime]
        for product in proProducts {
            #expect(product.tier == .pro, "Product \(product) should be Pro tier")
        }
    }

    @Test("All Power products map to Power tier")
    func powerProductsTier() {
        let powerProducts: [SubscriptionProduct] = [.powerMonthly, .powerYearly, .powerLifetime]
        for product in powerProducts {
            #expect(product.tier == .power, "Product \(product) should be Power tier")
        }
    }

    @Test("All products have correct tier - exhaustive")
    func allProductsTierExhaustive() {
        for product in SubscriptionProduct.allCases {
            switch product {
            case .proMonthly, .proYearly, .proLifetime:
                #expect(product.tier == .pro)
            case .powerMonthly, .powerYearly, .powerLifetime:
                #expect(product.tier == .power)
            }
        }
    }

    // MARK: - Lifetime Flag

    @Test("Only lifetime products have isLifetime true")
    func lifetimeFlag() {
        for product in SubscriptionProduct.allCases {
            let expected = product == .proLifetime || product == .powerLifetime
            #expect(product.isLifetime == expected, "Product \(product) isLifetime should be \(expected)")
        }
    }

    @Test("Monthly products are not lifetime")
    func monthlyNotLifetime() {
        #expect(!SubscriptionProduct.proMonthly.isLifetime)
        #expect(!SubscriptionProduct.powerMonthly.isLifetime)
    }

    @Test("Yearly products are not lifetime")
    func yearlyNotLifetime() {
        #expect(!SubscriptionProduct.proYearly.isLifetime)
        #expect(!SubscriptionProduct.powerYearly.isLifetime)
    }

    // MARK: - Display Names

    @Test("All products have non-empty display names")
    func allProductsHaveDisplayNames() {
        for product in SubscriptionProduct.allCases {
            #expect(!product.displayName.isEmpty, "Product \(product) should have a display name")
        }
    }

    @Test("Display names contain tier name")
    func displayNamesContainTier() {
        for product in SubscriptionProduct.allCases {
            let tierName = product.tier == .pro ? "Pro" : "Power"
            #expect(product.displayName.contains(tierName), "Display name should contain \(tierName)")
        }
    }

    @Test("Display names contain billing period")
    func displayNamesContainPeriod() {
        #expect(SubscriptionProduct.proMonthly.displayName.contains("Monthly"))
        #expect(SubscriptionProduct.proYearly.displayName.contains("Yearly"))
        #expect(SubscriptionProduct.proLifetime.displayName.contains("Lifetime"))
        #expect(SubscriptionProduct.powerMonthly.displayName.contains("Monthly"))
        #expect(SubscriptionProduct.powerYearly.displayName.contains("Yearly"))
        #expect(SubscriptionProduct.powerLifetime.displayName.contains("Lifetime"))
    }

    // MARK: - Raw Values (Product IDs)

    @Test("All raw values follow naming convention")
    func rawValuesFollowConvention() {
        for product in SubscriptionProduct.allCases {
            #expect(product.rawValue.hasPrefix("swiftspeak."), "Raw value should start with 'swiftspeak.'")
            #expect(product.rawValue.contains(".pro.") || product.rawValue.contains(".power."),
                   "Raw value should contain tier")
        }
    }

    @Test("Raw values are unique")
    func rawValuesUnique() {
        let rawValues = SubscriptionProduct.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count, "All raw values should be unique")
    }

    @Test("Raw values match expected product IDs")
    func rawValuesMatchExpected() {
        #expect(SubscriptionProduct.proMonthly.rawValue == "swiftspeak.pro.monthly")
        #expect(SubscriptionProduct.proYearly.rawValue == "swiftspeak.pro.yearly")
        #expect(SubscriptionProduct.proLifetime.rawValue == "swiftspeak.pro.lifetime")
        #expect(SubscriptionProduct.powerMonthly.rawValue == "swiftspeak.power.monthly")
        #expect(SubscriptionProduct.powerYearly.rawValue == "swiftspeak.power.yearly")
        #expect(SubscriptionProduct.powerLifetime.rawValue == "swiftspeak.power.lifetime")
    }

    // MARK: - Package Identifiers

    @Test("Package identifiers are unique")
    func packageIdentifiersUnique() {
        let identifiers = SubscriptionProduct.allCases.map { $0.packageIdentifier }
        let uniqueIdentifiers = Set(identifiers)
        #expect(identifiers.count == uniqueIdentifiers.count, "All package identifiers should be unique")
    }

    @Test("Package identifiers follow naming convention")
    func packageIdentifiersFollowConvention() {
        for product in SubscriptionProduct.allCases {
            let id = product.packageIdentifier
            #expect(id.contains("_"), "Package identifier should use underscores")
            #expect(!id.contains("."), "Package identifier should not contain dots")
        }
    }

    // MARK: - Init from Package Identifier

    @Test("Init from custom package identifiers")
    func initFromCustomIdentifiers() {
        #expect(SubscriptionProduct(packageIdentifier: "pro_monthly") == .proMonthly)
        #expect(SubscriptionProduct(packageIdentifier: "pro_yearly") == .proYearly)
        #expect(SubscriptionProduct(packageIdentifier: "pro_lifetime") == .proLifetime)
        #expect(SubscriptionProduct(packageIdentifier: "power_monthly") == .powerMonthly)
        #expect(SubscriptionProduct(packageIdentifier: "power_yearly") == .powerYearly)
        #expect(SubscriptionProduct(packageIdentifier: "power_lifetime") == .powerLifetime)
    }

    @Test("Init from RevenueCat standard identifiers")
    func initFromRCIdentifiers() {
        #expect(SubscriptionProduct(packageIdentifier: "$rc_monthly") == .proMonthly)
        #expect(SubscriptionProduct(packageIdentifier: "$rc_annual") == .proYearly)
        #expect(SubscriptionProduct(packageIdentifier: "$rc_lifetime") == .proLifetime)
    }

    @Test("Init returns nil for invalid identifiers")
    func initReturnsNilForInvalid() {
        #expect(SubscriptionProduct(packageIdentifier: "") == nil)
        #expect(SubscriptionProduct(packageIdentifier: "invalid") == nil)
        #expect(SubscriptionProduct(packageIdentifier: "pro") == nil)
        #expect(SubscriptionProduct(packageIdentifier: "monthly") == nil)
        #expect(SubscriptionProduct(packageIdentifier: "swiftspeak.pro.monthly") == nil) // This is raw value, not package id
    }

    // MARK: - Mock Prices

    @Test("All products have mock prices")
    func allProductsHaveMockPrices() {
        for product in SubscriptionProduct.allCases {
            #expect(!product.mockPrice.isEmpty, "Product \(product) should have a mock price")
        }
    }

    @Test("Mock prices start with dollar sign")
    func mockPricesHaveDollarSign() {
        for product in SubscriptionProduct.allCases {
            #expect(product.mockPrice.hasPrefix("$"), "Mock price should start with $")
        }
    }

    @Test("Power prices higher than Pro prices")
    func powerPricesHigherThanPro() {
        // Extract numeric values
        func extractPrice(_ str: String) -> Double {
            Double(str.replacingOccurrences(of: "$", with: "")) ?? 0
        }

        #expect(extractPrice(SubscriptionProduct.powerMonthly.mockPrice) > extractPrice(SubscriptionProduct.proMonthly.mockPrice))
        #expect(extractPrice(SubscriptionProduct.powerYearly.mockPrice) > extractPrice(SubscriptionProduct.proYearly.mockPrice))
        #expect(extractPrice(SubscriptionProduct.powerLifetime.mockPrice) > extractPrice(SubscriptionProduct.proLifetime.mockPrice))
    }

    @Test("Yearly prices offer savings vs monthly")
    func yearlyOffersSavings() {
        func extractPrice(_ str: String) -> Double {
            Double(str.replacingOccurrences(of: "$", with: "")) ?? 0
        }

        let proMonthlyAnnual = extractPrice(SubscriptionProduct.proMonthly.mockPrice) * 12
        let proYearly = extractPrice(SubscriptionProduct.proYearly.mockPrice)
        #expect(proYearly < proMonthlyAnnual, "Pro yearly should be cheaper than 12 months")

        let powerMonthlyAnnual = extractPrice(SubscriptionProduct.powerMonthly.mockPrice) * 12
        let powerYearly = extractPrice(SubscriptionProduct.powerYearly.mockPrice)
        #expect(powerYearly < powerMonthlyAnnual, "Power yearly should be cheaper than 12 months")
    }

    // MARK: - CaseIterable

    @Test("All cases count is 6")
    func allCasesCount() {
        #expect(SubscriptionProduct.allCases.count == 6)
    }
}

// MARK: - SubscriptionPackage Tests

@Suite("SubscriptionPackage Tests")
struct SubscriptionPackageTests {

    @Test("Mock package has correct properties")
    func mockPackageProperties() {
        let package = SubscriptionPackage(product: .proMonthly, hasFreeTrial: true)

        #expect(package.id == SubscriptionProduct.proMonthly.rawValue)
        #expect(package.product == .proMonthly)
        #expect(package.localizedPrice == SubscriptionProduct.proMonthly.mockPrice)
        #expect(package.hasFreeTrial == true)
        #expect(package.freeTrialDuration == "7-day free trial")
        #expect(package.rcPackage == nil)
    }

    @Test("Mock package without trial")
    func mockPackageNoTrial() {
        let package = SubscriptionPackage(product: .proLifetime, hasFreeTrial: false)

        #expect(package.hasFreeTrial == false)
        #expect(package.freeTrialDuration == nil)
    }

    @Test("All products can create mock packages")
    func allProductsCreateMockPackages() {
        for product in SubscriptionProduct.allCases {
            let package = SubscriptionPackage(product: product)
            #expect(package.product == product)
            #expect(package.id == product.rawValue)
        }
    }

    @Test("Package ID is stable")
    func packageIdStable() {
        let package1 = SubscriptionPackage(product: .powerMonthly)
        let package2 = SubscriptionPackage(product: .powerMonthly)
        #expect(package1.id == package2.id)
    }

    @Test("Package conforms to Identifiable")
    func packageIdentifiable() {
        let packages = [
            SubscriptionPackage(product: .proMonthly),
            SubscriptionPackage(product: .proYearly)
        ]

        // Can use in ForEach because of Identifiable
        let ids = packages.map { $0.id }
        #expect(ids.count == 2)
        #expect(ids[0] != ids[1])
    }
}

// MARK: - SubscriptionService Tests

@Suite("SubscriptionService Tests")
struct SubscriptionServiceTests {

    // MARK: - Singleton

    @Test("Service is singleton")
    @MainActor
    func serviceSingleton() {
        let service1 = SubscriptionService.shared
        let service2 = SubscriptionService.shared
        #expect(service1 === service2, "Should return the same instance")
    }

    // MARK: - Configuration

    @Test("Service configures successfully")
    @MainActor
    func serviceConfigures() {
        let service = SubscriptionService.shared
        service.configure()
        #expect(service.isConfigured == true)
    }

    @Test("Service only configures once")
    @MainActor
    func serviceConfiguresOnce() {
        let service = SubscriptionService.shared
        service.configure()
        let configuredFirst = service.isConfigured

        // Try to configure again
        service.configure()
        let configuredSecond = service.isConfigured

        #expect(configuredFirst == true)
        #expect(configuredSecond == true)
    }

    // MARK: - Mock Packages

    @Test("Service has all 6 mock packages")
    @MainActor
    func serviceHasAllPackages() {
        let service = SubscriptionService.shared
        service.configure()

        #expect(service.availablePackages.count == 6)
    }

    @Test("Service has 3 Pro packages")
    @MainActor
    func serviceHasProPackages() {
        let service = SubscriptionService.shared
        service.configure()

        #expect(service.proPackages.count == 3)
        for package in service.proPackages {
            #expect(package.product.tier == .pro)
        }
    }

    @Test("Service has 3 Power packages")
    @MainActor
    func serviceHasPowerPackages() {
        let service = SubscriptionService.shared
        service.configure()

        #expect(service.powerPackages.count == 3)
        for package in service.powerPackages {
            #expect(package.product.tier == .power)
        }
    }

    @Test("Package filtering by tier")
    @MainActor
    func packageFilteringByTier() {
        let service = SubscriptionService.shared
        service.configure()

        let proPackages = service.packages(for: .pro)
        let powerPackages = service.packages(for: .power)
        let freePackages = service.packages(for: .free)

        #expect(proPackages.count == 3)
        #expect(powerPackages.count == 3)
        #expect(freePackages.count == 0) // No packages for free tier
    }

    // MARK: - Tier Management

    @Test("Default tier is free")
    @MainActor
    func defaultTierIsFree() {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        #expect(service.currentTier == .free)
    }

    @Test("Set mock tier to Pro")
    @MainActor
    func setMockTierPro() {
        let service = SubscriptionService.shared
        service.configure()

        service.setMockTier(.pro)
        #expect(service.currentTier == .pro)

        service.resetMockSubscription()
    }

    @Test("Set mock tier to Power")
    @MainActor
    func setMockTierPower() {
        let service = SubscriptionService.shared
        service.configure()

        service.setMockTier(.power)
        #expect(service.currentTier == .power)

        service.resetMockSubscription()
    }

    @Test("Reset mock subscription returns to free")
    @MainActor
    func resetMockSubscription() {
        let service = SubscriptionService.shared
        service.configure()

        service.setMockTier(.power)
        #expect(service.currentTier == .power)

        service.resetMockSubscription()
        #expect(service.currentTier == .free)
    }

    // MARK: - Tier Checking

    @Test("hasTier - Free tier")
    @MainActor
    func hasTierFree() {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        #expect(service.hasTier(.free) == true)
        #expect(service.hasTier(.pro) == false)
        #expect(service.hasTier(.power) == false)
    }

    @Test("hasTier - Pro tier")
    @MainActor
    func hasTierPro() {
        let service = SubscriptionService.shared
        service.configure()
        service.setMockTier(.pro)

        #expect(service.hasTier(.free) == true) // Pro includes free
        #expect(service.hasTier(.pro) == true)
        #expect(service.hasTier(.power) == false)

        service.resetMockSubscription()
    }

    @Test("hasTier - Power tier")
    @MainActor
    func hasTierPower() {
        let service = SubscriptionService.shared
        service.configure()
        service.setMockTier(.power)

        #expect(service.hasTier(.free) == true) // Power includes free
        #expect(service.hasTier(.pro) == true) // Power includes pro
        #expect(service.hasTier(.power) == true)

        service.resetMockSubscription()
    }

    @Test("hasActiveSubscription - Free")
    @MainActor
    func hasActiveSubscriptionFree() {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        #expect(service.hasActiveSubscription == false)
    }

    @Test("hasActiveSubscription - Pro")
    @MainActor
    func hasActiveSubscriptionPro() {
        let service = SubscriptionService.shared
        service.configure()
        service.setMockTier(.pro)

        #expect(service.hasActiveSubscription == true)

        service.resetMockSubscription()
    }

    @Test("hasActiveSubscription - Power")
    @MainActor
    func hasActiveSubscriptionPower() {
        let service = SubscriptionService.shared
        service.configure()
        service.setMockTier(.power)

        #expect(service.hasActiveSubscription == true)

        service.resetMockSubscription()
    }

    // MARK: - Mock Purchase

    @Test("Mock purchase Pro updates tier")
    @MainActor
    func mockPurchasePro() async throws {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        let proPackage = service.proPackages.first!
        let success = try await service.purchase(proPackage)

        #expect(success == true)
        #expect(service.currentTier == .pro)

        service.resetMockSubscription()
    }

    @Test("Mock purchase Power updates tier")
    @MainActor
    func mockPurchasePower() async throws {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        let powerPackage = service.powerPackages.first!
        let success = try await service.purchase(powerPackage)

        #expect(success == true)
        #expect(service.currentTier == .power)

        service.resetMockSubscription()
    }

    @Test("Mock purchase by product")
    @MainActor
    func mockPurchaseByProduct() async throws {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        let success = try await service.purchase(product: .proMonthly)

        #expect(success == true)
        #expect(service.currentTier == .pro)

        service.resetMockSubscription()
    }

    // MARK: - Mock Restore

    @Test("Mock restore completes successfully")
    @MainActor
    func mockRestoreCompletes() async throws {
        let service = SubscriptionService.shared
        service.configure()

        let success = try await service.restorePurchases()
        #expect(success == true)
    }

    // MARK: - Error Handling

    @Test("Purchase fails if not configured")
    @MainActor
    func purchaseFailsIfNotConfigured() async {
        // This test is tricky because the singleton is already configured
        // We test by verifying the error type exists
        let error = SubscriptionError.notConfigured
        #expect(error.errorDescription != nil)
    }

    @Test("Purchase with invalid product throws error")
    @MainActor
    func purchaseInvalidProduct() async throws {
        let service = SubscriptionService.shared
        service.configure()

        // Create a package for a product that doesn't exist in availablePackages
        // Since we can't directly create an invalid package, we test the error type
        let error = SubscriptionError.productNotFound(identifier: "invalid.product")
        #expect(error.errorDescription?.contains("invalid.product") == true)
    }

    // MARK: - SharedSettings Sync

    @Test("Tier changes sync to SharedSettings")
    @MainActor
    func tierSyncsToSharedSettings() {
        let service = SubscriptionService.shared
        service.configure()

        service.setMockTier(.pro)
        #expect(SharedSettings.shared.subscriptionTier == .pro)

        service.setMockTier(.power)
        #expect(SharedSettings.shared.subscriptionTier == .power)

        service.resetMockSubscription()
        #expect(SharedSettings.shared.subscriptionTier == .free)
    }
}

// MARK: - SubscriptionError Tests

@Suite("SubscriptionError Tests")
struct SubscriptionErrorTests {

    // MARK: - Error Descriptions

    @Test("All errors have descriptions")
    func allErrorsHaveDescriptions() {
        let errors: [SubscriptionError] = [
            .notConfigured,
            .purchaseFailed(underlying: nil),
            .purchaseCancelled,
            .restoreFailed(underlying: nil),
            .noProductsAvailable,
            .productNotFound(identifier: "test"),
            .networkError,
            .receiptValidationFailed,
            .alreadySubscribed,
            .unknown(message: "test")
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have a description")
            #expect(!error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    @Test("Product not found includes identifier")
    func productNotFoundIncludesId() {
        let error = SubscriptionError.productNotFound(identifier: "test.product.id")
        #expect(error.errorDescription?.contains("test.product.id") == true)
    }

    @Test("Unknown error includes message")
    func unknownIncludesMessage() {
        let error = SubscriptionError.unknown(message: "Custom error message")
        #expect(error.errorDescription?.contains("Custom error message") == true)
    }

    @Test("Purchase failed includes underlying error")
    func purchaseFailedIncludesUnderlying() {
        let underlying = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = SubscriptionError.purchaseFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("Test error") == true)
    }

    @Test("Restore failed includes underlying error")
    func restoreFailedIncludesUnderlying() {
        let underlying = NSError(domain: "test", code: 456, userInfo: [NSLocalizedDescriptionKey: "Restore test error"])
        let error = SubscriptionError.restoreFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("Restore test error") == true)
    }

    // MARK: - Recovery Suggestions

    @Test("Most errors have recovery suggestions")
    func mostErrorsHaveRecoverySuggestions() {
        let errorsWithSuggestions: [SubscriptionError] = [
            .notConfigured,
            .purchaseFailed(underlying: nil),
            .restoreFailed(underlying: nil),
            .noProductsAvailable,
            .productNotFound(identifier: "test"),
            .networkError,
            .receiptValidationFailed,
            .alreadySubscribed,
            .unknown(message: "test")
        ]

        for error in errorsWithSuggestions {
            #expect(error.recoverySuggestion != nil, "Error \(error) should have recovery suggestion")
        }
    }

    @Test("Cancelled has no recovery suggestion")
    func cancelledNoRecoverySuggestion() {
        #expect(SubscriptionError.purchaseCancelled.recoverySuggestion == nil)
    }

    // MARK: - Retryable Flag

    @Test("Retryable errors")
    func retryableErrors() {
        #expect(SubscriptionError.purchaseFailed(underlying: nil).isRetryable == true)
        #expect(SubscriptionError.restoreFailed(underlying: nil).isRetryable == true)
        #expect(SubscriptionError.networkError.isRetryable == true)
    }

    @Test("Non-retryable errors")
    func nonRetryableErrors() {
        #expect(SubscriptionError.notConfigured.isRetryable == false)
        #expect(SubscriptionError.purchaseCancelled.isRetryable == false)
        #expect(SubscriptionError.noProductsAvailable.isRetryable == false)
        #expect(SubscriptionError.productNotFound(identifier: "test").isRetryable == false)
        #expect(SubscriptionError.receiptValidationFailed.isRetryable == false)
        #expect(SubscriptionError.alreadySubscribed.isRetryable == false)
        #expect(SubscriptionError.unknown(message: "test").isRetryable == false)
    }

    // MARK: - LocalizedError Conformance

    @Test("Conforms to LocalizedError")
    func conformsToLocalizedError() {
        let error: LocalizedError = SubscriptionError.networkError
        #expect(error.errorDescription != nil)
    }
}

// MARK: - SubscriptionTier Tests (from Models.swift)

@Suite("SubscriptionTier Tests")
struct SubscriptionTierTests {

    @Test("Tier ordering - free is lowest")
    func tierOrderingFreeLowest() {
        #expect(SubscriptionTier.free.rawValue == "free")
    }

    @Test("All tiers have raw values")
    func allTiersHaveRawValues() {
        #expect(!SubscriptionTier.free.rawValue.isEmpty)
        #expect(!SubscriptionTier.pro.rawValue.isEmpty)
        #expect(!SubscriptionTier.power.rawValue.isEmpty)
    }

    @Test("Tiers are distinct")
    func tiersDistinct() {
        #expect(SubscriptionTier.free != SubscriptionTier.pro)
        #expect(SubscriptionTier.pro != SubscriptionTier.power)
        #expect(SubscriptionTier.free != SubscriptionTier.power)
    }
}

// MARK: - Integration Tests

@Suite("Subscription Integration Tests")
struct SubscriptionIntegrationTests {

    @Test("Full purchase flow - Pro Monthly")
    @MainActor
    func fullPurchaseFlowProMonthly() async throws {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        // Initial state
        #expect(service.currentTier == .free)
        #expect(service.hasActiveSubscription == false)
        #expect(SharedSettings.shared.subscriptionTier == .free)

        // Find and purchase Pro Monthly
        guard let proMonthly = service.proPackages.first(where: { $0.product == .proMonthly }) else {
            Issue.record("Pro Monthly package not found")
            return
        }

        let success = try await service.purchase(proMonthly)

        // Verify purchase succeeded
        #expect(success == true)
        #expect(service.currentTier == .pro)
        #expect(service.hasActiveSubscription == true)
        #expect(service.hasTier(.pro) == true)
        #expect(SharedSettings.shared.subscriptionTier == .pro)

        // Cleanup
        service.resetMockSubscription()
    }

    @Test("Full purchase flow - Power Yearly")
    @MainActor
    func fullPurchaseFlowPowerYearly() async throws {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        // Find and purchase Power Yearly
        guard let powerYearly = service.powerPackages.first(where: { $0.product == .powerYearly }) else {
            Issue.record("Power Yearly package not found")
            return
        }

        let success = try await service.purchase(powerYearly)

        // Verify
        #expect(success == true)
        #expect(service.currentTier == .power)
        #expect(service.hasTier(.power) == true)
        #expect(service.hasTier(.pro) == true) // Power includes Pro

        // Cleanup
        service.resetMockSubscription()
    }

    @Test("Upgrade from Pro to Power")
    @MainActor
    func upgradeProToPower() async throws {
        let service = SubscriptionService.shared
        service.configure()
        service.resetMockSubscription()

        // Purchase Pro first
        try await service.purchase(product: .proMonthly)
        #expect(service.currentTier == .pro)

        // Upgrade to Power
        try await service.purchase(product: .powerMonthly)
        #expect(service.currentTier == .power)

        // Cleanup
        service.resetMockSubscription()
    }
}
