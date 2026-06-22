//
//  StudioWatchComplication.swift
//  StudioWatchComplication
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import WidgetKit
import SwiftUI

// MARK: - DATI CONDIVISI
struct StudioComplicationEntry: TimelineEntry {
    let date: Date
    let sessionActive: Bool
    let courseName: String
    let startDate: Date
    let isPaused: Bool
    let pausedSeconds: Int
    let weeklyMinutes: [Int]
}

struct StudioComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioComplicationEntry {
        StudioComplicationEntry(date: Date(), sessionActive: false, courseName: "", startDate: Date(), isPaused: false, pausedSeconds: 0, weeklyMinutes: [20, 40, 10, 60, 30, 0, 50])
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
        let isPaused = defaults?.bool(forKey: WatchSync.keyIsPaused) ?? false
        let pausedSeconds = defaults?.integer(forKey: WatchSync.keyPausedSeconds) ?? 0
        let weekly = defaults?.array(forKey: WatchSync.keyWeeklyMinutes) as? [Int] ?? Array(repeating: 0, count: 7)
        return StudioComplicationEntry(date: Date(), sessionActive: active, courseName: name, startDate: start, isPaused: isPaused, pausedSeconds: pausedSeconds, weeklyMinutes: weekly)
    }
}

// MARK: - COMPLICAZIONE 1: SOLO TIMER
struct StudioTimerView: View {
    let entry: StudioComplicationEntry
    @Environment(\.widgetFamily) var family

    private var pausedTimeText: String {
        let h = entry.pausedSeconds / 3600
        let m = (entry.pausedSeconds % 3600) / 60
        let s = entry.pausedSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner:   corner
        case .accessoryInline:   inline
        default:                 rectangular
        }
    }

    private var rectangular: some View {
        Group {
            if entry.sessionActive {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.courseName).font(.caption2.weight(.semibold)).lineLimit(1)
                    if entry.isPaused {
                        Text(pausedTimeText).font(.title3.weight(.bold)).monospacedDigit()
                    } else {
                        Text(entry.startDate, style: .timer).font(.title3.weight(.bold)).monospacedDigit()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: "play.circle").font(.title3)
                    Text("Nessuna sessione").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var circular: some View {
        Group {
            if entry.sessionActive {
                VStack(spacing: 0) {
                    Image(systemName: "play.fill").font(.caption2)
                    if entry.isPaused {
                        Text(pausedTimeText).font(.caption2).monospacedDigit().minimumScaleFactor(0.6)
                    } else {
                        Text(entry.startDate, style: .timer).font(.caption2).monospacedDigit().minimumScaleFactor(0.6)
                    }
                }
            } else {
                Image(systemName: "play.circle").font(.title3)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var corner: some View {
        Group {
            if entry.sessionActive {
                if entry.isPaused {
                    Text(pausedTimeText).font(.system(size: 14, weight: .bold)).monospacedDigit()
                } else {
                    Text(entry.startDate, style: .timer).font(.system(size: 14, weight: .bold)).monospacedDigit()
                }
            } else {
                Image(systemName: "play.circle")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Group {
            if entry.sessionActive {
                if entry.isPaused {
                    Text("\(entry.courseName) · \(pausedTimeText)")
                } else {
                    Text("\(entry.courseName) · \(entry.startDate, style: .timer)")
                }
            } else {
                Text("Studio: nessuna sessione")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioTimerWatchComplication: Widget {
    let kind = "StudioTimerWatchComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioComplicationProvider()) { entry in
            StudioTimerView(entry: entry)
        }
        .configurationDisplayName("Studio — Timer")
        .description("Timer live della sessione in corso.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - COMPLICAZIONE 2: SOLO GRAFICO SETTIMANALE
struct StudioChartView: View {
    let entry: StudioComplicationEntry
    @Environment(\.widgetFamily) var family

    private var totalWeekly: Int { entry.weeklyMinutes.reduce(0, +) }
    private var totalText: String {
        let h = totalWeekly / 60; let m = totalWeekly % 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner:   corner
        case .accessoryInline:   inline
        default:                 rectangular
        }
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(entry.weeklyMinutes.enumerated()), id: \.offset) { _, minutes in
                let maxVal = max(entry.weeklyMinutes.max() ?? 1, 1)
                Capsule().fill(.blue).frame(width: 6, height: max(3, CGFloat(minutes) / CGFloat(maxVal) * 24))
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Questa settimana").font(.caption2.weight(.semibold))
            bars
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var circular: some View {
        VStack(spacing: 1) {
            Image(systemName: "chart.bar.fill").font(.caption)
            Text(totalText).font(.caption2).monospacedDigit().minimumScaleFactor(0.6)
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var corner: some View {
        Image(systemName: "chart.bar.fill")
            .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Text("Settimana: \(totalText)")
            .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioChartWatchComplication: Widget {
    let kind = "StudioChartWatchComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioComplicationProvider()) { entry in
            StudioChartView(entry: entry)
        }
        .configurationDisplayName("Studio — Grafico")
        .description("Quanto hai studiato negli ultimi 7 giorni.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
