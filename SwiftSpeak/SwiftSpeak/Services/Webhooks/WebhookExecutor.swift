//
//  WebhookExecutor.swift
//  SwiftSpeak
//
//  Phase 4f: Execute webhooks for Power Mode workflows
//  - Context Sources: GET data before processing
//  - Output Destinations: POST results after completion
//  - Automation Triggers: POST to Make/Zapier workflows
//

import Foundation
import SwiftSpeakCore

// MARK: - Webhook Executor

@MainActor
final class WebhookExecutor {

    // MARK: - Types

    struct WebhookResult: Sendable {
        let webhookId: UUID
        let success: Bool
        let statusCode: Int?
        let responseBody: String?
        let error: String?
        let duration: TimeInterval
    }

    struct ContextSourceResult: Sendable {
        let webhookId: UUID
        let webhookName: String
        let content: String?
        let error: String?
    }

    // MARK: - Properties

    private let session: URLSession
    private let settings: SharedSettings

    // MARK: - Initialization

    init(settings: SharedSettings, session: URLSession? = nil) {
        self.settings = settings

        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Context Source Execution

    /// Execute all enabled context source webhooks for a Power Mode
    /// Returns combined context from all successful webhooks
    func fetchContext(for powerMode: PowerMode) async -> [ContextSourceResult] {
        let contextWebhooks = settings.enabledWebhooks(for: powerMode, ofType: .contextSource)

        guard !contextWebhooks.isEmpty else { return [] }

        var results: [ContextSourceResult] = []

        await withTaskGroup(of: ContextSourceResult.self) { group in
            for webhook in contextWebhooks {
                group.addTask {
                    await self.executeContextSource(webhook)
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Update webhook statuses
        for result in results {
            let status = result.error == nil ? "Success" : "Failed: \(result.error ?? "Unknown")"
            settings.updateWebhookStatus(id: result.webhookId, status: status)
        }

        return results
    }

    private func executeContextSource(_ webhook: Webhook) async -> ContextSourceResult {
        do {
            var request = URLRequest(url: webhook.url)
            request.httpMethod = "GET"
            applyAuthentication(to: &request, webhook: webhook)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return ContextSourceResult(
                    webhookId: webhook.id,
                    webhookName: webhook.name,
                    content: nil,
                    error: "Invalid response"
                )
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return ContextSourceResult(
                    webhookId: webhook.id,
                    webhookName: webhook.name,
                    content: nil,
                    error: "HTTP \(httpResponse.statusCode)"
                )
            }

            let content = String(data: data, encoding: .utf8)
            return ContextSourceResult(
                webhookId: webhook.id,
                webhookName: webhook.name,
                content: content,
                error: nil
            )
        } catch {
            return ContextSourceResult(
                webhookId: webhook.id,
                webhookName: webhook.name,
                content: nil,
                error: error.localizedDescription
            )
        }
    }

    // MARK: - Output Destination Execution

    /// Execute all enabled output destination webhooks for a Power Mode
    func sendOutput(
        for powerMode: PowerMode,
        input: String,
        output: String,
        contextName: String?
    ) async -> [WebhookResult] {
        let outputWebhooks = settings.enabledWebhooks(for: powerMode, ofType: .outputDestination)

        guard !outputWebhooks.isEmpty else { return [] }

        var results: [WebhookResult] = []

        await withTaskGroup(of: WebhookResult.self) { group in
            for webhook in outputWebhooks {
                group.addTask {
                    await self.executeOutputDestination(
                        webhook,
                        powerModeName: powerMode.name,
                        input: input,
                        output: output,
                        contextName: contextName
                    )
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Update webhook statuses
        for result in results {
            let status = result.success ? "Success" : "Failed: \(result.error ?? "Unknown")"
            settings.updateWebhookStatus(id: result.webhookId, status: status)
        }

        return results
    }

    private func executeOutputDestination(
        _ webhook: Webhook,
        powerModeName: String,
        input: String,
        output: String,
        contextName: String?
    ) async -> WebhookResult {
        let startTime = Date()

        do {
            var request = URLRequest(url: webhook.url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            applyAuthentication(to: &request, webhook: webhook)

            let payload = buildPayload(
                webhook: webhook,
                powerModeName: powerModeName,
                input: input,
                output: output,
                contextName: contextName
            )

            request.httpBody = try JSONEncoder().encode(payload)

            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return WebhookResult(
                    webhookId: webhook.id,
                    success: false,
                    statusCode: nil,
                    responseBody: nil,
                    error: "Invalid response",
                    duration: duration
                )
            }

            let responseBody = String(data: data, encoding: .utf8)
            let success = (200...299).contains(httpResponse.statusCode)

            return WebhookResult(
                webhookId: webhook.id,
                success: success,
                statusCode: httpResponse.statusCode,
                responseBody: responseBody,
                error: success ? nil : "HTTP \(httpResponse.statusCode)",
                duration: duration
            )
        } catch {
            return WebhookResult(
                webhookId: webhook.id,
                success: false,
                statusCode: nil,
                responseBody: nil,
                error: error.localizedDescription,
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }

    // MARK: - Automation Trigger Execution

    /// Execute all enabled automation trigger webhooks for a Power Mode
    func triggerAutomations(
        for powerMode: PowerMode,
        input: String,
        output: String,
        contextName: String?
    ) async -> [WebhookResult] {
        let triggerWebhooks = settings.enabledWebhooks(for: powerMode, ofType: .automationTrigger)

        guard !triggerWebhooks.isEmpty else { return [] }

        var results: [WebhookResult] = []

        await withTaskGroup(of: WebhookResult.self) { group in
            for webhook in triggerWebhooks {
                group.addTask {
                    await self.executeAutomationTrigger(
                        webhook,
                        powerModeName: powerMode.name,
                        input: input,
                        output: output,
                        contextName: contextName
                    )
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Update webhook statuses
        for result in results {
            let status = result.success ? "Success" : "Failed: \(result.error ?? "Unknown")"
            settings.updateWebhookStatus(id: result.webhookId, status: status)
        }

        return results
    }

    private func executeAutomationTrigger(
        _ webhook: Webhook,
        powerModeName: String,
        input: String,
        output: String,
        contextName: String?
    ) async -> WebhookResult {
        // Same implementation as output destination for now
        // Could be customized for specific automation platforms
        await executeOutputDestination(
            webhook,
            powerModeName: powerModeName,
            input: input,
            output: output,
            contextName: contextName
        )
    }

    // MARK: - Test Webhook

    /// Test a webhook configuration
    func testWebhook(_ webhook: Webhook) async -> WebhookResult {
        let startTime = Date()

        do {
            var request = URLRequest(url: webhook.url)

            switch webhook.type {
            case .contextSource:
                request.httpMethod = "GET"
            case .outputDestination, .automationTrigger:
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let testPayload = buildPayload(
                    webhook: webhook,
                    powerModeName: "Test Power Mode",
                    input: "This is a test input from SwiftSpeak",
                    output: "This is a test output from SwiftSpeak webhook test",
                    contextName: "Test Context"
                )
                request.httpBody = try JSONEncoder().encode(testPayload)
            }

            applyAuthentication(to: &request, webhook: webhook)

            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)

            guard let httpResponse = response as? HTTPURLResponse else {
                return WebhookResult(
                    webhookId: webhook.id,
                    success: false,
                    statusCode: nil,
                    responseBody: nil,
                    error: "Invalid response",
                    duration: duration
                )
            }

            let responseBody = String(data: data, encoding: .utf8)
            let success = (200...299).contains(httpResponse.statusCode)

            return WebhookResult(
                webhookId: webhook.id,
                success: success,
                statusCode: httpResponse.statusCode,
                responseBody: responseBody,
                error: success ? nil : "HTTP \(httpResponse.statusCode)",
                duration: duration
            )
        } catch {
            return WebhookResult(
                webhookId: webhook.id,
                success: false,
                statusCode: nil,
                responseBody: nil,
                error: error.localizedDescription,
                duration: Date().timeIntervalSince(startTime)
            )
        }
    }

    // MARK: - Helpers

    private func applyAuthentication(to request: inout URLRequest, webhook: Webhook) {
        switch webhook.authType {
        case .none:
            break
        case .bearerToken:
            if let token = webhook.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .apiKeyHeader:
            if let token = webhook.authToken {
                let header = webhook.authHeader ?? "X-API-Key"
                request.setValue(token, forHTTPHeaderField: header)
            }
        case .basicAuth:
            if let token = webhook.authToken,
               let data = token.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }
    }

    private func buildPayload(
        webhook: Webhook,
        powerModeName: String,
        input: String,
        output: String,
        contextName: String?
    ) -> WebhookPayload {
        WebhookPayload(
            input: webhook.includeInput ? input : nil,
            output: webhook.includeOutput ? output : nil,
            powerModeName: webhook.includeModeName ? powerModeName : nil,
            contextName: webhook.includeContext ? contextName : nil,
            timestamp: webhook.includeTimestamp ? ISO8601DateFormatter().string(from: Date()) : nil
        )
    }
}

// MARK: - Webhook Payload

struct WebhookPayload: Codable {
    let input: String?
    let output: String?
    let powerModeName: String?
    let contextName: String?
    let timestamp: String?

    // Slack-specific formatting
    var slackText: String? {
        guard let output = output else { return nil }
        return output
    }
}
