//
//  DarwinNotificationManager.swift
//  SwiftSpeakKeyboard
//
//  Darwin notifications for cross-process IPC between app and keyboard extension.
//  Based on: https://nonstrict.eu/blog/2023/darwin-notifications-app-extensions/
//
//  SHARED: This file is a copy of the main app's DarwinNotificationManager
//

import Foundation

/// Manager for Darwin notifications - enables IPC between app and keyboard extension.
/// Darwin notifications are system-wide and can be observed across processes.
///
/// IMPORTANT: Darwin notifications cannot carry data (no userInfo dictionary).
/// Use as signals only - store actual data in App Groups (UserDefaults).
final class DarwinNotificationManager {

    // MARK: - Singleton

    static let shared = DarwinNotificationManager()

    // MARK: - Properties

    private var callbacks: [String: () -> Void] = [:]
    private let lock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Posting Notifications

    /// Post a Darwin notification that can be observed by other processes.
    /// - Parameter name: The notification name (use Constants.SwiftLinkNotifications)
    func post(name: String) {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            notificationCenter,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true  // deliverImmediately
        )
    }

    // MARK: - Observing Notifications

    /// Start observing a Darwin notification.
    /// - Parameters:
    ///   - name: The notification name to observe
    ///   - callback: Called when notification is received (always on main thread)
    func startObserving(name: String, callback: @escaping () -> Void) {
        lock.lock()
        callbacks[name] = callback
        lock.unlock()

        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

        CFNotificationCenterAddObserver(
            notificationCenter,
            Unmanaged.passUnretained(self).toOpaque(),
            Self.notificationCallback,
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Stop observing a Darwin notification.
    /// - Parameter name: The notification name to stop observing
    func stopObserving(name: String) {
        let notificationCenter = CFNotificationCenterGetDarwinNotifyCenter()

        CFNotificationCenterRemoveObserver(
            notificationCenter,
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(name as CFString),
            nil
        )

        lock.lock()
        callbacks.removeValue(forKey: name)
        lock.unlock()
    }

    /// Stop observing all Darwin notifications.
    func stopObservingAll() {
        lock.lock()
        let names = Array(callbacks.keys)
        lock.unlock()

        for name in names {
            stopObserving(name: name)
        }
    }

    // MARK: - Callback Handler

    /// C-style callback function required by CFNotificationCenter.
    /// Called when any observed notification is received.
    private static let notificationCallback: CFNotificationCallback = { _, observer, name, _, _ in
        guard let observer = observer,
              let name = name?.rawValue as String?
        else { return }

        let manager = Unmanaged<DarwinNotificationManager>
            .fromOpaque(observer)
            .takeUnretainedValue()

        manager.lock.lock()
        let callback = manager.callbacks[name]
        manager.lock.unlock()

        // Darwin notifications are delivered on the main thread
        if let callback = callback {
            if Thread.isMainThread {
                callback()
            } else {
                DispatchQueue.main.async {
                    callback()
                }
            }
        }
    }
}

// MARK: - SwiftLink Convenience Methods (Keyboard Extension)

extension DarwinNotificationManager {

    /// Post that dictation has started (from keyboard)
    func postDictationStart() {
        post(name: Constants.SwiftLinkNotifications.startDictation)
    }

    /// Post that dictation has stopped (from keyboard)
    func postDictationStop() {
        post(name: Constants.SwiftLinkNotifications.stopDictation)
    }

    /// Observe result ready (in keyboard)
    func observeResultReady(callback: @escaping () -> Void) {
        startObserving(name: Constants.SwiftLinkNotifications.resultReady, callback: callback)
    }

    /// Observe session started (in keyboard)
    func observeSessionStarted(callback: @escaping () -> Void) {
        startObserving(name: Constants.SwiftLinkNotifications.sessionStarted, callback: callback)
    }

    /// Observe session ended (in keyboard)
    func observeSessionEnded(callback: @escaping () -> Void) {
        startObserving(name: Constants.SwiftLinkNotifications.sessionEnded, callback: callback)
    }

    /// Post streaming transcript update (from main app during streaming)
    func postStreamingUpdate() {
        post(name: Constants.SwiftLinkNotifications.streamingUpdate)
    }

    /// Observe streaming updates (in keyboard)
    func observeStreamingUpdate(callback: @escaping () -> Void) {
        startObserving(name: Constants.SwiftLinkNotifications.streamingUpdate, callback: callback)
    }

    /// Stop observing streaming updates (in keyboard)
    func stopObservingStreamingUpdate() {
        stopObserving(name: Constants.SwiftLinkNotifications.streamingUpdate)
    }
}
