# Orchestration Flow

Complete flow documentation for transcription and Power Mode scenarios.

---

## Standard Transcription Flow

```
IDLE --> RECORDING --> PROCESSING --> FORMATTING --> COMPLETE
             |              |              |
             v              v              v
        AudioRecorder  Transcription   Formatting
                       Provider        Provider
```

### Stages

| Stage | Provider | Input | Output |
|-------|----------|-------|--------|
| Recording | AudioRecorder | Microphone | audio.m4a |
| Processing | TranscriptionProvider | audio.m4a + language | Raw text |
| Formatting | FormattingProvider | Raw text + mode | Formatted text |
| Translation | TranslationProvider | Text + target lang | Translated text |

**Key files:**
- `TranscriptionOrchestrator.swift` - Main coordinator
- `AudioRecorder.swift` - Recording management
- `ProviderFactory.swift` - Provider instantiation

---

## Power Mode Flow

```
IDLE --> RECORDING --> PROCESSING --> EXECUTING --> COMPLETE
             |              |              |
             v              v              v
        AudioRecorder  Transcription   Streaming LLM
                       Provider        + Context + Memory + RAG
```

Power Mode uses `StreamingFormattingProvider` and injects:
- Context instructions
- Three-tier memory (global + context + power mode)
- RAG knowledge chunks
- Webhook data

**Key files:**
- `PowerModeOrchestrator.swift` - Power Mode coordinator
- `PromptContext.swift` - Context builder
- `SSEParser.swift` - Streaming response parser

---

## Prompt Contents

### Vocabulary Hint (Transcription)
```
Vocabulary terms to recognize:
- "AI" → "Artificial Intelligence"
- "SwiftSpeak" → "SwiftSpeak"
```

### Formatting Prompt
```
<system>
You are a text formatting assistant.
Mode: {mode.displayName}
Instructions: {mode.description}
</system>

<user>{rawTranscribedText}</user>
```

### Power Mode Prompt (Full)
```
<system>
{powerMode.instruction}

<context name="{context.name}">
{context.customInstructions}
</context>

<memory>
  <global>{globalMemory}</global>
  <context>{context.memory}</context>
  <powerMode>{powerMode.memory}</powerMode>
</memory>

<knowledge>
  <chunk source="{doc.name}" relevance="{score}">
    {chunkContent}
  </chunk>
</knowledge>
</system>

<user>{transcribedUserInput}</user>
```

---

## Scenario Matrix

| # | Scenario | Trans | Format | Translate | PM | Prompt Contents |
|---|----------|-------|--------|-----------|-----|-----------------|
| 1 | Raw only | Yes | No | No | No | Vocab hint |
| 2 | Raw + Translate | Yes | No | Yes | No | Vocab + Translation |
| 3 | Formatted | Yes | Yes | No | No | Vocab + Formatting |
| 4 | Formatted + Translate | Yes | Yes | Yes | No | Vocab + Format + Trans |
| 5 | Power Mode (basic) | Yes | No | No | Yes | Vocab + PM + global mem |
| 6 | Power Mode + Context | Yes | No | No | Yes | + context + all memories |
| 7 | Power Mode + RAG | Yes | No | No | Yes | + RAG chunks |
| 8 | Power Mode Full | Yes | No | No | Yes | All: mem + RAG + webhooks |

---

## Privacy Mode Blocking

When `privacyModeEnabled == true`:

| Component | Cloud | Local |
|-----------|-------|-------|
| Transcription | BLOCKED | WhisperKit |
| Formatting | BLOCKED | Apple Intelligence |
| Translation | BLOCKED | Apple Translation |
| Power Mode | BLOCKED | Limited |
| RAG Embeddings | BLOCKED | Local embeddings |

---

## Memory Hierarchy

```
┌──────────────────────────────────┐
│         Global Memory            │
│   (All interactions)             │
├──────────────────────────────────┤
│        Context Memory            │
│   (Work, Personal, etc.)         │
├──────────────────────────────────┤
│      Power Mode Memory           │
│   (Per power mode)               │
└──────────────────────────────────┘
```

**Injection order:** Global → Context → Power Mode

---

## Provider Selection

```swift
func getProvider(for category: UsageCategory) -> Provider? {
    // 1. Privacy mode check
    if privacyModeEnabled {
        return localProvider(for: category)
    }

    // 2. Get configured provider
    let selected = settings.selectedProvider(for: category)
    return factory.createProvider(for: selected)
}
```

---

## Cost Tracking

Every provider call tracks:

| Metric | Provider Type |
|--------|---------------|
| inputTokens | LLM |
| outputTokens | LLM |
| audioDurationSeconds | Transcription |
| characterCount | Translation (DeepL) |

Cost calculated via `CostCalculator` with pricing from `RemoteConfigManager`.
