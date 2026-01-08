//
//  SwiftSpeakWidgetBundle.swift
//  SwiftSpeakWidget
//
//  Widget extension entry point
//

import WidgetKit
import SwiftUI

@main
struct SwiftSpeakWidgetBundle: WidgetBundle {
    var body: some Widget {
        SwiftLinkWidget()
    }
}
