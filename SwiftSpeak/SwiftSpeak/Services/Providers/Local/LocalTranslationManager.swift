//
//  LocalTranslationManager.swift
//  SwiftSpeak
//
//  Phase 10f: Bridge between service layer and SwiftUI's translationTask
//  Apple's Translation framework requires SwiftUI context - this manager
//  coordinates translation requests between the service layer and SwiftUI views.
//

import Foundation
import SwiftUI

#if canImport(Translation)
import Translation
#endif

/// Manages on-device translation using Apple's Translation framework
///
/// This class bridges the gap between our service layer (which can't use SwiftUI)
/// and Apple's Translation API (which requires SwiftUI's `.translationTask` modifier).
///
/// Usage:
/// 1. Service layer calls `requestTranslation(text:from:to:)`
/// 2. SwiftUI view observes `configuration` and has `.translationTask` attached
/// 3. When translation completes, `completeTranslation(with:)` is called
/// 4. The original caller receives the result via async/await
@MainActor
@Observable
final class LocalTranslationManager {

    // MARK: - Singleton

    static let shared = LocalTranslationManager()

    // MARK: - Published State (for SwiftUI observation)

    /// Current translation configuration - observed by SwiftUI views
    /// When this changes, the `.translationTask` modifier triggers
    #if canImport(Translation)
    var configuration: TranslationSession.Configuration?
    #endif

    /// Whether a translation is currently in progress
    var isTranslating: Bool = false

    // MARK: - Private State

    /// The text being translated
    private var pendingText: String?

    /// Continuation for async/await bridge
    private var continuation: CheckedContinuation<String, Error>?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Request a translation
    ///
    /// This method is called by `AppleTranslationService`. It sets up the configuration
    /// which triggers the SwiftUI `.translationTask` modifier in the view hierarchy.
    ///
    /// - Parameters:
    ///   - text: The text to translate
    ///   - sourceLanguage: Source language (nil for auto-detect)
    ///   - targetLanguage: Target language
    /// - Returns: The translated text
    /// - Throws: LocalProviderError if translation fails
    func requestTranslation(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language
    ) async throws -> String {
        #if canImport(Translation)
        guard !isTranslating else {
            throw LocalProviderError.appleTranslationFailed(reason: "Translation already in progress")
        }

        // Store pending text
        pendingText = text
        isTranslating = true

        // Create configuration to trigger SwiftUI
        let source = sourceLanguage.map { Locale.Language(identifier: languageCode(for: $0)) }
        let target = Locale.Language(identifier: languageCode(for: targetLanguage))

        // Use withCheckedThrowingContinuation to bridge async/await
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            // Setting configuration triggers the .translationTask in SwiftUI
            self.configuration = TranslationSession.Configuration(
                source: source,
                target: target
            )
        }
        #else
        throw LocalProviderError.appleTranslationNotAvailable
        #endif
    }

    /// Called by SwiftUI when translation completes
    ///
    /// The `.translationTask` modifier calls this with the translation result.
    ///
    /// - Parameter result: The translated text or error
    func completeTranslation(with result: Result<String, Error>) {
        defer {
            isTranslating = false
            pendingText = nil
            #if canImport(Translation)
            configuration = nil
            #endif
        }

        guard let continuation = self.continuation else { return }
        self.continuation = nil

        switch result {
        case .success(let translatedText):
            continuation.resume(returning: translatedText)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    /// Get the text that needs to be translated
    ///
    /// Called by the SwiftUI view to get the pending text for translation.
    var textToTranslate: String? {
        pendingText
    }

    /// Cancel any pending translation
    func cancel() {
        if let continuation = self.continuation {
            continuation.resume(throwing: LocalProviderError.appleTranslationFailed(reason: "Translation cancelled"))
            self.continuation = nil
        }
        isTranslating = false
        pendingText = nil
        #if canImport(Translation)
        configuration = nil
        #endif
    }

    // MARK: - Language Code Conversion

    private func languageCode(for language: Language) -> String {
        switch language {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .russian: return "ru"
        case .chinese: return "zh-Hans"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .arabic: return "ar"
        case .egyptianArabic: return "ar"
        case .polish: return "pl"
        }
    }
}

// MARK: - SwiftUI View Modifier

/// A view modifier that handles Apple Translation for the app
///
/// Add this to a high-level view (like RecordingView or ContentView) to enable
/// on-device translation throughout the app.
///
/// Usage:
/// ```swift
/// RecordingView()
///     .localTranslationHandler()
/// ```
@available(iOS 17.4, *)
struct LocalTranslationModifier: ViewModifier {
    @State private var manager = LocalTranslationManager.shared

    func body(content: Content) -> some View {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            content
                .translationTask(manager.configuration) { session in
                    await performTranslation(session: session)
                }
        } else {
            // iOS 17.4-17.x: Translation API exists but TranslationSession
            // can only be used with .translationPresentation (UI-based)
            content
        }
        #else
        content
        #endif
    }

    #if canImport(Translation)
    @available(iOS 18.0, *)
    private func performTranslation(session: TranslationSession) async {
        guard let text = manager.textToTranslate else {
            manager.completeTranslation(with: .failure(
                LocalProviderError.appleTranslationFailed(reason: "No text to translate")
            ))
            return
        }

        do {
            let response = try await session.translate(text)
            manager.completeTranslation(with: .success(response.targetText))
        } catch {
            manager.completeTranslation(with: .failure(
                LocalProviderError.appleTranslationFailed(reason: error.localizedDescription)
            ))
        }
    }
    #endif
}

@available(iOS 17.4, *)
extension View {
    /// Adds Apple Translation support to this view
    ///
    /// Place this on a high-level view to enable on-device translation.
    /// The `LocalTranslationManager` coordinates translation requests
    /// from the service layer.
    func localTranslationHandler() -> some View {
        modifier(LocalTranslationModifier())
    }
}
