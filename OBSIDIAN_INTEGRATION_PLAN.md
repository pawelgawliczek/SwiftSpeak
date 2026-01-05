# Obsidian Vault Integration - Implementation Plan

## Overview

Enable cross-device access to multiple Obsidian vaults from SwiftSpeak. Mac indexes vaults and syncs embeddings to iCloud. iOS downloads and queries locally. Each Power Mode can select which vaults to include and define output actions.

**Key Features:**
- Multiple vaults support (separate settings section)
- Per-Power Mode vault selection
- Predefined actions (not AI-decided)
- Window context capture (macOS only)
- Iterative conversation with context preview

---

## Platform Capabilities

| Feature | macOS | iOS |
|---------|-------|-----|
| Add vault (folder picker) | ✓ | - |
| Index vault (generate embeddings) | ✓ | - |
| Sync to iCloud | ✓ (upload) | ✓ (download) |
| View vault list | ✓ | ✓ |
| Query vault (RAG) | ✓ | ✓ |
| Power Mode with vault context | ✓ | ✓ |
| Write to notes | ✓ | ✓ (if vault in iCloud Drive) |
| Watch for changes | ✓ | - |
| Window context capture | ✓ | - |
| Power Mode overlay | ✓ (floating panel) | ✓ (full screen) |

**Workflow:**
1. **Mac:** Add vault folder → Index → Auto-sync to iCloud
2. **iOS:** See synced vaults → Download embeddings → Query via voice
3. **Both:** Use vaults in Power Modes → Save output to notes

---

## Phase 1: Mac Indexing Infrastructure

**Goal:** Mac can select vault, index, and query locally

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `ObsidianVault.swift` | `SwiftSpeakCore/Sources/SwiftSpeakCore/Models/` | Vault, Manifest, NoteMetadata, ActionConfig models |
| `ObsidianIndexer.swift` | `SwiftSpeak/SwiftSpeak/Services/Obsidian/` | Scans vault, reuses DocumentParser/TextChunker/EmbeddingService |
| `ObsidianVectorStore.swift` | `SwiftSpeak/SwiftSpeak/Services/Obsidian/` | Separate SQLite for Obsidian embeddings |
| `MacVaultsSettingsView.swift` | `SwiftSpeakMac/Views/` | Vault list with add/remove/index |
| `MacAddVaultSheet.swift` | `SwiftSpeakMac/Views/` | Folder picker + vault config |
| `MacFileBookmarkManager.swift` | `SwiftSpeakMac/Services/` | Security-scoped bookmarks for persistent folder access |

### Data Models

```swift
public struct ObsidianVault: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var localPath: String?              // Mac only
    public var iCloudPath: String
    public var lastIndexed: Date?
    public var noteCount: Int
    public var chunkCount: Int
    public var status: ObsidianVaultStatus
    public var autoRefreshEnabled: Bool
    public var dailyNotePath: String           // e.g., "Daily Notes/YYYY-MM-DD.md"
    public var newNotesFolder: String          // e.g., "Inbox"
}

public enum ObsidianVaultStatus: String, Codable {
    case notConfigured, indexing, syncing, synced, needsRefresh, downloading, error
}
```

### Key Work
- [ ] Create ObsidianVault model with all properties
- [ ] Create ObsidianVaultManifest for sync metadata
- [ ] Create ObsidianIndexer that reuses existing RAG services
- [ ] Create ObsidianVectorStore (separate from Power Mode VectorStore)
- [ ] Create MacFileBookmarkManager for persistent folder access
- [ ] Create MacVaultsSettingsView with vault list
- [ ] Create MacAddVaultSheet with folder picker
- [ ] Store vault paths in MacSharedSettings

### Acceptance Criteria
- [ ] User can select an Obsidian vault folder on Mac
- [ ] Vault is validated (has `.obsidian` folder)
- [ ] Indexing shows progress and cost estimate
- [ ] Embeddings stored locally in SQLite
- [ ] Local queries work against indexed vault

---

## Phase 2: iCloud Sync

**Goal:** Mac uploads embeddings to iCloud, iOS can download

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `ObsidianSyncService.swift` | `SwiftSpeak/SwiftSpeak/Services/Obsidian/` | Upload/download iCloud Drive operations |
| `ObsidianDownloadSheet.swift` | `SwiftSpeak/SwiftSpeak/Views/Settings/` | iOS download progress UI |
| `VaultsSettingsView.swift` | `SwiftSpeak/SwiftSpeak/Views/Settings/` | iOS vault list |
| `VaultDetailView.swift` | `SwiftSpeak/SwiftSpeak/Views/Settings/` | iOS vault status/download |

### Files to Modify

| File | Change |
|------|--------|
| `SwiftSpeak.xcdatamodeld` | Add ObsidianVaultEntity |
| `PersistenceController.swift` | Register ObsidianVaultEntity |

### Storage Format (iCloud Drive)

```
~/Library/Mobile Documents/iCloud~pawelgawliczek~SwiftSpeak/Obsidian/
├── {vault-id}/
│   ├── manifest.json           # Vault metadata
│   ├── chunks_index.json       # Chunk text + metadata
│   ├── embeddings_0.bin        # Binary embeddings (10k chunks/file)
│   ├── embeddings_1.bin        # Additional batches if needed
│   └── ...
```

### Key Work
- [ ] Create ObsidianSyncService with upload/download methods
- [ ] Implement manifest.json format
- [ ] Implement chunks_index.json format
- [ ] Implement binary embedding serialization (Float32 arrays)
- [ ] Add ObsidianVaultEntity to Core Data (CloudKit sync)
- [ ] Create iOS VaultsSettingsView
- [ ] Create iOS VaultDetailView with download button
- [ ] Create ObsidianDownloadSheet with progress

### Acceptance Criteria
- [ ] Mac can upload vault embeddings to iCloud Drive
- [ ] iOS can see available vaults via CloudKit
- [ ] iOS can download embeddings with progress indicator
- [ ] Embeddings cached locally on iOS
- [ ] Re-download works after cache clear

---

## Phase 3: Query Integration

**Goal:** Voice queries work, Power Modes can include Obsidian context

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `ObsidianQueryService.swift` | `SwiftSpeak/SwiftSpeak/Services/Obsidian/` | Similarity search against cached embeddings |
| `PowerModeVaultSection.swift` | `SwiftSpeak/SwiftSpeak/Views/PowerMode/` | Vault picker in Power Mode editor |
| `PowerModeActionSection.swift` | `SwiftSpeak/SwiftSpeak/Views/PowerMode/` | Action config in Power Mode editor |

### Files to Modify

| File | Change |
|------|--------|
| `PowerMode.swift` | Add obsidianVaultIds, includeWindowContext, obsidianAction |
| `RAGOrchestrator.swift` | Add queryWithObsidian() method |
| `PowerModeOrchestrator.swift` | Include Obsidian context in prompt |
| `PowerModeEditorView.swift` | Add vault and action sections |

### PowerMode Extensions

```swift
public extension PowerMode {
    var obsidianVaultIds: [UUID]
    var includeWindowContext: Bool
    var maxObsidianChunks: Int
    var obsidianAction: ObsidianActionConfig?
}

public struct ObsidianActionConfig: Codable {
    var action: ObsidianAction
    var targetVaultId: UUID
    var targetNoteName: String?
    var autoExecute: Bool
}
```

### Key Work
- [ ] Create ObsidianQueryService with similarity search
- [ ] Extend PowerMode model with vault properties
- [ ] Create PowerModeVaultSection UI component
- [ ] Create PowerModeActionSection UI component
- [ ] Integrate ObsidianQueryService with RAGOrchestrator
- [ ] Update PowerModeOrchestrator to include Obsidian context
- [ ] Update PowerModeEditorView with new sections

### Acceptance Criteria
- [ ] Power Mode can select which vaults to include
- [ ] Power Mode can configure output action
- [ ] RAG queries include Obsidian vault context
- [ ] Context shown in Power Mode execution

---

## Phase 4: Note Writing & Polish

**Goal:** Write to Obsidian notes, auto-refresh, delta updates

### Files to Create

| File | Location | Purpose |
|------|----------|---------|
| `ObsidianNoteWriter.swift` | `SwiftSpeak/SwiftSpeak/Services/Obsidian/` | Create/append notes to vault |
| `ObsidianActionSheet.swift` | `SwiftSpeak/SwiftSpeak/Views/Components/` | Confirmation before saving |
| `MacFileWatcher.swift` | `SwiftSpeakMac/Services/` | FSEvents watcher for vault changes |
| `MacVaultDetailView.swift` | `SwiftSpeakMac/Views/` | Status, re-index, refresh |

### Files to Modify

| File | Change |
|------|--------|
| `PowerModeOrchestrator.swift` | Execute Obsidian actions after completion |

### Action Types

| Action | Description |
|--------|-------------|
| `appendToDaily` | Append output to daily note (YYYY-MM-DD.md) |
| `appendToNote` | Append to specific named note |
| `createNote` | Create new note (title from first heading) |
| `none` | Read-only, no writing |

### Append Format

```markdown

---
*Added via SwiftSpeak at 3:45 PM*

[AI output here]
```

### Key Work
- [ ] Create ObsidianNoteWriter with append/create methods
- [ ] Create ObsidianActionSheet for confirmation
- [ ] Integrate action execution in PowerModeOrchestrator
- [ ] Create MacFileWatcher for vault change detection
- [ ] Implement delta updates (only re-embed changed notes)
- [ ] Add "Needs refresh" badge to vault list
- [ ] Create MacVaultDetailView with re-index button

### Acceptance Criteria
- [ ] Power Mode output can be saved to daily note
- [ ] Power Mode output can be saved to specific note
- [ ] New notes can be created
- [ ] Confirmation shown before saving (unless auto-execute)
- [ ] Mac detects vault changes and shows refresh badge
- [ ] Delta updates only re-embed changed notes

---

## Phase 5: Window Context & Power Mode Overlay (Both Platforms)

**Goal:** Read active window content (Mac), iterative conversation overlay (Mac + iOS)

### Files to Create (macOS)

| File | Location | Purpose |
|------|----------|---------|
| `MacWindowContextService.swift` | `SwiftSpeakMac/Services/` | Accessibility API for window text |
| `MacPowerModeOverlayView.swift` | `SwiftSpeakMac/Views/` | Floating panel for Power Mode execution |
| `MacPowerModeOverlayController.swift` | `SwiftSpeakMac/Views/` | Window management for overlay |

### Files to Create (iOS)

| File | Location | Purpose |
|------|----------|---------|
| `PowerModeExecutionView.swift` | `SwiftSpeak/SwiftSpeak/Views/PowerMode/` | Full-screen Power Mode execution (update existing) |
| `ContextPreviewSection.swift` | `SwiftSpeak/SwiftSpeak/Views/PowerMode/Components/` | Shows injected context with toggles |
| `IterativeConversationView.swift` | `SwiftSpeak/SwiftSpeak/Views/PowerMode/Components/` | Q&A and refinement UI |

### Files to Modify

| File | Change |
|------|--------|
| `MacPermissionManager.swift` | Add Accessibility permission request |
| `MacHotkeyManager.swift` | Trigger overlay on Power Mode hotkey |
| `PowerModeExecutionView.swift` (iOS) | Add context preview and iteration UI |

### Overlay States

1. **Context Preview** - Shows all injected context with toggles
2. **Recording** - User dictates request
3. **Processing** - AI thinking
4. **AI Question** - Answer clarifying questions
5. **Result** - View result, iterate with refinements
6. **Action Complete** - Confirmation before auto-close

### Key Work
- [ ] Create MacWindowContextService using AXUIElement
- [ ] Add Accessibility permission to MacPermissionManager
- [ ] Create MacPowerModeOverlayView with all 6 states
- [ ] Create MacPowerModeOverlayController for window management
- [ ] Implement context preview with toggles
- [ ] Implement iterative refinement loop
- [ ] Implement output actions (Copy, Insert, Save to Obsidian)
- [ ] Connect to MacHotkeyManager for hotkey triggers

### Acceptance Criteria (macOS)
- [ ] Overlay appears on Power Mode hotkey
- [ ] Active window content captured and shown
- [ ] User can toggle context sources on/off
- [ ] User can dictate or type input
- [ ] AI can ask clarifying questions
- [ ] User can iterate on result
- [ ] Output actions work correctly
- [ ] Overlay auto-closes after action

### Acceptance Criteria (iOS)
- [ ] Power Mode execution shows context preview
- [ ] User can toggle Obsidian/memory context on/off
- [ ] User can dictate or type input
- [ ] AI can ask clarifying questions
- [ ] User can iterate on result with voice/typing
- [ ] Output actions (Copy, Insert, Save to Obsidian) work
- [ ] Keyboard extension can trigger Power Mode via SwiftLink

---

## Technical Reference

### iCloud Paths

```
# User's Obsidian vault (if in iCloud Drive):
~/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/MyVault/

# SwiftSpeak's iCloud container (for embeddings):
~/Library/Mobile Documents/iCloud~pawelgawliczek~SwiftSpeak/Obsidian/
```

### Offline Support

| Operation | Needs Internet? |
|-----------|-----------------|
| Mac: Index vault | Yes (OpenAI API) |
| Mac: Query vault | No |
| iOS: Download embeddings | Yes (from iCloud) |
| iOS: Query vault | No (cached) |
| Write to notes | No (syncs later) |

### Cost Estimate

- 500 notes × ~500 tokens/note = 250k tokens
- OpenAI text-embedding-3-small: $0.02/1M tokens
- **Initial index: ~$0.005 (half a cent)**
- Delta update (10 notes): ~$0.0001

### Window Context (Accessibility API)

```swift
let app = NSWorkspace.shared.frontmostApplication
let axApp = AXUIElementCreateApplication(app.processIdentifier)

var focusedElement: CFTypeRef?
AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)

var textValue: CFTypeRef?
AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXValueAttribute as CFString, &textValue)
```

---

## Out of Scope (Future)

- Wikilink parsing and graph queries
- Tag-based filtering in search
- Real-time collaborative editing
- iOS Share Sheet Extension
- Obsidian plugin for deeper integration
- Vault sync conflict resolution UI
- Multiple vault sync strategies
