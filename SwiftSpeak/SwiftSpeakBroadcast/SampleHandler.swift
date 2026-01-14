//
//  SampleHandler.swift
//  SwiftSpeakBroadcast
//
//  Broadcast Upload Extension for capturing screen context.
//  Performs OCR on-demand when requested by the main app (via Darwin notification).
//  Stores extracted text in App Group for use during AI processing.
//

import ReplayKit
import Vision
import CoreMedia
import os.log

class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Properties

    private let appGroupDefaults = UserDefaults(suiteName: "group.pawelgawliczek.swiftspeak")
    private var latestPixelBuffer: CVPixelBuffer?
    private var frameCount: Int = 0
    private var ocrRequestPending: Bool = false

    private let logger = Logger(subsystem: "pawelgawliczek.SwiftSpeak.SwiftSpeakBroadcast", category: "ScreenCapture")

    // Keys for App Group storage
    private enum Keys {
        static let latestScreenContext = "contextCapture_latestText"
        static let latestContextTime = "contextCapture_timestamp"
        static let isCapturing = "contextCapture_isActive"
        static let framesCaptured = "contextCapture_frameCount"
        static let ocrRequested = "contextCapture_ocrRequested"
    }

    // MARK: - Lifecycle

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        logger.info("Broadcast started")

        // Mark as capturing
        appGroupDefaults?.set(true, forKey: Keys.isCapturing)
        appGroupDefaults?.set(0, forKey: Keys.framesCaptured)
        appGroupDefaults?.set(false, forKey: Keys.ocrRequested)
        appGroupDefaults?.synchronize()

        // Listen for OCR request notifications from main app
        setupOCRRequestListener()

        // Post Darwin notification
        postNotification(name: "com.swiftspeak.contextCapture.started")
    }

    override func broadcastPaused() {
        logger.info("Broadcast paused")
    }

    override func broadcastResumed() {
        logger.info("Broadcast resumed")
    }

    override func broadcastFinished() {
        logger.info("Broadcast finished - \(self.frameCount) frames captured")

        // Mark as not capturing
        appGroupDefaults?.set(false, forKey: Keys.isCapturing)
        appGroupDefaults?.synchronize()

        // Post Darwin notification
        postNotification(name: "com.swiftspeak.contextCapture.stopped")
    }

    // MARK: - Sample Processing

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            processVideoSample(sampleBuffer)
        case .audioApp:
            break
        case .audioMic:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Video Processing

    private func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
        // Store the latest pixel buffer for on-demand OCR
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Store the pixel buffer (ARC handles memory management)
        latestPixelBuffer = pixelBuffer

        frameCount += 1

        // Update frame count every 30 frames (roughly every second at 30fps)
        if frameCount % 30 == 0 {
            appGroupDefaults?.set(frameCount, forKey: Keys.framesCaptured)
        }

        // Check if OCR was requested via UserDefaults (polling fallback)
        if let requested = appGroupDefaults?.bool(forKey: Keys.ocrRequested), requested {
            appGroupDefaults?.set(false, forKey: Keys.ocrRequested)
            performOCROnCurrentFrame()
        }
    }

    // MARK: - OCR Request Listener

    private func setupOCRRequestListener() {
        let notifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
        let name = "com.swiftspeak.contextCapture.requestOCR" as CFString

        CFNotificationCenterAddObserver(
            notifyCenter,
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
                handler.handleOCRRequest()
            },
            name,
            nil,
            .deliverImmediately
        )

        logger.info("OCR request listener set up")
    }

    private func handleOCRRequest() {
        logger.info("OCR request received")
        performOCROnCurrentFrame()
    }

    // MARK: - OCR

    /// Extract text with position-based message attribution for messenger apps
    /// Uses bounding box position to determine if text is from user (right) or others (left)
    private func extractTextWithAttribution(from observations: [VNRecognizedTextObservation]) -> String {
        // Sort observations by vertical position (top to bottom)
        // Note: Vision coordinates have origin at bottom-left, so higher Y = higher on screen
        let sortedObservations = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        // Threshold for determining left vs right (messenger bubble position)
        // Messages on right side (x > 0.55) are typically user's messages
        // Messages on left side (x < 0.45) are typically other's messages
        // Middle area (0.45-0.55) is ambiguous (could be system messages, timestamps, etc.)
        let rightThreshold: CGFloat = 0.55
        let leftThreshold: CGFloat = 0.45

        var formattedLines: [String] = []
        var lastAttribution: String? = nil

        for observation in sortedObservations {
            guard let text = observation.topCandidates(1).first?.string,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let midX = observation.boundingBox.midX

            // Determine attribution based on horizontal position
            let attribution: String?
            if midX > rightThreshold {
                attribution = "[YOU]"
            } else if midX < leftThreshold {
                attribution = "[OTHER]"
            } else {
                // Center content - likely UI elements, timestamps, or system messages
                attribution = nil
            }

            // Only add attribution prefix when it changes (avoids repetition)
            if let attr = attribution {
                if attr != lastAttribution {
                    formattedLines.append("\(attr): \(text)")
                    lastAttribution = attr
                } else {
                    // Same speaker continues - just add the text
                    formattedLines.append(text)
                }
            } else {
                // No attribution (center content) - add as-is
                formattedLines.append(text)
                lastAttribution = nil
            }
        }

        return formattedLines.joined(separator: "\n")
    }

    private func performOCROnCurrentFrame() {
        guard let pixelBuffer = latestPixelBuffer else {
            logger.warning("No pixel buffer available for OCR")
            // Still notify that OCR completed (with no result)
            postNotification(name: "com.swiftspeak.contextCapture.ocrComplete")
            return
        }

        logger.info("Performing OCR on current frame")

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("OCR error: \(error.localizedDescription)")
                self.postNotification(name: "com.swiftspeak.contextCapture.ocrComplete")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                self.postNotification(name: "com.swiftspeak.contextCapture.ocrComplete")
                return
            }

            // Extract text with position-based message attribution
            // In messenger apps: right side = user's messages, left side = other's messages
            let extractedText = self.extractTextWithAttribution(from: observations)

            // Save context (even if empty)
            self.saveContext(extractedText)

            // Notify that OCR is complete
            self.postNotification(name: "com.swiftspeak.contextCapture.ocrComplete")
        }

        // Use accurate recognition for on-demand OCR (better quality)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Perform the request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            logger.error("Failed to perform OCR: \(error.localizedDescription)")
            postNotification(name: "com.swiftspeak.contextCapture.ocrComplete")
        }
    }

    // MARK: - Context Storage

    private func saveContext(_ text: String) {
        appGroupDefaults?.set(text, forKey: Keys.latestScreenContext)
        appGroupDefaults?.set(Date(), forKey: Keys.latestContextTime)
        appGroupDefaults?.synchronize()

        let preview = text.isEmpty ? "(empty)" : String(text.prefix(100)) + "..."
        logger.info("Saved context: \(preview)")
    }

    // MARK: - Darwin Notifications

    private func postNotification(name: String) {
        let notifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            notifyCenter,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    deinit {
        // Remove notification observer
        let notifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(notifyCenter, Unmanaged.passUnretained(self).toOpaque())
    }
}
