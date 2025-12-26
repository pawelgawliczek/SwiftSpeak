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
| Anthropic | ❌ | ✅ | ✅ | claude-3-5-sonnet, claude-3-5-haiku, claude-3-opus |
| Google Gemini | ❌ | ✅ | ✅ | gemini-2.0-flash-exp, gemini-1.5-pro, gemini-1.5-flash |
| ElevenLabs | ✅ | ❌ | ❌ | scribe_v1 (2.5 hrs/month free) |
| Deepgram | ✅ | ❌ | ❌ | nova-2, nova, enhanced, base |
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

### Phase 1: Core Transcription + Testing Infrastructure
**Execution Guide:** See `/PHASE1_PLAN.md` for step-by-step implementation details.

**Testing Infrastructure:**
1. [ ] Create SwiftSpeakTests unit test target
2. [ ] Create SwiftSpeakUITests UI test target
3. [ ] Write model tests (AIProvider, FormattingMode, etc.)
4. [ ] Write service tests with mocks

**Core Transcription:**
1. [ ] Provider abstraction layer (protocols)
2. [ ] Real audio recording with AVAudioRecorder
3. [ ] OpenAI Whisper API integration
4. [ ] GPT-4 formatting integration (Email, Formal, Casual modes)
5. [ ] App Groups for keyboard ↔ app communication
6. [ ] URL scheme handling for keyboard → app launch
7. [ ] Auto-return to previous app + clipboard insertion
8. [ ] Silence detection for auto-stop (OPTIONAL)

### Phase 2: Templates & Translation
1. [ ] GPT-4 formatting integration (Email, Formal, Casual modes)
2. [ ] Translation feature with LLM
3. [ ] Custom template editor (TemplatesView.swift - NOT YET CREATED)
4. [ ] Template storage (local)

### Phase 3: Multi-Provider Support
1. [ ] ElevenLabs STT integration
2. [ ] Deepgram STT integration
3. [ ] Anthropic Claude LLM integration
4. [ ] Google Gemini LLM integration
5. [x] Local AI integration (Ollama, LM Studio, OpenAI-compatible) - **UI COMPLETE**
   - Provider type selection (Ollama, LM Studio, OpenAI-compatible)
   - Server URL configuration
   - Optional API token authentication
   - Test Connection with model discovery
   - Streaming and timeout options
6. [ ] Provider switching logic

### Phase 4: Power Mode Backend
1. [ ] Power Mode execution engine
2. [ ] Web search capability implementation
3. [ ] Bash/Computer use capability implementation (desktop only?)
4. [ ] Code execution capability implementation
5. [ ] Question asking with quick-tap UI
6. [ ] LLM streaming responses

### Phase 5: Advanced Features
1. [ ] Vocabulary replacement processing
2. [ ] Diff highlighting for refinements (DiffHighlighter.swift - NOT YET CREATED)
3. [ ] Per-mode memory storage (OPTIONAL)
4. [ ] Voice-based Power Mode creation (OPTIONAL)

### Phase 6: Monetization & Polish
1. [ ] StoreKit 2 / RevenueCat subscription integration
2. [ ] Paywall logic (Free/Pro/Power limits)
3. [ ] Usage tracking (free tier limits)
4. [ ] Error handling & offline states
5. [ ] App Store submission

### Phase 7: Community Features (OPTIONAL/V2)
1. [ ] Global profile system (ProfileEditor.swift)
2. [ ] Community Power Mode sharing (CommunityBrowser.swift)
3. [ ] Mode rating and discovery
4. [ ] Backend for community sync

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
