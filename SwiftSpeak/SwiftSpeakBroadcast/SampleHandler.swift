//
//  SampleHandler.swift
//  SwiftSpeakBroadcast
//
//  Placeholder broadcast upload extension
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // User has requested to start the broadcast
    }

    override func broadcastPaused() {
        // User has requested to pause the broadcast
    }

    override func broadcastResumed() {
        // User has requested to resume the broadcast
    }

    override func broadcastFinished() {
        // User has requested to finish the broadcast
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            break
        case .audioApp:
            break
        case .audioMic:
            break
        @unknown default:
            break
        }
    }
}
