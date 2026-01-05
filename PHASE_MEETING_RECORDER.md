# Phase: Meeting Recorder Mode

**Status:** Planning Complete
**Priority:** High
**Platforms:** iOS + macOS
**Estimated Effort:** MVP 8-11 hrs, Full 16-23 hrs

---

## Overview

Add meeting recording capability to SwiftSpeak with speaker diarization, long audio support, and automatic Obsidian note generation. Positions SwiftSpeak as a cost-effective alternative to Jamie AI, VOMO, and similar meeting transcription apps.

---

## Business Case

### Cost Comparison (20 meetings × 30 min/week = 43 hrs/month)

| Solution | Monthly Cost | Annual Cost |
|----------|--------------|-------------|
| **Jamie AI Pro** | €47 (~$51) | $612 |
| **VOMO Pro** | ~$9 | $108 |
| **SwiftSpeak + AssemblyAI** | **~$7-8** | **$84-96** |
| **SwiftSpeak + Whisper** | ~$17 | $204 |

**Annual savings vs Jamie: $500+**

### Provider Pricing (per minute)

| Provider | Rate | Monthly (2,600 min) | Diarization |
|----------|------|---------------------|-------------|
| **AssemblyAI Universal** | $0.0025 | **$6.50** | Yes (native) |
| GPT-4o Mini Transcribe | $0.003 | $7.80 | No |
| Deepgram Nova-3 (batch) | $0.0043 | $11.18 | Yes (not enabled) |
| OpenAI Whisper | $0.006 | $15.60 | No |
| Deepgram Nova-3 (streaming) | $0.0077 | $20.02 | Yes |
| Google STT | $0.016-0.024 | $41-62 | Limited |

**Recommendation:** AssemblyAI Universal for meetings (best value + native diarization)

### Competitive Advantages

| Feature | SwiftSpeak | Jamie | VOMO |
|---------|------------|-------|------|
| Cost (43 hrs/mo) | $7-17 | $51 | $9 |
| Obsidian Integration | Native | No | No |
| Custom AI Prompts | Full control | Limited | Limited |
| Provider Choice | 8+ providers | Fixed | Fixed |
| Offline Mode | WhisperKit | No | No |
| Data Privacy | BYOK | Their servers | Their servers |
| Keyboard Integration | Yes | No | No |

---

## Requirements

- **Speaker diarization**: Essential - identify who said what
- **Processing mode**: Post-meeting batch (cheaper, simpler)
- **Meeting duration**: 30-60 minutes (needs audio chunking)
- **Platforms**: Both iOS and macOS

---

## Current Architecture (What Exists)

### Reusable Components

1. **Power Mode Orchestration**
   - Record → Transcribe → RAG Query → LLM Generate → Obsidian Save
   - Memory injection (global/context/power mode)
   - Streaming generation support
   - `PowerModeOrchestrator.swift`

2. **Audio Recording**
   - M4A/AAC format, 16kHz mono
   - Real-time waveform visualization
   - `AudioRecorder.swift`
   - **Limitation:** 25MB max per provider (~25-30 min)

3. **Obsidian Integration**
   - `ObsidianNoteWriter`: appendToDaily, appendToNote, createNote
   - `ObsidianQueryService`: RAG context from vaults
   - `ObsidianSyncService`: iCloud sync

4. **Provider Infrastructure**
   - AssemblyAI, Deepgram, OpenAI, Google STT
   - Unified `TranscriptionProvider` protocol

### What's Missing

1. Speaker diarization (not enabled in any provider)
2. Audio chunking for >25MB files
3. Meeting-specific Power Mode template
4. Meeting metadata (duration, participants)
5. Meeting history UI

---

## Implementation Plan

### Phase 1: AssemblyAI Speaker Diarization

**Goal:** Enable speaker labels in transcription

**Files to modify:**
```
SwiftSpeak/SwiftSpeak/Services/Providers/AssemblyAI/AssemblyAITranscriptionService.swift
SwiftSpeak/SwiftSpeakCore/Sources/SwiftSpeakCore/Models/Transcription.swift
```

**Changes:**

1. Add `speaker_labels: true` to AssemblyAI request body:
```swift
// In transcription request
let body: [String: Any] = [
    "audio_url": uploadedURL,
    "speaker_labels": true,  // NEW
    "language_code": language?.code ?? "en"
]
```

2. Create `DiarizedTranscript` model:
```swift
struct DiarizedTranscript: Codable, Equatable {
    let segments: [SpeakerSegment]
    let speakerCount: Int

    var formattedText: String {
        segments.map { "[\($0.speaker)]: \($0.text)" }.joined(separator: "\n\n")
    }

    var plainText: String {
        segments.map { $0.text }.joined(separator: " ")
    }
}

struct SpeakerSegment: Codable, Equatable {
    let speaker: String      // "A", "B", "C", etc.
    let text: String
    let start: TimeInterval  // milliseconds
    let end: TimeInterval
    let confidence: Double?
}
```

3. Parse AssemblyAI `utterances` response:
```swift
// AssemblyAI response structure
struct AssemblyAITranscriptResponse: Decodable {
    let id: String
    let status: String
    let text: String?
    let utterances: [Utterance]?  // NEW
    let error: String?

    struct Utterance: Decodable {
        let speaker: String
        let text: String
        let start: Int
        let end: Int
        let confidence: Double
    }
}
```

4. Update `TranscriptionResult`:
```swift
struct TranscriptionResult {
    let text: String
    let language: Language?
    let duration: TimeInterval
    let diarization: DiarizedTranscript?  // NEW - optional
}
```

**Effort:** 2-3 hours

---

### Phase 2: Audio Chunking for Long Recordings

**Goal:** Support 30-60 minute meetings (up to ~60MB)

**Files to create:**
```
SwiftSpeak/SwiftSpeak/Services/Audio/AudioChunker.swift (NEW)
```

**Files to modify:**
```
SwiftSpeak/SwiftSpeak/Services/Orchestration/PowerModeOrchestrator.swift
```

**AudioChunker Implementation:**
```swift
import AVFoundation

actor AudioChunker {
    private let maxChunkSize: Int64 = 20 * 1024 * 1024  // 20MB (safe margin)
    private let chunkDuration: TimeInterval = 15 * 60   // 15 minutes per chunk

    /// Splits audio file if needed, returns array of chunk URLs
    func chunkIfNeeded(audioURL: URL) async throws -> [URL] {
        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0

        guard fileSize > maxChunkSize else {
            return [audioURL]  // No chunking needed
        }

        return try await splitAudio(url: audioURL)
    }

    private func splitAudio(url: URL) async throws -> [URL] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        var chunks: [URL] = []
        var currentTime: TimeInterval = 0
        var chunkIndex = 0

        while currentTime < totalSeconds {
            let endTime = min(currentTime + chunkDuration, totalSeconds)
            let chunkURL = try await exportChunk(
                asset: asset,
                startTime: currentTime,
                endTime: endTime,
                index: chunkIndex
            )
            chunks.append(chunkURL)
            currentTime = endTime
            chunkIndex += 1
        }

        return chunks
    }

    private func exportChunk(asset: AVAsset, startTime: TimeInterval, endTime: TimeInterval, index: Int) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk_\(index)_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ChunkingError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 1000),
            end: CMTime(seconds: endTime, preferredTimescale: 1000)
        )

        await exportSession.export()

        guard exportSession.status == .completed else {
            throw ChunkingError.exportFailed(exportSession.error)
        }

        return outputURL
    }

    enum ChunkingError: Error {
        case exportSessionCreationFailed
        case exportFailed(Error?)
    }
}
```

**Transcript Merging:**
```swift
extension AudioChunker {
    /// Merges multiple diarized transcripts maintaining speaker continuity
    func mergeTranscripts(_ transcripts: [DiarizedTranscript]) -> DiarizedTranscript {
        var allSegments: [SpeakerSegment] = []
        var timeOffset: TimeInterval = 0

        for transcript in transcripts {
            let offsetSegments = transcript.segments.map { segment in
                SpeakerSegment(
                    speaker: segment.speaker,
                    text: segment.text,
                    start: segment.start + timeOffset,
                    end: segment.end + timeOffset,
                    confidence: segment.confidence
                )
            }
            allSegments.append(contentsOf: offsetSegments)

            // Update offset for next chunk
            if let lastSegment = transcript.segments.last {
                timeOffset += lastSegment.end
            }
        }

        // Count unique speakers
        let speakerCount = Set(allSegments.map { $0.speaker }).count

        return DiarizedTranscript(segments: allSegments, speakerCount: speakerCount)
    }
}
```

**PowerModeOrchestrator Integration:**
```swift
// In transcribe phase
private func transcribeAudio(url: URL) async throws -> TranscriptionResult {
    // Check if chunking needed
    let chunks = try await audioChunker.chunkIfNeeded(audioURL: url)

    if chunks.count == 1 {
        // Normal single-file transcription
        return try await provider.transcribe(audioURL: url, language: settings.language)
    }

    // Chunked transcription
    var transcripts: [DiarizedTranscript] = []
    var fullText = ""
    var totalDuration: TimeInterval = 0

    for (index, chunkURL) in chunks.enumerated() {
        updatePhase(.transcribing(progress: Double(index) / Double(chunks.count)))

        let result = try await provider.transcribe(audioURL: chunkURL, language: settings.language)
        fullText += result.text + " "
        totalDuration += result.duration

        if let diarization = result.diarization {
            transcripts.append(diarization)
        }

        // Cleanup chunk file
        try? FileManager.default.removeItem(at: chunkURL)
    }

    let mergedDiarization = transcripts.isEmpty ? nil : audioChunker.mergeTranscripts(transcripts)

    return TranscriptionResult(
        text: fullText.trimmingCharacters(in: .whitespaces),
        language: settings.language,
        duration: totalDuration,
        diarization: mergedDiarization
    )
}
```

**Effort:** 4-6 hours

---

### Phase 3: Meeting Power Mode Template

**Goal:** Pre-configured Power Mode for meetings

**Files to modify:**
```
SwiftSpeak/SwiftSpeak/Shared/Models/PowerMode.swift
SwiftSpeak/SwiftSpeak/Views/PowerMode/PowerModeListView.swift
```

**Add Meeting Mode Flag:**
```swift
struct PowerMode: Identifiable, Codable, Equatable {
    // ... existing properties ...

    /// Indicates this is a meeting recording mode (enables diarization, long recording)
    var isMeetingMode: Bool = false

    /// Meeting-specific settings
    var meetingSettings: MeetingSettings?
}

struct MeetingSettings: Codable, Equatable {
    var requireDiarization: Bool = true
    var maxDurationMinutes: Int = 120
    var autoSaveToObsidian: Bool = true
    var includeTimestamps: Bool = false
}
```

**Default Meeting Template:**
```swift
extension PowerMode {
    static let meetingNotesTemplate = PowerMode(
        id: UUID(),
        name: "Meeting Notes",
        icon: "person.3.fill",
        colorPreset: .blue,
        instruction: """
        You are a professional meeting notes assistant. Analyze this transcript and create structured notes.

        ## Meeting Summary
        [2-3 sentence overview of what was discussed]

        ## Key Discussion Points
        - [Main topics covered with relevant context]

        ## Decisions Made
        - [Any decisions reached during the meeting]

        ## Action Items
        - [ ] [Task] - [Assignee if mentioned]

        ## Follow-up Questions
        - [Unresolved questions or items needing clarification]

        ---
        Transcript:
        {transcription}
        """,
        outputFormat: .markdown,
        memoryEnabled: true,
        isMeetingMode: true,
        meetingSettings: MeetingSettings(
            requireDiarization: true,
            maxDurationMinutes: 120,
            autoSaveToObsidian: true,
            includeTimestamps: false
        ),
        obsidianAction: .init(
            action: .appendToDaily,
            targetVaultId: nil,  // Use default vault
            autoExecute: false   // Confirm before saving
        )
    )
}
```

**Add to Default Templates:**
```swift
// In PowerModeListView or template factory
static let defaultTemplates: [PowerMode] = [
    .meetingNotesTemplate,
    // ... existing templates
]
```

**Effort:** 2 hours

---

### Phase 4: Meeting Recording UI (Optional)

**Goal:** Enhanced recording experience for meetings

**Files to create:**
```
SwiftSpeak/SwiftSpeak/Views/Meetings/MeetingRecordingView.swift (iOS)
SwiftSpeak/SwiftSpeakMac/Views/MacMeetingRecordingView.swift (macOS)
```

**iOS MeetingRecordingView:**
```swift
import SwiftUI

struct MeetingRecordingView: View {
    @StateObject private var viewModel: MeetingRecordingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Meeting Recording")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(.horizontal)

            Spacer()

            // Large Timer
            Text(viewModel.formattedDuration)
                .font(.system(size: 72, weight: .thin, design: .monospaced))
                .foregroundStyle(viewModel.isRecording ? .primary : .secondary)

            // Cost Estimate
            if viewModel.isRecording {
                Text("Est. cost: \(viewModel.estimatedCost)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Waveform
            WaveformView(levels: viewModel.audioLevels)
                .frame(height: 60)
                .padding(.horizontal)

            Spacer()

            // Status
            statusView

            // Controls
            controlsView
        }
        .padding()
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.state {
        case .idle:
            Text("Ready to record")
                .foregroundStyle(.secondary)
        case .recording:
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("Recording")
            }
        case .processing(let progress):
            VStack {
                ProgressView(value: progress)
                Text("Processing audio...")
                    .font(.caption)
            }
        case .generating:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Generating notes...")
            }
        case .complete:
            Label("Complete", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var controlsView: some View {
        HStack(spacing: 32) {
            // Pause/Resume (if recording)
            if viewModel.isRecording {
                Button {
                    viewModel.togglePause()
                } label: {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .frame(width: 60, height: 60)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Circle())
                }
            }

            // Record/Stop
            Button {
                viewModel.toggleRecording()
            } label: {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "record.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(viewModel.isRecording ? .white : .red)
                    .frame(width: 80, height: 80)
                    .background(viewModel.isRecording ? .red : .clear)
                    .overlay(
                        Circle()
                            .stroke(.red, lineWidth: 3)
                    )
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 32)
    }
}
```

**Effort:** 4-6 hours

---

### Phase 5: Meeting History View (Optional - Can Defer)

**Goal:** Browse past meeting notes

**Files to create:**
```
SwiftSpeak/SwiftSpeak/Views/Meetings/MeetingHistoryView.swift (iOS)
SwiftSpeak/SwiftSpeakMac/Views/MacMeetingHistoryView.swift (macOS)
```

**Features:**
- List of past meetings with date, duration, summary preview
- Search across meeting notes
- Re-process with different Power Mode
- Link to Obsidian note
- Delete/archive meetings

**Effort:** 4-6 hours (can defer to future phase)

---

## Implementation Order

| Phase | Description | Effort | Priority | Dependency |
|-------|-------------|--------|----------|------------|
| 1 | Speaker Diarization | 2-3 hrs | **Critical** | None |
| 2 | Audio Chunking | 4-6 hrs | **Critical** | Phase 1 |
| 3 | Meeting Template | 2 hrs | High | Phase 1 |
| 4 | Meeting UI | 4-6 hrs | Medium | Phase 2 |
| 5 | History View | 4-6 hrs | Low | Phase 3 |

**MVP (Phases 1-3):** ~8-11 hours
**Full Feature (Phases 1-5):** ~16-23 hours

---

## Testing Checklist

### Phase 1: Diarization
- [ ] AssemblyAI transcription includes speaker labels
- [ ] Speaker segments parsed correctly
- [ ] Formatted text shows `[Speaker A]: text` format
- [ ] Works with 2, 3, 4+ speakers
- [ ] Handles overlapping speech gracefully

### Phase 2: Chunking
- [ ] Files under 20MB are not chunked
- [ ] Files over 20MB split correctly
- [ ] Chunks transcribed sequentially
- [ ] Transcripts merged with correct timing
- [ ] Speaker continuity maintained across chunks
- [ ] Temporary chunk files cleaned up
- [ ] Progress updates during chunk processing

### Phase 3: Meeting Template
- [ ] Meeting Notes template appears in list
- [ ] Template uses correct prompt
- [ ] Obsidian action defaults to appendToDaily
- [ ] isMeetingMode flag enables diarization
- [ ] AI generates structured meeting notes

### Phase 4: UI
- [ ] Large timer displays correctly
- [ ] Waveform animates during recording
- [ ] Cost estimate updates live
- [ ] Pause/Resume works
- [ ] Processing progress shows
- [ ] Error states handled

---

## Future Enhancements

1. **Live Streaming Transcription** - See words as spoken (AssemblyAI/Deepgram streaming)
2. **Speaker Naming** - Label speakers with actual names
3. **Calendar Integration** - Auto-attach to calendar events
4. **Zoom/Teams Integration** - Record from virtual meetings
5. **Automatic Timestamps** - Insert timestamps every N minutes
6. **Topic Segmentation** - Break transcript into topics
7. **Export Formats** - PDF, Word, Notion, etc.

---

## Sources

- [Jamie AI Pricing](https://www.meetjamie.ai/pricing)
- [VOMO AI Pricing](https://vomo.ai/pricing)
- [Just Press Record](https://www.openplanetsoftware.com/just-press-record/)
- [OpenAI Whisper Pricing](https://brasstranscripts.com/blog/openai-whisper-api-pricing-2025-self-hosted-vs-managed)
- [AssemblyAI Pricing](https://brasstranscripts.com/blog/assemblyai-pricing-per-minute-2025-real-costs)
- [Deepgram Pricing](https://brasstranscripts.com/blog/deepgram-pricing-per-minute-2025-real-time-vs-batch)
- [AssemblyAI Speaker Diarization Docs](https://www.assemblyai.com/docs/speech-to-text/speaker-diarization)
