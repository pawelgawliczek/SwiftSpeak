//
//  MacCloudLogViewer.swift
//  SwiftSpeakMac
//
//  View for displaying iOS logs synced via CloudKit.
//  Enables debugging iOS issues from macOS during development.
//

import SwiftUI
import SwiftSpeakCore

struct MacCloudLogViewer: View {
    @StateObject private var logSync = CloudKitLogSync.shared
    @State private var selectedDevice: String? = nil
    @State private var selectedLevel: String = "INFO"
    @State private var searchText = ""
    @State private var autoRefresh = true
    @State private var refreshTimer: Timer?

    private let levelOptions = ["DEBUG", "INFO", "WARN", "ERROR"]

    var filteredLogs: [CloudLogEntry] {
        var logs = logSync.cloudLogs

        // Filter by device
        if let deviceId = selectedDevice {
            logs = logs.filter { $0.deviceId == deviceId }
        }

        // Filter by level
        if let levelIndex = levelOptions.firstIndex(of: selectedLevel) {
            let allowedLevels = Set(levelOptions[levelIndex...])
            logs = logs.filter { allowedLevels.contains($0.level) }
        }

        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return logs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Device picker
                Picker("Device", selection: $selectedDevice) {
                    Text("All Devices").tag(nil as String?)
                    ForEach(logSync.availableDevices, id: \.id) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }
                .frame(width: 150)

                // Level picker
                Picker("Level", selection: $selectedLevel) {
                    ForEach(levelOptions, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .frame(width: 100)

                // Search
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Spacer()

                // Auto-refresh toggle
                Toggle("Auto-refresh", isOn: $autoRefresh)
                    .toggleStyle(.checkbox)

                // Refresh button
                Button(action: { logSync.loadCloudLogs() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh logs")

                // Clear button
                Button(action: clearLogs) {
                    Image(systemName: "trash")
                }
                .help("Clear logs")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Log list
            if filteredLogs.isEmpty {
                emptyState
            } else {
                logList
            }

            Divider()

            // Status bar
            statusBar
        }
        .onAppear {
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: autoRefresh) { newValue in
            if newValue {
                startAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Cloud Logs")
                .font(.headline)

            Text("Logs from iOS devices will appear here when cloud logging is enabled.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                logSync.loadCloudLogs()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var logList: some View {
        List(filteredLogs) { log in
            LogEntryRow(log: log)
        }
        .listStyle(.inset)
    }

    private var statusBar: some View {
        HStack {
            if let lastSync = logSync.lastSyncTime {
                Text("Last sync: \(lastSync, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(filteredLogs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)

            if let deviceCount = logSync.availableDevices.count as Int?, deviceCount > 0 {
                Text("\(deviceCount) device\(deviceCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                logSync.loadCloudLogs()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func clearLogs() {
        if let deviceId = selectedDevice {
            logSync.clearLogs(forDevice: deviceId)
        } else {
            logSync.clearAllCloudLogs()
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let log: CloudLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Level badge
                Text(log.level)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.2))
                    .foregroundColor(levelColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Source badge
                Text(log.source)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Category
                Text(log.category)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Timestamp
                Text(log.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()

                // Device name
                Text(log.deviceName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Message
            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    private var levelColor: Color {
        switch log.level {
        case "ERROR": return .red
        case "WARN": return .orange
        case "DEBUG": return .gray
        default: return .primary
        }
    }
}

#Preview {
    MacCloudLogViewer()
        .frame(width: 800, height: 600)
}
