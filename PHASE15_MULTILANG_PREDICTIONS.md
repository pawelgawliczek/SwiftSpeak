# Phase 15: Multi-Language Predictions System

## Overview
Add multi-language support to the keyboard prediction system (word suggestions in the 3-slot prediction row). Currently English-only, need to support all 13 languages.

## Current State Analysis

### What Works
- `PredictionEngine` orchestrates predictions from multiple sources
- `PersonalDictionary` learns from user transcriptions (language-agnostic)
- `PredictionFeedback` tracks user acceptance/rejection (language-agnostic)
- `KeyboardSettings.spokenLanguage` already tracks current language
- AI Sentence Predictions (sparkles button) work in any language via LLM

### What's English-Only
| Component | Issue |
|-----------|-------|
| `NGramPredictor` | 165+ hardcoded English bigrams/trigrams |
| `ContextAwarePredictions` | English vocabulary for email/messaging/code contexts |
| `NGramPredictor.tokenize()` | Regex `[^a-z\\s']` drops accented chars |
| `PersonalDictionary` | Regex `[a-zA-Z]+` misses ą, ę, ó, ñ, é |
| Capitalization | English abbreviations only (Mr., Dr., etc.) |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PredictionRow.swift                          │
│  └─ Gets language from KeyboardSettings.spokenLanguage         │
└────────────────────┬────────────────────────────────────────────┘
                     │ language: "pl"
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│              PredictionEngine.getPredictions()                  │
│                     (language-aware)                             │
└────────────────────┬────────────────────────────────────────────┘
         ┌───────────┼───────────┬───────────────┐
         ▼           ▼           ▼               ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
│ NGramPredictor│ │Personal  │ │Context   │ │Prediction   │
│ (per-language)│ │Dictionary│ │Awareness │ │Feedback     │
│              │ │(Unicode) │ │(per-lang)│ │(unchanged)  │
└──────────────┘ └──────────┘ └──────────┘ └──────────────┘
```

## Implementation Plan

### Phase 1: Unicode Fixes (P0)
**Goal:** Fix regex patterns so Polish/Spanish/French words are captured

**Files:**
- `NGramPredictor.swift:155-161` - `tokenize()` method
- `PersonalDictionary.swift:183` - word extraction

**Changes:**
```swift
// Before (English only)
.replacingOccurrences(of: "[^a-z\\s']", with: " ", options: .regularExpression)

// After (Unicode letters)
.replacingOccurrences(of: "[^\\p{L}\\s']", with: " ", options: .regularExpression)
```

### Phase 2: Language Parameter Threading (P0)
**Goal:** Pass language through prediction pipeline

**Files to modify:**
1. `PredictionRow.swift:155-159` - Get language, pass to engine
2. `PredictionEngine.swift` - Add language param to `getPredictions()` and `localPredictions()`
3. `NGramPredictor.swift` - Add language param to `predict()` and `predictCompletion()`
4. `ContextAwarePredictions.swift` - Add language param to methods

**PredictionRow change:**
```swift
let settings = KeyboardSettings.load()
let language = settings.spokenLanguage

let newPredictions = await Self.predictionEngine.getPredictions(
    for: predictionContext,
    activeContext: activeContextName,
    language: language  // NEW
)
```

### Phase 3: Multi-Language N-Grams (P1)
**Goal:** Load language-specific n-gram models

**New file:** `SwiftSpeakKeyboard/Resources/NGrams/` with JSON files:
- `en_ngrams.json` (move existing hardcoded data)
- `pl_ngrams.json` (Polish)
- `es_ngrams.json` (Spanish)
- `fr_ngrams.json` (French)
- `de_ngrams.json` (German)
- `ru_ngrams.json` (Russian)

**NGramPredictor changes:**
```swift
// Per-language storage
private var ngramsByLanguage: [String: NGramData] = [:]

struct NGramData {
    var bigrams: [String: [String: Int]]
    var trigrams: [String: [String: Int]]
    var unigrams: [String: Int]
}

func loadNGrams(for language: String) {
    // Lazy load from JSON file
}
```

**N-gram data sources:**
- Google Ngram Viewer exports (simplified)
- OpenSubtitles word pairs
- Common phrase databases per language

### Phase 4: Multi-Language Context Vocabulary (P1)
**Goal:** Language-specific predictions for email/messaging contexts

**New file:** `SwiftSpeakKeyboard/Resources/ContextVocab/` with JSON:
- `en_context.json`
- `pl_context.json`
- `es_context.json`
- etc.

**Structure:**
```json
{
  "email": {
    "vocabulary": {"dziękuję": 500, "pozdrawiam": 450, "proszę": 400},
    "starters": ["Dzień dobry", "Szanowny Panie", "Dziękuję za"],
    "patterns": ["szanowny", "pozdrawiam", "z poważaniem"]
  },
  "messaging": {
    "vocabulary": {"cześć": 500, "co słychać": 450, "ok": 400},
    "starters": ["Cześć", "Hej", "Co tam"],
    "patterns": ["hej", "nara", "spoko"]
  }
}
```

### Phase 5: Language-Specific Capitalization (P2)
**Goal:** Correct abbreviation handling per language

**PredictionEngine changes:**
```swift
private let abbreviationsByLanguage: [String: [String]] = [
    "en": ["mr.", "mrs.", "ms.", "dr.", "prof.", "etc.", "vs."],
    "pl": ["dr.", "mgr.", "inż.", "prof.", "św.", "ul.", "nr."],
    "de": ["hr.", "fr.", "dr.", "prof.", "str.", "nr."],
    "es": ["sr.", "sra.", "dr.", "dra.", "prof.", "etc."],
    "fr": ["m.", "mme.", "dr.", "prof.", "etc."]
]
```

## File Changes Summary

| File | Changes |
|------|---------|
| `PredictionRow.swift` | Pass language to engine |
| `PredictionEngine.swift` | Add language param, route to lang-specific data |
| `NGramPredictor.swift` | Multi-lang storage, Unicode tokenization, lazy loading |
| `PersonalDictionary.swift` | Unicode regex fix |
| `ContextAwarePredictions.swift` | Language param, load from JSON |
| `Resources/NGrams/*.json` | NEW: N-gram data per language |
| `Resources/ContextVocab/*.json` | NEW: Context vocab per language |

## Languages Priority

| Priority | Languages | Reason |
|----------|-----------|--------|
| P0 | EN, PL | Already working (EN), user testing (PL) |
| P1 | ES, FR, DE | Common European languages |
| P2 | RU, IT, PT | Secondary European |
| P3 | AR, ZH, JA, KO | Complex scripts (defer to UITextChecker) |

## Bundle Size Impact
- Each language JSON: ~50-100KB
- Total for 9 languages: ~500KB-1MB
- Lazy loading prevents memory bloat

## Testing Strategy
1. Unit tests for Unicode tokenization
2. Unit tests for language-specific n-gram loading
3. Integration tests for Polish/Spanish/French predictions
4. Manual testing with native speakers

## Estimated Effort

| Phase | Effort |
|-------|--------|
| Phase 1: Unicode Fixes | 0.5 days |
| Phase 2: Language Threading | 0.5 days |
| Phase 3: Multi-Lang N-Grams | 2 days (including data sourcing) |
| Phase 4: Context Vocabulary | 1.5 days |
| Phase 5: Capitalization | 0.5 days |

**Total: ~5 days**
