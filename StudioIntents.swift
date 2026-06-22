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
import WidgetKit
import UserNotifications

struct StopStudySessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Termina sessione di studio"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.studioso")   // ← era "group.com.niccolo.studio"
        let sessionID = defaults?.string(forKey: "sharedSessionID") ?? ""
        let courseName = defaults?.string(forKey: "sharedCourseName") ?? ""
        let startDouble = defaults?.double(forKey: "sharedStartDate") ?? 0
        let pausedSeconds = defaults?.integer(forKey: "sharedPausedSeconds") ?? 0
        let isPaused = defaults?.bool(forKey: "sharedIsPaused") ?? false

        if !courseName.isEmpty, defaults?.bool(forKey: "sharedSessionActive") == true {
            let startDate = startDouble > 0 ? Date(timeIntervalSince1970: startDouble) : Date()
            let elapsed = isPaused ? pausedSeconds : Int(Date().timeIntervalSince(startDate))
            let minutes = max(1, elapsed / 60)
            defaults?.set(["courseName": courseName, "minutes": minutes], forKey: "sharedSessionEndedToComplete")
        }

        defaults?.set(true, forKey: "sharedStopRequested")
        defaults?.set(sessionID, forKey: "sharedStopSessionID")
        defaults?.set(false, forKey: "sharedSessionActive")   // ← aggiunto
        defaults?.set(false, forKey: "sharedIsPaused")
        defaults?.set(0, forKey: "sharedPausedSeconds")
        defaults?.set(0, forKey: "sharedStartDate")
        defaults?.set("", forKey: "sharedCourseName")
        defaults?.set("", forKey: "sharedSessionID")
        defaults?.synchronize()

        let isForeground = defaults?.bool(forKey: "appIsForeground") ?? false
        if !isForeground {
            let content = UNMutableNotificationContent()
            content.title = "Sessione interrotta"
            content.body = "Tocca per terminarla e salvare i dettagli."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "widgetStopSession", content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
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
        guard let data = UserDefaults(suiteName: "group.studioso")?
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
        UserDefaults(suiteName: "group.studioso")?
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

struct WidgetCourseStat: Codable, Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let colorName: String
    let minutes: Int
}

struct WidgetGradePoint: Codable, Identifiable {
    var id: Int { dayIndex }
    let dayIndex: Int
    let effort: Double
    let concentration: Double
    let satisfaction: Double

    var overall: Double {
        let values = [effort, concentration, satisfaction].filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}

struct WidgetGradeSummary: Codable {
    let averageEffort: Double
    let averageConcentration: Double
    let averageSatisfaction: Double
    let dailyPoints: [WidgetGradePoint]
}

