# Phase 5: Window Context, Power Mode Overlay & Hotkeys - Implementation Summary

## Overview
Phase 5 of the Obsidian Vault Integration adds window context capture, a Power Mode overlay with 6 execution states, and per-Power Mode hotkey support for macOS.

## Completed Components

### 1. MacWindowContextService ✅
**File:** `/SwiftSpeak/SwiftSpeakMac/Services/MacWindowContextService.swift`

**Purpose:** Captures text and metadata from the active window using macOS Accessibility API.

**Key Features:**
- Permission checking (`isAccessibilityEnabled()`)
- Permission requesting with system prompt
- Captures window title, app name, bundle ID
- Extracts selected text (if user has text highlighted)
- Extracts visible text (fallback when no selection)
- Configurable text length limits (2000 chars visible, 5000 chars selected)
- Error handling with descriptive errors

**Data Structure:**
```swift
public struct WindowContext: Sendable {
    let appName: String
    let appBundleId: String
    let windowTitle: String
    let selectedText: String?
    let visibleText: String?
    let capturedAt: Date
}
```

**Usage:**
```swift
let service = MacWindowContextService()

// Check permission
guard service.isAccessibilityEnabled() else {
    service.requestAccessibilityPermission()
    return
}

// Capture context
let context = try await service.captureWindowContext()
print(context.summary)
```

### 2. MacPowerModeOverlayViewModel ✅
**File:** `/SwiftSpeak/SwiftSpeakMac/Views/MacPowerModeOverlayViewModel.swift`

**Purpose:** Manages state and logic for the Power Mode overlay UI.

**Key States:**
1. **contextPreview** - Show context sources with toggles
2. **recording** - Recording voice input
3. **processing** - AI thinking
4. **aiQuestion** - AI asking clarification
5. **result** - Show result, allow iteration
6. **actionComplete** - Saved to Obsidian, auto-close

**Context Sources:**
- Window Context (from active app)
- Obsidian Notes (semantic search results)
- Memory (global + context + power mode)

**User Actions:**
- Toggle context sources on/off
- Record voice input
- Type input (planned)
- Answer AI questions
- Refine results
- Copy to clipboard
- Insert at cursor
- Save to Obsidian

**Dependencies:**
- `MacSettings` - User settings
- `MacWindowContextService` - Window context capture
- `MacAudioRecorder` - Voice recording
- `ProviderFactory` - AI provider creation
- `ObsidianQueryService` - Vault search
- `MacTextInsertionService` - Text insertion

### 3. MacPowerModeOverlayView ✅
**File:** `/SwiftSpeak/SwiftSpeakMac/Views/MacPowerModeOverlayView.swift`

**Purpose:** SwiftUI view for the Power Mode overlay with 6 execution states.

**UI Highlights:**
- Animated state transitions
- Context source cards with toggle buttons
- Recording indicator with waveform visualization
- Processing animation with brain icon
- Question/answer interface
- Result display with refinement input
- Action buttons (Copy, Insert, Save)
- Completion state with auto-close
- Error banner
- Keyboard shortcuts hints

**Keyboard Shortcuts:**
- `Esc` - Close overlay
- `Space` - Stop recording
- `Enter` - Submit answer/refinement

**Previews:** Includes 3 SwiftUI previews for different states.

### 4. MacPowerModeOverlayController ✅
**File:** `/SwiftSpeak/SwiftSpeakMac/Views/MacPowerModeOverlayController.swift`

**Purpose:** NSPanel wrapper for the floating overlay window.

**Window Configuration:**
- Level: `.floating` (always on top)
- Style: Non-activating panel (doesn't steal focus)
- Behavior: Can join all spaces, full screen auxiliary
- Positioning: Centered horizontally, upper third vertically
- Keyboard monitoring: Esc to close, Space to stop recording

**API:**
```swift
let controller = MacPowerModeOverlayController(
    settings: settings,
    windowContextService: windowContextService,
    audioRecorder: audioRecorder,
    providerFactory: providerFactory,
    obsidianQueryService: obsidianQueryService,
    textInsertion: textInsertion
)

// Show overlay
controller.showOverlay(for: powerMode, windowContext: nil)

// Hide overlay
controller.hideOverlay()

// Toggle
controller.toggleOverlay(for: powerMode)
```

### 5. MacPermissionManager Updates ✅
**File:** `/SwiftSpeak/SwiftSpeakMac/Platform/MacPermissionManager.swift`

**Changes:**
- Added `isAccessibilityEnabled` computed property for easy checking
- Updated `promptForAccessibilityPermission()` to refresh status after prompting
- Status refresh happens 0.5s after prompt to give user time to grant permission

### 6. Power Mode Hotkey Storage ✅
**Files:**
- `/SwiftSpeak/SwiftSpeakMac/MacSharedTypes.swift`
- `/SwiftSpeak/SwiftSpeakMac/MacSharedSettings.swift`

**Changes to `HotkeyAction` enum:**
```swift
enum HotkeyAction: String, CaseIterable, Hashable {
    case toggleRecording
    case cancelRecording
    case quickPaste
    case powerMode(UUID)  // NEW: Power Mode with ID

    // Custom hashable/equatable to support associated value
}
```

**Changes to `MacSettings`:**
```swift
@Published var powerModeHotkeys: [UUID: HotkeyCombination] = [:]

// Saves to UserDefaults as JSON
private func savePowerModeHotkeys()
private func loadPowerModeHotkeys()
```

## Remaining Tasks

### 1. Extend MacHotkeyManager (In Progress)
Need to add methods for registering/unregistering Power Mode hotkeys:

```swift
extension MacHotkeyManager {
    func registerPowerModeHotkey(
        powerModeId: UUID,
        keyCode: UInt16,
        modifiers: UInt
    ) throws

    func unregisterPowerModeHotkey(powerModeId: UUID)

    func registeredPowerModeHotkeys() -> [UUID: HotkeyCombination]

    func loadPowerModeHotkeys(from settings: MacSettings) throws
}
```

### 2. Create MacPowerModeHotkeyEditor
A UI component for configuring Power Mode hotkeys:
- Shows current hotkey or "Not Set"
- Record button to capture new hotkey
- Clear button to remove hotkey
- Used in Power Mode editor sheets

### 3. Integrate into MenuBarController
Add Power Mode overlay support to MenuBarController:
- Create `MacPowerModeOverlayController` instance
- Handle Power Mode hotkey presses
- Show overlay when hotkey pressed
- Update menu to show Power Modes with their hotkeys

### 4. Add Power Mode Menu Items
Update menu bar menu to show:
- Power Modes submenu
- Each Power Mode with its hotkey display (e.g., "Meeting Notes  ⌥M")
- Click to trigger Power Mode overlay

### 5. Write Tests
Unit tests for:
- `MacWindowContextService` (permission, context capture, text extraction)
- `MacPowerModeOverlayViewModel` (state transitions, context loading)
- `MacPowerModeOverlayController` (window management)

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│                    Menu Bar                          │
│  [SwiftSpeak Icon] (shows menu with Power Modes)    │
└────────────┬────────────────────────────────────────┘
             │
             │ User presses hotkey (e.g., ⌥M)
             ▼
┌─────────────────────────────────────────────────────┐
│         MacPowerModeOverlayController                │
│  ┌───────────────────────────────────────────────┐  │
│  │     MacPowerModeOverlayView (SwiftUI)         │  │
│  │  ┌──────────────────────────────────────┐    │  │
│  │  │ MacPowerModeOverlayViewModel         │    │  │
│  │  │  - State management                  │    │  │
│  │  │  - Context loading                   │    │  │
│  │  │  - AI interaction                    │    │  │
│  │  └────┬──────────────┬──────────────────┘    │  │
│  │       │              │                        │  │
│  └───────┼──────────────┼────────────────────────┘  │
└──────────┼──────────────┼───────────────────────────┘
           │              │
           ▼              ▼
    ┌─────────────┐  ┌──────────────────────┐
    │   Window    │  │     Obsidian         │
    │   Context   │  │   Query Service      │
    │   Service   │  │                      │
    └─────────────┘  └──────────────────────┘
```

## State Flow Diagram

```
┌──────────────────┐
│ Hotkey Pressed   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     ┌──────────────────┐
│ Context Preview  │────▶│ Load Context:    │
│ (State 1)        │     │ - Window text    │
│                  │     │ - Obsidian notes │
│ [User toggles    │     │ - Memory         │
│  context sources]│     └──────────────────┘
└────────┬─────────┘
         │ User taps Mic
         ▼
┌──────────────────┐
│ Recording        │
│ (State 2)        │
└────────┬─────────┘
         │ User stops
         ▼
┌──────────────────┐
│ Processing       │
│ (State 3)        │
│ - Transcribe     │
│ - Build prompt   │
│ - Call LLM       │
└────────┬─────────┘
         │
    ┌────┴───────────┐
    │ AI Response    │
    ▼                ▼
┌──────────────┐  ┌──────────────┐
│ AI Question  │  │   Result     │
│ (State 4)    │  │  (State 5)   │
└──────┬───────┘  └──────┬───────┘
       │                 │
       │ Answer          │ [Refine/Copy/Insert/Save]
       │                 │
       └────► back to    │
              State 3    ▼
                    ┌──────────────┐
                    │   Complete   │
                    │  (State 6)   │
                    │ Auto-closes  │
                    └──────────────┘
```

## Next Steps

1. **Extend MacHotkeyManager** - Add Power Mode hotkey registration methods
2. **Create MacPowerModeHotkeyEditor** - UI component for hotkey configuration
3. **Integrate into MenuBarController** - Wire up overlay controller and hotkey handling
4. **Update menu bar menu** - Show Power Modes with hotkey indicators
5. **Write comprehensive tests** - Ensure robustness

## Files Modified

### Created
1. `SwiftSpeakMac/Services/MacWindowContextService.swift`
2. `SwiftSpeakMac/Views/MacPowerModeOverlayViewModel.swift`
3. `SwiftSpeakMac/Views/MacPowerModeOverlayView.swift`
4. `SwiftSpeakMac/Views/MacPowerModeOverlayController.swift`

### Modified
1. `SwiftSpeakMac/Platform/MacPermissionManager.swift`
   - Added `isAccessibilityEnabled` property
   - Updated `promptForAccessibilityPermission()` to refresh status

2. `SwiftSpeakMac/MacSharedTypes.swift`
   - Extended `HotkeyAction` enum with `.powerMode(UUID)` case
   - Added custom hash/equality for associated value

3. `SwiftSpeakMac/MacSharedSettings.swift`
   - Added `powerModeHotkeys: [UUID: HotkeyCombination]` property
   - Added `savePowerModeHotkeys()` and `loadPowerModeHotkeys()` methods
   - Called `loadPowerModeHotkeys()` in initialization

## API Usage Examples

### Capturing Window Context
```swift
let service = MacWindowContextService()

// Request permission if needed
if !service.isAccessibilityEnabled() {
    service.requestAccessibilityPermission()
}

// Capture context
do {
    let context = try await service.captureWindowContext()
    print("App: \(context.appName)")
    print("Text: \(context.displayText)")
} catch {
    print("Failed: \(error)")
}
```

### Showing Power Mode Overlay
```swift
let overlayController = MacPowerModeOverlayController(
    settings: MacSettings.shared,
    windowContextService: MacWindowContextService(),
    audioRecorder: MacAudioRecorder(),
    providerFactory: ProviderFactory(settings: MacSettings.shared),
    obsidianQueryService: nil,
    textInsertion: MacTextInsertionService()
)

// Show for specific Power Mode
overlayController.showOverlay(for: powerMode)
```

### Configuring Power Mode Hotkeys
```swift
// Save hotkey for Power Mode
let powerModeId = powerMode.id
let hotkey = HotkeyCombination(
    keyCode: 46,  // M key
    modifiers: UInt(NSEvent.ModifierFlags.option.rawValue),
    displayString: "⌥M"
)

settings.powerModeHotkeys[powerModeId] = hotkey

// Load and register all Power Mode hotkeys
for (id, combination) in settings.powerModeHotkeys {
    try hotkeyManager.registerPowerModeHotkey(
        powerModeId: id,
        keyCode: combination.keyCode,
        modifiers: combination.modifiers
    )
}
```

## Known Limitations

1. **Accessibility Permission Required** - User must grant accessibility permission in System Settings for window context capture to work
2. **App-Specific Text Extraction** - Some apps may not expose text via Accessibility API (browsers, PDFs, etc.)
3. **Text Length Limits** - Window text truncated to 2000/5000 chars to avoid overwhelming context
4. **Type Input Not Implemented** - Currently only voice input is supported (type input is disabled)
5. **Obsidian Save Not Implemented** - Save to Obsidian action is placeholder (returns immediately)

## Testing Checklist

- [ ] Window context captures correctly from text editors (TextEdit, VS Code)
- [ ] Window context handles apps without text gracefully
- [ ] Accessibility permission prompt works
- [ ] Overlay shows all 6 states correctly
- [ ] Context toggles enable/disable sources
- [ ] Recording and transcription work
- [ ] AI processing shows loading state
- [ ] Question/answer flow works
- [ ] Result refinement works
- [ ] Copy to clipboard works
- [ ] Insert at cursor works (with accessibility permission)
- [ ] Auto-close after completion
- [ ] Keyboard shortcuts work (Esc, Space)
- [ ] Hotkey storage persists across app restarts
- [ ] Multiple Power Mode hotkeys don't conflict

## Performance Considerations

1. **Window Context Capture** - Async operation, may take 100-500ms depending on app
2. **Obsidian Query** - Searches all vaults, may take 200-1000ms
3. **Memory Loading** - Fast, just string concatenation
4. **AI Processing** - Dependent on provider latency (1-5 seconds typical)
5. **Text Insertion** - Accessibility method is instant, clipboard fallback requires user paste

## Security & Privacy

1. **Window Context** - Captured text stays local unless sent to AI provider
2. **Accessibility Permission** - System-level permission, clearly explained to user
3. **API Keys** - Stored securely in Keychain
4. **Logs** - Sensitive data sanitized (no window text in logs)
5. **iCloud Sync** - Hotkeys NOT synced to iCloud (macOS-specific, local only)

---

**Implementation Date:** January 2026
**Phase:** 5 of 5 (Obsidian Vault Integration)
**Status:** ~70% Complete
**Remaining:** Hotkey manager extension, hotkey editor UI, menu bar integration, tests
