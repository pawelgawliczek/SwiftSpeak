//
//  SwiftLinkTests.swift
//  SwiftSpeakTests
//
//  Unit tests for SwiftLink background dictation session functionality.
//

import Testing
import SwiftSpeakCore
import Foundation
@testable import SwiftSpeak

// MARK: - SwiftLinkApp Tests

@Suite("SwiftLinkApp Model Tests")
struct SwiftLinkAppTests {

    @Test func appHasRequiredProperties() {
        let app = SwiftLinkApp(
            bundleId: "com.example.app",
            name: "Example App",
            urlScheme: "example"
        )

        #expect(app.bundleId == "com.example.app")
        #expect(app.name == "Example App")
        #expect(app.urlScheme == "example")
        #expect(app.id == "com.example.app")
    }

    @Test func appWithoutURLScheme() {
        let app = SwiftLinkApp(
            bundleId: "com.example.noscheme",
            name: "No Scheme App",
            urlScheme: nil
        )

        #expect(app.urlScheme == nil)
        #expect(app.name == "No Scheme App")
    }

    @Test func appWithIconName() {
        let app = SwiftLinkApp(
            bundleId: "com.example.icon",
            name: "Icon App",
            urlScheme: "iconapp",
            iconName: "message.fill"
        )

        #expect(app.iconName == "message.fill")
    }

    @Test func appFromAppInfo() {
        let appInfo = AppInfo(
            bundleId: "net.whatsapp.WhatsApp",
            name: "WhatsApp",
            category: .messaging
        )

        let swiftLinkApp = SwiftLinkApp(from: appInfo)

        #expect(swiftLinkApp.bundleId == "net.whatsapp.WhatsApp")
        #expect(swiftLinkApp.name == "WhatsApp")
        #expect(swiftLinkApp.urlScheme == nil) // AppInfo doesn't have URL scheme
    }

    @Test func appEquality() {
        let app1 = SwiftLinkApp(bundleId: "com.test", name: "Test", urlScheme: nil)
        let app2 = SwiftLinkApp(bundleId: "com.test", name: "Test", urlScheme: nil)
        let app3 = SwiftLinkApp(bundleId: "com.other", name: "Other", urlScheme: nil)

        #expect(app1 == app2)
        #expect(app1 != app3)
    }

    @Test func appCodable() throws {
        let original = SwiftLinkApp(
            bundleId: "com.encode.test",
            name: "Encode Test",
            urlScheme: "encodetest",
            iconName: "star.fill"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SwiftLinkApp.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.bundleId == original.bundleId)
        #expect(decoded.urlScheme == original.urlScheme)
        #expect(decoded.iconName == original.iconName)
    }
}

// MARK: - SwiftLinkError Tests

@Suite("SwiftLinkError Tests")
struct SwiftLinkErrorTests {

    @Test func mustStartInForegroundError() {
        let error = SwiftLinkError.mustStartInForeground

        #expect(error.errorDescription?.contains("foreground") == true)
    }

    @Test func audioSessionFailedError() {
        let error = SwiftLinkError.audioSessionFailed("Microphone denied")

        #expect(error.errorDescription?.contains("Microphone denied") == true)
    }

    @Test func invalidAudioFormatError() {
        let error = SwiftLinkError.invalidAudioFormat

        #expect(error.errorDescription?.contains("audio format") == true)
    }

    @Test func sessionNotActiveError() {
        let error = SwiftLinkError.sessionNotActive

        #expect(error.errorDescription?.contains("session") == true)
    }

    @Test func recordingFailedError() {
        let error = SwiftLinkError.recordingFailed("Buffer overflow")

        #expect(error.errorDescription?.contains("Buffer overflow") == true)
    }
}

// MARK: - SwiftLinkSessionDuration Tests

@Suite("SwiftLinkSessionDuration Tests")
struct SwiftLinkSessionDurationTests {

    @Test func fiveMinutesDuration() {
        let duration = Constants.SwiftLinkSessionDuration.fiveMinutes

        #expect(duration.rawValue == 300)
        #expect(duration.timeInterval == 300)
        #expect(duration.displayName == "5 minutes")
    }

    @Test func fifteenMinutesDuration() {
        let duration = Constants.SwiftLinkSessionDuration.fifteenMinutes

        #expect(duration.rawValue == 900)
        #expect(duration.timeInterval == 900)
        #expect(duration.displayName == "15 minutes")
    }

    @Test func oneHourDuration() {
        let duration = Constants.SwiftLinkSessionDuration.oneHour

        #expect(duration.rawValue == 3600)
        #expect(duration.timeInterval == 3600)
        #expect(duration.displayName == "1 hour")
    }

    @Test func neverDuration() {
        let duration = Constants.SwiftLinkSessionDuration.never

        #expect(duration.rawValue == 0)
        #expect(duration.timeInterval == nil)
        #expect(duration.displayName == "Never (manual)")
    }

    @Test func allCasesAvailable() {
        let allCases = Constants.SwiftLinkSessionDuration.allCases

        #expect(allCases.count == 4)
        #expect(allCases.contains(.fiveMinutes))
        #expect(allCases.contains(.fifteenMinutes))
        #expect(allCases.contains(.oneHour))
        #expect(allCases.contains(.never))
    }

    @Test func durationFromRawValue() {
        #expect(Constants.SwiftLinkSessionDuration(rawValue: 300) == .fiveMinutes)
        #expect(Constants.SwiftLinkSessionDuration(rawValue: 900) == .fifteenMinutes)
        #expect(Constants.SwiftLinkSessionDuration(rawValue: 3600) == .oneHour)
        #expect(Constants.SwiftLinkSessionDuration(rawValue: 0) == .never)
        #expect(Constants.SwiftLinkSessionDuration(rawValue: 999) == nil)
    }
}

// MARK: - SwiftLink Constants Tests

@Suite("SwiftLink Constants Tests")
struct SwiftLinkConstantsTests {

    @Test func notificationNamesHaveCorrectPrefix() {
        let prefix = Constants.SwiftLinkNotifications.prefix

        #expect(prefix == "com.swiftspeak.swiftlink.")
        #expect(Constants.SwiftLinkNotifications.startDictation.hasPrefix(prefix))
        #expect(Constants.SwiftLinkNotifications.stopDictation.hasPrefix(prefix))
        #expect(Constants.SwiftLinkNotifications.resultReady.hasPrefix(prefix))
        #expect(Constants.SwiftLinkNotifications.sessionStarted.hasPrefix(prefix))
        #expect(Constants.SwiftLinkNotifications.sessionEnded.hasPrefix(prefix))
    }

    @Test func userDefaultsKeysExist() {
        // Verify all SwiftLink keys are defined
        #expect(Constants.Keys.swiftLinkApps == "swiftLinkApps")
        #expect(Constants.Keys.swiftLinkSessionDuration == "swiftLinkSessionDuration")
        #expect(Constants.Keys.swiftLinkLastUsedApp == "swiftLinkLastUsedApp")
        #expect(Constants.Keys.swiftLinkSessionActive == "swiftLinkSessionActive")
        #expect(Constants.Keys.swiftLinkSessionStartTime == "swiftLinkSessionStartTime")
        #expect(Constants.Keys.swiftLinkDictationStartTime == "swiftLinkDictationStartTime")
        #expect(Constants.Keys.swiftLinkDictationEndTime == "swiftLinkDictationEndTime")
        #expect(Constants.Keys.swiftLinkTranscriptionResult == "swiftLinkTranscriptionResult")
        #expect(Constants.Keys.swiftLinkProcessingStatus == "swiftLinkProcessingStatus")
    }
}

// MARK: - DarwinNotificationManager Tests

@Suite("DarwinNotificationManager Tests")
struct DarwinNotificationManagerTests {

    @Test func singletonExists() {
        let manager = DarwinNotificationManager.shared

        #expect(manager != nil)
    }

    @Test func canPostNotification() {
        // This test just verifies the method doesn't crash
        let manager = DarwinNotificationManager.shared
        manager.post(name: "com.test.notification")
        // If we get here without crashing, the test passes
    }

    @Test func canStartAndStopObserving() {
        let manager = DarwinNotificationManager.shared
        let testName = "com.test.observe.\(UUID().uuidString)"
        var callbackCalled = false

        manager.startObserving(name: testName) {
            callbackCalled = true
        }

        // Stop observing
        manager.stopObserving(name: testName)

        // Post notification - should not trigger callback since we stopped
        manager.post(name: testName)

        // Give a tiny bit of time for any async delivery
        Thread.sleep(forTimeInterval: 0.1)

        // Callback should not have been called since we stopped observing first
        #expect(callbackCalled == false)
    }
}
