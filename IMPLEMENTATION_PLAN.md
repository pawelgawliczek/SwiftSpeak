# iOS Voice Keyboard App - Implementation Plan

## App Name: SwiftSpeak

## Project Location: `~/projects/SwiftSpeak`

## Product Overview

A custom iOS keyboard app for voice transcription, translation, and AI formatting. Users switch to the SwiftSpeak keyboard, tap a mic button, speak, and text is inserted into any app.

---

## Business Model (V1: Bring Your Own Key)

Users provide their own API keys. Subscription unlocks features.
Supports cloud APIs (OpenAI, Anthropic, Google) AND local LLMs (Ollama, LM Studio, OpenAI-compatible).

**Key Value Proposition:** Users pay for app features (subscription) + their own API costs (BYOK).
This is **40-70% cheaper** than hosted competitors like Wispr Flow or Otter.ai.

### Free Tier - $0
- Basic transcription only
- 1 provider (OpenAI Whisper)
- 3 predefined templates (Email, Formal, Casual)
- Limited to X transcriptions/day

### Pro Tier - $6.99/month, $59.99/year, $99 lifetime
- **Unlimited transcriptions**
- Multiple providers (OpenAI, ElevenLabs, Deepgram)
- Translation feature
- Unlimited custom templates

### Power Tier - $12.99/month, $99.99/year, $199 lifetime
- Everything in Pro
- **Power Modes** - Voice-activated AI agents with capabilities
- AI can ask clarifying questions (quick-tap UI)
- Web search capability
- Bash/Computer use capability
- Code execution capability
- Full-screen workspace with refinement mode
- Version history navigation
- **Local AI Support** - Ollama, LM Studio, and any OpenAI-compatible server

---

## Competitive Analysis & Pricing Strategy

### Why BYOK Model Works

Users pay OpenAI directly for API usage:
- Whisper transcription: $0.006/min ($0.36/hour)
- GPT-4o-mini formatting: ~$0.0001/request

**Typical monthly API costs for users:**

| Usage Level | Transcriptions | API Cost |
|-------------|----------------|----------|
| Light | 50 × 30sec | ~$0.15 |
| Moderate | 150 × 30sec | ~$0.45 |
| Heavy | 400 × 1min | ~$1.20 |
| Power User | 500+ × 1min | ~$3.00 |

### Total Cost vs Competitors

**Moderate user (150 transcriptions/month):**

| App | Monthly Cost | SwiftSpeak Saves |
|-----|--------------|------------------|
| **SwiftSpeak Pro** | **$7.44** ($6.99 + $0.45 API) | — |
| **SwiftSpeak Power** | **$13.44** ($12.99 + $0.45 API) | — |
| Otter.ai Pro | $8.33-16.99 | 11-56% |
| Wispr Flow | $12-15 | 38-50% |
| Otter.ai Business | $20-30 | 63-75% |

**Heavy user (400 transcriptions/month):**

| App | Monthly Cost | SwiftSpeak Saves |
|-----|--------------|------------------|
| **SwiftSpeak Pro** | **$8.19** ($6.99 + $1.20 API) | — |
| **SwiftSpeak Power** | **$14.19** ($12.99 + $1.20 API) | — |
| Otter.ai Pro | $16.99 | 52% |
| Wispr Flow | $12-15 | 5-32% (Pro tier) |
| Otter.ai Business | $20-30 | 53-73% |

### Competitive Positioning

```
Price Scale (Monthly)
$0        $5        $10        $15        $20        $25        $30
|---------|---------|---------|---------|---------|---------|
   Whisper    SwiftSpeak   SwiftSpeak    Wispr      Otter
   Memos      Pro          Power         Flow       Business
   $4.99      $6.99        $12.99        $12-15     $20-30
```

### Feature Comparison

| Feature | SwiftSpeak Pro ($6.99) | Wispr Flow ($12-15) | Otter.ai Pro ($8.33) |
|---------|------------------------|---------------------|----------------------|
| iOS Keyboard | ✅ | ✅ | ❌ |
| Unlimited transcriptions | ✅ | ✅ | ❌ (1,200 min cap) |
| AI formatting modes | ✅ | ✅ | ❌ |
| Translation | ✅ | ✅ | ❌ |
| Multi-provider choice | ✅ | ❌ | ❌ |
| Local LLM (Ollama) | ✅ | ❌ | ❌ |
| Transparent API costs | ✅ | ❌ | ❌ |
| Lifetime option | ✅ $99 | ❌ | ❌ |

| Feature | SwiftSpeak Power ($12.99) | Wispr Flow ($12-15) |
|---------|---------------------------|---------------------|
| Voice AI agents | ✅ | ❌ |
| Web search capability | ✅ | ❌ |
| Code execution | ✅ | ❌ |
| Custom Power Modes | ✅ | ❌ |
| Lifetime option | ✅ $199 | ❌ |

### Lifetime Value Proposition

| App | Lifetime Price | Break-even vs Monthly |
|-----|----------------|----------------------|
| **SwiftSpeak Pro** | **$99** | 14 months |
| **SwiftSpeak Power** | **$199** | 15 months |
| Superwhisper | $249 | — |
| Wispr Flow | ❌ None | — |
| Otter.ai | ❌ None | — |

### Key Marketing Messages

1. **"Wispr Flow features at half the price"** - Power tier matches Wispr at $12.99 but adds AI agents
2. **"No minute caps, ever"** - Unlike Otter (1,200 min) or Whisper Memos (15 min limit)
3. **"Pay once, use forever"** - $99/$199 lifetime attracts subscription-averse users
4. **"Your keys, your control"** - Transparency, no vendor lock-in, Ollama for $0 costs
5. **"See exactly what you pay"** - No hidden markups on API usage

---

## Future: Hosted Option (V2+)

For users who don't want to manage API keys:
- SwiftSpeak handles all API calls
- Words-based pricing (like Wispr Flow)
- Premium subscription tier

---

## Core Features

### 1. Transcribe Button (Free)
- Tap → app opens → auto-records → Whisper transcription → auto-return
- Language auto-detection

### 2. Translate Button (Pro)
- Tap → app opens → record → Whisper → LLM translation → auto-return
- Source language: auto-detect or manual selection
- Target language: dropdown selection

### 3. Formatting Modes (Dropdown)
**Free modes:**
- Raw (no processing)
- Email (professional email format)
- Formal (official/business tone)
- Casual (friendly, conversational)

**Pro features:**
- Custom templates with user-defined prompts (NOT YET IMPLEMENTED)
- Template editor in settings (NOT YET IMPLEMENTED)

### 4. Power Modes (Power Tier)
- Voice-activated AI workflows with capabilities
- Web search, bash/computer use, code execution
- Full-screen workspace with refinement and version history

---

## Architecture

### V1: Client-Side (Bring Your Own Key)

For V1, all API calls are made directly from the iOS app.
No backend required (except optional community sharing later).

```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftSpeak iOS App                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Keyboard   │  │  Main App   │  │  Power Mode View    │  │
│  │  Extension  │  │  (Record)   │  │  (Full workspace)   │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          │                                   │
│              Unified AI Provider Layer                       │
│   ┌──────────────────────────────────────────────────────┐  │
│   │  AIProvider (enum) - One API key per provider        │  │
│   │  - openAI      (STT + LLM)                           │  │
│   │  - anthropic   (LLM only)                            │  │
│   │  - google      (LLM only)                            │  │
│   │  - elevenLabs  (STT only)                            │  │
│   │  - deepgram    (STT only)                            │  │
│   │  - local       (STT + LLM, Ollama/LM Studio/OpenAI)  │  │
│   │                                                      │  │
│   │  AIProviderConfig - Different model per capability   │  │
│   │  - transcriptionModel: "whisper-1"                   │  │
│   │  - translationModel:   "gpt-4o-mini"                 │  │
│   │  - powerModeModel:     "gpt-4o"                      │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
               ↓
         Provider APIs (OpenAI, Anthropic, Google, etc.)
```

### Provider Architecture (As Implemented)

The app uses a **unified AI provider architecture** where each provider has:
1. **One API key** that enables the provider
2. **Enabled capabilities** (transcription, translation, power mode)
3. **Different model per capability** - users can assign different models to each use case

```swift
// Unified AI Provider enum - covers all providers
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case elevenLabs = "elevenlabs"
    case deepgram = "deepgram"
    case local = "local"  // Ollama, LM Studio, or OpenAI-compatible

    var displayName: String { ... }
    var shortName: String { ... }
    var icon: String { ... }
    var description: String { ... }
    var requiresAPIKey: Bool { ... }     // false for local providers
    var isLocalProvider: Bool { ... }    // true for .local
    var costPerMinute: Double { ... }
    var apiKeyHelpURL: URL? { ... }
    var setupInstructions: String { ... }

    // Capability support
    var supportsTranscription: Bool { ... }  // OpenAI, ElevenLabs, Deepgram, Local
    var supportsTranslation: Bool { ... }    // OpenAI, Anthropic, Google, Local
    var supportsPowerMode: Bool { ... }      // OpenAI, Anthropic, Google, Local
    var supportedCategories: Set<ProviderUsageCategory> { ... }

    // Available models per type (for local providers, fetched dynamically)
    var availableSTTModels: [String] { ... }   // e.g., ["whisper-1"]
    var availableLLMModels: [String] { ... }   // e.g., ["gpt-4o", "gpt-4o-mini"]
    var defaultSTTModel: String? { ... }
    var defaultLLMModel: String? { ... }
}

// Local Provider Types - supports multiple local AI server types
enum LocalProviderType: String, Codable, CaseIterable, Identifiable {
    case ollama = "ollama"           // Ollama native API
    case lmStudio = "lm_studio"      // LM Studio (OpenAI-compatible)
    case openAICompatible = "openai_compatible"  // Any OpenAI-compatible server

    var displayName: String { ... }  // "Ollama", "LM Studio", etc.
    var icon: String { ... }
    var description: String { ... }
    var defaultEndpoint: String { ... }  // http://localhost:11434, etc.
    var modelsEndpoint: String { ... }   // /api/tags or /v1/models
    var chatEndpoint: String { ... }     // /api/chat or /v1/chat/completions
}

// Local Provider Configuration
struct LocalProviderConfig: Codable, Equatable {
    var type: LocalProviderType           // Ollama, LM Studio, or OpenAI-compatible
    var baseURL: String                   // Server URL (e.g., http://192.168.1.50:11434)
    var authToken: String?                // Optional API token for secured servers
    var defaultModel: String?             // Default model for this provider
    var streamingEnabled: Bool            // Enable streaming responses
    var timeoutSeconds: Int               // Request timeout (5, 10, 20, 30, 60)
}

// Provider Configuration - one API key, different model per capability
struct AIProviderConfig: Codable, Identifiable, Equatable {
    var provider: AIProvider
    var apiKey: String
    var endpoint: String?                           // Legacy, for backward compatibility
    var usageCategories: Set<ProviderUsageCategory> // Which capabilities are enabled
    var localConfig: LocalProviderConfig?           // For local providers only
    var cachedModels: [String]?                     // Models from last connection test

    // MODEL PER CAPABILITY - allows different models for each use case
    var transcriptionModel: String?    // STT model (e.g., "whisper-1")
    var translationModel: String?      // LLM model for translation (e.g., "gpt-4o-mini")
    var powerModeModel: String?        // LLM model for power mode (e.g., "gpt-4o")

    var isConfiguredForTranscription: Bool { ... }
    var isConfiguredForTranslation: Bool { ... }
    var isConfiguredForPowerMode: Bool { ... }
    var isLocalProviderConfigured: Bool { ... }     // For local providers

    func model(for category: ProviderUsageCategory) -> String? { ... }
    var modelSummary: String { ... }
    var detailedModelSummary: [(ProviderUsageCategory, String)] { ... }
}
```

### Provider Usage Categories

```swift
enum ProviderUsageCategory: String, Codable, CaseIterable {
    case transcription = "transcription"  // STT processing
    case translation = "translation"      // Text translation
    case powerMode = "power_mode"         // Power Mode AI workflows

    var displayName: String { ... }       // "Transcription", etc.
    var description: String { ... }       // "Speech to text", etc.
    var icon: String { ... }              // "mic.fill", etc.
}
```

### Example: OpenAI Configuration

A user adds OpenAI with one API key, then assigns different models to each capability:

```swift
AIProviderConfig(
    provider: .openAI,
    apiKey: "sk-xxx",
    usageCategories: [.transcription, .translation, .powerMode],
    transcriptionModel: "whisper-1",     // For voice-to-text
    translationModel: "gpt-4o-mini",     // For translation (cheaper)
    powerModeModel: "gpt-4o"             // For Power Mode (more capable)
)
```

### Supported Providers

| Provider | Transcription | Translation | Power Mode | Models |
|----------|:-------------:|:-----------:|:----------:|--------|
| OpenAI | ✅ | ✅ | ✅ | STT: whisper-1 / LLM: gpt-4o, gpt-4o-mini |
| Anthropic | ❌ | ✅ (via LLM) | ✅ | claude-3-5-sonnet-latest, claude-3-5-haiku-latest, claude-3-opus-latest |
| Google | ✅ (STT) | ✅ | ✅ (Gemini) | STT: long, short / LLM: gemini-2.0-flash-exp, gemini-1.5-pro |
| AssemblyAI | ✅ | ❌ | ❌ | default (upload + poll pattern) |
| Deepgram | ✅ | ❌ | ❌ | nova-2, nova, enhanced, base |
| DeepL | ❌ | ✅ | ❌ | default (dedicated translation API) |
| Azure | ❌ | ✅ | ❌ | Translator API (requires region) |
| ElevenLabs | ✅ | ❌ | ❌ | scribe_v1 (2.5 hrs/month free) - UI only |
| **Local AI** | ✅ | ✅ | ✅ | Models fetched dynamically from server |

### Local AI Provider Types (Power Tier Only)

| Type | Description | Default Endpoint | API Format |
|------|-------------|------------------|------------|
| **Ollama** | Popular local LLM server | http://localhost:11434 | Ollama native (/api/tags, /api/chat) |
| **LM Studio** | Desktop app with local models | http://localhost:1234 | OpenAI-compatible (/v1/models, /v1/chat/completions) |
| **Other OpenAI-compatible** | Any server with OpenAI API | http://localhost:8080 | OpenAI-compatible (/v1/models, /v1/chat/completions) |

**Local Provider Features:**
- **Test Connection**: Validates server connectivity and fetches available models
- **Model Auto-Discovery**: Models are loaded dynamically after successful connection
- **Optional Authentication**: Bearer token auth for secured servers
- **Streaming Support**: Enable/disable streaming responses
- **Configurable Timeout**: 5s, 10s, 20s, 30s, or 60s request timeout

### Settings UI: Provider Editor

When editing a provider, users see:

```
┌─────────────────────────────────────────────────────────┐
│  [OpenAI icon]  OpenAI                                  │
│  Whisper for transcription, GPT for AI processing      │
├─────────────────────────────────────────────────────────┤
│  CONFIGURATION                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ API Key: •••••••••••••••••sk-abc              🔒  │  │
│  └───────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  CAPABILITIES & MODELS                                  │
│                                                         │
│  [🎤] Transcription                              ✓     │
│       Speech to text conversion                         │
│       Model: [whisper-1 ▼]                             │
│                                                         │
│  [🌍] Translation                                ✓     │
│       Translate text to other languages                 │
│       Model: [gpt-4o-mini ▼]                           │
│                                                         │
│  [⚡] Power Mode                                 ✓     │
│       AI-powered voice workflows                        │
│       Model: [gpt-4o ▼]                                │
│                                                         │
│  [↻ Refresh Models]                         ✓ Updated  │
├─────────────────────────────────────────────────────────┤
│  ▶ How to get your API key                              │
└─────────────────────────────────────────────────────────┘
```

**Key Features:**
- Toggle capabilities on/off independently
- Select different model for each enabled capability
- "Refresh Models" fetches latest models from provider API
- Provider-specific setup instructions and help links

### Settings UI: Local Provider Editor

When editing a local AI provider, users see:

```
┌─────────────────────────────────────────────────────────┐
│  [🖥️]  Local AI                                         │
│  Local AI (Ollama, LM Studio, or OpenAI-compatible)    │
├─────────────────────────────────────────────────────────┤
│  SERVER CONFIGURATION                                   │
│                                                         │
│  Provider Type                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │ 🖥️ Ollama                                     ▼   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  Server URL                                             │
│  ┌───────────────────────────────────────────────────┐  │
│  │ http://192.168.1.50:11434                         │  │
│  └───────────────────────────────────────────────────┘  │
│  Examples: 192.168.1.50:11434, hostname.local:1234     │
│                                                         │
│  Use API Token                                   ○──   │
│  Optional authentication for secured servers           │
├─────────────────────────────────────────────────────────┤
│  CONNECTION                                             │
│                                                         │
│  [🌐 Test Connection]                    ✅ 42 ms      │
│                                                         │
│  ✓ 12 models available                                 │
│  llama3.2, mistral, codellama, whisper...              │
├─────────────────────────────────────────────────────────┤
│  ▶ Advanced Options                                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Enable Streaming                            ──○   │  │
│  │ Stream responses in real-time                     │  │
│  │                                                   │  │
│  │ Request Timeout                                   │  │
│  │ [ 5s ][ 10s ][ 20s ][ 30s ][ 60s ]               │  │
│  └───────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│  CAPABILITIES & MODELS                                  │
│  (same as cloud providers, models from Test Connection) │
└─────────────────────────────────────────────────────────┘
```

**Local Provider Configuration Fields:**
1. **Provider Type** (required): Ollama, LM Studio, or Other OpenAI-compatible
2. **Server URL** (required): IP:port, hostname.local:port, or VPN IP
3. **API Token** (optional): Bearer token for authenticated servers
4. **Test Connection**: Fetches models, measures latency, validates auth
5. **Streaming Mode** (advanced): Enable/disable streaming responses
6. **Timeout** (advanced): Request timeout in seconds

---

### iOS Constraint
Keyboard extensions **cannot access the microphone**. Must use two-app architecture:

```
┌─────────────────────────────────────┐
│         Keyboard Extension          │
│  ┌──────────┐  ┌──────────┐  ┌────┐│
│  │🎤 Trans- │  │🌍 Trans- │  │⚡  ││
│  │  cribe   │  │  late    │  │Pwr ││
│  └──────────┘  └──────────┘  └────┘│
│  ┌─────────────────────────────┐   │
│  │ Mode: Email ▼               │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ Target: Spanish 🇪🇸 ▼        │   │
│  └─────────────────────────────┘   │
│  [⎌ Insert Last] [⌫] [🌐 Globe]    │
└───────────────┬─────────────────────┘
                │ URL Scheme
                ↓
┌─────────────────────────────────────┐
│          Containing App             │
│  - Records audio (AVAudioRecorder)  │
│  - Calls STT Provider API           │
│  - Applies LLM formatting           │
│  - Returns text via App Groups      │
└───────────────┬─────────────────────┘
                │
                ↓
        Auto-return to original app
        Text inserted via clipboard
```

### URL Schemes (As Implemented)

```
// Standard recording
swiftspeak://record?mode=email&translate=false&target=es

// Power Mode launch
swiftspeak://powermode?id=<uuid>&autostart=true
```

---

## Project Structure (As Implemented)

```
SwiftSpeak/
├── SwiftSpeak.xcodeproj
├── PHASE1_PLAN.md                       # Phase 1 execution guide
├── SwiftSpeak/                          # Containing App
│   ├── SwiftSpeakApp.swift              # @main entry
│   ├── ContentView.swift                # 4-tab navigation + HomeView
│   ├── SharedSettings.swift             # App Groups + settings manager
│   ├── Models.swift                     # All shared data models
│   ├── Theme.swift                      # AppTheme colors/gradients/animations
│   ├── HapticManager.swift              # Centralized haptic feedback
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift     # TabView container (6 screens)
│   │   │   ├── WelcomeScreen.swift      # Logo + tagline
│   │   │   ├── HowItWorksScreen.swift   # 4-step carousel
│   │   │   ├── EnableKeyboardScreen.swift
│   │   │   ├── FullAccessScreen.swift
│   │   │   ├── APIKeyScreen.swift       # Manual entry (no QR)
│   │   │   └── AllSetScreen.swift       # Confetti celebration
│   │   ├── RecordingView.swift          # Recording UI with 7 waveform types
│   │   ├── SettingsView.swift           # Multi-provider management
│   │   ├── HistoryView.swift            # Past transcriptions with search
│   │   ├── PaywallView.swift            # Pro/Power subscription prompt
│   │   └── PowerMode/
│   │       ├── PowerModeListView.swift      # Browse/manage modes
│   │       ├── PowerModeEditorView.swift    # Create/edit modes
│   │       ├── PowerModeExecutionView.swift # Full execution workspace
│   │       └── IconPicker.swift             # Icon & color selection
│   ├── Services/                        # Phase 1: NEW DIRECTORY
│   │   ├── Protocols/                   # Provider abstraction layer
│   │   ├── Audio/                       # AudioRecorder, AudioSessionManager
│   │   ├── Providers/OpenAI/            # OpenAI Whisper + GPT services
│   │   ├── Providers/Mock/              # Mock providers for testing
│   │   ├── Orchestration/               # TranscriptionOrchestrator
│   │   └── Network/                     # APIClient
│   └── Components/
│       ├── WaveformView.swift           # 7 waveform animation types
│       ├── GlassBackground.swift        # Glassmorphic modifiers
│       └── ModeBadge.swift              # Mode indicator badges
├── SwiftSpeakKeyboard/                  # Keyboard Extension
│   ├── KeyboardViewController.swift     # UIInputViewController
│   ├── KeyboardView.swift               # SwiftUI keyboard UI
│   ├── KeyboardViewModel.swift          # URL scheme handling
│   ├── KeyboardTheme.swift              # Keyboard-specific theming
│   └── Info.plist                       # RequestsOpenAccess = YES
├── SwiftSpeakTests/                     # Phase 1: NEW TEST TARGET
│   ├── Models/                          # Model unit tests
│   ├── Services/                        # Service unit tests
│   ├── Settings/                        # SharedSettings tests
│   └── Mocks/                           # Test mocks
├── SwiftSpeakUITests/                   # Phase 1: NEW UI TEST TARGET
│   ├── RecordingFlowUITests.swift
│   └── SettingsUITests.swift
└── Shared/
    └── Constants.swift                  # URL scheme, App Group ID
```

---

## Main App Navigation (As Implemented)

4-tab structure:

```swift
TabView(selection: $selectedTab) {
    HomeView()           // Tab 0: Record - Mode selector + action buttons
        .tabItem { Image(systemName: "mic.fill"); Text("Record") }

    HistoryView()        // Tab 1: History - Past transcriptions
        .tabItem { Image(systemName: "clock.fill"); Text("History") }

    PowerModeListView()  // Tab 2: Power - Power Mode management
        .tabItem { Image(systemName: "bolt.fill"); Text("Power") }

    SettingsView()       // Tab 3: Settings - Providers, preferences
        .tabItem { Image(systemName: "gear"); Text("Settings") }
}
```

---

## User Experience Flow

### Recording Flow (3-5 seconds total)
1. User in WhatsApp, switches to SwiftSpeak keyboard (globe button)
2. Selects mode from dropdown (Email, Formal, etc.)
3. Taps 🎤 Transcribe button
4. App opens **INSTANTLY** (<200ms) with recording already started
5. Compact center card shows waveform animation (randomly selected from 7 types)
6. User speaks
7. Tap card to stop recording
8. "Processing..." → STT transcription → LLM formatting
9. Auto-return to WhatsApp
10. Text inserted

### Power Mode Flow
1. User taps ⚡ Power button in keyboard
2. Power Mode picker overlay appears
3. User selects a Power Mode
4. App opens full-screen PowerModeExecutionView
5. Recording starts automatically
6. User speaks their request
7. Processing: transcribing → thinking → using capabilities → generating
8. Result displayed with markdown rendering
9. User can refine by voice, edit manually, or navigate version history
10. Insert result when satisfied

---

## Keyboard UI (As Implemented)

```
┌─────────────────────────────────────────────────────────────┐
│  ┌──────────────┐ ┌──────────────┐ ┌────────────────────┐   │
│  │🎤 Transcribe │ │🌍 Translate  │ │ ⚡ Power (dropdown)│   │
│  └──────────────┘ └──────────────┘ └────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Mode: Email                                    ▼    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🇪🇸 Spanish                                     ▼    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────┐  ┌────────┐  ┌─────────────────────┐   │
│  │ ⎌ Insert Last   │  │   ⌫    │  │      🌐 Globe       │   │
│  └─────────────────┘  └────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Key Features:**
- **Transcribe**: Opens RecordingView for voice transcription
- **Translate**: Opens RecordingView with translation enabled
- **Power**: Dropdown showing available Power Modes
- **Mode Dropdown**: Raw, Email, Formal, Casual selection
- **Language Dropdown**: Target language for translation
- **Insert Last**: Inserts previous transcription result
- **Backspace**: Delete character in text field
- **Globe**: Switch to next keyboard

---

## Recording UI: Compact Center Card (As Implemented)

```
┌─────────────────────────────────────────────┐
│                                             │
│          (blurred background)               │
│                                             │
│       ┌─────────────────────────┐           │
│       │   [Email] [🇪🇸 Spanish]  │           │  ← Status badges
│       │                         │           │
│       │     ~~~~∿∿∿~~~~         │           │  ← Waveform animation
│       │   (7 different types)   │           │     (randomly selected)
│       │                         │           │
│       │   "Transcribing         │           │
│       │    with Email mode"     │           │
│       │                         │           │
│       │       0:04.2            │           │  ← Duration
│       │                         │           │
│       │   "Tap to finish"       │           │
│       │                         │           │
│       │   Transcription: OpenAI │           │  ← Provider info
│       │   Mode: GPT             │           │
│       └─────────────────────────┘           │
│                                             │
└─────────────────────────────────────────────┘
```

**Waveform Types (7 total):**
1. `bars` - Classic vertical bars
2. `circular` - Circular ring animation
3. `linear` - Horizontal sine wave
4. `mirrored` - Mirrored bar visualization
5. `blob` - Organic blob animation
6. `soundBars` - Sound level bars
7. `spectrum` - Frequency spectrum display

**Card States:**
1. **Idle** - "Tap to start"
2. **Recording** - Live waveform, duration, provider info
3. **Processing** - Spinner, "Processing transcription..."
4. **Formatting** - Spinner, "Applying [mode] mode..."
5. **Complete** - Green checkmark, result preview
6. **Error** - Red X, error message

---

## Power Mode System (As Implemented)

### Power Mode Data Model

```swift
struct PowerMode: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String                              // SF Symbol name
    var iconColor: PowerModeColorPreset           // 10 color presets
    var iconBackgroundColor: PowerModeColorPreset
    var instruction: String                       // System prompt
    var outputFormat: String                      // Output formatting instructions
    var enabledCapabilities: Set<PowerModeCapability>
    let createdAt: Date
    var updatedAt: Date
    var usageCount: Int
}
```

### Power Mode Capabilities (As Implemented)

```swift
enum PowerModeCapability: String, Codable, CaseIterable {
    case webSearch = "web_search"           // Search the web
    case bashComputerUse = "bash_computer_use"  // Execute shell commands
    case codeExecution = "code_execution"   // Run Python in sandbox

    var supportedProviders: [LLMProvider] {
        switch self {
        case .webSearch: return [.openAI, .anthropic, .google]
        case .bashComputerUse: return [.openAI, .anthropic]
        case .codeExecution: return [.openAI, .google]
        }
    }
}
```

### Power Mode Color Presets

```swift
enum PowerModeColorPreset: String, Codable, CaseIterable {
    case orange, blue, purple, pink, green
    case red, teal, indigo, yellow, mint

    var color: Color { ... }
    var gradient: LinearGradient { ... }
}
```

### Power Mode Execution States

```swift
enum PowerModeExecutionState: Equatable {
    case idle                                    // Ready to start
    case recording                               // Recording voice input
    case transcribing                            // Converting speech to text
    case thinking                                // AI processing
    case usingCapability(PowerModeCapability)    // Executing a capability
    case askingQuestion(PowerModeQuestion)       // AI needs clarification
    case generating                              // Generating response
    case complete(PowerModeSession)              // Done with results
    case error(String)                           // Error occurred
}
```

### Power Mode Session (Version History)

```swift
struct PowerModeSession: Codable, Identifiable, Equatable {
    let id: UUID
    var results: [PowerModeResult]      // All versions
    var currentVersionIndex: Int        // Currently displayed version

    var currentResult: PowerModeResult? { ... }
    var hasMultipleVersions: Bool { ... }
    var canGoToPrevious: Bool { ... }
    var canGoToNext: Bool { ... }

    mutating func goToPrevious() { ... }
    mutating func goToNext() { ... }
    mutating func addResult(_ result: PowerModeResult) { ... }
}

struct PowerModeResult: Codable, Identifiable, Equatable {
    let id: UUID
    let powerModeId: UUID
    let powerModeName: String
    let userInput: String
    let markdownOutput: String
    let capabilitiesUsed: [PowerModeCapability]
    let timestamp: Date
    let processingDuration: TimeInterval
    let versionNumber: Int
}
```

### Power Mode UI Flow

```
┌──────────────────────────────────────────────────────────┐
│  ← Back              Research Assistant           Done → │
├──────────────────────────────────────────────────────────┤
│ YOUR INPUT:                                              │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ "Find me the latest news about AI"                   │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ 🎤 Refine by Voice    ✏️ Edit Input                      │
├──────────────────────────────────────────────────────────┤
│ GENERATED OUTPUT:                           v1 ◀ ▶ v1   │ ← Version nav
│ ┌──────────────────────────────────────────────────────┐ │
│ │ # AI News Summary                                    │ │
│ │                                                      │ │
│ │ ## Key Developments                                  │ │
│ │ - OpenAI announced...                                │ │
│ │ - Google DeepMind...                                 │ │
│ │                                                      │ │
│ │ ## Sources                                           │ │
│ │ - TechCrunch                                         │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│        [🎤 Refine by Voice]    [Insert into App ✓]       │
└──────────────────────────────────────────────────────────┘
```

**Refinement Mode:**
- Tap "Refine by Voice" to add additional instructions
- Creates new version, preserving history
- Navigate between versions with ◀ ▶ buttons

**Edit Mode:**
- Tap "Edit Input" to manually modify transcribed input
- Re-process with edited input

### Preset Power Modes

```swift
static let presets: [PowerMode] = [
    PowerMode(
        name: "Research Assistant",
        icon: "magnifyingglass.circle.fill",
        iconColor: .blue,
        instruction: "Help me find accurate, up-to-date information...",
        enabledCapabilities: [.webSearch]
    ),
    PowerMode(
        name: "Email Composer",
        icon: "envelope.fill",
        iconColor: .purple,
        instruction: "Help me compose professional emails...",
        enabledCapabilities: []
    ),
    PowerMode(
        name: "Daily Planner",
        icon: "calendar",
        iconColor: .green,
        instruction: "Help me organize my day...",
        enabledCapabilities: []
    ),
    PowerMode(
        name: "Idea Expander",
        icon: "lightbulb.fill",
        iconColor: .yellow,
        instruction: "Take my initial idea and help expand it...",
        enabledCapabilities: [.webSearch]
    )
]
```

---

## Onboarding Flow (As Implemented)

6 screens with progress bar and skip button:

### Screen 1: WelcomeScreen
- Animated waveform circle logo
- "SwiftSpeak" title
- "Speak naturally. Type instantly."
- [Get Started] button

### Screen 2: HowItWorksScreen (4 steps, not 3)
- Step 1: "Record" - Microphone animation
- Step 2: "Process" - Waveform to text animation
- Step 3: "Choose Mode" - Mode icons
- Step 4: "Use Everywhere" - App icons grid
- Auto-advancing carousel

### Screen 3: EnableKeyboardScreen
- Settings mockup with arrow animation
- "Open Settings" button → deep link
- Detects when keyboard is enabled

### Screen 4: FullAccessScreen
- Privacy explanation cards
- "Why we need Full Access"
- Network access explanation
- "Your data is never stored"
- Detects when enabled

### Screen 5: APIKeyScreen
- OpenAI API key input
- "Get API Key" link to platform.openai.com
- Validation with green checkmark
- **Note: QR scanner NOT implemented**

### Screen 6: AllSetScreen
- Confetti celebration animation
- "You're ready to speak!"
- Quick tip about keyboard switching
- [Start Using SwiftSpeak] button

---

## Visual Design & Theming (As Implemented)

### AppTheme (Centralized)

```swift
struct AppTheme {
    // Colors
    static let accent = Color.blue
    static let powerAccent = Color.orange
    static let darkBase = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let lightBase = Color(red: 0.95, green: 0.95, blue: 0.97)

    // Gradients
    static let accentGradient = LinearGradient(...)
    static let powerGradient = LinearGradient(...)

    // Corner Radii
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 24

    // Animations
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
```

### KeyboardTheme (Extension-specific)

Mirrors AppTheme for keyboard extension use.

### HapticManager (Centralized)

```swift
struct HapticManager {
    static func lightTap() { ... }
    static func mediumTap() { ... }
    static func success() { ... }
    static func error() { ... }
    static func selection() { ... }
}
```

### Glass Background Modifier

```swift
extension View {
    func glassBackground(cornerRadius: CGFloat, includeShadow: Bool) -> some View
}
```

---

## History View (As Implemented)

- Search bar for filtering
- Multi-select mode for bulk actions
- Swipe actions (Copy, Reprocess, Delete)
- Reprocess with different mode
- Empty state with helpful message
- Grouped by date

---

## Settings View (As Implemented)

### Sections:
1. **Account** - Subscription status, upgrade button
2. **AI Models** - Unified AI provider management (see Provider Editor below)
3. **Translation** - Target language selection
4. **Vocabulary** - Custom word replacements (NOT YET FUNCTIONAL)
5. **About** - Version, links, debug info
6. **Debug** - Reset onboarding, add mock history, keyboard preview

### AI Provider Editor:
The unified provider editor allows:
- **One API key per provider** - Enter once, use for all capabilities
- **Capability toggles** - Enable/disable transcription, translation, power mode independently
- **Model per capability** - Select different model for each enabled capability
- **Refresh Models** - Fetch latest available models from provider API
- **Setup instructions** - Provider-specific help with links to API key pages

### Local AI Provider Editor:
For local AI providers (Power Tier only):
- **Provider type selection** - Ollama, LM Studio, or Other OpenAI-compatible
- **Server URL configuration** - IP:port, hostname.local, or VPN IP
- **Optional API token** - Bearer token authentication for secured servers
- **Test Connection** - Validates connection, fetches available models, measures latency
- **Streaming toggle** - Enable/disable streaming responses (Advanced)
- **Timeout selection** - 5s, 10s, 20s, 30s, or 60s request timeout (Advanced)

---

## Paywall View (As Implemented)

- Toggle between Monthly/Yearly/Lifetime billing
- Pro tier card ($6.99/mo, $59.99/yr, or $99 lifetime)
- Power tier card ($12.99/mo, $99.99/yr, or $199 lifetime)
- Features comparison section
- Success overlay animation after purchase
- **Value messaging**: "Save 40-70% vs Wispr Flow"

---

## Implementation Phases

### Phase 0: UI/UX Prototype ✅ COMPLETE
All screens functional with mock data, full navigation, polished animations.

**Completed:**
1. ✅ Xcode project setup with keyboard extension target
2. ✅ Onboarding flow (6 screens with animations)
3. ✅ Keyboard UI - buttons, dropdowns, Power Mode picker
4. ✅ Recording card - 7 waveform types, state transitions
5. ✅ Settings screens - multi-provider management
6. ✅ Power Mode workspace - execution, refinement, version history
7. ✅ Power Mode editor - create/edit with icon picker
8. ✅ Paywall screens - Pro and Power tier
9. ✅ History view - search, multi-select, reprocess
10. ✅ 4-tab main navigation

### Phase 1: Core Transcription + Testing Infrastructure ✅ COMPLETE
**Execution Guide:** See `/PHASE1_PLAN.md` for step-by-step implementation details.

**Testing Infrastructure:**
1. [x] Create SwiftSpeakTests unit test target (97 tests)
2. [x] Create SwiftSpeakUITests UI test target (10 tests)
3. [x] Write model tests (AIProvider, FormattingMode, Language, TranscriptionError)
4. [x] Write service tests with mocks (MockTranscriptionProvider, MockFormattingProvider)

**Core Transcription:**
1. [x] Provider abstraction layer (TranscriptionProvider, FormattingProvider, TranslationProvider protocols)
2. [x] Real audio recording with AVAudioRecorder (AudioRecorder, AudioSessionManager)
3. [x] OpenAI Whisper API integration (OpenAITranscriptionService)
4. [x] GPT-4 formatting integration (OpenAIFormattingService - Email, Formal, Casual modes)
5. [x] App Groups for keyboard ↔ app communication (already configured)
6. [x] URL scheme handling for keyboard → app launch (already configured)
7. [x] TranscriptionOrchestrator coordinating full flow
8. [ ] Auto-return to previous app + clipboard insertion (PHASE 2)
9. [ ] Silence detection for auto-stop (OPTIONAL)

### Phase 2: Templates & Translation ✅ COMPLETE
1. [x] GPT-4 formatting integration (Email, Formal, Casual modes) - Done in Phase 1
2. [x] Translation feature with LLM (OpenAITranslationService)
3. [x] Auto-return to previous app + clipboard insertion (configurable in settings)
4. [x] Custom template editor (TemplatesView.swift)
5. [x] Template storage and sync via App Groups
6. [x] Integrate custom templates into keyboard mode dropdown
7. [x] Connect waveforms to real audio levels
8. [x] Unit tests for translation and templates

### Phase 3: Multi-Provider Support ✅ COMPLETE
**Execution Guide:** See `/PHASE3_PLAN.md` for step-by-step implementation details.

**Transcription Providers:**
1. [x] OpenAI Whisper (Phase 1)
2. [x] AssemblyAI STT integration (upload + poll pattern)
3. [x] Deepgram STT integration (direct upload)
4. [x] Google Cloud Speech-to-Text (base64 encoding, requires Project ID)

**Translation Providers:**
5. [x] OpenAI GPT (Phase 2)
6. [x] DeepL Translation (uppercase language codes)
7. [x] Google Cloud Translation
8. [x] Azure Translator (requires region)
9. [ ] Amazon Translate (optional - AWS Sig V4 complexity, deferred)

**Power Mode/Formatting Providers:**
10. [x] OpenAI GPT (Phase 1)
11. [x] Anthropic Claude (x-api-key header, anthropic-version)
12. [x] Google Gemini (generateContent API)

**Infrastructure:**
13. [x] Local AI integration (Ollama, LM Studio, OpenAI-compatible) - **UI COMPLETE**
    - Provider type selection (Ollama, LM Studio, OpenAI-compatible)
    - Server URL configuration
    - Optional API token authentication
    - Test Connection with model discovery
    - Streaming and timeout options
14. [x] ProviderFactory for unified provider creation
15. [x] Update TranscriptionOrchestrator to use ProviderFactory
16. [x] Settings UI: provider-specific config (Google Project ID, Azure Region)
17. [x] Language code extensions (deepLCode, googleCode, azureCode, assemblyAICode, googleSTTCode)

**Files Created in Phase 3:**
| File | Purpose |
|------|---------|
| `Services/ProviderFactory.swift` | Unified factory for all provider types |
| `Services/Providers/AssemblyAI/AssemblyAITranscriptionService.swift` | AssemblyAI STT |
| `Services/Providers/Deepgram/DeepgramTranscriptionService.swift` | Deepgram STT |
| `Services/Providers/Google/GoogleSTTService.swift` | Google Cloud STT |
| `Services/Providers/Google/GoogleTranslationService.swift` | Google Translation |
| `Services/Providers/Google/GeminiService.swift` | Gemini LLM |
| `Services/Providers/DeepL/DeepLTranslationService.swift` | DeepL Translation |
| `Services/Providers/Azure/AzureTranslatorService.swift` | Azure Translator |
| `Services/Providers/Anthropic/AnthropicService.swift` | Anthropic Claude |

**Test Files Created (9 test files):**
| File | Coverage |
|------|----------|
| `SwiftSpeakTests/Services/AssemblyAITranscriptionServiceTests.swift` | Upload, polling, error handling |
| `SwiftSpeakTests/Services/DeepgramTranscriptionServiceTests.swift` | Model selection, language codes |
| `SwiftSpeakTests/Services/GoogleSTTServiceTests.swift` | Project ID validation, base64 |
| `SwiftSpeakTests/Services/DeepLTranslationServiceTests.swift` | Language codes, free tier |
| `SwiftSpeakTests/Services/GoogleTranslationServiceTests.swift` | API key auth, response parsing |
| `SwiftSpeakTests/Services/AzureTranslatorServiceTests.swift` | Region validation, headers |
| `SwiftSpeakTests/Services/AnthropicServiceTests.swift` | Version header, message format |
| `SwiftSpeakTests/Services/GeminiServiceTests.swift` | Endpoint construction, response |
| `SwiftSpeakTests/Services/ProviderFactoryTests.swift` | Factory creation, validation |

**⚠️ INVESTIGATION NEEDED (moved to Phase 3a):**
- [ ] **Terms & Conditions**: Research what disclosures are needed about third-party AI providers
- [ ] **User Information**: Determine what provider-related information must be shown to users
- [ ] Review Apple App Store guidelines for apps using third-party APIs
- [ ] Check each provider's branding guidelines for using their logos/names
- [ ] Draft privacy disclosure explaining data flows to each provider

### Phase 3a: Provider Help & Language Guidance
**Execution Guide:** See `/PHASE3A_PLAN.md` for step-by-step implementation details.

**Goal:** Reduce user friction when setting up multiple providers by adding contextual help and language compatibility guidance.

**Data Models:**
1. [ ] ProviderLanguageSupport model (language support levels per provider)
2. [ ] ProviderHelpContent model (setup guides per provider)
3. [ ] Populate language support matrix data
4. [ ] Populate provider setup guide content

**Help Components:**
5. [ ] ProviderHelpSheet (bottom sheet with setup steps)
6. [ ] ProviderStatusDashboard (at-a-glance config status)
7. [ ] ProviderComparisonView ("Help me choose" flow)

**Language Guidance:**
8. [ ] LanguageSupportView (language-provider compatibility matrix)
9. [ ] LanguageProviderRecommendation sheet
10. [ ] SmartLanguagePicker (shows compatibility in dropdown)
11. [ ] IncompatibilityWarning banner

**Integration:**
12. [ ] Add help (?) buttons to provider editor
13. [ ] Add status dashboard to Settings
14. [ ] Add language warnings to Settings
15. [ ] Add "Help me choose" navigation links
16. [ ] Add language warning indicator to keyboard

### Phase 4: Power Mode Backend + Advanced Features
**Execution Guide:** See `/PHASE4_PLAN.md` for step-by-step implementation details.

**Phase 4.0: UI Mock-ups (UI/UX First)** ✅ COMPLETE
Build all new screens with mock data before backend implementation:

1. [x] **Contexts UI:**
   - [x] ContextsView.swift (Settings → Contexts list)
   - [x] ContextEditorSheet.swift (Create/edit context with tone, language hints, formality)
   - [x] ContextQuickSwitcher.swift (Floating overlay for quick context switching)
   - [x] ContextDetailView.swift (Context detail with history link)

2. [x] **Memory UI:**
   - [x] MemoryView.swift (Settings → Memory management with filtering)
   - [x] MemoryEditorSheet.swift (View/edit memory content)

3. [x] **RAG/Knowledge Base UI:**
   - [x] KnowledgeBaseView.swift (Documents list in Power Mode editor)
   - [x] DocumentPickerSheet.swift (Upload PDF/TXT/MD or add URL)

4. [x] **Webhooks UI:**
   - [x] WebhooksView.swift (Settings → Webhooks list)
   - [x] WebhookEditorSheet.swift (Template picker, URL, auth, payload config)

5. [x] **Power Tab Redesign:**
   - [x] PowerTabView.swift (Segmented control: Modes | Contexts)
   - [x] SwipeablePowerModeCard.swift (WhatsApp-style swipe actions)

**Phase 4a: Conversation Contexts** ✅ COMPLETE
Named contexts (e.g., "Fatma", "Work") that customize tone and behavior across all features:

6. [x] ConversationContext model (name, icon, color, toneDescription, formality, languageHints, customInstructions)
7. [x] ContextFormality enum (auto, formal, informal, neutral) with DeepL integration
8. [x] Context storage in SharedSettings (contexts array, activeContextId)
9. [x] PromptContext.swift - Universal context injection for all providers
10. [x] Wire contexts into TranscriptionOrchestrator (inject into prompts)
11. [x] Formality picker in ContextEditorSheet with DeepL-specific note
12. [x] Context injection into transcription (promptHint with vocabulary + language)
13. [x] Context injection into translation (formality + context for LLM providers)
14. [x] Context injection into formatting (full system prompt with memory/tone/instructions)

**Phase 4b: Three-Tier Memory System** ✅ COMPLETE
Persistent memory across conversations:

15. [x] HistoryMemory model (global, always on, updated after each conversation)
16. [x] Global memory fields in SharedSettings (globalMemory, globalMemoryEnabled)
17. [x] Update PowerMode model with memory fields (memoryEnabled, memory, lastMemoryUpdate)
18. [x] Context memory fields in ConversationContext (memoryEnabled, memory)
19. [x] MemoryManager service (Services/Memory/MemoryManager.swift)
20. [x] Memory update after transcriptions complete (integrated into TranscriptionOrchestrator)
21. [x] Memory compression logic (when >2000 chars, compress to <1500)
22. [x] Add Memory section to SettingsView

**Phase 4c: PowerModeOrchestrator**
Replace mock implementations with real execution:

23. [ ] Create PowerModeOrchestrator with full state machine (idle → recording → transcribing → thinking → generating → complete)
24. [ ] Integrate with AudioRecorder for recording
25. [ ] Integrate with transcription providers via ProviderFactory
26. [ ] Integrate with formatting providers for LLM generation
27. [ ] Context/memory injection into prompts
28. [ ] Wire to PowerModeExecutionView (replace all mock callbacks)
29. [ ] Session with multiple versions working
30. [ ] Refinement flow working

**Phase 4d: LLM Streaming**
Real-time response generation:

31. [ ] StreamingClient.swift (SSE parsing)
32. [ ] Add streaming to OpenAIFormattingService
33. [ ] Add streaming to AnthropicService
34. [ ] Add streaming to GeminiService
35. [ ] Streaming toggle in provider settings
36. [ ] Progressive text rendering in Power Mode result view

**Phase 4e: RAG System**
Document-based knowledge per Power Mode:

37. [x] KnowledgeDocument model (name, type, sourceURL, contentHash, chunkCount)
38. [ ] DocumentChunk model (content, embedding, metadata)
39. [ ] DocumentParser.swift (PDF via PDFKit, text/markdown, web URL → markdown)
40. [ ] TextChunker.swift (~500 token chunks with 50 token overlap)
41. [ ] EmbeddingService.swift (OpenAI text-embedding-ada-002)
42. [ ] VectorStore.swift (similarity search, in-memory + file persistence)
43. [ ] KnowledgeBaseManager.swift (orchestrate RAG pipeline)
44. [ ] RAG integration in PowerModeOrchestrator
45. [ ] Wire Knowledge Base UI in PowerModeEditorView

**Phase 4f: Webhooks (Global)**
Outbound webhooks for integrations:

46. [x] Webhook model (type: contextSource/outputDestination/automationTrigger, URL, auth, payload config)
47. [ ] WebhookExecutor.swift (GET for context sources, POST for outputs/triggers)
48. [ ] Template picker integration (Slack, Notion, Make, Zapier, Todoist, Custom)
49. [x] Webhook storage in SharedSettings
50. [ ] Integration in PowerModeOrchestrator (fetch context before, send results after)
51. [ ] Test button functionality
52. [x] Add Webhooks section to SettingsView (UI mock)

**Phase 4g: Transcription Streaming (OPTIONAL)**
Real-time transcription as user speaks:

53. [ ] DeepgramStreamingService.swift (WebSocket)
54. [ ] AssemblyAIStreamingService.swift (WebSocket)
55. [ ] GoogleStreamingService.swift
56. [ ] Real-time transcription UI
57. [ ] Streaming toggle per provider

**REMOVED from original Phase 4 (no longer planned):**
- ~~Web search capability~~ → Replaced by RAG
- ~~Bash/Computer use capability~~ → Not applicable for mobile
- ~~Code execution capability~~ → Security concerns for mobile

**Files to Create (28 new files):**

| Category | File | Purpose |
|----------|------|---------|
| Contexts | `Shared/ConversationContext.swift` | Context model |
| Contexts | `Views/Settings/ContextsView.swift` | Context list |
| Contexts | `Views/Settings/ContextEditorSheet.swift` | Edit context |
| Contexts | `Views/Components/ContextQuickSwitcher.swift` | Quick switch overlay |
| Memory | `Services/Memory/MemoryManager.swift` | Memory update/compression |
| Memory | `Views/Settings/MemoryView.swift` | Memory management |
| Memory | `Views/Settings/MemoryEditorSheet.swift` | Edit memory |
| Orchestration | `Services/Orchestration/PowerModeOrchestrator.swift` | Central coordinator |
| Orchestration | `Services/Orchestration/PromptContext.swift` | Context builder |
| Streaming | `Services/Network/StreamingClient.swift` | SSE parsing |
| RAG | `Services/RAG/DocumentParser.swift` | PDF/text/web parsing |
| RAG | `Services/RAG/TextChunker.swift` | Chunking strategy |
| RAG | `Services/RAG/EmbeddingService.swift` | OpenAI embeddings |
| RAG | `Services/RAG/VectorStore.swift` | Similarity search |
| RAG | `Services/RAG/KnowledgeBaseManager.swift` | RAG orchestration |
| RAG | `Views/PowerMode/KnowledgeBaseView.swift` | Document list |
| RAG | `Views/PowerMode/DocumentPickerSheet.swift` | Add document |
| Webhooks | `Shared/Webhook.swift` | Webhook model |
| Webhooks | `Services/Webhooks/WebhookExecutor.swift` | Execute webhooks |
| Webhooks | `Views/Settings/WebhooksView.swift` | Webhook list |
| Webhooks | `Views/Settings/WebhookEditorSheet.swift` | Edit webhook |

**Files to Modify:**

| File | Changes |
|------|---------|
| `Shared/Models.swift` | Add HistoryMemory, update PowerMode with memory fields |
| `SharedSettings.swift` | Add contexts, activeContextId, historyMemory, webhooks |
| `Views/SettingsView.swift` | Add Contexts, Memory, Webhooks sections |
| `Views/PowerMode/PowerModeExecutionView.swift` | Use real orchestrator |
| `Views/PowerMode/PowerModeEditorView.swift` | Add knowledge base section |
| `Services/Providers/OpenAI/OpenAIFormattingService.swift` | Add streaming |
| `Services/Providers/Anthropic/AnthropicService.swift` | Add streaming |
| `Services/Providers/Google/GeminiService.swift` | Add streaming |
| `Services/Orchestration/TranscriptionOrchestrator.swift` | Context injection |
| `Services/ProviderFactory.swift` | Add streaming provider creation |

### Phase 5: Advanced Features (moved from original Phase 5)
1. [ ] Vocabulary replacement processing (ALREADY IMPLEMENTED)
2. [ ] Diff highlighting for refinements (DiffHighlighter.swift)
3. [ ] Voice-based Power Mode creation (OPTIONAL)

### Phase 6: Security & Data Protection
1. [ ] Migrate API keys to iOS Keychain (KeychainManager.swift)
2. [ ] Encrypt transcription history (using Data Protection)
3. [ ] Biometric protection for History view (Face ID / Touch ID) - optional setting
4. [ ] Biometric protection for viewing/editing API keys - optional setting
5. [ ] Secure data deletion (complete account/data reset)
6. [ ] Add privacy policy & data handling disclosure
7. [ ] Audit for App Store privacy nutrition labels

**Note:** NO biometric lock on app launch or recording flow - must remain frictionless for core UX.

### Phase 7: Monetization & Polish
1. [ ] StoreKit 2 / RevenueCat subscription integration
2. [ ] Paywall logic (Free/Pro/Power limits)
3. [ ] Usage tracking (free tier limits)
4. [ ] Error handling & offline states
5. [ ] App Store submission

### Phase 8: Community Features (OPTIONAL/V2)
1. [ ] Global profile system (ProfileEditor.swift)
2. [ ] Community Power Mode sharing (CommunityBrowser.swift)
3. [ ] Mode rating and discovery
4. [ ] Backend for community sync

### Phase 9: Remote Configuration & Cost Analytics
**Goal:** Display API cost information to users with remote updates to avoid app releases when pricing/languages change.

**Backend Service (Hostinger KVM):**
1. [ ] Set up nginx on Hostinger KVM to serve static JSON
2. [ ] Create `config.json` with provider pricing, languages, and status
3. [ ] Configure HTTPS with Let's Encrypt
4. [ ] Create simple script to update config and track version

**iOS App - RemoteConfigManager:**
5. [ ] Create `RemoteConfigManager.swift` - fetches and caches remote config
6. [ ] Implement weekly update check (on first app launch if >7 days since last check)
7. [ ] Add manual refresh button in Settings → About
8. [ ] Bundle fallback config for offline/first launch
9. [ ] Store cached config in App Groups for keyboard access

**Cost Display - Provider Settings/Help:**
10. [ ] Show provider rates in ProviderHelpSheet (e.g., "$0.006/minute for Whisper")
11. [ ] Add pricing info to provider editor (cost per minute/character/token)
12. [ ] Update rates from remote config automatically

**Cost Display - History:**
13. [ ] Add estimated cost column to TranscriptionRecord model
14. [ ] Calculate cost when transcription completes (based on duration/tokens)
15. [ ] Display cost per item in HistoryView (subtle, not prominent)

**Cost Analytics View (NEW):**
16. [ ] Create `CostAnalyticsView.swift` - dedicated cost tracking screen
17. [ ] Summary card: Total spend (day/week/month/all-time)
18. [ ] Per-provider breakdown with pie chart (SwiftUI Charts)
19. [ ] Usage over time line chart (transcriptions + costs)
20. [ ] Cost by category (transcription vs translation vs formatting)
21. [ ] Average cost per transcription stat
22. [ ] Export cost report (CSV/PDF) - optional

**UI Design - CostAnalyticsView:**
```
┌─────────────────────────────────────────────────────────┐
│  Cost Analytics                         [↻ Refresh]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           TOTAL SPEND                            │   │
│  │              $2.47                               │   │
│  │         ───────────────                          │   │
│  │   Today   This Week   This Month   All Time      │   │
│  │   $0.12     $0.89       $2.47        $2.47       │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  BY PROVIDER                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │    [Pie Chart]         OpenAI      $2.35  95%   │   │
│  │                        DeepL       $0.08   3%   │   │
│  │                        Anthropic   $0.04   2%   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  USAGE OVER TIME                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │    [Line Chart - transcriptions & cost/day]      │   │
│  │     ^                                            │   │
│  │    $│   ∙∙∙                                      │   │
│  │     │ ∙    ∙∙∙∙                                  │   │
│  │     │∙         ∙∙∙∙                              │   │
│  │     └────────────────────────────→ Date          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  BREAKDOWN                                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🎤 Transcription              $1.98   80%        │   │
│  │ 🌍 Translation                $0.37   15%        │   │
│  │ ✨ Formatting                 $0.12    5%        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  STATS                                                  │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📊 342 transcriptions this month                 │   │
│  │ ⏱️ Average: 28 seconds per transcription         │   │
│  │ 💰 Average cost: $0.007 per transcription        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Rates last updated: Dec 26, 2025                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Remote Config JSON Schema (with Dynamic Capabilities):**

The config includes full capability definitions so providers can add/remove features without app updates:

```json
{
  "version": "1.0.0",
  "lastUpdated": "2025-12-26T00:00:00Z",
  "schemaVersion": 2,
  "providers": {
    "openai": {
      "displayName": "OpenAI",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [
            { "id": "whisper-1", "name": "Whisper", "default": true }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
          "features": ["languageDetection", "timestamps"]
        },
        "translation": {
          "enabled": true,
          "models": [
            { "id": "gpt-4o-mini", "name": "GPT-4o Mini", "default": true },
            { "id": "gpt-4o", "name": "GPT-4o" }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
          "features": ["contextAware", "formalityControl"]
        },
        "powerMode": {
          "enabled": true,
          "models": [
            { "id": "gpt-4o", "name": "GPT-4o", "default": true },
            { "id": "gpt-4o-mini", "name": "GPT-4o Mini" },
            { "id": "o1", "name": "o1 (Reasoning)", "tier": "power" }
          ],
          "features": ["streaming", "functionCalling", "vision", "webSearch"]
        },
        "formatting": {
          "enabled": true,
          "models": [
            { "id": "gpt-4o-mini", "name": "GPT-4o Mini", "default": true }
          ]
        }
      },
      "pricing": {
        "whisper-1": { "unit": "minute", "cost": 0.006 },
        "gpt-4o": { "inputPerMToken": 2.50, "outputPerMToken": 10.00 },
        "gpt-4o-mini": { "inputPerMToken": 0.15, "outputPerMToken": 0.60 },
        "o1": { "inputPerMToken": 15.00, "outputPerMToken": 60.00 }
      },
      "freeCredits": "$5 for new accounts",
      "apiKeyUrl": "https://platform.openai.com/api-keys",
      "docsUrl": "https://platform.openai.com/docs"
    },
    "anthropic": {
      "displayName": "Anthropic",
      "status": "operational",
      "capabilities": {
        "transcription": { "enabled": false },
        "translation": {
          "enabled": true,
          "models": [
            { "id": "claude-3-5-sonnet-latest", "name": "Claude 3.5 Sonnet", "default": true },
            { "id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku" }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko"],
          "features": ["contextAware"]
        },
        "powerMode": {
          "enabled": true,
          "models": [
            { "id": "claude-3-5-sonnet-latest", "name": "Claude 3.5 Sonnet", "default": true },
            { "id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku" },
            { "id": "claude-3-opus-latest", "name": "Claude 3 Opus", "tier": "power" }
          ],
          "features": ["streaming", "functionCalling", "vision", "computerUse"]
        },
        "formatting": {
          "enabled": true,
          "models": [
            { "id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku", "default": true }
          ]
        }
      },
      "pricing": {
        "claude-3-5-sonnet-latest": { "inputPerMToken": 3.00, "outputPerMToken": 15.00 },
        "claude-3-5-haiku-latest": { "inputPerMToken": 0.80, "outputPerMToken": 4.00 },
        "claude-3-opus-latest": { "inputPerMToken": 15.00, "outputPerMToken": 75.00 }
      },
      "apiKeyUrl": "https://console.anthropic.com/settings/keys",
      "docsUrl": "https://docs.anthropic.com"
    },
    "google": {
      "displayName": "Google",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [
            { "id": "long", "name": "Long-form", "default": true },
            { "id": "short", "name": "Short-form" }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
          "features": ["languageDetection", "timestamps", "speakerDiarization"],
          "requiresProjectId": true
        },
        "translation": {
          "enabled": true,
          "models": [
            { "id": "nmt", "name": "Neural MT", "default": true }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi", "th", "vi"],
          "features": ["languageDetection", "glossary"]
        },
        "powerMode": {
          "enabled": true,
          "models": [
            { "id": "gemini-2.0-flash-exp", "name": "Gemini 2.0 Flash", "default": true },
            { "id": "gemini-1.5-pro", "name": "Gemini 1.5 Pro" },
            { "id": "gemini-1.5-flash", "name": "Gemini 1.5 Flash" }
          ],
          "features": ["streaming", "functionCalling", "vision", "codeExecution"]
        },
        "formatting": {
          "enabled": true,
          "models": [
            { "id": "gemini-2.0-flash-exp", "name": "Gemini 2.0 Flash", "default": true }
          ]
        }
      },
      "pricing": {
        "long": { "unit": "minute", "cost": 0.006 },
        "short": { "unit": "15seconds", "cost": 0.006 },
        "nmt": { "unit": "character", "cost": 0.00002 },
        "gemini-2.0-flash-exp": { "inputPerMToken": 0.075, "outputPerMToken": 0.30 },
        "gemini-1.5-pro": { "inputPerMToken": 1.25, "outputPerMToken": 5.00 },
        "gemini-1.5-flash": { "inputPerMToken": 0.075, "outputPerMToken": 0.30 }
      },
      "freeCredits": "Free tier available",
      "apiKeyUrl": "https://aistudio.google.com/apikey",
      "docsUrl": "https://ai.google.dev/docs"
    },
    "deepgram": {
      "displayName": "Deepgram",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [
            { "id": "nova-2", "name": "Nova-2", "default": true },
            { "id": "nova", "name": "Nova" },
            { "id": "enhanced", "name": "Enhanced" },
            { "id": "base", "name": "Base" }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pt", "ru", "it"],
          "features": ["languageDetection", "timestamps", "speakerDiarization", "streaming"]
        },
        "translation": { "enabled": false },
        "powerMode": { "enabled": false },
        "formatting": { "enabled": false }
      },
      "pricing": {
        "nova-2": { "unit": "minute", "cost": 0.0043 },
        "nova": { "unit": "minute", "cost": 0.0036 },
        "enhanced": { "unit": "minute", "cost": 0.0145 },
        "base": { "unit": "minute", "cost": 0.0125 }
      },
      "freeCredits": "$200 free credits",
      "apiKeyUrl": "https://console.deepgram.com/project/*/keys",
      "docsUrl": "https://developers.deepgram.com"
    },
    "deepl": {
      "displayName": "DeepL",
      "status": "operational",
      "capabilities": {
        "transcription": { "enabled": false },
        "translation": {
          "enabled": true,
          "models": [
            { "id": "default", "name": "DeepL Neural", "default": true }
          ],
          "languages": ["EN", "DE", "FR", "ES", "IT", "JA", "ZH", "PL", "PT", "RU", "NL", "SV", "DA", "FI", "EL", "CS", "RO", "HU", "SK", "BG", "LT", "LV", "ET", "SL"],
          "features": ["formalityControl", "glossary", "documentTranslation"]
        },
        "powerMode": { "enabled": false },
        "formatting": { "enabled": false }
      },
      "pricing": {
        "default": { "unit": "character", "cost": 0.00002 }
      },
      "freeCredits": "500,000 chars/month free",
      "apiKeyUrl": "https://www.deepl.com/account/summary",
      "docsUrl": "https://www.deepl.com/docs-api"
    },
    "azure": {
      "displayName": "Azure",
      "status": "operational",
      "capabilities": {
        "transcription": { "enabled": false },
        "translation": {
          "enabled": true,
          "models": [
            { "id": "translator", "name": "Azure Translator", "default": true }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi", "th", "vi", "id"],
          "features": ["languageDetection", "transliteration", "dictionary"],
          "requiresRegion": true
        },
        "powerMode": { "enabled": false },
        "formatting": { "enabled": false }
      },
      "pricing": {
        "translator": { "unit": "character", "cost": 0.00001 }
      },
      "freeCredits": "2M chars/month free",
      "apiKeyUrl": "https://portal.azure.com",
      "docsUrl": "https://learn.microsoft.com/en-us/azure/ai-services/translator"
    },
    "assemblyai": {
      "displayName": "AssemblyAI",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [
            { "id": "best", "name": "Best", "default": true },
            { "id": "nano", "name": "Nano (Fast)" }
          ],
          "languages": ["en", "es", "fr", "de", "it", "pt", "nl", "ja", "ko", "zh", "hi", "pl", "ru", "tr", "uk", "vi"],
          "features": ["languageDetection", "timestamps", "speakerDiarization", "summarization", "sentimentAnalysis"]
        },
        "translation": { "enabled": false },
        "powerMode": { "enabled": false },
        "formatting": { "enabled": false }
      },
      "pricing": {
        "best": { "unit": "minute", "cost": 0.00037 },
        "nano": { "unit": "minute", "cost": 0.00012 }
      },
      "apiKeyUrl": "https://www.assemblyai.com/app/account",
      "docsUrl": "https://www.assemblyai.com/docs"
    },
    "elevenlabs": {
      "displayName": "ElevenLabs",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [
            { "id": "scribe_v1", "name": "Scribe", "default": true }
          ],
          "languages": ["en", "es", "fr", "de", "ja", "ko", "zh", "pt", "it", "pl", "nl", "sv", "da", "fi", "no", "ru", "uk", "tr", "ar", "hi", "id", "ms", "th", "vi", "cs", "el", "hu", "ro", "sk", "bg"],
          "features": ["timestamps", "speakerDiarization"]
        },
        "translation": { "enabled": false },
        "powerMode": { "enabled": false },
        "formatting": { "enabled": false }
      },
      "pricing": {
        "scribe_v1": { "unit": "minute", "cost": 0.00 }
      },
      "freeCredits": "2.5 hours/month free, then $0.003/min",
      "notes": "Free tier includes 2.5 hours of transcription per month",
      "apiKeyUrl": "https://elevenlabs.io/app/settings/api-keys",
      "docsUrl": "https://elevenlabs.io/docs/api-reference"
    },
    "local": {
      "displayName": "Local AI",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [],
          "languages": [],
          "features": ["offline"],
          "note": "Models fetched dynamically from local server"
        },
        "translation": {
          "enabled": true,
          "models": [],
          "languages": [],
          "features": ["offline"],
          "note": "Models fetched dynamically from local server"
        },
        "powerMode": {
          "enabled": true,
          "models": [],
          "features": ["offline", "streaming"],
          "note": "Models fetched dynamically from local server"
        },
        "formatting": {
          "enabled": true,
          "models": [],
          "note": "Models fetched dynamically from local server"
        }
      },
      "pricing": {},
      "notes": "100% free - runs on your own hardware"
    }
  },
  "defaultProviders": {
    "transcription": "openai",
    "translation": "openai",
    "powerMode": "openai",
    "formatting": "openai"
  },
  "featureFlags": {
    "powerModeEnabled": true,
    "translationEnabled": true,
    "customTemplatesEnabled": true,
    "costTrackingEnabled": true
  },
  "announcements": [
    {
      "id": "gemini-2-launch",
      "type": "info",
      "title": "Gemini 2.0 Flash Now Available",
      "message": "Google's fastest model is now available for Power Mode!",
      "validUntil": "2025-01-15T00:00:00Z"
    }
  ]
}
```

**Capability Schema Explained:**

| Field | Purpose |
|-------|---------|
| `capabilities.<type>.enabled` | Whether this provider supports this capability (can change!) |
| `capabilities.<type>.models[]` | Available models with id, name, default flag, and tier |
| `capabilities.<type>.languages[]` | Supported language codes (can be updated remotely) |
| `capabilities.<type>.features[]` | Special features: streaming, vision, functionCalling, etc. |
| `capabilities.<type>.requiresProjectId` | Provider needs additional config (e.g., Google) |
| `capabilities.<type>.requiresRegion` | Provider needs region (e.g., Azure) |
| `pricing.<modelId>` | Cost per unit for each model |
| `freeCredits` | Info about free tier |
| `apiKeyUrl` | Direct link to get API key |
| `featureFlags` | App-wide feature toggles (can disable features remotely) |
| `announcements` | In-app notifications about new features/providers |

**Example: Provider Adds New Capability**

If Anthropic suddenly adds transcription support, you just update the config:
```json
// Before
"anthropic": {
  "capabilities": {
    "transcription": { "enabled": false },
    ...
  }
}

// After (update remotely, no app release needed!)
"anthropic": {
  "capabilities": {
    "transcription": {
      "enabled": true,
      "models": [{ "id": "claude-whisper", "name": "Claude Whisper", "default": true }],
      "languages": ["en", "es", "fr", "de"],
      "features": ["languageDetection"]
    },
    ...
  },
  "pricing": {
    "claude-whisper": { "unit": "minute", "cost": 0.005 },
    ...
  }
}
```

**How iOS App Uses Dynamic Capabilities:**

```swift
// Check if provider supports a capability (reads from remote config)
func supportsCapability(_ provider: AIProvider, _ capability: ProviderUsageCategory) -> Bool {
    guard let providerConfig = remoteConfig.providers[provider.rawValue],
          let capConfig = providerConfig.capabilities[capability.rawValue] else {
        return false
    }
    return capConfig.enabled
}

// Get available models for a capability
func availableModels(for provider: AIProvider, capability: ProviderUsageCategory) -> [ModelInfo] {
    remoteConfig.providers[provider.rawValue]?
        .capabilities[capability.rawValue]?
        .models ?? []
}

// Check if a feature is available
func hasFeature(_ provider: AIProvider, capability: ProviderUsageCategory, feature: String) -> Bool {
    remoteConfig.providers[provider.rawValue]?
        .capabilities[capability.rawValue]?
        .features.contains(feature) ?? false
}

// Get languages supported by provider for a capability
func supportedLanguages(for provider: AIProvider, capability: ProviderUsageCategory) -> [String] {
    remoteConfig.providers[provider.rawValue]?
        .capabilities[capability.rawValue]?
        .languages ?? []
}
```

**Dynamic UI Updates:**

When capabilities change remotely, the app automatically:
1. Shows/hides providers in capability dropdowns based on `enabled`
2. Updates available models in model picker based on `models[]`
3. Updates language dropdowns based on `languages[]`
4. Enables/disables features based on `featureFlags`
5. Shows announcements for new features/providers

**Files to Create:**
| File | Purpose |
|------|---------|
| `Services/Remote/RemoteConfigManager.swift` | Fetch, cache, parse remote config |
| `Services/Remote/RemoteConfig.swift` | Data models for remote config |
| `Services/Remote/CostCalculator.swift` | Calculate costs based on usage |
| `Views/CostAnalyticsView.swift` | Cost analytics dashboard |
| `Views/Components/CostSummaryCard.swift` | Total spend summary |
| `Views/Components/ProviderCostChart.swift` | Pie chart by provider |
| `Views/Components/UsageTimelineChart.swift` | Line chart over time |

**Files to Modify:**
| File | Changes |
|------|---------|
| `SharedSettings.swift` | Add cached config storage, cost tracking |
| `Models.swift` | Add `TranscriptionRecord.estimatedCost` field |
| `HistoryView.swift` | Display cost per item |
| `SettingsView.swift` | Add Cost Analytics navigation, refresh button |
| `Views/Components/ProviderHelpSheet.swift` | Show pricing from remote config |
| `TranscriptionOrchestrator.swift` | Calculate and store cost after transcription |

**Backend Setup (Hostinger KVM):**
```bash
# On Hostinger KVM (Ubuntu/Debian)

# 1. Install nginx
sudo apt update && sudo apt install nginx certbot python3-certbot-nginx

# 2. Create directory for config
sudo mkdir -p /var/www/swiftspeak-config
sudo chown $USER:$USER /var/www/swiftspeak-config

# 3. Create config.json
nano /var/www/swiftspeak-config/config.json

# 4. Configure nginx
sudo nano /etc/nginx/sites-available/swiftspeak-config
# server {
#     listen 80;
#     server_name config.yourdomain.com;
#     root /var/www/swiftspeak-config;
#     location / {
#         add_header Access-Control-Allow-Origin "*";
#         add_header Cache-Control "public, max-age=3600";
#     }
# }

# 5. Enable site
sudo ln -s /etc/nginx/sites-available/swiftspeak-config /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 6. Add HTTPS
sudo certbot --nginx -d config.yourdomain.com
```

**Fallback & Offline Handling:**
The iOS app must work even if the Hostinger server is temporarily unavailable:

1. **Bundled Fallback Config** - Ship a copy of config.json in app bundle
2. **Cache with Expiry** - Cache fetched config in UserDefaults/App Groups
3. **Graceful Degradation** - If fetch fails, use cached config (even if stale)
4. **Network-Resilient Flow:**
   ```
   App Launch
       │
       ▼
   ┌─────────────────────────┐
   │ Last fetch > 7 days?    │──No──→ Use cached config
   └─────────────────────────┘
       │ Yes
       ▼
   ┌─────────────────────────┐
   │ Fetch from Hostinger    │
   └─────────────────────────┘
       │
   ┌───┴───┐
   │       │
Success   Fail (timeout/error)
   │       │
   ▼       ▼
   ┌─────────────────────────┐
   │ Update cache, use new   │
   └─────────────────────────┘
           │
   ┌───────┴───────┐
   │               │
   ▼               ▼
   ┌─────────────────────────┐
   │ Use cached config       │──Cached exists──→ Use stale cache (show warning)
   └─────────────────────────┘
           │
           │ No cache
           ▼
   ┌─────────────────────────┐
   │ Use bundled fallback    │
   └─────────────────────────┘
   ```

5. **Stale Indicator** - If using stale cache (>30 days old), show subtle "Last updated X days ago" in Settings

**RemoteConfigManager Pseudocode:**
```swift
actor RemoteConfigManager {
    private let configURL = URL(string: "https://config.yourdomain.com/config.json")!
    private let cacheKey = "cachedProviderConfig"
    private let lastFetchKey = "lastConfigFetch"
    private let staleThreshold: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    func getConfig() async -> ProviderConfig {
        // 1. Check if we need to refresh
        if shouldRefresh() {
            if let freshConfig = await fetchRemoteConfig() {
                saveToCache(freshConfig)
                return freshConfig
            }
        }

        // 2. Try cached config
        if let cached = loadFromCache() {
            return cached
        }

        // 3. Fall back to bundled config
        return loadBundledConfig()
    }

    func forceRefresh() async -> Result<ProviderConfig, Error> {
        guard let config = await fetchRemoteConfig() else {
            return .failure(NetworkError.fetchFailed)
        }
        saveToCache(config)
        return .success(config)
    }

    private func fetchRemoteConfig() async -> ProviderConfig? {
        do {
            let (data, _) = try await URLSession.shared.data(from: configURL, timeout: 10)
            return try JSONDecoder().decode(ProviderConfig.self, from: data)
        } catch {
            print("Config fetch failed: \(error)")
            return nil
        }
    }
}
```

---

**Automatic Update Script (Hostinger):**

Create a Python script that updates pricing, capabilities, models, and languages automatically:

**File: `/var/www/swiftspeak-config/auto-update.py`**
```python
#!/usr/bin/env python3
"""
Auto-update provider pricing, capabilities, models, and languages.
Run via cron: 0 3 * * 0  /usr/bin/python3 /var/www/swiftspeak-config/auto-update.py
(Every Sunday at 3 AM)

This script maintains the master data for all providers.
When a provider adds/removes capabilities, update the PROVIDER_DATA dictionary below.
"""

import json
import requests
from datetime import datetime
from pathlib import Path
import shutil

CONFIG_PATH = Path("/var/www/swiftspeak-config/config.json")
BACKUP_DIR = Path("/var/www/swiftspeak-config/backups")

# ============================================================================
# MASTER DATA - Update this when providers change pricing/capabilities/models
# ============================================================================

PROVIDER_DATA = {
    "openai": {
        "displayName": "OpenAI",
        "capabilities": {
            "transcription": {
                "enabled": True,
                "models": [
                    {"id": "whisper-1", "name": "Whisper", "default": True}
                ],
                "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
                "features": ["languageDetection", "timestamps"]
            },
            "translation": {
                "enabled": True,
                "models": [
                    {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "default": True},
                    {"id": "gpt-4o", "name": "GPT-4o"}
                ],
                "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
                "features": ["contextAware", "formalityControl"]
            },
            "powerMode": {
                "enabled": True,
                "models": [
                    {"id": "gpt-4o", "name": "GPT-4o", "default": True},
                    {"id": "gpt-4o-mini", "name": "GPT-4o Mini"},
                    {"id": "o1", "name": "o1 (Reasoning)", "tier": "power"}
                ],
                "features": ["streaming", "functionCalling", "vision", "webSearch"]
            },
            "formatting": {
                "enabled": True,
                "models": [{"id": "gpt-4o-mini", "name": "GPT-4o Mini", "default": True}]
            }
        },
        "pricing": {
            "whisper-1": {"unit": "minute", "cost": 0.006},
            "gpt-4o": {"inputPerMToken": 2.50, "outputPerMToken": 10.00},
            "gpt-4o-mini": {"inputPerMToken": 0.15, "outputPerMToken": 0.60},
            "o1": {"inputPerMToken": 15.00, "outputPerMToken": 60.00}
        },
        "freeCredits": "$5 for new accounts",
        "apiKeyUrl": "https://platform.openai.com/api-keys",
        "docsUrl": "https://platform.openai.com/docs"
    },
    "anthropic": {
        "displayName": "Anthropic",
        "capabilities": {
            "transcription": {"enabled": False},  # Anthropic doesn't have STT (yet!)
            "translation": {
                "enabled": True,
                "models": [
                    {"id": "claude-3-5-sonnet-latest", "name": "Claude 3.5 Sonnet", "default": True},
                    {"id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku"}
                ],
                "languages": ["en", "es", "fr", "de", "ja", "zh", "ko"],
                "features": ["contextAware"]
            },
            "powerMode": {
                "enabled": True,
                "models": [
                    {"id": "claude-3-5-sonnet-latest", "name": "Claude 3.5 Sonnet", "default": True},
                    {"id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku"},
                    {"id": "claude-3-opus-latest", "name": "Claude 3 Opus", "tier": "power"}
                ],
                "features": ["streaming", "functionCalling", "vision", "computerUse"]
            },
            "formatting": {
                "enabled": True,
                "models": [{"id": "claude-3-5-haiku-latest", "name": "Claude 3.5 Haiku", "default": True}]
            }
        },
        "pricing": {
            "claude-3-5-sonnet-latest": {"inputPerMToken": 3.00, "outputPerMToken": 15.00},
            "claude-3-5-haiku-latest": {"inputPerMToken": 0.80, "outputPerMToken": 4.00},
            "claude-3-opus-latest": {"inputPerMToken": 15.00, "outputPerMToken": 75.00}
        },
        "apiKeyUrl": "https://console.anthropic.com/settings/keys",
        "docsUrl": "https://docs.anthropic.com"
    },
    # ... (other providers - deepgram, deepl, google, azure, assemblyai, elevenlabs, local)
    # Full data for all providers stored here - update when capabilities change
}

# Status page endpoints (Atlassian Statuspage format)
STATUS_ENDPOINTS = {
    "openai": "https://status.openai.com/api/v2/status.json",
    "anthropic": "https://status.anthropic.com/api/v2/status.json",
    "deepgram": "https://status.deepgram.com/api/v2/status.json",
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def backup_config():
    """Create timestamped backup."""
    BACKUP_DIR.mkdir(exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = BACKUP_DIR / f"config-{timestamp}.json"
    if CONFIG_PATH.exists():
        shutil.copy(CONFIG_PATH, backup_path)
        print(f"✓ Backup created: {backup_path}")
        # Keep only last 30 backups
        backups = sorted(BACKUP_DIR.glob("config-*.json"), reverse=True)
        for old_backup in backups[30:]:
            old_backup.unlink()

def load_config():
    """Load current config or create empty one."""
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH) as f:
            return json.load(f)
    return {"version": "1.0.0", "providers": {}}

def save_config(config):
    """Save updated config with version bump."""
    config["lastUpdated"] = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    # Bump patch version
    version_parts = config["version"].split(".")
    version_parts[2] = str(int(version_parts[2]) + 1)
    config["version"] = ".".join(version_parts)

    with open(CONFIG_PATH, "w") as f:
        json.dump(config, f, indent=2)

    print(f"✓ Config saved: version {config['version']}")

def check_provider_status(provider_key):
    """Check if provider API is operational via status page."""
    if provider_key not in STATUS_ENDPOINTS:
        return "operational"  # Assume operational if no status page

    try:
        resp = requests.get(STATUS_ENDPOINTS[provider_key], timeout=10)
        if resp.ok:
            data = resp.json()
            indicator = data.get("status", {}).get("indicator", "none")
            return "operational" if indicator == "none" else "degraded"
    except Exception as e:
        print(f"  ⚠ Could not check {provider_key} status: {e}")

    return "unknown"

def update_providers(config):
    """Update all provider data from PROVIDER_DATA."""
    for provider_key, provider_data in PROVIDER_DATA.items():
        print(f"Updating {provider_key}...")

        # Merge with existing data (preserve any manual additions)
        existing = config["providers"].get(provider_key, {})

        # Update from master data
        config["providers"][provider_key] = {
            **provider_data,
            "status": check_provider_status(provider_key)
        }

        # Log capability changes
        if existing:
            for cap_type in ["transcription", "translation", "powerMode", "formatting"]:
                old_enabled = existing.get("capabilities", {}).get(cap_type, {}).get("enabled", False)
                new_enabled = provider_data.get("capabilities", {}).get(cap_type, {}).get("enabled", False)
                if old_enabled != new_enabled:
                    action = "ENABLED" if new_enabled else "DISABLED"
                    print(f"  ⚡ {provider_key}.{cap_type}: {action}")

        print(f"  ✓ {provider_key} updated")

    return config

def update_announcements(config):
    """Remove expired announcements, add new ones."""
    now = datetime.utcnow()
    if "announcements" in config:
        config["announcements"] = [
            a for a in config["announcements"]
            if datetime.fromisoformat(a["validUntil"].replace("Z", "+00:00")).replace(tzinfo=None) > now
        ]
    return config

def main():
    print(f"\n{'='*60}")
    print(f"SwiftSpeak Config Auto-Update")
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*60}\n")

    # Backup current config
    backup_config()

    # Load and update
    config = load_config()
    config = update_providers(config)
    config = update_announcements(config)

    # Update metadata
    config["schemaVersion"] = 2
    config["defaultProviders"] = {
        "transcription": "openai",
        "translation": "openai",
        "powerMode": "openai",
        "formatting": "openai"
    }
    config["featureFlags"] = {
        "powerModeEnabled": True,
        "translationEnabled": True,
        "customTemplatesEnabled": True,
        "costTrackingEnabled": True
    }

    # Save
    save_config(config)

    print(f"\n{'='*60}")
    print("Auto-update complete!")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    main()
```

**When to Update PROVIDER_DATA:**

| Change Type | What to Update |
|-------------|----------------|
| New model released | Add to `capabilities.<type>.models[]` and `pricing` |
| Model deprecated | Remove from `models[]` and `pricing` |
| Price change | Update `pricing.<modelId>` values |
| New capability | Set `capabilities.<type>.enabled = True`, add models |
| Capability removed | Set `capabilities.<type>.enabled = False` |
| New language | Add to `capabilities.<type>.languages[]` |
| New feature | Add to `capabilities.<type>.features[]` |

**Example: Anthropic Adds Transcription**
```python
# Before
"anthropic": {
    "capabilities": {
        "transcription": {"enabled": False},
        ...
    }
}

# After (just update PROVIDER_DATA)
"anthropic": {
    "capabilities": {
        "transcription": {
            "enabled": True,
            "models": [{"id": "claude-whisper", "name": "Claude Whisper", "default": True}],
            "languages": ["en", "es", "fr", "de"],
            "features": ["languageDetection"]
        },
        ...
    },
    "pricing": {
        "claude-whisper": {"unit": "minute", "cost": 0.005},
        ...
    }
}
```

Run `python3 auto-update.py` and the app will automatically show Anthropic in the transcription provider dropdown!

**Cron Setup:**
```bash
# Edit crontab
crontab -e

# Add line to run every Sunday at 3 AM:
0 3 * * 0 /usr/bin/python3 /var/www/swiftspeak-config/auto-update.py >> /var/log/swiftspeak-config-update.log 2>&1

# Or run daily at 4 AM:
0 4 * * * /usr/bin/python3 /var/www/swiftspeak-config/auto-update.py >> /var/log/swiftspeak-config-update.log 2>&1
```

**Manual Update Script (for quick edits):**
```bash
#!/bin/bash
# /var/www/swiftspeak-config/update-config.sh

CONFIG_FILE="/var/www/swiftspeak-config/config.json"
BACKUP_DIR="/var/www/swiftspeak-config/backups"

# Create backup
mkdir -p $BACKUP_DIR
cp $CONFIG_FILE "$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).json"

# Edit config
${EDITOR:-nano} $CONFIG_FILE

# Update lastUpdated timestamp
sed -i "s/\"lastUpdated\": \".*\"/\"lastUpdated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" $CONFIG_FILE

# Validate JSON
python3 -m json.tool $CONFIG_FILE > /dev/null && echo "✓ Valid JSON" || echo "✗ Invalid JSON!"

echo "Config updated."
```

**Required Python packages on Hostinger:**
```bash
pip3 install requests
```

---

## NOT YET IMPLEMENTED (From Original Plan)

### Views to Create:
- `TemplatesView.swift` - Custom template editor
- `DiffHighlighter.swift` - Visual diff for refinements
- `ProfileEditor.swift` - Global memory/profile system (V2)
- `CommunityBrowser.swift` - Browse shared Power Modes (V2)

### Features to Implement:
- [ ] QR code scanner for API keys
- [ ] In-keyboard inline recording (Raw mode only)
- [ ] Silence detection for auto-stop
- [ ] Voice-based Power Mode creation
- [ ] Confetti on FullAccessScreen (currently only on AllSetScreen)
- [ ] Real audio recording (currently mock)
- [ ] Real API integrations (currently mock)

---

## Security Architecture (Phase 6)

### API Key Storage: iOS Keychain

**Current (INSECURE):** API keys stored in UserDefaults (plain text, extractable from backups)

**Target:** Migrate to iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

```swift
// KeychainManager.swift (NEW FILE)
struct KeychainManager {
    enum KeychainKey: String {
        case openAIAPIKey = "com.swiftspeak.openai.apikey"
        case anthropicAPIKey = "com.swiftspeak.anthropic.apikey"
        case elevenLabsAPIKey = "com.swiftspeak.elevenlabs.apikey"
        case deepgramAPIKey = "com.swiftspeak.deepgram.apikey"
        case googleAPIKey = "com.swiftspeak.google.apikey"
        case localAuthToken = "com.swiftspeak.local.authtoken"
    }

    static func save(key: KeychainKey, value: String) -> Bool
    static func get(key: KeychainKey) -> String?
    static func delete(key: KeychainKey) -> Bool
    static func deleteAll() -> Bool
}
```

**Migration path:**
1. On first launch after update, migrate keys from UserDefaults to Keychain
2. Delete keys from UserDefaults after successful migration
3. Update `SharedSettings` to use `KeychainManager` for API keys
4. Keep non-sensitive settings in UserDefaults (modes, preferences)

### Biometric Authentication (Selective - History & API Keys Only)

**IMPORTANT UX PRINCIPLE:** The core recording flow (keyboard → app → record → transcribe → return) must remain completely frictionless. NO Face ID prompts during normal usage.

**What IS protected (optional, user-enabled):**
- History tab (contains all past transcriptions)
- Viewing/editing API keys in Settings

**What is NOT protected (for speed):**
- App launch
- Recording flow
- Settings (except API keys section)
- Power Mode execution

**Settings UI:**
```
Settings → Privacy & Security
┌─────────────────────────────────────────┐
│ PRIVACY & SECURITY                      │
│                                         │
│ Protect History              ────●      │
│ Require Face ID to view past            │
│ transcriptions                          │
│                                         │
│ Protect API Keys             ────●      │
│ Require Face ID to view or edit         │
│ your API keys                           │
└─────────────────────────────────────────┘
```

**Implementation:**
```swift
// BiometricManager.swift (NEW FILE)
import LocalAuthentication

struct BiometricManager {
    static var biometricType: LABiometryType  // .faceID, .touchID, .none
    static var isAvailable: Bool

    /// Authenticate for sensitive data access
    /// - Parameter reason: Shown to user (e.g., "Access your transcription history")
    static func authenticate(reason: String) async -> Bool
}
```

**Flow when History is protected:**
1. User taps History tab
2. Blur overlay appears with Face ID prompt
3. Success → History content revealed
4. Fail → Stay on blur, show "Try Again" or go back

**Protected actions (when enabled):**
- Viewing History tab
- Viewing API keys in provider settings
- Editing/deleting API keys

### Data Protection

**Transcription History Encryption:**
- Use iOS Data Protection API (`FileProtectionType.complete`)
- History file only accessible when device is unlocked
- Alternatively: Encrypt with user-derived key before storing

**Audio Files:**
- Already using `temporaryDirectory` ✅
- Files deleted after API upload ✅
- Add explicit cleanup on app termination

### Secure Data Deletion

```
Settings → About → Delete All Data
┌─────────────────────────────────────────┐
│ ⚠️ Delete All Data                      │
│                                         │
│ This will permanently delete:           │
│ • All API keys                          │
│ • Transcription history                 │
│ • Custom templates                      │
│ • Power Modes                           │
│ • All preferences                       │
│                                         │
│ This action cannot be undone.           │
│                                         │
│ [Cancel]            [Delete Everything] │
└─────────────────────────────────────────┘
```

### App Store Privacy Labels

Data collected by SwiftSpeak:

| Data Type | Collected | Linked to User | Used for Tracking |
|-----------|-----------|----------------|-------------------|
| Audio | Yes (temporary) | No | No |
| User Content (transcripts) | Yes | No | No |
| Identifiers | No | - | No |
| Usage Data | No | - | No |
| Diagnostics | No | - | No |

**Privacy disclosures required:**
- Microphone usage description
- Full Access keyboard justification
- Data not sold to third parties
- Data processed on-device or via user's own API keys

---

## Technical Requirements

- **iOS 17.0+** minimum deployment target
- **Xcode 15+** for development
- **Apple Developer Account** for keyboard extension
- **OpenAI API key** for Whisper and GPT-4
- **App Groups** entitlement
- **Network Extension** entitlement (for keyboard API calls)

---

## Keyboard Extension Entitlements

```xml
<!-- SwiftSpeakKeyboard.entitlements -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.pawelgawliczek.swiftspeak</string>
</array>
```

```xml
<!-- Info.plist -->
<key>RequestsOpenAccess</key>
<true/>
```

---

## Estimated API Costs

| Feature | API | Cost |
|---------|-----|------|
| Transcription | Whisper | $0.006/min |
| Translation | GPT-4o-mini | ~$0.0001/request |
| Formatting | GPT-4o-mini | ~$0.0001/request |
| Power Mode | GPT-4o | ~$0.001/request |

Typical 30-second dictation: ~$0.003 + $0.0002 = **$0.0032**

---

## Data Models Summary (As Implemented in Models.swift)

### Core Models

| Model | Purpose |
|-------|---------|
| `SubscriptionTier` | free, pro, power |
| `FormattingMode` | raw, email, formal, casual |
| `Language` | 13 languages with flags |
| `TranscriptionRecord` | History item |
| `RecordingState` | State machine for recording |

### AI Provider Models

| Model | Purpose |
|-------|---------|
| `AIProvider` | Unified enum: openAI, anthropic, google, elevenLabs, deepgram, local |
| `AIProviderConfig` | API key + enabled capabilities + model per capability + localConfig |
| `ProviderUsageCategory` | transcription, translation, powerMode |
| `LocalProviderType` | ollama, lmStudio, openAICompatible |
| `LocalProviderConfig` | type, baseURL, authToken, streamingEnabled, timeoutSeconds |
| `LocalProviderConnectionResult` | Connection test result with latency and models |

### Power Mode Models

| Model | Purpose |
|-------|---------|
| `PowerMode` | Mode configuration (name, icon, instruction, capabilities) |
| `PowerModeCapability` | webSearch, bashComputerUse, codeExecution |
| `PowerModeColorPreset` | 10 color options with gradients |
| `PowerModeQuestion` | Clarifying question from AI |
| `PowerModeQuestionOption` | Quick-tap option for questions |
| `PowerModeResult` | Single execution result |
| `PowerModeSession` | Version history container |
| `PowerModeExecutionState` | Execution state machine |

### Other Models

| Model | Purpose |
|-------|---------|
| `CustomTemplate` | User-defined template (NOT YET USED) |
| `VocabularyEntry` | Word replacement rule (NOT YET FUNCTIONAL) |
| `VocabularyCategory` | name, company, acronym, slang, technical, other |

---

## Quick Reference Commands

```bash
# Open project in Xcode
open ~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeak.xcodeproj

# Build for simulator
xcodebuild -project SwiftSpeak.xcodeproj -scheme SwiftSpeak \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## Session Start Checklist

1. Read this IMPLEMENTATION_PLAN.md for context
2. Check current phase status above
3. UI is the source of truth - check SwiftUI views for actual implementation
4. Models.swift contains all data models
5. Focus on mock data until Phase 1 begins real API integration
