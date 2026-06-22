//
//  StudioStatusWidget.swift
//  studio
//
//  Created by Niccolo Pirronello on 20/06/2026.
//
import WidgetKit
import SwiftUI
import AppIntents
import Foundation

struct StudioStatusEntry: TimelineEntry {
    let date: Date
    let sessionActive: Bool
    let courseName: String
    let courseIcon: String
    let courseColorName: String
    let startDate: Date
    let isPaused: Bool
    let pausedSeconds: Int
}

struct StudioStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioStatusEntry {
        StudioStatusEntry(
            date: Date(),
            sessionActive: true,
            courseName: "Matematica",
            courseIcon: "function",
            courseColorName: "blue",
            startDate: Date().addingTimeInterval(-540),
            isPaused: false,
            pausedSeconds: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StudioStatusEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioStatusEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> StudioStatusEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        let active = defaults?.bool(forKey: "sharedSessionActive") ?? false
        let name = defaults?.string(forKey: "sharedCourseName") ?? ""
        let startInterval = defaults?.double(forKey: "sharedStartDate") ?? 0
        let start = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()
        let isPaused = defaults?.bool(forKey: "sharedIsPaused") ?? false
        let pausedSeconds = defaults?.integer(forKey: "sharedPausedSeconds") ?? 0

        var icon = "book.fill"
        var colorName = "blue"
        if let data = defaults?.data(forKey: "widgetCourses"),
           let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data),
           let match = courses.first(where: { $0.name == name }) {
            icon = match.icon
            colorName = match.colorName
        }

        return StudioStatusEntry(
            date: Date(),
            sessionActive: active,
            courseName: name,
            courseIcon: icon,
            courseColorName: colorName,
            startDate: start,
            isPaused: isPaused,
            pausedSeconds: pausedSeconds
        )
    }
}

struct StudioStatusWidgetView: View {
    let entry: StudioStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if entry.sessionActive {
                HStack(spacing: 8) {
                    Image(systemName: entry.courseIcon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Presets.color(from: entry.courseColorName), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.courseName.isEmpty ? "Sessione" : entry.courseName)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                        Text(entry.isPaused ? "In pausa" : "In corso")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entry.isPaused ? .orange : .secondary)
                    }
                }

                Spacer(minLength: 0)

                if entry.isPaused {
                    Text(format(seconds: entry.pausedSeconds))
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(entry.startDate, style: .timer)
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                HStack(spacing: 8) {
                    Button(intent: TogglePauseIntent()) {
                        Image(systemName: entry.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(entry.isPaused ? .green : .blue)

                    Button(intent: StopStudySessionIntent()) {
                        Image(systemName: "stop.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                Spacer(minLength: 0)
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Nessuna sessione")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func format(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let h = safeSeconds / 3600
        let m = (safeSeconds % 3600) / 60
        let s = safeSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

struct StudioStatusWidget: Widget {
    let kind = "StudioStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioStatusProvider()) { entry in
            StudioStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio - Sessione attiva")
        .description("Timer live e controlli rapidi per la sessione.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
