# SwiftSpeak Phase 3: Multi-Provider Support

> **Execution guide for Phase 3.** Follow this document step-by-step.
> Master project documentation: `/Users/pawelgawliczek/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`

## Overview

Add support for 9 unique AI providers across transcription, translation, and power mode capabilities. Each provider requires its own service implementation following existing patterns.

**Provider Matrix (9 unique providers):**

| Provider | Transcription | Translation | Power Mode | Auth Pattern |
|----------|:------------:|:-----------:|:----------:|--------------|
| OpenAI | ✅ Whisper | ✅ GPT | ✅ GPT | `Authorization: Bearer` |
| AssemblyAI | ✅ | ❌ | ❌ | `authorization: {key}` |
| Google Cloud | ✅ STT | ✅ Translation | ✅ Gemini | `x-goog-api-key` |
| Deepgram | ✅ | ❌ | ❌ | `Authorization: Token` |
| DeepL | ❌ | ✅ | ❌ | `Authorization: DeepL-Auth-Key` |
| Azure | ❌ | ✅ Translator | ❌ | `Ocp-Apim-Subscription-Key` |
| Amazon Translate | ❌ | ✅ (optional) | ❌ | AWS Sig V4 |
| Anthropic | ❌ | ❌ | ✅ Claude | `x-api-key` |
| Local (existing) | ✅ | ✅ | ✅ | Optional Bearer |

**Note:** OpenAI and Local providers already implemented in Phases 1-2.

---

## Progress Tracking

### Step 1: Update AIProvider Enum + Constants
- [ ] **Status: Pending**

### Step 2: AssemblyAI Transcription Service
- [ ] **Status: Pending**

### Step 3: Deepgram Transcription Service
- [ ] **Status: Pending**

### Step 4: Google Cloud Speech-to-Text Service
- [ ] **Status: Pending**

### Step 5: DeepL Translation Service
- [ ] **Status: Pending**

### Step 6: Google Cloud Translation Service
- [ ] **Status: Pending**

### Step 7: Azure Translator Service
- [ ] **Status: Pending**

### Step 8: Anthropic Claude Service
- [ ] **Status: Pending**

### Step 9: Google Gemini Service
- [ ] **Status: Pending**

### Step 10: Provider Factory + Orchestrator Updates
- [ ] **Status: Pending**

### Step 11: Settings UI Updates
- [ ] **Status: Pending**

### Step 12: Tests
- [ ] **Status: Pending**

---

## API Research Summary

### Transcription Providers

#### AssemblyAI
```
Upload: POST https://api.assemblyai.com/v2/upload
Create: POST https://api.assemblyai.com/v2/transcript
Poll:   GET  https://api.assemblyai.com/v2/transcript/{id}
Header: authorization: {API_KEY}
Flow: Upload audio → Create transcript job → Poll until status=completed
```

#### Deepgram
```
POST https://api.deepgram.com/v1/listen?model=nova-2&language=en
Header: Authorization: Token {API_KEY}
Body: Binary audio data (multipart/form-data)
Response: { "results": { "channels": [{ "alternatives": [{ "transcript": "..." }] }] } }
```

#### Google Cloud Speech-to-Text
```
POST https://speech.googleapis.com/v2/projects/{PROJECT_ID}/locations/global/recognizers/_:recognize
Header: x-goog-api-key: {API_KEY}
Body: { "config": { "languageCodes": ["en-US"], "model": "long" }, "content": "<base64_audio>" }
Response: { "results": [{ "alternatives": [{ "transcript": "..." }] }] }
```

### Translation Providers

#### DeepL
```
POST https://api.deepl.com/v2/translate
Header: Authorization: DeepL-Auth-Key {API_KEY}
Body: { "text": ["Hello"], "target_lang": "DE" }
Response: { "translations": [{ "detected_source_language": "EN", "text": "Hallo" }] }
```

#### Google Cloud Translation
```
POST https://translation.googleapis.com/language/translate/v2
Header: x-goog-api-key: {API_KEY}
Body: { "q": "Hello", "target": "de", "format": "text" }
Response: { "data": { "translations": [{ "translatedText": "Hallo" }] } }
```

#### Azure Translator
```
POST https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=de
Headers:
  - Ocp-Apim-Subscription-Key: {API_KEY}
  - Ocp-Apim-Subscription-Region: {REGION}
Body: [{ "text": "Hello" }]
Response: [{ "translations": [{ "text": "Hallo", "to": "de" }] }]
```

### Power Mode Providers

#### Anthropic Claude
```
POST https://api.anthropic.com/v1/messages
Headers:
  - x-api-key: {API_KEY}
  - anthropic-version: 2023-06-01
Body: { "model": "claude-3-5-sonnet-20241022", "max_tokens": 4096, "messages": [...] }
Response: { "content": [{ "type": "text", "text": "..." }] }
```

#### Google Gemini
```
POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
Header: x-goog-api-key: {API_KEY}
Body: { "contents": [{ "role": "user", "parts": [{ "text": "..." }] }] }
Response: { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
```

---

## Implementation Order

```
┌─────────────────────────────────────────────────────────────────────┐
│ Step 1: Update AIProvider enum + Constants                          │
│ (Add new cases: assemblyAI, deepL, azure)                           │
└──────────────────────────────┬──────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Step 2-4: Transcription Providers (can run in parallel)                               │
│ ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────────────┐│
│ │ AssemblyAI STT      │  │ Deepgram STT        │  │ Google Cloud STT                ││
│ │ (upload+poll flow)  │  │ (direct upload)     │  │ (base64 encoding)               ││
│ └─────────────────────┘  └─────────────────────┘  └─────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Step 5-7: Translation Providers (can run in parallel)                                 │
│ ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────────────────┐│
│ │ DeepL Translation   │  │ Google Translation  │  │ Azure Translator                ││
│ └─────────────────────┘  └─────────────────────┘  │ (+region config)                ││
│                                                   └─────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Step 8-9: Power Mode Providers (can run in parallel)                                  │
│ ┌─────────────────────────────────┐  ┌──────────────────────────────────────────────┐│
│ │ Anthropic Claude                │  │ Google Gemini                                ││
│ │ (anthropic-version header)      │  │ (different response format)                  ││
│ └─────────────────────────────────┘  └──────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Step 10: Provider Factory + Orchestrator Updates                                      │
│ (Wire all providers into TranscriptionOrchestrator)                                   │
└──────────────────────────────────────────────────────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Step 11: Settings UI Updates                                                          │
│ (Provider-specific configuration fields: region for Azure, project ID for Google)    │
└──────────────────────────────────────────────────────────────────────────────────────┘
                               ↓
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Step 12: Tests (per provider)                                                         │
│ Unit tests for each service + integration tests for orchestrator                      │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Execution Strategy: Parallel Agent Implementation

To maximize efficiency, spawn multiple agents in parallel during implementation:

**Round 1: Foundation (sequential)**
- Step 1: Update AIProvider enum + Constants (required before provider services)

**Round 2: Transcription Providers (3 agents in parallel)**
```
Agent 1: AssemblyAITranscriptionService + tests
Agent 2: DeepgramTranscriptionService + tests
Agent 3: GoogleSTTService + tests
```

**Round 3: Translation Providers (3 agents in parallel)**
```
Agent 1: DeepLTranslationService + tests
Agent 2: GoogleTranslationService + tests
Agent 3: AzureTranslatorService + tests
```

**Round 4: Power Mode Providers (2 agents in parallel)**
```
Agent 1: AnthropicService + tests
Agent 2: GeminiService + tests
```

**Round 5: Integration (sequential)**
- Step 10: ProviderFactory + Orchestrator updates
- Step 11: Settings UI updates
- Step 12: Integration tests

---

## Step 1: Update AIProvider Enum + Constants

**File:** `SwiftSpeak/Shared/Models.swift`

Add new cases to AIProvider enum:
```swift
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"           // Covers STT, Translation, Gemini
    case elevenLabs = "elevenlabs"
    case deepgram = "deepgram"
    case local = "local"
    // NEW:
    case assemblyAI = "assemblyai"
    case deepL = "deepl"
    case azure = "azure"
    case amazonTranslate = "amazon_translate"  // Optional

    var supportsTranscription: Bool {
        switch self {
        case .openAI, .assemblyAI, .google, .deepgram, .local: return true
        default: return false
        }
    }

    var supportsTranslation: Bool {
        switch self {
        case .openAI, .google, .deepL, .azure, .amazonTranslate, .local: return true
        default: return false
        }
    }

    var supportsPowerMode: Bool {
        switch self {
        case .openAI, .anthropic, .google, .local: return true
        default: return false
        }
    }
}
```

**File:** `SwiftSpeak/Shared/Constants.swift`

Add API endpoints:
```swift
struct APIEndpoints {
    // Existing
    static let openAIWhisper = "https://api.openai.com/v1/audio/transcriptions"
    static let openAIChat = "https://api.openai.com/v1/chat/completions"

    // Transcription
    static let assemblyAIUpload = "https://api.assemblyai.com/v2/upload"
    static let assemblyAITranscript = "https://api.assemblyai.com/v2/transcript"
    static let deepgram = "https://api.deepgram.com/v1/listen"
    static let googleSTT = "https://speech.googleapis.com/v2/projects"

    // Translation
    static let deepL = "https://api.deepl.com/v2/translate"
    static let googleTranslation = "https://translation.googleapis.com/language/translate/v2"
    static let azureTranslator = "https://api.cognitive.microsofttranslator.com/translate"

    // Power Mode
    static let anthropic = "https://api.anthropic.com/v1/messages"
    static let gemini = "https://generativelanguage.googleapis.com/v1beta/models"
}
```

---

## Step 2: AssemblyAI Transcription Service

**Create:** `Services/Providers/AssemblyAI/AssemblyAITranscriptionService.swift`

```swift
final class AssemblyAITranscriptionService: TranscriptionProvider {
    let providerId: AIProvider = .assemblyAI
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { "default" }

    private let apiKey: String
    private let apiClient: APIClient

    func transcribe(audioURL: URL, language: Language?) async throws -> String {
        // Step 1: Upload audio file
        let uploadURL = try await uploadAudio(audioURL)

        // Step 2: Create transcript job
        let transcriptId = try await createTranscriptJob(audioURL: uploadURL, language: language)

        // Step 3: Poll for completion
        return try await pollForResult(transcriptId: transcriptId)
    }

    private func uploadAudio(_ url: URL) async throws -> String {
        // POST to /v2/upload with binary audio
    }

    private func createTranscriptJob(audioURL: String, language: Language?) async throws -> String {
        // POST to /v2/transcript with audio_url
    }

    private func pollForResult(transcriptId: String, maxAttempts: Int = 60) async throws -> String {
        // GET /v2/transcript/{id} until status == "completed"
    }
}
```

**Test file:** `SwiftSpeakTests/Services/AssemblyAITranscriptionServiceTests.swift`

---

## Step 3: Deepgram Transcription Service

**Create:** `Services/Providers/Deepgram/DeepgramTranscriptionService.swift`

```swift
final class DeepgramTranscriptionService: TranscriptionProvider {
    let providerId: AIProvider = .deepgram
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { modelName }

    private let apiKey: String
    private let modelName: String  // nova-2, nova, enhanced, base

    func transcribe(audioURL: URL, language: Language?) async throws -> String {
        var urlComponents = URLComponents(string: APIEndpoints.deepgram)!
        urlComponents.queryItems = [
            URLQueryItem(name: "model", value: modelName),
            URLQueryItem(name: "language", value: language?.code ?? "en")
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Data(contentsOf: audioURL)

        // Parse response.results.channels[0].alternatives[0].transcript
    }
}
```

**Test file:** `SwiftSpeakTests/Services/DeepgramTranscriptionServiceTests.swift`

---

## Step 4: Google Cloud Speech-to-Text Service

**Create:** `Services/Providers/Google/GoogleSTTService.swift`

```swift
final class GoogleSTTService: TranscriptionProvider {
    let providerId: AIProvider = .google
    var isConfigured: Bool { !apiKey.isEmpty && !projectId.isEmpty }
    var model: String { modelName }

    private let apiKey: String
    private let projectId: String  // Required for Google Cloud
    private let modelName: String  // long, short, telephony, etc.

    func transcribe(audioURL: URL, language: Language?) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        let url = URL(string: "\(APIEndpoints.googleSTT)/\(projectId)/locations/global/recognizers/_:recognize")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "config": [
                "languageCodes": [language?.googleCode ?? "en-US"],
                "model": modelName
            ],
            "content": base64Audio
        ]

        // Parse response.results[0].alternatives[0].transcript
    }
}
```

**Note:** Google Cloud requires a Project ID in addition to API key.

**Test file:** `SwiftSpeakTests/Services/GoogleSTTServiceTests.swift`

---

## Step 5: DeepL Translation Service

**Create:** `Services/Providers/DeepL/DeepLTranslationService.swift`

```swift
final class DeepLTranslationService: TranslationProvider {
    let providerId: AIProvider = .deepL
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { "default" }
    var supportedLanguages: [Language] { Language.allCases }

    private let apiKey: String

    func translate(text: String, from: Language?, to: Language) async throws -> String {
        var request = URLRequest(url: URL(string: APIEndpoints.deepL)!)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "text": [text],
            "target_lang": to.deepLCode
        ]
        if let sourceLanguage = from {
            body["source_lang"] = sourceLanguage.deepLCode
        }

        // Parse response.translations[0].text
    }
}
```

**Note:** DeepL uses uppercase language codes (DE, EN, FR, etc.)

**Test file:** `SwiftSpeakTests/Services/DeepLTranslationServiceTests.swift`

---

## Step 6: Google Cloud Translation Service

**Create:** `Services/Providers/Google/GoogleTranslationService.swift`

```swift
final class GoogleTranslationService: TranslationProvider {
    let providerId: AIProvider = .google
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { "default" }
    var supportedLanguages: [Language] { Language.allCases }

    private let apiKey: String

    func translate(text: String, from: Language?, to: Language) async throws -> String {
        var urlComponents = URLComponents(string: APIEndpoints.googleTranslation)!
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "q": text,
            "target": to.googleCode,
            "format": "text"
        ]
        if let sourceLanguage = from {
            body["source"] = sourceLanguage.googleCode
        }

        // Parse response.data.translations[0].translatedText
    }
}
```

**Test file:** `SwiftSpeakTests/Services/GoogleTranslationServiceTests.swift`

---

## Step 7: Azure Translator Service

**Create:** `Services/Providers/Azure/AzureTranslatorService.swift`

```swift
final class AzureTranslatorService: TranslationProvider {
    let providerId: AIProvider = .azure
    var isConfigured: Bool { !apiKey.isEmpty && !region.isEmpty }
    var model: String { "default" }
    var supportedLanguages: [Language] { Language.allCases }

    private let apiKey: String
    private let region: String  // Required: eastus, westeurope, etc.

    func translate(text: String, from: Language?, to: Language) async throws -> String {
        var urlComponents = URLComponents(string: APIEndpoints.azureTranslator)!
        urlComponents.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "to", value: to.azureCode)
        ]
        if let sourceLanguage = from {
            urlComponents.queryItems?.append(URLQueryItem(name: "from", value: sourceLanguage.azureCode))
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [["text": text]]

        // Parse response[0].translations[0].text
    }
}
```

**Note:** Azure requires both API key AND region. Update AIProviderConfig to store region.

**Update AIProviderConfig:**
```swift
struct AIProviderConfig {
    // Existing fields...
    var azureRegion: String?  // For Azure Translator
    var googleProjectId: String?  // For Google Cloud STT
}
```

**Test file:** `SwiftSpeakTests/Services/AzureTranslatorServiceTests.swift`

---

## Step 8: Anthropic Claude Service

**Create:** `Services/Providers/Anthropic/AnthropicService.swift`

```swift
final class AnthropicService: FormattingProvider {
    let providerId: AIProvider = .anthropic
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { modelName }

    private let apiKey: String
    private let modelName: String  // claude-3-5-sonnet-20241022, claude-3-opus-20240229, etc.

    func format(text: String, mode: FormattingMode, customPrompt: String?) async throws -> String {
        var request = URLRequest(url: URL(string: APIEndpoints.anthropic)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = customPrompt ?? mode.systemPrompt
        let body: [String: Any] = [
            "model": modelName,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        // Parse response.content[0].text
    }
}
```

**Note:** Anthropic uses `x-api-key` header and `anthropic-version` header.

**Test file:** `SwiftSpeakTests/Services/AnthropicServiceTests.swift`

---

## Step 9: Google Gemini Service

**Create:** `Services/Providers/Google/GeminiService.swift`

```swift
final class GeminiService: FormattingProvider {
    let providerId: AIProvider = .google
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { modelName }

    private let apiKey: String
    private let modelName: String  // gemini-2.0-flash-exp, gemini-1.5-pro, etc.

    func format(text: String, mode: FormattingMode, customPrompt: String?) async throws -> String {
        let url = URL(string: "\(APIEndpoints.gemini)/\(modelName):generateContent")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = customPrompt ?? mode.systemPrompt
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemPrompt)\n\n\(text)"]
                    ]
                ]
            ]
        ]

        // Parse response.candidates[0].content.parts[0].text
    }
}
```

**Test file:** `SwiftSpeakTests/Services/GeminiServiceTests.swift`

---

## Step 10: Provider Factory + Orchestrator Updates

**Create:** `Services/ProviderFactory.swift`

```swift
@MainActor
struct ProviderFactory {
    private let settings: SharedSettings

    func createTranscriptionProvider(for provider: AIProvider) -> TranscriptionProvider? {
        guard let config = settings.getAIProviderConfig(for: provider) else { return nil }

        switch provider {
        case .openAI:
            return OpenAITranscriptionService(config: config)
        case .assemblyAI:
            return AssemblyAITranscriptionService(apiKey: config.apiKey)
        case .deepgram:
            return DeepgramTranscriptionService(apiKey: config.apiKey, model: config.transcriptionModel ?? "nova-2")
        case .google:
            guard let projectId = config.googleProjectId else { return nil }
            return GoogleSTTService(apiKey: config.apiKey, projectId: projectId, model: config.transcriptionModel ?? "long")
        case .local:
            // Existing local provider logic
        default:
            return nil
        }
    }

    func createTranslationProvider(for provider: AIProvider) -> TranslationProvider? {
        guard let config = settings.getAIProviderConfig(for: provider) else { return nil }

        switch provider {
        case .openAI:
            return OpenAITranslationService(config: config)
        case .deepL:
            return DeepLTranslationService(apiKey: config.apiKey)
        case .google:
            return GoogleTranslationService(apiKey: config.apiKey)
        case .azure:
            guard let region = config.azureRegion else { return nil }
            return AzureTranslatorService(apiKey: config.apiKey, region: region)
        case .local:
            // Existing local provider logic
        default:
            return nil
        }
    }

    func createFormattingProvider(for provider: AIProvider) -> FormattingProvider? {
        guard let config = settings.getAIProviderConfig(for: provider) else { return nil }

        switch provider {
        case .openAI:
            return OpenAIFormattingService(config: config)
        case .anthropic:
            return AnthropicService(apiKey: config.apiKey, model: config.powerModeModel ?? "claude-3-5-sonnet-20241022")
        case .google:
            return GeminiService(apiKey: config.apiKey, model: config.powerModeModel ?? "gemini-2.0-flash-exp")
        case .local:
            // Existing local provider logic
        default:
            return nil
        }
    }
}
```

**Update:** `Services/Orchestration/TranscriptionOrchestrator.swift`

Replace direct service instantiation with ProviderFactory calls.

---

## Step 11: Settings UI Updates

**File:** `Views/SettingsView.swift` (ProviderEditorSheet)

Add provider-specific configuration fields:

```swift
// For Google Cloud providers
if config.provider == .google {
    TextField("Project ID", text: $projectId)
        .textContentType(.none)
}

// For Azure Translator
if config.provider == .azure {
    Picker("Region", selection: $azureRegion) {
        ForEach(AzureRegion.allCases) { region in
            Text(region.displayName).tag(region)
        }
    }
}
```

**Add:** Azure region enum
```swift
enum AzureRegion: String, CaseIterable, Identifiable {
    case eastUS = "eastus"
    case westUS = "westus"
    case westEurope = "westeurope"
    case southeastAsia = "southeastasia"
    // ... etc

    var id: String { rawValue }
    var displayName: String { ... }
}
```

---

## Step 12: Tests

**Unit tests per provider:**

| Test File | Covers |
|-----------|--------|
| `AssemblyAITranscriptionServiceTests.swift` | Upload, create job, poll, error handling |
| `DeepgramTranscriptionServiceTests.swift` | Direct upload, response parsing |
| `GoogleSTTServiceTests.swift` | Base64 encoding, project ID handling |
| `DeepLTranslationServiceTests.swift` | Language code mapping, response parsing |
| `GoogleTranslationServiceTests.swift` | Query param auth, response parsing |
| `AzureTranslatorServiceTests.swift` | Region header, response parsing |
| `AnthropicServiceTests.swift` | Version header, message format |
| `GeminiServiceTests.swift` | Generate content format, response parsing |

**Integration tests:**
- `ProviderFactoryTests.swift` - Factory creates correct provider types
- `TranscriptionOrchestratorTests.swift` - Orchestrator uses correct providers

---

## Files to Create

| File | Purpose |
|------|---------|
| `Services/Providers/AssemblyAI/AssemblyAITranscriptionService.swift` | AssemblyAI STT |
| `Services/Providers/Deepgram/DeepgramTranscriptionService.swift` | Deepgram STT |
| `Services/Providers/Google/GoogleSTTService.swift` | Google Cloud STT |
| `Services/Providers/Google/GoogleTranslationService.swift` | Google Translation |
| `Services/Providers/Google/GeminiService.swift` | Gemini LLM |
| `Services/Providers/DeepL/DeepLTranslationService.swift` | DeepL Translation |
| `Services/Providers/Azure/AzureTranslatorService.swift` | Azure Translator |
| `Services/Providers/Anthropic/AnthropicService.swift` | Anthropic Claude |
| `Services/ProviderFactory.swift` | Unified provider creation |
| `SwiftSpeakTests/Services/AssemblyAITranscriptionServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/DeepgramTranscriptionServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/GoogleSTTServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/GoogleTranslationServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/GeminiServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/DeepLTranslationServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/AzureTranslatorServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/AnthropicServiceTests.swift` | Tests |
| `SwiftSpeakTests/Services/ProviderFactoryTests.swift` | Tests |

## Files to Modify

| File | Changes |
|------|---------|
| `Shared/Models.swift` | Add AIProvider cases, language code extensions |
| `Shared/Constants.swift` | Add API endpoint constants |
| `SharedSettings.swift` | Add azureRegion, googleProjectId fields |
| `Services/Orchestration/TranscriptionOrchestrator.swift` | Use ProviderFactory |
| `Views/SettingsView.swift` | Provider-specific config UI |

---

## Language Code Extensions

**Add to Models.swift (Language enum):**

```swift
extension Language {
    var deepLCode: String {
        switch self {
        case .english: return "EN"
        case .spanish: return "ES"
        case .french: return "FR"
        case .german: return "DE"
        // ... map all languages
        }
    }

    var googleCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        // ... lowercase ISO codes
        }
    }

    var azureCode: String {
        // Same as googleCode for most languages
        googleCode
    }

    var assemblyAICode: String? {
        // AssemblyAI supports: en, es, fr, de, it, pt, nl, hi, ja, zh, fi, ko, pl, ru, tr, uk, vi
        switch self {
        case .english: return "en"
        // ... map supported languages, nil for unsupported
        }
    }
}
```

---

## Verification Checklist

- [ ] AIProvider enum has all new cases (assemblyAI, deepL, azure)
- [ ] Each provider service implements correct protocol
- [ ] API authentication headers are correct per provider
- [ ] Language codes map correctly for each provider
- [ ] Google Cloud providers require Project ID
- [ ] Azure Translator requires region
- [ ] ProviderFactory creates all provider types
- [ ] Orchestrator uses factory for provider creation
- [ ] Settings UI shows provider-specific fields
- [ ] Unit tests pass for all new services
- [ ] Integration tests verify orchestrator uses correct providers
- [ ] Existing OpenAI and Local providers still work

---

## Notes

- **No streaming in Phase 3** - will be added in Phase 4 with Power Mode
- AssemblyAI uses polling pattern (upload → create job → poll for result)
- Google Cloud APIs use `x-goog-api-key` header, not `Authorization: Bearer`
- DeepL uses uppercase language codes (DE not de)
- Azure requires both API key AND region in headers
- Amazon Translate deferred due to AWS Sig V4 complexity
