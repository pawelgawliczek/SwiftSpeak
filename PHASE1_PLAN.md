# SwiftSpeak Phase 1: Core Transcription + Testing Infrastructure

> **This is the execution guide for Phase 1.** Follow this document step-by-step.
> Master project documentation: `/Users/pawelgawliczek/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`

## Overview

Transition from UI prototype (Phase 0) to functional voice transcription with real API integration and testing infrastructure.

**Scope:**
- Testing infrastructure setup (unit + UI tests)
- Provider abstraction layer (protocols)
- Audio recording (AVAudioRecorder)
- OpenAI Whisper integration
- GPT-4 formatting (email, formal, casual templates)
- App Groups communication enhancement

**Pre-requisites Verified:**
- ✅ RequestsOpenAccess = true in keyboard Info.plist
- ✅ App Groups configured (group.pawelgawliczek.swiftspeak)
- ✅ URL scheme ready (swiftspeak://)
- ✅ Existing models ready (AIProvider, AIProviderConfig, FormattingMode, etc.)

---

## New File Structure

```
SwiftSpeak/SwiftSpeak/
├── Services/                              # NEW DIRECTORY
│   ├── Protocols/
│   │   ├── TranscriptionProvider.swift    # STT provider protocol
│   │   ├── FormattingProvider.swift       # Text formatting protocol
│   │   └── TranslationProvider.swift      # Translation protocol (Phase 2 ready)
│   ├── Audio/
│   │   ├── AudioSessionManager.swift      # AVAudioSession configuration
│   │   └── AudioRecorder.swift            # AVAudioRecorder wrapper
│   ├── Providers/
│   │   ├── OpenAI/
│   │   │   ├── OpenAITranscriptionService.swift
│   │   │   └── OpenAIFormattingService.swift
│   │   └── Mock/
│   │       ├── MockTranscriptionProvider.swift
│   │       └── MockFormattingProvider.swift
│   ├── Orchestration/
│   │   └── TranscriptionOrchestrator.swift  # Coordinates full flow
│   ├── Network/
│   │   └── APIClient.swift                  # Reusable HTTP client
│   └── TranscriptionError.swift             # Error types
│
├── SwiftSpeakTests/                       # NEW TEST TARGET
│   ├── Models/
│   │   ├── AIProviderTests.swift
│   │   ├── FormattingModeTests.swift
│   │   └── TranscriptionRecordTests.swift
│   ├── Services/
│   │   ├── AudioRecorderTests.swift
│   │   ├── OpenAITranscriptionServiceTests.swift
│   │   └── TranscriptionOrchestratorTests.swift
│   ├── Settings/
│   │   └── SharedSettingsTests.swift
│   └── Mocks/
│       └── TestMocks.swift
│
└── SwiftSpeakUITests/                     # NEW TEST TARGET
    ├── RecordingFlowUITests.swift
    └── SettingsUITests.swift
```

---

## Implementation Steps

### Step 1: Create Test Targets in Xcode
**Priority: First** (enables TDD approach)

1. Open `SwiftSpeak.xcodeproj`
2. File → New → Target → Unit Testing Bundle → "SwiftSpeakTests"
3. File → New → Target → UI Testing Bundle → "SwiftSpeakUITests"
4. Configure test target to access Shared files (target membership)
5. Add initial test file structure

### Step 2: Create Services Directory & Protocols
**Dependencies: None**

Create protocol files defining the abstraction layer:

```swift
// TranscriptionProvider.swift
protocol TranscriptionProvider {
    var providerId: AIProvider { get }
    var isConfigured: Bool { get }
    func transcribe(audioURL: URL, language: Language?) async throws -> String
    func validateAPIKey(_ key: String) async -> Bool
}

// FormattingProvider.swift
protocol FormattingProvider {
    var providerId: AIProvider { get }
    func format(text: String, mode: FormattingMode, customPrompt: String?) async throws -> String
}
```

### Step 3: Implement Audio Recording
**Dependencies: Step 2**

Files to create:
- `AudioSessionManager.swift` - Configure AVAudioSession, request permissions
- `AudioRecorder.swift` - Record to m4a (16kHz, mono, AAC for Whisper)

Key features:
- Pre-warm audio session at app launch (<200ms startup)
- Publish audio levels for waveform visualization
- Handle interruptions (calls, notifications)

Audio format settings:
```swift
let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 16000,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

### Step 4: Implement Network Layer
**Dependencies: Step 2**

Create `APIClient.swift`:
- Generic HTTP client with async/await
- Multipart form upload for audio files
- JSON POST for chat completions
- Error handling with retry logic

### Step 5: Implement OpenAI Services
**Dependencies: Steps 2, 4**

`OpenAITranscriptionService.swift`:
- Endpoint: `https://api.openai.com/v1/audio/transcriptions`
- Model: `whisper-1`
- Multipart upload with audio file
- Handle rate limits and errors

`OpenAIFormattingService.swift`:
- Endpoint: `https://api.openai.com/v1/chat/completions`
- Model: `gpt-4o-mini` (cost-effective)
- Use prompts from `FormattingMode.prompt`

### Step 6: Implement TranscriptionOrchestrator
**Dependencies: Steps 3, 5**

Central coordinator managing the flow:
```
idle → recording → processing → formatting → complete
                 ↘ error (at any step)
```

Responsibilities:
- Get provider config from `SharedSettings`
- Instantiate appropriate providers
- Manage state transitions (published for SwiftUI)
- Apply vocabulary replacements
- Save to history
- Update `lastTranscription` for keyboard

### Step 7: Update RecordingView
**Dependencies: Step 6**

Modify `/SwiftSpeak/SwiftSpeak/Views/RecordingView.swift`:
- Replace mock `simulateTranscription()` with real orchestrator
- Connect waveform to real audio levels
- Handle errors with retry button
- Add proper loading states

### Step 8: Implement Mock Providers
**Dependencies: Step 2**

For testing without API calls:
- `MockTranscriptionProvider` - configurable delays, results, failures
- `MockFormattingProvider` - same pattern

### Step 9: Write Unit Tests
**Dependencies: Steps 1-8**

Priority test files:
1. `AIProviderTests.swift` - capability flags, model lists
2. `SharedSettingsTests.swift` - persistence, history management
3. `TranscriptionOrchestratorTests.swift` - state machine, flow
4. `OpenAITranscriptionServiceTests.swift` - request/response handling

### Step 10: Write UI Tests
**Dependencies: Step 9**

- `RecordingFlowUITests.swift` - tap record, verify states
- `SettingsUITests.swift` - provider configuration flow

---

## Critical Files to Modify

| File | Changes |
|------|---------|
| `/SwiftSpeak/SwiftSpeak/Views/RecordingView.swift` | Replace mock with real orchestrator |
| `/SwiftSpeak/SwiftSpeak/SwiftSpeakApp.swift` | Pre-warm audio session on launch |
| `/SwiftSpeak/SwiftSpeak/SharedSettings.swift` | Add orchestrator integration methods |
| `/SwiftSpeak/SwiftSpeak/Shared/Constants.swift` | Add timeout values, file limits |

---

## Error Handling

Create `TranscriptionError.swift`:
```swift
enum TranscriptionError: LocalizedError {
    case microphonePermissionDenied
    case recordingFailed(Error)
    case networkError
    case apiKeyInvalid
    case apiKeyMissing
    case rateLimited(retryAfter: TimeInterval)
    case fileTooLarge(sizeMB: Double)  // Whisper max: 25MB
    case providerNotConfigured
}
```

---

## Testing Strategy

### Unit Tests (SwiftSpeakTests)
- **Models:** Verify enum cases, computed properties, Codable
- **Services:** Test with mock HTTP responses (URLProtocol)
- **Orchestrator:** State transitions, error handling
- **Settings:** App Groups persistence, vocabulary

### UI Tests (SwiftSpeakUITests)
- Recording flow: tap button → card appears → states transition
- Settings: add/edit provider configuration
- Mode selection persistence

### Test Coverage Goals
- Models: 100%
- Services: 80%+
- Views: State logic only (30-50%)

---

## Dependencies Graph

```
Step 1 (Test Targets) ─────────────────────────────→ Step 9, 10
Step 2 (Protocols) ──┬──→ Step 3 (Audio) ──┐
                     ├──→ Step 4 (Network) ─┼──→ Step 5 (OpenAI) ──→ Step 6 (Orchestrator) ──→ Step 7 (RecordingView)
                     └──→ Step 8 (Mocks) ───┘
```

---

## Verification Checklist

After implementation, verify:
- [ ] Can record audio and see waveform
- [ ] Transcription returns real text from Whisper API
- [ ] Formatting modes (email, formal, casual) apply correctly
- [ ] Raw mode bypasses formatting
- [ ] Result saved to history
- [ ] `lastTranscription` accessible from keyboard
- [ ] Error states display user-friendly messages
- [ ] All unit tests pass
- [ ] UI tests pass

---

## Notes

- **RequestsOpenAccess** is already `true` in keyboard Info.plist
- Existing `AIProvider`, `AIProviderConfig`, `FormattingMode` models are ready to use
- Focus on OpenAI only for Phase 1; other providers in Phase 3
- Auto-return uses clipboard (iOS limitation - can't programmatically switch apps)

---

## After Phase 1 Completion

Update `/Users/pawelgawliczek/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`:
1. Mark Phase 1 items as complete
2. Add "Testing Infrastructure" section to Phase 1
3. Add test targets to Project Structure section
4. Update "NOT YET IMPLEMENTED" section
