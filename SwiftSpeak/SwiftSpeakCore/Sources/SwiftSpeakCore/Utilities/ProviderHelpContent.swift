//
//  ProviderHelpContent.swift
//  SwiftSpeak
//
//  Setup guide data model and content for provider configuration help
//
//  SHARED: This file is used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftUI

// MARK: - Setup Step

/// A single step in the provider setup process
public struct SetupStep: Identifiable {
    public let id = UUID()
    public let number: Int
    public let title: String
    public let description: String?
    public let actionURL: URL?  // Deep link if applicable

    public init(
        number: Int,
        title: String,
        description: String? = nil,
        actionURL: URL? = nil
    ) {
        self.number = number
        self.title = title
        self.description = description
        self.actionURL = actionURL
    }
}

// MARK: - Provider Setup Guide

/// Complete setup guide for a provider
public struct ProviderSetupGuide {
    public let provider: AIProvider
    public let steps: [SetupStep]
    public let tips: [String]
    public let estimatedCost: String          // e.g., "~$0.006/minute"
    public let freeCredits: String?           // e.g., "$5 for new accounts"
    public let bestFor: [String]              // e.g., ["Transcription", "Translation"]
    public let websiteURL: URL?
    public let apiKeyURL: URL?
    public let pricingURL: URL?
    public let documentationURL: URL?

    public init(
        provider: AIProvider,
        steps: [SetupStep],
        tips: [String] = [],
        estimatedCost: String,
        freeCredits: String? = nil,
        bestFor: [String] = [],
        websiteURL: URL? = nil,
        apiKeyURL: URL? = nil,
        pricingURL: URL? = nil,
        documentationURL: URL? = nil
    ) {
        self.provider = provider
        self.steps = steps
        self.tips = tips
        self.estimatedCost = estimatedCost
        self.freeCredits = freeCredits
        self.bestFor = bestFor
        self.websiteURL = websiteURL
        self.apiKeyURL = apiKeyURL ?? provider.apiKeyHelpURL
        self.pricingURL = pricingURL
        self.documentationURL = documentationURL
    }
}

// MARK: - Provider Help Database

/// Static database of setup guides for all providers
public struct ProviderHelpDatabase {

    /// Get setup guide for a specific provider
    public static func guide(for provider: AIProvider) -> ProviderSetupGuide {
        switch provider {
        case .openAI:
            return openAIGuide
        case .anthropic:
            return anthropicGuide
        case .google:
            return googleGuide
        case .deepgram:
            return deepgramGuide
        case .elevenLabs:
            return elevenLabsGuide
        case .local:
            return localGuide
        case .assemblyAI:
            return assemblyAIGuide
        case .deepL:
            return deepLGuide
        case .azure:
            return azureGuide
        case .appleSpeech:
            return appleSpeechGuide
        case .whisperKit:
            return whisperKitGuide
        }
    }

    /// Get all available guides
    public static var allGuides: [ProviderSetupGuide] {
        AIProvider.allCases.map { guide(for: $0) }
    }

    // MARK: - Individual Provider Guides

    public static let openAIGuide = ProviderSetupGuide(
        provider: .openAI,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to platform.openai.com",
                description: "Open the OpenAI developer platform in your browser",
                actionURL: URL(string: "https://platform.openai.com")
            ),
            SetupStep(
                number: 2,
                title: "Sign in or create an account",
                description: "Use your email or continue with Google/Microsoft"
            ),
            SetupStep(
                number: 3,
                title: "Navigate to API Keys section",
                description: "Click your profile icon, then select 'API keys'"
            ),
            SetupStep(
                number: 4,
                title: "Click \"Create new secret key\"",
                description: "Give your key a name like 'SwiftSpeak'"
            ),
            SetupStep(
                number: 5,
                title: "Copy the key and paste here",
                description: "Important: You won't be able to see the key again!"
            )
        ],
        tips: [
            "$5 free credits for new accounts",
            "Best all-around provider choice",
            "Supports transcription, translation, and Power Mode",
            "Whisper is the most accurate transcription model"
        ],
        estimatedCost: "~$0.006/minute",
        freeCredits: "$5 for new accounts",
        bestFor: ["Transcription", "Translation", "Power Mode"],
        websiteURL: URL(string: "https://openai.com"),
        apiKeyURL: URL(string: "https://platform.openai.com/api-keys"),
        pricingURL: URL(string: "https://openai.com/pricing"),
        documentationURL: URL(string: "https://platform.openai.com/docs")
    )

    public static let anthropicGuide = ProviderSetupGuide(
        provider: .anthropic,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to console.anthropic.com",
                description: "Open the Anthropic Console in your browser",
                actionURL: URL(string: "https://console.anthropic.com")
            ),
            SetupStep(
                number: 2,
                title: "Create account",
                description: "Phone verification is required for new accounts"
            ),
            SetupStep(
                number: 3,
                title: "Go to Settings > API Keys",
                description: "Navigate to the API Keys section"
            ),
            SetupStep(
                number: 4,
                title: "Click \"Create Key\"",
                description: "Give your key a descriptive name"
            ),
            SetupStep(
                number: 5,
                title: "Copy the key and paste here",
                description: "Store this key securely - you won't see it again"
            )
        ],
        tips: [
            "Best for nuanced AI responses and safety",
            "Claude excels at complex formatting tasks",
            "Great for Power Mode with extended context",
            "No transcription support - pair with another provider"
        ],
        estimatedCost: "~$0.003-0.015/1K tokens",
        freeCredits: nil,
        bestFor: ["Translation", "Power Mode", "Complex Formatting"],
        websiteURL: URL(string: "https://anthropic.com"),
        apiKeyURL: URL(string: "https://console.anthropic.com/settings/keys"),
        pricingURL: URL(string: "https://anthropic.com/pricing"),
        documentationURL: URL(string: "https://docs.anthropic.com")
    )

    public static let googleGuide = ProviderSetupGuide(
        provider: .google,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to aistudio.google.com",
                description: "Open Google AI Studio in your browser",
                actionURL: URL(string: "https://aistudio.google.com")
            ),
            SetupStep(
                number: 2,
                title: "Sign in with Google",
                description: "Use your Google account to sign in"
            ),
            SetupStep(
                number: 3,
                title: "Click \"Get API Key\"",
                description: "Find this button in the left sidebar"
            ),
            SetupStep(
                number: 4,
                title: "Create key in new or existing project",
                description: "A new project is fine for most users"
            ),
            SetupStep(
                number: 5,
                title: "Copy the key and paste here",
                description: "Your API key will be displayed once created"
            )
        ],
        tips: [
            "Generous free tier available",
            "Best language coverage (100+ languages)",
            "Gemini models are fast and cost-effective",
            "Great for translation to less common languages"
        ],
        estimatedCost: "Free tier available",
        freeCredits: "15 requests/minute free",
        bestFor: ["Translation", "Power Mode", "Rare Languages"],
        websiteURL: URL(string: "https://ai.google.dev"),
        apiKeyURL: URL(string: "https://aistudio.google.com/app/apikey"),
        pricingURL: URL(string: "https://ai.google.dev/pricing"),
        documentationURL: URL(string: "https://ai.google.dev/docs")
    )

    public static let deepgramGuide = ProviderSetupGuide(
        provider: .deepgram,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to deepgram.com",
                description: "Open the Deepgram website",
                actionURL: URL(string: "https://deepgram.com")
            ),
            SetupStep(
                number: 2,
                title: "Create a free account",
                description: "Sign up with email or continue with Google/GitHub"
            ),
            SetupStep(
                number: 3,
                title: "Go to Dashboard > API Keys",
                description: "Navigate to the API Keys section in your dashboard"
            ),
            SetupStep(
                number: 4,
                title: "Create a new API key",
                description: "Name it 'SwiftSpeak' for easy identification"
            ),
            SetupStep(
                number: 5,
                title: "Copy the key and paste here",
                description: "Your key will be shown once - save it securely"
            )
        ],
        tips: [
            "$200 in free credits for new accounts!",
            "Fastest transcription speeds available",
            "Great for real-time transcription",
            "Nova-2 model offers best accuracy"
        ],
        estimatedCost: "~$0.0043/minute",
        freeCredits: "$200 for new accounts",
        bestFor: ["Fast Transcription", "Real-time Audio"],
        websiteURL: URL(string: "https://deepgram.com"),
        apiKeyURL: URL(string: "https://console.deepgram.com/project/api-keys"),
        pricingURL: URL(string: "https://deepgram.com/pricing"),
        documentationURL: URL(string: "https://developers.deepgram.com/docs")
    )

    public static let elevenLabsGuide = ProviderSetupGuide(
        provider: .elevenLabs,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to elevenlabs.io",
                description: "Open the ElevenLabs website",
                actionURL: URL(string: "https://elevenlabs.io")
            ),
            SetupStep(
                number: 2,
                title: "Create an account",
                description: "Sign up with email or continue with Google"
            ),
            SetupStep(
                number: 3,
                title: "Go to Profile > API Keys",
                description: "Click your profile icon, then Settings"
            ),
            SetupStep(
                number: 4,
                title: "Copy your API key",
                description: "Your API key is already generated for you"
            ),
            SetupStep(
                number: 5,
                title: "Paste the key here",
                description: "That's it! You're ready to go"
            )
        ],
        tips: [
            "2.5 hours free transcription per month",
            "Premium voice quality",
            "Best for voice cloning projects",
            "Supports 29 languages"
        ],
        estimatedCost: "Free tier: 2.5 hrs/month",
        freeCredits: "2.5 hours/month free",
        bestFor: ["Transcription", "Voice Quality"],
        websiteURL: URL(string: "https://elevenlabs.io"),
        apiKeyURL: URL(string: "https://elevenlabs.io/app/settings/api-keys"),
        pricingURL: URL(string: "https://elevenlabs.io/pricing"),
        documentationURL: URL(string: "https://docs.elevenlabs.io")
    )

    public static let localGuide = ProviderSetupGuide(
        provider: .local,
        steps: [
            SetupStep(
                number: 1,
                title: "Choose your local AI server",
                description: "Ollama, LM Studio, or any OpenAI-compatible server"
            ),
            SetupStep(
                number: 2,
                title: "Install the software",
                description: "Download from ollama.ai, lmstudio.ai, or your preferred provider"
            ),
            SetupStep(
                number: 3,
                title: "Download a model",
                description: "For Ollama: ollama pull llama3.2 or ollama pull whisper"
            ),
            SetupStep(
                number: 4,
                title: "Start the server",
                description: "The server runs automatically on localhost"
            ),
            SetupStep(
                number: 5,
                title: "Enter the server URL",
                description: "Default: http://localhost:11434 for Ollama"
            )
        ],
        tips: [
            "100% free - no API costs!",
            "Complete privacy - data stays on your device",
            "Requires Mac/PC running during use",
            "Quality depends on model choice",
            "Great for sensitive or confidential content"
        ],
        estimatedCost: "Free (local compute)",
        freeCredits: "Always free",
        bestFor: ["Privacy", "Offline Use", "No API Costs"],
        websiteURL: URL(string: "https://ollama.ai"),
        apiKeyURL: nil, // No API key needed
        pricingURL: nil,
        documentationURL: URL(string: "https://ollama.ai/docs")
    )

    public static let assemblyAIGuide = ProviderSetupGuide(
        provider: .assemblyAI,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to assemblyai.com",
                description: "Open the AssemblyAI website",
                actionURL: URL(string: "https://assemblyai.com")
            ),
            SetupStep(
                number: 2,
                title: "Create a free account",
                description: "Sign up with email or continue with Google/GitHub"
            ),
            SetupStep(
                number: 3,
                title: "Go to Account Settings",
                description: "Click your profile to access settings"
            ),
            SetupStep(
                number: 4,
                title: "Copy your API key",
                description: "Your API key is displayed in the account settings"
            ),
            SetupStep(
                number: 5,
                title: "Paste the key here",
                description: "You're all set!"
            )
        ],
        tips: [
            "Fast and accurate transcription",
            "Speaker diarization (identify speakers)",
            "Supports 17 languages",
            "Great for meetings and interviews"
        ],
        estimatedCost: "~$0.015/minute",
        freeCredits: "$50 for new accounts",
        bestFor: ["Transcription", "Speaker Identification"],
        websiteURL: URL(string: "https://assemblyai.com"),
        apiKeyURL: URL(string: "https://www.assemblyai.com/app/account"),
        pricingURL: URL(string: "https://www.assemblyai.com/pricing"),
        documentationURL: URL(string: "https://www.assemblyai.com/docs")
    )

    public static let deepLGuide = ProviderSetupGuide(
        provider: .deepL,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to deepl.com/pro",
                description: "Open the DeepL Pro page",
                actionURL: URL(string: "https://www.deepl.com/pro")
            ),
            SetupStep(
                number: 2,
                title: "Create an account",
                description: "Sign up for DeepL API Free or Pro"
            ),
            SetupStep(
                number: 3,
                title: "Go to Account summary",
                description: "Access your account settings"
            ),
            SetupStep(
                number: 4,
                title: "Scroll to API Keys",
                description: "Find the API Keys section at the bottom"
            ),
            SetupStep(
                number: 5,
                title: "Create and copy your key",
                description: "Generate a new key and paste it here"
            )
        ],
        tips: [
            "Best-in-class translation quality",
            "Free tier: 500,000 characters/month",
            "Supports 31 languages",
            "Preserves formatting and style"
        ],
        estimatedCost: "Free tier available",
        freeCredits: "500K chars/month free",
        bestFor: ["Translation Quality", "European Languages"],
        websiteURL: URL(string: "https://www.deepl.com"),
        apiKeyURL: URL(string: "https://www.deepl.com/account/summary"),
        pricingURL: URL(string: "https://www.deepl.com/pro-api"),
        documentationURL: URL(string: "https://www.deepl.com/docs-api")
    )

    public static let azureGuide = ProviderSetupGuide(
        provider: .azure,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to portal.azure.com",
                description: "Open the Azure Portal",
                actionURL: URL(string: "https://portal.azure.com")
            ),
            SetupStep(
                number: 2,
                title: "Create a Translator resource",
                description: "Search for 'Translator' and create a new resource"
            ),
            SetupStep(
                number: 3,
                title: "Choose your region",
                description: "Select a region close to you for lower latency"
            ),
            SetupStep(
                number: 4,
                title: "Go to Keys and Endpoint",
                description: "Find this in the resource's left menu"
            ),
            SetupStep(
                number: 5,
                title: "Copy Key 1 or Key 2",
                description: "Also note your region for configuration"
            )
        ],
        tips: [
            "100+ languages supported",
            "2 million characters free per month",
            "Enterprise-grade reliability",
            "Custom translator available for domain-specific terms"
        ],
        estimatedCost: "2M chars/month free",
        freeCredits: "2M characters/month",
        bestFor: ["Translation", "Enterprise", "Rare Languages"],
        websiteURL: URL(string: "https://azure.microsoft.com/products/ai-services/translator"),
        apiKeyURL: URL(string: "https://portal.azure.com/#view/Microsoft_Azure_ProjectOxford/CognitiveServicesHub/~/TextTranslation"),
        pricingURL: URL(string: "https://azure.microsoft.com/pricing/details/cognitive-services/translator"),
        documentationURL: URL(string: "https://docs.microsoft.com/azure/cognitive-services/translator")
    )

    public static let appleSpeechGuide = ProviderSetupGuide(
        provider: .appleSpeech,
        steps: [
            SetupStep(
                number: 1,
                title: "Grant Speech Recognition Permission",
                description: "When prompted, allow SwiftSpeak to use speech recognition"
            ),
            SetupStep(
                number: 2,
                title: "That's it!",
                description: "Apple Speech Recognition is built into iOS and macOS - no account or API key needed"
            )
        ],
        tips: [
            "100% free - no API costs ever",
            "Complete privacy - all processing on device",
            "Works offline after language download",
            "50+ languages supported",
            "Best for quick dictation tasks"
        ],
        estimatedCost: "Free (on-device)",
        freeCredits: "Always free",
        bestFor: ["Privacy", "Offline Use", "No Setup"],
        websiteURL: URL(string: "https://developer.apple.com/documentation/speech"),
        apiKeyURL: nil, // No API key needed
        pricingURL: nil,
        documentationURL: URL(string: "https://developer.apple.com/documentation/speech")
    )

    public static let whisperKitGuide = ProviderSetupGuide(
        provider: .whisperKit,
        steps: [
            SetupStep(
                number: 1,
                title: "Go to Settings → Local Models",
                description: "Open the Local Models section in SwiftSpeak settings"
            ),
            SetupStep(
                number: 2,
                title: "Select a WhisperKit model",
                description: "Choose a model size based on your accuracy and speed needs"
            ),
            SetupStep(
                number: 3,
                title: "Download the model",
                description: "The model will be downloaded to your device (requires internet)"
            ),
            SetupStep(
                number: 4,
                title: "Enable WhisperKit",
                description: "Toggle on the provider to use it for transcription"
            )
        ],
        tips: [
            "100% free - no API costs ever",
            "Complete privacy - all processing on device",
            "Works completely offline after download",
            "Larger models are more accurate but slower",
            "large-v3-turbo offers best balance of speed and accuracy"
        ],
        estimatedCost: "Free (on-device)",
        freeCredits: "Always free",
        bestFor: ["Privacy", "Offline Use", "Accuracy"],
        websiteURL: URL(string: "https://github.com/argmaxinc/WhisperKit"),
        apiKeyURL: nil, // No API key needed
        pricingURL: nil,
        documentationURL: URL(string: "https://github.com/argmaxinc/WhisperKit")
    )
}

// MARK: - Provider Recommendation

/// Recommendation for a use case
public struct ProviderRecommendation: Identifiable {
    public let id = UUID()
    public let useCase: String
    public let description: String
    public let icon: String
    public let iconColor: Color
    public let recommendedProvider: AIProvider
    public let alternativeProviders: [AIProvider]
    public let reasoning: String

    public init(useCase: String, description: String, icon: String, iconColor: Color, recommendedProvider: AIProvider, alternativeProviders: [AIProvider], reasoning: String) {
        self.useCase = useCase
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
        self.recommendedProvider = recommendedProvider
        self.alternativeProviders = alternativeProviders
        self.reasoning = reasoning
    }
}

/// Provider recommendations for common use cases
public struct ProviderRecommendations {
    public static let allRecommendations: [ProviderRecommendation] = [
        ProviderRecommendation(
            useCase: "Just Transcription",
            description: "Convert speech to text only",
            icon: "waveform",
            iconColor: .blue,
            recommendedProvider: .openAI,
            alternativeProviders: [.deepgram, .assemblyAI, .elevenLabs],
            reasoning: "OpenAI Whisper offers the best accuracy across all languages"
        ),
        ProviderRecommendation(
            useCase: "Transcription + Translation",
            description: "Speak in one language, get text in another",
            icon: "globe",
            iconColor: .purple,
            recommendedProvider: .openAI,
            alternativeProviders: [.google, .deepL],
            reasoning: "OpenAI handles both transcription and translation with one API key"
        ),
        ProviderRecommendation(
            useCase: "Best Translation Quality",
            description: "Highest quality translations",
            icon: "text.book.closed.fill",
            iconColor: .teal,
            recommendedProvider: .deepL,
            alternativeProviders: [.openAI, .google],
            reasoning: "DeepL is widely regarded as having the best translation quality"
        ),
        ProviderRecommendation(
            useCase: "Power Mode & AI Agents",
            description: "Full AI capabilities with tools",
            icon: "bolt.fill",
            iconColor: .orange,
            recommendedProvider: .openAI,
            alternativeProviders: [.anthropic, .google],
            reasoning: "OpenAI offers the best balance of capabilities, speed, and cost"
        ),
        ProviderRecommendation(
            useCase: "Privacy First",
            description: "Keep all data on your device",
            icon: "lock.shield.fill",
            iconColor: .green,
            recommendedProvider: .local,
            alternativeProviders: [],
            reasoning: "Local AI processes everything on your Mac - no data leaves your device"
        ),
        ProviderRecommendation(
            useCase: "Budget Conscious",
            description: "Minimize API costs",
            icon: "dollarsign.circle.fill",
            iconColor: .yellow,
            recommendedProvider: .google,
            alternativeProviders: [.deepgram, .elevenLabs],
            reasoning: "Google offers a generous free tier with good quality"
        )
    ]
}

// MARK: - Preview

#Preview("Provider Setup Guide - OpenAI") {
    NavigationStack {
        List {
            Section {
                ForEach(ProviderHelpDatabase.openAIGuide.steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.number)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.accent)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.callout.weight(.medium))
                            if let desc = step.description {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Setup Steps")
            }

            Section {
                ForEach(ProviderHelpDatabase.openAIGuide.tips, id: \.self) { tip in
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(tip)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Tips")
            }
        }
        .navigationTitle("Setting up OpenAI")
    }
    .preferredColorScheme(.dark)
}
