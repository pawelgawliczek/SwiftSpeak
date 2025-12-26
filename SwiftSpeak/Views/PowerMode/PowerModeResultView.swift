//
//  PowerModeResultView.swift
//  SwiftSpeak
//
//  Display markdown result with version navigation and inline diff
//

import SwiftUI

struct PowerModeResultView: View {
    @State var session: PowerModeSession
    let onCopy: () -> Void
    let onInsert: () -> Void
    let onRegenerate: () -> Void

    @State private var showDiff = false

    var body: some View {
        VStack(spacing: 16) {
            // Header with mode info
            headerSection

            // Version navigation (if multiple versions)
            if session.hasMultipleVersions {
                versionNavigation
            }

            // Result content
            ScrollView {
                if showDiff, session.currentVersionIndex > 0 {
                    InlineDiffView(
                        oldText: session.results[session.currentVersionIndex - 1].markdownOutput,
                        newText: session.currentResult?.markdownOutput ?? ""
                    )
                    .padding(.horizontal, 16)
                } else {
                    MarkdownView(text: session.currentResult?.markdownOutput ?? "")
                        .padding(.horizontal, 16)
                }
            }

            // Action buttons
            actionButtons
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.powerGradient)

                Text(session.currentResult?.powerModeName ?? "Power Mode")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 8) {
                if session.hasMultipleVersions {
                    Text("Version \(session.currentVersionIndex + 1) of \(session.results.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                }

                if let result = session.currentResult {
                    Text("Completed in \(String(format: "%.1f", result.processingDuration))s")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !result.capabilitiesUsed.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text("\(result.capabilitiesUsed.map { $0.displayName }.joined(separator: ", ")) used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.05))
    }

    // MARK: - Version Navigation

    private var versionNavigation: some View {
        HStack(spacing: 12) {
            Button(action: {
                HapticManager.selection()
                session.goToPrevious()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text("Previous")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(session.canGoToPrevious ? AppTheme.powerAccent : .secondary.opacity(0.3))
            }
            .disabled(!session.canGoToPrevious)

            Spacer()

            Button(action: {
                HapticManager.selection()
                session.goToNext()
            }) {
                HStack(spacing: 4) {
                    Text("Next")
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(session.canGoToNext ? AppTheme.powerAccent : .secondary.opacity(0.3))
            }
            .disabled(!session.canGoToNext)

            Divider()
                .frame(height: 16)

            Button(action: {
                HapticManager.selection()
                showDiff.toggle()
            }) {
                Text(showDiff ? "Hide Diff" : "Show Diff")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(session.currentVersionIndex > 0 ? AppTheme.powerAccent : .secondary.opacity(0.3))
            }
            .disabled(session.currentVersionIndex == 0)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onCopy) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.footnote)
                    Text("Copy")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            Button(action: onInsert) {
                HStack(spacing: 6) {
                    Image(systemName: "text.insert")
                        .font(.footnote)
                    Text("Insert")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }

            Button(action: onRegenerate) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote)
                    Text("Regenerate")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppTheme.powerGradient)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Simple Markdown View

struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(), id: \.id) { element in
                element.view
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parseMarkdown() -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                elements.append(MarkdownElement(type: .spacer))
            } else if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2))
                elements.append(MarkdownElement(type: .h1(content)))
            } else if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3))
                elements.append(MarkdownElement(type: .h2(content)))
            } else if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4))
                elements.append(MarkdownElement(type: .h3(content)))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                elements.append(MarkdownElement(type: .bullet(content)))
            } else if let match = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                let content = String(trimmed[match.upperBound...])
                let number = String(trimmed[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
                elements.append(MarkdownElement(type: .numbered(number, content)))
            } else {
                elements.append(MarkdownElement(type: .paragraph(trimmed)))
            }
        }

        return elements
    }
}

private struct MarkdownElement: Identifiable {
    let id = UUID()
    let type: MarkdownType

    enum MarkdownType {
        case h1(String)
        case h2(String)
        case h3(String)
        case paragraph(String)
        case bullet(String)
        case numbered(String, String)
        case spacer
    }

    @ViewBuilder
    var view: some View {
        switch type {
        case .h1(let text):
            Text(parseBold(text))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        case .h2(let text):
            Text(parseBold(text))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 8)
        case .h3(let text):
            Text(parseBold(text))
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.top, 4)
        case .paragraph(let text):
            Text(parseBold(text))
                .font(.body)
                .foregroundStyle(.primary)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(parseBold(text))
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        case .numbered(let number, let text):
            HStack(alignment: .top, spacing: 8) {
                Text(number)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
                Text(parseBold(text))
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        case .spacer:
            Spacer().frame(height: 8)
        }
    }

    private func parseBold(_ text: String) -> AttributedString {
        var result = AttributedString(text)

        // Simple bold parsing for **text**
        let pattern = #"\*\*(.+?)\*\*"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

            for match in matches.reversed() {
                if let boldRange = Range(match.range(at: 1), in: text),
                   let fullRange = Range(match.range, in: text) {
                    let boldText = String(text[boldRange])
                    var attributed = AttributedString(boldText)
                    attributed.font = .body.bold()

                    if let resultRange = result.range(of: String(text[fullRange])) {
                        result.replaceSubrange(resultRange, with: attributed)
                    }
                }
            }
        }

        return result
    }
}

// MARK: - Inline Diff View

struct InlineDiffView: View {
    let oldText: String
    let newText: String

    private var diffs: [DiffElement] {
        computeDiff(old: oldText, new: newText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(diffs) { diff in
                diff.view
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func computeDiff(old: String, new: String) -> [DiffElement] {
        // Simple line-by-line diff for MVP
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        var result: [DiffElement] = []
        var oldIndex = 0
        var newIndex = 0

        while oldIndex < oldLines.count || newIndex < newLines.count {
            if oldIndex >= oldLines.count {
                // Remaining new lines are additions
                result.append(DiffElement(type: .added(newLines[newIndex])))
                newIndex += 1
            } else if newIndex >= newLines.count {
                // Remaining old lines are deletions
                result.append(DiffElement(type: .removed(oldLines[oldIndex])))
                oldIndex += 1
            } else if oldLines[oldIndex] == newLines[newIndex] {
                // Same line
                result.append(DiffElement(type: .unchanged(oldLines[oldIndex])))
                oldIndex += 1
                newIndex += 1
            } else {
                // Different - check if it's a modification or add/remove
                // Simple heuristic: if next old line matches current new, it's an addition
                if oldIndex + 1 < oldLines.count && oldLines[oldIndex + 1] == newLines[newIndex] {
                    result.append(DiffElement(type: .removed(oldLines[oldIndex])))
                    oldIndex += 1
                } else if newIndex + 1 < newLines.count && oldLines[oldIndex] == newLines[newIndex + 1] {
                    result.append(DiffElement(type: .added(newLines[newIndex])))
                    newIndex += 1
                } else {
                    // Modification
                    result.append(DiffElement(type: .removed(oldLines[oldIndex])))
                    result.append(DiffElement(type: .added(newLines[newIndex])))
                    oldIndex += 1
                    newIndex += 1
                }
            }
        }

        return result
    }
}

private struct DiffElement: Identifiable {
    let id = UUID()
    let type: DiffType

    enum DiffType {
        case unchanged(String)
        case added(String)
        case removed(String)
    }

    @ViewBuilder
    var view: some View {
        switch type {
        case .unchanged(let text):
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
            } else {
                Spacer().frame(height: 8)
            }
        case .added(let text):
            if !text.isEmpty {
                HStack(spacing: 8) {
                    Text("+")
                        .font(.body.monospaced())
                        .foregroundStyle(.green)
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        case .removed(let text):
            if !text.isEmpty {
                HStack(spacing: 8) {
                    Text("-")
                        .font(.body.monospaced())
                        .foregroundStyle(.red)
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    var session = PowerModeSession()
    session.addResult(PowerModeResult.sample)

    return PowerModeResultView(
        session: session,
        onCopy: {},
        onInsert: {},
        onRegenerate: {}
    )
    .background(AppTheme.darkBase)
    .preferredColorScheme(.dark)
}
