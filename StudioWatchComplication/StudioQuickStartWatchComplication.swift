//
//  StudioQuickStartWatchComplication.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/06/2026.
//

import WidgetKit
import SwiftUI
import AppIntents

struct StudioQuickStartWatchEntry: TimelineEntry {
    let date: Date
    let topCourseName: String
    let topCourseIcon: String
}

struct StudioQuickStartWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioQuickStartWatchEntry {
        StudioQuickStartWatchEntry(date: Date(), topCourseName: "Matematica", topCourseIcon: "function")
    }
    func getSnapshot(in context: Context, completion: @escaping (StudioQuickStartWatchEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioQuickStartWatchEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }
    private func currentEntry() -> StudioQuickStartWatchEntry {
        let defaults = WatchSync.defaults
        if let data = defaults?.data(forKey: WatchSync.keyCourses),
           let courses = try? JSONDecoder().decode([WatchCourseLite].self, from: data),
           let first = courses.first {
            return StudioQuickStartWatchEntry(date: Date(), topCourseName: first.name, topCourseIcon: first.icon)
        }
        return StudioQuickStartWatchEntry(date: Date(), topCourseName: "Studio", topCourseIcon: "book.fill")
    }
}

struct StudioQuickStartWatchView: View {
    let entry: StudioQuickStartWatchEntry

    var body: some View {
        Button(intent: makeIntent()) {
            HStack(spacing: 4) {
                Image(systemName: entry.topCourseIcon)
                Text(entry.topCourseName).font(.caption2).lineLimit(1)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private func makeIntent() -> WatchStartStudySessionIntent {
        let intent = WatchStartStudySessionIntent()
        intent.courseName = entry.topCourseName
        return intent
    }
}

struct StudioQuickStartWatchComplication: Widget {
    let kind = "StudioQuickStartWatchComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioQuickStartWatchProvider()) { entry in
            StudioQuickStartWatchView(entry: entry)
        }
        .configurationDisplayName("Studio — Avvio rapido")
        .description("Avvia la materia più studiata con un tocco.")
        .supportedFamilies([.accessoryRectangular])
    }
}
