# Three-Tier Memory System

SwiftSpeak uses a three-tier memory system to provide personalized, context-aware dictation. Memory is updated via batch processing (NOT per-transcription) to reduce API costs.

## Memory Tiers

| Tier | Scope | Purpose |
|------|-------|---------|
| Global | All conversations | User's general communication style, vocabulary, frequent contacts |
| Context | Per ConversationContext | Context-specific patterns (e.g., "Work" vs "Personal" communication) |
| Power Mode | Per Power Mode | Workflow-specific knowledge (e.g., "Research Assistant" remembers research topics) |

## Key Files

| File | Purpose |
|------|---------|
| `MemoryUpdateScheduler.swift` | Batch memory updates on app start (12h-24h intervals) |
| `MemoryManager.swift` | Utility functions: getCombinedMemory, clearMemory, isMemoryEnabled |
| `SharedSettings.swift` | Memory tracking: lastGlobalMemoryUpdate, lastContextMemoryUpdates, globalMemoryLimit |
| `TranscriptionRecord` | Memory flags: globalMemoryEnabled, usedForGlobalMemory, etc. |

## Update Schedule

- **Minimum interval:** 12 hours (max twice per day)
- **Maximum interval:** 24 hours (must update at least daily if there are new records)
- **Trigger:** On app start and when app returns to foreground

## Message Tracking

Each `TranscriptionRecord` tracks which memory tiers were enabled at transcription time:

```swift
// State at transcription time
let globalMemoryEnabled: Bool
let contextMemoryEnabled: Bool
let powerModeMemoryEnabled: Bool

// Processing tracking
var usedForGlobalMemory: Bool
var usedForContextMemory: Bool
var usedForPowerModeMemory: Bool
```

When memory updates run, only records where `{tier}MemoryEnabled == true && usedFor{Tier}Memory == false` are processed.

## Memory Limits

Each tier has a configurable character limit (500-2000 characters, default 2000):
- `SharedSettings.globalMemoryLimit` - Global memory limit
- `ConversationContext.memoryLimit` - Per-context limit
- `PowerMode.memoryLimit` - Per-power-mode limit

## Multilingual Support

Memory prompts explicitly preserve:
- Text in original language and script (Chinese, Japanese, Arabic, Korean)
- Proper nouns, names, and technical terms in their original form
- Language-specific punctuation and formatting
- Note which languages the user commonly uses
