//
//  StudioStatusWidget.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/06/2026.
//
import WidgetKit
import SwiftUI
import AppIntents

struct StudioStatusEntry: TimelineEntry {
    let date: Date
    let sessionActive: Bool
    let courseName: String
    let courseIcon: String
    let startDate: Date
}

struct StudioStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioStatusEntry {
        StudioStatusEntry(date: Date(), sessionActive: true, courseName: "Matematica", courseIcon: "function", startDate: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (StudioStatusEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioStatusEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }
    private func currentEntry() -> StudioStatusEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        let active = defaults?.bool(forKey: "sharedSessionActive") ?? false
        let name = defaults?.string(forKey: "sharedCourseName") ?? ""
        let startInterval = defaults?.double(forKey: "sharedStartDate") ?? 0
        let start = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()

        var icon = "book.fill"
        if let data = defaults?.data(forKey: "widgetCourses"),
           let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data),
           let match = courses.first(where: { $0.name == name }) {
            icon = match.icon
        }
        return StudioStatusEntry(date: Date(), sessionActive: active, courseName: name, courseIcon: icon, startDate: start)
    }
}

struct StudioStatusWidgetView: View {
    let entry: StudioStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.sessionActive {
                HStack(spacing: 6) {
                    Image(systemName: entry.courseIcon)
                    Text(entry.courseName).font(.caption.weight(.semibold)).lineLimit(1)
                }
                Text(entry.startDate, style: .timer)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()

                Button(intent: StopStudySessionIntent()) {
                    Label("Termina", systemImage: "stop.fill").font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Label("Nessuna sessione attiva", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioStatusWidget: Widget {
    let kind = "StudioStatusWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioStatusProvider()) { entry in
            StudioStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio — Sessione attiva")
        .description("Timer live e pulsante per terminare la sessione.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
