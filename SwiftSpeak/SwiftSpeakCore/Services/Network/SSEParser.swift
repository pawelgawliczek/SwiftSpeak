//
//  SSEParser.swift
//  SwiftSpeak
//
//  Server-Sent Events parser for LLM streaming responses
//

import Foundation

/// Represents a Server-Sent Event
public struct SSEEvent: Equatable, Sendable {
    /// Event type (e.g., "message", "content_block_delta")
    public let event: String?
    /// Event data (required - the main payload)
    public let data: String
    /// Event ID for resumption (optional)
    public let id: String?
    /// Reconnection time in milliseconds (optional)
    public let retry: Int?

    nonisolated init(event: String? = nil, data: String, id: String? = nil, retry: Int? = nil) {
        self.event = event
        self.data = data
        self.id = id
        self.retry = retry
    }
}

/// Parser for Server-Sent Events streams
///
/// SSE format specification (https://html.spec.whatwg.org/multipage/server-sent-events.html):
/// - Lines starting with `:` are comments (ignored)
/// - Empty line = end of event
/// - `data:` lines concatenate with newlines
/// - `event:` sets the event type
/// - `id:` sets the event ID
/// - `retry:` sets reconnection time
///
/// Example SSE stream:
/// ```
/// event: message
/// data: {"content": "Hello"}
///
/// data: {"content": " world"}
///
/// data: [DONE]
/// ```
public actor SSEParser {
    private var buffer = ""
    private var currentEvent: String?
    private var currentData: [String] = []
    private var currentId: String?
    private var currentRetry: Int?

    /// Parse incoming text chunk and return complete events
    /// - Parameter chunk: Raw text chunk from the stream (should include newlines)
    /// - Returns: Array of complete SSE events parsed from the chunk
    public func parse(_ chunk: String) -> [SSEEvent] {
        buffer += chunk
        var events: [SSEEvent] = []

        // Process complete lines
        while let newlineRange = buffer.range(of: "\n") {
            let line = String(buffer[..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])

            // Handle carriage return if present (CRLF)
            let cleanLine = line.hasSuffix("\r") ? String(line.dropLast()) : line

            if let event = processLine(cleanLine) {
                events.append(event)
            }
        }

        return events
    }

    /// Process a single line and potentially return a complete event
    private func processLine(_ line: String) -> SSEEvent? {
        // Empty line = dispatch event
        if line.isEmpty {
            return dispatchEvent()
        }

        // Comment line (starts with :)
        if line.hasPrefix(":") {
            return nil
        }

        // Parse field:value
        let colonIndex = line.firstIndex(of: ":")
        let field: String
        var value: String

        if let colonIndex = colonIndex {
            field = String(line[..<colonIndex])
            let valueStart = line.index(after: colonIndex)
            value = String(line[valueStart...])
            // Remove leading space if present
            if value.hasPrefix(" ") {
                value = String(value.dropFirst())
            }
        } else {
            // Line with no colon - treat entire line as field with empty value
            field = line
            value = ""
        }

        // Process known fields
        switch field {
        case "event":
            currentEvent = value
        case "data":
            currentData.append(value)
        case "id":
            // Per spec, id field cannot contain null characters
            if !value.contains("\u{0000}") {
                currentId = value
            }
        case "retry":
            // Must be only ASCII digits
            if let retryValue = Int(value), value.allSatisfy(\.isNumber) {
                currentRetry = retryValue
            }
        default:
            // Unknown field - ignore per spec
            break
        }

        return nil
    }

    /// Dispatch the current event and reset state
    private func dispatchEvent() -> SSEEvent? {
        // Only dispatch if we have data
        guard !currentData.isEmpty else {
            return nil
        }

        // Join data lines with newlines per spec
        let dataString = currentData.joined(separator: "\n")

        let event = SSEEvent(
            event: currentEvent,
            data: dataString,
            id: currentId,
            retry: currentRetry
        )

        // Reset for next event (id and retry persist per spec, but we reset for simplicity)
        currentEvent = nil
        currentData = []
        // Note: Per spec, id persists but we reset for each event for simpler handling
        currentId = nil
        currentRetry = nil

        return event
    }

    /// Reset parser state completely
    public func reset() {
        buffer = ""
        currentEvent = nil
        currentData = []
        currentId = nil
        currentRetry = nil
    }

    /// Check if there's buffered content that hasn't been processed
    public var hasBufferedContent: Bool {
        !buffer.isEmpty || !currentData.isEmpty
    }
}

// MARK: - Provider-Specific Chunk Extractors

public extension SSEEvent {
    /// Extract text content from OpenAI streaming response
    /// Format: `{"choices":[{"delta":{"content":"Hello"}}]}`
    /// Returns nil for [DONE] or non-content events
    public func openAIContent() -> String? {
        guard data != "[DONE]" else { return nil }

        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }

        return content
    }

    /// Extract text content from Anthropic streaming response
    /// Format: `{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}`
    /// Returns nil for non-text events
    public func anthropicContent() -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String,
              type == "content_block_delta",
              let delta = json["delta"] as? [String: Any],
              let deltaType = delta["type"] as? String,
              deltaType == "text_delta",
              let text = delta["text"] as? String else {
            return nil
        }

        return text
    }

    /// Extract text content from Gemini streaming response
    /// Format: `{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}`
    public func geminiContent() -> String? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            return nil
        }

        return text
    }

    /// Check if this is an OpenAI [DONE] event
    public var isOpenAIDone: Bool {
        data == "[DONE]"
    }

    /// Check if this is an Anthropic message_stop event
    public var isAnthropicDone: Bool {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String else {
            return false
        }
        return type == "message_stop"
    }
}
