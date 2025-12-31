# Phase 12: Edit Text Feature

## Overview

The Edit Text feature allows users to modify existing text in a text field using voice instructions. When the keyboard detects text in the field, the flow changes from "record new text" to "edit existing text".

**Tier:** Free (available to all users)

## User Flows

### Flow A: Standard (No SwiftLink)

```
User in any app with text field
        │
        ↓
┌─────────────────────────────────────────┐
│  Keyboard detects text in field         │
│  Button changes: "Record" → "Edit Text" │
│  (Green button with pencil icon)        │
└─────────────────────────────────────────┘
        │
        ↓ (Edit Text tapped)
┌─────────────────────────────────────────┐
│  Main App Opens (Edit Mode)             │
│  Shows: Green "Edit" badge              │
│  Collapsible "Original text" preview    │
│  Recording prompt: "Describe changes..."│
└─────────────────────────────────────────┘
        │
        ↓ (User dictates instructions)
┌─────────────────────────────────────────┐
│  LLM modifies text → auto-return        │
│  Text copied to clipboard               │
│  History entry created (edit type)      │
└─────────────────────────────────────────┘
```

### Flow B: SwiftLink Active (Stays in Keyboard)

```
┌─────────────────────────────────────────┐
│  SwiftLink session active               │
│  Keyboard detects text in field         │
│  Button shows: "✏️ Edit" (green)        │
└─────────────────────────────────────────┘
        │
        ↓ (User taps mic/speaks)
┌─────────────────────────────────────────┐
│  Keyboard shows "Editing..." status     │
│  Records instructions in keyboard       │
│  Sends startEdit notification to app    │
└─────────────────────────────────────────┘
        │
        ↓ (Main app processes in background)
┌─────────────────────────────────────────┐
│  Transcribe instructions                │
│  LLM edits original text                │
│  Result sent via editResultReady notif  │
└─────────────────────────────────────────┘
        │
        ↓
┌─────────────────────────────────────────┐
│  Keyboard clears field                  │
│  Inserts edited result                  │
│  History entry created (edit type)      │
└─────────────────────────────────────────┘
```

## Implementation Details

### Files Modified

| File | Changes |
|------|---------|
| `Shared/Models/Transcription.swift` | Added `EditContext` struct, `editContext` field to `TranscriptionRecord`, `isEditOperation` computed property |
| `Shared/Constants.swift` | Added `URLHosts` enum, SwiftLink edit notifications (`startEdit`, `editResultReady`), `EditMode` keys |
| `SwiftSpeakKeyboard/KeyboardView.swift` | Added `existingTextInField`, edit mode UI (green button), `startSwiftLinkEdit()`, `startEditModeViaURL()` |
| `SwiftSpeakKeyboard/DarwinNotificationManager.swift` | (Already had infrastructure, used for edit notifications) |
| `Services/SwiftLink/SwiftLinkSessionManager.swift` | Added `isEditMode`, observer for `startEdit`, `processEditMode()`, `saveEditToHistory()` |
| `ContentView.swift` | Added `editModeOriginalText` state, handler for `swiftspeak://edit` URL |
| `Views/RecordingView.swift` | Added `editModeOriginalText` param, `isEditMode`, edit mode UI in RecordingCard |
| `Services/Orchestration/TranscriptionOrchestrator.swift` | Added `editOriginalText`, `isEditMode`, `applyEdit()`, `saveEditToHistory()`, `findParentEntryId()` |
| `Views/HistoryView.swift` | Added green "Edit" badge, edit-specific content display, parent link in detail view |

### Data Model

```swift
/// Context for edit operations where user modifies existing text
struct EditContext: Codable, Equatable {
    /// The original text that was in the text field
    let originalText: String

    /// What the user dictated as editing instructions
    let instructions: String

    /// If the original text came from a previous transcription
    let parentEntryId: UUID?
}
```

### URL Scheme

```
swiftspeak://edit
```

Original text is passed via App Groups (`Constants.EditMode.pendingEditText`) rather than URL encoding (which is problematic for large text).

### Darwin Notifications

```swift
// Keyboard → App: Start edit mode recording
Constants.SwiftLinkNotifications.startEdit = "com.swiftspeak.swiftlink.startEdit"

// App → Keyboard: Edit result is ready
Constants.SwiftLinkNotifications.editResultReady = "com.swiftspeak.swiftlink.editResultReady"
```

### LLM Prompt

```
System: You are a text editor. Modify the provided text according to the user's instructions.
Return ONLY the modified text, nothing else.
Preserve the original language unless translation is requested.
Do not add explanations, prefixes, or commentary.

User:
Original text:
[original text from field]

Instructions:
[transcribed user instructions]
```

## UI Elements

### Keyboard Edit Button
- **Color:** Green (instead of accent color)
- **Icon:** `pencil.circle.fill` (instead of `mic.fill`)
- **Label:** "Edit" or "Editing..." during recording

### RecordingView Edit Mode
- **Badge:** Green "Edit" badge in header
- **Preview:** Collapsible "Original text" section showing what will be edited
- **Status text:** "Describe your changes..." (instead of "Transcribing...")
- **Complete text:** "Text edited!" (instead of "Done!")

### HistoryView Edit Entries
- **Badge:** Green "Edit" badge (replaces mode badge)
- **Content:** Shows "Instructions" (italic) and "Result" instead of "Input"/"Output"
- **Detail view:** Full context with Original → Instructions → Result flow
- **Parent link:** If text came from a SwiftSpeak transcription, shows link to parent entry

## History Entry Example

```
┌─────────────────────────────────────────┐
│ [Edit]                        2m ago    │
│ Instructions: "make it more formal"     │
│ Result: "Dear Mr. Smith, I am..."       │
│ 🕐 8s · $0.001         [Details >]      │
└─────────────────────────────────────────┘
```

## Parent Entry Finding

The system attempts to find if the original text came from a recent SwiftSpeak transcription:

1. **Exact match:** Check last 50 entries from past 24 hours for exact text match
2. **Trimmed match:** Compare after trimming whitespace
3. **Prefix match:** Handle partial text selection (≥80% length similarity)

If found, the edit entry links to the parent via `parentEntryId`.

## Cost Tracking

Edit operations track:
- **Transcription cost:** For transcribing the voice instructions
- **Formatting cost:** For the LLM edit operation (input = original + instructions, output = result)

## Testing Checklist

- [ ] Keyboard detects text and shows Edit button (green)
- [ ] Standard flow: Edit opens main app in edit mode
- [ ] Edit recording shows original text preview
- [ ] Edit processing shows "Applying your edits..."
- [ ] Result is copied to clipboard
- [ ] SwiftLink flow: Edit stays in keyboard
- [ ] SwiftLink clears field and inserts result
- [ ] History shows edit entries with green badge
- [ ] History detail shows Original/Instructions/Result
- [ ] Parent linking works for recent transcriptions
- [ ] Cost tracking includes edit operation costs

## Future Enhancements

- Selection-based editing (edit only selected text)
- Multi-step edits (chain of edits on same text)
- Edit suggestions/quick actions ("make formal", "fix grammar")
- Undo last edit in keyboard
