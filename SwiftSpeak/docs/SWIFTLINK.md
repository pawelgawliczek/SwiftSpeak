# SwiftLink - Background Dictation

SwiftLink enables voice dictation without leaving the current app. The main app runs in the background while the keyboard triggers recording.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Keyboard Extension                            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Start Link  │    │  Recording  │    │   Insert    │         │
│  │   Button    │───▶│   Button    │───▶│   Result    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
└────────────┬───────────────┬────────────────┬───────────────────┘
             │               │                │
     Darwin Notify    Darwin Notify    App Groups
     (startSession)   (startDictation) (result text)
             │               │                │
             ▼               ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Main App (Background)                       │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Start     │    │   Record    │    │  Transcribe │         │
│  │   Session   │───▶│   Audio     │───▶│  & Format   │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                                      │                 │
│   Background                            Darwin Notify            │
│   Audio Mode                            (resultReady)            │
└─────────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `DarwinNotificationManager.swift` | Darwin notification IPC for keyboard ↔ app |
| `KeyboardView.swift` | SwiftLink UI (start button, recording indicator) |
| `ContentView.swift` | Background session handling, audio recording |
| `Constants.swift` | SwiftLink notification names and keys |

## Darwin Notifications (IPC)

```swift
// Notification names (Constants.SwiftLinkNotifications)
static let prefix = "com.swiftspeak.swiftlink."
static let startDictation = prefix + "startDictation"
static let stopDictation = prefix + "stopDictation"
static let resultReady = prefix + "resultReady"
static let sessionStarted = prefix + "sessionStarted"
static let sessionEnded = prefix + "sessionEnded"
static let startEdit = prefix + "startEdit"
static let streamingUpdate = prefix + "streamingUpdate"
```

## App Groups Keys

```swift
// SwiftLink state (Constants.Keys)
static let swiftLinkSessionActive = "swiftLinkSessionActive"
static let swiftLinkTranscriptionResult = "swiftLinkTranscriptionResult"
static let swiftLinkProcessingStatus = "swiftLinkProcessingStatus"

// Edit Mode (Constants.EditMode)
static let pendingEditText = "pendingEditText"
static let swiftLinkEditOriginalText = "swiftLinkEditOriginalText"
static let lastResultWasEdit = "lastResultWasEdit"
```

## SwiftLink Flow

1. **Start Session**: User taps "Link" button in keyboard
   - Main app opens briefly, starts background audio session
   - Returns to original app automatically
   - Keyboard shows orange "SwiftLink Active" indicator

2. **Record**: User taps mic button (now orange)
   - Darwin notification triggers recording in background app
   - Keyboard shows red pulsing button with waveform
   - User speaks, taps to stop

3. **Process**: Main app transcribes and formats
   - Status updates via Darwin notifications
   - Result stored in App Groups

4. **Insert**: Keyboard receives result notification
   - Text automatically inserted into text field
   - Ready for next dictation

## Edit Mode

When text exists in the field, the keyboard enters "Edit Mode":
- Button turns **green** with pencil icon
- Label shows "Edit text"
- User can dictate changes to existing text

**Two Edit Flows:**
1. **SwiftLink Edit**: Stays in keyboard, processes in background
2. **URL Scheme Edit**: Opens main app for complex edits

```swift
// Keyboard detects existing text
var hasTextInField: Bool {
    guard let proxy = textDocumentProxy else { return false }
    let before = proxy.documentContextBeforeInput ?? ""
    let after = proxy.documentContextAfterInput ?? ""
    return !before.isEmpty || !after.isEmpty
}

// Edit mode replaces all text with new result
private func deleteAllTextInField() {
    // Move to end, delete all backwards
}
```

## URL Scheme Extensions

```
swiftspeak://edit              # Edit mode (text passed via App Groups)
swiftspeak://swiftlink/start   # Start SwiftLink session
swiftspeak://swiftlink/stop    # End SwiftLink session
```
