//
//  StudioWeeklyWidget.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/06/2026.
//

import WidgetKit
import SwiftUI
import Charts

struct StudioWeeklyEntry: TimelineEntry {
    let date: Date
    let weeklyMinutes: [Int]
}

struct StudioWeeklyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioWeeklyEntry {
        StudioWeeklyEntry(date: Date(), weeklyMinutes: [30, 45, 0, 60, 20, 90, 15])
    }
    func getSnapshot(in context: Context, completion: @escaping (StudioWeeklyEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioWeeklyEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }
    private func currentEntry() -> StudioWeeklyEntry {
        let defaults = UserDefaults(suiteName: "group.com.niccolo.studio")
        let weekly = defaults?.array(forKey: "weeklyMinutesByDay") as? [Int] ?? Array(repeating: 0, count: 7)
        return StudioWeeklyEntry(date: Date(), weeklyMinutes: weekly)
    }
}

struct StudioWeeklyWidgetView: View {
    let entry: StudioWeeklyEntry
    private let dayLabels = ["L", "M", "M", "G", "V", "S", "D"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Questa settimana")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(Array(entry.weeklyMinutes.enumerated()), id: \.offset) { index, minutes in
                    BarMark(x: .value("Giorno", dayLabels[index]), y: .value("Min", minutes))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                }
            }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) } }
            .chartYAxis(.hidden)
        }
        .padding()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioWeeklyWidget: Widget {
    let kind = "StudioWeeklyWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioWeeklyProvider()) { entry in
            StudioWeeklyWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio — Settimana")
        .description("Quanto hai studiato negli ultimi 7 giorni.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
