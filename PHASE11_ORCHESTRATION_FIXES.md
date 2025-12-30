# Phase 11: Orchestration Security, Reliability & UX

## Overview

Phase 11 addresses critical security vulnerabilities, reliability issues, and implements the complete retry/audio queue system. This is the most important user-facing flow in the application.

**Total Sub-Phases:** 12 (11a-11k, excluding 11i which was deemed not a bug)

**Status:** IN PROGRESS

---

## Progress Tracker

| Sub-Phase | Description | Priority | Status |
|-----------|-------------|----------|--------|
| 11a | Prompt Injection Sanitization | CRITICAL | [ ] |
| 11b | Fix Formatting Provider Bug | CRITICAL | [ ] |
| 11c | Memory Update Serialization | CRITICAL | [ ] |
| 11d | Token Limit Checks | CRITICAL | [ ] |
| 11e | Provider Retry Logic + Audio Queue | HIGH | [ ] |
| 11f | Provider Fallback | HIGH | [ ] |
| 11g | Webhook Timeout Improvements | HIGH | [ ] |
| 11h | Partial Failure Recovery | HIGH | [x] Merged into 11e |
| ~~11i~~ | ~~Privacy Mode During Operation~~ | ~~MEDIUM~~ | [x] REMOVED - Not a bug |
| 11j | Audio Duration Validation | MEDIUM | [ ] |
| 11k | Documentation Updates | MEDIUM | [ ] |
| NEW | Keyboard UI (Banner, Auto-Insert) | HIGH | [ ] |
| NEW | Settings UI (Retry Section) | MEDIUM | [ ] |

---

## CRITICAL PRIORITY

### Phase 11a: Prompt Injection Sanitization

**Problem:** User-controlled data flows directly into LLM prompts with no sanitization.

**Attack Vectors:**
1. Vocabulary replacements → Whisper prompts
2. Context custom instructions → Power Mode prompts
3. Webhook response data → Prompt injection
4. RAG document content → Prompt hijacking

**Implementation:**

```swift
// Services/Security/PromptSanitizer.swift (NEW)
struct PromptSanitizer {
    /// Sanitize user input before injecting into prompts
    static func sanitize(_ text: String) -> String {
        var result = text
        result = escapeXML(result)
        result = removeInjectionPatterns(result)
        result = normalizeUnicode(result)
        return result
    }

    static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func detectInjection(_ text: String) -> Bool {
        let patterns = [
            "</context>", "</system>", "</user>",
            "IGNORE PREVIOUS", "IGNORE ALL", "OVERRIDE",
            "You are now", "Act as", "Pretend to be",
            "\\[INST\\]", "\\[/INST\\]"
        ]
        let lowercased = text.lowercased()
        return patterns.contains { lowercased.contains($0.lowercased()) }
    }

    static func truncate(_ text: String, maxTokens: Int) -> String {
        let maxChars = maxTokens * 4
        if text.count <= maxChars { return text }
        return String(text.prefix(maxChars)) + "..."
    }
}
```

**Apply at injection points:**
- `TranscriptionOrchestrator.swift` - Vocabulary hints
- `PowerModeOrchestrator.swift` - Context instructions, Webhook data, RAG chunks
- `PromptContext.swift` - All context building

**Files:**
- `Services/Security/PromptSanitizer.swift` (NEW)
- `Services/Orchestration/TranscriptionOrchestrator.swift`
- `Services/Orchestration/PowerModeOrchestrator.swift`
- `Services/Orchestration/PromptContext.swift`

---

### Phase 11b: Fix Formatting Provider Bug

**Problem:**
```swift
// TranscriptionOrchestrator.swift:330 - BUG!
formattingProvider = settings.selectedTranslationProvider  // WRONG!
```
Cost calculation uses wrong provider.

**Fix:**
```swift
formattingProvider = mode != .raw ? settings.selectedTranslationProvider : nil
```

**Files:**
- `Services/Orchestration/TranscriptionOrchestrator.swift`
- `SwiftSpeakTests/Services/TranscriptionOrchestratorTests.swift` (add regression test)

---

### Phase 11c: Memory Update Serialization

**Problem:** Multiple rapid transcriptions cause race condition in memory updates, losing data.

**Implementation:**
```swift
// Services/Memory/MemoryUpdateCoordinator.swift (NEW)
actor MemoryUpdateCoordinator {
    private let memoryManager: MemoryManager

    func updateMemory(text: String, type: MemoryType) async {
        await memoryManager.updateMemory(with: text, for: type)
    }
}
```

**Files:**
- `Services/Memory/MemoryUpdateCoordinator.swift` (NEW)
- `Services/Memory/MemoryManager.swift`
- `Services/Orchestration/TranscriptionOrchestrator.swift`
- `Services/Orchestration/PowerModeOrchestrator.swift`

---

### Phase 11d: Token Limit Checks

**Problem:** No token count validation before sending prompts to LLM.

**Implementation:**
```swift
// Services/Providers/TokenCounter.swift (NEW)
struct TokenCounter {
    static func estimate(_ text: String) -> Int {
        return (text.count + 3) / 4
    }

    static func limit(for model: String) -> Int {
        switch model {
        case _ where model.contains("gpt-4o"): return 128000
        case _ where model.contains("gpt-4"): return 8192
        case _ where model.contains("claude-3"): return 200000
        case _ where model.contains("gemini"): return 1000000
        default: return 4096
        }
    }
}

struct PromptLimits {
    static let globalMemory = 500
    static let contextMemory = 400
    static let powerModeMemory = 300
    static let ragChunks = 2000
    static let webhookContext = 1000
    static let userInput = 4000
    static let totalPrompt = 8000
}
```

**Files:**
- `Services/Providers/TokenCounter.swift` (NEW)
- `Services/Orchestration/PromptContext.swift`
- `Services/Orchestration/PowerModeOrchestrator.swift`

---

## HIGH PRIORITY

### Phase 11e: Provider Retry Logic + Audio Queue (MERGED with 11h)

**Problem:** Single network failure = complete workflow failure. Audio deleted on error.

**New Data Models (Models.swift):**
```swift
struct PendingAudio: Codable, Identifiable {
    let id: UUID
    let audioFileURL: URL
    let createdAt: Date
    let duration: TimeInterval
    let mode: FormattingMode
    let translateEnabled: Bool
    let targetLanguage: Language?
    let customTemplateId: UUID?
    var status: PendingAudioStatus
    var rawTranscription: String?
    var retryCount: Int
    var lastError: String?
    var lastAttemptAt: Date?
}

enum PendingAudioStatus: String, Codable {
    case pending, processing, partialSuccess, failed
}

struct ProcessingStatus: Codable {
    var isProcessing: Bool
    var currentStep: ProcessingStep
    var retryAttempt: Int
    var maxRetries: Int
    var errorMessage: String?
    var pendingAutoInsert: Bool
    var lastCompletedText: String?
}

enum ProcessingStep: String, Codable {
    case idle, recording, transcribing, formatting, translating, retrying, complete, failed
}
```

**New RecordingState case:**
```swift
case retrying(attempt: Int, maxAttempts: Int, reason: String)
```

**SharedSettings additions:**
```swift
@Published var autoRetryEnabled: Bool = true
@Published var maxRetryCount: Int = 3
@Published var keepFailedRecordings: Bool = true
@Published var pendingAudioRetentionDays: Int = 7
@Published var pendingAudioQueue: [PendingAudio] = []
var processingStatus: ProcessingStatus
```

**RetryPolicy:**
```swift
// Services/Network/RetryPolicy.swift
struct RetryPolicy {
    let maxAttempts: Int
    let initialDelay: TimeInterval = 1.0
    let backoffMultiplier: Double = 2.0
    let maxDelay: TimeInterval = 16.0

    func delay(for attempt: Int) -> TimeInterval {
        min(initialDelay * pow(backoffMultiplier, Double(attempt - 1)), maxDelay)
    }
}
```

**Files:**
- `Shared/Models.swift`
- `SharedSettings.swift`
- `Services/Network/RetryPolicy.swift` (NEW)
- `Services/Orchestration/TranscriptionOrchestrator.swift`
- `Services/Audio/AudioRecorder.swift`

---

### Phase 11f: Provider Fallback

**Problem:** If primary provider is down, no automatic failover.

**Implementation:**
```swift
// Services/Providers/ProviderHealthTracker.swift (NEW)
actor ProviderHealthTracker {
    private var failureCounts: [AIProvider: Int] = [:]
    private var lastFailure: [AIProvider: Date] = [:]
    private let failureThreshold = 3
    private let cooldownPeriod: TimeInterval = 300

    func recordFailure(for provider: AIProvider)
    func recordSuccess(for provider: AIProvider)
    func isHealthy(_ provider: AIProvider) -> Bool
}
```

**Files:**
- `Services/Providers/ProviderHealthTracker.swift` (NEW)
- `Services/ProviderFactory.swift`

---

### Phase 11g: Webhook Timeout Improvements

**Problem:** 5 webhooks × 30s timeout = 150 seconds blocking.

**Implementation:**
```swift
// Services/Webhooks/WebhookCircuitBreaker.swift (NEW)
actor WebhookCircuitBreaker {
    func shouldSkip(_ webhookId: UUID) -> Bool
    func recordFailure(_ webhookId: UUID)
    func recordSuccess(_ webhookId: UUID)
}
```

**Files:**
- `Services/Webhooks/WebhookCircuitBreaker.swift` (NEW)
- `Services/Webhooks/WebhookExecutor.swift`

---

## MEDIUM PRIORITY

### Phase 11j: Audio Duration Validation

**Problem:** Too short audio returns garbage, too long may timeout.

**Implementation:**
```swift
struct AudioValidation {
    static let minDuration: TimeInterval = 0.5
    static let maxDuration: TimeInterval = 600
    static let warnDuration: TimeInterval = 300
}

// New error cases
case audioTooShort
case audioTooLong
```

**Files:**
- `Services/Audio/AudioRecorder.swift`
- `Services/Orchestration/TranscriptionOrchestrator.swift`
- `Services/TranscriptionError.swift`

---

### Phase 11k: Documentation Updates

Update `CLAUDE.md` and `ORCHESTRATION_FLOW.md` with:
- New states: `.retrying`
- Retry flow diagram
- Audio queue system
- Phase 11 marked complete

---

## NEW: Auto-Insert & Keyboard UI

### Keyboard Status Banner

```
┌─────────────────────────────────────────────────────┐
│ ┌─────────────────────────────────────────────────┐ │
│ │  ◐ Transcribing...                              │ │  ← Banner
│ └─────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────┤
│  ● OpenAI Whisper                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │     🎤      │  │     🌍      │  │     ⚡      │ │
│  │ Transcribe  │  │  Translate  │  │  Power Mode │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
│  ...                                                │
│  ┌───────┐  ┌──────────────────────┐  ┌─────────┐ │
│  │  🌐   │  │ 🔴 1 pending audio   │  │    ⌫    │ │  ← Replaces "Insert Last"
│  └───────┘  └──────────────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────┘
```

**Banner States:**
- `◐ Transcribing...`
- `◐ Formatting...`
- `⟳ Retrying (2/3)... Network timeout`
- `✓ Done! Text inserted.`
- `✕ Failed after 3 retries [Retry] [Dismiss]`
- `⚠ Formatting failed - raw used [Rerun]`

### Auto-Insert Implementation

```swift
// KeyboardViewController.swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewModel.loadSettings()
    viewModel.checkAutoInsert()
}

// KeyboardViewModel
func checkAutoInsert() {
    let status = processingStatus
    if status.pendingAutoInsert, let text = status.lastCompletedText {
        textDocumentProxy?.insertText(text)
        // Clear flag
        var updated = status
        updated.pendingAutoInsert = false
        updated.lastCompletedText = nil
        saveProcessingStatus(updated)
    }
}
```

**Files:**
- `SwiftSpeakKeyboard/KeyboardView.swift`
- `SwiftSpeakKeyboard/KeyboardViewController.swift`
- `SwiftSpeakKeyboard/PendingAudioSheet.swift` (NEW)

### Settings: Retry Section

```swift
Section {
    Toggle("Auto-Retry on Failure", isOn: $settings.autoRetryEnabled)
    if settings.autoRetryEnabled {
        Stepper("Maximum Retries: \(settings.maxRetryCount)",
               value: $settings.maxRetryCount, in: 1...10)
    }
    Toggle("Keep Failed Recordings", isOn: $settings.keepFailedRecordings)
    if settings.keepFailedRecordings {
        Picker("Auto-Delete After", selection: $settings.pendingAudioRetentionDays) {
            Text("Never").tag(0)
            Text("1 day").tag(1)
            Text("7 days").tag(7)
            Text("30 days").tag(30)
        }
    }
} header: {
    Text("Retry Settings")
}
```

**Files:**
- `Views/SettingsView.swift`
- `Views/Settings/PendingAudioListView.swift` (NEW)

---

## Files Summary

### NEW FILES (9)
| File | Purpose |
|------|---------|
| `Services/Security/PromptSanitizer.swift` | Sanitize user input before LLM |
| `Services/Providers/TokenCounter.swift` | Token counting and limits |
| `Services/Network/RetryPolicy.swift` | Retry with exponential backoff |
| `Services/Memory/MemoryUpdateCoordinator.swift` | Serialize memory updates |
| `Services/Providers/ProviderHealthTracker.swift` | Track provider failures |
| `Services/Webhooks/WebhookCircuitBreaker.swift` | Skip failing webhooks |
| `SwiftSpeakKeyboard/PendingAudioSheet.swift` | Keyboard pending queue UI |
| `Views/Settings/PendingAudioListView.swift` | Main app pending queue |
| `SwiftSpeakTests/Services/PromptSanitizerTests.swift` | Security tests |

### MODIFIED FILES (14)
| File | Changes |
|------|---------|
| `Shared/Models.swift` | PendingAudio, ProcessingStatus, RecordingState.retrying |
| `SharedSettings.swift` | Retry settings, pending queue, processing status |
| `Services/Orchestration/TranscriptionOrchestrator.swift` | Retry logic, audio preservation |
| `Services/Orchestration/PowerModeOrchestrator.swift` | Sanitization, token limits |
| `Services/Orchestration/PromptContext.swift` | Sanitization, truncation |
| `Services/Audio/AudioRecorder.swift` | Duration validation, keep file option |
| `Services/ProviderFactory.swift` | Fallback provider logic |
| `Services/Webhooks/WebhookExecutor.swift` | Parallel exec, circuit breaker |
| `Services/TranscriptionError.swift` | audioTooShort, audioTooLong |
| `Views/RecordingView.swift` | Retry UI, error options |
| `Views/SettingsView.swift` | Retry settings section |
| `ContentView.swift` | Pending badge |
| `SwiftSpeakKeyboard/KeyboardView.swift` | Status banner, pending indicator |
| `SwiftSpeakKeyboard/KeyboardViewController.swift` | Auto-insert check |

---

## Implementation Order

```
1. Phase 11a: PromptSanitizer ─────────────────┐
2. Phase 11b: Fix formatting provider bug ─────┼── Security First
3. Phase 11c: Memory serialization ────────────┘

4. Phase 11d: Token limits ────────────────────┐
5. Phase 11e: Retry logic + audio queue ───────┼── Reliability
6. Phase 11f: Provider fallback ───────────────┘

7. Phase 11g: Webhook improvements ────────────┐
8. Phase 11j: Audio duration validation ───────┼── Polish
9. Phase 11k: Documentation ───────────────────┘

10. Keyboard UI: Banner, pending, auto-insert ─── UX
11. Settings UI: Retry section ────────────────── UX
12. Testing ───────────────────────────────────── QA
```

---

## Test Scenarios

1. **Prompt injection** - Try `</system>IGNORE PREVIOUS` in vocabulary
2. **Rapid transcriptions** - 10 quick recordings, verify no memory loss
3. **Network failure** - Airplane mode mid-transcription
4. **Retry exhausted** - All 3 retries fail, verify audio saved
5. **Partial success** - Mock formatting failure after transcription
6. **Auto-insert** - Complete flow, verify text appears in host app
7. **Pending queue** - Multiple failures, manage from keyboard sheet
8. **Provider fallback** - Primary down, verify fallback used
9. **Webhook timeout** - Slow webhook doesn't block others
10. **Audio too short** - 0.2s recording rejected

---

## Notes

- **Phase 11i (Privacy Mode During Operation) REMOVED** - Settings should be locked at operation start. Changing mid-stream would be confusing.
- **Phase 11h merged into 11e** - Partial failure recovery is part of the retry/queue system.
