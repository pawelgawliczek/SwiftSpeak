# Unified Logging System

Both the main app and keyboard extension write to a shared log file via App Groups for unified debugging.

**IMPORTANT:** Always use `appLog()` or `keyboardLog()` for ALL logging. NEVER use `os.log`, `Logger`, `print()`, or `NSLog()`. The `appLog()`/`keyboardLog()` functions write to the shared App Groups file that users can view and export in DiagnosticsView.

## Architecture

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

## Key Files

| File | Purpose |
|------|---------|
| `LogSanitizer.swift` | Removes API keys, user content, PII from logs |
| `SharedLogManager.swift` | Actor-based file logging to App Groups |
| `LogExporter.swift` | Exports logs with device info header |
| `DiagnosticsView.swift` | UI for viewing/exporting logs |
| `Logging.swift` | os.log Logger extensions (categories) |

## Privacy-Safe Logging

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

## Usage

```swift
// From main app
appLog("Recording started (mode: email)", category: "Transcription")
appLog("API error: \(LogSanitizer.sanitizeError(error))", category: "API", level: .error)

// From keyboard extension
keyboardLog("Transcription requested", category: "Action")
keyboardLog("Keyboard appeared", category: "Lifecycle")
```

## Log Categories

| Category | Usage |
|----------|-------|
| `Transcription` | Recording, transcription, formatting, translation |
| `Navigation` | URL scheme handling, view transitions |
| `Subscription` | RevenueCat configuration, tier changes |
| `Audio` | Audio session management |
| `RAG` | Document processing, vector search |
| `Lifecycle` | Keyboard load/appear |
| `Action` | User actions in keyboard |
