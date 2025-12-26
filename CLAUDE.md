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

### What's Done
- [x] Xcode project created (SwiftUI, Swift, iOS 17+)
- [x] Keyboard extension target added: `SwiftSpeakKeyboard`
- [x] App Groups capability configured in both targets
- [x] Basic `KeyboardViewController.swift` with globe button
- [x] Implementation plan document complete

### What's NOT Done
- [ ] `RequestsOpenAccess` is `false` in Info.plist (needs to be `true` for network access)
- [ ] All UI screens (Phase 0 is UI-first with mock data)
- [ ] Recording functionality
- [ ] API integrations
- [ ] Onboarding flow

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

### Phase 0: UI/UX Prototype (CURRENT)
**Goal:** Build all screens with mock data, full navigation, polished animations.
No real API calls - just simulated responses.

**Deliverables:**
1. Onboarding flow (6 screens with animations)
2. Keyboard UI - buttons, dropdowns, all states
3. Recording card - waveform animation, state transitions
4. Settings screens - providers, API keys, templates
5. Paywall screens - Free/Pro/Power tiers
6. History view - past transcriptions list

### Phase 1: Core Transcription
- Provider abstraction layer
- OpenAI Whisper integration (real API calls)
- Audio recording with AVAudioRecorder
- App Groups communication
- URL scheme handling
- Auto-return and clipboard insertion

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

## Target File Structure

```
SwiftSpeak/
├── SwiftSpeak.xcodeproj
├── SwiftSpeak/                          # Containing App
│   ├── SwiftSpeakApp.swift              # @main entry
│   ├── ContentView.swift                # Main app navigation
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift     # TabView container
│   │   │   ├── WelcomeScreen.swift      # Logo + tagline
│   │   │   ├── HowItWorksScreen.swift   # 3-step carousel
│   │   │   ├── EnableKeyboardScreen.swift
│   │   │   ├── FullAccessScreen.swift
│   │   │   ├── APIKeyScreen.swift
│   │   │   └── AllSetScreen.swift       # Confetti celebration
│   │   ├── RecordingView.swift          # Recording UI with waveform
│   │   ├── SettingsView.swift           # API keys, preferences
│   │   ├── TemplatesView.swift          # Manage formatting templates
│   │   ├── HistoryView.swift            # Past transcriptions
│   │   └── PaywallView.swift            # Pro subscription prompt
│   ├── Models/
│   │   ├── AudioRecorder.swift          # AVAudioRecorder wrapper
│   │   ├── TranscriptionService.swift   # OpenAI Whisper API
│   │   ├── TranslationService.swift     # GPT-4 translation
│   │   ├── FormattingService.swift      # GPT-4 template formatting
│   │   ├── SettingsManager.swift        # UserDefaults + App Groups
│   │   └── SubscriptionManager.swift    # StoreKit 2 purchases
│   ├── Components/
│   │   ├── WaveformView.swift           # Audio visualization
│   │   └── RecordingCard.swift          # Compact center card
│   └── Resources/
│       └── Localizable.strings
├── SwiftSpeakKeyboard/                  # Keyboard Extension
│   ├── KeyboardViewController.swift     # UIInputViewController
│   ├── KeyboardView.swift               # SwiftUI keyboard UI
│   ├── Components/
│   │   ├── TranscribeButton.swift
│   │   ├── TranslateButton.swift
│   │   ├── ModeDropdown.swift
│   │   └── LanguageDropdown.swift
│   └── Info.plist                       # RequestsOpenAccess = YES
└── Shared/
    ├── SharedSettings.swift             # App Groups data
    ├── Template.swift                   # Formatting template model
    └── Constants.swift                  # API endpoints, keys
```

## Business Model (For Paywall UI)

### Free Tier - $0
- Basic transcription only
- 1 provider (OpenAI Whisper)
- 3 predefined templates (Email, Formal, Casual)
- Limited transcriptions/day

### Pro Tier - $9.99/month
- Unlimited transcriptions
- Multiple providers (OpenAI, Anthropic, ElevenLabs, Deepgram)
- Translation feature
- Unlimited custom templates
- Local LLM support (Ollama)

### Power Tier - $19.99/month
- Everything in Pro
- Power Modes - Voice-activated AI agents with tools
- AI can ask clarifying questions
- Web search tool
- Full-screen workspace with diff highlighting

## Key UI Components

### 1. Onboarding Flow
6 screens with animations:
1. **WelcomeScreen** - Animated logo, "Speak naturally. Type instantly."
2. **HowItWorksScreen** - 3-step carousel with auto-advance
3. **EnableKeyboardScreen** - Deep link to Settings, detect when enabled
4. **FullAccessScreen** - Permission explanation, detect toggle
5. **APIKeyScreen** - Enter OpenAI key, validate
6. **AllSetScreen** - Confetti celebration

### 2. Keyboard UI
```
┌─────────────────────────────────────────┐
│  [🎤 Transcribe]    [🌍 Translate]      │
│  ┌───────────────────────────────────┐  │
│  │ Mode: Email ▼                     │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ Target: Spanish ▼                 │  │
│  └───────────────────────────────────┘  │
│  [🌐 Globe]                             │
└─────────────────────────────────────────┘
```

### 3. Recording Card (Compact Center)
```
┌─────────────────────────┐
│     ~~~~∿∿∿~~~~         │
│   (waveform animation)   │
│   "Listening..."        │
│   [Tap to finish]       │
└─────────────────────────┘
```

**States:**
1. Listening - Live waveform, "Listening..."
2. Processing - Spinner, "Transcribing..."
3. Formatting - Spinner, "Formatting..."

### 4. Waveform Animation
```swift
ForEach(0..<12) { i in
    RoundedRectangle(cornerRadius: 3)
        .fill(LinearGradient(colors: [.blue, .purple]))
        .frame(width: 4, height: heights[i])
        .animation(.spring(dampingFraction: 0.5), value: heights[i])
}
```

## Design Guidelines

- **Dark mode by default** - easier on eyes, feels premium
- **Spring animations** - organic, Apple-like feel
- **Haptic feedback** - light tap on record, success on complete
- **Blur backgrounds** - `.ultraThinMaterial` for cards
- **Accent color** - Blue or customizable

## Keyboard Detection

```swift
// Check if SwiftSpeak keyboard is enabled
func isKeyboardEnabled() -> Bool {
    let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String] ?? []
    return keyboards.contains { $0.contains("SwiftSpeakKeyboard") }
}

// Deep link to keyboard settings
func openKeyboardSettings() {
    if let url = URL(string: "App-prefs:General&path=Keyboard/KEYBOARDS") {
        UIApplication.shared.open(url)
    }
}
```

## Info.plist Changes Needed

In `SwiftSpeakKeyboard/Info.plist`, change:
```xml
<key>RequestsOpenAccess</key>
<true/>  <!-- Currently false, needs to be true -->
```

## Predefined Templates

**Email Template:**
```
Format this dictated text as a professional email.
Add appropriate greeting and sign-off.
Fix grammar and punctuation. Keep the original meaning.
```

**Formal Template:**
```
Rewrite this text in a formal, professional tone.
Use proper business language. Fix any grammatical errors.
```

**Casual Template:**
```
Clean up this text while keeping a casual, friendly tone.
Fix grammar but maintain conversational style.
```

## Provider Abstraction

```swift
protocol TranscriptionProvider {
    var id: String { get }
    var name: String { get }
    var requiresAPIKey: Bool { get }
    var costPerMinute: Double { get }

    func transcribe(audioURL: URL) async throws -> String
    func validateAPIKey(_ key: String) async -> Bool
}

protocol TranslationProvider {
    var id: String { get }
    var name: String { get }
    var supportedLanguages: [Language] { get }

    func translate(text: String, from: Language, to: Language) async throws -> String
}
```

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
- Pre-warm audio session at app startup
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

# Build for simulator
xcodebuild -project SwiftSpeak.xcodeproj -scheme SwiftSpeak -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Session Start Checklist

1. Read this CLAUDE.md for context
2. Check current phase (Phase 0 = UI prototype)
3. Use Context7 for Swift/SwiftUI documentation if needed
4. Focus on mock data - no real API calls in Phase 0
