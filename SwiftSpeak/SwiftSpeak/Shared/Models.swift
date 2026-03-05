//
//  Models.swift
//  SwiftSpeak
//
//  REFACTORED: This file has been split into smaller, focused model files.
//  See the Models/ directory for individual model files:
//
//  - Subscription.swift (DataRetentionPeriod)
//  - AIProvider.swift (AIProvider, AzureRegion, ProviderUsageCategory)
//  - AIProviderConfig.swift (AIProviderConfig, LocalProviderType, LocalProviderConfig)
//  - Language.swift (Language)
//  - FormattingMode.swift (FormattingMode)
//  - Cost.swift (CostBreakdown, Double extensions)
//  - Processing.swift (ProcessingStepType, ProcessingStepInfo, ProcessingMetadata)
//  - Transcription.swift (TranscriptionRecord, RecordingState)
//  - PendingAudio.swift (PendingAudio, PendingAudioStatus, ProcessingStep, ProcessingStatus)
//  - Vocabulary.swift (VocabularyEntry, VocabularyCategory, CustomTemplate)
//  - Context.swift (ConversationContext, ContextFormality, HistoryMemory)
//  - Knowledge.swift (KnowledgeDocument, KnowledgeDocumentType, UpdateInterval)
//  - Webhook.swift (Webhook, WebhookType, WebhookAuthType, WebhookTemplate)
//  - PowerMode.swift (PowerMode, PowerModeColorPreset, PowerModeQuestion, etc.)
//  - RAG.swift (RAGConfiguration, RAGChunkingStrategy, RAGEmbeddingModel)
//  - LocalProvider.swift (LocalModelType, WhisperModel, WhisperKitSettings, etc.)
//  - ProviderSelection.swift (ProviderSelection, ProviderType, ProviderDefaults)
//
//  SHARED: All model files are used by both SwiftSpeak and SwiftSpeakKeyboard targets
//

import Foundation
import SwiftSpeakCore

// This file intentionally left minimal after refactoring.
// All types are now in the Models/ subdirectory and are automatically
// available throughout the module without explicit imports.
