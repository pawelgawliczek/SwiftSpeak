//
//  ShareViewController.swift
//  SwiftSpeakShare
//
//  Share Extension for receiving content and passing it to SwiftSpeak
//  for processing through Power Modes.
//
//  Supports: Audio, Text, Images, URLs, PDFs
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - Constants

    private let appGroupIdentifier = "group.pawelgawliczek.swiftspeak"
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
        .audio, .mpeg4Audio, .mp3, .wav, .aiff,
        UTType("com.apple.m4a-audio") ?? .audio,
        UTType("public.mpeg-4-audio") ?? .audio
    ]

    private let imageTypes: [UTType] = [
        .image, .jpeg, .png, .heic, .gif, .tiff, .bmp,
        UTType("public.heif") ?? .image
    ]

    private let pdfType = UTType.pdf
    private let textTypes: [UTType] = [.plainText, .utf8PlainText, .text]
    private let urlType = UTType.url

    // MARK: - Content Type Detection

    private enum SharedContentType: String {
        case audio
        case text
        case image
        case url
        case pdf
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        processSharedItems()
    }

    // MARK: - Processing

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeWithError("No items shared")
            return
        }

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }

            for attachment in attachments {
                // Check content types in priority order

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

                // 4. URLs (check before text since URLs can also be text)
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
        }

        completeWithError("No supported content found in shared items")
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

    private func saveTextToAppGroup(text: String) {
        let shareId = UUID().uuidString

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
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
            userDefaults?.set(shareId, forKey: pendingShareKey)
            userDefaults?.set(SharedContentType.text.rawValue, forKey: contentTypeKey)
            userDefaults?.set(text, forKey: textContentKey)
            userDefaults?.set(Date().timeIntervalSince1970, forKey: timestampKey)
            userDefaults?.synchronize()

            DispatchQueue.main.async {
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
        // Construct URL scheme with content type
        guard let url = URL(string: "swiftspeak://share?type=\(contentType.rawValue)&file=\(shareId)") else {
            completeWithError("Invalid URL scheme")
            return
        }

        // Open URL using responder chain
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] success in
                    if success {
                        self?.completeSuccessfully()
                    } else {
                        self?.completeWithError("Failed to open SwiftSpeak")
                    }
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: use openURL selector (for iOS 13+)
        let selector = sel_registerName("openURL:")
        responder = self
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                completeSuccessfully()
                return
            }
            responder = responder?.next
        }

        completeWithError("Cannot open main app")
    }

    // MARK: - Completion

    private func completeSuccessfully() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func completeWithError(_ message: String) {
        let error = NSError(
            domain: "com.swiftspeak.share",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        extensionContext?.cancelRequest(withError: error)
    }
}
