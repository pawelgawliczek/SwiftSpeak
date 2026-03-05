//
//  ConfigChangeDetectorTests.swift
//  SwiftSpeakTests
//
//  Tests for ConfigChangeDetector - detecting meaningful config changes
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - Helper Factories

private enum TestDataFactory {

    static func makeProviderConfig(
        displayName: String = "Test Provider",
        status: ProviderOperationalStatus = .operational,
        transcription: CapabilityRemoteConfig? = nil,
        translation: CapabilityRemoteConfig? = nil,
        powerMode: CapabilityRemoteConfig? = nil,
        pricing: [String: PricingRemoteConfig] = [:]
    ) -> ProviderRemoteConfig {
        ProviderRemoteConfig(
            displayName: displayName,
            status: status,
            transcription: transcription,
            translation: translation,
            powerMode: powerMode,
            pricing: pricing,
            freeCredits: nil,
            apiKeyUrl: nil,
            notes: nil
        )
    }

    static func makeCapabilityConfig(
        enabled: Bool = true,
        models: [ModelRemoteConfig]? = nil,
        languages: [String: String]? = nil,
        features: [String]? = nil
    ) -> CapabilityRemoteConfig {
        CapabilityRemoteConfig(
            enabled: enabled,
            models: models,
            languages: languages,
            features: features
        )
    }

    static func makeModelConfig(
        id: String,
        name: String,
        isDefault: Bool? = nil
    ) -> ModelRemoteConfig {
        ModelRemoteConfig(
            id: id,
            name: name,
            isDefault: isDefault
        )
    }

    static func makePricingConfig(
        unit: String? = nil,
        cost: Double? = nil,
        inputPerMToken: Double? = nil,
        outputPerMToken: Double? = nil
    ) -> PricingRemoteConfig {
        PricingRemoteConfig(
            unit: unit,
            cost: cost,
            inputPerMToken: inputPerMToken,
            outputPerMToken: outputPerMToken
        )
    }

    static func makeRemoteConfig(
        version: String = "1.0",
        providers: [String: ProviderRemoteConfig]
    ) -> RemoteProviderConfig {
        RemoteProviderConfig(
            version: version,
            lastUpdated: Date(),
            schemaVersion: 1,
            providers: providers
        )
    }
}

// MARK: - ConfigChangeDetector Tests

@Suite("ConfigChangeDetector Tests")
struct ConfigChangeDetectorTests {

    let detector = ConfigChangeDetector()

    // MARK: - No Changes Tests

    @Test("Returns empty array when old config is nil")
    func testReturnsEmptyWhenOldIsNil() {
        let newConfig = TestDataFactory.makeRemoteConfig(providers: [:])

        let changes = detector.detectChanges(
            old: nil,
            new: newConfig,
            userProviders: [.openAI]
        )

        #expect(changes.isEmpty)
    }

    @Test("Returns empty array when no user providers")
    func testReturnsEmptyWhenNoUserProviders() {
        let config = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig()]
        )

        let changes = detector.detectChanges(
            old: config,
            new: config,
            userProviders: []
        )

        #expect(changes.isEmpty)
    }

    @Test("Returns empty array when configs are identical")
    func testReturnsEmptyWhenIdentical() {
        let config = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig()]
        )

        let changes = detector.detectChanges(
            old: config,
            new: config,
            userProviders: [.openAI]
        )

        #expect(changes.isEmpty)
    }

    // MARK: - Status Change Tests

    @Test("Detects status change from operational to degraded")
    func testDetectsStatusChangeToDegrade() {
        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(status: .operational)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(status: .degraded)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        #expect(changes.count == 1)
        if case .statusChange(let provider, let oldStatus, let newStatus) = changes.first {
            #expect(provider == .openAI)
            #expect(oldStatus == .operational)
            #expect(newStatus == .degraded)
        } else {
            #expect(Bool(false), "Wrong change type")
        }
    }

    @Test("Detects status change from down to operational")
    func testDetectsStatusChangeToOperational() {
        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(status: .down)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(status: .operational)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        #expect(changes.count == 1)
        if case .statusChange(_, _, let newStatus) = changes.first {
            #expect(newStatus == .operational)
        }
    }

    // MARK: - New Language Tests

    @Test("Detects new language added")
    func testDetectsNewLanguage() {
        let oldTranscription = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "excellent"]
        )
        let newTranscription = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "excellent", "es": "good"]
        )

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: oldTranscription)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: newTranscription)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let newLangChanges = changes.filter {
            if case .newLanguage = $0 { return true }
            return false
        }
        #expect(newLangChanges.count == 1)
    }

    // MARK: - Language Quality Improvement Tests

    @Test("Detects language quality improvement")
    func testDetectsLanguageQualityImprovement() {
        let oldTranscription = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "limited"]
        )
        let newTranscription = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "excellent"]
        )

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: oldTranscription)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: newTranscription)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let qualityChanges = changes.filter {
            if case .languageQualityImproved = $0 { return true }
            return false
        }
        #expect(qualityChanges.count == 1)
    }

    @Test("Does not report quality decrease as improvement")
    func testDoesNotReportQualityDecrease() {
        let oldTranscription = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "excellent"]
        )
        let newTranscription = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "limited"]
        )

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: oldTranscription)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: newTranscription)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let qualityChanges = changes.filter {
            if case .languageQualityImproved = $0 { return true }
            return false
        }
        #expect(qualityChanges.isEmpty)
    }

    // MARK: - New Model Tests

    @Test("Detects new model added")
    func testDetectsNewModel() {
        let oldModels = [TestDataFactory.makeModelConfig(id: "model-1", name: "Model 1")]
        let newModels = [
            TestDataFactory.makeModelConfig(id: "model-1", name: "Model 1"),
            TestDataFactory.makeModelConfig(id: "model-2", name: "Model 2")
        ]

        let oldTranscription = TestDataFactory.makeCapabilityConfig(models: oldModels)
        let newTranscription = TestDataFactory.makeCapabilityConfig(models: newModels)

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: oldTranscription)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(transcription: newTranscription)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let modelChanges = changes.filter {
            if case .newModel = $0 { return true }
            return false
        }
        #expect(modelChanges.count == 1)
    }

    // MARK: - Pricing Change Tests

    @Test("Detects pricing increase")
    func testDetectsPricingIncrease() {
        let oldPricing = ["whisper-1": TestDataFactory.makePricingConfig(unit: "minute", cost: 0.006)]
        let newPricing = ["whisper-1": TestDataFactory.makePricingConfig(unit: "minute", cost: 0.010)]

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(pricing: oldPricing)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(pricing: newPricing)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let priceChanges = changes.filter {
            if case .pricingIncrease = $0 { return true }
            return false
        }
        #expect(priceChanges.count == 1)
    }

    @Test("Detects pricing decrease")
    func testDetectsPricingDecrease() {
        let oldPricing = ["whisper-1": TestDataFactory.makePricingConfig(unit: "minute", cost: 0.010)]
        let newPricing = ["whisper-1": TestDataFactory.makePricingConfig(unit: "minute", cost: 0.006)]

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(pricing: oldPricing)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(pricing: newPricing)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let priceChanges = changes.filter {
            if case .pricingDecrease = $0 { return true }
            return false
        }
        #expect(priceChanges.count == 1)
    }

    @Test("Ignores small pricing changes under 5%")
    func testIgnoresSmallPricingChanges() {
        let oldPricing = ["whisper-1": TestDataFactory.makePricingConfig(unit: "minute", cost: 0.010)]
        let newPricing = ["whisper-1": TestDataFactory.makePricingConfig(unit: "minute", cost: 0.0102)]

        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(pricing: oldPricing)]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: ["openai": TestDataFactory.makeProviderConfig(pricing: newPricing)]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        let priceChanges = changes.filter {
            if case .pricingIncrease = $0 { return true }
            if case .pricingDecrease = $0 { return true }
            return false
        }
        #expect(priceChanges.isEmpty)
    }

    // MARK: - Multiple Provider Tests

    @Test("Only detects changes for user's configured providers")
    func testOnlyDetectsChangesForUserProviders() {
        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: [
                "openai": TestDataFactory.makeProviderConfig(status: .operational),
                "anthropic": TestDataFactory.makeProviderConfig(status: .operational)
            ]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: [
                "openai": TestDataFactory.makeProviderConfig(status: .operational),
                "anthropic": TestDataFactory.makeProviderConfig(status: .degraded)
            ]
        )

        // Only using OpenAI, not Anthropic
        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI]
        )

        // Should not report Anthropic status change
        #expect(changes.isEmpty)
    }

    @Test("Detects changes for all user providers")
    func testDetectsChangesForAllUserProviders() {
        let oldConfig = TestDataFactory.makeRemoteConfig(
            providers: [
                "openai": TestDataFactory.makeProviderConfig(status: .operational),
                "anthropic": TestDataFactory.makeProviderConfig(status: .operational)
            ]
        )
        let newConfig = TestDataFactory.makeRemoteConfig(
            providers: [
                "openai": TestDataFactory.makeProviderConfig(status: .degraded),
                "anthropic": TestDataFactory.makeProviderConfig(status: .down)
            ]
        )

        let changes = detector.detectChanges(
            old: oldConfig,
            new: newConfig,
            userProviders: [.openAI, .anthropic]
        )

        #expect(changes.count == 2)
    }
}

// MARK: - ConfigChange Tests

@Suite("ConfigChange Tests")
struct ConfigChangeTests {

    // MARK: - ID Tests

    @Test("Each change type has unique ID")
    func testUniqueIds() {
        let changes: [ConfigChange] = [
            .newLanguage(provider: .openAI, language: .english, capability: "Transcription", quality: .excellent),
            .languageQualityImproved(provider: .openAI, language: .english, capability: "Transcription", oldTier: .limited, newTier: .excellent),
            .pricingIncrease(provider: .openAI, model: "whisper-1", oldCost: 0.006, newCost: 0.010),
            .pricingDecrease(provider: .openAI, model: "whisper-1", oldCost: 0.010, newCost: 0.006),
            .newModel(provider: .openAI, model: ModelRemoteConfig(id: "new-model", name: "New Model", isDefault: nil, tier: nil), capability: "Transcription"),
            .statusChange(provider: .openAI, oldStatus: .operational, newStatus: .degraded)
        ]

        let ids = Set(changes.map { $0.id })
        #expect(ids.count == changes.count)
    }

    // MARK: - Category Tests

    @Test("Language changes have correct category")
    func testLanguageChangeCategory() {
        let change1 = ConfigChange.newLanguage(provider: .openAI, language: .english, capability: "Test", quality: .excellent)
        let change2 = ConfigChange.languageQualityImproved(provider: .openAI, language: .english, capability: "Test", oldTier: .limited, newTier: .excellent)

        #expect(change1.category == .languages)
        #expect(change2.category == .languages)
    }

    @Test("Pricing changes have correct category")
    func testPricingChangeCategory() {
        let change1 = ConfigChange.pricingIncrease(provider: .openAI, model: "model", oldCost: 1, newCost: 2)
        let change2 = ConfigChange.pricingDecrease(provider: .openAI, model: "model", oldCost: 2, newCost: 1)

        #expect(change1.category == .pricing)
        #expect(change2.category == .pricing)
    }

    @Test("New model has correct category")
    func testNewModelCategory() {
        let model = ModelRemoteConfig(id: "id", name: "Name", isDefault: nil, tier: nil)
        let change = ConfigChange.newModel(provider: .openAI, model: model, capability: "Test")
        #expect(change.category == .models)
    }

    @Test("Status change has correct category")
    func testStatusChangeCategory() {
        let change = ConfigChange.statusChange(provider: .openAI, oldStatus: .operational, newStatus: .degraded)
        #expect(change.category == .status)
    }

    // MARK: - Icon Tests

    @Test("Each change type has valid icon")
    func testValidIcons() {
        let changes: [ConfigChange] = [
            .newLanguage(provider: .openAI, language: .english, capability: "Test", quality: .excellent),
            .languageQualityImproved(provider: .openAI, language: .english, capability: "Test", oldTier: .limited, newTier: .excellent),
            .pricingIncrease(provider: .openAI, model: "model", oldCost: 1, newCost: 2),
            .pricingDecrease(provider: .openAI, model: "model", oldCost: 2, newCost: 1),
            .newModel(provider: .openAI, model: ModelRemoteConfig(id: "id", name: "Name", isDefault: nil, tier: nil), capability: "Test"),
            .statusChange(provider: .openAI, oldStatus: .operational, newStatus: .degraded)
        ]

        for change in changes {
            #expect(!change.iconName.isEmpty)
        }
    }

    // MARK: - Title and Subtitle Tests

    @Test("Each change type has title and subtitle")
    func testTitleAndSubtitle() {
        let changes: [ConfigChange] = [
            .newLanguage(provider: .openAI, language: .english, capability: "Test", quality: .excellent),
            .languageQualityImproved(provider: .openAI, language: .english, capability: "Test", oldTier: .limited, newTier: .excellent),
            .pricingIncrease(provider: .openAI, model: "model", oldCost: 1, newCost: 2),
            .pricingDecrease(provider: .openAI, model: "model", oldCost: 2, newCost: 1),
            .newModel(provider: .openAI, model: ModelRemoteConfig(id: "id", name: "New Model", isDefault: nil, tier: nil), capability: "Test"),
            .statusChange(provider: .openAI, oldStatus: .operational, newStatus: .degraded)
        ]

        for change in changes {
            #expect(!change.title.isEmpty)
            #expect(!change.subtitle.isEmpty)
        }
    }

    // MARK: - isPositive Tests

    @Test("New language is positive")
    func testNewLanguageIsPositive() {
        let change = ConfigChange.newLanguage(provider: .openAI, language: .english, capability: "Test", quality: .excellent)
        #expect(change.isPositive == true)
    }

    @Test("Quality improvement is positive")
    func testQualityImprovementIsPositive() {
        let change = ConfigChange.languageQualityImproved(provider: .openAI, language: .english, capability: "Test", oldTier: .limited, newTier: .excellent)
        #expect(change.isPositive == true)
    }

    @Test("New model is positive")
    func testNewModelIsPositive() {
        let model = ModelRemoteConfig(id: "id", name: "Name", isDefault: nil, tier: nil)
        let change = ConfigChange.newModel(provider: .openAI, model: model, capability: "Test")
        #expect(change.isPositive == true)
    }

    @Test("Price decrease is positive")
    func testPriceDecreaseIsPositive() {
        let change = ConfigChange.pricingDecrease(provider: .openAI, model: "model", oldCost: 2, newCost: 1)
        #expect(change.isPositive == true)
    }

    @Test("Price increase is not positive")
    func testPriceIncreaseIsNotPositive() {
        let change = ConfigChange.pricingIncrease(provider: .openAI, model: "model", oldCost: 1, newCost: 2)
        #expect(change.isPositive == false)
    }

    @Test("Status to operational is positive")
    func testStatusToOperationalIsPositive() {
        let change = ConfigChange.statusChange(provider: .openAI, oldStatus: .degraded, newStatus: .operational)
        #expect(change.isPositive == true)
    }

    @Test("Status to degraded is not positive")
    func testStatusToDegradedIsNotPositive() {
        let change = ConfigChange.statusChange(provider: .openAI, oldStatus: .operational, newStatus: .degraded)
        #expect(change.isPositive == false)
    }
}

// MARK: - ConfigChangeCategory Tests

@Suite("ConfigChangeCategory Tests")
struct ConfigChangeCategoryTests {

    @Test("All cases have icon")
    func testAllCasesHaveIcon() {
        for category in ConfigChangeCategory.allCases {
            #expect(!category.iconName.isEmpty)
        }
    }

    @Test("All cases have raw value")
    func testAllCasesHaveRawValue() {
        #expect(ConfigChangeCategory.languages.rawValue == "Languages")
        #expect(ConfigChangeCategory.pricing.rawValue == "Pricing")
        #expect(ConfigChangeCategory.models.rawValue == "Models")
        #expect(ConfigChangeCategory.status.rawValue == "Status")
    }
}

// MARK: - RemoteConfig Model Tests

@Suite("RemoteConfig Model Tests")
struct RemoteConfigModelTests {

    @Test("ProviderRemoteConfig supports method works")
    func testProviderSupportsMethod() {
        let provider = TestDataFactory.makeProviderConfig(
            transcription: TestDataFactory.makeCapabilityConfig(enabled: true),
            translation: TestDataFactory.makeCapabilityConfig(enabled: false),
            powerMode: nil
        )

        #expect(provider.supports(.transcription) == true)
        #expect(provider.supports(.translation) == false)
        #expect(provider.supports(.powerMode) == false)
    }

    @Test("ProviderRemoteConfig capability method works")
    func testProviderCapabilityMethod() {
        let transcription = TestDataFactory.makeCapabilityConfig(enabled: true)
        let provider = TestDataFactory.makeProviderConfig(transcription: transcription)

        #expect(provider.capability(.transcription) != nil)
        #expect(provider.capability(.translation) == nil)
    }

    @Test("CapabilityRemoteConfig defaultModel works")
    func testCapabilityDefaultModel() {
        let models = [
            TestDataFactory.makeModelConfig(id: "model-1", name: "Model 1"),
            TestDataFactory.makeModelConfig(id: "model-2", name: "Model 2", isDefault: true)
        ]
        let capability = TestDataFactory.makeCapabilityConfig(models: models)

        #expect(capability.defaultModel?.id == "model-2")
    }

    @Test("CapabilityRemoteConfig defaultModel falls back to first")
    func testCapabilityDefaultModelFallback() {
        let models = [
            TestDataFactory.makeModelConfig(id: "model-1", name: "Model 1"),
            TestDataFactory.makeModelConfig(id: "model-2", name: "Model 2")
        ]
        let capability = TestDataFactory.makeCapabilityConfig(models: models)

        #expect(capability.defaultModel?.id == "model-1")
    }

    @Test("CapabilityRemoteConfig supportedLanguages works")
    func testCapabilitySupportedLanguages() {
        let capability = TestDataFactory.makeCapabilityConfig(
            languages: ["en": "excellent", "es": "good"]
        )

        let supported = capability.supportedLanguages
        #expect(supported.contains(.english))
        #expect(supported.contains(.spanish))
    }

    @Test("ModelRemoteConfig properties work")
    func testModelProperties() {
        let model = TestDataFactory.makeModelConfig(id: "1", name: "Test Model")
        #expect(model.id == "1")
        #expect(model.name == "Test Model")
    }

    @Test("PricingRemoteConfig estimatedCostPerMinute works for minute-based")
    func testPricingEstimateMinuteBased() {
        let pricing = TestDataFactory.makePricingConfig(unit: "minute", cost: 0.006)
        #expect(pricing.estimatedCostPerMinute == 0.006)
    }

    @Test("PricingRemoteConfig estimatedCostPerMinute works for second-based")
    func testPricingEstimateSecondBased() {
        let pricing = TestDataFactory.makePricingConfig(unit: "second", cost: 0.0001)
        #expect(pricing.estimatedCostPerMinute == 0.0001 * 60)
    }

    @Test("PricingRemoteConfig isUnitBased and isTokenBased work")
    func testPricingTypeProperties() {
        let unitPricing = TestDataFactory.makePricingConfig(unit: "minute", cost: 0.006)
        let tokenPricing = TestDataFactory.makePricingConfig(inputPerMToken: 0.5, outputPerMToken: 1.5)

        #expect(unitPricing.isUnitBased == true)
        #expect(unitPricing.isTokenBased == false)
        #expect(tokenPricing.isUnitBased == false)
        #expect(tokenPricing.isTokenBased == true)
    }
}
