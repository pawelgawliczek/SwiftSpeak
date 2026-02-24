# CLAUDE.md - SwiftSpeak Voice Keyboard

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**SwiftSpeak** is an iOS custom keyboard + macOS menu bar app for voice transcription, translation, and AI formatting. Users speak and text is inserted anywhere.

**Value Proposition:** Voice-to-text with AI formatting modes - like having a professional writer format your dictation in real-time.

## Project Location

```
~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeak.xcodeproj
```

**Important Paths:**
- Main iOS App: `SwiftSpeak/SwiftSpeak/`
- Keyboard Extension: `SwiftSpeak/SwiftSpeakKeyboard/`
- macOS App: `SwiftSpeak/SwiftSpeakMac/`
- Shared Package: `SwiftSpeak/SwiftSpeakCore/`
- Documentation: `SwiftSpeak/docs/`

## Bundle IDs & Configuration

| Component | Bundle ID |
|-----------|-----------|
| iOS App | `pawelgawliczek.SwiftSpeak` |
| Keyboard Extension | `pawelgawliczek.SwiftSpeak.SwiftSpeakKeyboard` |
| macOS App | `pawelgawliczek.SwiftSpeakMac` |
| App Group | `group.pawelgawliczek.swiftspeak` |

**Technical Requirements:**
- iOS 17.0+ / macOS 13.5+
- iOS 18.0+ for Apple Translation (gracefully disabled on older versions)
- Xcode 15+ for development
- SwiftUI for all UI components

---

## Project Status

### Completed Phases

| Phase | Name | Description |
|-------|------|-------------|
| 0 | UI/UX Prototype | All screens with mock data, navigation, animations |
| 1 | Core Transcription | Provider protocols, audio recording, OpenAI services |
| 2 | Templates & Translation | Translation, auto-return, custom templates |
| 3 | Multi-Provider Support | 10 providers: OpenAI, Anthropic, Gemini, AssemblyAI, Deepgram, Google, DeepL, Azure, Parakeet MLX |
| 3A | Provider Help | ProviderHelpSheet, LanguageSupportView, SmartLanguagePicker |
| 4 | Power Mode Backend | Contexts, 3-tier memory, RAG, webhooks, LLM streaming |
| 6 | Security | Keychain, biometrics, data retention |
| 7 | Subscription | RevenueCat integration, feature gating |
| 9 | Remote Config | Firebase, cost tracking, analytics |
| 10 | Privacy Mode | Local providers (WhisperKit, Apple Intelligence, Parakeet MLX) |
| 11 | Orchestration | Security hardening, retry policies, circuit breakers |
| 12 | SwiftLink | Background dictation, Edit Mode |

### In Progress

| Phase | Name | Status | Details |
|-------|------|--------|---------|
| macOS | Menu Bar Port | 85% complete (16 views, 5 services) | [docs/MACOS_PORT.md](SwiftSpeak/docs/MACOS_PORT.md) |
| 13 | Keyboard Redesign | Full QWERTY + voice modes | `PHASE13_KEYBOARD_REDESIGN.md` |
| 14 | Multi-lang Spelling | SymSpell for 13 languages | `PHASE14_MULTILANG_SPELLING.md` |
| 15 | Multi-lang Predictions | Language-aware word predictions | `PHASE15_MULTILANG_PREDICTIONS.md` |
| NEW | Obsidian Integration | Vault indexing, RAG queries | `OBSIDIAN_INTEGRATION_PLAN.md` |

### Remaining Work

| Task | Priority |
|------|----------|
| App Store Connect subscription config | Medium |
| RevenueCat production API key | High |
| macOS shared services (iCloud sync) | Medium |
| WebSocket real-time transcription (4g) | Low |

---

## Architecture

### iOS Keyboard Constraint

**CRITICAL:** iOS keyboard extensions **cannot access the microphone**. This requires a two-app architecture:

```
┌─────────────────────────────────────┐
│         Keyboard Extension          │
│  ┌──────────┐  ┌──────────┐        │
│  │ 🎤 Record │  │ 🌍 Translate│       │
│  └──────────┘  └──────────┘        │
└───────────────┬─────────────────────┘
                │ URL Scheme (swiftspeak://)
                ↓
┌─────────────────────────────────────┐
│          Containing App             │
│  - Records audio (AVAudioRecorder)  │
│  - Calls transcription API          │
│  - Applies AI formatting            │
│  - Returns text via App Groups      │
└───────────────┬─────────────────────┘
                ↓
        Auto-return to original app
```

**URL Scheme:** `swiftspeak://record?mode=email&translate=false&target=es`

### Key Subsystems

| Subsystem | Description | Details |
|-----------|-------------|---------|
| Orchestration | Transcription & Power Mode flows | [docs/ORCHESTRATION.md](SwiftSpeak/docs/ORCHESTRATION.md) |
| SwiftLink | Background dictation via Darwin notifications | [docs/SWIFTLINK.md](SwiftSpeak/docs/SWIFTLINK.md) |
| Memory System | 3-tier AI memory (Global/Context/PowerMode) | [docs/MEMORY_SYSTEM.md](SwiftSpeak/docs/MEMORY_SYSTEM.md) |
| Logging | Privacy-safe unified logging | [docs/LOGGING.md](SwiftSpeak/docs/LOGGING.md) |
| macOS Port | Menu bar app architecture | [docs/MACOS_PORT.md](SwiftSpeak/docs/MACOS_PORT.md) |

### Directory Structure

```
SwiftSpeak/
├── SwiftSpeakCore/           # Shared Swift Package (models, protocols)
├── SwiftSpeak/               # iOS App
│   ├── Services/             # Providers, orchestration, networking
│   ├── Views/                # SwiftUI views
│   └── Shared/               # Constants, Theme, Models
├── SwiftSpeakKeyboard/       # iOS Keyboard Extension
├── SwiftSpeakMac/            # macOS Menu Bar App
├── SwiftSpeakTests/          # Unit Tests
└── docs/                     # Subsystem documentation
```

Full file tree: [docs/FILE_STRUCTURE.md](SwiftSpeak/docs/FILE_STRUCTURE.md)

---

## Business Model (BYOK)

Users pay for app features + their own API costs. 40-70% cheaper than hosted competitors.

| Tier | Features |
|------|----------|
| **Free** | Basic transcription, 1 provider, 3 templates |
| **Pro** | Unlimited, multi-provider, translation, custom templates |
| **Power** | Power Modes, AI agents, RAG, web search |

---

## Development Guidelines

### iOS/macOS UI Consistency (Critical)

**macOS views MUST mimic iOS views.** Maintain identical user flow and feel across both platforms:
- Same navigation structure and settings organization
- Same feature availability (unless platform-specific like hotkeys)
- Same section names, icons, and terminology
- Same data models and bindings
- When adding a feature to iOS, add equivalent to macOS (and vice versa)

Only diverge for platform-specific features:
- macOS: Global hotkeys, menu bar, window context capture
- iOS: Keyboard extension, SwiftLink background mode

### CLAUDE.md Maintenance (Critical)

**After completing each development phase or significant session, update this file with:**
1. New completed phases → move to Completed table
2. New in-progress work → add to In Progress table
3. New architectural decisions or constraints discovered
4. New legacy files created or removed
5. Remove stale/obsolete information

**Target length: 200-300 lines.** If exceeding 400 lines, move details to `docs/` files.

### Logging Policy

**ALWAYS use `appLog()` or `keyboardLog()`.** Never use `print()`, `os.log`, or `NSLog()`.

```swift
appLog("Recording started", category: "Transcription")
keyboardLog("Action triggered", category: "Action")
```

Details: [docs/LOGGING.md](SwiftSpeak/docs/LOGGING.md)

### AI Prompts Policy

**IMPORTANT:** Before implementing or modifying any AI prompts, you MUST discuss with the user first. This includes:
- Transcription prompts (Whisper/STT)
- Formatting prompts (LLMs)
- Translation prompts
- Context/Power Mode agent prompts

The exact wording significantly impacts output quality.

### Legacy Code Policy

When encountering duplicate or legacy code:
1. **Remove duplicate code immediately**
2. **Mark legacy files clearly** with header comment
3. **Prefer deletion** - if truly unused, delete entirely

**Legacy File Header:**
```swift
// LEGACY: Deprecated, kept for reference only
// Replaced by: [NewFile.swift] on [YYYY-MM-DD]
// DO NOT USE - Will be removed in future cleanup
```

**Current Legacy Files:**
- `MemoryUpdateCoordinator.swift` → Replaced by `MemoryUpdateScheduler.swift`

### Testing Strategy

- **Unit Tests:** Swift Testing framework (@Test, #expect)
- **Mock Providers:** MockTranscriptionProvider, MockFormattingProvider
- **IMPORTANT:** Run tests sequentially (not parallel/background)

---

## Quick Reference

```bash
# Open project
open ~/projects/SwiftSpeak/SwiftSpeak/SwiftSpeak.xcodeproj

# Build iOS
xcodebuild -project SwiftSpeak.xcodeproj -scheme SwiftSpeak \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild test -project SwiftSpeak.xcodeproj -scheme SwiftSpeak \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| `IMPLEMENTATION_PLAN.md` | Master implementation plan |
| `OBSIDIAN_INTEGRATION_PLAN.md` | Obsidian vault integration plan |
| `PHASE13-15_*.md` | Active phase plans (keyboard, spelling, predictions) |
| `archive/` | Historical phase plans |
| `SwiftSpeak/docs/` | Subsystem documentation (6 files) |
