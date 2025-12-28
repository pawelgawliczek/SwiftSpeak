//
//  WebhookExecutorTests.swift
//  SwiftSpeakTests
//
//  Tests for WebhookExecutor - webhook execution for Power Mode workflows
//

import Testing
import Foundation
@testable import SwiftSpeak

// MARK: - Mock URL Protocol

/// Thread-safe mock URL protocol for testing
final class MockWebhookURLProtocol: URLProtocol {
    // Use the URL path as key to avoid collisions between parallel tests
    nonisolated(unsafe) static var mockResponses: [String: (Data?, URLResponse?, Error?)] = [:]
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []
    static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.capturedRequests.append(request)
        Self.lock.unlock()

        // Use full URL string as key
        let key = request.url?.absoluteString ?? ""

        Self.lock.lock()
        let mock = Self.mockResponses[key]
        Self.lock.unlock()

        if let mock = mock {
            if let error = mock.2 {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                if let response = mock.1 {
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data = mock.0 {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            }
        } else {
            let error = NSError(domain: "MockURLProtocol", code: 404, userInfo: [NSLocalizedDescriptionKey: "No mock response for \(key)"])
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        lock.lock()
        mockResponses = [:]
        capturedRequests = []
        lock.unlock()
    }

    static func setMock(for url: URL, data: Data?, response: URLResponse?, error: Error?) {
        lock.lock()
        mockResponses[url.absoluteString] = (data, response, error)
        lock.unlock()
    }

    static func getLastRequest() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests.last
    }

    static func getRequests(for url: URL) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests.filter { $0.url?.absoluteString == url.absoluteString }
    }
}

// MARK: - Test Helpers

@MainActor
func createMockWebhookSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockWebhookURLProtocol.self]
    return URLSession(configuration: config)
}

@MainActor
func createTestWebhook(
    id: UUID = UUID(),
    name: String = "Test Webhook",
    type: WebhookType = .outputDestination,
    url: URL = URL(string: "https://test.example.com/webhook")!,
    authType: WebhookAuthType = .none,
    authToken: String? = nil,
    authHeader: String? = nil
) -> Webhook {
    var webhook = Webhook(
        id: id,
        name: name,
        type: type,
        template: .custom,
        url: url,
        isEnabled: true,
        authType: authType,
        authToken: authToken,
        includeInput: true,
        includeOutput: true,
        includeModeName: true,
        includeContext: true,
        includeTimestamp: true
    )
    if let authHeader = authHeader {
        webhook.authHeader = authHeader
    }
    return webhook
}

@MainActor
func createTestPowerMode(
    id: UUID = UUID(),
    name: String = "Test Power Mode",
    enabledWebhookIds: [UUID] = []
) -> PowerMode {
    PowerMode(
        id: id,
        name: name,
        icon: "bolt.fill",
        iconColor: .orange,
        iconBackgroundColor: .orange,
        instruction: "Test instruction",
        outputFormat: "Test format",
        enabledWebhookIds: enabledWebhookIds
    )
}

// MARK: - Test Webhook Tests (Most Reliable - No SharedSettings Dependencies)

@Suite("WebhookExecutor - Test Webhook")
@MainActor
struct WebhookExecutorTestWebhookTests {

    @Test("Test webhook returns success for 200 response")
    func testWebhookSuccess() async {
        // Use unique URL per test to avoid collisions
        let url = URL(string: "https://test-webhook-success-\(UUID().uuidString).example.com/test")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "Test OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .outputDestination, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        let result = await executor.testWebhook(webhook)

        #expect(result.success == true)
        #expect(result.statusCode == 200)
        #expect(result.responseBody == "Test OK")
        #expect(result.error == nil)
        #expect(result.duration >= 0)
    }

    @Test("Test webhook returns failure for error response")
    func testWebhookFailure() async {
        let url = URL(string: "https://test-webhook-fail-\(UUID().uuidString).example.com/test")!
        let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "Unauthorized".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .outputDestination, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        let result = await executor.testWebhook(webhook)

        #expect(result.success == false)
        #expect(result.statusCode == 401)
        #expect(result.error?.contains("401") == true)
    }

    @Test("Test webhook uses GET for context source")
    func testWebhookUsesGetForContextSource() async {
        let url = URL(string: "https://test-get-\(UUID().uuidString).example.com/context")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "Context".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .contextSource, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        #expect(requests.first?.httpMethod == "GET")
    }

    @Test("Test webhook uses POST for output destination")
    func testWebhookUsesPostForOutputDestination() async {
        let url = URL(string: "https://test-post-\(UUID().uuidString).example.com/output")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .outputDestination, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        #expect(requests.first?.httpMethod == "POST")
    }

    @Test("Test webhook handles network error")
    func testWebhookHandlesNetworkError() async {
        let url = URL(string: "https://test-network-error-\(UUID().uuidString).example.com/fail")!
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        MockWebhookURLProtocol.setMock(for: url, data: nil, response: nil, error: error)

        let webhook = createTestWebhook(type: .outputDestination, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        let result = await executor.testWebhook(webhook)

        #expect(result.success == false)
        #expect(result.error != nil)
    }

    @Test("Test webhook uses POST for automation trigger")
    func testWebhookUsesPostForAutomationTrigger() async {
        let url = URL(string: "https://test-automation-\(UUID().uuidString).zapier.com/hook")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .automationTrigger, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        #expect(requests.first?.httpMethod == "POST")
    }
}

// MARK: - Authentication Tests

@Suite("WebhookExecutor - Authentication")
@MainActor
struct WebhookExecutorAuthTests {

    @Test("Applies bearer token authentication")
    func appliesBearerAuth() async {
        let url = URL(string: "https://auth-bearer-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(
            type: .outputDestination,
            url: url,
            authType: .bearerToken,
            authToken: "my-secret-token-123"
        )
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        let authHeader = requests.first?.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer my-secret-token-123")
    }

    @Test("Applies API key header authentication")
    func appliesApiKeyAuth() async {
        let url = URL(string: "https://auth-apikey-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(
            type: .outputDestination,
            url: url,
            authType: .apiKeyHeader,
            authToken: "api-key-xyz789",
            authHeader: "X-Custom-API-Key"
        )
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        let apiKeyHeader = requests.first?.value(forHTTPHeaderField: "X-Custom-API-Key")
        #expect(apiKeyHeader == "api-key-xyz789")
    }

    @Test("Applies basic authentication")
    func appliesBasicAuth() async {
        let url = URL(string: "https://auth-basic-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(
            type: .outputDestination,
            url: url,
            authType: .basicAuth,
            authToken: "user:password"
        )
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        let authHeader = requests.first?.value(forHTTPHeaderField: "Authorization")
        let expectedBase64 = "user:password".data(using: .utf8)!.base64EncodedString()
        #expect(authHeader == "Basic \(expectedBase64)")
    }

    @Test("Uses default X-API-Key header when custom header not specified")
    func usesDefaultApiKeyHeader() async {
        let url = URL(string: "https://auth-default-apikey-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(
            type: .outputDestination,
            url: url,
            authType: .apiKeyHeader,
            authToken: "default-api-key"
        )
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        let apiKeyHeader = requests.first?.value(forHTTPHeaderField: "X-API-Key")
        #expect(apiKeyHeader == "default-api-key")
    }
}

// MARK: - Payload Tests

@Suite("WebhookExecutor - Payload")
@MainActor
struct WebhookExecutorPayloadTests {

    @Test("POST request includes JSON content type")
    func postRequestIncludesJsonContentType() async {
        let url = URL(string: "https://payload-json-\(UUID().uuidString).example.com/webhook")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .outputDestination, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        let contentType = requests.first?.value(forHTTPHeaderField: "Content-Type")
        #expect(contentType == "application/json")
    }

    @Test("Test payload includes expected test data")
    func testPayloadIncludesTestData() async {
        let url = URL(string: "https://payload-test-\(UUID().uuidString).example.com/webhook")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(type: .outputDestination, url: url)
        let settings = SharedSettings.shared
        let session = createMockWebhookSession()
        let executor = WebhookExecutor(settings: settings, session: session)

        _ = await executor.testWebhook(webhook)

        let requests = MockWebhookURLProtocol.getRequests(for: url)
        if let body = requests.first?.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            // Test payload should have input and output
            #expect(json["input"] != nil || json["output"] != nil)
        }
    }
}

// MARK: - Status Code Tests

@Suite("WebhookExecutor - Status Codes")
@MainActor
struct WebhookExecutorStatusCodeTests {

    @Test("200 OK is success")
    func status200IsSuccess() async {
        let url = URL(string: "https://status-200-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(url: url)
        let executor = WebhookExecutor(settings: SharedSettings.shared, session: createMockWebhookSession())

        let result = await executor.testWebhook(webhook)
        #expect(result.success == true)
    }

    @Test("201 Created is success")
    func status201IsSuccess() async {
        let url = URL(string: "https://status-201-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "Created".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(url: url)
        let executor = WebhookExecutor(settings: SharedSettings.shared, session: createMockWebhookSession())

        let result = await executor.testWebhook(webhook)
        #expect(result.success == true)
    }

    @Test("299 is success")
    func status299IsSuccess() async {
        let url = URL(string: "https://status-299-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 299, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "OK".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(url: url)
        let executor = WebhookExecutor(settings: SharedSettings.shared, session: createMockWebhookSession())

        let result = await executor.testWebhook(webhook)
        #expect(result.success == true)
    }

    @Test("300 redirect is failure")
    func status300IsFailure() async {
        let url = URL(string: "https://status-300-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 300, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: nil, response: response, error: nil)

        let webhook = createTestWebhook(url: url)
        let executor = WebhookExecutor(settings: SharedSettings.shared, session: createMockWebhookSession())

        let result = await executor.testWebhook(webhook)
        #expect(result.success == false)
    }

    @Test("400 Bad Request is failure")
    func status400IsFailure() async {
        let url = URL(string: "https://status-400-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "Bad Request".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(url: url)
        let executor = WebhookExecutor(settings: SharedSettings.shared, session: createMockWebhookSession())

        let result = await executor.testWebhook(webhook)
        #expect(result.success == false)
        #expect(result.error?.contains("400") == true)
    }

    @Test("500 Server Error is failure")
    func status500IsFailure() async {
        let url = URL(string: "https://status-500-\(UUID().uuidString).example.com/api")!
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)
        MockWebhookURLProtocol.setMock(for: url, data: "Server Error".data(using: .utf8), response: response, error: nil)

        let webhook = createTestWebhook(url: url)
        let executor = WebhookExecutor(settings: SharedSettings.shared, session: createMockWebhookSession())

        let result = await executor.testWebhook(webhook)
        #expect(result.success == false)
        #expect(result.error?.contains("500") == true)
    }
}
