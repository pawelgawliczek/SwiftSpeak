//
//  SwiftSpeakWidgetLiveActivity.swift
//  SwiftSpeakWidget
//
//  Created by Pawel Gawliczek on 08/01/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SwiftSpeakWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SwiftSpeakWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SwiftSpeakWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SwiftSpeakWidgetAttributes {
    fileprivate static var preview: SwiftSpeakWidgetAttributes {
        SwiftSpeakWidgetAttributes(name: "World")
    }
}

extension SwiftSpeakWidgetAttributes.ContentState {
    fileprivate static var smiley: SwiftSpeakWidgetAttributes.ContentState {
        SwiftSpeakWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SwiftSpeakWidgetAttributes.ContentState {
         SwiftSpeakWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SwiftSpeakWidgetAttributes.preview) {
   SwiftSpeakWidgetLiveActivity()
} contentStates: {
    SwiftSpeakWidgetAttributes.ContentState.smiley
    SwiftSpeakWidgetAttributes.ContentState.starEyes
}
