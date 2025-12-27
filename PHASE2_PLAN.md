# SwiftSpeak Phase 2: Templates & Translation

> **Execution guide for Phase 2.** Follow this document step-by-step.
> Master project documentation: `/Users/pawelgawliczek/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`

## Overview

Complete the transcription flow with translation support, auto-return functionality, custom templates, and connect waveforms to real audio data.

**Scope:**
- Phase 1 leftovers: waveform audio connection, auto-return to previous app
- Translation feature with OpenAI GPT
- Custom template editor (TemplatesView.swift)
- Template storage via App Groups
- Keyboard integration for custom templates

## User Decisions

| Decision | Choice |
|----------|--------|
| Translation provider | OpenAI GPT only (initially) |
| Auto-return behavior | Configurable in settings |
| Custom templates access | Pro feature only |

---

## Phase 1 Leftovers

### Leftover 1: Connect Waveforms to Real Audio Levels

- [x] **Status: Complete**

**Problem:** TranscriptionOrchestrator publishes `audioLevels: [Float]` from real microphone, but waveform views use internal timers with mock animations.

**Files to modify:**

| File | Changes |
|------|---------|
| `Views/RecordingView.swift` | Pass `orchestrator.audioLevels` to RecordingCard |
| `Views/RecordingView.swift` (RecordingCard) | Add `audioLevels: [Float]` parameter, pass to waveformForType() |
| `Views/Components/WaveformView.swift` | All 9 waveform views: accept optional `audioLevels: [Float]?`, use when provided |

**Data flow after fix:**
```
AudioRecorder.currentLevel → TranscriptionOrchestrator.audioLevels → RecordingCard → WaveformView
```

### Leftover 2: Auto-Return to Previous App (Configurable)

- [x] **Status: Complete**

**Problem:** After transcription completes, app stays open. Should copy to clipboard and optionally dismiss based on user preference.

**Files to modify:**

| File | Changes |
|------|---------|
| `SharedSettings.swift` | Add `autoReturnEnabled: Bool` setting (default: true) |
| `Views/SettingsView.swift` | Add toggle for auto-return preference in Behavior section |
| `Views/RecordingView.swift` | Check setting before auto-dismissing |

---

## New Phase 2 Features

### Step 1: Implement OpenAITranslationService

- [x] **Status: Complete**

**Create:** `Services/Providers/OpenAI/OpenAITranslationService.swift`

**Pattern:** Follow `OpenAIFormattingService.swift` structure

```swift
final class OpenAITranslationService: TranslationProvider {
    let providerId: AIProvider = .openAI
    var isConfigured: Bool { !apiKey.isEmpty }
    var model: String { modelName }
    var supportedLanguages: [Language] { Language.allCases }

    func translate(
        text: String,
        from sourceLanguage: Language?,
        to targetLanguage: Language
    ) async throws -> String {
        // Build translation prompt
        // Call GPT API
        // Return translated text
    }
}
```

### Step 2: Fix ContentView URL Handling

- [x] **Status: Complete**

**File:** `ContentView.swift` (lines 86-98)

**Current bug:** Translate flag is extracted but discarded:
```swift
_ = queryItems.first(where: { $0.name == "translate" })?.value == "true"
```

**Fix:** Capture and pass to RecordingView.

### Step 3: Add Translation to TranscriptionOrchestrator

- [x] **Status: Complete**

**File:** `Services/Orchestration/TranscriptionOrchestrator.swift`

Add translation step after formatting in stopRecording().

### Step 4: Add Custom Templates Storage

- [x] **Status: Complete**

**Files:**
- `Shared/Constants.swift` - Add key
- `SharedSettings.swift` - Add property and CRUD methods

### Step 5: Create TemplatesView (Pro Feature Only)

- [x] **Status: Complete**

**Create:** `Views/TemplatesView.swift`

**Features:**
- List of custom templates with swipe to delete
- Add button in toolbar (disabled for free users with paywall prompt)
- Edit sheet for creating/editing templates
- Fields: name, icon (SF Symbol picker), prompt (multiline text)
- Pro badge/lock icon for free users

### Step 6: Add Templates to SettingsView

- [x] **Status: Complete**

**File:** `Views/SettingsView.swift`

Add section with NavigationLink to TemplatesView.

### Step 7: Integrate Templates into Keyboard Dropdown (Pro Only)

- [x] **Status: Complete**

**Files:**
- `SwiftSpeakKeyboard/KeyboardView.swift` - Show custom templates in dropdown
- `SwiftSpeakKeyboard/KeyboardViewModel.swift` - Load custom templates

### Step 8: Handle Custom Template in URL Scheme

- [x] **Status: Complete**

**File:** `ContentView.swift`

Handle `template=<uuid>` parameter in URL scheme.

### Step 9: Update FormattingProvider for Custom Templates

- [x] **Status: Complete**

**File:** `Services/Orchestration/TranscriptionOrchestrator.swift`

Modify format() to handle custom templates.

### Step 10: Write Tests

- [x] **Status: Complete**

**New test files:**
- `SwiftSpeakTests/Services/OpenAITranslationServiceTests.swift`
- `SwiftSpeakTests/Models/CustomTemplateTests.swift`

---

## Implementation Order

```
Leftover 1 (Waveform) ───────────────────────────────────────┐
Leftover 2 (Auto-return) ────────────────────────────────────┤
                                                              ↓
Step 1 (TranslationService) ──┐                          All can run
Step 2 (Fix ContentView) ─────┼──→ Step 3 (Orchestrator)  in parallel
                              │                              ↓
Step 4 (Templates Storage) ───┼──→ Step 5 (TemplatesView) → Step 6 (SettingsView)
                              │                              ↓
                              └──→ Step 7 (Keyboard) ──→ Step 8 (URL Scheme) → Step 9 (Formatting)
                                                              ↓
                                                         Step 10 (Tests)
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Services/Providers/OpenAI/OpenAITranslationService.swift` | GPT translation |
| `Views/TemplatesView.swift` | Template management UI |
| `SwiftSpeakTests/Services/OpenAITranslationServiceTests.swift` | Translation tests |
| `SwiftSpeakTests/Models/CustomTemplateTests.swift` | Template model tests |

## Files to Modify

| File | Changes |
|------|---------|
| `Views/RecordingView.swift` | Pass audioLevels, add auto-dismiss |
| `Views/Components/WaveformView.swift` | Accept audioLevels parameter |
| `ContentView.swift` | Fix translate flag handling |
| `Services/Orchestration/TranscriptionOrchestrator.swift` | Add translation step |
| `Shared/Constants.swift` | Add customTemplates key |
| `SharedSettings.swift` | Add customTemplates storage, autoReturnEnabled |
| `Views/SettingsView.swift` | Add Templates section, auto-return toggle |
| `SwiftSpeakKeyboard/KeyboardView.swift` | Show custom templates in dropdown |
| `SwiftSpeakKeyboard/KeyboardViewModel.swift` | Load custom templates |

---

## Verification Checklist

After implementation, verify:
- [ ] Waveforms respond to actual microphone input
- [ ] Auto-return setting toggle works in Settings
- [ ] App auto-dismisses only when setting is enabled
- [ ] App stays open when setting is disabled
- [ ] Translation works when translate button tapped in keyboard
- [ ] Free users cannot create custom templates (paywall shown)
- [ ] Pro users can create, edit, delete custom templates
- [ ] Custom templates appear in keyboard dropdown for Pro users only
- [ ] Custom templates sync between app and keyboard
- [ ] Custom template formatting applies correctly
- [ ] All new unit tests pass
- [ ] Existing tests still pass

---

## Notes

- CustomTemplate struct already exists in Models.swift (lines 743-767)
- TranslationProvider protocol already exists (Phase 1)
- IconPicker component exists from PowerMode (can reuse)
- All waveform changes should be backward-compatible (optional parameters)
- RecordingState may need new `.translating` case
- Need to check `subscriptionManager.hasProAccess` for template features
