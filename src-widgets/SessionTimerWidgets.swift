// Placeholder for SessionTimerWidgets - will be implemented in Phase 7 (User Story 5)
import WidgetKit
import SwiftUI

@main
struct SessionTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        SessionTimerLiveActivity()
    }
}

struct SessionTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SessionTimerWidget", provider: Provider()) { _ in
            Text("Session Timer Widget")
        }
        .configurationDisplayName("Session Timer")
        .description("Track your practice sessions")
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}
