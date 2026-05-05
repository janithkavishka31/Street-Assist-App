//
//  street_assistLiveActivity.swift
//  street assist
//
//  Created by COBSCCOMP242P-050 on 2026-05-05.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct street_assistAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct street_assistLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: street_assistAttributes.self) { context in
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

extension street_assistAttributes {
    fileprivate static var preview: street_assistAttributes {
        street_assistAttributes(name: "World")
    }
}

extension street_assistAttributes.ContentState {
    fileprivate static var smiley: street_assistAttributes.ContentState {
        street_assistAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: street_assistAttributes.ContentState {
         street_assistAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: street_assistAttributes.preview) {
   street_assistLiveActivity()
} contentStates: {
    street_assistAttributes.ContentState.smiley
    street_assistAttributes.ContentState.starEyes
}
