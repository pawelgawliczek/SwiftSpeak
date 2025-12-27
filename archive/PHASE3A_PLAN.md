# SwiftSpeak Phase 3a: Provider Help & Language Guidance

> **Execution guide for Phase 3a.** Follow this document step-by-step.
> Master project documentation: `/Users/pawelgawliczek/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`

## Current Status

### Phase 3A-1: UX Mockups - COMPLETE
All UI components and data models have been created with SwiftUI Previews:
- [x] Data models (ProviderLanguageSupport, ProviderHelpContent)
- [x] ProviderHelpSheet - Setup guide bottom sheet
- [x] ProviderStatusDashboard - At-a-glance status card
- [x] ProviderComparisonView - Provider selection guide
- [x] LanguageSupportView - Language compatibility matrix
- [x] SmartLanguagePicker - Enhanced language dropdown
- [x] IncompatibilityWarning - Warning banners

### Phase 3A-2: Integration - PENDING
Integration with existing views still needs to be done:
- [ ] Add help (?) button to provider editor in SettingsView
- [ ] Add status dashboard to Settings
- [ ] Add language warnings to Settings
- [ ] Add "Help me choose" navigation links
- [ ] Add language warning to keyboard

---

## Overview

Reduce user friction when setting up multiple AI providers by adding contextual help, provider comparisons, and language compatibility guidance.

**Goal:** Users should be able to:
1. Understand which provider to choose for their needs
2. Know which providers support their target language
3. Get step-by-step setup help for any provider
4. See warnings before misconfiguring incompatible provider/language combos

**Scope:**
- Contextual help sheets per provider
- Provider status dashboard
- Provider comparison/recommendation view
- Language-provider compatibility matrix
- Smart language dropdown with compatibility indicators
- Incompatibility warnings

---

## User Decisions

| Decision | Choice |
|----------|--------|
| Help content location | Bottom sheets (not separate views) |
| Language data source | Hardcoded initially, can fetch from API later |
| Quality ratings | Curated by us (not user-generated) |

---

## Data Models

### Step 1: Create ProviderLanguageSupport Model

- [x] **Status: Complete**

**Create:** `Shared/ProviderLanguageSupport.swift`

```swift
/// Language support level for a provider
enum LanguageSupportLevel: String, Codable {
    case excellent    // Native-level quality
    case good         // Minor occasional errors
    case limited      // Works but not recommended
    case unsupported  // Does not work

    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .limited: return "exclamationmark.triangle.fill"
        case .unsupported: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .limited: return .orange
        case .unsupported: return .red
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .limited: return "Limited"
        case .unsupported: return "Not Supported"
        }
    }
}

/// Provider capabilities for a specific language
struct ProviderLanguageCapability {
    let provider: AIProvider
    let language: Language
    let transcriptionSupport: LanguageSupportLevel
    let translationSupport: LanguageSupportLevel
    let notes: String?  // e.g., "Best for formal Japanese"
}

/// Static data store for language support info
struct ProviderLanguageDatabase {
    /// Get support level for a provider + language + capability combo
    static func supportLevel(
        provider: AIProvider,
        language: Language,
        for capability: ProviderUsageCategory
    ) -> LanguageSupportLevel

    /// Get all providers that support a language for a capability
    static func providers(
        supporting language: Language,
        for capability: ProviderUsageCategory,
        minimumLevel: LanguageSupportLevel = .limited
    ) -> [AIProvider]

    /// Get recommended provider for a language
    static func recommendedProvider(
        for language: Language,
        capability: ProviderUsageCategory
    ) -> AIProvider?

    /// Get all languages supported by a provider
    static func languages(
        supportedBy provider: AIProvider,
        for capability: ProviderUsageCategory,
        minimumLevel: LanguageSupportLevel = .limited
    ) -> [Language]
}
```

### Step 2: Create ProviderHelpContent Model

- [x] **Status: Complete**

**Create:** `Shared/ProviderHelpContent.swift`

```swift
/// Help content for setting up a provider
struct ProviderSetupGuide {
    let provider: AIProvider
    let steps: [SetupStep]
    let tips: [String]
    let estimatedCost: String          // e.g., "~$0.006/minute"
    let freeCredits: String?           // e.g., "$5 for new accounts"
    let bestFor: [String]              // e.g., ["Transcription", "Translation"]
    let websiteURL: URL?
    let apiKeyURL: URL?

    struct SetupStep {
        let number: Int
        let title: String
        let description: String?
        let actionURL: URL?            // Deep link if applicable
    }
}

/// Static database of setup guides
struct ProviderHelpDatabase {
    static func guide(for provider: AIProvider) -> ProviderSetupGuide
    static var allGuides: [ProviderSetupGuide]
}
```

### Step 3: Populate Language Support Data

- [x] **Status: Complete**

**File:** `Shared/ProviderLanguageSupport.swift`

Populate the static data for all provider/language combinations:

| Provider | Transcription Languages | Translation Languages |
|----------|------------------------|----------------------|
| OpenAI Whisper | 50+ (excellent) | N/A (use GPT) |
| OpenAI GPT | N/A | 50+ (excellent) |
| Anthropic | N/A | 30+ (good-excellent) |
| Google | N/A | 100+ (excellent) |
| Deepgram | 30+ (varies) | N/A |
| ElevenLabs | 29 (good) | N/A |
| Local/Ollama | Model-dependent | Model-dependent |

**Key language support notes to encode:**
- Japanese: All providers good, OpenAI best for keigo
- Polish: OpenAI/Google excellent, Anthropic good, Deepgram limited
- Vietnamese: OpenAI/Google good, others limited
- Arabic: OpenAI excellent (RTL), others vary
- Hindi: OpenAI/Google good, Deepgram limited

### Step 4: Populate Provider Setup Guides

- [x] **Status: Complete**

**File:** `Shared/ProviderHelpContent.swift`

Create setup guides for each provider:

**OpenAI:**
1. Go to platform.openai.com
2. Sign in or create account
3. Navigate to API Keys section
4. Click "Create new secret key"
5. Copy and paste here

Tips: "$5 free credits for new accounts", "Best all-around choice"

**Anthropic:**
1. Go to console.anthropic.com
2. Create account (requires phone verification)
3. Go to API Keys
4. Create new key
5. Copy and paste here

Tips: "Best for nuanced AI responses", "No free credits"

**Google:**
1. Go to aistudio.google.com
2. Sign in with Google account
3. Click "Get API Key"
4. Create key in new/existing project
5. Copy and paste here

Tips: "Free tier available", "Best language coverage"

**Deepgram:**
1. Go to deepgram.com
2. Create free account
3. Go to Dashboard → API Keys
4. Create new key
5. Copy and paste here

Tips: "$200 free credits", "Fast transcription"

**ElevenLabs:**
1. Go to elevenlabs.io
2. Create account
3. Go to Profile → API Keys
4. Copy your API key

Tips: "2.5 hours free/month", "Premium voice quality"

**Local (Ollama):**
1. Install Ollama from ollama.ai
2. Run `ollama pull llama3.2`
3. Ollama runs on localhost:11434
4. No API key needed

Tips: "100% free", "Requires Mac/PC running", "Privacy-focused"

---

## UI Components

### Step 5: Create ProviderHelpSheet View

- [x] **Status: Complete**

**Create:** `Views/Components/ProviderHelpSheet.swift`

Bottom sheet showing setup guide for a provider:

```swift
struct ProviderHelpSheet: View {
    let provider: AIProvider
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Header with provider icon and name
        // Numbered setup steps
        // Tips section
        // Cost estimate
        // "Open Website" button
        // "Get API Key" button
    }
}
```

**Design:**
```
┌─────────────────────────────────────────┐
│ ━━━━━  (drag indicator)                 │
│                                         │
│ [Icon] Setting up OpenAI                │
│                                         │
│ ─────────────────────────────────────── │
│                                         │
│ 1  Go to platform.openai.com            │
│    ○───────────────────────────         │
│                                         │
│ 2  Sign in or create account            │
│    ○───────────────────────────         │
│                                         │
│ 3  Navigate to API Keys section         │
│    ○───────────────────────────         │
│                                         │
│ 4  Click "Create new secret key"        │
│    ○───────────────────────────         │
│                                         │
│ 5  Copy the key and paste here          │
│    ●───────────────────────────         │
│                                         │
│ ─────────────────────────────────────── │
│                                         │
│ 💡 TIPS                                 │
│ • $5 free credits for new accounts      │
│ • Best all-around provider choice       │
│                                         │
│ 💰 Estimated cost: ~$0.006/minute       │
│                                         │
│ [    Open OpenAI Website    ]           │
│ [      Get API Key →        ]           │
│                                         │
└─────────────────────────────────────────┘
```

### Step 6: Create ProviderStatusDashboard View

- [x] **Status: Complete**

**Create:** `Views/Components/ProviderStatusDashboard.swift`

Shows at-a-glance what's configured:

```swift
struct ProviderStatusDashboard: View {
    @ObservedObject var settings: SharedSettings

    var body: some View {
        // "Your Setup" card
        // Status for each capability (transcription, translation, power mode)
        // Checkmark if configured, warning if not
        // "Help me choose" button
    }
}
```

**Design:**
```
┌─────────────────────────────────────────┐
│ YOUR SETUP                              │
│                                         │
│ 🎤 Transcription     ✅ OpenAI          │
│ 🌍 Translation       ✅ OpenAI          │
│ ⚡ Power Mode        ⚠️ Not configured  │
│                                         │
│ [+ Add Provider]    [? Help me choose]  │
└─────────────────────────────────────────┘
```

### Step 7: Create ProviderComparisonView

- [x] **Status: Complete**

**Create:** `Views/ProviderComparisonView.swift`

Help users choose the right provider:

```swift
struct ProviderComparisonView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // "What do you need?" section
                // Use case cards (Just Transcription, Full Power, etc.)
                // Each card shows recommended provider + Set Up button
            }
            .navigationTitle("Choose a Provider")
        }
    }
}
```

### Step 8: Create LanguageSupportView

- [x] **Status: Complete**

**Create:** `Views/LanguageSupportView.swift`

Language-provider compatibility matrix:

```swift
struct LanguageSupportView: View {
    @State private var searchText = ""
    @ObservedObject var settings: SharedSettings

    var body: some View {
        NavigationStack {
            List {
                // Search bar
                // Popular languages section
                // All languages section
                // Each row shows language + provider support icons
            }
            .navigationTitle("Language Support")
            .searchable(text: $searchText)
        }
    }
}
```

### Step 9: Create LanguageProviderRecommendation Sheet

- [x] **Status: Complete** (merged into LanguageSupportView as LanguageDetailSheet)

**Create:** `Views/Components/LanguageProviderRecommendation.swift`

Shown when user selects a language with limited support:

```swift
struct LanguageProviderRecommendation: View {
    let language: Language
    let capability: ProviderUsageCategory
    @ObservedObject var settings: SharedSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Language flag + name
        // "Best providers for [language]" header
        // Ranked list of providers with quality stars
        // "Set Up" buttons
    }
}
```

### Step 10: Create SmartLanguagePicker

- [x] **Status: Complete**

**Modify:** `Views/SettingsView.swift` (or create component)

Enhanced language picker showing provider compatibility:

```swift
struct SmartLanguagePicker: View {
    @Binding var selection: Language
    let currentProvider: AIProvider
    let capability: ProviderUsageCategory

    var body: some View {
        // Picker with custom label showing compatibility
        // Each option shows:
        //   - Flag + Language name
        //   - Support level indicator (✅ All, ⚠️ Limited, etc.)
        // Footer showing current provider compatibility
    }
}
```

### Step 11: Create IncompatibilityWarning View

- [x] **Status: Complete**

**Create:** `Views/Components/IncompatibilityWarning.swift`

Warning banner when provider doesn't support selected language:

```swift
struct IncompatibilityWarning: View {
    let provider: AIProvider
    let language: Language
    let capability: ProviderUsageCategory
    let recommendedProvider: AIProvider?
    let onSwitchProvider: (AIProvider) -> Void

    var body: some View {
        // Warning icon + message
        // "Switch to [recommended]" button
    }
}
```

**Design:**
```
┌─────────────────────────────────────────┐
│ ⚠️ Deepgram doesn't support Polish      │
│                                         │
│ Translation will fail. Switch to:       │
│ • OpenAI (recommended)                  │
│ • Google Gemini                         │
│                                         │
│ [Switch to OpenAI]                      │
└─────────────────────────────────────────┘
```

---

## Integration Points

### Step 12: Add Help Button to Provider Editor

- [ ] **Status: Pending**

**Modify:** `Views/SettingsView.swift`

Add (?) button that opens ProviderHelpSheet:

```swift
// In provider editor header
HStack {
    ProviderIcon(provider: config.provider)
    Text(config.provider.displayName)
    Spacer()
    Button(action: { showHelp = true }) {
        Image(systemName: "questionmark.circle")
    }
}
.sheet(isPresented: $showHelp) {
    ProviderHelpSheet(provider: config.provider)
}
```

### Step 13: Add Status Dashboard to Settings

- [ ] **Status: Pending**

**Modify:** `Views/SettingsView.swift`

Add ProviderStatusDashboard at top of AI Providers section:

```swift
Section {
    ProviderStatusDashboard(settings: settings)
} header: {
    Text("AI Providers")
}
```

### Step 14: Add Language Warnings to Settings

- [ ] **Status: Pending**

**Modify:** `Views/SettingsView.swift`

Check compatibility when language or provider changes:

```swift
// In Translation section
if let warning = checkLanguageCompatibility() {
    IncompatibilityWarning(
        provider: settings.selectedTranslationProvider,
        language: settings.selectedTargetLanguage,
        capability: .translation,
        recommendedProvider: warning.recommended,
        onSwitchProvider: { provider in
            settings.selectedTranslationProvider = provider
        }
    )
}
```

### Step 15: Add "Help me choose" Navigation

- [ ] **Status: Pending**

**Modify:** `Views/SettingsView.swift`

Add navigation to comparison and language support views:

```swift
Section {
    NavigationLink(destination: ProviderComparisonView()) {
        Label("Help me choose a provider", systemImage: "questionmark.circle")
    }
    NavigationLink(destination: LanguageSupportView()) {
        Label("Language support guide", systemImage: "globe")
    }
} header: {
    Text("Help")
}
```

---

## Keyboard Integration

### Step 16: Add Language Warning to Keyboard

- [ ] **Status: Pending**

**Modify:** `SwiftSpeakKeyboard/KeyboardView.swift`

Show subtle warning if selected language may not work:

```swift
// Near language dropdown
if !isLanguageSupported(settings.selectedTargetLanguage) {
    Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .font(.caption)
}
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `Shared/ProviderLanguageSupport.swift` | Language support data model + database |
| `Shared/ProviderHelpContent.swift` | Setup guide data model + content |
| `Views/Components/ProviderHelpSheet.swift` | Setup guide bottom sheet |
| `Views/Components/ProviderStatusDashboard.swift` | At-a-glance status card |
| `Views/Components/LanguageProviderRecommendation.swift` | Language-specific recommendations |
| `Views/Components/IncompatibilityWarning.swift` | Warning banner |
| `Views/Components/SmartLanguagePicker.swift` | Enhanced language dropdown |
| `Views/ProviderComparisonView.swift` | Provider comparison/selection |
| `Views/LanguageSupportView.swift` | Language support matrix |

## Files to Modify

| File | Changes |
|------|---------|
| `Views/SettingsView.swift` | Add dashboard, help buttons, warnings, navigation |
| `SwiftSpeakKeyboard/KeyboardView.swift` | Add language compatibility indicator |
| `Shared/Models.swift` | Add any needed enums |

---

## Implementation Order

```
Step 1-4 (Data Models) ─────────────────────────────┐
                                                     │
Step 5 (ProviderHelpSheet) ──────────────────────────┼──→ Step 12 (Integration)
                                                     │
Step 6 (StatusDashboard) ────────────────────────────┼──→ Step 13 (Integration)
                                                     │
Step 7 (ComparisonView) ─────────────────────────────┼──→ Step 15 (Navigation)
                                                     │
Step 8 (LanguageSupportView) ────────────────────────┤
                                                     │
Step 9 (LanguageRecommendation) ─────────────────────┤
                                                     │
Step 10 (SmartLanguagePicker) ───────────────────────┼──→ Step 14 (Warnings)
                                                     │
Step 11 (IncompatibilityWarning) ────────────────────┤
                                                     │
                                                     └──→ Step 16 (Keyboard)
```

**Recommended order:**
1. Data models first (Steps 1-4) - foundation for everything
2. Help sheet (Step 5) - highest impact, simplest
3. Status dashboard (Step 6) - quick win
4. Warnings (Steps 10-11, 14) - prevents user errors
5. Comparison/Language views (Steps 7-9, 15) - nice to have
6. Keyboard indicator (Step 16) - polish

---

## Verification Checklist

After implementation, verify:

- [ ] Help (?) button appears next to each provider in editor
- [ ] Help sheet shows correct steps for each provider
- [ ] "Get API Key" button opens correct URL for each provider
- [ ] Status dashboard shows correct configuration state
- [ ] Status dashboard updates when providers are added/removed
- [ ] Language dropdown shows compatibility indicators
- [ ] Warning appears when selecting incompatible language/provider
- [ ] "Switch to [provider]" button works in warning
- [ ] Provider comparison view shows all use cases
- [ ] Language support view shows all languages
- [ ] Language support search works
- [ ] Keyboard shows warning indicator for incompatible language

---

## Sample Language Support Data

### Transcription Support (Whisper/Deepgram/ElevenLabs)

| Language | OpenAI | Deepgram | ElevenLabs |
|----------|--------|----------|------------|
| English | Excellent | Excellent | Excellent |
| Spanish | Excellent | Excellent | Good |
| French | Excellent | Excellent | Good |
| German | Excellent | Excellent | Good |
| Japanese | Excellent | Good | Good |
| Korean | Excellent | Good | Good |
| Chinese | Excellent | Good | Good |
| Polish | Excellent | Limited | Limited |
| Vietnamese | Excellent | Limited | Limited |
| Arabic | Excellent | Good | Limited |
| Hindi | Excellent | Good | Limited |

### Translation Support (GPT/Claude/Gemini)

| Language | OpenAI | Anthropic | Google |
|----------|--------|-----------|--------|
| Spanish | Excellent | Excellent | Excellent |
| French | Excellent | Excellent | Excellent |
| German | Excellent | Excellent | Excellent |
| Japanese | Excellent | Good | Excellent |
| Korean | Excellent | Good | Excellent |
| Chinese | Excellent | Good | Excellent |
| Polish | Excellent | Good | Excellent |
| Vietnamese | Good | Limited | Excellent |
| Arabic | Excellent | Good | Excellent |
| Hindi | Good | Limited | Excellent |
| Thai | Good | Limited | Excellent |
| Burmese | Limited | Unsupported | Good |

---

## Notes

- Language support data should be conservative (underestimate rather than overestimate)
- Provider setup steps should be verified against current provider websites
- API key URLs may change - use provider's main API page as fallback
- Consider adding "Last updated" date to help content
- Local/Ollama language support depends on model - show "varies by model"
