# CLAUDE.md - SwiftSpeak iOS Voice Keyboard

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**SwiftSpeak** is an iOS custom keyboard app for voice transcription, translation, and AI formatting. Users switch to the SwiftSpeak keyboard, tap a mic button, speak, and text is inserted into any app.

**Value Proposition:** Voice-to-text with AI formatting modes - like having a professional writer format your dictation in real-time.

## Project Location

```
~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeak.xcodeproj
```

**Important Paths:**
- Main App: `~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeak/`
- Keyboard Extension: `~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeakKeyboard/`
- Implementation Plan: `~/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`
- Archived Plans: `archive/` (all phase plans completed)

## Bundle IDs & Configuration

| Component | Bundle ID |
|-----------|-----------|
| Main App | `pawelgawliczek.SwiftSpeak` |
| Keyboard Extension | `pawelgawliczek.SwiftSpeak.SwiftSpeakKeyboard` |
| App Group | `group.pawelgawliczek.swiftspeak` |

**Technical Requirements:**
- iOS 17.0+ minimum deployment target
- iOS 18.0+ for Apple Translation (gracefully disabled on older versions)
- Xcode 15+ for development
- SwiftUI for all UI components

## Current Project State

### Phase 0: UI/UX Prototype - COMPLETE ✅
All screens functional with mock data, full navigation, polished animations.

### Phase 1: Core Transcription - COMPLETE ✅
Provider protocols, audio recording, OpenAI services, TranscriptionOrchestrator.

### Phase 2: Templates & Translation - COMPLETE ✅
Translation, auto-return, custom templates, waveform audio connection.

### Phase 3: Multi-Provider Support - COMPLETE ✅
9 providers implemented: OpenAI, Anthropic, Gemini, AssemblyAI, Deepgram, Google STT, DeepL, Google Translate, Azure.

### Phase 3A: Provider Help & Language Guidance - COMPLETE ✅
- [x] All UI components created (ProviderHelpSheet, StatusDashboard, LanguageSupportView, SmartLanguagePicker)
- [x] ProviderHelpSheet integrated with live pricing from RemoteConfigManager
- [x] ProviderLanguageSupport refactored to use RemoteConfigManager as single source of truth

### Phase 4: Power Mode Backend - COMPLETE ✅
- [x] Phase 4a: Conversation Contexts (ConversationContext model, ContextsView, ContextEditorSheet)
- [x] Phase 4b: Three-Tier Memory System (MemoryManager, global/context/powerMode memory)
- [x] Phase 4c: PowerModeOrchestrator (central coordinator, context/memory injection, wired to UI)
- [x] Phase 4d: LLM Streaming (SSEParser, streaming for OpenAI/Anthropic/Gemini, progressive UI)
- [x] Phase 4e: RAG System (DocumentParser, TextChunker, EmbeddingService, VectorStore, RAGOrchestrator)
- [x] Phase 4f: Webhooks (WebhookExecutor, global webhooks with per-PowerMode assignment)
- [x] App Auto-Enable: Pre-built library of 100+ apps for automatic context/powermode activation
- [ ] Phase 4g: Transcription Streaming (OPTIONAL - WebSocket real-time transcription)

### Phase 6: Security & Data Protection - COMPLETE ✅
- [x] KeychainManager for secure API key storage (shared between app and keyboard extension)
- [x] BiometricAuthManager with session-based Face ID/Touch ID (5-min timeout)
- [x] BiometricGateView wrapper for protected views (Settings, History)
- [x] User-configurable data retention (Never, 7/30/90 days auto-delete)
- [x] Security section in SettingsView with biometric toggle and retention picker

### Phase 7: Subscription Service - COMPLETE ✅
- [x] SubscriptionService with RevenueCat integration (configure, purchase, restore)
- [x] SubscriptionError for error handling
- [x] Configuration.storekit for local testing
- [x] Feature gating by tier (Free, Pro, Power)
- [x] PaywallView connected to SubscriptionService
- [ ] App Store Connect configuration (deployment task)

### Phase 9: Remote Configuration & Cost Analytics - COMPLETE ✅
- [x] Phase 9a: Firebase setup (RemoteConfig.swift, RemoteConfigManager.swift)
- [x] Phase 9b: Config change detection (ConfigChangeDetector.swift, ConfigUpdateSheet.swift)
- [x] Phase 9c: Cost tracking (CostCalculator.swift, CostBreakdown in Models.swift)
- [x] Phase 9d: Cost display in HistoryView (cost badge, breakdown in detail view)
- [x] Phase 9e: Cost Analytics Dashboard (CostAnalyticsView.swift)
- [x] Phase 9f: Integration (ProviderHelpSheet uses remote pricing, ProviderLanguageSupport uses remote config)
- [x] Hostinger cron script (scripts/update_firebase_config.py with Claude CLI)
- [x] Tests (RemoteConfigTests.swift, CostCalculatorTests.swift)

### Phase 10: Privacy Mode & Local Provider Restructure - COMPLETE ✅
- [x] Phase 10a: Provider Hierarchy (ProviderType, ProviderSelection, ProviderDefaults)
- [x] Phase 10b: On-Device AI Views (WhisperKitSetupView, AppleIntelligenceSetupView, AppleTranslationSetupView)
- [x] Phase 10c: WhisperKit Language Support (per-model language capabilities)
- [x] Phase 10d: Provider UI Polish (improved dropdown, cloud/local sections)
- [x] Phase 10e: Privacy Mode Implementation (indicator, cloud blocking, Power Mode warnings)
- [x] Phase 10f: SDK Integration (WhisperKit, Apple Translation, Apple Intelligence wired to orchestrators)

### Phase 11: Orchestration Security, Reliability & UX - COMPLETE ✅
Critical security and reliability improvements for the transcription/formatting pipeline:

- [x] Phase 11a: PromptSanitizer (injection protection for vocabularies, contexts, webhooks, RAG)
- [x] Phase 11b: Formatting provider verification (confirmed correct behavior)
- [x] Phase 11c: MemoryUpdateCoordinator (actor-based serialization, prevents race conditions)
- [x] Phase 11d: TokenCounter + PromptLimits (configurable token budgets per component)
- [x] Phase 11e: RetryPolicy + PendingAudio queue (exponential backoff, audio preservation)
- [x] Phase 11f: ProviderHealthTracker (circuit breaker for provider failover)
- [x] Phase 11g: WebhookCircuitBreaker (parallel webhook execution, timeout handling)
- [x] Phase 11j: Audio duration validation (min 0.5s, max 10 minutes, file size limits)
- [x] Settings UI: Retry settings section + Advanced Token Limits view with descriptions
- [x] Keyboard UI: Status banner, pending audio indicator, auto-insert on return

**Key Token Limits (user-configurable in Advanced Settings):**
- Global Memory: 500 tokens (AI's persistent memory)
- Context Memory: 400 tokens (per-context memory)
- RAG Chunks: 2000 tokens (document content)
- User Input: 4000 tokens (transcribed text)

### App Store Submission Preparation - COMPLETE ✅
- [x] Fixed iOS deployment target (26.2 → 17.0)
- [x] Added microphone privacy description to build settings
- [x] Registered URL scheme in build settings
- [x] Created privacy manifests (PrivacyInfo.xcprivacy for both targets)
- [x] Implemented unified logging system (SharedLogManager, LogSanitizer, LogExporter)
- [x] Created DiagnosticsView for log viewing/export
- [x] Converted all print() statements to privacy-safe logging
- [x] Fixed force unwraps in WhisperKit and RAG services
- [x] iOS 18 availability: Apple Translation uses runtime `#available` checks (gracefully disabled on iOS 17)
- [x] RecordingView uses `localTranslationHandlerIfAvailable()` extension for backward compatibility

### Remaining Work
| Phase | Task | Priority |
|-------|------|----------|
| 7 | App Store Connect subscription configuration | Medium (deployment) |
| 4g | WebSocket real-time transcription streaming | Low (optional) |
| - | RevenueCat production API key | High (before submission) |

## iOS Keyboard Architecture Constraint

**CRITICAL:** iOS keyboard extensions **cannot access the microphone**. This requires a two-app architecture:

```
┌─────────────────────────────────────┐
│         Keyboard Extension          │
│  ┌──────────┐  ┌──────────┐        │
│  │ 🎤 Record │  │ 🌍 Translate│       │
│  └──────────┘  └──────────┘        │
│  ┌─────────────────────────────┐   │
│  │ Mode: Email ▼               │   │
│  └─────────────────────────────┘   │
└───────────────┬─────────────────────┘
                │ URL Scheme (swiftspeak://)
                ↓
┌─────────────────────────────────────┐
│          Containing App             │
│  - Records audio (AVAudioRecorder)  │
│  - Calls OpenAI Whisper API         │
│  - Applies GPT-4 formatting         │
│  - Returns text via App Groups      │
└───────────────┬─────────────────────┘
                │
                ↓
        Auto-return to original app
        Text inserted via clipboard
```

**URL Scheme Format:**
```
swiftspeak://record?mode=email&translate=false&target=es
swiftspeak://record?mode=raw&translate=true&target=french
```

## Implementation Phases Summary

| Phase | Name | Status |
|-------|------|--------|
| 0 | UI/UX Prototype | ✅ Complete |
| 1 | Core Transcription | ✅ Complete |
| 2 | Templates & Translation | ✅ Complete |
| 3 | Multi-Provider Support | ✅ Complete |
| 3A | Provider Help & Language Guidance | ✅ Complete |
| 4 | Power Mode Backend | ✅ Complete (4g optional) |
| 6 | Security & Data Protection | ✅ Complete |
| 7 | Subscription Service | ✅ Complete |
| 9 | Remote Config & Cost Analytics | ✅ Complete |
| 10 | Privacy Mode & Local Providers | ✅ Complete |
| 11 | Orchestration Security & Reliability | ✅ Complete |
| - | App Store Submission Preparation | ✅ Complete |

## Current File Structure

```
SwiftSpeak/
├── SwiftSpeak.xcodeproj
├── IMPLEMENTATION_PLAN.md
├── PHASE1_PLAN.md
├── CLAUDE.md
├── SwiftSpeak/                          # Containing App
│   ├── SwiftSpeakApp.swift              # @main entry (pre-warms audio session)
│   ├── ContentView.swift                # Main app navigation
│   ├── SharedSettings.swift             # App Groups data + settings management
│   │
│   ├── Services/
│   │   ├── Protocols/
│   │   │   ├── TranscriptionProvider.swift
│   │   │   ├── FormattingProvider.swift
│   │   │   ├── TranslationProvider.swift
│   │   │   ├── AudioRecorderProtocol.swift      # Phase 4c - Audio abstraction
│   │   │   ├── ProviderFactoryProtocol.swift    # Phase 4c - Factory abstraction
│   │   │   └── MemoryManagerProtocol.swift      # Phase 4c - Memory abstraction
│   │   ├── Audio/
│   │   │   ├── AudioSessionManager.swift
│   │   │   └── AudioRecorder.swift
│   │   ├── Memory/
│   │   │   ├── MemoryManager.swift              # Phase 4b - Memory update/compression
│   │   │   └── MemoryUpdateCoordinator.swift    # Phase 11c - Actor-based serialization
│   │   ├── Security/                            # Phase 6 + 11 - Security services
│   │   │   ├── KeychainManager.swift            # Secure API key storage
│   │   │   ├── BiometricAuthManager.swift       # Face ID/Touch ID with session
│   │   │   └── PromptSanitizer.swift            # Phase 11a - Prompt injection protection
│   │   ├── Remote/                              # Phase 9 - Remote config & cost
│   │   │   ├── RemoteConfig.swift               # Data models for provider config
│   │   │   ├── RemoteConfigManager.swift        # Firebase fetch/cache/listen
│   │   │   ├── ConfigChangeDetector.swift       # Detect pricing/model changes
│   │   │   └── CostCalculator.swift             # Cost calculation logic
│   │   ├── Subscription/                        # Phase 7 - Subscriptions
│   │   │   ├── SubscriptionService.swift        # RevenueCat integration
│   │   │   └── SubscriptionError.swift          # Error handling
│   │   ├── Providers/
│   │   │   ├── OpenAI/
│   │   │   │   ├── OpenAITranscriptionService.swift
│   │   │   │   └── OpenAIFormattingService.swift
│   │   │   ├── Local/                           # Phase 10f - On-device providers
│   │   │   │   ├── WhisperKitTranscriptionService.swift
│   │   │   │   ├── AppleTranslationService.swift
│   │   │   │   ├── LocalTranslationManager.swift    # Bridge for SwiftUI translationTask
│   │   │   │   ├── AppleIntelligenceFormattingService.swift
│   │   │   │   └── LocalProviderErrors.swift
│   │   │   ├── Mock/
│   │   │   │   ├── MockTranscriptionProvider.swift
│   │   │   │   ├── MockFormattingProvider.swift
│   │   │   │   ├── MockAudioRecorder.swift      # Phase 4c - For testing
│   │   │   │   ├── MockProviderFactory.swift    # Phase 4c - For testing
│   │   │   │   ├── MockMemoryManager.swift      # Phase 4c - For testing
│   │   │   │   └── MockKeychainManager.swift    # Phase 6 - For testing
│   │   │   ├── TokenCounter.swift               # Phase 11d - Token estimation & limits
│   │   │   └── ProviderHealthTracker.swift      # Phase 11f - Provider circuit breaker
│   │   ├── Orchestration/
│   │   │   ├── TranscriptionOrchestrator.swift  # Includes cost calculation
│   │   │   ├── PowerModeOrchestrator.swift      # Phase 4c - Power Mode coordinator
│   │   │   └── PromptContext.swift              # Phase 4c - Context builder
│   │   ├── Network/
│   │   │   ├── APIClient.swift
│   │   │   └── RetryPolicy.swift                # Phase 11e - Exponential backoff retry
│   │   ├── Webhooks/
│   │   │   └── WebhookCircuitBreaker.swift      # Phase 11g - Webhook circuit breaker
│   │   ├── Logging/                             # App Store Prep - Unified logging
│   │   │   ├── Logging.swift                    # Logger extensions for os.log
│   │   │   └── LogExporter.swift                # Export logs to shareable .txt file
│   │   ├── ProviderFactory.swift
│   │   └── TranscriptionError.swift
│   │
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   ├── WelcomeScreen.swift
│   │   │   ├── HowItWorksScreen.swift
│   │   │   ├── EnableKeyboardScreen.swift
│   │   │   ├── FullAccessScreen.swift
│   │   │   ├── APIKeyScreen.swift
│   │   │   └── AllSetScreen.swift
│   │   ├── PowerMode/
│   │   │   ├── PowerModeListView.swift
│   │   │   ├── PowerModeEditorView.swift
│   │   │   ├── PowerModeExecutionView.swift
│   │   │   ├── PowerModeResultView.swift
│   │   │   ├── PowerModeQuestionView.swift
│   │   │   └── Components/
│   │   │       └── IconPicker.swift
│   │   ├── Components/
│   │   │   ├── WaveformView.swift
│   │   │   ├── Animations.swift
│   │   │   ├── ProviderHelpSheet.swift         # Phase 3A - Setup guide (uses remote pricing)
│   │   │   ├── ProviderStatusDashboard.swift   # Phase 3A - Status card
│   │   │   ├── SmartLanguagePicker.swift       # Phase 3A - Language dropdown
│   │   │   ├── IncompatibilityWarning.swift    # Phase 3A - Warning banners
│   │   │   ├── AppAssignmentSection.swift      # App auto-enable for contexts/powermodes
│   │   │   ├── BiometricGateView.swift         # Phase 6 - Auth wrapper for protected views
│   │   │   ├── LockedView.swift                # Phase 6 - "Unlock with Face ID" UI
│   │   │   └── ConfigUpdateSheet.swift         # Phase 9 - "What's New" modal
│   │   ├── Settings/                           # Phase 4a/4b/10/11 - Settings views
│   │   │   ├── ContextsView.swift              # Phase 4a - Context list
│   │   │   ├── ContextEditorSheet.swift        # Phase 4a - Edit context
│   │   │   ├── ContextDetailView.swift         # Phase 4a - View context
│   │   │   ├── MemoryView.swift                # Phase 4b - Memory management
│   │   │   ├── MemoryEditorSheet.swift         # Phase 4b - Edit memory
│   │   │   ├── AppLibraryView.swift            # App library browser with category reassignment
│   │   │   ├── WhisperKitSetupView.swift       # Phase 10b - WhisperKit setup & download
│   │   │   ├── AppleIntelligenceSetupView.swift # Phase 10b - Apple Intelligence config
│   │   │   ├── AppleTranslationSetupView.swift # Phase 10b - Translation languages
│   │   │   ├── LocalModelStorageView.swift     # Phase 10 - Storage management
│   │   │   ├── AdvancedTokenLimitsView.swift   # Phase 11 - Token limit configuration
│   │   │   ├── PendingAudioListView.swift      # Phase 11 - Pending recordings management
│   │   │   └── DiagnosticsView.swift           # App Store Prep - Log viewer & export
│   │   ├── RecordingView.swift          # Uses real TranscriptionOrchestrator
│   │   ├── SettingsView.swift
│   │   ├── HistoryView.swift            # Phase 9 - Cost badge and breakdown
│   │   ├── CostAnalyticsView.swift      # Phase 9 - Usage analytics dashboard
│   │   ├── PaywallView.swift
│   │   ├── KeyboardPreviewView.swift
│   │   ├── ProviderComparisonView.swift        # Phase 3A - Provider selection
│   │   └── LanguageSupportView.swift           # Phase 3A - Language matrix
│   │
│   └── Shared/
│       ├── Constants.swift              # API endpoints, timeouts, AudioValidation (Phase 11j)
│       ├── Models.swift                 # AIProvider, FormattingMode, Language, PendingAudio, ProcessingStatus (Phase 11)
│       ├── Theme.swift                  # AppTheme, HapticManager
│       ├── ProviderLanguageSupport.swift       # Phase 3A - Language support data
│       ├── ProviderHelpContent.swift           # Phase 3A - Setup guides
│       ├── AppLibrary.swift             # Pre-built database of 100+ apps for auto-enable
│       ├── LogSanitizer.swift           # App Store Prep - Sanitize sensitive data from logs
│       ├── SharedLogManager.swift       # App Store Prep - App Groups file logging (shared with keyboard)
│       └── PrivacyInfo.xcprivacy        # App Store Prep - Privacy manifest
│
├── SwiftSpeakKeyboard/                  # Keyboard Extension
│   ├── KeyboardViewController.swift
│   ├── KeyboardView.swift
│   ├── LogSanitizer.swift               # Copy of Shared/LogSanitizer.swift (separate target)
│   ├── SharedLogManager.swift           # Copy of Shared/SharedLogManager.swift (separate target)
│   ├── Components/
│   │   └── (keyboard UI components)
│   ├── Info.plist                       # RequestsOpenAccess = YES
│   └── PrivacyInfo.xcprivacy            # App Store Prep - Privacy manifest
│
├── SwiftSpeakTests/                     # Unit Tests
│   ├── Models/
│   │   ├── AIProviderTests.swift
│   │   ├── FormattingModeTests.swift
│   │   ├── LanguageTests.swift
│   │   └── ProcessingMetadataTests.swift
│   ├── Services/
│   │   ├── RetryPolicyTests.swift              # Phase 11 - Retry logic tests
│   │   ├── PromptSanitizerTests.swift          # Phase 11 - Injection protection tests
│   │   ├── TokenCounterTests.swift             # Phase 11 - Token counting tests
│   │   ├── ProviderHealthTrackerTests.swift    # Phase 11 - Circuit breaker tests
│   │   ├── WebhookCircuitBreakerTests.swift    # Phase 11 - Webhook timeout tests
│   │   ├── MemoryUpdateCoordinatorTests.swift  # Phase 11 - Serialization tests
│   │   ├── LocalTranslationManagerTests.swift  # Phase 10 - iOS 18+ translation tests
│   │   └── (other service tests)
│   └── Integration/                            # Phase 11 - Integration tests
│       ├── ConcurrencyTests.swift
│       ├── ErrorRecoveryTests.swift
│       ├── TranscriptionFlowIntegrationTests.swift
│       └── PowerModeFlowIntegrationTests.swift
│
└── SwiftSpeakUITests/                   # UI Tests
    └── (test files)
```

## Provider Protocols (Implemented)

```swift
protocol TranscriptionProvider {
    var providerId: AIProvider { get }
    var isConfigured: Bool { get }
    var model: String { get }
    func transcribe(audioURL: URL, language: Language?) async throws -> String
    func validateAPIKey(_ key: String) async -> Bool
}

protocol FormattingProvider {
    var providerId: AIProvider { get }
    var isConfigured: Bool { get }
    var model: String { get }
    func format(text: String, mode: FormattingMode, customPrompt: String?) async throws -> String
}

protocol TranslationProvider {
    var providerId: AIProvider { get }
    var isConfigured: Bool { get }
    var model: String { get }
    func translate(text: String, from: Language?, to: Language) async throws -> String
}
```

## TranscriptionOrchestrator State Machine

```
idle → recording → processing → formatting → complete
                 ↘ error (at any step)
```

The orchestrator:
1. Manages audio recording via AudioRecorder
2. Sends audio to transcription provider (OpenAI Whisper)
3. Applies formatting via FormattingProvider (if mode != .raw)
4. Applies vocabulary replacements from settings
5. Saves to history
6. Copies to clipboard
7. Updates `lastTranscription` for keyboard access

## Audio Recording Configuration

Audio format optimized for Whisper API:
```swift
let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 16000,          // 16kHz for Whisper
    AVNumberOfChannelsKey: 1,         // Mono
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

## Business Model (BYOK - Bring Your Own Key)

**Value Proposition:** Users pay for app features (subscription) + their own API costs.
This is **40-70% cheaper** than hosted competitors like Wispr Flow ($12-15/mo) or Otter.ai ($8-30/mo).

### Free Tier - $0
- Basic transcription only
- 1 provider (OpenAI Whisper)
- 3 predefined templates (Email, Formal, Casual)
- Limited transcriptions/day

### Pro Tier - $6.99/month, $59.99/year, $99 lifetime
- Unlimited transcriptions
- Multiple providers (OpenAI, Anthropic, ElevenLabs, Deepgram)
- Translation feature
- Unlimited custom templates
- Local LLM support (Ollama)

### Power Tier - $12.99/month, $99.99/year, $199 lifetime
- Everything in Pro
- Power Modes - Voice-activated AI agents with tools
- AI can ask clarifying questions
- Web search, code execution capabilities
- Full-screen workspace with version history

## Key UI Components

### Recording Card States
1. **Recording** - Live waveform, "Transcribing..."
2. **Processing** - Spinner, "Processing transcription..."
3. **Formatting** - Spinner, "Applying [mode] mode..."
4. **Complete** - Checkmark, result preview
5. **Error** - Error icon, message, tap to retry

### Waveform Animation
```swift
ForEach(0..<12) { i in
    RoundedRectangle(cornerRadius: 3)
        .fill(AppTheme.accentGradient)
        .frame(width: 4, height: heights[i])
        .animation(AppTheme.smoothSpring, value: heights[i])
}
```

## Design Guidelines

- **Dark mode by default** - easier on eyes, feels premium
- **Spring animations** - organic, Apple-like feel (use AppTheme.smoothSpring)
- **Haptic feedback** - use HapticManager for consistent haptics
- **Blur backgrounds** - `.ultraThinMaterial` for cards
- **Accent color** - Use AppTheme.accent and AppTheme.accentGradient

## App Groups Data Sharing

```swift
// Shared UserDefaults
let sharedDefaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")

// Save from main app
sharedDefaults?.set(transcribedText, forKey: "lastTranscription")

// Read from keyboard
let text = sharedDefaults?.string(forKey: "lastTranscription")
```

## Unified Logging System

Both the main app and keyboard extension write to a shared log file via App Groups for unified debugging.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  SharedLogManager (actor, thread-safe)                  │
│  └── Writes to: App Groups/swiftspeak_logs.jsonl        │
└─────────────────────────────────────────────────────────┘
         ↑                              ↑
    appLog(...)                   keyboardLog(...)
         ↑                              ↑
┌────────────────┐            ┌────────────────┐
│   Main App     │            │   Keyboard     │
│   - Recording  │            │   - Actions    │
│   - Formatting │            │   - Lifecycle  │
│   - Navigation │            │   - Auto-insert│
└────────────────┘            └────────────────┘
```

### Key Components

| File | Purpose |
|------|---------|
| `LogSanitizer.swift` | Removes API keys, user content, PII from logs |
| `SharedLogManager.swift` | Actor-based file logging to App Groups |
| `LogExporter.swift` | Exports logs with device info header |
| `DiagnosticsView.swift` | UI for viewing/exporting logs |
| `Logging.swift` | os.log Logger extensions (categories) |

### Privacy-Safe Logging

**NEVER log (sanitized out):**
- API keys → `"sk-***"` or `"configured"`
- Transcription text → `"[text: 42 chars]"`
- User dictation → `"[audio: 30.2s]"`
- Custom prompts → `"[custom template]"`
- Error messages with user content → truncated

**SAFE to log:**
- Timestamps, action types, provider names
- Mode names, duration/counts, success/failure
- Language codes, error codes (not full messages)

### Usage

```swift
// From main app
appLog("Recording started (mode: email)", category: "Transcription")
appLog("API error: \(LogSanitizer.sanitizeError(error))", category: "API", level: .error)

// From keyboard extension
keyboardLog("Transcription requested", category: "Action")
keyboardLog("Keyboard appeared", category: "Lifecycle")
```

### Log Categories

- `Transcription` - Recording, transcription, formatting, translation
- `Navigation` - URL scheme handling, view transitions
- `Subscription` - RevenueCat configuration, tier changes
- `Audio` - Audio session management
- `RAG` - Document processing, vector search
- `Lifecycle` - Keyboard load/appear
- `Action` - User actions in keyboard

## Performance Targets

- App launch: <200ms (critical for UX)
- Pre-warm audio session at app startup (in SwiftSpeakApp.init())
- Start recording before UI renders
- Keep app in memory with background modes

## API Costs Reference

| Feature | API | Cost |
|---------|-----|------|
| Transcription | Whisper | $0.006/min |
| Translation | GPT-4o-mini | ~$0.0001/request |
| Formatting | GPT-4o-mini | ~$0.0001/request |

Typical 30-second dictation: ~$0.0032

## Quick Reference Commands

```bash
# Open project in Xcode
open ~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeak.xcodeproj

# Build for simulator (use available simulator)
xcodebuild -project SwiftSpeak.xcodeproj -scheme SwiftSpeak -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild test -project SwiftSpeak.xcodeproj -scheme SwiftSpeak -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Session Start Checklist

1. Read this CLAUDE.md for context
2. Check remaining work in the table above (Phase 7 polish, App Store prep)
3. Use Context7 for Swift/SwiftUI documentation if needed
4. Run build to verify current state before making changes

## App Auto-Enable Feature

Automatically activates contexts or power modes based on which app the keyboard is being used in.

**Architecture:**
- iOS keyboard extensions cannot detect the host app via public APIs (Apple blocks this for privacy)
- Solution: Pre-built database of 100+ popular apps organized by category
- Users can reassign apps to different categories (e.g., move Notion from Work to Personal)
- Contexts and PowerModes have `appAssignment` property specifying which apps/categories auto-enable them

**Key Files:**
- `AppLibrary.swift` - Database of apps with AppCategory, AppInfo, AppAssignment models
- `AppLibraryView.swift` - Browse apps, search, reassign categories
- `AppAssignmentSection.swift` - Reusable UI component for Context/PowerMode editors
- `SharedSettings.swift` - Methods for `contextForApp(bundleId:)` and `powerModeForApp(bundleId:)`

**How It Works:**
```swift
// In keyboard extension, get host bundle ID (via private API or input traits)
let bundleId = "com.google.Gmail"

// Find matching context or power mode
if let context = settings.contextForApp(bundleId: bundleId) {
    settings.setActiveContext(context)
}
if let powerMode = settings.powerModeForApp(bundleId: bundleId) {
    // Auto-enable this power mode
}
```

**Note:** Getting the host bundle ID requires either private API (risky for App Store) or inferring from input traits (limited but safe).

## Error Types

`TranscriptionError` enum covers:
- Microphone/audio errors (permission denied, recording failed)
- Network errors (connectivity, timeout, server errors)
- API errors (invalid key, rate limiting, quota exceeded)
- File errors (audio file not found, too large)
- Provider errors (not configured, empty response)

Each error includes:
- User-friendly `errorDescription`
- `isUserRecoverable` flag
- `shouldRetry` flag
- `iconName` for UI display

## Testing Strategy

- **Unit Tests:** Swift Testing framework (@Test attribute, #expect macro)
- **Mock Providers:** MockTranscriptionProvider, MockFormattingProvider with configurable delays and failures
- **UI Tests:** XCTest framework for recording flow and settings

**IMPORTANT:** Do NOT run tests in parallel or in background. Run tests sequentially to avoid laptop performance issues.

## Critical: AI Prompts Discussion Required

**IMPORTANT:** Before implementing or modifying any AI prompts (system prompts, user prompts, formatting instructions), you MUST discuss with the user first. This includes:

- Transcription prompts sent to Whisper/STT providers
- Formatting prompts sent to LLMs (GPT-4, Claude, etc.)
- Translation prompts
- Context instructions that get injected into prompts
- Power Mode agent prompts
- Any prompt engineering decisions

The exact wording of prompts significantly impacts output quality and user experience. Always present proposed prompts to the user for review before implementing.
