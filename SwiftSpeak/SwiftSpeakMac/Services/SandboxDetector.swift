//
//  SandboxDetector.swift
//  SwiftSpeakMac
//
//  Detects if the app is running in sandbox mode
//  Used to enable/disable accessibility features based on distribution type
//

import Foundation
import ApplicationServices

/// Utility to detect if the app is running sandboxed
enum SandboxDetector {

    /// Returns true if the app is running in App Sandbox
    static var isSandboxed: Bool {
        // Method 1: Check for sandbox container path
        let homeDir = NSHomeDirectory()
        if homeDir.contains("/Library/Containers/") {
            return true
        }

        // Method 2: Check environment variable
        if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
            return true
        }

        // Method 3: Try to access a path outside sandbox (fallback)
        let testPath = "/private/var/root"
        let accessible = FileManager.default.isReadableFile(atPath: testPath)
        // If we can't read this restricted path AND we're not root, we might be sandboxed
        // But this is less reliable, so we primarily use methods 1 and 2

        return false
    }

    /// Returns true if accessibility features are available
    /// (Non-sandboxed with proper permissions)
    static var canUseAccessibility: Bool {
        guard !isSandboxed else {
            return false
        }
        return AXIsProcessTrusted()
    }

    /// Human-readable distribution type
    static var distributionType: String {
        isSandboxed ? "App Store" : "Direct Download"
    }
}
