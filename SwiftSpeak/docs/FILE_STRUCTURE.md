# File Structure

Detailed file tree for SwiftSpeak project.

```
SwiftSpeak/
├── SwiftSpeak.xcodeproj
├── IMPLEMENTATION_PLAN.md
├── CLAUDE.md
├── SwiftSpeakCore/                      # Shared Swift Package
│   ├── Package.swift
│   ├── Sources/SwiftSpeakCore/
│   │   ├── Models/                      # AIProvider, FormattingMode, Language, etc.
│   │   ├── Protocols/                   # TranscriptionProvider, FormattingProvider, etc.
│   │   ├── Utilities/                   # Constants, Theme, LogSanitizer
│   │   └── Errors/                      # TranscriptionError
│   └── Tests/
├── SwiftSpeak/                          # iOS Containing App
│   ├── SwiftSpeakApp.swift              # @main entry (pre-warms audio session)
│   ├── ContentView.swift                # Main app navigation
│   ├── SharedSettings.swift             # App Groups data + settings management
│   │
│   ├── Services/
│   │   ├── Protocols/
│   │   │   ├── TranscriptionProvider.swift
│   │   │   ├── FormattingProvider.swift
│   │   │   ├── TranslationProvider.swift
│   │   │   ├── StreamingTranscriptionProvider.swift
│   │   │   ├── AudioRecorderProtocol.swift
│   │   │   ├── ProviderFactoryProtocol.swift
│   │   │   ├── MemoryManagerProtocol.swift
│   │   │   ├── ClipboardProtocol.swift
│   │   │   ├── HotkeyManagerProtocol.swift
│   │   │   ├── PermissionManagerProtocol.swift
│   │   │   ├── TextInsertionProtocol.swift
│   │   │   └── TranscriptionSettingsProtocol.swift
│   │   ├── Audio/
│   │   │   ├── AudioSessionManager.swift
│   │   │   ├── AudioRecorder.swift
│   │   │   └── StreamingAudioRecorder.swift
│   │   ├── Memory/
│   │   │   ├── MemoryManager.swift
│   │   │   ├── MemoryUpdateScheduler.swift
│   │   │   └── MemoryUpdateCoordinator.swift    # LEGACY
│   │   ├── Security/
│   │   │   ├── KeychainManager.swift
│   │   │   ├── BiometricAuthManager.swift
│   │   │   └── PromptSanitizer.swift
│   │   ├── Remote/
│   │   │   ├── RemoteConfig.swift
│   │   │   ├── RemoteConfigManager.swift
│   │   │   ├── ConfigChangeDetector.swift
│   │   │   └── CostCalculator.swift
│   │   ├── Providers/
│   │   │   ├── OpenAI/
│   │   │   │   ├── OpenAITranscriptionService.swift
│   │   │   │   ├── OpenAIFormattingService.swift
│   │   │   │   ├── OpenAIStreamingService.swift
│   │   │   │   └── OpenAITranslationService.swift
│   │   │   ├── Anthropic/
│   │   │   │   └── AnthropicService.swift
│   │   │   ├── Google/
│   │   │   │   ├── GeminiService.swift
│   │   │   │   ├── GoogleSTTService.swift
│   │   │   │   └── GoogleTranslationService.swift
│   │   │   ├── AssemblyAI/
│   │   │   │   ├── AssemblyAITranscriptionService.swift
│   │   │   │   └── AssemblyAIStreamingService.swift
│   │   │   ├── Deepgram/
│   │   │   │   ├── DeepgramTranscriptionService.swift
│   │   │   │   └── DeepgramStreamingService.swift
│   │   │   ├── DeepL/
│   │   │   │   └── DeepLTranslationService.swift
│   │   │   ├── Azure/
│   │   │   │   └── AzureTranslatorService.swift
│   │   │   ├── Local/
│   │   │   │   ├── WhisperKitTranscriptionService.swift
│   │   │   │   ├── AppleTranslationService.swift
│   │   │   │   ├── LocalTranslationManager.swift
│   │   │   │   ├── AppleIntelligenceFormattingService.swift
│   │   │   │   └── LocalProviderErrors.swift
│   │   │   ├── Mock/
│   │   │   │   ├── MockTranscriptionProvider.swift
│   │   │   │   ├── MockFormattingProvider.swift
│   │   │   │   ├── MockAudioRecorder.swift
│   │   │   │   ├── MockProviderFactory.swift
│   │   │   │   ├── MockMemoryManager.swift
│   │   │   │   └── MockKeychainManager.swift
│   │   │   ├── TokenCounter.swift
│   │   │   └── ProviderHealthTracker.swift
│   │   ├── Orchestration/
│   │   │   ├── TranscriptionOrchestrator.swift
│   │   │   ├── PowerModeOrchestrator.swift
│   │   │   ├── StreamingTranscriptionOrchestrator.swift
│   │   │   └── PromptContext.swift
│   │   ├── Network/
│   │   │   ├── APIClient.swift
│   │   │   ├── RetryPolicy.swift
│   │   │   └── SSEParser.swift
│   │   ├── Webhooks/
│   │   │   ├── WebhookCircuitBreaker.swift
│   │   │   └── WebhookExecutor.swift
│   │   ├── SwiftLink/
│   │   │   ├── DarwinNotificationManager.swift
│   │   │   └── SwiftLinkSessionManager.swift
│   │   ├── Obsidian/
│   │   │   ├── ObsidianIndexer.swift
│   │   │   ├── ObsidianSyncService.swift
│   │   │   ├── ObsidianQueryService.swift
│   │   │   ├── ObsidianNoteWriter.swift
│   │   │   ├── ObsidianVaultManager.swift
│   │   │   └── ObsidianVectorStore.swift
│   │   ├── RAG/
│   │   │   ├── RAGOrchestrator.swift
│   │   │   ├── RAGSecurityManager.swift
│   │   │   ├── EmbeddingService.swift
│   │   │   ├── VectorStore.swift
│   │   │   ├── DocumentParser.swift
│   │   │   ├── TextChunker.swift
│   │   │   └── DocumentChunk.swift
│   │   ├── Persistence/
│   │   │   ├── CoreDataManager.swift
│   │   │   ├── PersistenceController.swift
│   │   │   ├── DataMigrationManager.swift
│   │   │   ├── CoreDataEntityExtensions.swift
│   │   │   └── ObsidianVaultEntity+Extensions.swift
│   │   ├── KeyboardAction/
│   │   │   └── KeyboardActionHandler.swift
│   │   ├── Logging/
│   │   │   ├── Logging.swift
│   │   │   ├── LogExporter.swift
│   │   │   └── CloudKitLogSync.swift
│   │   ├── ProviderFactory.swift
│   │   └── TranscriptionError.swift
│   │
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   ├── WelcomeScreen.swift
│   │   │   ├── HowItWorksScreen.swift
│   │   │   ├── KeyboardSetupScreen.swift
│   │   │   ├── APIKeyScreen.swift
│   │   │   └── AllSetScreen.swift
│   │   ├── PowerMode/
│   │   │   ├── PowerModeListView.swift
│   │   │   ├── PowerModeEditorView.swift
│   │   │   ├── PowerModeDetailView.swift
│   │   │   ├── PowerModeExecutionView.swift
│   │   │   ├── PowerModeResultView.swift
│   │   │   ├── PowerModeQuestionView.swift
│   │   │   ├── PowerTabView.swift
│   │   │   ├── KnowledgeBaseView.swift
│   │   │   ├── DocumentPickerSheet.swift
│   │   │   ├── PowerModeActionSection.swift
│   │   │   ├── PowerModeVaultSection.swift
│   │   │   └── Components/
│   │   │       ├── IconPicker.swift
│   │   │       └── SwipeablePowerModeCard.swift
│   │   ├── Components/
│   │   │   ├── WaveformView.swift
│   │   │   ├── Animations.swift
│   │   │   ├── ProviderHelpSheet.swift
│   │   │   ├── ProviderStatusDashboard.swift
│   │   │   ├── ProviderIcon.swift
│   │   │   ├── SmartLanguagePicker.swift
│   │   │   ├── IncompatibilityWarning.swift
│   │   │   ├── AppAssignmentSection.swift
│   │   │   ├── BiometricGateView.swift
│   │   │   ├── LockedView.swift
│   │   │   ├── ConfigUpdateSheet.swift
│   │   │   ├── ContextQuickSwitcher.swift
│   │   │   ├── KeyboardActionOverlay.swift
│   │   │   ├── PrivacyModeIndicator.swift
│   │   │   ├── RAGPrivacyWarning.swift
│   │   │   ├── SwiftLinkQuickStartSheet.swift
│   │   │   └── ObsidianActionSheet.swift
│   │   ├── Settings/
│   │   │   ├── ContextsView.swift
│   │   │   ├── ContextEditorSheet.swift
│   │   │   ├── ContextDetailView.swift
│   │   │   ├── MemoryView.swift
│   │   │   ├── MemoryEditorSheet.swift
│   │   │   ├── AppLibraryView.swift
│   │   │   ├── WhisperKitSetupView.swift
│   │   │   ├── AppleIntelligenceSetupView.swift
│   │   │   ├── AppleTranslationSetupView.swift
│   │   │   ├── LocalModelStorageView.swift
│   │   │   ├── AdvancedTokenLimitsView.swift
│   │   │   ├── PendingAudioListView.swift
│   │   │   ├── DiagnosticsView.swift
│   │   │   ├── SwiftLinkSetupView.swift
│   │   │   ├── VocabularyView.swift
│   │   │   ├── LanguagePickerView.swift
│   │   │   ├── VoiceLanguageSettingsView.swift
│   │   │   ├── TranscriptionAISettingsView.swift
│   │   │   ├── BehaviorSettingsView.swift
│   │   │   ├── PersonalizationSettingsView.swift
│   │   │   ├── SecurityPrivacyView.swift
│   │   │   ├── RetrySettingsView.swift
│   │   │   ├── WebhooksView.swift
│   │   │   ├── WebhookEditorSheet.swift
│   │   │   ├── VaultsSettingsView.swift
│   │   │   ├── VaultDetailView.swift
│   │   │   ├── ObsidianDownloadSheet.swift
│   │   │   ├── Providers/
│   │   │   │   ├── DefaultProvidersView.swift
│   │   │   │   ├── AddAIProviderSheet.swift
│   │   │   │   ├── AIProviderEditorSheet.swift
│   │   │   │   ├── ConfiguredProviderRows.swift
│   │   │   │   └── ProviderConfigurationRow.swift
│   │   │   ├── LocalModels/
│   │   │   │   ├── LocalModelRow.swift
│   │   │   │   └── AddLocalModelSheet.swift
│   │   │   └── Components/
│   │   │       └── SettingsRow.swift
│   │   ├── History/
│   │   │   └── HistoryFilterSheet.swift
│   │   ├── ContentView.swift
│   │   ├── RecordingView.swift
│   │   ├── SettingsView.swift
│   │   ├── HistoryView.swift
│   │   ├── CostAnalyticsView.swift
│   │   ├── KeyboardPreviewView.swift
│   │   ├── ProviderComparisonView.swift
│   │   └── LanguageSupportView.swift
│   │
│   └── Shared/
│       ├── Constants.swift
│       ├── Models.swift                 # TranscriptionRecord, etc.
│       ├── Models/                      # Individual model files
│       │   ├── AIProvider.swift
│       │   ├── AIProviderConfig.swift
│       │   ├── Context.swift
│       │   ├── Cost.swift
│       │   ├── FormattingMode.swift
│       │   ├── KeyboardAction.swift
│       │   ├── Knowledge.swift
│       │   ├── Language.swift
│       │   ├── LocalProvider.swift
│       │   ├── PendingAudio.swift
│       │   ├── PowerMode.swift
│       │   ├── Processing.swift
│       │   ├── ProviderSelection.swift
│       │   ├── RAG.swift
│       │   ├── Transcription.swift
│       │   ├── Vocabulary.swift
│       │   └── Webhook.swift
│       ├── Theme.swift
│       ├── AppLibrary.swift
│       ├── AudioUtils.swift
│       ├── ProviderLanguageSupport.swift
│       ├── ProviderHelpContent.swift
│       ├── LogSanitizer.swift
│       ├── SharedLogManager.swift
│       └── PrivacyInfo.xcprivacy
│
├── SwiftSpeakKeyboard/                  # Keyboard Extension
│   ├── KeyboardViewController.swift
│   ├── KeyboardView.swift
│   ├── KeyboardViewModel.swift
│   ├── DarwinNotificationManager.swift
│   ├── SharedLogManager.swift
│   ├── LogSanitizer.swift
│   ├── Shared/
│   │   ├── Constants.swift
│   │   ├── Theme.swift
│   │   └── Models/
│   │       ├── FormattingMode.swift
│   │       ├── KeyboardAction.swift
│   │       └── Language.swift
│   ├── Models/
│   │   └── KeyboardSettings.swift
│   ├── Data/
│   │   ├── KeyboardLayout.swift
│   │   ├── AccentMappings.swift
│   │   ├── SwipeTypingDictionary.swift
│   │   ├── PredictionModels.swift
│   │   └── VoiceCommands.swift
│   ├── Services/
│   │   ├── SwipeTypingEngine.swift
│   │   ├── PredictionEngine.swift
│   │   ├── NGramPredictor.swift
│   │   ├── PersonalDictionary.swift
│   │   ├── ContextAwarePredictions.swift
│   │   ├── PredictionFeedback.swift
│   │   ├── AutoCapitalizationService.swift
│   │   ├── SmartPunctuationService.swift
│   │   ├── AutocorrectHistoryService.swift
│   │   ├── CursorController.swift
│   │   ├── VoiceCommandParser.swift
│   │   └── [13 language] AutocorrectService.swift
│   ├── Components/
│   │   ├── KeyboardMode/
│   │   │   ├── QWERTYKeyboard.swift
│   │   │   ├── TypingKeyboardView.swift
│   │   │   ├── SwiftSpeakBar.swift
│   │   │   ├── RecordingBar.swift
│   │   │   ├── PredictionRow.swift
│   │   │   ├── SentencePredictionView.swift
│   │   │   ├── StreamingTranscriptRow.swift
│   │   │   └── QuickSettingsPopover.swift
│   │   ├── Keys/
│   │   │   ├── LetterKey.swift
│   │   │   ├── ActionKey.swift
│   │   │   ├── SpaceBar.swift
│   │   │   └── AccentPopup.swift
│   │   ├── EmojiGIF/
│   │   │   ├── EmojiKeyboard.swift
│   │   │   ├── EmojiGIFPanel.swift
│   │   │   ├── EmojiData.swift
│   │   │   └── InlineSearchKeyboard.swift
│   │   ├── Panels/
│   │   │   └── ClipboardPanel.swift
│   │   └── SwipePathView.swift
│   ├── Info.plist
│   └── PrivacyInfo.xcprivacy
│
├── SwiftSpeakMac/                       # macOS Menu Bar App
│   ├── SwiftSpeakMacApp.swift
│   ├── MacSharedSettings.swift
│   ├── MacSharedTypes.swift
│   ├── MacProviderFactory.swift
│   ├── Platform/
│   │   ├── MacAudioRecorder.swift
│   │   ├── MacHotkeyManager.swift
│   │   ├── MacPermissionManager.swift
│   │   ├── MacTextInsertionService.swift
│   │   └── MacBiometricAuth.swift
│   ├── Services/
│   │   ├── MacWindowContextService.swift
│   │   ├── MacFileWatcher.swift
│   │   ├── MacFileBookmarkManager.swift
│   │   ├── MacCloudKitLogSync.swift
│   │   └── MacObsidianStubs.swift
│   └── Views/
│       ├── MenuBarController.swift
│       ├── RecordingOverlayView.swift
│       ├── MacContextsView.swift
│       ├── MacCostAnalyticsView.swift
│       ├── MacMemoryView.swift
│       ├── MacPowerModesView.swift
│       ├── MacPowerModeOverlayView.swift
│       ├── MacPowerModeOverlayController.swift
│       ├── MacPowerModeOverlayViewModel.swift
│       ├── MacPowerModeHotkeyEditor.swift
│       ├── MacHistoryView.swift
│       ├── MacVaultsSettingsView.swift
│       ├── MacVaultDetailView.swift
│       ├── MacAddVaultSheet.swift
│       ├── MacCloudLogViewer.swift
│       └── MacProviderIcon.swift
│
├── SwiftSpeakTests/                     # Unit Tests
│   ├── Models/
│   ├── Services/
│   └── Integration/
│
└── SwiftSpeakUITests/                   # UI Tests
```

## Legacy Files

These files are deprecated and kept for reference only:

| File | Replaced By | Date |
|------|------------|------|
| `MemoryUpdateCoordinator.swift` | MemoryUpdateScheduler.swift | 2025-01 |
