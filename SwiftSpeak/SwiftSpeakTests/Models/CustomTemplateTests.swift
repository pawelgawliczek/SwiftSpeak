//
//  CustomTemplateTests.swift
//  SwiftSpeakTests
//
//  Tests for CustomTemplate model
//

import Testing
import Foundation
@testable import SwiftSpeak

@MainActor
struct CustomTemplateTests {

    // MARK: - Basic Properties

    @Test func templateHasRequiredProperties() {
        let template = CustomTemplate(
            id: UUID(),
            name: "Test Template",
            prompt: "Format as a test",
            icon: "doc.text",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(!template.name.isEmpty)
        #expect(!template.prompt.isEmpty)
        #expect(!template.icon.isEmpty)
    }

    @Test func templateHasUniqueId() {
        let template1 = CustomTemplate(
            id: UUID(),
            name: "Template 1",
            prompt: "Prompt 1",
            icon: "doc.text",
            createdAt: Date(),
            updatedAt: Date()
        )

        let template2 = CustomTemplate(
            id: UUID(),
            name: "Template 2",
            prompt: "Prompt 2",
            icon: "doc.text",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(template1.id != template2.id)
    }

    // MARK: - Codable

    @Test func templateEncodesAndDecodes() throws {
        let template = CustomTemplate(
            id: UUID(),
            name: "Test Template",
            prompt: "Format this text as meeting notes",
            icon: "list.bullet",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(template)
        let decoded = try decoder.decode(CustomTemplate.self, from: data)

        #expect(decoded.id == template.id)
        #expect(decoded.name == template.name)
        #expect(decoded.prompt == template.prompt)
        #expect(decoded.icon == template.icon)
    }

    @Test func multipleTemplatesEncodeAndDecode() throws {
        let templates = [
            CustomTemplate(
                id: UUID(),
                name: "Meeting Notes",
                prompt: "Format as meeting notes",
                icon: "list.bullet",
                createdAt: Date(),
                updatedAt: Date()
            ),
            CustomTemplate(
                id: UUID(),
                name: "Summary",
                prompt: "Summarize this text",
                icon: "doc.text",
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(templates)
        let decoded = try decoder.decode([CustomTemplate].self, from: data)

        #expect(decoded.count == templates.count)
        #expect(decoded[0].name == templates[0].name)
        #expect(decoded[1].name == templates[1].name)
    }

    // MARK: - Identifiable

    @Test func templateIsIdentifiable() {
        let template = CustomTemplate(
            id: UUID(),
            name: "Test",
            prompt: "Test prompt",
            icon: "star",
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(template.id == template.id)
    }

    // MARK: - Edge Cases

    @Test func templateWithSpecialCharacters() throws {
        let template = CustomTemplate(
            id: UUID(),
            name: "Test with émojis 🎤",
            prompt: "Format with special chars: <>&\"'",
            icon: "doc.text.fill",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(template)
        let decoded = try decoder.decode(CustomTemplate.self, from: data)

        #expect(decoded.name == template.name)
        #expect(decoded.prompt == template.prompt)
    }

    @Test func templateWithLongPrompt() throws {
        let longPrompt = String(repeating: "This is a very long prompt. ", count: 100)
        let template = CustomTemplate(
            id: UUID(),
            name: "Long Prompt Template",
            prompt: longPrompt,
            icon: "doc.text",
            createdAt: Date(),
            updatedAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(template)
        let decoded = try decoder.decode(CustomTemplate.self, from: data)

        #expect(decoded.prompt == longPrompt)
    }
}
