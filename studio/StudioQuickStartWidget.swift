//
//  StudioQuickStartWidget.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/06/2026.
//
import WidgetKit
import SwiftUI
import AppIntents

struct StudioQuickStartEntry: TimelineEntry {
    let date: Date
    let courses: [WidgetCourse]
}

struct StudioQuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioQuickStartEntry {
        StudioQuickStartEntry(date: Date(), courses: [])
    }
    func getSnapshot(in context: Context, completion: @escaping (StudioQuickStartEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioQuickStartEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }
    private func currentEntry() -> StudioQuickStartEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        guard let data = defaults?.data(forKey: "widgetCourses"),
              let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data) else {
            return StudioQuickStartEntry(date: Date(), courses: [])
        }
        return StudioQuickStartEntry(date: Date(), courses: courses)
    }
}

struct StudioQuickStartWidgetView: View {
    let entry: StudioQuickStartEntry
    @Environment(\.widgetFamily) var family

    private var visibleCourses: [WidgetCourse] {
        Array(entry.courses.prefix(family == .systemSmall ? 2 : 4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Avvia sessione")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if visibleCourses.isEmpty {
                Text("Nessuna materia")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(visibleCourses) { course in
                    Button(intent: makeIntent(for: course)) {
                        HStack {
                            Image(systemName: course.icon)
                            Text(course.name).lineLimit(1)
                            Spacer()
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.clear }
    }

    private func makeIntent(for course: WidgetCourse) -> StartStudySessionIntent {
        let intent = StartStudySessionIntent()
        intent.course = CourseEntity(id: course.name, name: course.name, icon: course.icon)
        return intent
    }
}

struct StudioQuickStartWidget: Widget {
    let kind = "StudioQuickStartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioQuickStartProvider()) { entry in
            StudioQuickStartWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio — Avvio rapido")
        .description("Avvia una sessione di studio con un tocco.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
