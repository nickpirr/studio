//
//  Untitled.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//
import Foundation
import AppIntents
import AppIntents

// MARK: - ENTITÀ MATERIA
struct CourseEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Materia"
    static var defaultQuery = CourseEntityQuery()

    let id: String
    let name: String
    let icon: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
    }
}

struct CourseEntityQuery: AppIntents.EntityQuery {
    typealias Entity = CourseEntity

    func entities(for identifiers: [String]) async throws -> [CourseEntity] {
        loadCourses().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [CourseEntity] {
        loadCourses()
    }

    private func loadCourses() -> [CourseEntity] {
        guard let data = UserDefaults(suiteName: "group.com.niccolo.studio")?
            .data(forKey: "widgetCourses"),
              let courses = try? JSONDecoder().decode([WidgetCourse].self, from: data)
        else { return [] }
        return courses.map {
            CourseEntity(id: $0.name, name: $0.name, icon: $0.icon)
        }
    }
}

// MARK: - INTENT: AVVIA SESSIONE
struct StartStudySessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Avvia sessione di studio"
    static var description = IntentDescription("Apre Studio e avvia una sessione per la materia scelta.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Materia", description: "La materia da studiare")
    var course: CourseEntity

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.niccolo.studio")?
            .set(course.name, forKey: "shortcutPendingCourse")
        return .result()
    }
}

// MARK: - SHORTCUTS PROVIDER
struct StudioShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStudySessionIntent(),
            phrases: [
                "Avvia sessione su \(\.$course) con \(.applicationName)",
                "Studia \(\.$course) con \(.applicationName)",
                "Inizia a studiare \(\.$course) con \(.applicationName)"
            ],
            shortTitle: "Avvia sessione",
            systemImageName: "play.fill"
        )
    }
}
// MARK: - NOTIFICATION NAMES
// Modello condiviso per i corsi nel Widget
struct WidgetCourse: Codable, Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let colorName: String
}

