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
- Phase Plans: `~/projects/SwiftSpeak/PHASE1_PLAN.md`, `PHASE2_PLAN.md`, `PHASE3_PLAN.md`, `PHASE3A_PLAN.md`

## Bundle IDs & Configuration

| Component | Bundle ID |
|-----------|-----------|
| Main App | `pawelgawliczek.SwiftSpeak` |
| Keyboard Extension | `pawelgawliczek.SwiftSpeak.SwiftSpeakKeyboard` |
| App Group | `group.pawelgawliczek.swiftspeak` |

**Technical Requirements:**
- iOS 17.0+ minimum deployment target
- Xcode 15+ for development
- SwiftUI for all UI components

## Current Project State

### Phase 0: UI/UX Prototype - COMPLETE
- [x] Onboarding flow (6 screens with animations)
- [x] Keyboard UI - buttons, dropdowns, all states
- [x] Recording card - waveform animation, state transitions
- [x] Settings screens - providers, API keys, templates
- [x] Paywall screens - Free/Pro/Power tiers
- [x] History view - past transcriptions list
- [x] Power Mode views

### Phase 1: Core Transcription - IN PROGRESS
- [x] Test targets created (SwiftSpeakTests, SwiftSpeakUITests)
- [x] Provider abstraction layer (TranscriptionProvider, FormattingProvider, TranslationProvider protocols)
- [x] Audio recording (AudioRecorder, AudioSessionManager)
- [x] Network layer (APIClient with async/await)
- [x] OpenAI services (OpenAITranscriptionService, OpenAIFormattingService)
- [x] TranscriptionOrchestrator (coordinates full recording → transcription → formatting flow)
- [x] Mock providers for testing
- [x] RecordingView integrated with real orchestrator
- [x] RequestsOpenAccess = true in keyboard Info.plist
- [ ] Unit tests
- [ ] UI tests

### Phase 3A: Provider Help & Language Guidance - UX MOCKUPS COMPLETE
- [x] ProviderLanguageSupport.swift - Language support data model + database
- [x] ProviderHelpContent.swift - Setup guide data model + content
- [x] ProviderHelpSheet.swift - Setup guide bottom sheet
- [x] ProviderStatusDashboard.swift - At-a-glance status card
- [x] ProviderComparisonView.swift - Provider selection guide
- [x] LanguageSupportView.swift - Language compatibility matrix
- [x] SmartLanguagePicker.swift - Enhanced language dropdown
- [x] IncompatibilityWarning.swift - Warning banners
- [ ] Integration with SettingsView (pending)
- [ ] Integration with KeyboardView (pending)

### What's NOT Done Yet
- [ ] Translation feature integration (Phase 2)
- [ ] Multi-provider support services (Anthropic, ElevenLabs, Deepgram, Ollama) - Phase 3
- [ ] Power Mode voice agents - Phase 4
- [ ] StoreKit 2 subscriptions - Phase 5

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

## Implementation Phases

### Phase 0: UI/UX Prototype - COMPLETE
All screens built with mock data, full navigation, polished animations.

### Phase 1: Core Transcription - IN PROGRESS
- Testing infrastructure (Swift Testing framework)
- Provider abstraction layer
- OpenAI Whisper integration (real API calls)
- Audio recording with AVAudioRecorder
- App Groups communication
- URL scheme handling

### Phase 2: Templates & Translation
- Predefined templates (Email, Formal, Casual)
- GPT-4 formatting integration
- Translation feature
- Custom template editor

### Phase 3: Multi-Provider Support
- Anthropic Claude, ElevenLabs, Deepgram, Ollama

### Phase 4: Power Mode
- Full-screen AI workspace with tools
- Voice-activated AI agents

### Phase 5: Monetization & Polish
- StoreKit 2 subscriptions
- App Store submission

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
│   ├── Services/                        # NEW - Phase 1
│   │   ├── Protocols/
│   │   │   ├── TranscriptionProvider.swift
│   │   │   ├── FormattingProvider.swift
│   │   │   └── TranslationProvider.swift
│   │   ├── Audio/
│   │   │   ├── AudioSessionManager.swift
│   │   │   └── AudioRecorder.swift
│   │   ├── Providers/
│   │   │   ├── OpenAI/
│   │   │   │   ├── OpenAITranscriptionService.swift
│   │   │   │   └── OpenAIFormattingService.swift
│   │   │   └── Mock/
│   │   │       ├── MockTranscriptionProvider.swift
│   │   │       └── MockFormattingProvider.swift
│   │   ├── Orchestration/
│   │   │   └── TranscriptionOrchestrator.swift
│   │   ├── Network/
│   │   │   └── APIClient.swift
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
│   │   │   ├── ProviderHelpSheet.swift         # Phase 3A - Setup guide
│   │   │   ├── ProviderStatusDashboard.swift   # Phase 3A - Status card
│   │   │   ├── SmartLanguagePicker.swift       # Phase 3A - Language dropdown
│   │   │   └── IncompatibilityWarning.swift    # Phase 3A - Warning banners
│   │   ├── RecordingView.swift          # Uses real TranscriptionOrchestrator
│   │   ├── SettingsView.swift
│   │   ├── HistoryView.swift
│   │   ├── PaywallView.swift
│   │   ├── KeyboardPreviewView.swift
│   │   ├── ProviderComparisonView.swift        # Phase 3A - Provider selection
│   │   └── LanguageSupportView.swift           # Phase 3A - Language matrix
│   │
│   └── Shared/
│       ├── Constants.swift              # API endpoints, timeouts
│       ├── Models.swift                 # AIProvider, FormattingMode, Language, etc.
│       ├── Theme.swift                  # AppTheme, HapticManager
│       ├── ProviderLanguageSupport.swift       # Phase 3A - Language support data
│       └── ProviderHelpContent.swift           # Phase 3A - Setup guides
│
├── SwiftSpeakKeyboard/                  # Keyboard Extension
│   ├── KeyboardViewController.swift
│   ├── KeyboardView.swift
│   ├── Components/
│   │   └── (keyboard UI components)
│   └── Info.plist                       # RequestsOpenAccess = YES
│
├── SwiftSpeakTests/                     # Unit Tests
│   └── (test files)
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
2. Check current phase (Phase 1 = Core Transcription in progress)
3. Review PHASE1_PLAN.md for specific implementation steps
4. Use Context7 for Swift/SwiftUI documentation if needed
5. Run build to verify current state before making changes

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

## Critical: AI Prompts Discussion Required

**IMPORTANT:** Before implementing or modifying any AI prompts (system prompts, user prompts, formatting instructions), you MUST discuss with the user first. This includes:

- Transcription prompts sent to Whisper/STT providers
- Formatting prompts sent to LLMs (GPT-4, Claude, etc.)
- Translation prompts
- Context instructions that get injected into prompts
- Power Mode agent prompts
- Any prompt engineering decisions

The exact wording of prompts significantly impacts output quality and user experience. Always present proposed prompts to the user for review before implementing.
