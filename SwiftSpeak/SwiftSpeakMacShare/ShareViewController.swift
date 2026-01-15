//
//  ShareViewController.swift
//  SwiftSpeakMacShare
//
//  macOS Share Extension for receiving content and passing it to SwiftSpeakMac
//  for processing through Power Modes.
//
//  Supports: Audio, Text, Images, URLs, PDFs
//

import Cocoa
import UniformTypeIdentifiers
import SwiftUI

class ShareViewController: NSViewController {

    // MARK: - Constants

    private let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"

    private func debugLog(_ message: String) {
        // Write to App Group container so main app can read it
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            NSLog("[SwiftSpeakShare] Cannot access container for logging")
            return
        }
        let logFile = containerURL.appendingPathComponent("share_extension_debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
    private let sharedContentDirectory = "shared_content"

    // UserDefaults keys for shared content
    private let pendingShareKey = "pendingShareContentId"
    private let contentTypeKey = "shareContentType"
    private let originalFilenameKey = "shareOriginalFilename"
    private let timestampKey = "shareTimestamp"
    private let sourceURLKey = "shareSourceURL"
    private let textContentKey = "shareTextContent"

    // Supported content type identifiers
    private let audioTypes: [UTType] = [
        .audio, .mpeg4Audio, .mp3, .wav, .aiff
    ]

    private let imageTypes: [UTType] = [
        .image, .jpeg, .png, .heic, .gif, .tiff, .bmp
    ]

    private let pdfType = UTType.pdf
    private let textTypes: [UTType] = [.plainText, .utf8PlainText, .text]
    private let urlType = UTType.url
    private let fileURLType = UTType.fileURL

    // MARK: - Content Type Detection

    private enum SharedContentType: String {
        case audio
        case text
        case image
        case url
        case pdf
    }

    // MARK: - Lifecycle

    override var nibName: NSNib.Name? {
        return nil
    }

    override func loadView() {
        // Create a hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: MacShareLoadingView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        self.view = hostingView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        debugLog("viewDidLoad called")
        NSLog("[SwiftSpeakShare] viewDidLoad called")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        debugLog("viewWillAppear called")
        NSLog("[SwiftSpeakShare] viewWillAppear called")

        // Process items on every appear (handles extension reuse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.processSharedItems()
        }
    }

    // MARK: - Processing

    private func processSharedItems() {
        debugLog("processSharedItems called")
        debugLog("inputItems count: \(self.extensionContext?.inputItems.count ?? 0)")
        NSLog("[SwiftSpeakShare] processSharedItems called")
        NSLog("[SwiftSpeakShare] inputItems count: \(self.extensionContext?.inputItems.count ?? 0)")

        guard let extensionItem = self.extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            debugLog("No extension items or attachments")
            NSLog("[SwiftSpeakShare] No extension items or attachments")
            completeWithError("No items shared")
            return
        }

        debugLog("Found \(attachments.count) attachments")
        NSLog("[SwiftSpeakShare] Found \(attachments.count) attachments")

        for (index, attachment) in attachments.enumerated() {
            debugLog("Attachment \(index): \(attachment.registeredTypeIdentifiers)")
            NSLog("[SwiftSpeakShare] Attachment \(index): \(attachment.registeredTypeIdentifiers)")

            // Check content types in priority order

            // 0. File URLs - check file extension to determine actual type
            debugLog("Checking if attachment conforms to fileURLType: \(fileURLType.identifier)")
            if attachment.hasItemConformingToTypeIdentifier(fileURLType.identifier) {
                debugLog("Matched fileURLType, loading...")
                NSLog("[SwiftSpeakShare] Matched fileURLType, loading...")
                loadFileURL(from: attachment)
                return
            } else {
                debugLog("Does NOT conform to fileURLType")
            }

            // 1. Audio files
            for audioType in audioTypes {
                if attachment.hasItemConformingToTypeIdentifier(audioType.identifier) {
                    loadAudioFile(from: attachment, typeIdentifier: audioType.identifier)
                    return
                }
            }

            // 2. PDF files
            if attachment.hasItemConformingToTypeIdentifier(pdfType.identifier) {
                loadPDFFile(from: attachment)
                return
            }

            // 3. Image files
            for imageType in imageTypes {
                if attachment.hasItemConformingToTypeIdentifier(imageType.identifier) {
                    loadImageFile(from: attachment, typeIdentifier: imageType.identifier)
                    return
                }
            }

            // 4. Web URLs (not file URLs)
            if attachment.hasItemConformingToTypeIdentifier(urlType.identifier) {
                loadURL(from: attachment)
                return
            }

            // 5. Plain text
            for textType in textTypes {
                if attachment.hasItemConformingToTypeIdentifier(textType.identifier) {
                    loadText(from: attachment, typeIdentifier: textType.identifier)
                    return
                }
            }
        }

        completeWithError("No supported content found in shared items")
    }

    // MARK: - File URL Loading (determines type from extension)

    private func loadFileURL(from attachment: NSItemProvider) {
        debugLog("loadFileURL called")
        NSLog("[SwiftSpeakShare] Loading file URL...")

        attachment.loadItem(forTypeIdentifier: fileURLType.identifier, options: nil) { [weak self] item, error in
            self?.debugLog("loadItem callback received, error: \(error?.localizedDescription ?? "none"), item: \(String(describing: item))")
            guard let self = self else {
                NSLog("[SwiftSpeakShare] self is nil!")
                return
            }

            if let error = error {
                self.debugLog("Error loading file: \(error.localizedDescription)")
                NSLog("[SwiftSpeakShare] Error loading file: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completeWithError("Failed to load file: \(error.localizedDescription)")
                }
                return
            }

            // Handle different item types - can be URL, Data, or String
            let url: URL
            if let directURL = item as? URL {
                url = directURL
            } else if let data = item as? Data, let urlString = String(data: data, encoding: .utf8), let parsedURL = URL(string: urlString) {
                self.debugLog("Converted Data to URL: \(urlString)")
                url = parsedURL
            } else if let urlString = item as? String, let parsedURL = URL(string: urlString) {
                self.debugLog("Converted String to URL: \(urlString)")
                url = parsedURL
            } else {
                self.debugLog("Item is not a URL, Data, or String: \(String(describing: item))")
                NSLog("[SwiftSpeakShare] Item is not a URL: \(String(describing: item))")
                DispatchQueue.main.async {
                    self.completeWithError("Could not get file URL")
                }
                return
            }

            self.debugLog("Got file URL: \(url.path)")
            NSLog("[SwiftSpeakShare] Got file URL: \(url.path)")

            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Determine content type from file extension
            let ext = url.pathExtension.lowercased()
            let contentType = self.contentTypeFromExtension(ext)
            NSLog("[SwiftSpeakShare] Detected content type: \(contentType.rawValue) for extension: \(ext)")

            switch contentType {
            case .audio:
                self.copyFileToAppGroup(sourceURL: url, contentType: .audio)
            case .pdf:
                self.copyFileToAppGroup(sourceURL: url, contentType: .pdf)
            case .image:
                self.copyFileToAppGroup(sourceURL: url, contentType: .image)
            case .text:
                // For text files, read content directly
                self.loadTextFile(from: url)
            case .url:
                // This shouldn't happen for file URLs
                DispatchQueue.main.async {
                    self.completeWithError("Unsupported file type")
                }
            }
        }
    }

    private func contentTypeFromExtension(_ ext: String) -> SharedContentType {
        // Audio extensions
        let audioExtensions = ["mp3", "m4a", "wav", "aiff", "aac", "flac", "ogg"]
        if audioExtensions.contains(ext) {
            return .audio
        }

        // PDF
        if ext == "pdf" {
            return .pdf
        }

        // Image extensions
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp"]
        if imageExtensions.contains(ext) {
            return .image
        }

        // Text extensions (including markdown, code files, etc.)
        let textExtensions = ["txt", "md", "markdown", "rtf", "json", "xml", "html", "htm",
                              "css", "js", "ts", "swift", "py", "rb", "java", "c", "cpp", "h",
                              "yml", "yaml", "toml", "ini", "conf", "sh", "bash", "zsh",
                              "log", "csv", "sql"]
        if textExtensions.contains(ext) {
            return .text
        }

        // Default to text for unknown extensions (most shareable files are text-based)
        return .text
    }

    private func loadTextFile(from url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            saveTextToAppGroup(text: text, originalFilename: url.lastPathComponent)
        } catch {
            DispatchQueue.main.async {
                self.completeWithError("Failed to read file: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Audio Loading

    private func loadAudioFile(from attachment: NSItemProvider, typeIdentifier: String) {
        attachment.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.completeWithError("Failed to load audio: \(error.localizedDescription)")
                }
                return
            }

            guard let sourceURL = url else {
                DispatchQueue.main.async {
                    self.completeWithError("No URL for audio file")
                }
                return
            }

            self.copyFileToAppGroup(sourceURL: sourceURL, contentType: .audio)
        }
    }

    // MARK: - PDF Loading

    private func loadPDFFile(from attachment: NSItemProvider) {
        attachment.loadFileRepresentation(forTypeIdentifier: pdfType.identifier) { [weak self] url, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.completeWithError("Failed to load PDF: \(error.localizedDescription)")
                }
                return
            }

            guard let sourceURL = url else {
                DispatchQueue.main.async {
                    self.completeWithError("No URL for PDF file")
                }
                return
            }

            self.copyFileToAppGroup(sourceURL: sourceURL, contentType: .pdf)
        }
    }

    // MARK: - Image Loading

    private func loadImageFile(from attachment: NSItemProvider, typeIdentifier: String) {
        attachment.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.completeWithError("Failed to load image: \(error.localizedDescription)")
                }
                return
            }

            guard let sourceURL = url else {
                DispatchQueue.main.async {
                    self.completeWithError("No URL for image file")
                }
                return
            }

            self.copyFileToAppGroup(sourceURL: sourceURL, contentType: .image)
        }
    }

    // MARK: - URL Loading

    private func loadURL(from attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: urlType.identifier, options: nil) { [weak self] item, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.completeWithError("Failed to load URL: \(error.localizedDescription)")
                }
                return
            }

            let urlString: String?
            if let url = item as? URL {
                urlString = url.absoluteString
            } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                urlString = str
            } else if let str = item as? String {
                urlString = str
            } else {
                urlString = nil
            }

            guard let finalURLString = urlString else {
                DispatchQueue.main.async {
                    self.completeWithError("Could not extract URL")
                }
                return
            }

            self.saveURLToAppGroup(urlString: finalURLString)
        }
    }

    // MARK: - Text Loading

    private func loadText(from attachment: NSItemProvider, typeIdentifier: String) {
        attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.completeWithError("Failed to load text: \(error.localizedDescription)")
                }
                return
            }

            let text: String?
            if let str = item as? String {
                text = str
            } else if let data = item as? Data {
                text = String(data: data, encoding: .utf8)
            } else {
                text = nil
            }

            guard let finalText = text, !finalText.isEmpty else {
                DispatchQueue.main.async {
                    self.completeWithError("No text content found")
                }
                return
            }

            self.saveTextToAppGroup(text: finalText)
        }
    }

    // MARK: - App Group Storage

    private func copyFileToAppGroup(sourceURL: URL, contentType: SharedContentType) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            DispatchQueue.main.async {
                self.completeWithError("Cannot access App Group container")
            }
            return
        }

        // Create shared content directory if needed
        let sharedDir = containerURL.appendingPathComponent(sharedContentDirectory)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        // Generate unique ID for this share
        let shareId = UUID().uuidString
        let fileExtension = sourceURL.pathExtension.isEmpty ? defaultExtension(for: contentType) : sourceURL.pathExtension
        let destinationURL = sharedDir.appendingPathComponent("\(shareId).\(fileExtension)")

        do {
            // Copy file to App Group
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            // Store metadata in UserDefaults
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
            userDefaults?.set(shareId, forKey: pendingShareKey)
            userDefaults?.set(contentType.rawValue, forKey: contentTypeKey)
            userDefaults?.set(sourceURL.lastPathComponent, forKey: originalFilenameKey)
            userDefaults?.set(Date().timeIntervalSince1970, forKey: timestampKey)
            userDefaults?.synchronize()

            // Open main app
            DispatchQueue.main.async {
                self.openMainApp(shareId: shareId, contentType: contentType)
            }
        } catch {
            DispatchQueue.main.async {
                self.completeWithError("Failed to copy file: \(error.localizedDescription)")
            }
        }
    }

    private func saveURLToAppGroup(urlString: String) {
        let shareId = UUID().uuidString

        // Store in UserDefaults
        let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        userDefaults?.set(shareId, forKey: pendingShareKey)
        userDefaults?.set(SharedContentType.url.rawValue, forKey: contentTypeKey)
        userDefaults?.set(urlString, forKey: sourceURLKey)
        userDefaults?.set(Date().timeIntervalSince1970, forKey: timestampKey)
        userDefaults?.synchronize()

        // Open main app
        DispatchQueue.main.async {
            self.openMainApp(shareId: shareId, contentType: .url)
        }
    }

    private func saveTextToAppGroup(text: String, originalFilename: String? = nil) {
        debugLog("saveTextToAppGroup called with text length: \(text.count), filename: \(originalFilename ?? "nil")")
        NSLog("[SwiftSpeakShare] saveTextToAppGroup called with text length: \(text.count), filename: \(originalFilename ?? "nil")")
        let shareId = UUID().uuidString
        debugLog("Generated shareId: \(shareId)")
        NSLog("[SwiftSpeakShare] Generated shareId: \(shareId)")

        // For large text, save to file; for small text, use UserDefaults
        if text.count > 10000 {
            // Save to file
            guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
                DispatchQueue.main.async {
                    self.completeWithError("Cannot access App Group container")
                }
                return
            }

            let sharedDir = containerURL.appendingPathComponent(sharedContentDirectory)
            try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

            let destinationURL = sharedDir.appendingPathComponent("\(shareId).txt")

            do {
                try text.write(to: destinationURL, atomically: true, encoding: .utf8)

                let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
                userDefaults?.set(shareId, forKey: pendingShareKey)
                userDefaults?.set(SharedContentType.text.rawValue, forKey: contentTypeKey)
                userDefaults?.set(Date().timeIntervalSince1970, forKey: timestampKey)
                if let filename = originalFilename {
                    userDefaults?.set(filename, forKey: originalFilenameKey)
                }
                userDefaults?.synchronize()

                DispatchQueue.main.async {
                    self.openMainApp(shareId: shareId, contentType: .text)
                }
            } catch {
                DispatchQueue.main.async {
                    self.completeWithError("Failed to save text: \(error.localizedDescription)")
                }
            }
        } else {
            // Store directly in UserDefaults
            debugLog("Storing text in UserDefaults (small text path)")
            NSLog("[SwiftSpeakShare] Storing text in UserDefaults (small text path)")
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
            debugLog("UserDefaults suite: \(appGroupIdentifier), userDefaults: \(userDefaults != nil ? "OK" : "NIL")")
            NSLog("[SwiftSpeakShare] UserDefaults suite: \(appGroupIdentifier), userDefaults: \(userDefaults != nil ? "OK" : "NIL")")
            userDefaults?.set(shareId, forKey: pendingShareKey)
            userDefaults?.set(SharedContentType.text.rawValue, forKey: contentTypeKey)
            userDefaults?.set(text, forKey: textContentKey)
            userDefaults?.set(Date().timeIntervalSince1970, forKey: timestampKey)
            if let filename = originalFilename {
                userDefaults?.set(filename, forKey: originalFilenameKey)
            }
            let syncResult = userDefaults?.synchronize() ?? false
            debugLog("UserDefaults synchronized: \(syncResult)")
            NSLog("[SwiftSpeakShare] UserDefaults synchronized: \(syncResult)")

            DispatchQueue.main.async {
                self.debugLog("Calling openMainApp with shareId: \(shareId)")
                NSLog("[SwiftSpeakShare] Calling openMainApp")
                self.openMainApp(shareId: shareId, contentType: .text)
            }
        }
    }

    private func defaultExtension(for contentType: SharedContentType) -> String {
        switch contentType {
        case .audio: return "m4a"
        case .pdf: return "pdf"
        case .image: return "jpg"
        case .text: return "txt"
        case .url: return ""
        }
    }

    // MARK: - Open Main App

    private func openMainApp(shareId: String, contentType: SharedContentType) {
        NSLog("[SwiftSpeakShare] openMainApp called with shareId: \(shareId), type: \(contentType.rawValue)")

        // Construct URL scheme with content type
        guard let url = URL(string: "swiftspeak-mac://share?type=\(contentType.rawValue)&file=\(shareId)") else {
            NSLog("[SwiftSpeakShare] Failed to construct URL")
            completeWithError("Invalid URL scheme")
            return
        }

        NSLog("[SwiftSpeakShare] Opening URL: \(url.absoluteString)")

        // Open URL via NSWorkspace (synchronous API)
        let success = NSWorkspace.shared.open(url)
        NSLog("[SwiftSpeakShare] NSWorkspace.open result: \(success)")

        if success {
            completeSuccessfully()
        } else {
            completeWithError("Failed to open SwiftSpeak")
        }
    }

    // MARK: - Completion

    private func completeSuccessfully() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func completeWithError(_ message: String) {
        let error = NSError(
            domain: "com.swiftspeak.macshare",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        extensionContext?.cancelRequest(withError: error)
    }
}

// MARK: - Loading View

struct MacShareLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Processing...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 400, height: 300)
    }
}
