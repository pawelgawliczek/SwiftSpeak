//
//  MacLocalLogViewer.swift
//  SwiftSpeakMac
//
//  Local log viewer for macOS - shows logs from the current Mac app.
//  Similar to iOS log viewer functionality.
//

import SwiftUI
import AppKit

struct MacLocalLogViewer: View {
    @StateObject private var logManager = MacSharedLogManager.shared
    @State private var selectedLevel: MacLogLevel = .info
    @State private var searchText = ""
    @State private var selectedCategory: String = ""
    @State private var autoScroll = true
    @State private var showExportSheet = false

    var filteredLogs: [MacLogEntry] {
        logManager.filteredLogs(
            minLevel: selectedLevel,
            searchText: searchText,
            category: selectedCategory.isEmpty ? nil : selectedCategory
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                // Level picker
                Picker("Level", selection: $selectedLevel) {
                    ForEach(MacLogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .frame(width: 100)

                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag("")
                    ForEach(logManager.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .frame(width: 150)

                // Search
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Spacer()

                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                // Refresh button
                Button(action: { logManager.loadLogs() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh logs")

                // Copy all button
                Button(action: copyAllToClipboard) {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy all logs to clipboard")

                // Export button
                Button(action: { showExportSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export logs to file")

                // Clear button
                Button(action: { logManager.clearLogs() }) {
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
        .fileExporter(
            isPresented: $showExportSheet,
            document: LogDocument(content: logManager.exportLogs()),
            contentType: .plainText,
            defaultFilename: "swiftspeak_logs_\(formattedDate()).txt"
        ) { _ in }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Logs")
                .font(.headline)

            Text("Logs will appear here as the app runs.\nTry adjusting the filter level or clearing the search.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") {
                logManager.loadLogs()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List(filteredLogs) { log in
                LocalLogEntryRow(log: log)
                    .id(log.id)
            }
            .listStyle(.inset)
            .onChange(of: filteredLogs.count) { _ in
                if autoScroll, let lastLog = filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            if let lastUpdate = logManager.lastUpdate {
                Text("Last update: \(lastUpdate, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(filteredLogs.count) of \(logManager.logs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)

            let sizeKB = Double(logManager.logFileSize()) / 1024.0
            Text(String(format: "%.1f KB", sizeKB))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
    }

    private func copyAllToClipboard() {
        let logsText = filteredLogs.map { $0.formatted }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logsText, forType: .string)
    }
}

// MARK: - Log Entry Row

struct LocalLogEntryRow: View {
    let log: MacLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Level badge
                Text(log.level.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.2))
                    .foregroundColor(levelColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Category
                Text(log.category)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Timestamp
                Text(log.formattedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
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
        case .error: return .red
        case .warning: return .orange
        case .debug: return .gray
        case .info: return .primary
        }
    }
}

// MARK: - Log Document for Export

struct LogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(data: data, encoding: .utf8) ?? ""
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: content.data(using: .utf8) ?? Data())
    }
}

import UniformTypeIdentifiers

#Preview {
    MacLocalLogViewer()
        .frame(width: 800, height: 600)
}
