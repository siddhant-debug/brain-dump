import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    // Required group ID matching Android/iOS App Group
    let userDefaults = UserDefaults(suiteName: "group.com.siddhant.braindump")

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), lastNote: "Loading your thoughts...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let note = userDefaults?.string(forKey: "lastNote") ?? "Tap to capture a new thought"
        let entry = SimpleEntry(date: Date(), lastNote: note)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let note = userDefaults?.string(forKey: "lastNote") ?? "Tap to capture a new thought"
        let entry = SimpleEntry(date: Date(), lastNote: note)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let lastNote: String
}

struct BrainDumpWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Thought")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(entry.lastNote)
                .font(.body)
                .lineLimit(3)
            
            Spacer()
        }
        .padding()
        // URL Scheme to open deep link directly to capture sheet
        .widgetURL(URL(string: "braindump://capture?startInJournal=true&autoTriggerMic=true"))
    }
}

@main
struct BrainDumpWidget: Widget {
    let kind: String = "BrainDumpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BrainDumpWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BrainDump Capture")
        .description("Quickly capture thoughts and see your latest note.")
    }
}
