# SwiftSpeak Phase 10: Privacy Mode & Provider Restructure

> **Execution guide for Phase 10.** Follow this document step-by-step.
> Master project documentation: `/IMPLEMENTATION_PLAN.md`

## Overview

Phase 10 adds on-device AI processing and restructures provider management:
- **On-Device Voice Recognition** - WhisperKit (MIT licensed, free, hosted on Hugging Face)
- **On-Device Text Formatting** - Apple Intelligence (iOS 18.5+, A17 Pro+)
- **On-Device Translation** - Apple Translation API (iOS 17.4+, free)
- **Privacy Mode Toggle** - Force local-only processing
- **Settings Restructure** - Split into "AI Cloud Models" and "AI Local Models"
- **Global Provider Defaults** - Set default provider per capability
- **Power Mode Provider Override** - Each Power Mode can use different LLM

**No Self-Hosting Required:**
- WhisperKit models hosted by Argmax on Hugging Face
- Translation models managed by Apple's system
- Apple Intelligence managed by iOS

---

## Phase 10.0: UI Mock-ups (Start Here)

Build all new screens with mock data before implementing backends.

### 10.0.1 Settings Main View Restructure

**SettingsView.swift** (Updated):
```
┌─────────────────────────────────────────────────────────┐
│  Settings                                               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  AI CLOUD MODELS                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ☁️  OpenAI                          Configured ✓ │   │
│  │     GPT-4o, Whisper                              │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ☁️  Anthropic                       Configured ✓ │   │
│  │     Claude 3.5 Sonnet                            │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ☁️  DeepL                           Configured ✓ │   │
│  │     Translation                                  │   │
│  ├─────────────────────────────────────────────────┤   │
│  │                  + Add Cloud Provider            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  AI LOCAL MODELS                                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📱 On-Device Voice (WhisperKit)     Ready ✓     │   │
│  │    large-v3 · 1.5 GB                             │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🧠 Apple Intelligence               Available   │   │
│  │    Tap to enable                                 │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🌍 Apple Translation                3 languages │   │
│  │    English, Polish, Spanish                      │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🖥️ Ollama (Self-Hosted)             Connected   │   │
│  │    llama3:8b @ 192.168.1.50                      │   │
│  ├─────────────────────────────────────────────────┤   │
│  │                  + Add Local Model               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  DEFAULT PROVIDERS                                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Transcription          OpenAI Whisper        >  │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ Translation            DeepL                 >  │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ Power Mode LLM         Anthropic Claude      >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  PRIVACY                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔒 Force Privacy Mode                    [OFF]  │   │
│  │    Only use local models (works offline)         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  TRANSCRIPTION                                          │
│  ...                                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**States for Local Model Rows:**

```
[Not Configured]
┌─────────────────────────────────────────────────────┐
│ 📱 On-Device Voice (WhisperKit)        Not Set Up  │
│    Tap to configure                                 │
└─────────────────────────────────────────────────────┘

[Downloading]
┌─────────────────────────────────────────────────────┐
│ 📱 On-Device Voice (WhisperKit)       Downloading  │
│    large-v3 · 67% · 1.0 GB / 1.5 GB                │
│    ████████████████░░░░░░░░                        │
└─────────────────────────────────────────────────────┘

[Ready]
┌─────────────────────────────────────────────────────┐
│ 📱 On-Device Voice (WhisperKit)           Ready ✓  │
│    large-v3 · 1.5 GB                               │
└─────────────────────────────────────────────────────┘

[Not Available - Device]
┌─────────────────────────────────────────────────────┐
│ 🧠 Apple Intelligence                 Not Available│
│    Requires iPhone 15 Pro or later                 │
└─────────────────────────────────────────────────────┘

[Not Available - iOS]
┌─────────────────────────────────────────────────────┐
│ 🧠 Apple Intelligence                 Not Available│
│    Requires iOS 18.5 or later                      │
└─────────────────────────────────────────────────────┘
```

---

### 10.0.2 Add Local Model Sheet

**AddLocalModelSheet.swift**:
```
┌─────────────────────────────────────────────────────────┐
│                 Add Local Model                    ✕    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ON-DEVICE                                              │
│  Models that run directly on this iPhone                │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🎤 Voice Recognition                            │   │
│  │    WhisperKit · Transcribe audio locally        │   │
│  │                                              >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🧠 Apple Intelligence                           │   │
│  │    Text formatting and rewriting                │   │
│  │                                              >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🌍 Translation Languages                        │   │
│  │    Download languages for offline use           │   │
│  │                                              >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  SELF-HOSTED                                            │
│  Connect to AI servers on your network                  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🖥️ Ollama                                       │   │
│  │    Run open-source LLMs on your Mac/PC          │   │
│  │                                              >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💻 LM Studio                                    │   │
│  │    Local AI server with GUI                     │   │
│  │                                              >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.3 WhisperKit Setup View

**WhisperKitSetupView.swift** (Device Supports All Models):
```
┌─────────────────────────────────────────────────────────┐
│  < Back         Voice Recognition                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                      🎤                          │   │
│  │                                                  │   │
│  │                  WhisperKit                      │   │
│  │         On-Device Speech Recognition             │   │
│  │                                                  │   │
│  │    ✓ Audio never leaves your device             │   │
│  │    ✓ Works without internet                     │   │
│  │    ✓ No API costs                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  YOUR DEVICE                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ iPhone 15 Pro                                    │   │
│  │ A17 Pro · iOS 18.2                              │   │
│  │                                                  │   │
│  │ ✓ All models supported                          │   │
│  │ Available storage: 45.2 GB                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  SELECT MODEL                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ○  tiny.en                              39 MB   │   │
│  │    English only · Fastest                        │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ○  base                                142 MB   │   │
│  │    All languages · Fast                          │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ○  small                               466 MB   │   │
│  │    All languages · Balanced                      │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ◉  large-v3                            1.5 GB   │   │
│  │    All languages · Best accuracy    Recommended │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            Download large-v3 (1.5 GB)           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**WhisperKitSetupView.swift** (Older Device - Limited Support):
```
┌─────────────────────────────────────────────────────────┐
│  < Back         Voice Recognition                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ...header...                                           │
│                                                         │
│  YOUR DEVICE                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ iPhone XR                                        │   │
│  │ A12 Bionic · iOS 17.4                           │   │
│  │                                                  │   │
│  │ ⚠️ Limited model support                        │   │
│  │    Larger models may be slow                     │   │
│  │ Available storage: 12.1 GB                      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  SELECT MODEL                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ◉  tiny.en                              39 MB   │   │
│  │    English only · Fastest           Recommended │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ○  base                                142 MB   │   │
│  │    All languages · May be slow                   │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ ○  small                               466 MB   │   │
│  │    ⚠️ Performance may suffer                    │   │
│  ├─────────────────────────────────────────────────┤   │
│  │     large-v3                           1.5 GB   │   │
│  │    ✗ Not recommended for this device            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ...download button...                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**WhisperKitSetupView.swift** (Model Already Downloaded):
```
┌─────────────────────────────────────────────────────────┐
│  < Back         Voice Recognition                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ...header & device info...                             │
│                                                         │
│  CURRENT MODEL                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ large-v3                               1.5 GB   │   │
│  │ All languages · Best accuracy                   │   │
│  │                                                  │   │
│  │ ✓ Ready to use                                  │   │
│  │ Downloaded: Dec 15, 2025                        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  CHANGE MODEL                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ○  tiny.en                              39 MB   │   │
│  │ ○  base                                142 MB   │   │
│  │ ○  small                               466 MB   │   │
│  │ ◉  large-v3                    ✓ Downloaded     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              Delete Model (1.5 GB)              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.4 Download Progress View

**ModelDownloadView.swift** (Overlay/Sheet):
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                  │   │
│  │                      🎤                          │   │
│  │                                                  │   │
│  │           Downloading WhisperKit                 │   │
│  │                 large-v3                         │   │
│  │                                                  │   │
│  │      ████████████████████░░░░░░░░░░             │   │
│  │                   67%                            │   │
│  │                                                  │   │
│  │            1.0 GB of 1.5 GB                     │   │
│  │         ~2 minutes remaining                     │   │
│  │                                                  │   │
│  │  ───────────────────────────────────────────    │   │
│  │                                                  │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │              Cancel Download              │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  │                                                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.5 Apple Intelligence Setup View

**AppleIntelligenceSetupView.swift** (Available):
```
┌─────────────────────────────────────────────────────────┐
│  < Back       Apple Intelligence                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                      🧠                          │   │
│  │                                                  │   │
│  │              Apple Intelligence                  │   │
│  │          On-Device Text Processing               │   │
│  │                                                  │   │
│  │    ✓ Rewrite text in different tones           │   │
│  │    ✓ Fix grammar and improve clarity            │   │
│  │    ✓ Text stays on your device                  │   │
│  │    ✓ No API costs                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  DEVICE STATUS                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ iPhone 15 Pro                                    │   │
│  │                                                  │   │
│  │ ✓ A17 Pro chip                                  │   │
│  │ ✓ iOS 18.5                                      │   │
│  │ ✓ Apple Intelligence available                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  USE FOR                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ✓ Email formatting mode                         │   │
│  │ ✓ Formal formatting mode                        │   │
│  │ ✓ Casual formatting mode                        │   │
│  │ ✓ Simple Power Mode prompts                     │   │
│  │                                                  │   │
│  │ ⚠️ Not suitable for:                            │   │
│  │    Complex reasoning or world knowledge         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Enable Apple Intelligence             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**AppleIntelligenceSetupView.swift** (Not Available):
```
┌─────────────────────────────────────────────────────────┐
│  < Back       Apple Intelligence                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ...header...                                           │
│                                                         │
│  DEVICE STATUS                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ iPhone 14 Pro                                    │   │
│  │                                                  │   │
│  │ ✗ A16 Bionic chip                               │   │
│  │   Requires A17 Pro or later                      │   │
│  │                                                  │   │
│  │ ───────────────────────────────────────────     │   │
│  │                                                  │   │
│  │ Apple Intelligence is available on:              │   │
│  │ • iPhone 15 Pro and later                       │   │
│  │ • iPad with M1 chip or later                    │   │
│  │ • Mac with M1 chip or later                     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ALTERNATIVE                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ You can still use cloud-based LLMs for text     │   │
│  │ formatting. Configure OpenAI, Anthropic, or     │   │
│  │ other providers in AI Cloud Models.             │   │
│  │                                                  │   │
│  │              Go to AI Cloud Models           >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.6 Apple Translation Setup View

**AppleTranslationSetupView.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  < Back      Translation Languages                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                      🌍                          │   │
│  │                                                  │   │
│  │              Apple Translation                   │   │
│  │            Offline Translation                   │   │
│  │                                                  │   │
│  │    ✓ Translate without internet                 │   │
│  │    ✓ Text stays on your device                  │   │
│  │    ✓ Powered by Apple's ML models              │   │
│  │    ✓ No API costs                               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  DOWNLOADED LANGUAGES                                   │
│  Languages you can use offline                          │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🇬🇧 English                          System     │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🇵🇱 Polish                           312 MB     │   │
│  │                                      [Remove]   │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🇪🇸 Spanish                          287 MB     │   │
│  │                                      [Remove]   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ADD LANGUAGES                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Tap to open system language settings            │   │
│  │                                                  │   │
│  │     Open Settings → Translate → Languages    >  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ℹ️ Languages are shared with Apple Translate app      │
│     and all other apps using Apple Translation.         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.7 Default Providers View

**DefaultProvidersView.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  < Back       Default Providers                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Set which provider to use for each capability.         │
│  Power Modes can override the LLM setting.              │
│                                                         │
│  TRANSCRIPTION                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Provider                                         │   │
│  │ ┌───────────────────────────────────────────┐   │   │
│  │ │ ☁️ OpenAI                              ▼  │   │   │
│  │ └───────────────────────────────────────────┘   │   │
│  │                                                  │   │
│  │ Model                                            │   │
│  │ ┌───────────────────────────────────────────┐   │   │
│  │ │ whisper-1                              ▼  │   │   │
│  │ └───────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  TRANSLATION                                            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Provider                                         │   │
│  │ ┌───────────────────────────────────────────┐   │   │
│  │ │ ☁️ DeepL                               ▼  │   │   │
│  │ └───────────────────────────────────────────┘   │   │
│  │                                                  │   │
│  │ (DeepL uses automatic model selection)           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  POWER MODE / FORMATTING                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Provider                                         │   │
│  │ ┌───────────────────────────────────────────┐   │   │
│  │ │ ☁️ Anthropic                           ▼  │   │   │
│  │ └───────────────────────────────────────────┘   │   │
│  │                                                  │   │
│  │ Model                                            │   │
│  │ ┌───────────────────────────────────────────┐   │   │
│  │ │ claude-sonnet-4-20250514               ▼  │   │   │
│  │ └───────────────────────────────────────────┘   │   │
│  │                                                  │   │
│  │ ℹ️ Individual Power Modes can override this     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  OFFLINE FALLBACK                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Use local when offline                  [ON]    │   │
│  │                                                  │   │
│  │ When cloud providers are unreachable:            │   │
│  │ • WhisperKit for transcription                   │   │
│  │ • Apple Intelligence for formatting              │   │
│  │ • Apple Translation for translation              │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Provider Dropdown Options:**
```
┌───────────────────────────────────────────┐
│ CLOUD                                      │
│ ────────────────────────────────────────── │
│   ☁️ OpenAI                                │
│   ☁️ Anthropic                             │
│   ☁️ Google Gemini                         │
│                                            │
│ LOCAL                                      │
│ ────────────────────────────────────────── │
│   📱 WhisperKit (on-device)                │
│   🧠 Apple Intelligence                    │
│   🌍 Apple Translation                     │
│   🖥️ Ollama                                │
│   💻 LM Studio                             │
└───────────────────────────────────────────┘
```

---

### 10.0.8 Power Mode Editor - Provider Override

**PowerModeEditorView.swift** (Updated Section):
```
┌─────────────────────────────────────────────────────────┐
│  Cancel         Edit Power Mode               Save      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ...existing fields (Icon, Name, Prompt, etc.)...       │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  LLM PROVIDER                                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ○  Use default                                  │   │
│  │    Currently: Anthropic Claude                   │   │
│  │                                                  │   │
│  │ ◉  Use specific provider                        │   │
│  │    ┌─────────────────────────────────────────┐  │   │
│  │    │ Provider                                │  │   │
│  │    │ ┌───────────────────────────────────┐   │  │   │
│  │    │ │ ☁️ OpenAI                      ▼  │   │  │   │
│  │    │ └───────────────────────────────────┘   │  │   │
│  │    │                                         │  │   │
│  │    │ Model                                   │  │   │
│  │    │ ┌───────────────────────────────────┐   │  │   │
│  │    │ │ gpt-4o                         ▼  │   │  │   │
│  │    │ └───────────────────────────────────┘   │  │   │
│  │    └─────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ...rest of editor (Knowledge Base, Memory, etc.)...    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.9 Power Mode List - Provider Indicator

**PowerModeListView.swift** (Updated Cards):
```
┌─────────────────────────────────────────────────────────┐
│  Power Modes                                  + Add     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📧 Email Composer                            >  │   │
│  │    Compose professional emails from voice       │   │
│  │    ☁️ Default (Anthropic)                       │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 💻 Code Reviewer                             >  │   │
│  │    Review and explain code changes              │   │
│  │    ☁️ OpenAI GPT-4o                             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📝 Quick Notes                               >  │   │
│  │    Convert thoughts into bullet points          │   │
│  │    🧠 Apple Intelligence                        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔒 Private Draft                             >  │   │
│  │    Draft sensitive content locally              │   │
│  │    🖥️ Ollama llama3                             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.10 Privacy Mode Toggle Behavior

**When Privacy Mode is OFF:**
```
┌─────────────────────────────────────────────────────────┐
│  PRIVACY                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔒 Force Privacy Mode                    [OFF]  │   │
│  │    Only use local models (works offline)         │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

All providers available in pickers.
```

**When Privacy Mode is ON:**
```
┌─────────────────────────────────────────────────────────┐
│  PRIVACY                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔒 Force Privacy Mode                     [ON]  │   │
│  │    Only local models are being used              │   │
│  │                                                  │   │
│  │    Active providers:                             │   │
│  │    • 📱 WhisperKit (transcription)              │   │
│  │    • 🧠 Apple Intelligence (formatting)         │   │
│  │    • 🌍 Apple Translation (translation)         │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

Cloud providers grayed out in pickers with "Requires Privacy Mode off".
```

**Privacy Mode without required local models:**
```
┌─────────────────────────────────────────────────────────┐
│  PRIVACY                                                │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔒 Force Privacy Mode                    [OFF]  │   │
│  │    Only use local models (works offline)         │   │
│  │                                                  │   │
│  │    ⚠️ Missing local models:                     │   │
│  │    • Voice recognition not configured            │   │
│  │    • Apple Intelligence not available            │   │
│  │                                                  │   │
│  │    Configure local models first to enable.       │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

Toggle is disabled until local models are configured.
```

---

### 10.0.11 Keyboard Status Indicators

**KeyboardView.swift** (Status Bar Variants):

```
[Normal - Cloud Active]
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────┐   │
│  │ ☁️ Cloud                              🎤 Record │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

[Privacy Mode - Local Only]
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🔒 Private                            🎤 Record │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

[Offline - Auto Fallback to Local]
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📴 Offline                            🎤 Record │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

[Processing - Shows Active Provider]
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📱 WhisperKit                      ⏳ Processing│   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

### 10.0.12 Storage Management View

**LocalModelStorageView.swift**:
```
┌─────────────────────────────────────────────────────────┐
│  < Back        Local Model Storage                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  STORAGE USAGE                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ███████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │   │
│  │                                                  │   │
│  │  2.1 GB used                                    │   │
│  │  45.2 GB available                              │   │
│  │                                                  │   │
│  │  🎤 Voice Models        1.5 GB                  │   │
│  │  🌍 Translation         0.6 GB                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  INSTALLED MODELS                                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 🎤 WhisperKit large-v3                  1.5 GB  │   │
│  │    Voice recognition                            │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🌍 Polish                               312 MB  │   │
│  │    Apple Translation                            │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ 🌍 Spanish                              287 MB  │   │
│  │    Apple Translation                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Swipe left on any item to delete                       │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │            Clear All Local Models               │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ℹ️ Translation languages are managed by iOS.          │
│     Go to Settings → Translate to remove them.          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Navigation Flow

```
Settings
│
├── AI CLOUD MODELS
│   ├── [Provider Row] → AIProviderEditorSheet (existing)
│   └── + Add Cloud Provider → AddAIProviderSheet (existing)
│
├── AI LOCAL MODELS
│   ├── On-Device Voice → WhisperKitSetupView
│   │                     └── Download → ModelDownloadView
│   ├── Apple Intelligence → AppleIntelligenceSetupView
│   ├── Apple Translation → AppleTranslationSetupView
│   │                       └── Open Settings (deep link)
│   ├── Ollama → OllamaConfigSheet (existing)
│   ├── LM Studio → LMStudioConfigSheet (existing)
│   └── + Add Local Model → AddLocalModelSheet
│                           ├── Voice Recognition → WhisperKitSetupView
│                           ├── Apple Intelligence → AppleIntelligenceSetupView
│                           ├── Translation → AppleTranslationSetupView
│                           ├── Ollama → OllamaConfigSheet
│                           └── LM Studio → LMStudioConfigSheet
│
├── DEFAULT PROVIDERS → DefaultProvidersView
│   ├── Transcription picker
│   ├── Translation picker
│   └── Power Mode LLM picker
│
├── PRIVACY
│   └── Force Privacy Mode toggle
│
└── (gear icon) → LocalModelStorageView
```

---

## Implementation Phases

After UI mockups are approved:

```
10a: Settings Restructure
├── Rename "AI Models" → "AI Cloud Models"
├── Create "AI Local Models" section
├── Create AddLocalModelSheet
└── Update navigation

10b: WhisperKit Integration
├── Add WhisperKit SPM dependency
├── Create WhisperKitService
├── Device capability detection
├── Model download/management
└── WhisperKitSetupView implementation

10c: Apple Intelligence Integration
├── Availability detection
├── AppleIntelligenceService
└── AppleIntelligenceSetupView implementation

10d: Apple Translation Integration
├── TranslationSession wrapper
├── Language availability detection
└── AppleTranslationSetupView implementation

10e: Default Provider Selection
├── ProviderDefaults model
├── DefaultProvidersView implementation
├── Provider resolution logic
└── Offline fallback handling

10f: Power Mode Provider Override
├── Add providerOverride to PowerMode model
├── Update PowerModeEditorView
├── Update PowerModeListView
└── Update PowerModeOrchestrator

10g: Privacy Mode
├── forcePrivacyMode toggle
├── Provider picker filtering
├── Keyboard status indicators
└── Auto-fallback when offline

10h: Storage Management
├── LocalModelStorageView
├── Storage calculation
└── Delete model functionality
```

---

## Verification Checklist

### Phase 10.0: UI Mock-ups
- [ ] Settings main view with Cloud/Local sections
- [ ] Add Local Model sheet
- [ ] WhisperKit setup (all device variants)
- [ ] Download progress view
- [ ] Apple Intelligence setup (available/unavailable)
- [ ] Apple Translation setup
- [ ] Default Providers view
- [ ] Power Mode editor with provider override
- [ ] Power Mode list with provider indicators
- [ ] Privacy Mode toggle states
- [ ] Keyboard status indicators
- [ ] Storage management view
