//
//  AIProvider.swift
//  SwiftSpeak
//
//  AI provider definitions and capabilities
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - Unified AI Provider
/// A unified provider enum that covers all AI providers for transcription, translation, and power modes
public enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case elevenLabs = "elevenlabs"
    case deepgram = "deepgram"
    case local = "local"  // Renamed from ollama to support multiple local provider types
    // Phase 3 additions:
    case assemblyAI = "assemblyai"
    case deepL = "deepl"
    case azure = "azure"
    case appleSpeech = "applespeech"  // On-device SFSpeechRecognizer
    case whisperKit = "whisperkit"  // On-device WhisperKit transcription
    case parakeetMLX = "parakeetMLX"  // On-device Parakeet TDT v3 transcription (macOS only)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic Claude"
        case .google: return "Google Cloud"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local AI"
        case .assemblyAI: return "AssemblyAI"
        case .deepL: return "DeepL"
        case .azure: return "Azure Translator"
        case .appleSpeech: return "Apple Speech"
        case .whisperKit: return "WhisperKit"
        case .parakeetMLX: return "Parakeet MLX"
        }
    }

    public var shortName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Claude"
        case .google: return "Google"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .local: return "Local"
        case .assemblyAI: return "AssemblyAI"
        case .deepL: return "DeepL"
        case .azure: return "Azure"
        case .appleSpeech: return "Apple"
        case .whisperKit: return "WhisperKit"
        case .parakeetMLX: return "Parakeet"
        }
    }

    public var icon: String {
        switch self {
        case .openAI: return "brain"
        case .anthropic: return "sparkles"
        case .google: return "brain"  // Same as OpenAI - generic AI icon
        case .elevenLabs: return "waveform"
        case .deepgram: return "mic.fill"
        case .local: return "desktopcomputer"
        case .assemblyAI: return "waveform.circle.fill"
        case .deepL: return "character.book.closed.fill"
        case .azure: return "cloud.fill"
        case .appleSpeech: return "apple.logo"
        case .whisperKit: return "mic.fill"
        case .parakeetMLX: return "bird"
        }
    }

    public var description: String {
        switch self {
        case .openAI: return "Whisper for transcription, GPT for AI processing"
        case .anthropic: return "Advanced reasoning and safety-focused AI"
        case .google: return "STT, Translation, and Gemini for AI processing"
        case .elevenLabs: return "Speech recognition with free tier (2.5 hrs/month)"
        case .deepgram: return "Fast transcription with competitive pricing"
        case .local: return "Local AI (Ollama, LM Studio, or OpenAI-compatible)"
        case .assemblyAI: return "Fast, accurate transcription with speaker diarization"
        case .deepL: return "High-quality neural machine translation"
        case .azure: return "Microsoft Azure Translator for 100+ languages"
        case .appleSpeech: return "On-device speech recognition using Apple's Speech framework"
        case .whisperKit: return "On-device Whisper transcription using CoreML"
        case .parakeetMLX: return "On-device Parakeet TDT v3 transcription via MLX (macOS only)"
        }
    }

    /// Whether this provider requires an API key (cloud providers)
    public var requiresAPIKey: Bool {
        self != .local && self != .appleSpeech && self != .whisperKit && self != .parakeetMLX
    }

    /// Whether this is a local/self-hosted provider
    public var isLocalProvider: Bool {
        self == .local || self == .appleSpeech || self == .whisperKit || self == .parakeetMLX
    }

    // MARK: - Capability Support

    public var supportsTranscription: Bool {
        switch self {
        case .openAI, .elevenLabs, .deepgram, .local, .assemblyAI, .google, .appleSpeech, .whisperKit, .parakeetMLX: return true
        case .anthropic, .deepL, .azure: return false
        }
    }

    public var supportsTranslation: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local, .deepL, .azure: return true
        case .elevenLabs, .deepgram, .assemblyAI, .appleSpeech, .whisperKit, .parakeetMLX: return false
        }
    }

    public var supportsPowerMode: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local: return true
        case .elevenLabs, .deepgram, .assemblyAI, .deepL, .azure, .appleSpeech, .whisperKit, .parakeetMLX: return false
        }
    }

    public var supportedCategories: Set<ProviderUsageCategory> {
        var categories: Set<ProviderUsageCategory> = []
        if supportsTranscription { categories.insert(.transcription) }
        if supportsTranslation { categories.insert(.translation) }
        if supportsPowerMode { categories.insert(.powerMode) }
        return categories
    }

    /// Human-readable list of provider capabilities for display
    public var capabilities: [String] {
        var caps: [String] = []
        if supportsTranscription { caps.append("Transcription") }
        if supportsTranslation { caps.append("Translation") }
        if supportsPowerMode { caps.append("Power Mode") }
        return caps
    }

    // MARK: - STT Models (for transcription)

    /// Default STT models - for local providers, these are fetched dynamically
    public var availableSTTModels: [String] {
        switch self {
        case .openAI: return ["gpt-4o-transcribe", "gpt-4o-mini-transcribe", "whisper-1"]
        case .elevenLabs: return ["scribe_v1"]
        case .deepgram: return ["nova-2", "nova", "enhanced", "base"]
        case .local: return [] // Models are fetched dynamically from the local server
        case .assemblyAI: return ["best", "nano"]
        case .google: return ["default", "latest_long", "latest_short", "command_and_search", "telephony"]
        case .appleSpeech: return ["on-device"]
        case .whisperKit: return [] // Model selected via WhisperKitSettings
        case .parakeetMLX: return [] // Model selected via ParakeetMLXSettings
        case .anthropic, .deepL, .azure: return []
        }
    }

    public var defaultSTTModel: String? {
        switch self {
        case .openAI: return "gpt-4o-transcribe"  // Default to streaming-capable model
        case .elevenLabs: return "scribe_v1"
        case .deepgram: return "nova-2"
        case .local: return nil // Must be selected after connecting
        case .assemblyAI: return "best"
        case .google: return "default"  // Safest - supports all languages
        case .appleSpeech: return "on-device"
        case .whisperKit: return nil // Model selected via WhisperKitSettings
        case .parakeetMLX: return nil // Model selected via ParakeetMLXSettings
        case .anthropic, .deepL, .azure: return nil
        }
    }

    /// Whether this provider supports streaming transcription
    public var supportsStreamingTranscription: Bool {
        switch self {
        case .openAI, .deepgram, .assemblyAI, .google, .appleSpeech: return true
        case .elevenLabs, .local, .anthropic, .deepL, .azure, .whisperKit, .parakeetMLX: return false
        }
    }

    /// STT models that support streaming transcription (real-time WebSocket/gRPC)
    /// Returns empty array if provider doesn't support streaming
    public var streamingSTTModels: [String] {
        switch self {
        case .openAI: return ["gpt-4o-transcribe", "gpt-4o-mini-transcribe"]
        case .deepgram: return ["nova-2", "nova", "enhanced", "base"]  // All Deepgram models support streaming
        case .assemblyAI: return ["best", "nano"]  // All AssemblyAI models support streaming
        case .google: return ["default", "latest_long", "latest_short"]  // Google Cloud STT streaming models
        case .appleSpeech: return ["on-device"]  // Apple Speech streaming via SFSpeechAudioBufferRecognitionRequest
        case .elevenLabs, .local, .anthropic, .deepL, .azure, .whisperKit, .parakeetMLX: return []
        }
    }

    /// Check if a specific STT model supports streaming
    public func modelSupportsStreaming(_ model: String) -> Bool {
        streamingSTTModels.contains(model)
    }

    // MARK: - LLM Models (for translation/power mode)

    /// Default LLM models - for local providers, these are fetched dynamically
    public var availableLLMModels: [String] {
        switch self {
        case .openAI: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .anthropic: return ["claude-3-5-sonnet-latest", "claude-3-5-haiku-latest", "claude-3-opus-latest"]
        case .google: return ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]
        case .local: return [] // Models are fetched dynamically from the local server
        case .deepL: return ["default"]  // DeepL doesn't have model selection
        case .azure: return ["default"]  // Azure Translator doesn't have model selection
        case .elevenLabs, .deepgram, .assemblyAI, .appleSpeech, .whisperKit, .parakeetMLX: return []
        }
    }

    public var defaultLLMModel: String? {
        switch self {
        case .openAI: return "gpt-4o-mini"
        case .anthropic: return "claude-3-5-sonnet-latest"
        case .google: return "gemini-2.0-flash-exp"
        case .local: return nil // Must be selected after connecting
        case .deepL: return "default"
        case .azure: return "default"
        case .elevenLabs, .deepgram, .assemblyAI, .appleSpeech, .whisperKit, .parakeetMLX: return nil
        }
    }

    // MARK: - API Help

    public var apiKeyHelpURL: URL? {
        switch self {
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")
        case .google: return URL(string: "https://console.cloud.google.com/apis/library/speech.googleapis.com")
        case .elevenLabs: return URL(string: "https://elevenlabs.io/app/settings/api-keys")
        case .deepgram: return URL(string: "https://console.deepgram.com/project/api-keys")
        case .local: return URL(string: "https://ollama.ai") // Default to Ollama docs
        case .assemblyAI: return URL(string: "https://www.assemblyai.com/app/account")
        case .deepL: return URL(string: "https://www.deepl.com/account/summary")
        case .azure: return URL(string: "https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub/~/TextTranslation")
        case .appleSpeech, .whisperKit, .parakeetMLX: return nil  // No API key needed - on-device
        }
    }

    public var setupInstructions: String {
        switch self {
        case .openAI:
            return """
            1. Go to platform.openai.com
            2. Sign in or create an account
            3. Navigate to API Keys section
            4. Click "Create new secret key"
            5. Copy and paste the key here
            """
        case .anthropic:
            return """
            1. Go to console.anthropic.com
            2. Sign in or create an account
            3. Go to Settings → API Keys
            4. Click "Create Key"
            5. Copy and paste the key here
            """
        case .google:
            return """
            For Transcription (Speech-to-Text v2 API):

            1. Go to console.cloud.google.com
            2. Create or select a project
            3. Copy the Project ID (shown in project selector)

            4. Enable Speech-to-Text API:
               • APIs & Services → Library
               • Search "Cloud Speech-to-Text API"
               • Click ENABLE

            5. Create an API Key:
               • APIs & Services → Credentials
               • + CREATE CREDENTIALS → API key
               • IMPORTANT: Click "Edit API key"
               • Under "API restrictions" select either:
                 - "Don't restrict key" (easiest), OR
                 - "Restrict key" and add "Cloud Speech-to-Text API"

            6. Paste API Key and Project ID here

            Note: API key must be unrestricted or explicitly allow Speech-to-Text API.
            """
        case .elevenLabs:
            return """
            1. Go to elevenlabs.io
            2. Sign in or create an account
            3. Click your profile icon
            4. Go to Settings → API Keys
            5. Copy your API key
            """
        case .deepgram:
            return """
            1. Go to console.deepgram.com
            2. Sign in or create an account
            3. Create a new project
            4. Go to API Keys section
            5. Create and copy your key
            """
        case .local:
            return """
            Choose your local AI server type:

            Ollama:
            1. Install Ollama (ollama.ai)
            2. Pull models: ollama pull llama3.2
            3. Server runs on http://localhost:11434

            LM Studio:
            1. Download LM Studio
            2. Download a model from the app
            3. Start the local server
            4. Server runs on http://localhost:1234

            Other OpenAI-compatible:
            Enter your server's URL and optional API token.
            """
        case .assemblyAI:
            return """
            1. Go to assemblyai.com
            2. Sign in or create an account
            3. Go to Account settings
            4. Copy your API key
            5. Paste the key here
            """
        case .deepL:
            return """
            1. Go to deepl.com/pro
            2. Sign in or create an account
            3. Go to Account summary
            4. Scroll to "API Keys" section
            5. Create and copy your key
            """
        case .azure:
            return """
            1. Go to portal.azure.com
            2. Create a Translator resource
            3. Go to Keys and Endpoint
            4. Copy Key 1 or Key 2
            5. Note the region (e.g., eastus)
            """
        case .appleSpeech:
            return """
            Apple Speech Recognition is built into iOS and macOS.
            No setup required - just grant speech recognition permission when prompted.

            Supports 50+ languages with on-device processing.
            """
        case .whisperKit:
            return """
            WhisperKit runs Whisper models locally on your device.

            1. Go to Settings → Local Models
            2. Select a model size (larger = more accurate but slower)
            3. Download the model
            4. Enable for transcription

            Works offline with no API costs.
            """
        case .parakeetMLX:
            return """
            Parakeet MLX runs NVIDIA's Parakeet TDT v3 model locally on your Mac.

            1. Install Python 3.10+ if not already installed
            2. Run: pip install parakeet-mlx
            3. Go to Settings → Local Models
            4. Click "Check Installation" to verify
            5. Enable for transcription

            Supports 25 European languages. macOS only (Apple Silicon).
            """
        }
    }

    public var costPerMinute: Double {
        switch self {
        case .openAI: return 0.006
        case .elevenLabs: return 0.0
        case .deepgram: return 0.0043
        case .assemblyAI: return 0.00025  // $0.00025/second = $0.015/minute (universal model)
        case .anthropic, .google, .local, .deepL, .azure, .appleSpeech, .whisperKit, .parakeetMLX: return 0.0  // Per-character pricing doesn't translate to per-minute
        }
    }

}

// MARK: - Azure Region
/// Azure Translator regions for configuration
public enum AzureRegion: String, Codable, CaseIterable, Identifiable {
    case eastUS = "eastus"
    case eastUS2 = "eastus2"
    case westUS = "westus"
    case westUS2 = "westus2"
    case centralUS = "centralus"
    case northCentralUS = "northcentralus"
    case southCentralUS = "southcentralus"
    case westEurope = "westeurope"
    case northEurope = "northeurope"
    case southeastAsia = "southeastasia"
    case eastAsia = "eastasia"
    case australiaEast = "australiaeast"
    case brazilSouth = "brazilsouth"
    case canadaCentral = "canadacentral"
    case japanEast = "japaneast"
    case koreacentral = "koreacentral"
    case uksouth = "uksouth"
    case global = "global"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .eastUS: return "East US"
        case .eastUS2: return "East US 2"
        case .westUS: return "West US"
        case .westUS2: return "West US 2"
        case .centralUS: return "Central US"
        case .northCentralUS: return "North Central US"
        case .southCentralUS: return "South Central US"
        case .westEurope: return "West Europe"
        case .northEurope: return "North Europe"
        case .southeastAsia: return "Southeast Asia"
        case .eastAsia: return "East Asia"
        case .australiaEast: return "Australia East"
        case .brazilSouth: return "Brazil South"
        case .canadaCentral: return "Canada Central"
        case .japanEast: return "Japan East"
        case .koreacentral: return "Korea Central"
        case .uksouth: return "UK South"
        case .global: return "Global"
        }
    }
}

// MARK: - Provider Usage Category
public enum ProviderUsageCategory: String, Codable, CaseIterable, Identifiable {
    case transcription = "transcription"
    case translation = "translation"
    case formatting = "formatting"
    case powerMode = "power_mode"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .transcription: return "Transcription"
        case .translation: return "Translation"
        case .formatting: return "Formatting"
        case .powerMode: return "Power Mode"
        }
    }

    public var icon: String {
        switch self {
        case .transcription: return "waveform"
        case .translation: return "globe"
        case .formatting: return "text.badge.checkmark"
        case .powerMode: return "bolt.fill"
        }
    }

    public var description: String {
        switch self {
        case .transcription: return "Speech-to-text processing"
        case .translation: return "Text translation between languages"
        case .formatting: return "AI text formatting for contexts"
        case .powerMode: return "AI-powered voice workflows"
        }
    }

    public var color: Color {
        switch self {
        case .transcription: return .blue
        case .translation: return .purple
        case .formatting: return .teal
        case .powerMode: return .orange
        }
    }
}
