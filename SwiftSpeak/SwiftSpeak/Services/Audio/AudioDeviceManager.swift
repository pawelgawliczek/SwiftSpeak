//
//  AudioDeviceManager.swift
//  SwiftSpeak
//
//  Manages audio input device enumeration and selection on iOS
//

import Foundation
import AVFoundation
import SwiftSpeakCore
import Combine

/// Manages audio input devices on iOS using AVAudioSession
@MainActor
public final class AudioDeviceManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var availableDevices: [AudioInputDevice] = []
    @Published public var selectedDevice: AudioInputDevice? {
        didSet {
            // Save and apply selection when changed via picker binding
            if selectedDevice?.id != oldValue?.id {
                saveSelection()
                applySelectedDevice()
            }
        }
    }

    // MARK: - Private Properties

    private var routeChangeObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private static let selectedDeviceKey = "ios_selectedAudioInputDeviceUID"

    // MARK: - Initialization

    public init() {
        refreshDevices()
        loadSavedSelection()
        setupRouteChangeObserver()
    }

    /// Load previously saved device selection
    private func loadSavedSelection() {
        guard let savedDeviceUID = defaults.string(forKey: Self.selectedDeviceKey) else {
            // No saved selection - use default
            return
        }

        // Find device with saved UID
        if let device = availableDevices.first(where: { $0.id == savedDeviceUID }) {
            selectedDevice = device  // This will also call applySelectedDevice via didSet
            appLog("Restored saved audio device: \(device.name)", category: "AudioDevice")
        } else {
            appLog("Saved device not found (UID: \(savedDeviceUID)), using default", category: "AudioDevice")
        }
    }

    /// Save the current device selection
    private func saveSelection() {
        if let device = selectedDevice {
            defaults.set(device.id, forKey: Self.selectedDeviceKey)
        } else {
            defaults.removeObject(forKey: Self.selectedDeviceKey)
        }
    }

    /// Apply the selected device to AVAudioSession
    private func applySelectedDevice() {
        guard let device = selectedDevice else { return }

        let session = AVAudioSession.sharedInstance()

        do {
            if device.isSystemDefault {
                // Clear preferred input to use system default
                try session.setPreferredInput(nil)
            } else {
                // Find the matching port
                guard let inputs = session.availableInputs,
                      let port = inputs.first(where: { $0.uid == device.id }) else {
                    appLog("Could not find matching port for device: \(device.name)", category: "AudioDevice", level: .warning)
                    return
                }
                try session.setPreferredInput(port)
            }
            appLog("Applied audio device: \(device.name)", category: "AudioDevice")
        } catch {
            appLog("Failed to set preferred input: \(error)", category: "AudioDevice", level: .error)
        }
    }

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Refresh the list of available input devices
    public func refreshDevices() {
        let session = AVAudioSession.sharedInstance()

        // Activate session to get available inputs
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            appLog("Failed to activate audio session: \(error)", category: "AudioDevice", level: .error)
        }

        guard let inputs = session.availableInputs else {
            appLog("No available audio inputs", category: "AudioDevice", level: .warning)
            availableDevices = [.systemDefault]
            return
        }

        var devices: [AudioInputDevice] = []

        // Add system default option
        devices.append(.systemDefault)

        // Map AVAudioSession ports to AudioInputDevice
        for port in inputs {
            let device = createAudioInputDevice(from: port)
            devices.append(device)
        }

        availableDevices = devices

        // If no device selected, use default or first available
        if selectedDevice == nil {
            selectedDevice = devices.first
        }

        // Validate current selection still exists
        if let selected = selectedDevice,
           !selected.isSystemDefault,
           !devices.contains(where: { $0.id == selected.id }) {
            appLog("Selected device disconnected, falling back to default", category: "AudioDevice")
            selectedDevice = devices.first
        }

        appLog("Found \(devices.count - 1) input devices (plus system default)", category: "AudioDevice")
    }

    /// Select a specific audio input device
    /// - Parameter device: The device to select
    public func selectDevice(_ device: AudioInputDevice) throws {
        let session = AVAudioSession.sharedInstance()

        if device.isSystemDefault {
            // Clear preferred input to use system default
            try session.setPreferredInput(nil)
        } else {
            // Find the matching port
            guard let inputs = session.availableInputs,
                  let port = inputs.first(where: { $0.uid == device.id }) else {
                throw AudioDeviceError.deviceNotFound
            }

            try session.setPreferredInput(port)
        }

        selectedDevice = device
        appLog("Selected audio device: \(device.name) (\(device.deviceType))", category: "AudioDevice")
    }

    /// Get the currently active input port UID
    public func getCurrentInputUID() -> String? {
        guard let selected = selectedDevice, !selected.isSystemDefault else {
            return nil
        }
        return selected.id
    }

    // MARK: - Device Mapping

    private func createAudioInputDevice(from port: AVAudioSessionPortDescription) -> AudioInputDevice {
        let deviceType = mapPortType(port.portType, name: port.portName)
        let currentInput = AVAudioSession.sharedInstance().currentRoute.inputs.first

        return AudioInputDevice(
            id: port.uid,
            name: port.portName,
            deviceType: deviceType,
            isDefault: currentInput?.uid == port.uid,
            isAvailable: true
        )
    }

    private func mapPortType(_ portType: AVAudioSession.Port, name: String) -> AudioInputDevice.DeviceType {
        // Check for AirPods by name
        let lowercaseName = name.lowercased()
        if lowercaseName.contains("airpods") {
            return .airpods
        }

        // Map port type
        switch portType {
        case .builtInMic:
            return .builtIn
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            return .bluetooth
        case .usbAudio:
            return .usb
        case .headsetMic, .headphones:
            return .bluetooth // Wired headsets
        default:
            return .unknown
        }
    }

    // MARK: - Route Change Observer

    private func setupRouteChangeObserver() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Get the reason for the route change
            if let userInfo = notification.userInfo,
               let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
                appLog("Audio route changed: \(reason)", category: "AudioDevice")
            }

            Task { @MainActor in
                self.refreshDevices()
            }
        }

        appLog("Audio route change observer installed", category: "AudioDevice")
    }
}

// MARK: - AVAudioSession.RouteChangeReason Description

extension AVAudioSession.RouteChangeReason: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "unknown"
        case .newDeviceAvailable: return "newDeviceAvailable"
        case .oldDeviceUnavailable: return "oldDeviceUnavailable"
        case .categoryChange: return "categoryChange"
        case .override: return "override"
        case .wakeFromSleep: return "wakeFromSleep"
        case .noSuitableRouteForCategory: return "noSuitableRouteForCategory"
        case .routeConfigurationChange: return "routeConfigurationChange"
        @unknown default: return "unknown(\(rawValue))"
        }
    }
}
