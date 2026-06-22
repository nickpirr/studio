//
//  AppIntent.swift
//  widgetstudio
//
//  Created by Niccoló Pirronello on 20/05/26.
//

import WidgetKit
import AppIntents
import Foundation
import ActivityKit
import UserNotifications

// 1. Configurazione Widget (Top-level)
struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description: IntentDescription = "This is an example widget."

    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
    
    init() {}
}

// 2. Intent Pausa (FUORI da ConfigurationAppIntent)
struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pausa / Riprendi"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let defaults = AppConstants.sharedDefaults
        let isPaused = defaults.bool(forKey: "sharedIsPaused")
        let now = Date()
        
        if isPaused {
            // RIPRENDI
            // Regola unica: sharedStartDate è sempre la data effettiva da cui far partire
            // il timer visibile. Quindi quando riprendo imposto: now - tempo già accumulato.
            let accumulated = defaults.integer(forKey: "sharedPausedSeconds")
            let resumedStartDate = now.addingTimeInterval(-TimeInterval(accumulated))

            defaults.set(false, forKey: "sharedIsPaused")
            defaults.set(resumedStartDate.timeIntervalSince1970, forKey: "sharedStartDate")
            defaults.set(true, forKey: "sharedSessionActive")

            // Aggiorna Live Activity DIRETTAMENTE dal background
            for activity in Activity<StudyActivityAttributes>.activities {
                let state = StudyActivityAttributes.ContentState(startDate: resumedStartDate, accumulatedSeconds: accumulated)
                await activity.update(.init(state: state, staleDate: nil))
            }

            await MainActor.run {
                NotificationCenter.default.post(name: AppConstants.resumeSession, object: nil)
            }
            defaults.synchronize()
            WidgetCenter.shared.reloadTimelines(ofKind: "widgetstudio")
            WidgetCenter.shared.reloadAllTimelines()
            
        } else {
            // PAUSA
            // sharedStartDate è già la data effettiva di inizio, quindi NON devo sommare
            // currentPaused: sarebbe il doppio conteggio che faceva saltare il timer.
            let startDouble = defaults.double(forKey: "sharedStartDate")
            let startDate = startDouble > 0 ? Date(timeIntervalSince1970: startDouble) : now
            let totalPaused = max(0, Int(now.timeIntervalSince(startDate)))

            defaults.set(true, forKey: "sharedIsPaused")
            defaults.set(totalPaused, forKey: "sharedPausedSeconds")
            defaults.set(true, forKey: "sharedSessionActive")
            
            // Aggiorna Live Activity DIRETTAMENTE dal background
            for activity in Activity<StudyActivityAttributes>.activities {
                let state = StudyActivityAttributes.ContentState(startDate: nil, accumulatedSeconds: totalPaused)
                await activity.update(.init(state: state, staleDate: nil))
            }

            await MainActor.run {
                NotificationCenter.default.post(name: AppConstants.pauseSession, object: nil)
            }
            defaults.synchronize()
            WidgetCenter.shared.reloadTimelines(ofKind: "widgetstudio")
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        return .result()
    }
}

// 3. Intent Snooze Pausa (notifica promemoria, NON ferma il timer)
struct SnoozeReminderIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Promemoria pausa"

    @Parameter(title: "Minuti")
    var minutes: Int

    init() {
        self.minutes = 5
    }

    init(minutes: Int) {
        self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        let courseName = AppConstants.sharedDefaults.string(forKey: "sharedCourseName") ?? "la tua materia"

        let content = UNMutableNotificationContent()
        content.title = "Pausa terminata"
        content.body = "Sono passati \(minutes) minuti. Torna a studiare \(courseName)!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "snoozeReminder-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)

        return .result()
    }
}


private func finalElapsedSeconds(from defaults: UserDefaults) -> Int {
    let pausedSeconds = defaults.integer(forKey: "sharedPausedSeconds")
    if defaults.bool(forKey: "sharedIsPaused") {
        return max(0, pausedSeconds)
    }

    let startDouble = defaults.double(forKey: "sharedStartDate")
    guard startDouble > 0 else { return max(0, pausedSeconds) }

    let startDate = Date(timeIntervalSince1970: startDouble)
    return max(0, Int(Date().timeIntervalSince(startDate)))
}

private func closeSharedSessionForWidgets(defaults: UserDefaults) {
    let currentSessionID = defaults.string(forKey: "sharedSessionID") ?? ""
    defaults.set(true, forKey: "sharedStopRequested")
    defaults.set(currentSessionID, forKey: "sharedStopSessionID")
    defaults.set(false, forKey: "sharedSessionActive")
    defaults.set(false, forKey: "sharedIsPaused")
    defaults.set(0, forKey: "sharedPausedSeconds")
    defaults.set(0, forKey: "sharedStartDate")
    defaults.set("", forKey: "sharedCourseName")
    defaults.set("", forKey: "sharedSessionID")
    defaults.synchronize()
}

// 4. Intent Termina (FUORI da ConfigurationAppIntent)
struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Termina"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let defaults = AppConstants.sharedDefaults
        let currentSessionID = defaults.string(forKey: "sharedSessionID") ?? ""
        let finalElapsedSeconds = finalElapsedSeconds(from: defaults)
        defaults.set(true, forKey: "sharedStopRequested")
        defaults.set(currentSessionID, forKey: "sharedStopSessionID")
        
        if defaults.bool(forKey: "sharedSessionActive"), let courseName = defaults.string(forKey: "sharedCourseName") {
            let minutes = max(1, finalElapsedSeconds / 60)
            let sessionData = ["courseName": courseName, "minutes": minutes] as [String : Any]
            defaults.set(sessionData, forKey: AppConstants.sharedSessionEndedToCompleteKey)
        }

        let finalContent = ActivityContent(
            state: StudyActivityAttributes.ContentState(startDate: nil, accumulatedSeconds: finalElapsedSeconds, isEnded: true),
            staleDate: nil
        )
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.update(finalContent)
        }

        closeSharedSessionForWidgets(defaults: defaults)   // chiude subito lo stato, non aspetta l'app
        
        Task {
            for activity in Activity<StudyActivityAttributes>.activities {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }
        
        await MainActor.run {
            NotificationCenter.default.post(name: AppConstants.stopSession, object: nil)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "widgetstudio")
        WidgetCenter.shared.reloadAllTimelines()   // ← forza il refresh del widget
        return .result()
    }
}
struct EndSessionFromWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Termina sessione"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = AppConstants.sharedDefaults
        let currentSessionID = defaults.string(forKey: "sharedSessionID") ?? ""
        let finalElapsedSeconds = finalElapsedSeconds(from: defaults)
        defaults.set(true, forKey: "sharedStopRequested")
        defaults.set(currentSessionID, forKey: "sharedStopSessionID")

        if defaults.bool(forKey: "sharedSessionActive"), let courseName = defaults.string(forKey: "sharedCourseName") {
            let minutes = max(1, finalElapsedSeconds / 60)
            let sessionData = ["courseName": courseName, "minutes": minutes] as [String: Any]
            defaults.set(sessionData, forKey: AppConstants.sharedSessionEndedToCompleteKey)
        }

        let finalContent = ActivityContent(
            state: StudyActivityAttributes.ContentState(startDate: nil, accumulatedSeconds: finalElapsedSeconds, isEnded: true),
            staleDate: nil
        )
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.update(finalContent)
        }

        closeSharedSessionForWidgets(defaults: defaults)   // chiude subito lo stato

        Task {
            for activity in Activity<StudyActivityAttributes>.activities {
                await activity.end(finalContent, dismissalPolicy: .immediate)
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "widgetstudio")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
