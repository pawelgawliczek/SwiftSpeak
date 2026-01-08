//
//  AudioInputDevice.swift
//  SwiftSpeakCore
//
//  Unified audio input device model for both iOS and macOS
//

import Foundation

/// Unified audio input device model for both platforms
public struct AudioInputDevice: Identifiable, Hashable, Codable, Sendable {
    /// Platform-specific identifier (AudioDeviceID string on macOS, UID on iOS)
    public let id: String

    /// Human-readable device name
    public let name: String

    /// Type of audio input device
    public let deviceType: DeviceType

    /// Whether this is the system default input device
    public let isDefault: Bool

    /// Whether the device is currently available/connected
    public let isAvailable: Bool

    public init(
        id: String,
        name: String,
        deviceType: DeviceType,
        isDefault: Bool,
        isAvailable: Bool
    ) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.isDefault = isDefault
        self.isAvailable = isAvailable
    }

    // MARK: - Device Types

    public enum DeviceType: String, Codable, Sendable, CaseIterable {
        case builtIn        // Built-in microphone (MacBook, iPhone)
        case airpods        // AirPods (any generation)
        case bluetooth      // Other Bluetooth devices (headsets, speakers)
        case continuity     // iPhone via Continuity Camera (macOS 13+ only)
        case usb            // USB microphones
        case virtual        // Virtual/aggregate audio devices
        case unknown        // Unknown device type

        /// SF Symbol icon name for this device type
        public var iconName: String {
            switch self {
            case .builtIn: return "laptopcomputer"
            case .airpods: return "airpodspro"
            case .bluetooth: return "headphones"
            case .continuity: return "iphone"
            case .usb: return "mic.fill"
            case .virtual: return "waveform"
            case .unknown: return "questionmark.circle"
            }
        }

        /// Display name for this device type
        public var displayName: String {
            switch self {
            case .builtIn: return "Built-in"
            case .airpods: return "AirPods"
            case .bluetooth: return "Bluetooth"
            case .continuity: return "iPhone"
            case .usb: return "USB"
            case .virtual: return "Virtual"
            case .unknown: return "Unknown"
            }
        }
    }

    // MARK: - System Default

    /// Placeholder representing "use system default device"
    public static let systemDefault = AudioInputDevice(
        id: "system_default",
        name: "System Default",
        deviceType: .builtIn,
        isDefault: true,
        isAvailable: true
    )

    /// Check if this represents the system default option
    public var isSystemDefault: Bool {
        id == "system_default"
    }
}

// MARK: - Device Detection Helpers

public extension AudioInputDevice {
    /// Create device with AirPods detection based on name
    static func detectType(
        id: String,
        name: String,
        transportType: TransportType,
        isDefault: Bool
    ) -> AudioInputDevice {
        let deviceType: DeviceType

        // Detect AirPods by name
        let lowercaseName = name.lowercased()
        if lowercaseName.contains("airpods") {
            deviceType = .airpods
        } else {
            // Map transport type to device type
            switch transportType {
            case .builtIn:
                deviceType = .builtIn
            case .bluetooth:
                deviceType = .bluetooth
            case .continuity:
                deviceType = .continuity
            case .usb:
                deviceType = .usb
            case .virtual:
                deviceType = .virtual
            case .unknown:
                deviceType = .unknown
            }
        }

        return AudioInputDevice(
            id: id,
            name: name,
            deviceType: deviceType,
            isDefault: isDefault,
            isAvailable: true
        )
    }

    /// Transport type (used during device detection)
    enum TransportType {
        case builtIn
        case bluetooth
        case continuity
        case usb
        case virtual
        case unknown
    }
}

// MARK: - Errors

public enum AudioDeviceError: LocalizedError {
    case deviceNotFound
    case deviceSelectionFailed(String)
    case permissionDenied
    case noInputDevices

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Audio input device not found"
        case .deviceSelectionFailed(let reason):
            return "Failed to select audio device: \(reason)"
        case .permissionDenied:
            return "Microphone permission denied"
        case .noInputDevices:
            return "No audio input devices available"
        }
    }
}
