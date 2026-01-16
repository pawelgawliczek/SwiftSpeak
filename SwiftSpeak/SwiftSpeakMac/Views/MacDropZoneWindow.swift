//
//  MacDropZoneWindow.swift
//  SwiftSpeakMac
//
//  Floating drop zone window for drag-and-drop content into SwiftSpeak.
//  Appears near the menu bar when dragging supported content types.
//

import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers
import SwiftSpeakCore

// MARK: - Drop Zone Window Controller

@MainActor
final class MacDropZoneWindowController {

    private var window: NSWindow?
    private var dropView: MacDropZoneNSView?
    private var dragMonitor: Any?

    var onContentDropped: ((SharedContentType, URL?, String?) -> Void)?

    // MARK: - Window Management

    func showWindow() {
        if window == nil {
            createWindow()
        }

        window?.makeKeyAndOrderFront(nil)

        // Animate fade in
        window?.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 1
        }
    }

    func hideWindow() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    private func createWindow() {
        // Position near menu bar (top center of screen)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowWidth: CGFloat = 350
        let windowHeight: CGFloat = 200
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.maxY - windowHeight - 100  // Below menu bar area

        let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.isReleasedWhenClosed = false

        // Create drop view
        let dropView = MacDropZoneNSView(frame: NSRect(origin: .zero, size: frame.size))
        dropView.onDrop = { [weak self] contentType, fileURL, text in
            self?.hideWindow()
            self?.onContentDropped?(contentType, fileURL, text)
        }
        self.dropView = dropView

        window.contentView = dropView
        self.window = window
    }

    // MARK: - Global Drag Monitoring

    func startMonitoring() {
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            // This is a basic approach - monitoring drag start
            // In practice, you'd use NSDraggingDestination on a transparent window
        }
    }

    func stopMonitoring() {
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
        }
    }
}

// MARK: - Drop Zone NSView (for NSDraggingDestination)

final class MacDropZoneNSView: NSView {

    var onDrop: ((SharedContentType, URL?, String?) -> Void)?

    private var isHighlighted = false
    private let hostingView: NSHostingView<MacDropZoneView>
    private var viewModel: MacDropZoneViewModel

    // Supported types
    private let supportedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        .string,
        .tiff,
        .png
    ]

    override init(frame frameRect: NSRect) {
        self.viewModel = MacDropZoneViewModel()
        self.hostingView = NSHostingView(rootView: MacDropZoneView(viewModel: viewModel))
        super.init(frame: frameRect)

        addSubview(hostingView)
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]

        // Register for drag types
        registerForDraggedTypes(supportedTypes)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let contentType = detectContentType(from: sender.draggingPasteboard)
        if contentType != nil {
            Task { @MainActor in
                viewModel.isHighlighted = true
                viewModel.detectedType = contentType
            }
            return .copy
        }
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return detectContentType(from: sender.draggingPasteboard) != nil ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Task { @MainActor in
            viewModel.isHighlighted = false
            viewModel.detectedType = nil
        }
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return detectContentType(from: sender.draggingPasteboard) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard

        // Try to extract content based on type
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let fileURL = fileURLs.first {
            // File dropped
            let contentType = detectFileContentType(fileURL)
            onDrop?(contentType, fileURL, nil)
            return true
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first, !url.isFileURL {
            // Web URL dropped
            onDrop?(.url, nil, url.absoluteString)
            return true
        }

        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let text = strings.first {
            // Text dropped
            onDrop?(.text, nil, text)
            return true
        }

        return false
    }

    // MARK: - Content Type Detection

    private func detectContentType(from pasteboard: NSPasteboard) -> SharedContentType? {
        // Check for file URLs first
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let fileURL = fileURLs.first {
            return detectFileContentType(fileURL)
        }

        // Check for web URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first, !url.isFileURL {
            return .url
        }

        // Check for text
        if pasteboard.string(forType: .string) != nil {
            return .text
        }

        // Check for image data
        if pasteboard.data(forType: .tiff) != nil || pasteboard.data(forType: .png) != nil {
            return .image
        }

        return nil
    }

    private func detectFileContentType(_ url: URL) -> SharedContentType {
        guard let uttype = UTType(filenameExtension: url.pathExtension) else {
            return .text
        }

        if uttype.conforms(to: .pdf) {
            return .pdf
        }
        if uttype.conforms(to: .audio) {
            return .audio
        }
        if uttype.conforms(to: .image) {
            return .image
        }
        if uttype.conforms(to: .plainText) || uttype.conforms(to: .text) {
            return .text
        }

        return .text
    }
}

// MARK: - View Model

final class MacDropZoneViewModel: ObservableObject {
    @Published var isHighlighted = false
    @Published var detectedType: SharedContentType?
}

// MARK: - SwiftUI View

struct MacDropZoneView: View {
    @ObservedObject var viewModel: MacDropZoneViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(viewModel.isHighlighted ? iconColor : .secondary)
                .scaleEffect(viewModel.isHighlighted ? 1.1 : 1.0)
                .animation(.spring(duration: 0.2), value: viewModel.isHighlighted)

            // Text
            VStack(spacing: 4) {
                Text(viewModel.isHighlighted ? "Release to Import" : "Drop Content Here")
                    .font(.headline)

                if let type = viewModel.detectedType {
                    Text("Detected: \(type.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Audio, Text, Images, URLs, PDFs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            viewModel.isHighlighted ? iconColor : Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 3, dash: [8, 4])
                        )
                )
        )
        .padding(10)
    }

    private var iconName: String {
        guard let type = viewModel.detectedType else {
            return "arrow.down.circle"
        }
        return type.icon
    }

    private var iconColor: Color {
        guard let type = viewModel.detectedType else {
            return .blue
        }

        switch type {
        case .audio: return .purple
        case .text: return .blue
        case .image: return .green
        case .url: return .orange
        case .pdf: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    MacDropZoneView(viewModel: MacDropZoneViewModel())
        .frame(width: 350, height: 200)
}
