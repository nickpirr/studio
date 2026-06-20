//
//  StudioWatchComplication.swift
//  StudioWatchComplication
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import WidgetKit
import SwiftUI

struct StudioComplicationEntry: TimelineEntry {
    let date: Date
    let sessionActive: Bool
    let courseName: String
    let startDate: Date
    let weeklyMinutes: [Int]
}

struct StudioComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioComplicationEntry {
        StudioComplicationEntry(date: Date(), sessionActive: false, courseName: "", startDate: Date(), weeklyMinutes: [20, 40, 10, 60, 30, 0, 50])
    }
    func getSnapshot(in context: Context, completion: @escaping (StudioComplicationEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioComplicationEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextUpdate)))
    }
    private func currentEntry() -> StudioComplicationEntry {
        let defaults = WatchSync.defaults
        let active = defaults?.bool(forKey: WatchSync.keySessionActive) ?? false
        let name = defaults?.string(forKey: WatchSync.keyCourseName) ?? ""
        let startInterval = defaults?.double(forKey: WatchSync.keyStartDate) ?? 0
        let start = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()
        let weekly = defaults?.array(forKey: WatchSync.keyWeeklyMinutes) as? [Int] ?? Array(repeating: 0, count: 7)
        return StudioComplicationEntry(date: Date(), sessionActive: active, courseName: name, startDate: start, weeklyMinutes: weekly)
    }
}

struct StudioComplicationView: View {
    let entry: StudioComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            rectangularView
        }
    }

    private var rectangularView: some View {
        Group {
            if entry.sessionActive {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.courseName).font(.caption2.weight(.semibold)).lineLimit(1)
                    Text(entry.startDate, style: .timer).font(.title3.weight(.bold)).monospacedDigit()
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Questa settimana").font(.caption2.weight(.semibold))
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(entry.weeklyMinutes.enumerated()), id: \.offset) { _, minutes in
                            let maxVal = max(entry.weeklyMinutes.max() ?? 1, 1)
                            Capsule().fill(.blue).frame(width: 6, height: max(3, CGFloat(minutes) / CGFloat(maxVal) * 24))
                        }
                    }
                    .frame(height: 24, alignment: .bottom)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var circularView: some View {
        Group {
            if entry.sessionActive {
                VStack(spacing: 0) {
                    Image(systemName: "play.fill").font(.caption2)
                    Text(entry.startDate, style: .timer).font(.caption2).monospacedDigit().minimumScaleFactor(0.6)
                }
            } else {
                Image(systemName: "book.fill").font(.title3)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var cornerView: some View {
        Group {
            if entry.sessionActive {
                Text(entry.startDate, style: .timer)
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
            } else {
                Image(systemName: "book.fill")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var inlineView: some View {
        Group {
            if entry.sessionActive {
                Text("\(entry.courseName) · \(entry.startDate, style: .timer)")
            } else {
                Text("Studio: nessuna sessione")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioWatchComplication: Widget {
    let kind = "StudioWatchComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioComplicationProvider()) { entry in
            StudioComplicationView(entry: entry)
        }
        .configurationDisplayName("Studio")
        .description("Timer live o grafico settimanale di studio.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
