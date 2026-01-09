//
//  SwiftSpeakWidgetBundle.swift
//  SwiftSpeakWidget
//
//  Created by Pawel Gawliczek on 08/01/2026.
//

import WidgetKit
import SwiftUI

@main
struct SwiftSpeakWidgetBundle: WidgetBundle {
    var body: some Widget {
        // SwiftLink status widget (Lock Screen + Home Screen)
        SwiftLinkWidget()
        // Control Center widget (iOS 18+)
        SwiftSpeakWidgetControl()
        // Live Activity (for future use)
        SwiftSpeakWidgetLiveActivity()
    }
}
