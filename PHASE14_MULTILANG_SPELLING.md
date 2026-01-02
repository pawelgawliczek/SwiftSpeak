# Phase 14: Multi-Language Spelling Correction

## Overview
Comprehensive spelling correction for all 13 languages supported by SwiftSpeak, with bundled dictionaries, optional AI grammar correction per-mode, and language sync with transcription settings.

## Status: IN PROGRESS

## Requirements
- **Languages**: All 13 (EN, ES, FR, DE, IT, PT, ZH, JA, KO, AR, ARZ, RU, PL)
- **Level**: Medium by default (typos + suggestions), optional AI grammar per-mode
- **Detection**: Sync with transcription language; auto-detect when that option is selected
- **Approach**: Bundle dictionaries for quality over memory
- **CJK**: UITextChecker fallback (defer IME to future phase)
- **Grammar UX**: Inline suggestion in prediction row
- **Fallback**: UITextChecker as secondary check for all languages

## Architecture

### Language Categories
| Category | Languages | Approach |
|----------|-----------|----------|
| **Latin** | EN, ES, FR, DE, IT, PT, PL | SymSpell + phonetic + UITextChecker fallback |
| **Cyrillic** | RU | SymSpell + UITextChecker fallback |
| **Arabic** | AR, ARZ | SymSpell + RTL handling + UITextChecker fallback |
| **CJK** | ZH, JA, KO | UITextChecker only (defer IME to future) |

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  SpellingManager                         │
│  - Current language (synced with transcription)          │
│  - Language detection for auto mode                      │
│  - Grammar correction toggle per mode                    │
└─────────────────────────────────┬───────────────────────┘
                                  │
       ┌──────────────────────────┼──────────────────────────┐
       ↓                          ↓                          ↓
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ MultiLang-   │         │ Language-    │         │ AI Grammar   │
│ SymSpell     │         │ Specific     │         │ Corrector    │
│              │         │ Services     │         │ (optional)   │
└──────────────┘         └──────────────┘         └──────────────┘
       │                        │                        │
       ↓                        ↓                        ↓
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ UITextChecker│         │ Polish/      │         │ Context      │
│ Wrapper      │         │ Spanish/     │         │ Integration  │
│ (fallback)   │         │ French/      │         │ (PromptCtx)  │
└──────────────┘         │ Russian/     │         └──────────────┘
                         │ Arabic       │
                         └──────────────┘
```

## Implementation Phases

### Phase 14a: Dictionary Infrastructure - COMPLETE
**Status:** ✅ Complete

**Files:**
- [x] `SwiftSpeakKeyboard/Services/Spelling/SpellingLanguage.swift` - Language enum
- [x] `SwiftSpeakKeyboard/Services/Spelling/SpellingManager.swift` - Main coordinator
- [x] `SwiftSpeakKeyboard/Services/Spelling/MultiLangSymSpell.swift` - Language-aware SymSpell
- [x] `SwiftSpeakKeyboard/Services/Spelling/UITextCheckerWrapper.swift` - Apple fallback
- [x] `SwiftSpeakKeyboard/Services/Spelling/LanguageDetector.swift` - N-gram detection

**Tasks:**
- [x] Create `SpellingLanguage` enum with capabilities
- [x] Create `SpellingManager` as main coordinator
- [x] Create `MultiLangSymSpell` with lazy dictionary loading
- [x] Create `UITextCheckerWrapper` for CJK and fallback
- [ ] Refactor existing `AutocorrectService` to use new system

### Phase 14b: Frequency Dictionaries - COMPLETE
**Status:** ✅ Complete

**Files (total ~8.7MB):**
- [x] `en_frequency.txt` (1.3MB, ~82K words from SymSpell)
- [x] `es_frequency.txt` (643KB, 50K words from OpenSubtitles)
- [x] `fr_frequency.txt` (1.6MB, ~100K words from SymSpell)
- [x] `de_frequency.txt` (1.7MB, ~100K words from SymSpell)
- [x] `it_frequency.txt` (638KB, 50K words from OpenSubtitles)
- [x] `pt_frequency.txt` (637KB, 50K words from OpenSubtitles)
- [x] `pl_frequency.txt` (661KB, 50K words from OpenSubtitles)
- [x] `ru_frequency.txt` (975KB, 50K words from OpenSubtitles)
- [x] `ar_frequency.txt` (787KB, 50K words from OpenSubtitles)

**Sources:**
- English: [SymSpell frequency_dictionary_en_82_765.txt](https://github.com/wolfgarbe/SymSpell)
- French/German: [SymSpell fr-100k.txt, de-100k.txt](https://github.com/wolfgarbe/SymSpell/tree/master/SymSpell.FrequencyDictionary)
- Spanish/Italian/Portuguese/Russian/Polish/Arabic: [OpenSubtitles FrequencyWords](https://github.com/hermitdave/FrequencyWords)

### Phase 14c: Language-Specific Services - COMPLETE
**Status:** ✅ Complete

**Files:**
- [x] `PolishAutocorrectService.swift` - Diacritics + proper nouns (existing)
- [x] `SpanishAutocorrectService.swift` - Accent restoration
- [x] `FrenchAutocorrectService.swift` - Accent/elision rules
- [x] `RussianAutocorrectService.swift` - Proper nouns + yoisation (ё)
- [x] `ArabicAutocorrectService.swift` - Ligatures/RTL

**Tasks:**
- [x] Spanish: Accent restoration (e.g., "como" → "cómo" in questions)
- [x] French: Accent restoration + elision (e.g., "l'homme")
- [x] Russian: Proper noun capitalization + ё handling
- [x] Arabic: Common diacritic patterns + ligature handling

### Phase 14d: Language Sync & Detection - PENDING
**Status:** ⏳ Pending

**Files:**
- [ ] `SwiftSpeakKeyboard/Services/Spelling/LanguageDetector.swift`
- [ ] `SwiftSpeakKeyboard/Models/KeyboardSettings.swift` (modify)
- [ ] `SwiftSpeakKeyboard/KeyboardView.swift` (modify)

**Tasks:**
- [ ] Sync `autocorrectLanguage` with `spokenLanguage` by default
- [ ] Implement n-gram based language detection
- [ ] Show current spelling language in quick settings
- [ ] Handle language switching at runtime

### Phase 14e: AI Grammar Correction - PENDING
**Status:** ⏳ Pending

**Files:**
- [ ] `SwiftSpeakKeyboard/Services/AI/GrammarCorrector.swift`
- [ ] `SwiftSpeak/Shared/Models/FormattingMode.swift` (modify)
- [ ] `SwiftSpeak/Shared/Models/PowerMode.swift` (modify)
- [ ] `SwiftSpeak/Services/Orchestration/PromptContext.swift` (modify)
- [ ] `SwiftSpeakKeyboard/Components/KeyboardMode/PredictionRow.swift` (modify)

**Tasks:**
- [ ] Add `enableGrammarCorrection: Bool` to FormattingMode/PowerMode
- [ ] Create `GrammarCorrector` service
- [ ] Integrate grammar rules with context instructions
- [ ] Show grammar suggestion in prediction row
- [ ] Debounce grammar checks (pause or sentence end)

**Grammar Integration:**
```swift
// Grammar rules appended to context instructions
systemPrompt += """

ADDITIONAL GRAMMAR RULES:
- Fix ONLY clear grammar errors
- Make MINIMAL changes to the text
- Preserve the user's word choices and meaning
- Only fix: subject-verb agreement, tense consistency, article usage, punctuation
- Do NOT change: vocabulary, style, or structure
"""
```

## File Structure

```
SwiftSpeakKeyboard/
├── Services/
│   ├── Spelling/
│   │   ├── SpellingLanguage.swift              # Language enum with capabilities
│   │   ├── SpellingManager.swift               # Main coordinator
│   │   ├── MultiLangSymSpell.swift             # Language-aware SymSpell
│   │   ├── UITextCheckerWrapper.swift          # Apple fallback + CJK
│   │   ├── LanguageDetector.swift              # N-gram detection
│   │   ├── PolishAutocorrectService.swift      # Existing - diacritics
│   │   ├── SpanishAutocorrectService.swift     # Accent restoration
│   │   ├── FrenchAutocorrectService.swift      # Accent/elision
│   │   ├── RussianAutocorrectService.swift     # Proper nouns + ё
│   │   └── ArabicAutocorrectService.swift      # Ligatures/RTL
│   └── AI/
│       └── GrammarCorrector.swift              # LLM-based grammar
├── Resources/
│   └── Dictionaries/
│       ├── en_frequency.txt
│       ├── es_frequency.txt
│       ├── fr_frequency.txt
│       ├── de_frequency.txt
│       ├── it_frequency.txt
│       ├── pt_frequency.txt
│       ├── pl_frequency.txt
│       ├── ru_frequency.txt
│       └── ar_frequency.txt
```

## Settings UI Changes

1. **Keyboard Settings → Autocorrect Language**
   - "Sync with transcription language" (default)
   - "Auto-detect while typing"
   - Manual language list

2. **Mode Editor (FormattingMode/PowerMode)**
   - New toggle: "Enable AI Grammar Correction"
   - Description: "Uses AI to fix grammar with minimal changes"

## Bundle Size Impact
- Each frequency dictionary: 1-5 MB (depending on language)
- Total additional size: ~20-30 MB for all 9 dictionaries
- Lazy loading prevents memory bloat at runtime

## Estimated Effort

| Phase | Effort | Status |
|-------|--------|--------|
| Phase 14a: Dictionary Infrastructure | 2-3 days | 🔄 In Progress |
| Phase 14b: Frequency Dictionaries | 1 day | ⏳ Pending |
| Phase 14c: Language-Specific Services | 2 days | ⏳ Pending |
| Phase 14d: Language Sync & Detection | 1 day | ⏳ Pending |
| Phase 14e: AI Grammar Correction | 2 days | ⏳ Pending |

**Total: ~8-9 days**

## Testing Strategy
1. Unit tests for each language-specific service
2. Integration tests for language switching
3. UI tests for grammar correction flow
4. Manual testing with native speakers for quality validation

## Notes
- CJK languages use UITextChecker only - no bundled dictionaries
- Grammar correction merges with existing context instructions
- Egyptian Arabic uses Arabic dictionary as fallback
