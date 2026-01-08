//
//  MacAudioDeviceManager.swift
//  SwiftSpeakMac
//
//  Manages audio input device enumeration and selection using Core Audio
//

import Foundation
import CoreAudio
import AudioToolbox
import SwiftSpeakCore
import Combine

/// Manages audio input devices on macOS using Core Audio APIs
@MainActor
public final class MacAudioDeviceManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var availableDevices: [AudioInputDevice] = []
    @Published public var selectedDevice: AudioInputDevice? {
        didSet {
            // Save selection when changed via picker binding
            if selectedDevice?.id != oldValue?.id {
                saveSelection()
            }
        }
    }

    // MARK: - Private Properties

    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private let defaults = UserDefaults.standard
    private static let selectedDeviceKey = "mac_selectedAudioInputDeviceID"

    // MARK: - Initialization

    public init() {
        refreshDevices()
        loadSavedSelection()
        setupDeviceChangeListener()
    }

    /// Load previously saved device selection
    private func loadSavedSelection() {
        guard let savedDeviceID = defaults.string(forKey: Self.selectedDeviceKey) else {
            // No saved selection - use default
            return
        }

        // Find device with saved ID
        if let device = availableDevices.first(where: { $0.id == savedDeviceID }) {
            selectedDevice = device
            macLog("Restored saved audio device: \(device.name)", category: "AudioDevice")
        } else {
            macLog("Saved device not found (ID: \(savedDeviceID)), using default", category: "AudioDevice")
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

    deinit {
        // Remove listeners synchronously without actor isolation
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        if let block = deviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &devicesAddress,
                DispatchQueue.main,
                block
            )
        }

        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        if let block = defaultDeviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                DispatchQueue.main,
                block
            )
        }
    }

    // MARK: - Public Methods

    /// Refresh the list of available input devices
    public func refreshDevices() {
        availableDevices = enumerateInputDevices()

        // If no device selected, use default
        if selectedDevice == nil {
            selectedDevice = availableDevices.first(where: { $0.isDefault })
                ?? availableDevices.first
        }

        // Validate current selection still exists
        if let selected = selectedDevice,
           !selected.isSystemDefault,
           !availableDevices.contains(where: { $0.id == selected.id }) {
            // Selected device disconnected, fall back to default
            macLog("Selected device disconnected, falling back to default", category: "AudioDevice")
            selectedDevice = availableDevices.first(where: { $0.isDefault })
                ?? availableDevices.first
        }
    }

    /// Select a specific audio input device
    /// - Parameter device: The device to select
    public func selectDevice(_ device: AudioInputDevice) {
        selectedDevice = device
        saveSelection()
        macLog("Selected audio device: \(device.name) (\(device.deviceType))", category: "AudioDevice")
    }

    /// Get the AudioDeviceID for the currently selected device
    /// - Returns: The device ID, or nil for system default
    public func getSelectedDeviceID() -> AudioDeviceID? {
        guard let selected = selectedDevice, !selected.isSystemDefault else {
            return nil // Use system default
        }
        return AudioDeviceID(selected.id) ?? getDefaultInputDeviceID()
    }

    // MARK: - Device Enumeration

    private func enumerateInputDevices() -> [AudioInputDevice] {
        var devices: [AudioInputDevice] = []

        // Add system default option
        devices.append(.systemDefault)

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            macLog("Failed to get audio devices size: \(status)", category: "AudioDevice", level: .error)
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            macLog("Failed to get audio devices: \(status)", category: "AudioDevice", level: .error)
            return devices
        }

        // Get default input device for comparison
        let defaultDeviceID = getDefaultInputDeviceID()

        // Filter for input devices only (exclude virtual/aggregate devices)
        for deviceID in deviceIDs {
            // Skip aggregate and virtual devices (like CADefaultDeviceAggregate)
            if isAggregateOrVirtualDevice(deviceID: deviceID) {
                continue
            }

            if hasInputChannels(deviceID: deviceID),
               let device = createAudioInputDevice(deviceID: deviceID, isDefault: deviceID == defaultDeviceID) {
                devices.append(device)
            }
        }

        macLog("Found \(devices.count - 1) input devices (plus system default)", category: "AudioDevice")
        return devices
    }

    /// Check if a device has input channels
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)

        guard status == noErr, dataSize > 0 else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        let getStatus = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer)

        guard getStatus == noErr else { return false }

        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0
    }

    /// Create an AudioInputDevice from a Core Audio device ID
    private func createAudioInputDevice(deviceID: AudioDeviceID, isDefault: Bool) -> AudioInputDevice? {
        // Get device name
        guard let name = getDeviceName(deviceID: deviceID) else { return nil }

        // Get transport type
        let transportType = getTransportType(deviceID: deviceID)

        // Create device with auto-detection of AirPods
        return AudioInputDevice.detectType(
            id: String(deviceID),
            name: name,
            transportType: transportType,
            isDefault: isDefault
        )
    }

    /// Get device name
    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString? = nil
        var dataSize = UInt32(MemoryLayout<CFString?>.size)

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)

        guard status == noErr, let deviceName = name as String? else { return nil }
        return deviceName
    }

    /// Check if device is aggregate or virtual (should be hidden from user)
    private func isAggregateOrVirtualDevice(deviceID: AudioDeviceID) -> Bool {
        // Check transport type
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &transportType)
        if status == noErr {
            if transportType == kAudioDeviceTransportTypeAggregate ||
               transportType == kAudioDeviceTransportTypeVirtual {
                return true
            }
        }

        // Also check device name for system aggregate devices
        if let name = getDeviceName(deviceID: deviceID) {
            let lowercaseName = name.lowercased()
            if lowercaseName.contains("aggregate") ||
               lowercaseName.contains("cadefaultdevice") ||
               lowercaseName.contains("multi-output") {
                return true
            }
        }

        return false
    }

    /// Get transport type (built-in, bluetooth, continuity, etc.)
    private func getTransportType(deviceID: AudioDeviceID) -> AudioInputDevice.TransportType {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &transportType)

        guard status == noErr else { return .unknown }

        // Map Core Audio transport types to our enum
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate:
            return .virtual
        default:
            // Check for Continuity Camera (macOS 13+)
            // kAudioDeviceTransportTypeContinuityCaptureWired = 'ccwd'
            // kAudioDeviceTransportTypeContinuityCapture = 'ccap'
            if #available(macOS 13.0, *) {
                if transportType == fourCharCode("ccwd") || transportType == fourCharCode("ccap") {
                    return .continuity
                }
            }
            return .unknown
        }
    }

    /// Get the default input device ID
    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        return status == noErr ? deviceID : 0
    }

    // MARK: - Device Change Listener

    private func setupDeviceChangeListener() {
        // Listen for device list changes
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        deviceListenerBlock = { [weak self] (_, _) in
            DispatchQueue.main.async {
                self?.refreshDevices()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            DispatchQueue.main,
            deviceListenerBlock!
        )

        // Listen for default device changes
        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        defaultDeviceListenerBlock = { [weak self] (_, _) in
            DispatchQueue.main.async {
                self?.refreshDevices()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            defaultDeviceListenerBlock!
        )

        macLog("Audio device change listeners installed", category: "AudioDevice")
    }

    private func removeDeviceChangeListener() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        if let block = deviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &devicesAddress,
                DispatchQueue.main,
                block
            )
        }

        var defaultDeviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        if let block = defaultDeviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                DispatchQueue.main,
                block
            )
        }
    }
}

// MARK: - Helpers

/// Convert four character code string to UInt32
private func fourCharCode(_ string: String) -> UInt32 {
    guard string.count == 4 else { return 0 }
    var result: UInt32 = 0
    for char in string.utf8 {
        result = (result << 8) | UInt32(char)
    }
    return result
}
