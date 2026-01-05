# Phase macOS: SwiftSpeak macOS Port

> **Execution guide for macOS port.** Follow this document step-by-step.
> Master project documentation: `/IMPLEMENTATION_PLAN.md`

## Overview

Port SwiftSpeak iOS to macOS as a **menu bar app with floating overlay**, maximizing code sharing (~80%) through a shared framework.

**Key Decisions:**
- macOS 13+ (Ventura) minimum target
- Single Xcode project with platform targets
- Menu bar app with floating recording overlay
- Text insertion: Accessibility API first, clipboard fallback
- Global hotkey: Configurable (default Cmd+Shift+D)
- No keyboard extension needed (macOS doesn't have this architecture)

**Status:** PLANNING COMPLETE - Ready for Implementation

---

## Project Structure

```
SwiftSpeak/
├── SwiftSpeak.xcodeproj
│   ├── SwiftSpeakCore/              # SHARED FRAMEWORK (new)
│   │   ├── Services/
│   │   │   ├── Providers/           # All cloud providers (100% shared)
│   │   │   ├── Network/             # APIClient, SSEParser, RetryPolicy
│   │   │   ├── Memory/              # MemoryManager, Coordinator
│   │   │   ├── RAG/                 # Full RAG system
│   │   │   ├── Webhooks/            # WebhookExecutor
│   │   │   ├── Security/            # Keychain, PromptSanitizer
│   │   │   ├── Remote/              # RemoteConfig, CostCalculator
│   │   │   └── Protocols/           # Platform abstractions
│   │   ├── Models/                  # All data models
│   │   ├── Orchestration/           # TranscriptionOrchestrator, PowerModeOrchestrator
│   │   └── Utilities/               # Constants, Theme, Logging
│   │
│   ├── SwiftSpeakiOS/               # iOS App (existing, refactored)
│   ├── SwiftSpeakKeyboard/          # iOS Keyboard Extension (unchanged)
│   │
│   └── SwiftSpeakMac/               # macOS App (NEW)
│       ├── Platform/
│       │   ├── MacAudioRecorder.swift         # AVAudioEngine recording
│       │   ├── MacTextInsertionService.swift  # AXUIElement + clipboard
│       │   ├── MacHotkeyManager.swift         # Global hotkeys
│       │   ├── MacPermissionManager.swift     # Mic + Accessibility
│       │   └── MacBiometricAuth.swift         # Touch ID
│       ├── Views/
│       │   ├── MenuBarController.swift        # NSStatusItem
│       │   ├── FloatingOverlayWindow.swift    # NSPanel recording UI
│       │   ├── RecordingOverlayView.swift     # SwiftUI overlay
│       │   ├── SettingsWindow.swift           # Preferences
│       │   └── SettingsView.swift             # SwiftUI settings
│       └── Providers/Local/
│           ├── WhisperKitMacService.swift
│           └── MacTranslationService.swift
```

---

## Platform Abstraction Protocols

### New Protocols for SwiftSpeakCore

```swift
// TextInsertionProtocol.swift - macOS text field integration
public enum TextInsertionResult {
    case accessibilitySuccess
    case clipboardFallback
    case failed(Error)
}

@MainActor
public protocol TextInsertionProtocol {
    var isAccessibilityAvailable: Bool { get }
    func insertText(_ text: String, replaceSelection: Bool) async -> TextInsertionResult
    func getSelectedText() async -> String?
    func replaceAllText(with text: String) async -> TextInsertionResult
}

// HotkeyManagerProtocol.swift - macOS global hotkeys
public enum HotkeyAction: String, CaseIterable {
    case startRecording, stopRecording, toggleRecording, openSettings, showOverlay
}

public struct HotkeyCombination: Codable, Equatable {
    public let keyCode: UInt16
    public let modifiers: UInt
    public let displayString: String  // e.g., "Cmd+Shift+D"
}

@MainActor
public protocol HotkeyManagerProtocol: ObservableObject {
    var registeredHotkeys: [HotkeyAction: HotkeyCombination] { get }
    func registerHotkey(_ combo: HotkeyCombination, for action: HotkeyAction) throws
    func unregisterHotkey(for action: HotkeyAction)
    func setHandler(_ handler: @escaping (HotkeyAction) -> Void)
}

// PermissionManagerProtocol.swift - Cross-platform permissions
public enum PermissionType {
    case microphone
    case accessibility      // macOS only
}

public enum PermissionStatus {
    case authorized, denied, notDetermined, restricted
}

@MainActor
public protocol PermissionManagerProtocol: ObservableObject {
    func checkPermission(_ type: PermissionType) -> PermissionStatus
    func requestPermission(_ type: PermissionType) async -> Bool
    func openSystemPreferences(for type: PermissionType)
}
```

---

## Phase macOS-1: Framework Setup

**Effort:** 2-3 days
**Status:** [ ] Not Started

### Goals
- Extract shared code into SwiftSpeakCore framework
- Verify iOS app works unchanged with framework

### Tasks

- [ ] Create SwiftSpeakCore framework target in Xcode
- [ ] Move to framework - Services:
  - [ ] `Services/Providers/` (all cloud providers)
  - [ ] `Services/Network/` (APIClient, SSEParser, RetryPolicy)
  - [ ] `Services/Memory/` (MemoryManager, Coordinator, Scheduler)
  - [ ] `Services/RAG/` (full RAG system)
  - [ ] `Services/Webhooks/` (WebhookExecutor, CircuitBreaker)
  - [ ] `Services/Security/` (KeychainManager, PromptSanitizer)
  - [ ] `Services/Remote/` (RemoteConfigManager, CostCalculator)
- [ ] Move to framework - Models:
  - [ ] `Shared/Models/` (all data models)
  - [ ] `Shared/Constants.swift`
- [ ] Move to framework - Orchestration:
  - [ ] `Services/Orchestration/TranscriptionOrchestrator.swift`
  - [ ] `Services/Orchestration/PowerModeOrchestrator.swift`
  - [ ] `Services/Orchestration/PromptContext.swift`
- [ ] Define platform abstraction protocols:
  - [ ] `TextInsertionProtocol.swift`
  - [ ] `HotkeyManagerProtocol.swift`
  - [ ] `PermissionManagerProtocol.swift`
- [ ] Refactor for cross-platform:
  - [ ] Remove `import UIKit` from orchestrators
  - [ ] Replace `UIPasteboard` with protocol-based clipboard
  - [ ] Add conditional compilation for haptics in Theme.swift
- [ ] Update iOS app to import SwiftSpeakCore
- [ ] Verify iOS app builds and runs correctly

### Files Modified

| File | Changes |
|------|---------|
| `SwiftSpeak.xcodeproj` | Add SwiftSpeakCore framework target |
| `TranscriptionOrchestrator.swift` | Remove UIKit, use clipboard protocol |
| `PowerModeOrchestrator.swift` | Remove UIKit, use clipboard protocol |
| `Theme.swift` | `#if os(iOS)` for haptics |
| `SharedSettings.swift` | Ensure cross-platform compatibility |

---

## Phase macOS-2: macOS App Shell

**Effort:** 3-4 days
**Status:** [ ] Not Started

### Goals
- Basic menu bar app that can record and transcribe
- Floating overlay window for recording UI

### Tasks

- [ ] Create SwiftSpeakMac app target (App Sandbox enabled)
- [ ] Implement `MacAudioRecorder`:
  - [ ] AVAudioEngine setup
  - [ ] 16kHz mono AAC output (Whisper-optimized)
  - [ ] Real-time audio levels for waveform
  - [ ] Recording duration tracking
- [ ] Implement `MacPermissionManager`:
  - [ ] Microphone permission via AVCaptureDevice
  - [ ] Permission status checking
- [ ] Implement `MenuBarController`:
  - [ ] NSStatusItem with waveform icon
  - [ ] Dropdown menu (Record, Settings, Quit)
  - [ ] Icon turns red when recording
- [ ] Create `FloatingOverlayWindow`:
  - [ ] NSPanel with HUD style
  - [ ] Always on top, draggable
  - [ ] Appears near cursor or center screen
- [ ] Create `RecordingOverlayView` (SwiftUI):
  - [ ] Waveform visualization
  - [ ] Recording timer
  - [ ] Stop button
  - [ ] Status text
- [ ] Wire basic flow:
  - [ ] Click menu → Show overlay → Record → Transcribe → Copy to clipboard

### New Files

| File | Purpose |
|------|---------|
| `SwiftSpeakMac/SwiftSpeakMacApp.swift` | @main entry point |
| `SwiftSpeakMac/Platform/MacAudioRecorder.swift` | AVAudioEngine recording |
| `SwiftSpeakMac/Platform/MacPermissionManager.swift` | Mic permission |
| `SwiftSpeakMac/Views/MenuBarController.swift` | NSStatusItem menu bar |
| `SwiftSpeakMac/Views/FloatingOverlayWindow.swift` | NSPanel wrapper |
| `SwiftSpeakMac/Views/RecordingOverlayView.swift` | SwiftUI recording UI |

### Verification
- [ ] Menu bar icon appears
- [ ] Clicking icon shows menu
- [ ] "Record" opens floating overlay
- [ ] Recording captures audio
- [ ] Transcription returns text
- [ ] Text copied to clipboard

---

## Phase macOS-3: Text Insertion

**Effort:** 3-4 days
**Status:** [ ] Not Started

### Goals
- Insert text directly into focused text fields
- Fallback to clipboard when accessibility unavailable

### Tasks

- [ ] Implement `MacTextInsertionService`:
  - [ ] Check `AXIsProcessTrusted()` for accessibility
  - [ ] Get focused element via `AXUIElementCreateSystemWide()`
  - [ ] Get focused app → focused UI element
  - [ ] Insert via `kAXSelectedTextAttribute` (replace selection)
  - [ ] Insert via `kAXValueAttribute` (full text)
  - [ ] Clipboard fallback with notification
- [ ] Create `AccessibilityPermissionView`:
  - [ ] Explain why accessibility is needed
  - [ ] "Open System Preferences" button
  - [ ] Show when permission denied
- [ ] Implement edit mode:
  - [ ] `getSelectedText()` from focused field
  - [ ] Show "Edit" option when text exists
  - [ ] `replaceAllText()` for edit results
- [ ] Update overlay UI:
  - [ ] Show insertion method used (Accessibility/Clipboard)
  - [ ] "Copied to clipboard - press Cmd+V" for fallback
- [ ] Test with major apps

### New Files

| File | Purpose |
|------|---------|
| `SwiftSpeakMac/Platform/MacTextInsertionService.swift` | AXUIElement text insertion |
| `SwiftSpeakMac/Views/AccessibilityPermissionView.swift` | Permission onboarding |

### App Compatibility Testing

| App | Status | Notes |
|-----|--------|-------|
| Safari | [ ] | |
| Chrome | [ ] | |
| Firefox | [ ] | |
| VS Code | [ ] | |
| Xcode | [ ] | |
| TextEdit | [ ] | |
| Notes | [ ] | |
| Mail | [ ] | |
| Slack | [ ] | |
| Discord | [ ] | |
| Messages | [ ] | |
| Notion | [ ] | |

---

## Phase macOS-4: Full Transcription Features

**Effort:** 3-4 days
**Status:** [ ] Not Started

### Goals
- Complete transcription workflow with formatting
- Settings window for configuration

### Tasks

- [ ] Port full TranscriptionOrchestrator features:
  - [ ] All formatting modes (Raw, Email, Formal, Casual, etc.)
  - [ ] Custom templates
  - [ ] Translation
  - [ ] Vocabulary replacements
- [ ] Update overlay UI:
  - [ ] Mode selector dropdown
  - [ ] Translation toggle + language picker
  - [ ] Context indicator
- [ ] Create Settings window:
  - [ ] NSWindow with SwiftUI content
  - [ ] Sidebar navigation (macOS style)
  - [ ] Provider configuration
  - [ ] API key management
  - [ ] Default modes
- [ ] Port history view:
  - [ ] List of transcriptions
  - [ ] Cost tracking
  - [ ] Search/filter

### New Files

| File | Purpose |
|------|---------|
| `SwiftSpeakMac/Views/SettingsWindow.swift` | NSWindow wrapper |
| `SwiftSpeakMac/Views/SettingsView.swift` | SwiftUI settings (sidebar) |
| `SwiftSpeakMac/Views/HistoryView.swift` | Transcription history |
| `SwiftSpeakMac/Views/ProviderSettingsView.swift` | API key config |

---

## Phase macOS-5: Power Mode

**Effort:** 4-5 days
**Status:** [ ] Not Started

### Goals
- Full Power Mode with RAG and webhooks
- Streaming responses in overlay

### Tasks

- [ ] Port PowerModeOrchestrator:
  - [ ] Recording → Transcription → LLM → Result
  - [ ] Streaming responses
  - [ ] Question/answer flow
- [ ] Create Power Mode execution UI:
  - [ ] Larger overlay window for results
  - [ ] Streaming text display (markdown)
  - [ ] Question prompts
  - [ ] Copy/insert result buttons
- [ ] Enable RAG system:
  - [ ] Document picker in settings
  - [ ] Vector store per Power Mode
  - [ ] Chunk retrieval during execution
- [ ] Enable webhooks:
  - [ ] Context sources (GET before)
  - [ ] Output destinations (POST after)
  - [ ] Webhook editor in settings
- [ ] Port contexts:
  - [ ] Context selector in overlay
  - [ ] Context editor in settings
- [ ] Port memory system:
  - [ ] Global, context, power mode memories
  - [ ] Memory editor in settings

### New Files

| File | Purpose |
|------|---------|
| `SwiftSpeakMac/Views/PowerModeOverlayView.swift` | Large result window |
| `SwiftSpeakMac/Views/PowerModeListView.swift` | Power Mode browser |
| `SwiftSpeakMac/Views/ContextsView.swift` | Context management |
| `SwiftSpeakMac/Views/MemoryView.swift` | Memory management |

---

## Phase macOS-6: Global Hotkeys & Polish

**Effort:** 3-4 days
**Status:** [ ] Not Started

### Goals
- Global keyboard shortcuts
- Local AI providers
- Touch ID authentication

### Tasks

- [ ] Implement `MacHotkeyManager`:
  - [ ] Carbon Events API for global hotkeys
  - [ ] `RegisterEventHotKey` / `UnregisterEventHotKey`
  - [ ] Default: Cmd+Shift+D to toggle recording
- [ ] Create hotkey configuration UI:
  - [ ] Record new hotkey combination
  - [ ] Display current hotkey
  - [ ] Conflict detection
- [ ] Implement local providers:
  - [ ] WhisperKit for macOS (if compatible)
  - [ ] Apple Translation (macOS 14+ only)
  - [ ] Graceful fallback to cloud
- [ ] Implement Touch ID:
  - [ ] LAContext (same as iOS)
  - [ ] Protect settings access
  - [ ] Session timeout
- [ ] Port subscription integration:
  - [ ] RevenueCat for Mac App Store
  - [ ] Feature gating by tier
- [ ] UI polish:
  - [ ] macOS-native styling
  - [ ] Dark mode support
  - [ ] Animations

### New Files

| File | Purpose |
|------|---------|
| `SwiftSpeakMac/Platform/MacHotkeyManager.swift` | Carbon global hotkeys |
| `SwiftSpeakMac/Platform/MacBiometricAuth.swift` | Touch ID via LAContext |
| `SwiftSpeakMac/Views/HotkeySettingsView.swift` | Hotkey configuration UI |
| `SwiftSpeakMac/Providers/Local/WhisperKitMacService.swift` | Local transcription |
| `SwiftSpeakMac/Providers/Local/MacTranslationService.swift` | Apple Translation |

---

## Phase macOS-7: Testing & Release

**Effort:** 3-4 days
**Status:** [ ] Not Started

### Goals
- Production quality
- App Store submission

### Tasks

- [ ] Test across macOS versions:
  - [ ] macOS 13 (Ventura) - minimum
  - [ ] macOS 14 (Sonoma)
  - [ ] macOS 15 (Sequoia)
- [ ] Accessibility testing:
  - [ ] VoiceOver compatibility
  - [ ] Keyboard navigation
- [ ] Performance testing:
  - [ ] Memory profiling
  - [ ] CPU usage during recording
  - [ ] Launch time
- [ ] App Store preparation:
  - [ ] Screenshots (menu bar, overlay, settings)
  - [ ] App description
  - [ ] Privacy policy update
  - [ ] Entitlements review
- [ ] Beta testing:
  - [ ] TestFlight distribution
  - [ ] Collect feedback
- [ ] App Store submission

---

## macOS Version Compatibility

| Feature | macOS 13 | macOS 14+ |
|---------|----------|-----------|
| Core transcription | ✅ | ✅ |
| All cloud providers | ✅ | ✅ |
| Power Mode + RAG | ✅ | ✅ |
| Text insertion | ✅ | ✅ |
| Global hotkeys | ✅ | ✅ |
| Touch ID | ✅ | ✅ |
| Apple Translation | ❌ (cloud fallback) | ✅ |
| WhisperKit | ⚠️ (TBD) | ⚠️ (TBD) |

---

## Code Sharing Summary

| Component | Shareability | Notes |
|-----------|--------------|-------|
| Cloud Providers (9) | 100% | No changes needed |
| Network Layer | 100% | No changes needed |
| Data Models | 100% | No changes needed |
| RAG System | 100% | PDFKit works on both |
| Memory System | 100% | No changes needed |
| Webhooks | 100% | No changes needed |
| Keychain | 100% | Security framework shared |
| Remote Config | 100% | Firebase works on both |
| Orchestrators | 95% | Remove UIKit imports |
| Audio Recording | 30% | Different APIs (AVAudioSession vs AVAudioEngine) |
| UI Layer | 20% | Platform-specific (menu bar vs keyboard) |

**Overall: ~80% code shared between iOS and macOS**

---

## Effort Summary

| Phase | Dev Days | Description |
|-------|----------|-------------|
| macOS-1: Framework Setup | 2-3 | Extract shared code |
| macOS-2: macOS App Shell | 3-4 | Menu bar + recording |
| macOS-3: Text Insertion | 3-4 | Accessibility API |
| macOS-4: Full Transcription | 3-4 | Formatting, translation |
| macOS-5: Power Mode | 4-5 | RAG, webhooks, memory |
| macOS-6: Hotkeys & Polish | 3-4 | Global hotkeys, local AI |
| macOS-7: Testing & Release | 3-4 | QA, App Store |
| **Total** | **21-28** | **5-7 weeks full-time** |

---

## Quick Start Checklist

First steps to begin implementation:

1. [ ] Create `SwiftSpeakCore` framework target in Xcode
2. [ ] Move `Services/Providers/` to framework
3. [ ] Move `Shared/Models/` to framework
4. [ ] Move `Services/Network/` to framework
5. [ ] Define `TextInsertionProtocol` in framework
6. [ ] Create `SwiftSpeakMac` app target
7. [ ] Implement basic `MenuBarController`
8. [ ] Implement `MacAudioRecorder`
9. [ ] Test basic record → transcribe → clipboard flow

---

## Testing Strategy

### Cross-Platform Testing Benefits

Testing on macOS gives high confidence for iOS because the shared framework code is identical:

| Component | macOS Test Confidence → iOS |
|-----------|----------------------------|
| All 9 Cloud Providers | 100% - Same HTTP, same JSON |
| Network Layer | 100% - URLSession identical |
| Data Models | 100% - Pure Swift Codable |
| RAG System | 100% - Pure Swift |
| Memory System | 100% - Pure Swift |
| Webhooks | 100% - HTTP calls identical |
| Keychain | 100% - Security framework same |
| Orchestration Logic | 100% - State machine, retry |
| Prompt Building | 100% - Pure Swift |
| Cost Calculation | 100% - Pure Swift |

**~80% of code is shared** - if it works on macOS, it works on iOS.

### Platform-Specific Testing (Separate)

| Component | macOS | iOS |
|-----------|-------|-----|
| Audio Recording | AVAudioEngine | AVAudioSession |
| Text Insertion | Accessibility API | UITextDocumentProxy |
| UI Layer | Menu bar + NSPanel | Keyboard extension |

### Recommended Workflow

1. **Develop shared code on macOS** - Faster iteration, no device needed
2. **Run unit tests on both platforms** - Framework tests pass on both
3. **Debug provider issues on macOS first** - Easier debugging
4. **Verify iOS integration** - Only for platform-specific code

---

## Detailed Implementation Code

### MacAudioRecorder.swift (Full Implementation)

```swift
// SwiftSpeakMac/Platform/MacAudioRecorder.swift

import AVFoundation
import Combine
import SwiftSpeakCore

@MainActor
final class MacAudioRecorder: NSObject, AudioRecorderProtocol, ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var isRecording = false
    @Published private(set) var currentLevel: Float = 0.0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var error: TranscriptionError?

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var durationTimer: Timer?
    private var startTime: Date?

    var recordingFileSize: Int? {
        guard let url = recordingURL else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
    }

    // MARK: - Public Methods

    func startRecording() async throws {
        // Check microphone permission
        guard await checkMicrophonePermission() else {
            throw TranscriptionError.microphonePermissionDenied
        }

        // Create temporary file URL
        let url = createTemporaryURL()

        // Setup audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Recording settings (16kHz mono for Whisper)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create output file
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: settings)
        } catch {
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        // Install tap for audio data
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // Start engine
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw TranscriptionError.recordingFailed(error.localizedDescription)
        }

        // Update state
        self.audioEngine = engine
        self.recordingURL = url
        self.isRecording = true
        self.startTime = Date()
        self.error = nil

        // Start duration timer
        startDurationTimer()
    }

    @discardableResult
    func stopRecording() throws -> URL {
        stopDurationTimer()

        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Close audio file
        audioFile = nil

        // Validate recording
        guard let url = recordingURL else {
            throw TranscriptionError.noAudioRecorded
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.noAudioRecorded
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        if fileSize < 1000 {
            throw TranscriptionError.audioTooShort
        }

        // Reset state
        isRecording = false
        currentLevel = 0

        return url
    }

    func cancelRecording() {
        stopDurationTimer()

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordingURL = nil
        isRecording = false
        currentLevel = 0
        duration = 0
    }

    func deleteRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }

    // MARK: - Private Methods

    private func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Calculate audio level for waveform
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let average = sum / Float(max(frameLength, 1))

        // Update level on main thread
        Task { @MainActor in
            self.currentLevel = min(1.0, average * 10)
        }

        // Write to file (format conversion happens automatically)
        if let file = audioFile {
            do {
                try file.write(from: buffer)
            } catch {
                Task { @MainActor in
                    self.error = .recordingFailed(error.localizedDescription)
                }
            }
        }
    }

    private func createTemporaryURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "swiftspeak_mac_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(filename)
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            Task { @MainActor in
                self.duration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
```

### MacTextInsertionService.swift (Full Implementation)

```swift
// SwiftSpeakMac/Platform/MacTextInsertionService.swift

import AppKit
import ApplicationServices
import SwiftSpeakCore

@MainActor
final class MacTextInsertionService: TextInsertionProtocol {

    // MARK: - Properties

    var isAccessibilityAvailable: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Public Methods

    func insertText(_ text: String, replaceSelection: Bool) async -> TextInsertionResult {
        // Try accessibility first
        if isAccessibilityAvailable {
            do {
                try insertViaAccessibility(text, replaceSelection: replaceSelection)
                return .accessibilitySuccess
            } catch {
                // Fall through to clipboard
            }
        }

        // Fallback to clipboard
        return copyToClipboard(text)
    }

    func getSelectedText() async -> String? {
        guard isAccessibilityAvailable else { return nil }
        guard let element = getFocusedElement() else { return nil }

        var selectedText: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard result == .success, let text = selectedText as? String else {
            return nil
        }

        return text.isEmpty ? nil : text
    }

    func replaceAllText(with text: String) async -> TextInsertionResult {
        if isAccessibilityAvailable {
            do {
                try replaceAllViaAccessibility(text)
                return .accessibilitySuccess
            } catch {
                // Fall through
            }
        }
        return copyToClipboard(text)
    }

    /// Request accessibility permission (opens System Preferences)
    func requestAccessibilityPermission() {
        // Prompt the system to show accessibility dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Open System Preferences to Accessibility pane
    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Methods

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused application
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success else {
            return nil
        }

        // Get focused UI element within that app
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focusedApp as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else {
            return nil
        }

        return focusedElement as? AXUIElement
    }

    private func insertViaAccessibility(_ text: String, replaceSelection: Bool) throws {
        guard let element = getFocusedElement() else {
            throw TextInsertionError.noFocusedElement
        }

        // Check if element is editable
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        let editableRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        guard let roleString = role as? String, editableRoles.contains(roleString) else {
            throw TextInsertionError.elementNotEditable
        }

        // Check if element is enabled
        var enabled: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled)
        if let isEnabled = enabled as? Bool, !isEnabled {
            throw TextInsertionError.elementNotEditable
        }

        if replaceSelection {
            // Replace selected text only
            let result = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextAttribute as CFString,
                text as CFString
            )
            guard result == .success else {
                throw TextInsertionError.insertionFailed
            }
        } else {
            // Get current value and cursor position for proper insertion
            var currentValue: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

            var selectedRange: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)

            if let range = selectedRange, let currentText = currentValue as? String {
                // Insert at cursor position
                var cfRange = CFRange()
                AXValueGetValue(range as! AXValue, .cfRange, &cfRange)

                let location = cfRange.location
                let prefix = String(currentText.prefix(location))
                let suffix = String(currentText.dropFirst(location + cfRange.length))
                let newValue = prefix + text + suffix

                let result = AXUIElementSetAttributeValue(
                    element,
                    kAXValueAttribute as CFString,
                    newValue as CFString
                )
                guard result == .success else {
                    throw TextInsertionError.insertionFailed
                }
            } else {
                // Fallback: append to end
                let result = AXUIElementSetAttributeValue(
                    element,
                    kAXValueAttribute as CFString,
                    text as CFString
                )
                guard result == .success else {
                    throw TextInsertionError.insertionFailed
                }
            }
        }
    }

    private func replaceAllViaAccessibility(_ text: String) throws {
        guard let element = getFocusedElement() else {
            throw TextInsertionError.noFocusedElement
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFString
        )

        guard result == .success else {
            throw TextInsertionError.insertionFailed
        }
    }

    private func copyToClipboard(_ text: String) -> TextInsertionResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return .clipboardFallback
    }
}

// MARK: - Errors

enum TextInsertionError: LocalizedError {
    case noFocusedElement
    case elementNotEditable
    case insertionFailed

    var errorDescription: String? {
        switch self {
        case .noFocusedElement:
            return "No text field is currently focused."
        case .elementNotEditable:
            return "The focused element does not accept text input."
        case .insertionFailed:
            return "Failed to insert text into the focused element."
        }
    }
}
```

### MenuBarController.swift (Full Implementation)

```swift
// SwiftSpeakMac/Views/MenuBarController.swift

import AppKit
import SwiftUI
import Combine
import SwiftSpeakCore

@MainActor
final class MenuBarController: ObservableObject {

    // MARK: - Published State
    @Published var isRecording = false
    @Published var isOverlayVisible = false
    @Published var currentMode: FormattingMode = .raw

    // MARK: - Private Properties
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var floatingWindow: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Dependencies
    private let orchestrator: TranscriptionOrchestrator
    private let audioRecorder: MacAudioRecorder
    private let textInsertion: MacTextInsertionService

    init(orchestrator: TranscriptionOrchestrator,
         audioRecorder: MacAudioRecorder,
         textInsertion: MacTextInsertionService) {
        self.orchestrator = orchestrator
        self.audioRecorder = audioRecorder
        self.textInsertion = textInsertion
    }

    // MARK: - Setup

    func setup() {
        createStatusItem()
        createMenu()
        createFloatingWindow()
        setupBindings()
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.circle",
                                   accessibilityDescription: "SwiftSpeak")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func createMenu() {
        menu = NSMenu()

        // Record item
        let recordItem = NSMenuItem(title: "Start Recording",
                                    action: #selector(toggleRecording),
                                    keyEquivalent: "")
        recordItem.target = self
        menu?.addItem(recordItem)

        menu?.addItem(.separator())

        // Mode submenu
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeSubmenu = NSMenu()
        for mode in FormattingMode.allCases {
            let item = NSMenuItem(title: mode.displayName,
                                  action: #selector(selectMode(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            modeSubmenu.addItem(item)
        }
        modeItem.submenu = modeSubmenu
        menu?.addItem(modeItem)

        menu?.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit SwiftSpeak",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    private func createFloatingWindow() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 180),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .utilityWindow

        // Set SwiftUI content
        let overlayView = RecordingOverlayView(
            audioRecorder: audioRecorder,
            onStop: { [weak self] in
                Task { await self?.stopRecordingAndProcess() }
            },
            onCancel: { [weak self] in
                self?.cancelRecording()
            }
        )
        window.contentView = NSHostingView(rootView: overlayView)

        floatingWindow = window
    }

    private func setupBindings() {
        // Update menu bar icon based on recording state
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                self?.updateStatusIcon(isRecording: recording)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click shows menu
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Left click toggles recording
            toggleRecording()
        }
    }

    @objc private func toggleRecording() {
        if audioRecorder.isRecording {
            Task { await stopRecordingAndProcess() }
        } else {
            Task { await startRecording() }
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? FormattingMode {
            currentMode = mode
        }
    }

    @objc private func openSettings() {
        // Open settings window
        NSApp.activate(ignoringOtherApps: true)
        // TODO: Show settings window
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Recording Flow

    func startRecording() async {
        showOverlay()

        do {
            try await audioRecorder.startRecording()
        } catch {
            hideOverlay()
            showNotification(title: "Recording Failed", body: error.localizedDescription)
        }
    }

    func stopRecordingAndProcess() async {
        do {
            let audioURL = try audioRecorder.stopRecording()

            // Process transcription
            let result = try await orchestrator.transcribe(
                audioURL: audioURL,
                mode: currentMode,
                translate: false,
                targetLanguage: nil
            )

            // Insert text
            let insertResult = await textInsertion.insertText(result, replaceSelection: true)

            switch insertResult {
            case .accessibilitySuccess:
                showNotification(title: "Text Inserted", body: "")
            case .clipboardFallback:
                showNotification(title: "Copied to Clipboard", body: "Press Cmd+V to paste")
            case .failed(let error):
                showNotification(title: "Insertion Failed", body: error.localizedDescription)
            }

        } catch {
            showNotification(title: "Transcription Failed", body: error.localizedDescription)
        }

        hideOverlay()
    }

    func cancelRecording() {
        audioRecorder.cancelRecording()
        hideOverlay()
    }

    // MARK: - UI Helpers

    func showOverlay() {
        guard let window = floatingWindow else { return }

        // Position near mouse or center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame

            // Center on screen
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        isOverlayVisible = true
    }

    func hideOverlay() {
        floatingWindow?.orderOut(nil)
        isOverlayVisible = false
    }

    private func updateStatusIcon(isRecording: Bool) {
        let iconName = isRecording ? "waveform.circle.fill" : "waveform.circle"
        statusItem?.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: "SwiftSpeak"
        )
        statusItem?.button?.contentTintColor = isRecording ? .systemRed : nil
    }

    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        NSUserNotificationCenter.default.deliver(notification)
    }
}
```

### MacHotkeyManager.swift (Full Implementation)

```swift
// SwiftSpeakMac/Platform/MacHotkeyManager.swift

import Carbon
import AppKit
import SwiftSpeakCore

@MainActor
final class MacHotkeyManager: HotkeyManagerProtocol, ObservableObject {

    @Published private(set) var registeredHotkeys: [HotkeyAction: HotkeyCombination] = [:]

    private var eventHandler: ((HotkeyAction) -> Void)?
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var hotkeyActions: [UInt32: HotkeyAction] = [:]
    private var nextHotkeyId: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    // MARK: - Initialization

    init() {
        installEventHandler()
    }

    deinit {
        // Unregister all hotkeys
        for ref in hotkeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        // Remove event handler
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    // MARK: - Public Methods

    func registerHotkey(_ combination: HotkeyCombination, for action: HotkeyAction) throws {
        // Unregister existing hotkey for this action
        unregisterHotkey(for: action)

        let hotkeyId = nextHotkeyId
        nextHotkeyId += 1

        var hotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x5353_504B), // "SSPK"
            id: hotkeyId
        )

        let modifiers = carbonModifiers(from: combination.modifiers)

        let status = RegisterEventHotKey(
            UInt32(combination.keyCode),
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            throw HotkeyError.registrationFailed
        }

        hotkeyRefs[hotkeyId] = ref
        hotkeyActions[hotkeyId] = action
        registeredHotkeys[action] = combination
    }

    func unregisterHotkey(for action: HotkeyAction) {
        guard registeredHotkeys[action] != nil else { return }

        for (id, registeredAction) in hotkeyActions where registeredAction == action {
            if let ref = hotkeyRefs[id] {
                UnregisterEventHotKey(ref)
            }
            hotkeyRefs.removeValue(forKey: id)
            hotkeyActions.removeValue(forKey: id)
        }

        registeredHotkeys.removeValue(forKey: action)
    }

    func setHandler(_ handler: @escaping (HotkeyAction) -> Void) {
        self.eventHandler = handler
    }

    // MARK: - Default Hotkeys

    func registerDefaultHotkeys() throws {
        // Default: Cmd+Shift+D for toggle recording
        let defaultCombination = HotkeyCombination(
            keyCode: 0x02, // 'd' key
            modifiers: UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue),
            displayString: "⌘⇧D"
        )

        try registerHotkey(defaultCombination, for: .toggleRecording)
    }

    // MARK: - Private Methods

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Store self pointer for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return status }

            // Dispatch to main actor
            let manager = Unmanaged<MacHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            Task { @MainActor in
                if let action = manager.hotkeyActions[hotKeyID.id] {
                    manager.eventHandler?(action)
                }
            }

            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )

        self.eventHandlerRef = handlerRef
    }

    private func carbonModifiers(from modifiers: UInt) -> UInt32 {
        var result: UInt32 = 0

        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 {
            result |= UInt32(cmdKey)
        }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 {
            result |= UInt32(optionKey)
        }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 {
            result |= UInt32(controlKey)
        }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 {
            result |= UInt32(shiftKey)
        }

        return result
    }
}

// MARK: - Hotkey Combination Helpers

extension HotkeyCombination {
    /// Create from NSEvent
    static func from(event: NSEvent) -> HotkeyCombination {
        HotkeyCombination(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags.rawValue,
            displayString: event.modifierFlags.description + (event.charactersIgnoringModifiers?.uppercased() ?? "")
        )
    }
}

enum HotkeyError: LocalizedError {
    case registrationFailed
    case alreadyRegistered
    case invalidCombination

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Failed to register hotkey. It may be in use by another application."
        case .alreadyRegistered:
            return "This hotkey is already registered."
        case .invalidCombination:
            return "Invalid key combination."
        }
    }
}
```

---

## Current iOS Files Reference

### Files to Move to SwiftSpeakCore (Shared)

```
SwiftSpeak/SwiftSpeak/Services/
├── Providers/
│   ├── OpenAI/
│   │   ├── OpenAITranscriptionService.swift
│   │   ├── OpenAIFormattingService.swift
│   │   ├── OpenAITranslationService.swift
│   │   └── OpenAIStreamingService.swift
│   ├── Anthropic/AnthropicService.swift
│   ├── Google/
│   │   ├── GeminiService.swift
│   │   ├── GoogleSTTService.swift
│   │   └── GoogleTranslationService.swift
│   ├── AssemblyAI/AssemblyAITranscriptionService.swift
│   ├── Deepgram/DeepgramTranscriptionService.swift
│   ├── DeepL/DeepLTranslationService.swift
│   ├── Azure/AzureTranslatorService.swift
│   ├── TokenCounter.swift
│   └── ProviderHealthTracker.swift
├── Network/
│   ├── APIClient.swift
│   ├── SSEParser.swift
│   └── RetryPolicy.swift
├── Memory/
│   ├── MemoryManager.swift
│   ├── MemoryUpdateCoordinator.swift
│   └── MemoryUpdateScheduler.swift
├── RAG/
│   ├── RAGOrchestrator.swift
│   ├── DocumentParser.swift
│   ├── TextChunker.swift
│   ├── VectorStore.swift
│   ├── EmbeddingService.swift
│   └── RAGSecurityManager.swift
├── Webhooks/
│   ├── WebhookExecutor.swift
│   └── WebhookCircuitBreaker.swift
├── Security/
│   ├── KeychainManager.swift
│   └── PromptSanitizer.swift
├── Remote/
│   ├── RemoteConfigManager.swift
│   ├── RemoteConfig.swift
│   ├── ConfigChangeDetector.swift
│   └── CostCalculator.swift
├── Orchestration/
│   ├── TranscriptionOrchestrator.swift
│   ├── PowerModeOrchestrator.swift
│   └── PromptContext.swift
├── ProviderFactory.swift
└── TranscriptionError.swift

SwiftSpeak/SwiftSpeak/Shared/
├── Models/
│   ├── AIProvider.swift
│   ├── Language.swift
│   ├── FormattingMode.swift
│   ├── PowerMode.swift
│   ├── Context.swift
│   ├── Webhook.swift
│   ├── Cost.swift
│   ├── Processing.swift
│   ├── Transcription.swift
│   ├── Knowledge.swift
│   ├── RAG.swift
│   ├── LocalProvider.swift
│   └── ProviderSelection.swift
├── Constants.swift
├── LogSanitizer.swift
└── ProviderLanguageSupport.swift
```

### Files Remaining iOS-Only

```
SwiftSpeak/SwiftSpeak/Services/
├── Audio/
│   ├── AudioRecorder.swift         # iOS AVAudioSession
│   ├── AudioSessionManager.swift   # iOS-specific
│   └── StreamingAudioRecorder.swift
├── Providers/Local/
│   ├── WhisperKitTranscriptionService.swift
│   ├── AppleTranslationService.swift
│   ├── AppleIntelligenceFormattingService.swift
│   └── LocalTranslationManager.swift
├── Security/
│   └── BiometricAuthManager.swift  # Works on both, but may need adaptation
├── SwiftLink/
│   ├── SwiftLinkSessionManager.swift
│   └── DarwinNotificationManager.swift
├── Logging/
│   ├── Logging.swift
│   └── LogExporter.swift
└── Subscription/
    ├── SubscriptionService.swift
    └── SubscriptionError.swift

SwiftSpeak/SwiftSpeak/Views/           # All iOS views
SwiftSpeakKeyboard/                    # iOS keyboard extension only
```

---

## Entitlements & Capabilities

### SwiftSpeakMac.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
```

### Info.plist Additions

```xml
<key>NSMicrophoneUsageDescription</key>
<string>SwiftSpeak needs microphone access to transcribe your voice.</string>

<key>LSUIElement</key>
<true/>  <!-- Menu bar app, no Dock icon -->

<key>NSAppleEventsUsageDescription</key>
<string>SwiftSpeak needs accessibility access to insert text into other applications.</string>
```

---

## RevenueCat Cross-Platform Subscriptions

RevenueCat fully supports macOS with shared subscriptions across iOS and macOS:

| Feature | Support | Notes |
|---------|---------|-------|
| macOS SDK | ✅ | `Purchases` framework works identically |
| Shared Subscriptions | ✅ | Same Apple ID = same entitlements |
| Single Codebase | ✅ | `SubscriptionService.swift` unchanged |
| Universal Purchase | ✅ | Buy on iOS → unlocked on macOS |
| App Store Connect | ✅ | One app record for both platforms |

### How Cross-Platform Works

```
User buys Pro on iPhone
        │
        ↓
App Store Connect (Universal Purchase)
        │
        ↓
RevenueCat syncs entitlements
        │
        ↓
User opens SwiftSpeak on Mac (same Apple ID)
        │
        ↓
RevenueCat recognizes user → Pro unlocked on Mac
```

### Code Changes Required

**None!** The existing `SubscriptionService.swift` works on macOS:

```swift
// This code works identically on iOS and macOS
import RevenueCat

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var currentTier: SubscriptionTier = .free

    func configure(apiKey: String) async throws {
        Purchases.configure(withAPIKey: apiKey)
        // Works on both platforms
    }

    func checkEntitlements() async {
        let customerInfo = try? await Purchases.shared.customerInfo()
        // Same entitlements on iOS and macOS
        if customerInfo?.entitlements["power"]?.isActive == true {
            currentTier = .power
        } else if customerInfo?.entitlements["pro"]?.isActive == true {
            currentTier = .pro
        }
    }
}
```

### App Store Connect Setup

For Universal Purchase (recommended):
1. Create one App Record for iOS
2. Add macOS platform to same record
3. Same bundle ID prefix: `pawelgawliczek.SwiftSpeak`
4. Subscriptions automatically shared

---

## Settings Synchronization (iCloud)

Settings sync automatically across iOS and macOS with zero user configuration. If the user has an Apple ID (required to download the app), sync just works.

### Zero-Config Design

**User requirements:**
- ✅ Apple ID signed in (already required for App Store)
- ✅ iCloud enabled (default on all Apple devices)
- ❌ No additional toggles or setup screens needed

**How it works invisibly:**
```
User creates context on iPhone
        ↓
CloudKit syncs in background (user doesn't notice)
        ↓
User opens SwiftSpeak on Mac
        ↓
Context is already there ✨
```

### Storage Strategy

| Data Type | Storage | Reason |
|-----------|---------|--------|
| Simple settings | `NSUbiquitousKeyValueStore` | Fast, automatic, <1MB total |
| Contexts | CloudKit Private DB | Structured, unlimited storage |
| Power Modes | CloudKit Private DB | Structured, relationships |
| Memories (global/context/powermode) | CloudKit Private DB | Can be 2000+ chars each |
| Vocabulary | CloudKit Private DB | Can grow large |
| API Keys | Local Keychain only | Security - never sync |
| History/transcriptions | Local only | Privacy - user content |

### NSUbiquitousKeyValueStore (Simple Settings)

For lightweight preferences that sync instantly:

```swift
// SwiftSpeakCore/Services/Sync/CloudSettingsSync.swift

import Foundation

@MainActor
final class CloudSettingsSync: ObservableObject {

    private let cloudStore = NSUbiquitousKeyValueStore.default

    // Keys for synced settings
    private enum Key {
        static let defaultMode = "sync_defaultMode"
        static let defaultLanguage = "sync_defaultLanguage"
        static let translateEnabled = "sync_translateEnabled"
        static let autoReturnEnabled = "sync_autoReturnEnabled"
        static let defaultTranscriptionProvider = "sync_transcriptionProvider"
        static let defaultFormattingProvider = "sync_formattingProvider"
    }

    init() {
        startObserving()
        cloudStore.synchronize()
    }

    // MARK: - Synced Properties

    var defaultMode: String {
        get { cloudStore.string(forKey: Key.defaultMode) ?? "raw" }
        set { cloudStore.set(newValue, forKey: Key.defaultMode); cloudStore.synchronize() }
    }

    var defaultLanguage: String {
        get { cloudStore.string(forKey: Key.defaultLanguage) ?? "en" }
        set { cloudStore.set(newValue, forKey: Key.defaultLanguage); cloudStore.synchronize() }
    }

    var translateEnabled: Bool {
        get { cloudStore.bool(forKey: Key.translateEnabled) }
        set { cloudStore.set(newValue, forKey: Key.translateEnabled); cloudStore.synchronize() }
    }

    var autoReturnEnabled: Bool {
        get { cloudStore.bool(forKey: Key.autoReturnEnabled) }
        set { cloudStore.set(newValue, forKey: Key.autoReturnEnabled); cloudStore.synchronize() }
    }

    // MARK: - Observation

    private func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
    }

    @objc private func cloudStoreDidChange(_ notification: Notification) {
        // External change from other device - update UI
        objectWillChange.send()
    }
}
```

### CloudKit (Contexts, Power Modes, Memories)

For structured user content with proper relationships:

```swift
// SwiftSpeakCore/Services/Sync/CloudKitSync.swift

import CloudKit

@MainActor
final class CloudKitSync: ObservableObject {

    private let container = CKContainer(identifier: "iCloud.pawelgawliczek.SwiftSpeak")
    private lazy var privateDB = container.privateCloudDatabase

    @Published private(set) var isSyncing = false
    @Published private(set) var isAvailable = false

    // Record types
    private enum RecordType {
        static let context = "Context"
        static let powerMode = "PowerMode"
        static let memory = "Memory"
        static let vocabulary = "Vocabulary"
    }

    // MARK: - Initialization (Silent, No User Prompts)

    func initialize() async {
        // Check silently - never show error to user
        let status = try? await container.accountStatus()
        isAvailable = (status == .available)

        if isAvailable {
            await syncFromCloud()
        }
        // If not available, just work locally - no error shown
    }

    // MARK: - Contexts

    func saveContext(_ context: ConversationContext) async {
        guard isAvailable else { return }  // Silent fallback to local

        let record = CKRecord(recordType: RecordType.context,
                              recordID: CKRecord.ID(recordName: context.id.uuidString))
        record["name"] = context.name
        record["instructions"] = context.instructions
        record["icon"] = context.icon
        record["color"] = context.color
        record["memory"] = context.memory  // Up to 2000 chars - fine for CloudKit

        do {
            _ = try await privateDB.save(record)
        } catch {
            // Silent failure - local copy still works
            appLog("CloudKit save failed: \(error)", category: "Sync", level: .debug)
        }
    }

    func fetchContexts() async -> [ConversationContext] {
        guard isAvailable else { return [] }

        let query = CKQuery(recordType: RecordType.context, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await privateDB.records(matching: query)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return recordToContext(record)
            }
        } catch {
            return []  // Silent - use local data
        }
    }

    // MARK: - Power Modes (with Memories)

    func savePowerMode(_ powerMode: PowerMode) async {
        guard isAvailable else { return }

        let record = CKRecord(recordType: RecordType.powerMode,
                              recordID: CKRecord.ID(recordName: powerMode.id.uuidString))
        record["name"] = powerMode.name
        record["systemPrompt"] = powerMode.systemPrompt
        record["icon"] = powerMode.icon
        record["color"] = powerMode.color
        record["memory"] = powerMode.memory  // Power mode specific memory
        record["outputFormat"] = powerMode.outputFormat.rawValue
        record["enableQuestions"] = powerMode.enableQuestions

        _ = try? await privateDB.save(record)
    }

    // MARK: - Global Memory

    func saveGlobalMemory(_ memory: String) async {
        guard isAvailable else { return }

        let recordID = CKRecord.ID(recordName: "global_memory")
        let record = CKRecord(recordType: RecordType.memory, recordID: recordID)
        record["content"] = memory
        record["type"] = "global"

        _ = try? await privateDB.save(record)
    }

    func fetchGlobalMemory() async -> String? {
        guard isAvailable else { return nil }

        let recordID = CKRecord.ID(recordName: "global_memory")
        let record = try? await privateDB.record(for: recordID)
        return record?["content"] as? String
    }

    // MARK: - Vocabulary

    func saveVocabulary(_ entries: [VocabularyEntry]) async {
        guard isAvailable else { return }

        let records = entries.map { entry -> CKRecord in
            let record = CKRecord(recordType: RecordType.vocabulary,
                                  recordID: CKRecord.ID(recordName: entry.id.uuidString))
            record["original"] = entry.original
            record["replacement"] = entry.replacement
            record["caseSensitive"] = entry.caseSensitive
            return record
        }

        _ = try? await privateDB.modifyRecords(saving: records, deleting: [])
    }

    // MARK: - Sync All

    func syncFromCloud() async {
        isSyncing = true
        defer { isSyncing = false }

        // Fetch all data types in parallel
        async let contexts = fetchContexts()
        async let powerModes = fetchPowerModes()
        async let vocabulary = fetchVocabulary()
        async let globalMemory = fetchGlobalMemory()

        // Merge with local data (cloud wins for conflicts by timestamp)
        let (fetchedContexts, fetchedPowerModes, fetchedVocab, fetchedMemory) =
            await (contexts, powerModes, vocabulary, globalMemory)

        // Update local storage with cloud data
        await mergeWithLocal(
            contexts: fetchedContexts,
            powerModes: fetchedPowerModes,
            vocabulary: fetchedVocab,
            globalMemory: fetchedMemory
        )
    }

    // MARK: - Private Helpers

    private func recordToContext(_ record: CKRecord) -> ConversationContext? {
        guard let name = record["name"] as? String else { return nil }

        var context = ConversationContext(
            name: name,
            instructions: record["instructions"] as? String ?? ""
        )
        context.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        context.icon = record["icon"] as? String ?? "bubble.left"
        context.color = record["color"] as? String ?? "blue"
        context.memory = record["memory"] as? String ?? ""
        return context
    }

    private func fetchPowerModes() async -> [PowerMode] {
        // Similar to fetchContexts
        []
    }

    private func fetchVocabulary() async -> [VocabularyEntry] {
        // Similar pattern
        []
    }

    private func mergeWithLocal(
        contexts: [ConversationContext],
        powerModes: [PowerMode],
        vocabulary: [VocabularyEntry],
        globalMemory: String?
    ) async {
        // Merge logic: cloud timestamp > local timestamp wins
        // Implementation depends on SharedSettings structure
    }
}
```

### Entitlements Required

Add to **both** iOS and macOS entitlements:

```xml
<!-- iCloud entitlements -->
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.pawelgawliczek.SwiftSpeak</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)pawelgawliczek.SwiftSpeak</string>
```

### Edge Cases (All Silent)

| Scenario | Behavior |
|----------|----------|
| iCloud disabled | Works locally, syncs when enabled |
| No internet | Works locally, syncs when connected |
| First device | Creates cloud data |
| Second device | Fetches existing data on launch |
| Conflict (same item edited on both) | Last modified timestamp wins |
| Over quota (very rare) | Works locally, logs warning |

**No error dialogs, no setup screens, no user action required.**

### Data Privacy

| Data | Synced | Location |
|------|--------|----------|
| Preferences | ✅ | iCloud KVS (encrypted) |
| Contexts + memories | ✅ | CloudKit Private DB (encrypted) |
| Power Modes + memories | ✅ | CloudKit Private DB (encrypted) |
| Vocabulary | ✅ | CloudKit Private DB (encrypted) |
| API Keys | ❌ | Local Keychain only |
| Transcription history | ❌ | Local only |
| Audio files | ❌ | Never stored |

All synced data is encrypted at rest and in transit by Apple automatically.

---

## Notes for Implementation

1. **Start with Phase macOS-1 (Framework Setup)** - This is the foundation for everything else
2. **Test iOS app after framework extraction** - Ensure nothing breaks
3. **macOS app shell (Phase macOS-2) can be developed in parallel** once framework exists
4. **Accessibility permission is critical** - Plan for clipboard fallback from day one
5. **Global hotkeys require Carbon** - Modern alternative (CGEventTap) needs accessibility permission anyway
6. **Firebase SDK works on macOS** - Remote config should work unchanged
7. **RevenueCat supports macOS** - Subscription logic ports with ZERO changes
8. **Universal Purchase** - Users buy once, use on both iOS and macOS
