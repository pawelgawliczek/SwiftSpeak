//
//  NetworkQualityMonitor.swift
//  SwiftSpeakCore
//
//  Monitors network quality for automatic audio quality adjustment
//

import Foundation
import Network

/// Monitors network quality for automatic audio quality adjustment
/// Thread-safe singleton that starts monitoring on first access
public final class NetworkQualityMonitor: @unchecked Sendable {
    public static let shared = NetworkQualityMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.swiftspeak.networkmonitor")
    private let lock = NSLock()

    private var _isConstrained: Bool = false
    private var _isExpensive: Bool = false

    /// Whether the network path is constrained (e.g., Low Data Mode)
    public var isConstrained: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConstrained
    }

    /// Whether the network path is expensive (e.g., cellular)
    public var isExpensive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isExpensive
    }

    public enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.lock.lock()
            self._isConstrained = path.isConstrained
            self._isExpensive = path.isExpensive
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    /// Get recommended quality based on current network conditions
    public var recommendedQuality: AudioQualityMode {
        if isConstrained {
            return .lowBandwidth
        } else if isExpensive {
            return .standard
        } else {
            return .high
        }
    }

    /// Human-readable network status
    public var networkStatusDescription: String {
        if isConstrained {
            return "Low Data Mode active"
        } else if isExpensive {
            return "Cellular/metered connection"
        } else {
            return "Wi-Fi or unlimited connection"
        }
    }
}
