//
//  SSEParserTests.swift
//  SwiftSpeakTests
//
//  Tests for SSEParser - Server-Sent Events parsing
//

import Testing
import Foundation
@testable import SwiftSpeak

struct SSEParserTests {

    // MARK: - Basic Parsing

    @Test func parsesSimpleDataEvent() async {
        let parser = SSEParser()
        let events = await parser.parse("data: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.data == "hello")
        #expect(events.first?.event == nil)
    }

    @Test func parsesEventWithType() async {
        let parser = SSEParser()
        let events = await parser.parse("event: message\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.event == "message")
        #expect(events.first?.data == "hello")
    }

    @Test func parsesEventWithId() async {
        let parser = SSEParser()
        let events = await parser.parse("id: 123\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.id == "123")
        #expect(events.first?.data == "hello")
    }

    @Test func parsesEventWithRetry() async {
        let parser = SSEParser()
        let events = await parser.parse("retry: 5000\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.retry == 5000)
        #expect(events.first?.data == "hello")
    }

    // MARK: - Multi-line Data

    @Test func parsesMultiLineData() async {
        let parser = SSEParser()
        let events = await parser.parse("data: line1\ndata: line2\ndata: line3\n\n")

        #expect(events.count == 1)
        #expect(events.first?.data == "line1\nline2\nline3")
    }

    // MARK: - Multiple Events

    @Test func parsesMultipleEvents() async {
        let parser = SSEParser()
        let events = await parser.parse("data: first\n\ndata: second\n\n")

        #expect(events.count == 2)
        #expect(events[0].data == "first")
        #expect(events[1].data == "second")
    }

    // MARK: - Comments

    @Test func ignoresComments() async {
        let parser = SSEParser()
        let events = await parser.parse(": this is a comment\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.data == "hello")
    }

    @Test func ignoresOnlyComments() async {
        let parser = SSEParser()
        let events = await parser.parse(": comment only\n\n")

        #expect(events.isEmpty)
    }

    // MARK: - Edge Cases

    @Test func handlesEmptyData() async {
        let parser = SSEParser()
        let events = await parser.parse("data:\n\n")

        #expect(events.count == 1)
        #expect(events.first?.data == "")
    }

    @Test func handlesDataWithLeadingSpace() async {
        let parser = SSEParser()
        let events = await parser.parse("data: hello world\n\n")

        #expect(events.first?.data == "hello world")
    }

    @Test func handlesCRLFLineEndings() async {
        let parser = SSEParser()
        // CRLF at end of data line should be stripped
        _ = await parser.parse("data: hello\r\n")
        // LF-only for empty line terminator (common in practice)
        let events = await parser.parse("\n")

        #expect(events.count == 1)
        #expect(events.first?.data == "hello")
    }

    @Test func ignoresUnknownFields() async {
        let parser = SSEParser()
        let events = await parser.parse("unknown: value\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.data == "hello")
    }

    @Test func ignoresEmptyEventsWithoutData() async {
        let parser = SSEParser()
        let events = await parser.parse("event: test\n\n")

        #expect(events.isEmpty)
    }

    @Test func ignoresIdWithNullCharacter() async {
        let parser = SSEParser()
        let events = await parser.parse("id: test\u{0000}value\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.id == nil)
    }

    @Test func ignoresNonNumericRetry() async {
        let parser = SSEParser()
        let events = await parser.parse("retry: abc\ndata: hello\n\n")

        #expect(events.count == 1)
        #expect(events.first?.retry == nil)
    }

    // MARK: - Chunked Input

    @Test func handlesChunkedInput() async {
        let parser = SSEParser()

        // First chunk - incomplete
        let events1 = await parser.parse("data: hel")
        #expect(events1.isEmpty)

        // Second chunk - completes the event
        let events2 = await parser.parse("lo\n\n")
        #expect(events2.count == 1)
        #expect(events2.first?.data == "hello")
    }

    @Test func handlesMultipleChunksForOneEvent() async {
        let parser = SSEParser()

        let events1 = await parser.parse("event: ")
        #expect(events1.isEmpty)

        let events2 = await parser.parse("message\n")
        #expect(events2.isEmpty)

        let events3 = await parser.parse("data: test\n")
        #expect(events3.isEmpty)

        let events4 = await parser.parse("\n")
        #expect(events4.count == 1)
        #expect(events4.first?.event == "message")
        #expect(events4.first?.data == "test")
    }

    // MARK: - Reset

    @Test func resetClearsBuffer() async {
        let parser = SSEParser()

        // Partial input
        _ = await parser.parse("data: incomplete")
        #expect(await parser.hasBufferedContent)

        await parser.reset()
        #expect(await !parser.hasBufferedContent)
    }

    // MARK: - OpenAI Content Extraction

    @Test func extractsOpenAIContent() {
        let event = SSEEvent(data: #"{"choices":[{"delta":{"content":"Hello"}}]}"#)
        #expect(event.openAIContent() == "Hello")
    }

    @Test func returnsNilForOpenAIDone() {
        let event = SSEEvent(data: "[DONE]")
        #expect(event.openAIContent() == nil)
        #expect(event.isOpenAIDone)
    }

    @Test func returnsNilForInvalidOpenAIJson() {
        let event = SSEEvent(data: "invalid json")
        #expect(event.openAIContent() == nil)
    }

    @Test func returnsNilForOpenAIWithoutContent() {
        let event = SSEEvent(data: #"{"choices":[{"delta":{}}]}"#)
        #expect(event.openAIContent() == nil)
    }

    // MARK: - Anthropic Content Extraction

    @Test func extractsAnthropicContent() {
        let event = SSEEvent(data: #"{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}"#)
        #expect(event.anthropicContent() == "Hello")
    }

    @Test func returnsNilForAnthropicNonTextDelta() {
        let event = SSEEvent(data: #"{"type":"message_start","message":{}}"#)
        #expect(event.anthropicContent() == nil)
    }

    @Test func detectsAnthropicDone() {
        let event = SSEEvent(data: #"{"type":"message_stop"}"#)
        #expect(event.isAnthropicDone)
        #expect(event.anthropicContent() == nil)
    }

    // MARK: - Gemini Content Extraction

    @Test func extractsGeminiContent() {
        let event = SSEEvent(data: #"{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}"#)
        #expect(event.geminiContent() == "Hello")
    }

    @Test func returnsNilForInvalidGeminiJson() {
        let event = SSEEvent(data: #"{"candidates":[]}"#)
        #expect(event.geminiContent() == nil)
    }

    // MARK: - Complete Stream Simulation

    @Test func parsesOpenAIStreamSimulation() async {
        let parser = SSEParser()
        // Simulate line-by-line streaming as URLSession.bytes.lines would provide
        _ = await parser.parse("data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}\n")
        let events1 = await parser.parse("\n")
        _ = await parser.parse("data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n")
        let events2 = await parser.parse("\n")
        _ = await parser.parse("data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n")
        let events3 = await parser.parse("\n")
        _ = await parser.parse("data: [DONE]\n")
        let events4 = await parser.parse("\n")

        let allEvents = events1 + events2 + events3 + events4
        #expect(allEvents.count == 4)

        let contents = allEvents.compactMap { $0.openAIContent() }
        #expect(contents == ["Hello", " world"])
    }

    @Test func parsesAnthropicStreamSimulation() async {
        let parser = SSEParser()
        // Simulate line-by-line streaming
        _ = await parser.parse("event: message_start\n")
        _ = await parser.parse("data: {\"type\":\"message_start\",\"message\":{}}\n")
        let events1 = await parser.parse("\n")

        _ = await parser.parse("event: content_block_delta\n")
        _ = await parser.parse("data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n")
        let events2 = await parser.parse("\n")

        _ = await parser.parse("event: content_block_delta\n")
        _ = await parser.parse("data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\" world\"}}\n")
        let events3 = await parser.parse("\n")

        _ = await parser.parse("event: message_stop\n")
        _ = await parser.parse("data: {\"type\":\"message_stop\"}\n")
        let events4 = await parser.parse("\n")

        let allEvents = events1 + events2 + events3 + events4
        #expect(allEvents.count == 4)

        let contents = allEvents.compactMap { $0.anthropicContent() }
        #expect(contents == ["Hello", " world"])

        #expect(allEvents.last?.isAnthropicDone == true)
    }
}
