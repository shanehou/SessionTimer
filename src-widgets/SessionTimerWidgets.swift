// T054: SessionTimerWidgets - Widget Bundle Entry Point
// Session Timer - Widget Extension 入口

import WidgetKit
import SwiftUI

@main
struct SessionTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        SessionTimerLiveActivityWidget()
    }
}

/// Live Activity Widget 配置
struct SessionTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionTimerAttributes.self) { context in
            // Lock Screen / Banner UI
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Region
                DynamicIslandExpandedRegion(.leading) {
                    DynamicIslandExpandedLeadingView(context: context)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    DynamicIslandExpandedTrailingView(context: context)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    DynamicIslandExpandedBottomView(context: context)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    DynamicIslandExpandedCenterView(context: context)
                }
            } compactLeading: {
                DynamicIslandCompactLeadingView(context: context)
            } compactTrailing: {
                DynamicIslandCompactTrailingView(context: context)
            } minimal: {
                DynamicIslandMinimalView(context: context)
            }
        }
    }
}
