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
        // Studio
        "book.fill", "books.vertical.fill", "book.closed.fill", "graduationcap.fill",
        "pencil.and.outline", "pencil", "doc.fill", "doc.text.fill", "note.text",
        "folder.fill", "tray.fill", "archivebox.fill", "paperclip", "text.book.closed.fill",
        // Scienze
        "atom", "function", "sum", "percent", "chart.line.uptrend.xyaxis",
        "chart.pie.fill", "chart.bar.fill", "globe.europe.africa.fill", "globe.americas.fill",
        "leaf.fill", "brain.head.profile", "flask.fill", "testtube.2", "pills.fill",
        // Tech
        "desktopcomputer", "display", "laptopcomputer", "keyboard", "cpu.fill",
        "wifi", "antenna.radiowaves.left.and.right", "network", "server.rack",
        // Arte e musica
        "music.note", "music.note.list", "guitars.fill", "pianokeys", "paintbrush.fill",
        "paintpalette.fill", "camera.fill", "film.fill", "photo.fill",
        // Sport e salute
        "figure.walk", "figure.run", "figure.strengthtraining.traditional",
        "heart.fill", "cross.case.fill", "bandage.fill",
        // Varie
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
// Modello specchio per decodificare i dati mandati dall'app principale


struct Provider: AppIntentTimelineProvider {
    // Ora ConfigurationAppIntent dovrebbe essere riconosciuto
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent(), courses: [])
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let courses = loadCoursesFromSharedDefaults()
        return SimpleEntry(date: Date(), configuration: configuration, courses: courses)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let courses = loadCoursesFromSharedDefaults()
        let entry = SimpleEntry(date: Date(), configuration: configuration, courses: courses)
        
        // Aggiorna il widget alla fine o quando esplicitamente ricaricato dall'app principale
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    private func loadCoursesFromSharedDefaults() -> [WidgetCourse] {
        guard let defaults = UserDefaults(suiteName: "group.com.niccolo.studio"),
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
}

struct widgetstudioEntryView : View {
    var entry: Provider.Entry

    var body: some View {
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
    }
}

struct widgetstudio: Widget {
    let kind: String = "widgetstudio"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            widgetstudioEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}
