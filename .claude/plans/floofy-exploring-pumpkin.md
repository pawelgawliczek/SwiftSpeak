# Plan: Implement SwiftLink (Background Dictation Sessions)

## Overview

SwiftLink enables dictation directly from the keyboard without switching apps for every recording. Inspired by Wispr Flow's "Flow Sessions" system.

## How It Works

1. **One-time session start**: User opens main app to activate background audio session
2. **Pre-configured apps**: User selects which apps they want SwiftLink enabled for
3. **Quick return**: After session starts, user returns to their app via URL scheme
4. **Inline dictation**: For session duration, keyboard can record WITHOUT app switching
5. **Configurable duration**: Sessions last 5 min, 15 min, 1 hour, or "never"
6. **Live Activity**: Shows session status in Dynamic Island/Lock Screen

---

## Technical Architecture (Verified with Apple Documentation)

### Critical iOS Constraints

| What | Allowed? | Source |
|------|----------|--------|
| Start recording from foreground | ✅ Yes | [Apple Audio Guidelines](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html) |
| Continue recording in background | ✅ Yes | [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes) |
| Start NEW recording from background | ❌ No | iOS Security |
| Keyboard extension access microphone | ❌ No | iOS Security |
| Detect host app from keyboard | ❌ No public API | Privacy restriction |
| Auto-return to previous app | ❌ No public API | [Apple Forums](https://developer.apple.com/forums/thread/126107) |

### Solution: Continuous Recording with Selective Processing

From [Wispr Flow FAQs](https://docs.wisprflow.ai/articles/9206270279-faqs):
> "During a Flow session, the mic is on, but Flow is not processing any data. Flow only processes your audio data when you start and stop dictation."

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   SESSION START (FOREGROUND)                             │
│                                                                         │
│  1. User opens app → selects target app → taps "Start"                  │
│  2. AVAudioEngine starts with installTap (MUST be foreground)           │
│  3. Audio flows to circular buffer continuously                         │
│  4. App opens target app URL scheme → returns user                      │
│  5. Recording continues in background                                   │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              DURING SESSION (KEYBOARD + BACKGROUND APP)                  │
│                                                                         │
│  Keyboard:                          Main App (background):              │
│  ┌────────────────────────┐         ┌────────────────────────┐         │
│  │ Shows: 🎤 button       │         │ Continuous recording   │         │
│  │ (session indicator)    │         │ Audio → circular buffer│         │
│  │                        │         │                        │         │
│  │ Mic tap = write        │  ────►  │ Sees "start" marker    │         │
│  │ "startDictation" flag  │ Darwin  │ → mark timestamp       │         │
│  │                        │  Notif  │                        │         │
│  │ ✓ tap = write          │  ────►  │ Sees "stop" marker     │         │
│  │ "stopDictation" flag   │         │ → extract segment      │         │
│  │                        │         │ → transcribe           │         │
│  │ Polls for result       │  ◄────  │ → format               │         │
│  │ → insert text          │ AppGrp  │ → write result         │         │
│  └────────────────────────┘         └────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## User Flow

### Setup (One Time in Settings)

```
Settings → SwiftLink

┌─────────────────────────────────────────┐
│  SwiftLink                              │
│                                         │
│  My Apps:                               │
│  ┌─────────────────────────────────┐   │
│  │ ✓ Gmail                         │   │
│  │ ✓ Messages                      │   │
│  │ ✓ WhatsApp                      │   │
│  │ ✓ Notes                         │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [+ Add App]                            │
│                                         │
│  Session Duration: [15 minutes ▼]       │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  How SwiftLink Works:                   │
│  SwiftLink keeps a recording session    │
│  active so you can dictate from the     │
│  keyboard without switching apps.       │
└─────────────────────────────────────────┘
```

### Using SwiftLink

```
KEYBOARD (always shows mic):

[🔤] [🎤] [🌍]

User taps 🎤:

┌─────────────────────────────────────────┐
│ IF session ACTIVE:                      │
│   → Record inline (show waveform)       │
│   → On complete, insert text            │
│   → No app switching!                   │
│                                         │
│ IF session NOT active:                  │
│   → Open main app via URL scheme        │
└─────────────────────────────────────────┘


MAIN APP (when session not active):

┌─────────────────────────────────────────┐
│  Start SwiftLink                        │
│                                         │
│  Going back to:                         │
│                                         │
│  [📧 Gmail]  ← Last used               │
│                                         │
│  [💬 Messages]  [📱 WhatsApp]          │
│  [📝 Notes]                             │
│                                         │
│  ─────────────────────────────────────  │
│                                         │
│  App not in list?                       │
│  [+ Add New App]                        │
└─────────────────────────────────────────┘

User taps app:
1. Session starts (recording begins)
2. Live Activity appears in Dynamic Island
3. App opens target URL scheme (e.g., googlegmail://)
4. User returns to Gmail
5. Keyboard now records inline!
```

### Session Lifecycle

| Event | Session Status | User Action |
|-------|---------------|-------------|
| Phone restart | ❌ Dies | Tap mic → quick restart |
| App killed by iOS | ❌ Dies | Tap mic → quick restart |
| Session timeout | ❌ Expires | Tap mic → quick restart |
| App in background | ✅ Continues | None |
| Phone locked | ✅ Continues | None |

---

## IPC: Keyboard ↔ App Communication

### App Groups (Data Storage)

```swift
// Shared UserDefaults keys
struct SwiftLinkKeys {
    static let sessionActive = "swiftlink_session_active"
    static let dictationStartTime = "swiftlink_dictation_start"
    static let dictationEndTime = "swiftlink_dictation_end"
    static let transcriptionResult = "swiftlink_result"
    static let lastUsedApp = "swiftlink_last_app"
    static let configuredApps = "swiftlink_apps"
}
```

### Darwin Notifications (Real-Time Signals)

From [Nonstrict Blog](https://nonstrict.eu/blog/2023/darwin-notifications-app-extensions/) and [OhMySwift](https://ohmyswift.com/blog/2024/08/27/send-data-between-ios-apps-and-extensions-using-darwin-notifications/):

```swift
// Notification names
let startDictation = "com.swiftspeak.swiftlink.startDictation"
let stopDictation = "com.swiftspeak.swiftlink.stopDictation"
let resultReady = "com.swiftspeak.swiftlink.resultReady"

// Keyboard posts:
DarwinNotificationManager.shared.post(name: startDictation)

// Main app observes:
DarwinNotificationManager.shared.startObserving(name: startDictation) {
    // Mark timestamp, start processing segment
}
```

**Limitation**: Darwin notifications cannot carry data - use as signals only, store data in App Groups.

---

## Return to Previous App

From [Wispr Flow FAQ](https://docs.wisprflow.ai/iphone/faq):
> "Not all apps allow Flow to reopen the app after you turn on Flow. In those cases, you can swipe back on the bottom of the screen or press the return arrow in the top left."

### Our Approach

1. **Store URL schemes** for pre-configured apps (from AppLibrary.swift)
2. **Open URL scheme** after starting session: `UIApplication.shared.open(URL(string: "googlegmail://")!)`
3. **Fallback**: iOS shows "< Back to SwiftSpeak" button in status bar

### URL Schemes for Common Apps

Already in `AppLibrary.swift`:
- Gmail: `googlegmail://`
- Messages: `sms://`
- WhatsApp: `whatsapp://`
- Notes: `mobilenotes://`
- Slack: `slack://`
- Telegram: `telegram://`
- etc.

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `Services/SwiftLink/SwiftLinkSessionManager.swift` | Background audio session, circular buffer |
| `Services/SwiftLink/DarwinNotificationManager.swift` | IPC notifications |
| `Views/Settings/SwiftLinkSetupView.swift` | Configure apps, session duration |
| `Views/SwiftLink/SwiftLinkStartView.swift` | Modal for starting session |
| `SwiftSpeakWidgets/SwiftLinkLiveActivity.swift` | Dynamic Island, Lock Screen |

### Modified Files

| File | Changes |
|------|---------|
| `Info.plist` | Add `UIBackgroundModes: audio` |
| `SwiftSpeak.entitlements` | Add background audio capability |
| `SharedSettings.swift` | Add SwiftLink apps storage |
| `Constants.swift` | Add SwiftLink keys |
| `KeyboardView.swift` | Check session, record inline |
| `ContentView.swift` | Handle `swiftspeak://swiftlink` URL |
| `SwiftSpeakApp.swift` | URL scheme handling |

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Add background audio entitlements
- [ ] Create SwiftLinkSessionManager (continuous recording)
- [ ] Create DarwinNotificationManager
- [ ] Add SwiftLink storage to SharedSettings

### Phase 2: UI
- [ ] Create SwiftLinkSetupView (Settings)
- [ ] Create SwiftLinkStartView (modal)
- [ ] Add SwiftLink section to SettingsView

### Phase 3: Keyboard Integration
- [ ] Modify KeyboardView to check session
- [ ] Add inline recording UI to keyboard
- [ ] Handle dictation start/stop via Darwin notifications
- [ ] Poll for results and insert text

### Phase 4: Session Management
- [ ] URL scheme handling for starting session
- [ ] Auto-return to target app
- [ ] Session timeout handling

### Phase 5: Live Activity
- [ ] Create Widget Extension target
- [ ] SwiftLinkLiveActivity for Dynamic Island
- [ ] Lock Screen presentation
- [ ] Update from background via push

---

## Session Duration Options

From Wispr Flow:
- 5 minutes (default)
- 15 minutes
- 1 hour
- Never (until manual end)

> "Increasing this time window should not affect battery life or performance"

---

## App Store Considerations

From [Apple Developer Forums](https://developer.apple.com/forums/thread/91872):
> "Your app declares support for audio in the UIBackgroundModes key in your Info.plist but did not include features that require persistent audio."

**To pass review:**
1. Actually use background audio (continuous recording) ✅
2. Red status bar indicator when recording (iOS automatic) ✅
3. Legitimate use case (voice dictation) ✅
4. Don't abuse background mode ✅

---

## Sources

- [Apple: AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Apple: UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)
- [Apple: Audio Guidelines](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/AudioGuidelinesByAppType/AudioGuidelinesByAppType.html)
- [Apple: installTap(onBus:)](https://developer.apple.com/documentation/avfaudio/avaudionode/1387122-installtap)
- [Apple Forums: Back to previous app](https://developer.apple.com/forums/thread/126107)
- [Wispr Flow FAQs](https://docs.wisprflow.ai/articles/9206270279-faqs)
- [Nonstrict: Darwin Notifications](https://nonstrict.eu/blog/2023/darwin-notifications-app-extensions/)
- [OhMySwift: Darwin Notifications](https://ohmyswift.com/blog/2024/08/27/send-data-between-ios-apps-and-extensions-using-darwin-notifications/)
- [KeyboardKit: Host Application](https://keyboardkit.com/features/host/)
- [KeyboardKit: Navigation Back](https://keyboardkit.com/blog/2024/01/31/how-to-not-navigate-back-to-the-keyboard-from-the-app)
