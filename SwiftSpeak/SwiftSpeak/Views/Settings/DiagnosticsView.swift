//
//  DiagnosticsView.swift
//  SwiftSpeak
//
//  Provides log viewing and export functionality for customer support.
//

import SwiftUI

struct DiagnosticsView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var recentEntries: [LogEntry] = []
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showClearConfirmation = false
    @State private var selectedTimeRange: LogExporter.TimeRange = .last24Hours
    @State private var selectedLevel: LogExporter.MinLevel = .all
    @State private var logFileSize: Int64 = 0
    @State private var isCopying = false
    @State private var showCopiedToast = false
    @State private var isSavingToiCloud = false
    @State private var showSavedToiCloudToast = false
    @State private var iCloudError: String?

    private var backgroundColor: Color {
        colorScheme == .dark ? AppTheme.darkBase : AppTheme.lightBase
    }

    private var rowBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            List {
                // Recent Activity Section
                Section {
                    if recentEntries.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No recent activity")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                        .listRowBackground(rowBackground)
                    } else {
                        ForEach(recentEntries.suffix(10).reversed(), id: \.timestamp) { entry in
                            LogEntryRow(entry: entry)
                                .listRowBackground(rowBackground)
                        }
                    }
                } header: {
                    Text("Recent Activity")
                } footer: {
                    Text("Showing last 10 entries. Export for full log.")
                }

                // Export Options Section
                Section {
                    Picker("Time Range", selection: $selectedTimeRange) {
                        Text("Last Hour").tag(LogExporter.TimeRange.last1Hour)
                        Text("Last 24 Hours").tag(LogExporter.TimeRange.last24Hours)
                        Text("All Time").tag(LogExporter.TimeRange.allTime)
                    }
                    .listRowBackground(rowBackground)

                    Picker("Log Level", selection: $selectedLevel) {
                        Text("All Levels").tag(LogExporter.MinLevel.all)
                        Text("Info & Above").tag(LogExporter.MinLevel.infoAndAbove)
                        Text("Warnings & Errors").tag(LogExporter.MinLevel.warningsAndErrors)
                        Text("Errors Only").tag(LogExporter.MinLevel.errorsOnly)
                    }
                    .listRowBackground(rowBackground)

                    Button(action: copyLogsToClipboard) {
                        HStack {
                            if isCopying {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Copying...")
                            } else if showCopiedToast {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Copied!")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "doc.on.doc")
                                Text("Copy to Clipboard")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isCopying)
                    .listRowBackground(rowBackground)

                    Button(action: exportLogs) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Exporting...")
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export as File")
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isExporting)
                    .listRowBackground(rowBackground)

                    Button(action: saveToiCloud) {
                        HStack {
                            if isSavingToiCloud {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving to iCloud...")
                            } else if showSavedToiCloudToast {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Saved to iCloud!")
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("Save to iCloud Drive")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSavingToiCloud)
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Export")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logs contain only metadata. No dictation content, API keys, or personal information is recorded.")
                        if let error = iCloudError {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Manage Section
                Section {
                    HStack {
                        Text("Log File Size")
                        Spacer()
                        Text(formatFileSize(logFileSize))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(rowBackground)

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Logs")
                        }
                    }
                    .listRowBackground(rowBackground)
                } header: {
                    Text("Manage")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRecentEntries()
            loadLogFileSize()
        }
        .refreshable {
            loadRecentEntries()
            loadLogFileSize()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Clear Logs?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearLogs()
            }
        } message: {
            Text("This will permanently delete all diagnostic logs. This action cannot be undone.")
        }
    }

    // MARK: - Actions

    private func loadRecentEntries() {
        Task {
            let entries = await SharedLogManager.shared.readEntries()
            await MainActor.run {
                self.recentEntries = entries
            }
        }
    }

    private func loadLogFileSize() {
        Task {
            let size = await SharedLogManager.shared.logFileSize()
            await MainActor.run {
                self.logFileSize = size
            }
        }
    }

    private func copyLogsToClipboard() {
        isCopying = true
        HapticManager.lightTap()

        Task {
            let entries = await SharedLogManager.shared.readEntries()

            // Filter by time range
            let cutoff: Date
            switch selectedTimeRange {
            case .currentSession:
                cutoff = Date().addingTimeInterval(-1800) // ~30 mins for current session
            case .last1Hour:
                cutoff = Date().addingTimeInterval(-3600)
            case .last24Hours:
                cutoff = Date().addingTimeInterval(-86400)
            case .allTime:
                cutoff = Date.distantPast
            }

            let filteredEntries = entries.filter { entry in
                guard entry.timestamp >= cutoff else { return false }

                switch selectedLevel {
                case .all:
                    return true
                case .infoAndAbove:
                    return entry.level != .debug
                case .warningsAndErrors:
                    return entry.level == .warning || entry.level == .error
                case .errorsOnly:
                    return entry.level == .error
                }
            }

            // Format entries as text
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

            var logText = "SwiftSpeak Logs - \(dateFormatter.string(from: Date()))\n"
            logText += "Time Range: \(selectedTimeRange)\n"
            logText += "Level: \(selectedLevel)\n"
            logText += "Entries: \(filteredEntries.count)\n"
            logText += String(repeating: "-", count: 50) + "\n\n"

            for entry in filteredEntries {
                let timestamp = dateFormatter.string(from: entry.timestamp)
                let level = entry.level.rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
                let source = entry.source.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                logText += "[\(timestamp)] [\(level)] [\(source)] [\(entry.category)] \(entry.message)\n"
            }

            await MainActor.run {
                UIPasteboard.general.string = logText
                self.isCopying = false
                self.showCopiedToast = true
                HapticManager.success()

                // Hide toast after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showCopiedToast = false
                }
            }
        }
    }

    private func exportLogs() {
        isExporting = true
        HapticManager.lightTap()

        Task {
            if let url = await LogExporter.exportLogs(
                timeRange: selectedTimeRange,
                minLevel: selectedLevel
            ) {
                await MainActor.run {
                    self.exportURL = url
                    self.isExporting = false
                    self.showShareSheet = true
                }
            } else {
                await MainActor.run {
                    self.isExporting = false
                }
            }
        }
    }

    private func saveToiCloud() {
        isSavingToiCloud = true
        iCloudError = nil
        HapticManager.lightTap()

        Task {
            do {
                // Check if iCloud is available
                guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                    throw NSError(domain: "DiagnosticsView", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "iCloud Drive is not available. Please sign in to iCloud in Settings."
                    ])
                }

                // Create logs directory in iCloud Drive
                let logsFolder = iCloudURL.appendingPathComponent("Documents/Logs", isDirectory: true)
                try FileManager.default.createDirectory(at: logsFolder, withIntermediateDirectories: true)

                // Generate log content
                let entries = await SharedLogManager.shared.readEntries()

                // Filter by time range
                let cutoff: Date
                switch selectedTimeRange {
                case .currentSession:
                    cutoff = Date().addingTimeInterval(-1800)
                case .last1Hour:
                    cutoff = Date().addingTimeInterval(-3600)
                case .last24Hours:
                    cutoff = Date().addingTimeInterval(-86400)
                case .allTime:
                    cutoff = Date.distantPast
                }

                let filteredEntries = entries.filter { entry in
                    guard entry.timestamp >= cutoff else { return false }

                    switch selectedLevel {
                    case .all:
                        return true
                    case .infoAndAbove:
                        return entry.level != .debug
                    case .warningsAndErrors:
                        return entry.level == .warning || entry.level == .error
                    case .errorsOnly:
                        return entry.level == .error
                    }
                }

                // Format entries as text
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

                var logText = "SwiftSpeak Logs - \(dateFormatter.string(from: Date()))\n"
                logText += "Time Range: \(selectedTimeRange)\n"
                logText += "Level: \(selectedLevel)\n"
                logText += "Entries: \(filteredEntries.count)\n"
                logText += String(repeating: "-", count: 50) + "\n\n"

                for entry in filteredEntries {
                    let timestamp = dateFormatter.string(from: entry.timestamp)
                    let level = entry.level.rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
                    let source = entry.source.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                    logText += "[\(timestamp)] [\(level)] [\(source)] [\(entry.category)] \(entry.message)\n"
                }

                // Create filename with timestamp
                let fileFormatter = DateFormatter()
                fileFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
                let filename = "SwiftSpeak_Logs_\(fileFormatter.string(from: Date())).txt"
                let fileURL = logsFolder.appendingPathComponent(filename)

                // Write to iCloud
                try logText.write(to: fileURL, atomically: true, encoding: .utf8)

                await MainActor.run {
                    self.isSavingToiCloud = false
                    self.showSavedToiCloudToast = true
                    HapticManager.success()

                    // Hide toast after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.showSavedToiCloudToast = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSavingToiCloud = false
                    self.iCloudError = error.localizedDescription
                    HapticManager.error()
                }
            }
        }
    }

    private func clearLogs() {
        HapticManager.warning()
        Task {
            await SharedLogManager.shared.clearLogs()
            loadRecentEntries()
            loadLogFileSize()
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Level indicator
                Circle()
                    .fill(levelColor)
                    .frame(width: 8, height: 8)

                // Source badge
                Text(entry.source.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sourceColor.opacity(0.2))
                    .foregroundStyle(sourceColor)
                    .clipShape(Capsule())

                // Category
                Text(entry.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Time
                Text(formatTime(entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Message
            Text(entry.message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private var sourceColor: Color {
        switch entry.source {
        case .app: return .blue
        case .keyboard: return .purple
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DiagnosticsView()
    }
}
