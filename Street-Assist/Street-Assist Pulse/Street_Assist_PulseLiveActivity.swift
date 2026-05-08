//
//  Street_Assist_PulseLiveActivity.swift
//  Street-Assist Pulse
//
//  Created by COBSCCOMP242P-050 on 2026-05-07.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Street_Assist_PulseAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Street_Assist_PulseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Street_Assist_PulseAttributes.self) { context in
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

extension Street_Assist_PulseAttributes {
    fileprivate static var preview: Street_Assist_PulseAttributes {
        Street_Assist_PulseAttributes(name: "World")
    }
}

extension Street_Assist_PulseAttributes.ContentState {
    fileprivate static var smiley: Street_Assist_PulseAttributes.ContentState {
        Street_Assist_PulseAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Street_Assist_PulseAttributes.ContentState {
         Street_Assist_PulseAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Street_Assist_PulseAttributes.preview) {
   Street_Assist_PulseLiveActivity()
} contentStates: {
    Street_Assist_PulseAttributes.ContentState.smiley
    Street_Assist_PulseAttributes.ContentState.starEyes
}
