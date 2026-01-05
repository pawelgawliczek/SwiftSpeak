# macOS Port

SwiftSpeak macOS is a **menu bar app with floating overlay** for voice dictation anywhere on the desktop.

## Status: 85% Complete

| Component | Status | Notes |
|-----------|--------|-------|
| Views | 16/16 | All main views implemented |
| Platform Services | 5/5 | Audio, hotkeys, permissions, text insertion |
| Settings + iCloud Sync | Complete | Cross-device sync working |
| Obsidian Services | Not ported | Services in iOS only |
| Power Mode Execution | Partial | Overlay exists, orchestrator wiring incomplete |

---

## Architecture Differences

| Aspect | iOS | macOS |
|--------|-----|-------|
| **Entry Point** | Keyboard extension | Menu bar icon |
| **Recording UI** | Full-screen RecordingView | Floating overlay panel |
| **Text Insertion** | textDocumentProxy | Accessibility API / Clipboard |
| **Microphone Access** | Via main app (URL scheme) | Direct (menu bar app) |
| **Global Trigger** | Keyboard button tap | Hotkey (Cmd+Shift+D) |
| **SwiftLink** | Required (keyboard ↔ app) | Not needed |
| **Settings Storage** | App Groups UserDefaults | Standard UserDefaults + iCloud |

---

## Implemented Views

**Location:** `SwiftSpeakMac/Views/`

| View | Lines | Purpose |
|------|-------|---------|
| `MenuBarController.swift` | 2,088 | Menu bar + overlay management |
| `RecordingOverlayView.swift` | 905 | Floating recording panel |
| `MacContextsView.swift` | 851 | Context management (HSplitView) |
| `MacCostAnalyticsView.swift` | 881 | Cost analytics dashboard |
| `MacMemoryView.swift` | 574 | 3-tier memory management |
| `MacPowerModesView.swift` | 588 | Power Mode list/editor |
| `MacPowerModeOverlayView.swift` | 612 | Power Mode execution overlay |
| `MacHistoryView.swift` | 410 | Transcription history |
| `MacVaultsSettingsView.swift` | 479 | Obsidian vault settings |

---

## Platform Services

**Location:** `SwiftSpeakMac/Platform/`

| Service | Purpose |
|---------|---------|
| `MacAudioRecorder.swift` | AVAudioEngine-based recording |
| `MacHotkeyManager.swift` | Global hotkey registration (Carbon Events) |
| `MacPermissionManager.swift` | Microphone + Accessibility permissions |
| `MacTextInsertionService.swift` | AXUIElement text insertion |
| `MacBiometricAuth.swift` | Touch ID authentication |

**Location:** `SwiftSpeakMac/Services/`

| Service | Purpose |
|---------|---------|
| `MacWindowContextService.swift` | Capture active window text via Accessibility |
| `MacFileWatcher.swift` | File system monitoring for vaults |
| `MacFileBookmarkManager.swift` | Security-scoped bookmark persistence |
| `MacCloudKitLogSync.swift` | CloudKit log synchronization |

---

## Settings & iCloud Sync

**File:** `MacSharedSettings.swift` (~1,200 lines)

Synced via iCloud (NSUbiquitousKeyValueStore):
- Provider selections (transcription, formatting, translation)
- AI provider configurations
- Language preferences
- Memory content (global, context, power mode)
- Custom templates and vocabulary

**iCloud Keys:** 19 synchronized properties

---

## Remaining Work

### High Priority
- [ ] Port Obsidian services (ObsidianSyncService, ObsidianQueryService)
- [ ] Wire PowerModeOrchestrator to overlay
- [ ] Complete Power Mode execution flow

### Medium Priority
- [ ] Security/Privacy settings view
- [ ] Behavior settings (auto-insert, sounds)
- [ ] Additional AI provider services (Google, DeepL, etc.)

### Low Priority
- [ ] Webhooks UI
- [ ] RAG/Knowledge Base UI
- [ ] Diagnostics view

---

## Development Patterns

### HSplitView for Master-Detail
```swift
HSplitView {
    List(selection: $selectedItem) { ... }
        .frame(minWidth: 200)
    DetailView(item: selectedItem)
        .frame(minWidth: 400)
}
```

### Form for Settings
```swift
Form {
    Section("Provider Settings") {
        Picker("Transcription", selection: $provider) { ... }
    }
}
.formStyle(.grouped)
```

### Global Hotkeys
```swift
// Register via MacHotkeyManager
hotkeyManager.registerHotkey(
    HotkeyCombination(keyCode: 2, modifiers: cmdShift, displayString: "⌘⇧D"),
    for: .toggleRecording
)
```

---

## Key Files Reference

| Purpose | File |
|---------|------|
| App entry | `SwiftSpeakMacApp.swift` |
| Settings model | `MacSharedSettings.swift` |
| Type definitions | `MacSharedTypes.swift` |
| Provider factory | `MacProviderFactory.swift` |
| Menu bar logic | `MenuBarController.swift` |
