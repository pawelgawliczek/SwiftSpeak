//
//  TextToSpeechService.swift
//  SwiftSpeak
//
//  Phase 17: Text-to-Speech service for Power Mode output actions
//  Uses AVSpeechSynthesizer to read results aloud
//

import Foundation
import AVFoundation

// MARK: - Text to Speech Service

@MainActor
final class TextToSpeechService: NSObject {

    // MARK: - Types

    enum TTSError: Error, LocalizedError {
        case synthesisInProgress
        case invalidVoice(String)
        case speechFailed(String)

        var errorDescription: String? {
            switch self {
            case .synthesisInProgress:
                return "Speech synthesis already in progress"
            case .invalidVoice(let identifier):
                return "Voice not found: \(identifier)"
            case .speechFailed(let message):
                return "Speech failed: \(message)"
            }
        }
    }

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var currentContinuation: CheckedContinuation<Void, Error>?
    private var isSpeaking = false

    /// Default speech rate (0.0 - 1.0)
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    /// Default pitch multiplier (0.5 - 2.0)
    var pitchMultiplier: Float = 1.0

    /// Default volume (0.0 - 1.0)
    var volume: Float = 1.0

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Methods

    /// Speak the given text
    /// - Parameters:
    ///   - text: The text to speak
    ///   - voice: Optional voice identifier (e.g., "com.apple.ttsbundle.Samantha-compact")
    ///   - rate: Optional speech rate override
    /// - Throws: TTSError if speech fails
    func speak(
        text: String,
        voice: String? = nil,
        rate: Float? = nil
    ) async throws {
        guard !isSpeaking else {
            throw TTSError.synthesisInProgress
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate ?? self.rate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume

        // Set voice if specified
        if let voiceIdentifier = voice {
            if let selectedVoice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                utterance.voice = selectedVoice
            } else {
                // Try to find by language
                utterance.voice = AVSpeechSynthesisVoice(language: voiceIdentifier)
            }
        } else {
            // Use default voice for device language
            utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        }

        isSpeaking = true

        try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, Error>) in
            guard let self = self else {
                continuation.resume(throwing: TTSError.speechFailed("Service deallocated"))
                return
            }

            self.currentContinuation = continuation
            self.synthesizer.speak(utterance)
        }
    }

    /// Stop any ongoing speech
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false

        if let continuation = currentContinuation {
            continuation.resume(throwing: CancellationError())
            currentContinuation = nil
        }
    }

    /// Pause ongoing speech
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }

    /// Resume paused speech
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    // MARK: - Voice Helpers

    /// Get all available voices
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    /// Get voices for a specific language
    static func voices(for languageCode: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(languageCode)
        }
    }

    /// Get the default voice for the current language
    static var defaultVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    /// Get display-friendly voice info
    static func voiceDisplayInfo() -> [(id: String, name: String, language: String)] {
        AVSpeechSynthesisVoice.speechVoices().map { voice in
            (
                id: voice.identifier,
                name: voice.name,
                language: voice.language
            )
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = false
            if let continuation = currentContinuation {
                continuation.resume()
                currentContinuation = nil
            }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = false
            // Continuation already handled in stop()
        }
    }
}
