# SwiftSpeak Phase 9: Remote Configuration & Cost Analytics

> **Execution guide for Phase 9.** Follow this document step-by-step.
> Master project documentation: `/Users/pawelgawliczek/projects/SwiftSpeak/IMPLEMENTATION_PLAN.md`

## Overview

Add remote configuration service for dynamic pricing, capabilities, and language updates, plus a beautiful cost analytics dashboard with charts.

**Goals:**
1. Display API cost information to users
2. Update pricing/capabilities/languages without app releases
3. Provide cost tracking and analytics per provider

**Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    SwiftSpeak iOS App                       │
│  ┌─────────────────────────────────────────────────────────┐│
│  │           RemoteConfigManager                           ││
│  │  • Weekly update check (on first launch if >7 days)     ││
│  │  • Manual refresh button in Settings                    ││
│  │  • Fallback: cached → bundled config                   ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTPS (weekly)
                               ↓
┌─────────────────────────────────────────────────────────────┐
│              Hostinger KVM (Static JSON + nginx)            │
│  GET https://config.yourdomain.com/config.json             │
│  • Pricing, capabilities, models, languages                 │
│  • Provider status (via status page APIs)                   │
│  • Feature flags & announcements                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Progress Tracking

### Backend (Hostinger KVM)
- [ ] **Step 1:** Set up nginx with HTTPS
- [ ] **Step 2:** Create config.json with full schema
- [ ] **Step 3:** Create auto-update.py script
- [ ] **Step 4:** Set up cron job for weekly updates
- [ ] **Step 5:** Create manual update script

### iOS App - Remote Config
- [ ] **Step 6:** Create RemoteConfig.swift data models
- [ ] **Step 7:** Create RemoteConfigManager.swift
- [ ] **Step 8:** Bundle fallback config.json
- [ ] **Step 9:** Integrate with SharedSettings
- [ ] **Step 10:** Add refresh button to Settings

### iOS App - Cost Tracking
- [ ] **Step 11:** Add estimatedCost to TranscriptionRecord
- [ ] **Step 12:** Create CostCalculator.swift
- [ ] **Step 13:** Update TranscriptionOrchestrator to calculate costs
- [ ] **Step 14:** Display costs in HistoryView

### iOS App - Cost Analytics View
- [ ] **Step 15:** Create CostAnalyticsView.swift
- [ ] **Step 16:** Create CostSummaryCard component
- [ ] **Step 17:** Create ProviderCostChart (pie chart)
- [ ] **Step 18:** Create UsageTimelineChart (line chart)
- [ ] **Step 19:** Add navigation from Settings

### Integration & Polish
- [ ] **Step 20:** Update ProviderHelpSheet with remote pricing
- [ ] **Step 21:** Update provider editor with pricing info
- [ ] **Step 22:** Add stale config warning
- [ ] **Step 23:** Tests

---

## Step 1: Set Up nginx with HTTPS (Hostinger KVM)

**SSH into your Hostinger KVM:**
```bash
ssh root@your-kvm-ip
```

**Install nginx and certbot:**
```bash
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx python3-pip -y
pip3 install requests
```

**Create directory structure:**
```bash
sudo mkdir -p /var/www/swiftspeak-config
sudo mkdir -p /var/www/swiftspeak-config/backups
sudo chown -R $USER:$USER /var/www/swiftspeak-config
```

**Configure nginx:**
```bash
sudo nano /etc/nginx/sites-available/swiftspeak-config
```

**Paste this configuration:**
```nginx
server {
    listen 80;
    server_name config.yourdomain.com;  # Replace with your domain
    root /var/www/swiftspeak-config;

    location / {
        # CORS for iOS app
        add_header Access-Control-Allow-Origin "*";
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Content-Type";

        # Cache for 1 hour (app checks weekly anyway)
        add_header Cache-Control "public, max-age=3600";

        # JSON content type
        default_type application/json;

        # Gzip compression
        gzip on;
        gzip_types application/json;
    }

    # Health check endpoint
    location /health {
        return 200 '{"status": "ok"}';
        add_header Content-Type application/json;
    }
}
```

**Enable site and get HTTPS:**
```bash
sudo ln -s /etc/nginx/sites-available/swiftspeak-config /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d config.yourdomain.com
```

**Verify:**
```bash
curl -I https://config.yourdomain.com/health
# Should return 200 OK
```

---

## Step 2: Create config.json

**Create the config file:**
```bash
nano /var/www/swiftspeak-config/config.json
```

**Paste the full schema (see IMPLEMENTATION_PLAN.md for complete JSON):**
```json
{
  "version": "1.0.0",
  "lastUpdated": "2025-12-26T00:00:00Z",
  "schemaVersion": 2,
  "providers": {
    "openai": {
      "displayName": "OpenAI",
      "status": "operational",
      "capabilities": {
        "transcription": {
          "enabled": true,
          "models": [{"id": "whisper-1", "name": "Whisper", "default": true}],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
          "features": ["languageDetection", "timestamps"]
        },
        "translation": {
          "enabled": true,
          "models": [
            {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "default": true},
            {"id": "gpt-4o", "name": "GPT-4o"}
          ],
          "languages": ["en", "es", "fr", "de", "ja", "zh", "ko", "pl", "pt", "ru", "it", "ar", "hi"],
          "features": ["contextAware", "formalityControl"]
        },
        "powerMode": {
          "enabled": true,
          "models": [
            {"id": "gpt-4o", "name": "GPT-4o", "default": true},
            {"id": "gpt-4o-mini", "name": "GPT-4o Mini"},
            {"id": "o1", "name": "o1 (Reasoning)", "tier": "power"}
          ],
          "features": ["streaming", "functionCalling", "vision", "webSearch"]
        },
        "formatting": {
          "enabled": true,
          "models": [{"id": "gpt-4o-mini", "name": "GPT-4o Mini", "default": true}]
        }
      },
      "pricing": {
        "whisper-1": {"unit": "minute", "cost": 0.006},
        "gpt-4o": {"inputPerMToken": 2.50, "outputPerMToken": 10.00},
        "gpt-4o-mini": {"inputPerMToken": 0.15, "outputPerMToken": 0.60},
        "o1": {"inputPerMToken": 15.00, "outputPerMToken": 60.00}
      },
      "freeCredits": "$5 for new accounts",
      "apiKeyUrl": "https://platform.openai.com/api-keys",
      "docsUrl": "https://platform.openai.com/docs"
    }
    // ... add all other providers (see IMPLEMENTATION_PLAN.md)
  },
  "defaultProviders": {
    "transcription": "openai",
    "translation": "openai",
    "powerMode": "openai",
    "formatting": "openai"
  },
  "featureFlags": {
    "powerModeEnabled": true,
    "translationEnabled": true,
    "customTemplatesEnabled": true,
    "costTrackingEnabled": true
  },
  "announcements": []
}
```

**Validate JSON:**
```bash
python3 -m json.tool /var/www/swiftspeak-config/config.json > /dev/null && echo "✓ Valid" || echo "✗ Invalid"
```

---

## Step 3: Create auto-update.py Script

**Create the script:**
```bash
nano /var/www/swiftspeak-config/auto-update.py
```

**Paste the full script from IMPLEMENTATION_PLAN.md (the enhanced version with PROVIDER_DATA).**

**Make executable:**
```bash
chmod +x /var/www/swiftspeak-config/auto-update.py
```

**Test run:**
```bash
python3 /var/www/swiftspeak-config/auto-update.py
```

---

## Step 4: Set Up Cron Job

```bash
crontab -e
```

**Add this line (runs every Sunday at 3 AM):**
```
0 3 * * 0 /usr/bin/python3 /var/www/swiftspeak-config/auto-update.py >> /var/log/swiftspeak-config.log 2>&1
```

**Create log file:**
```bash
sudo touch /var/log/swiftspeak-config.log
sudo chmod 666 /var/log/swiftspeak-config.log
```

---

## Step 5: Create Manual Update Script

**Create script:**
```bash
nano /var/www/swiftspeak-config/update.sh
```

**Paste:**
```bash
#!/bin/bash
set -e

CONFIG="/var/www/swiftspeak-config/config.json"
BACKUP_DIR="/var/www/swiftspeak-config/backups"

# Backup
mkdir -p $BACKUP_DIR
cp $CONFIG "$BACKUP_DIR/config-$(date +%Y%m%d-%H%M%S).json"
echo "✓ Backup created"

# Edit
${EDITOR:-nano} $CONFIG

# Validate
python3 -m json.tool $CONFIG > /dev/null
if [ $? -eq 0 ]; then
    # Update timestamp
    sed -i "s/\"lastUpdated\": \".*\"/\"lastUpdated\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" $CONFIG
    echo "✓ Config updated"
else
    echo "✗ Invalid JSON! Restoring backup..."
    cp "$BACKUP_DIR/$(ls -t $BACKUP_DIR | head -1)" $CONFIG
fi
```

**Make executable:**
```bash
chmod +x /var/www/swiftspeak-config/update.sh
```

---

## Step 6: Create RemoteConfig.swift Data Models

**Create:** `SwiftSpeak/Services/Remote/RemoteConfig.swift`

```swift
import Foundation

// MARK: - Root Config

struct RemoteConfig: Codable {
    let version: String
    let lastUpdated: Date
    let schemaVersion: Int
    let providers: [String: ProviderConfig]
    let defaultProviders: DefaultProviders
    let featureFlags: FeatureFlags
    let announcements: [Announcement]

    struct DefaultProviders: Codable {
        let transcription: String
        let translation: String
        let powerMode: String
        let formatting: String
    }

    struct FeatureFlags: Codable {
        let powerModeEnabled: Bool
        let translationEnabled: Bool
        let customTemplatesEnabled: Bool
        let costTrackingEnabled: Bool
    }
}

// MARK: - Provider Config

struct ProviderConfig: Codable {
    let displayName: String
    let status: ProviderStatus
    let capabilities: ProviderCapabilities
    let pricing: [String: PricingInfo]
    let freeCredits: String?
    let apiKeyUrl: String?
    let docsUrl: String?
    let notes: String?

    enum ProviderStatus: String, Codable {
        case operational
        case degraded
        case unknown
    }
}

struct ProviderCapabilities: Codable {
    let transcription: CapabilityConfig?
    let translation: CapabilityConfig?
    let powerMode: CapabilityConfig?
    let formatting: CapabilityConfig?

    subscript(category: ProviderUsageCategory) -> CapabilityConfig? {
        switch category {
        case .transcription: return transcription
        case .translation: return translation
        case .powerMode: return powerMode
        }
    }
}

struct CapabilityConfig: Codable {
    let enabled: Bool
    let models: [ModelInfo]?
    let languages: [String]?
    let features: [String]?
    let requiresProjectId: Bool?
    let requiresRegion: Bool?
    let note: String?
}

struct ModelInfo: Codable, Identifiable {
    let id: String
    let name: String
    let `default`: Bool?
    let tier: String?  // "power" for premium models

    var isDefault: Bool { `default` ?? false }
    var isPowerTier: Bool { tier == "power" }
}

// MARK: - Pricing

struct PricingInfo: Codable {
    // For per-unit pricing (transcription, translation)
    let unit: String?           // "minute", "character", "15seconds"
    let cost: Double?

    // For token-based pricing (LLMs)
    let inputPerMToken: Double?
    let outputPerMToken: Double?

    var displayString: String {
        if let cost = cost, let unit = unit {
            return String(format: "$%.4f/%@", cost, unit)
        } else if let input = inputPerMToken, let output = outputPerMToken {
            return String(format: "$%.2f/$%.2f per 1M tokens", input, output)
        }
        return "Free"
    }
}

// MARK: - Announcements

struct Announcement: Codable, Identifiable {
    let id: String
    let type: AnnouncementType
    let title: String
    let message: String
    let validUntil: Date

    enum AnnouncementType: String, Codable {
        case info
        case warning
        case newFeature = "new_feature"
    }

    var isValid: Bool {
        validUntil > Date()
    }
}

// MARK: - Convenience Extensions

extension RemoteConfig {
    func provider(_ key: String) -> ProviderConfig? {
        providers[key]
    }

    func provider(_ aiProvider: AIProvider) -> ProviderConfig? {
        providers[aiProvider.rawValue]
    }

    func supportsCapability(_ provider: AIProvider, _ category: ProviderUsageCategory) -> Bool {
        guard let config = providers[provider.rawValue]?
            .capabilities[category] else { return false }
        return config.enabled
    }

    func models(for provider: AIProvider, category: ProviderUsageCategory) -> [ModelInfo] {
        providers[provider.rawValue]?
            .capabilities[category]?
            .models ?? []
    }

    func languages(for provider: AIProvider, category: ProviderUsageCategory) -> [String] {
        providers[provider.rawValue]?
            .capabilities[category]?
            .languages ?? []
    }

    func pricing(for provider: AIProvider, modelId: String) -> PricingInfo? {
        providers[provider.rawValue]?.pricing[modelId]
    }

    var validAnnouncements: [Announcement] {
        announcements.filter { $0.isValid }
    }
}
```

---

## Step 7: Create RemoteConfigManager.swift

**Create:** `SwiftSpeak/Services/Remote/RemoteConfigManager.swift`

```swift
import Foundation

actor RemoteConfigManager {
    static let shared = RemoteConfigManager()

    // MARK: - Configuration

    private let configURL = URL(string: "https://config.yourdomain.com/config.json")!
    private let cacheKey = "cachedRemoteConfig"
    private let lastFetchKey = "lastConfigFetch"
    private let staleThreshold: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    private let veryStaleThreshold: TimeInterval = 30 * 24 * 60 * 60  // 30 days

    private var cachedConfig: RemoteConfig?

    // MARK: - Public API

    /// Get config (from cache, remote, or bundled fallback)
    func getConfig() async -> RemoteConfig {
        // 1. Check if we have a valid cached config
        if let cached = loadFromCache() {
            cachedConfig = cached

            // Refresh in background if stale
            if shouldRefresh() {
                Task.detached { [weak self] in
                    _ = try? await self?.fetchRemoteConfig()
                }
            }

            return cached
        }

        // 2. Try to fetch from remote
        if let fresh = try? await fetchRemoteConfig() {
            return fresh
        }

        // 3. Fall back to bundled config
        return loadBundledConfig()
    }

    /// Force refresh from remote (for manual refresh button)
    func forceRefresh() async throws -> RemoteConfig {
        let config = try await fetchRemoteConfig()
        return config
    }

    /// Check if config is stale (>30 days old)
    var isConfigVeryStale: Bool {
        guard let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastFetch) > veryStaleThreshold
    }

    /// Last update date for display
    var lastUpdateDate: Date? {
        UserDefaults.standard.object(forKey: lastFetchKey) as? Date
    }

    // MARK: - Private Methods

    private func shouldRefresh() -> Bool {
        guard let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastFetch) > staleThreshold
    }

    private func fetchRemoteConfig() async throws -> RemoteConfig {
        var request = URLRequest(url: configURL)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ConfigError.fetchFailed
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let config = try decoder.decode(RemoteConfig.self, from: data)

        // Save to cache
        saveToCache(data)
        cachedConfig = config

        return config
    }

    private func loadFromCache() -> RemoteConfig? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try? decoder.decode(RemoteConfig.self, from: data)
    }

    private func saveToCache(_ data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: lastFetchKey)
    }

    private func loadBundledConfig() -> RemoteConfig {
        guard let url = Bundle.main.url(forResource: "fallback-config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            fatalError("Bundled fallback-config.json not found!")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(RemoteConfig.self, from: data)
        } catch {
            fatalError("Failed to decode bundled config: \(error)")
        }
    }

    // MARK: - Errors

    enum ConfigError: LocalizedError {
        case fetchFailed
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .fetchFailed: return "Failed to fetch configuration"
            case .decodeFailed: return "Failed to decode configuration"
            }
        }
    }
}

// MARK: - Convenience for SwiftUI

@MainActor
class RemoteConfigObservable: ObservableObject {
    @Published var config: RemoteConfig?
    @Published var isLoading = false
    @Published var lastError: Error?

    func load() async {
        isLoading = true
        config = await RemoteConfigManager.shared.getConfig()
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        do {
            config = try await RemoteConfigManager.shared.forceRefresh()
            lastError = nil
        } catch {
            lastError = error
        }
        isLoading = false
    }
}
```

---

## Step 8: Bundle Fallback Config

**Create:** `SwiftSpeak/Resources/fallback-config.json`

Copy the same JSON from your server. This ensures the app works even on first launch with no network.

**Add to Xcode:**
1. Right-click on SwiftSpeak folder in Xcode
2. Add Files to "SwiftSpeak"
3. Select `fallback-config.json`
4. Ensure "Copy items if needed" is checked
5. Target: SwiftSpeak (main app)

---

## Step 9: Integrate with SharedSettings

**Update:** `SwiftSpeak/SharedSettings.swift`

```swift
// Add to SharedSettings class:

@Published var remoteConfig: RemoteConfig?

func loadRemoteConfig() async {
    remoteConfig = await RemoteConfigManager.shared.getConfig()
}

func refreshRemoteConfig() async throws {
    remoteConfig = try await RemoteConfigManager.shared.forceRefresh()
}

var isConfigStale: Bool {
    RemoteConfigManager.shared.isConfigVeryStale
}

var configLastUpdated: Date? {
    RemoteConfigManager.shared.lastUpdateDate
}

// Use remote config for capability checks:
func supportsCapability(_ provider: AIProvider, _ category: ProviderUsageCategory) -> Bool {
    remoteConfig?.supportsCapability(provider, category) ?? provider.supportedCategories.contains(category)
}
```

---

## Step 10: Add Refresh Button to Settings

**Update:** `SwiftSpeak/Views/SettingsView.swift`

Add to the "About" section:

```swift
Section("Configuration") {
    // Last updated
    if let date = settings.configLastUpdated {
        HStack {
            Text("Rates last updated")
            Spacer()
            Text(date, style: .relative)
                .foregroundStyle(.secondary)
        }
    }

    // Stale warning
    if settings.isConfigStale {
        Label("Config may be outdated", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }

    // Refresh button
    Button {
        Task {
            isRefreshing = true
            do {
                try await settings.refreshRemoteConfig()
            } catch {
                showRefreshError = true
            }
            isRefreshing = false
        }
    } label: {
        HStack {
            Label("Refresh Configuration", systemImage: "arrow.clockwise")
            Spacer()
            if isRefreshing {
                ProgressView()
            }
        }
    }
    .disabled(isRefreshing)
}
```

---

## Step 11: Add estimatedCost to TranscriptionRecord

**Update:** `SwiftSpeak/Shared/Models.swift`

```swift
struct TranscriptionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let mode: FormattingMode
    let provider: AIProvider
    let model: String?
    let timestamp: Date
    let duration: TimeInterval  // Recording duration in seconds
    let characterCount: Int     // For translation cost calc

    // NEW: Cost tracking
    var estimatedCost: Double?
    var costBreakdown: CostBreakdown?

    struct CostBreakdown: Codable, Equatable {
        let transcriptionCost: Double
        let formattingCost: Double
        let translationCost: Double?

        var total: Double {
            transcriptionCost + formattingCost + (translationCost ?? 0)
        }
    }
}
```

---

## Step 12: Create CostCalculator.swift

**Create:** `SwiftSpeak/Services/Remote/CostCalculator.swift`

```swift
import Foundation

struct CostCalculator {
    let config: RemoteConfig

    // MARK: - Transcription Cost

    func transcriptionCost(
        provider: AIProvider,
        model: String,
        durationSeconds: TimeInterval
    ) -> Double {
        guard let pricing = config.pricing(for: provider, modelId: model) else {
            return 0
        }

        let minutes = durationSeconds / 60.0
        return (pricing.cost ?? 0) * minutes
    }

    // MARK: - Translation/Formatting Cost (Token-based)

    func llmCost(
        provider: AIProvider,
        model: String,
        inputTokens: Int,
        outputTokens: Int
    ) -> Double {
        guard let pricing = config.pricing(for: provider, modelId: model) else {
            return 0
        }

        let inputCost = (pricing.inputPerMToken ?? 0) * Double(inputTokens) / 1_000_000
        let outputCost = (pricing.outputPerMToken ?? 0) * Double(outputTokens) / 1_000_000

        return inputCost + outputCost
    }

    // MARK: - Character-based Cost (DeepL, Azure)

    func characterCost(
        provider: AIProvider,
        model: String,
        characterCount: Int
    ) -> Double {
        guard let pricing = config.pricing(for: provider, modelId: model) else {
            return 0
        }

        return (pricing.cost ?? 0) * Double(characterCount)
    }

    // MARK: - Estimate for a Transcription

    func estimateCost(
        transcriptionProvider: AIProvider,
        transcriptionModel: String,
        formattingProvider: AIProvider?,
        formattingModel: String?,
        translationProvider: AIProvider?,
        translationModel: String?,
        durationSeconds: TimeInterval,
        estimatedInputTokens: Int = 100,  // Rough estimate
        estimatedOutputTokens: Int = 150
    ) -> TranscriptionRecord.CostBreakdown {
        let transcriptionCost = self.transcriptionCost(
            provider: transcriptionProvider,
            model: transcriptionModel,
            durationSeconds: durationSeconds
        )

        var formattingCost: Double = 0
        if let provider = formattingProvider, let model = formattingModel {
            formattingCost = llmCost(
                provider: provider,
                model: model,
                inputTokens: estimatedInputTokens,
                outputTokens: estimatedOutputTokens
            )
        }

        var translationCost: Double?
        if let provider = translationProvider, let model = translationModel {
            // Check if character-based (DeepL, Azure) or token-based
            if provider == .deepL || provider == .azure {
                translationCost = characterCost(
                    provider: provider,
                    model: model,
                    characterCount: estimatedInputTokens * 4  // Rough char estimate
                )
            } else {
                translationCost = llmCost(
                    provider: provider,
                    model: model,
                    inputTokens: estimatedInputTokens,
                    outputTokens: estimatedOutputTokens
                )
            }
        }

        return TranscriptionRecord.CostBreakdown(
            transcriptionCost: transcriptionCost,
            formattingCost: formattingCost,
            translationCost: translationCost
        )
    }
}

// MARK: - Formatting Helpers

extension Double {
    var formattedCost: String {
        if self < 0.01 {
            return String(format: "$%.4f", self)
        } else if self < 1 {
            return String(format: "$%.3f", self)
        } else {
            return String(format: "$%.2f", self)
        }
    }
}
```

---

## Step 13: Update TranscriptionOrchestrator

**Update:** `SwiftSpeak/Services/Orchestration/TranscriptionOrchestrator.swift`

After transcription completes, calculate and store cost:

```swift
// In the completion handler, after saving the transcription:

if let config = await RemoteConfigManager.shared.getConfig() {
    let calculator = CostCalculator(config: config)

    let costBreakdown = calculator.estimateCost(
        transcriptionProvider: transcriptionProvider.providerId,
        transcriptionModel: transcriptionProvider.model,
        formattingProvider: mode != .raw ? formattingProvider?.providerId : nil,
        formattingModel: mode != .raw ? formattingProvider?.model : nil,
        translationProvider: nil,  // Add if translating
        translationModel: nil,
        durationSeconds: recordingDuration
    )

    record.costBreakdown = costBreakdown
    record.estimatedCost = costBreakdown.total
}
```

---

## Step 14: Display Costs in HistoryView

**Update:** `SwiftSpeak/Views/HistoryView.swift`

Add cost display to each row:

```swift
// In the list row:
HStack {
    VStack(alignment: .leading) {
        Text(record.text)
            .lineLimit(2)
        Text(record.timestamp, style: .relative)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    Spacer()

    // Cost badge
    if let cost = record.estimatedCost, cost > 0 {
        Text(cost.formattedCost)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
```

---

## Step 15-18: Create CostAnalyticsView

**Create:** `SwiftSpeak/Views/CostAnalyticsView.swift`

```swift
import SwiftUI
import Charts

struct CostAnalyticsView: View {
    @EnvironmentObject var settings: SharedSettings
    @State private var selectedPeriod: CostPeriod = .month

    enum CostPeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Card
                CostSummaryCard(
                    period: selectedPeriod,
                    records: filteredRecords
                )

                // Period Picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(CostPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Provider Breakdown
                if !providerCosts.isEmpty {
                    ProviderCostChart(costs: providerCosts)
                }

                // Usage Timeline
                if !dailyCosts.isEmpty {
                    UsageTimelineChart(data: dailyCosts)
                }

                // Category Breakdown
                CategoryBreakdownCard(records: filteredRecords)

                // Stats
                StatsCard(records: filteredRecords)

                // Last updated
                if let date = settings.configLastUpdated {
                    Text("Rates last updated: \(date, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Cost Analytics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { try? await settings.refreshRemoteConfig() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Computed Properties

    var filteredRecords: [TranscriptionRecord] {
        let now = Date()
        return settings.transcriptionHistory.filter { record in
            switch selectedPeriod {
            case .today:
                return Calendar.current.isDateInToday(record.timestamp)
            case .week:
                return record.timestamp > now.addingTimeInterval(-7 * 24 * 60 * 60)
            case .month:
                return record.timestamp > now.addingTimeInterval(-30 * 24 * 60 * 60)
            case .allTime:
                return true
            }
        }
    }

    var providerCosts: [(provider: AIProvider, cost: Double)] {
        Dictionary(grouping: filteredRecords, by: { $0.provider })
            .map { (provider: $0.key, cost: $0.value.reduce(0) { $0 + ($1.estimatedCost ?? 0) }) }
            .filter { $0.cost > 0 }
            .sorted { $0.cost > $1.cost }
    }

    var dailyCosts: [(date: Date, cost: Double, count: Int)] {
        Dictionary(grouping: filteredRecords) { record in
            Calendar.current.startOfDay(for: record.timestamp)
        }
        .map { (
            date: $0.key,
            cost: $0.value.reduce(0) { $0 + ($1.estimatedCost ?? 0) },
            count: $0.value.count
        )}
        .sorted { $0.date < $1.date }
    }
}

// MARK: - Summary Card

struct CostSummaryCard: View {
    let period: CostAnalyticsView.CostPeriod
    let records: [TranscriptionRecord]

    var totalCost: Double {
        records.reduce(0) { $0 + ($1.estimatedCost ?? 0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("TOTAL SPEND")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(totalCost.formattedCost)
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("\(records.count) transcriptions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Provider Pie Chart

struct ProviderCostChart: View {
    let costs: [(provider: AIProvider, cost: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY PROVIDER")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(costs, id: \.provider) { item in
                SectorMark(
                    angle: .value("Cost", item.cost),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Provider", item.provider.displayName))
                .cornerRadius(4)
            }
            .frame(height: 200)

            // Legend
            VStack(alignment: .leading, spacing: 4) {
                ForEach(costs, id: \.provider) { item in
                    HStack {
                        Circle()
                            .fill(providerColor(item.provider))
                            .frame(width: 8, height: 8)
                        Text(item.provider.displayName)
                        Spacer()
                        Text(item.cost.formattedCost)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    func providerColor(_ provider: AIProvider) -> Color {
        switch provider {
        case .openAI: return .green
        case .anthropic: return .orange
        case .google: return .blue
        case .deepgram: return .purple
        case .deepL: return .teal
        default: return .gray
        }
    }
}

// MARK: - Timeline Chart

struct UsageTimelineChart: View {
    let data: [(date: Date, cost: Double, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("USAGE OVER TIME")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(data, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Cost", item.cost)
                )
                .foregroundStyle(AppTheme.accentGradient)

                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Cost", item.cost)
                )
                .foregroundStyle(.accent)
            }
            .frame(height: 150)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Category Breakdown

struct CategoryBreakdownCard: View {
    let records: [TranscriptionRecord]

    var transcriptionTotal: Double {
        records.reduce(0) { $0 + ($1.costBreakdown?.transcriptionCost ?? 0) }
    }

    var formattingTotal: Double {
        records.reduce(0) { $0 + ($1.costBreakdown?.formattingCost ?? 0) }
    }

    var translationTotal: Double {
        records.reduce(0) { $0 + ($1.costBreakdown?.translationCost ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BREAKDOWN")
                .font(.caption)
                .foregroundStyle(.secondary)

            CategoryRow(icon: "mic.fill", label: "Transcription", cost: transcriptionTotal, color: .blue)
            CategoryRow(icon: "sparkles", label: "Formatting", cost: formattingTotal, color: .purple)
            CategoryRow(icon: "globe", label: "Translation", cost: translationTotal, color: .green)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct CategoryRow: View {
    let icon: String
    let label: String
    let cost: Double
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(cost.formattedCost)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    let records: [TranscriptionRecord]

    var averageDuration: TimeInterval {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.duration } / Double(records.count)
    }

    var averageCost: Double {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + ($1.estimatedCost ?? 0) } / Double(records.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.accent)
                Text("\(records.count) transcriptions")
            }

            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.accent)
                Text("Average: \(Int(averageDuration)) seconds")
            }

            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.accent)
                Text("Average cost: \(averageCost.formattedCost)")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
```

---

## Step 19: Add Navigation from Settings

**Update:** `SwiftSpeak/Views/SettingsView.swift`

```swift
// In the settings list:
Section("Usage") {
    NavigationLink {
        CostAnalyticsView()
    } label: {
        Label("Cost Analytics", systemImage: "chart.pie.fill")
    }
}
```

---

## Step 20-22: Integration & Polish

**Step 20:** Update ProviderHelpSheet to show pricing from remote config
**Step 21:** Update provider editor to show model costs
**Step 22:** Add stale config warning banner

These involve updating existing Phase 3a views to use `RemoteConfigManager.shared`.

---

## Step 23: Tests

**Create:** `SwiftSpeakTests/Services/RemoteConfigTests.swift`

```swift
import Testing
@testable import SwiftSpeak

@Suite("RemoteConfig Tests")
struct RemoteConfigTests {

    @Test("Bundled config loads successfully")
    func testBundledConfigLoads() {
        // Load from bundle
        let url = Bundle.main.url(forResource: "fallback-config", withExtension: "json")!
        let data = try! Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let config = try! decoder.decode(RemoteConfig.self, from: data)

        #expect(!config.providers.isEmpty)
        #expect(config.schemaVersion == 2)
    }

    @Test("Cost calculator computes transcription cost")
    func testTranscriptionCost() {
        // Create mock config
        // ...
        let calculator = CostCalculator(config: mockConfig)

        let cost = calculator.transcriptionCost(
            provider: .openAI,
            model: "whisper-1",
            durationSeconds: 60
        )

        #expect(cost == 0.006)  // $0.006/minute
    }
}
```

---

## Verification Checklist

### Backend
- [ ] nginx serves config.json over HTTPS
- [ ] Config validates as proper JSON
- [ ] auto-update.py runs without errors
- [ ] Cron job is scheduled
- [ ] Health endpoint returns 200

### iOS App
- [ ] App loads config on launch
- [ ] Fallback works without network
- [ ] Refresh button updates config
- [ ] Stale warning appears after 30 days
- [ ] Costs appear in History
- [ ] Cost Analytics charts render
- [ ] Provider help shows remote pricing

---

## Files Created

| File | Purpose |
|------|---------|
| `/var/www/swiftspeak-config/config.json` | Main config file |
| `/var/www/swiftspeak-config/auto-update.py` | Update script |
| `/var/www/swiftspeak-config/update.sh` | Manual edit script |
| `Services/Remote/RemoteConfig.swift` | Data models |
| `Services/Remote/RemoteConfigManager.swift` | Fetch & cache |
| `Services/Remote/CostCalculator.swift` | Cost calculations |
| `Resources/fallback-config.json` | Bundled fallback |
| `Views/CostAnalyticsView.swift` | Analytics dashboard |

## Files Modified

| File | Changes |
|------|---------|
| `SharedSettings.swift` | Add remoteConfig, loading methods |
| `Models.swift` | Add estimatedCost to TranscriptionRecord |
| `TranscriptionOrchestrator.swift` | Calculate cost after transcription |
| `HistoryView.swift` | Display cost per item |
| `SettingsView.swift` | Add refresh button, analytics link |
| `ProviderHelpSheet.swift` | Use remote pricing |

---

## Notes

- **Domain:** Replace `config.yourdomain.com` with your actual domain
- **HTTPS:** Required for iOS App Transport Security
- **Caching:** App checks weekly, but caches indefinitely if network fails
- **Charts:** Uses iOS 16+ SwiftUI Charts framework
- **Fallback:** Always bundle a recent config.json in the app
