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
