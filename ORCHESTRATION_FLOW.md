# SwiftSpeak Orchestration Flow

## Overview

This document describes the complete orchestration flow for all transcription and Power Mode scenarios, including what data is included in prompts and when.

---

## Standard Transcription Flow

```
IDLE --> RECORDING --> PROCESSING --> FORMATTING --> COMPLETE
             |              |              |
             v              v              v
        AudioRecorder  Transcription   Formatting
                       Provider        Provider
```

### Stage Details

**1. Recording Stage**
- Provider: AudioRecorder
- Input: Microphone audio
- Output: audio.m4a file
- Prompt: None

**2. Processing Stage (Transcription)**
- Provider: TranscriptionProvider (OpenAI Whisper, Deepgram, etc.)
- Input: audio.m4a + source language
- Output: Raw transcribed text
- Prompt: Vocabulary hint (if vocabulary replacements exist)

**3. Formatting Stage**
- Provider: FormattingProvider (GPT-4, Claude, etc.)
- Input: Raw text + formatting mode
- Output: Formatted text
- Prompt: Formatting instructions based on selected mode
- Note: Skipped when mode = raw

**4. Translation Stage (Optional)**
- Provider: TranslationProvider (DeepL, GPT-4, etc.)
- Input: Text + target language
- Output: Translated text
- Prompt: Translation instructions
- Note: Only when translation is enabled

---

## Power Mode Flow

```
IDLE --> RECORDING --> PROCESSING --> EXECUTING --> COMPLETE
             |              |              |
             v              v              v
        AudioRecorder  Transcription   Streaming LLM
                       Provider        + Context + Memory + RAG
```

### Key Difference from Standard Flow

Power Mode uses `StreamingFormattingProvider` instead of `FormattingProvider`, and injects:
- Context instructions
- Three-tier memory (global + context + power mode)
- RAG knowledge chunks
- Webhook data

---

## Prompt Contents by Type

### 1. Transcription Hint

**When included:** Always (when vocabulary replacements exist in settings)

**Source:** `SharedSettings.vocabularyReplacements`

**Format:**
```
Vocabulary terms to recognize:
- "AI" should be transcribed as "Artificial Intelligence"
- "SwiftSpeak" should be transcribed as "SwiftSpeak"
```

---

### 2. Formatting Prompt (Standard Mode)

**When included:** When formattingMode != raw

**Format:**
```
<system>
You are a text formatting assistant.
Format the following transcribed text according to the specified mode.

Mode: {mode.displayName}
Instructions: {mode.description}
</system>

<user>
{rawTranscribedText}
</user>
```

**Available Modes:**

| Mode    | Purpose                                          |
|---------|--------------------------------------------------|
| raw     | No formatting (skips FormattingProvider)         |
| formal  | Professional language, proper grammar            |
| casual  | Friendly tone, relaxed grammar                   |
| email   | Email format with greeting, body, sign-off       |
| bullet  | Convert to bullet points                         |
| summary | Summarize the key points                         |
| custom  | User-defined prompt                              |

---

### 3. Translation Prompt

**When included:** When translateEnabled == true

**Format:**
```
<system>
Translate the following text from {sourceLanguage} to {targetLanguage}.
Preserve the original meaning and tone.
</system>

<user>
{textToTranslate}
</user>
```

**Note:** Translation happens AFTER formatting (if formatting is enabled).

---

### 4. Power Mode Prompt (Full)

**When included:** When Power Mode is active

**Format:**
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

<webhooks>
  {webhookData}
</webhooks>
</system>

<conversation>
{conversationHistory}
</conversation>

<user>
{transcribedUserInput}
</user>
```

---

## Scenario Matrix

### What Gets Included In Each Scenario

| # | Scenario                     | Trans | Format | Translate | PM  | Prompt Contents                              |
|---|------------------------------|-------|--------|-----------|-----|----------------------------------------------|
| 1 | Raw only                     | Yes   | No     | No        | No  | Vocab hint only                              |
| 2 | Raw + Translate              | Yes   | No     | Yes       | No  | Vocab + Translation prompt                   |
| 3 | Formatted                    | Yes   | Yes    | No        | No  | Vocab + Formatting prompt                    |
| 4 | Formatted + Translate        | Yes   | Yes    | Yes       | No  | Vocab + Formatting + Translation             |
| 5 | Power Mode (no context)      | Yes   | No     | No        | Yes | Vocab + PM instruction + global memory       |
| 6 | Power Mode + Context         | Yes   | No     | No        | Yes | Vocab + PM + context + all 3 memories        |
| 7 | Power Mode + RAG             | Yes   | No     | No        | Yes | Vocab + PM + context + memories + RAG        |
| 8 | Power Mode + Webhooks        | Yes   | No     | No        | Yes | Vocab + PM + context + memories + webhooks   |
| 9 | Power Mode Full              | Yes   | No     | No        | Yes | Vocab + PM + context + memories + RAG + wh   |
| 10| Power Mode + Translate       | Yes   | No     | Yes       | Yes | Full PM prompt + Translation of response     |

Legend:
- Trans = Transcription
- PM = Power Mode
- wh = webhooks

---

## Privacy Mode Blocking

When `privacyModeEnabled == true`:

| Component         | Cloud Provider | Local Provider                |
|-------------------|----------------|-------------------------------|
| Transcription     | BLOCKED        | Allowed (WhisperKit)          |
| Formatting        | BLOCKED        | Allowed (Apple Intelligence)  |
| Translation       | BLOCKED        | Allowed (Apple Translation)   |
| Power Mode        | BLOCKED        | Limited (local models only)   |
| RAG Embeddings    | BLOCKED        | Allowed (local embeddings)    |

**Warning:** Power Mode shows warning when enabled in Privacy Mode since most LLM features require cloud providers.

---

## Memory Hierarchy

```
+----------------------------------------------+
|              Global Memory                    |
|  (Applies to all interactions)               |
|  Example: "User prefers concise responses"   |
+----------------------------------------------+
               |
               v
+----------------------------------------------+
|            Context Memory                     |
|  (Per context: Work, Personal, etc.)         |
|  Example: "Work context: formal language"    |
+----------------------------------------------+
               |
               v
+----------------------------------------------+
|          Power Mode Memory                    |
|  (Per power mode)                            |
|  Example: "Research mode: cite sources"      |
+----------------------------------------------+
```

**Injection Order:** Global -> Context -> Power Mode

All three levels are included when Power Mode is active with a context selected.

---

## RAG Context Injection

**When included:** When Power Mode has `knowledgeEnabled == true` and documents are attached

**Process:**
1. User input is embedded using EmbeddingService
2. VectorStore finds top-k similar chunks
3. Relevant chunks are injected into `<knowledge>` section
4. Chunks are ranked by similarity score

---

## Webhook Context Injection

**When included:** When Power Mode has enabled webhooks

**Process:**
1. Before LLM call, WebhookExecutor runs enabled webhooks
2. Webhook responses are parsed and formatted
3. Data is injected into `<webhooks>` section

**Example webhooks:**
- Weather API: Current conditions
- Calendar API: Today's events
- CRM API: Customer context
- Custom endpoints: Any JSON data

---

## Provider Selection Logic

```swift
func getProvider(for category: UsageCategory) -> Provider? {
    // 1. Check privacy mode
    if privacyModeEnabled {
        return localProvider(for: category)
    }

    // 2. Get selected provider for category
    let selected = settings.selectedProvider(for: category)

    // 3. Find configuration
    if let config = settings.configuredAIProviders.first(where: {
        $0.provider == selected &&
        $0.usageCategories.contains(category)
    }) {
        return factory.createProvider(for: config)
    }

    return nil
}
```

---

## Flow Decision Tree

```
START
  |
  +-- Is Power Mode Active?
       |
       +-- YES --> PowerModeOrchestrator
       |            |
       |            +-- Record Audio
       |            +-- Transcribe (with vocab hint)
       |            +-- Build PromptContext:
       |            |     - Add PM instruction
       |            |     - Add context (if any)
       |            |     - Add memories (global + context + PM)
       |            |     - Add RAG chunks (if enabled)
       |            |     - Add webhook data (if enabled)
       |            +-- Stream LLM Response
       |            +-- Update memories (if memoryEnabled)
       |            +-- Translate response (if translateEnabled)
       |
       +-- NO --> TranscriptionOrchestrator
                   |
                   +-- Record Audio
                   +-- Transcribe (with vocab hint)
                   +-- Format (if mode != raw)
                   +-- Apply vocabulary replacements
                   +-- Translate (if translateEnabled)
                   +-- Save to history
                   |
                   +-- COMPLETE
```

---

## Cost Tracking

Every provider call tracks:

| Metric                | Used By                    |
|-----------------------|----------------------------|
| inputTokens           | LLM providers              |
| outputTokens          | LLM providers              |
| audioDurationSeconds  | Transcription providers    |
| characterCount        | Translation (DeepL)        |

Cost is calculated using `CostCalculator` with pricing from `RemoteConfigManager`.
