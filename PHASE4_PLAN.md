# SwiftSpeak Phase 4: Power Mode + Contexts + Memory + RAG + Streaming

> **Execution guide for Phase 4.** Follow this document step-by-step.
> Master project documentation: `/IMPLEMENTATION_PLAN.md`

## Overview

Phase 4 transforms Power Mode from mock UI into a fully functional AI workflow system with:
- **Conversation Contexts** - Named contexts with tone/style injection
- **Three-Tier Memory** - History, Workflow, and Context memory
- **RAG (Retrieval-Augmented Generation)** - Document-based knowledge per Power Mode
- **Streaming** - Real-time transcription and LLM responses
- **Webhooks** - Outbound integrations (Slack, Notion, Make, Zapier)

**REMOVED from original plan:**
- ~~Web search capability~~ → Replaced by RAG
- ~~Bash/Computer use~~ → Not applicable for mobile
- ~~Code execution~~ → Security concerns for mobile

---

## Phase 4.0: UI Mock-ups (Start Here)

Build all new screens with mock data before implementing backends.

### 4.0.1 Contexts UI

**ContextsView.swift** (Settings → Contexts):
```
┌─────────────────────────────────────────────────────────┐
│  Contexts                                    [+ Add]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Active context affects transcription, translation,    │
│  and Power Mode behavior.                              │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💕 Fatma                              ✓ Active  │   │
│  │ Casual, loving conversation with my wife        │   │
│  │ Languages: Polish, English                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💼 Work                                         │   │
│  │ Professional, formal business communication    │   │
│  │ Languages: English                              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 👨‍👩‍👧 Family                                       │   │
│  │ Warm, friendly family conversations             │   │
│  │ Languages: Polish                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │
│    No active context                                    │
│    Tap a context above to activate                      │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**ContextEditorSheet.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  [Cancel]        Edit Context              [Save]       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Icon & Color                                           │
│  ┌──────┐  ┌──────────────────────────────────────┐    │
│  │  💕  │  │ [pink] [blue] [green] [purple] [...]│    │
│  └──────┘  └──────────────────────────────────────┘    │
│                                                         │
│  Name                                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Fatma                                           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Short Description                                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Casual, loving conversation with my wife        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Tone & Style (Detailed)                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Casual and loving. We often joke around and     │   │
│  │ use pet names. She speaks Polish primarily      │   │
│  │ but we mix in English words sometimes.          │   │
│  │ Keep translations warm and natural.             │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Expected Languages                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [✓ Polish] [✓ English] [ Spanish] [ German]    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Custom Instructions (injected into all prompts)       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ When translating to Polish, use informal "ty"   │   │
│  │ form. Add endearments where appropriate.        │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  Context Memory                              [Toggle ◉] │
│  Remember details from conversations in this context   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Current memory:                                 │   │
│  │ "Fatma mentioned she has a meeting Tuesday..."  │   │
│  │                                    [Edit] [Clear]│   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [                    Delete Context                  ] │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**ContextQuickSwitcher.swift** (Floating overlay):
```
┌─────────────────────────────────────────────────────────┐
│            Switch Context                               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐            │
│  │  💕   │  │  💼   │  │ 👨‍👩‍👧  │  │  ⊘   │            │
│  │ Fatma │  │ Work  │  │Family │  │ None  │            │
│  │  ✓    │  │       │  │       │  │       │            │
│  └───────┘  └───────┘  └───────┘  └───────┘            │
│                                                         │
│  Currently: Fatma                                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4.0.2 Memory UI

**MemoryView.swift** (Settings → Memory):
```
┌─────────────────────────────────────────────────────────┐
│  Memory                                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  HISTORY MEMORY (Global)                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Updated after every conversation                │   │
│  │ Always active                                   │   │
│  │                                                 │   │
│  │ "User prefers formal English for work,         │   │
│  │ casual Polish for family. Often discusses      │   │
│  │ Swift programming and AI topics."              │   │
│  │                                                 │   │
│  │ Last updated: 2 hours ago                       │   │
│  │                               [View] [Edit]     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  WORKFLOW MEMORIES                                      │
│  Per Power Mode (only shows modes with memory enabled)  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📧 Email Composer                               │   │
│  │ "Last email was to client about project delay"  │   │
│  │ Updated: Yesterday                      [Edit]  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💻 Code Reviewer                                │   │
│  │ "Reviewing Swift codebase, focus on memory..."  │   │
│  │ Updated: 3 days ago                     [Edit]  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  CONTEXT MEMORIES                                       │
│  Per Context (only shows contexts with memory enabled)  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💕 Fatma                                        │   │
│  │ "Fatma has meeting Tuesday, planning dinner..." │   │
│  │ Updated: Today                          [Edit]  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [              Clear All Memory                      ] │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**MemoryEditorSheet.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  [Cancel]       Edit Memory                 [Save]      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  💕 Fatma - Context Memory                              │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Fatma mentioned she has a meeting on Tuesday    │   │
│  │ afternoon. We're planning dinner for Friday.    │   │
│  │ She prefers Italian food lately.                │   │
│  │                                                 │   │
│  │                                                 │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Last updated: Today at 2:34 PM                         │
│  Character count: 142 / 2000                           │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [                  Clear Memory                      ] │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4.0.3 RAG/Knowledge Base UI

**KnowledgeBaseView.swift** (in PowerModeEditorView):
```
┌─────────────────────────────────────────────────────────┐
│  Knowledge Base                              [+ Add]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Documents attached to this Power Mode will be         │
│  searched to provide relevant context.                 │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📄 API Documentation.pdf                   ✓    │   │
│  │ 156 chunks indexed • 2.3 MB                     │   │
│  │ Last updated: Yesterday                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🌐 Project Wiki                            ↻    │   │
│  │ https://wiki.example.com/project                │   │
│  │ 89 chunks • Auto-update: Weekly                 │   │
│  │ Last checked: 2 days ago                        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📝 Style Guide.md                          ✓    │   │
│  │ 12 chunks indexed • 45 KB                       │   │
│  │ Uploaded: Dec 20, 2025                          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Swipe left to delete • Tap to view details            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**DocumentPickerSheet.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  [Cancel]       Add Document                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────────┐  ┌────────────────────┐        │
│  │   📄 Upload File   │  │    🌐 Add URL      │        │
│  └────────────────────┘  └────────────────────┘        │
│                                                         │
│  ═══════════════════════════════════════════════════   │
│                                                         │
│  [If Upload File selected:]                            │
│                                                         │
│  Supported formats: PDF, TXT, MD                       │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │              [Choose File]                      │   │
│  │                                                 │   │
│  │         Tap to select a document                │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ═══════════════════════════════════════════════════   │
│                                                         │
│  [If Add URL selected:]                                │
│                                                         │
│  URL                                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ https://docs.example.com/api                    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Name (optional)                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ API Documentation                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Auto-update Interval                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [Never] [Daily] [Weekly] [◉ Always]            │   │
│  └─────────────────────────────────────────────────┘   │
│  "Always" checks for updates before each query        │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [                    Add Document                    ] │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4.0.4 Webhooks UI

**WebhooksView.swift** (Settings → Webhooks):
```
┌─────────────────────────────────────────────────────────┐
│  Webhooks                                    [+ Add]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Webhooks run during Power Mode workflows.             │
│  All connections are outbound only.                    │
│                                                         │
│  CONTEXT SOURCES (fetch before processing)             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📅 Calendar Events                     [◉ On]   │   │
│  │ GET https://api.calendar.com/today              │   │
│  │ Last fetch: 2 hours ago                         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  OUTPUT DESTINATIONS (send after completion)           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💬 Slack Channel                       [◉ On]   │   │
│  │ POST #ai-outputs                                │   │
│  │ Last sent: Yesterday                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📝 Notion Database                     [○ Off]  │   │
│  │ POST to Tasks database                          │   │
│  │ Never triggered                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  AUTOMATION TRIGGERS                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ⚡ Make.com Scenario                   [◉ On]   │   │
│  │ POST https://hook.make.com/...                  │   │
│  │ Last triggered: 3 days ago                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**WebhookEditorSheet.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  [Cancel]        Add Webhook                [Save]      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Template                                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [💬 Slack] [📝 Notion] [✓ Todoist]             │   │
│  │ [⚡ Make] [🔗 Zapier] [⚙️ Custom]               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Name                                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ My Todoist Tasks                                │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Webhook Type                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [Context] [◉ Output] [Trigger]                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  URL                                                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ https://api.todoist.com/rest/v2/tasks          │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Authentication                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [None] [◉ Bearer Token] [API Key] [Basic]      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Token                                                  │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ••••••••••••••••••••••••••••                   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Payload (what to include)                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [✓ Input] [✓ Output] [✓ Mode Name]             │   │
│  │ [✓ Context] [✓ Timestamp]                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  [              Test Webhook                          ] │
│                                                         │
│  [                  Delete                            ] │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 4a: Conversation Contexts (Backend)

### Data Model

```swift
struct ConversationContext: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String                    // "Fatma"
    var icon: String                    // SF Symbol or emoji
    var color: PowerModeColorPreset
    var description: String             // Short description for list view
    var toneDescription: String         // Detailed tone guidance
    var languageHints: [Language]       // Expected languages
    var customInstructions: String      // Injected into all prompts
    var memoryEnabled: Bool             // Context-level memory toggle
    var memory: String?                 // Stored memory for this context
    var lastMemoryUpdate: Date?
    var isActive: Bool                  // Currently selected context
    let createdAt: Date
    var updatedAt: Date

    static var empty: ConversationContext {
        ConversationContext(
            id: UUID(),
            name: "",
            icon: "person.circle",
            color: .blue,
            description: "",
            toneDescription: "",
            languageHints: [],
            customInstructions: "",
            memoryEnabled: false,
            memory: nil,
            lastMemoryUpdate: nil,
            isActive: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
```

### Injection Points

| Feature | How Context is Used |
|---------|---------------------|
| **Transcription** | Language hints sent to Whisper for better accuracy |
| **Translation** | Tone description guides translation style |
| **Formatting** | Custom instructions prepended to formatting prompt |
| **Power Mode** | Full context as system prompt prefix |

---

## Phase 4b: Three-Tier Memory System

### Memory Levels

1. **History Memory** (Global)
   - Updated after every conversation
   - Always active
   - Short summary of user preferences and recent topics

2. **Workflow Memory** (Per Power Mode)
   - Toggle per Power Mode
   - Remembers context from previous uses

3. **Context Memory** (Per Conversation Context)
   - Toggle per context
   - Remembers relationship-specific details

### Memory Update Flow

```
Conversation completes
        │
        ▼
┌─────────────────────────────────────┐
│ Generate summary using LLM:         │
│ "Summarize in 1-2 sentences for    │
│  future context"                    │
└─────────────────┬───────────────────┘
                  │
      ┌───────────┼───────────┐
      ▼           ▼           ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ History │ │Workflow │ │ Context │
│ Memory  │ │ Memory  │ │ Memory  │
│(always) │ │(if on)  │ │(if on)  │
└─────────┘ └─────────┘ └─────────┘
```

### Compression

When memory exceeds 2000 characters:
1. Combine existing memory + new summary
2. Ask LLM to compress to under 1500 chars
3. Replace with compressed version

---

## Phase 4c: PowerModeOrchestrator

### State Machine

```
idle → recording → transcribing → thinking → generating → complete
                                     │
                                     ├── [Fetch webhooks context]
                                     ├── [RAG query if docs attached]
                                     ├── [Memory injection]
                                     └── [Context injection]
```

### Key Methods

```swift
@MainActor
final class PowerModeOrchestrator: ObservableObject {
    @Published private(set) var state: PowerModeExecutionState = .idle
    @Published private(set) var streamingOutput: String = ""

    func startRecording() async
    func stopRecording() async  // Triggers full workflow
    func refine(with feedback: String) async
    func cancel()
}
```

---

## Phase 4d: LLM Streaming

### Provider Support

| Provider | LLM Streaming | Notes |
|----------|:-------------:|-------|
| OpenAI | ✅ | `stream: true` in request |
| Anthropic | ✅ | SSE streaming |
| Gemini | ✅ | `streamGenerateContent` endpoint |
| Local (Ollama) | ✅ | Streams by default |

### UI Behavior

- Text flows in real-time
- Markdown rendered progressively
- Spinner only for initial connection

---

## Phase 4e: RAG System

### Pipeline

```
Document Upload → Parse → Chunk → Embed → Store
                                            │
Query                                       │
  │                                         │
  ▼                                         ▼
Embed Query ─────────────────────→ Vector Store
  │                                         │
  ▼                                         │
Similarity Search ◄─────────────────────────┘
  │
  ▼
Top K Chunks → Include in LLM Prompt
```

### Chunking Strategy

- ~500 tokens per chunk
- ~50 token overlap
- Preserve paragraph boundaries

---

## Phase 4f: Webhooks

### Types

| Type | Direction | When |
|------|-----------|------|
| Context Source | GET | Before processing |
| Output Destination | POST | After completion |
| Automation Trigger | POST | After completion |

All webhooks are **outbound only** (mobile-friendly).

---

## Implementation Order

```
4.0: UI Mock-ups
├── ContextsView + ContextEditorSheet + ContextQuickSwitcher
├── MemoryView + MemoryEditorSheet
├── KnowledgeBaseView + DocumentPickerSheet
└── WebhooksView + WebhookEditorSheet

4a: Contexts Backend
├── ConversationContext model
├── Storage in SharedSettings
└── Injection into orchestrator

4b: Memory System
├── HistoryMemory model
├── MemoryManager service
└── Compression logic

4c: PowerModeOrchestrator
├── Full state machine
├── Real transcription/generation
└── Replace mocks in PowerModeExecutionView

4d: LLM Streaming
├── StreamingClient (SSE)
├── OpenAI/Anthropic/Gemini streaming
└── Progressive UI

4e: RAG
├── DocumentParser
├── TextChunker + EmbeddingService
├── VectorStore
└── KnowledgeBaseManager

4f: Webhooks
├── Webhook model
├── WebhookExecutor
└── Integration in orchestrator

4g: Transcription Streaming (OPTIONAL)
├── Deepgram/AssemblyAI WebSocket
└── Real-time UI
```

---

## Verification Checklist

### Phase 4.0: UI Mock-ups ✅ COMPLETE
- [x] ContextsView, ContextEditorSheet, ContextDetailView
- [x] ContextQuickSwitcher floating overlay
- [x] MemoryView with filtering, MemoryEditorSheet
- [x] KnowledgeBaseView, DocumentPickerSheet
- [x] WebhooksView, WebhookEditorSheet
- [x] PowerTabView with segmented control
- [x] SwipeablePowerModeCard with swipe actions

### Phase 4a: Contexts ✅ COMPLETE
- [x] Create, edit, delete contexts
- [x] Quick switch from recording view
- [x] Context injected into prompts (PromptContext.swift)
- [x] Language hints affect transcription (promptHint)
- [x] Formality picker with DeepL-specific note
- [x] Tone description injected into LLM prompts

### Phase 4b: Memory 🟡 IN PROGRESS
- [x] HistoryMemory model
- [x] Global memory in SharedSettings
- [x] Workflow memory toggle per Power Mode
- [x] Context memory toggle per context
- [ ] MemoryManager service
- [ ] Memory updates after conversations
- [ ] Compression at threshold (>2000 chars → <1500)

### Phase 4c: PowerModeOrchestrator
- [ ] Full state machine working
- [ ] Real transcription (not mock)
- [ ] Real LLM calls (not mock)
- [ ] All injections working

### Phase 4d: Streaming
- [ ] StreamingClient.swift (SSE parsing)
- [ ] OpenAI streaming works
- [ ] Anthropic streaming works
- [ ] Gemini streaming works
- [ ] Progressive text rendering

### Phase 4e: RAG
- [x] KnowledgeDocument model
- [ ] DocumentChunk model
- [ ] Upload PDF/TXT/MD (DocumentParser)
- [ ] Add URL with auto-update
- [ ] TextChunker, EmbeddingService, VectorStore
- [ ] Query returns relevant chunks
- [ ] Chunks included in prompt

### Phase 4f: Webhooks
- [x] Webhook model
- [x] Webhooks UI (mock)
- [ ] WebhookExecutor service
- [ ] Context sources fetch data
- [ ] Output destinations send results
- [ ] Test button works

### Phase 4g: Transcription Streaming (OPTIONAL)
- [ ] DeepgramStreamingService (WebSocket)
- [ ] AssemblyAIStreamingService (WebSocket)
- [ ] Real-time transcription UI
