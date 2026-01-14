//
//  ContextCaptureManager.swift
//  SwiftSpeak
//
//  Manages screen context capture via ReplayKit Broadcast Extension.
//  Provides captured text context for voice transcription formatting.
//

import Foundation
import ReplayKit
import Combine
import SwiftSpeakCore

@MainActor
public class ContextCaptureManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = ContextCaptureManager()

    // MARK: - Published Properties

    @Published public private(set) var isCapturing: Bool = false
    @Published public private(set) var lastCapturedContext: String?
    @Published public private(set) var lastCaptureTime: Date?
    @Published public private(set) var framesCaptured: Int = 0

    // MARK: - Private Properties

    private let appGroupDefaults = UserDefaults(suiteName: SwiftSpeakCore.Constants.appGroupIdentifier)
    private var refreshTimer: Timer?
    private var ocrCompletionContinuation: CheckedContinuation<String?, Never>?

    // Keys matching the broadcast extension
    private enum Keys {
        static let latestScreenContext = "contextCapture_latestText"
        static let latestContextTime = "contextCapture_timestamp"
        static let isCapturing = "contextCapture_isActive"
        static let framesCaptured = "contextCapture_frameCount"
        static let ocrRequested = "contextCapture_ocrRequested"
    }

    // MARK: - Initialization

    private init() {
        // Load initial state
        refreshState()

        // Validate capture state on startup - clear stale state if capture appears stuck
        validateCaptureState()

        // Listen for Darwin notifications from broadcast extension
        setupNotificationListeners()
    }

    /// Validate capture state on startup - clear if stale
    private func validateCaptureState() {
        guard isCapturing else { return }

        // If capture claims to be active but last capture time is very old (> 2 min), it's stale
        if let lastTime = lastCaptureTime {
            let age = Date().timeIntervalSince(lastTime)
            if age > 120 { // 2 minutes
                appLog("Clearing stale capture state on startup (last capture: \(Int(age))s ago)", category: "ContextCapture", level: .warning)
                clearStaleState()
            }
        } else {
            // No capture time but claims to be capturing - likely stale
            appLog("Clearing stale capture state on startup (no capture time recorded)", category: "ContextCapture", level: .warning)
            clearStaleState()
        }
    }

    // MARK: - Public API

    /// Get the latest captured screen context for transcription
    /// - Parameter maxAge: Maximum age of context in seconds (default 30)
    /// - Returns: Captured text if available and recent enough
    public func getLatestContext(maxAge: TimeInterval = 30) -> String? {
        refreshState()

        guard let context = lastCapturedContext,
              let captureTime = lastCaptureTime,
              Date().timeIntervalSince(captureTime) < maxAge else {
            return nil
        }

        return context
    }

    /// Check if context capture is currently enabled in settings
    public var isEnabled: Bool {
        get { SharedSettings.shared.contextCaptureEnabled }
        set { SharedSettings.shared.contextCaptureEnabled = newValue }
    }

    /// Refresh state from App Group (call before checking status)
    public func refreshState() {
        isCapturing = appGroupDefaults?.bool(forKey: Keys.isCapturing) ?? false
        lastCapturedContext = appGroupDefaults?.string(forKey: Keys.latestScreenContext)
        lastCaptureTime = appGroupDefaults?.object(forKey: Keys.latestContextTime) as? Date
        framesCaptured = appGroupDefaults?.integer(forKey: Keys.framesCaptured) ?? 0
    }

    /// Clear stored context (e.g., when SwiftLink session ends)
    public func clearContext() {
        appGroupDefaults?.removeObject(forKey: Keys.latestScreenContext)
        appGroupDefaults?.removeObject(forKey: Keys.latestContextTime)
        lastCapturedContext = nil
        lastCaptureTime = nil
        appLog("Context capture cleared", category: "ContextCapture")
    }

    /// Request fresh OCR from the broadcast extension and wait for result
    /// - Parameter timeout: Maximum time to wait for OCR in seconds (default 5)
    /// - Returns: Fresh screen context or nil if not available
    public func requestFreshContext(timeout: TimeInterval = 5.0) async -> String? {
        refreshState()

        // Check if capture is active
        guard isCapturing else {
            appLog("Cannot request OCR - capture not active", category: "ContextCapture", level: .warning)
            return nil
        }

        appLog("Requesting fresh OCR from broadcast extension", category: "ContextCapture")

        // Request OCR via Darwin notification
        postOCRRequest()

        // Wait for OCR completion with timeout
        let result = await withCheckedContinuation { continuation in
            self.ocrCompletionContinuation = continuation

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                // If continuation hasn't been resumed yet, resume with nil
                if let pending = self.ocrCompletionContinuation {
                    self.ocrCompletionContinuation = nil
                    appLog("OCR request timed out after \(timeout)s - clearing stale capture state", category: "ContextCapture", level: .warning)
                    // Clear the stale isCapturing flag since broadcast isn't responding
                    self.clearStaleState()
                    pending.resume(returning: nil)
                }
            }
        }

        return result
    }

    /// Clear stale capture state (called when broadcast doesn't respond)
    private func clearStaleState() {
        appGroupDefaults?.set(false, forKey: Keys.isCapturing)
        appGroupDefaults?.synchronize()
        isCapturing = false
        appLog("Cleared stale capture state - broadcast not responding", category: "ContextCapture")
    }

    /// Post Darwin notification to request OCR from broadcast extension
    private func postOCRRequest() {
        // Also set flag in UserDefaults as fallback
        appGroupDefaults?.set(true, forKey: Keys.ocrRequested)
        appGroupDefaults?.synchronize()

        // Post Darwin notification
        let notifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            notifyCenter,
            CFNotificationName("com.swiftspeak.contextCapture.requestOCR" as CFString),
            nil,
            nil,
            true
        )
    }

    /// Start periodic refresh while capturing (for UI updates)
    public func startMonitoring() {
        stopMonitoring()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshState()
            }
        }
        appLog("Started context capture monitoring", category: "ContextCapture")
    }

    /// Stop periodic refresh
    public func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Darwin Notification Listeners

    private func setupNotificationListeners() {
        let notifyCenter = CFNotificationCenterGetDarwinNotifyCenter()

        // Listen for capture started
        let startedName = "com.swiftspeak.contextCapture.started" as CFString
        CFNotificationCenterAddObserver(
            notifyCenter,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let manager = Unmanaged<ContextCaptureManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleCaptureStarted()
                }
            },
            startedName,
            nil,
            .deliverImmediately
        )

        // Listen for capture stopped
        let stoppedName = "com.swiftspeak.contextCapture.stopped" as CFString
        CFNotificationCenterAddObserver(
            notifyCenter,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let manager = Unmanaged<ContextCaptureManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleCaptureStopped()
                }
            },
            stoppedName,
            nil,
            .deliverImmediately
        )

        // Listen for OCR completion
        let ocrCompleteName = "com.swiftspeak.contextCapture.ocrComplete" as CFString
        CFNotificationCenterAddObserver(
            notifyCenter,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let manager = Unmanaged<ContextCaptureManager>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    manager.handleOCRComplete()
                }
            },
            ocrCompleteName,
            nil,
            .deliverImmediately
        )
    }

    private func handleOCRComplete() {
        appLog("OCR complete notification received", category: "ContextCapture")

        // Refresh state to get the latest context
        refreshState()

        // Resume continuation if waiting
        if let continuation = ocrCompletionContinuation {
            ocrCompletionContinuation = nil
            continuation.resume(returning: lastCapturedContext)
        }
    }

    private func handleCaptureStarted() {
        appLog("Context capture started (notification received)", category: "ContextCapture")
        refreshState()
        startMonitoring()
    }

    private func handleCaptureStopped() {
        appLog("Context capture stopped (notification received)", category: "ContextCapture")
        refreshState()
        stopMonitoring()
    }

    deinit {
        // Remove Darwin notification observers
        let notifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(notifyCenter, Unmanaged.passUnretained(self).toOpaque())
    }
}

// MARK: - Context Summary

extension ContextCaptureManager {

    /// Get a summarized version of the context (for prompts)
    public func getSummarizedContext(maxLength: Int = 1000) -> String? {
        guard let context = getLatestContext() else { return nil }

        // If context is short enough, return as-is
        if context.count <= maxLength {
            return context
        }

        // Truncate intelligently - keep beginning and end
        let halfLength = maxLength / 2
        let prefix = String(context.prefix(halfLength))
        let suffix = String(context.suffix(halfLength))

        return "\(prefix)\n...[truncated]...\n\(suffix)"
    }

    /// Get context formatted for use in transcription prompts
    public func getContextForPrompt() -> String? {
        guard let context = getSummarizedContext() else { return nil }

        return """
        [Screen Context - What the user is looking at:]
        \(context)
        [End of Screen Context]
        """
    }
}
