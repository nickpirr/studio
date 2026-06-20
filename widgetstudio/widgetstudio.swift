///
//  widgetstudio.swift
//  widgetstudio
//
//  Created by Niccoló Pirronello on 20/05/26.
//
import Foundation
import WidgetKit
import SwiftUI
import AppIntents

struct Presets {
    static let icons = [
        "book.fill", "books.vertical.fill", "book.closed.fill", "graduationcap.fill",
        "pencil.and.outline", "pencil", "doc.fill", "doc.text.fill", "note.text",
        "folder.fill", "tray.fill", "archivebox.fill", "paperclip", "text.book.closed.fill",
        "atom", "function", "sum", "percent", "chart.line.uptrend.xyaxis",
        "chart.pie.fill", "chart.bar.fill", "globe.europe.africa.fill", "globe.americas.fill",
        "leaf.fill", "brain.head.profile", "flask.fill", "testtube.2", "pills.fill",
        "desktopcomputer", "display", "laptopcomputer", "keyboard", "cpu.fill",
        "wifi", "antenna.radiowaves.left.and.right", "network", "server.rack",
        "music.note", "music.note.list", "guitars.fill", "pianokeys", "paintbrush.fill",
        "paintpalette.fill", "camera.fill", "film.fill", "photo.fill",
        "figure.walk", "figure.run", "figure.strengthtraining.traditional",
        "heart.fill", "cross.case.fill", "bandage.fill",
        "star.fill", "crown.fill", "trophy.fill", "target", "flame.fill",
        "bolt.fill", "map.fill", "mappin", "house.fill", "building.2.fill",
        "building.columns.fill", "gift.fill", "cart.fill", "bag.fill",
        "fork.knife", "cup.and.saucer.fill", "creditcard.fill",
        "headphones", "airpodspro", "speaker.wave.3.fill",
        "pawprint.fill", "tortoise.fill", "hare.fill",
        "moon.stars.fill", "sun.max.fill", "cloud.fill", "umbrella.fill",
        "bookmark.fill", "tag.fill", "bell.fill", "clock.fill", "calendar",
        "person.fill", "person.2.fill", "person.crop.circle.fill"
    ]

    static let colorNames: [String] = [
        "blue", "brown", "gray", "green", "indigo", "orange",
        "red", "purple", "pink", "cyan", "mint", "teal"
    ]

    static var colors: [Color] { colorNames.map { color(from: $0) } }

    static func color(from name: String) -> Color {
        switch name {
        case "blue":   return .blue
        case "brown":  return .brown
        case "gray":   return .gray
        case "green":  return .green
        case "indigo": return .indigo
        case "orange": return .orange
        case "red":    return .red
        case "purple": return .purple
        case "pink":   return .pink
        case "cyan":   return .cyan
        case "mint":   return .mint
        case "teal":   return .teal
        default:       return .blue
        }
    }

    static func name(from color: Color) -> String {
        switch color {
        case .blue:   return "blue"
        case .brown:  return "brown"
        case .gray:   return "gray"
        case .green:  return "green"
        case .indigo: return "indigo"
        case .orange: return "orange"
        case .red:    return "red"
        case .purple: return "purple"
        case .pink:   return "pink"
        case .cyan:   return "cyan"
        case .mint:   return "mint"
        case .teal:   return "teal"
        default:      return "blue"
        }
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), courses: [],
                    sessionActive: false, courseName: "", courseIcon: "book.fill",
                    courseColorName: "blue", startDate: Date(), isPaused: false, pausedSeconds: 0)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        buildEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        Timeline(entries: [buildEntry(configuration: configuration)], policy: .never)
    }

    private func buildEntry(configuration: ConfigurationAppIntent) -> SimpleEntry {
        let courses = loadCoursesFromSharedDefaults()
        let defaults = UserDefaults(suiteName: "group.studioso")

        let active = defaults?.bool(forKey: "sharedSessionActive") ?? false
        let name = defaults?.string(forKey: "sharedCourseName") ?? ""
        let startInterval = defaults?.double(forKey: "sharedStartDate") ?? 0
        let start = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()
        let isPaused = defaults?.bool(forKey: "sharedIsPaused") ?? false
        let pausedSeconds = defaults?.integer(forKey: "sharedPausedSeconds") ?? 0
        let match = courses.first(where: { $0.name == name })

        return SimpleEntry(
            date: Date(), configuration: configuration, courses: courses,
            sessionActive: active, courseName: name,
            courseIcon: match?.icon ?? "book.fill", courseColorName: match?.colorName ?? "blue",
            startDate: start, isPaused: isPaused, pausedSeconds: pausedSeconds
        )
    }

    private func loadCoursesFromSharedDefaults() -> [WidgetCourse] {
        guard let defaults = UserDefaults(suiteName: "group.studioso"),
              let data = defaults.data(forKey: "widgetCourses"),
              let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data) else {
            return []
        }
        return courses
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let courses: [WidgetCourse]
    let sessionActive: Bool
    let courseName: String
    let courseIcon: String
    let courseColorName: String
    let startDate: Date
    let isPaused: Bool
    let pausedSeconds: Int
}

struct widgetstudioEntryView: View {
    var entry: Provider.Entry

    private var effectiveStartDate: Date {
        entry.startDate.addingTimeInterval(-Double(entry.pausedSeconds))
    }

    private var pausedTimeText: String {
        let h = entry.pausedSeconds / 3600
        let m = (entry.pausedSeconds % 3600) / 60
        let s = entry.pausedSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    var body: some View {
        if entry.sessionActive {
            activeSessionView
        } else {
            courseListView
        }
    }

    private var courseListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Materie")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            if entry.courses.isEmpty {
                Text("Apri l'app per inserire materie.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(entry.courses.prefix(3)) { course in
                    Link(destination: URL(string: "studio://start/\(course.name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")")!) {
                        HStack(spacing: 8) {
                            Image(systemName: course.icon)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Presets.color(from: course.colorName))
                                .clipShape(Circle())

                            Text(course.name)
                                .font(.footnote.bold())
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var activeSessionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: entry.courseIcon)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Presets.color(from: entry.courseColorName))
                    .clipShape(Circle())

                Text(entry.courseName)
                    .font(.footnote.bold())
                    .lineLimit(1)

                Spacer()
            }

            if entry.isPaused {
                Text(pausedTimeText)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            } else {
                Text(effectiveStartDate, style: .timer)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 8) {
                Button(intent: TogglePauseIntent()) {
                    Label(entry.isPaused ? "Riprendi" : "Pausa", systemImage: entry.isPaused ? "play.fill" : "pause.fill")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button(intent: EndSessionFromWidgetIntent()) {
                    Label("Termina", systemImage: "stop.fill")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct widgetstudio: Widget {
    let kind: String = "widgetstudio"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            widgetstudioEntryView(entry: entry)
        }
        .configurationDisplayName("Studio — Materie")
        .description("Avvia una materia o segui la sessione in corso.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
