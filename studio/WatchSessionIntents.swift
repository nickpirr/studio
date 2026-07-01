//
//  WatchSessionIntents.swift
//  studio
//
//  Created by Niccoló Pirronello on 20/06/2026.
//

import AppIntents
import WatchConnectivity
import WidgetKit

struct WatchStartStudySessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Avvia sessione"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Materia")
    var courseName: String

    func perform() async throws -> some IntentResult {
        let newID = UUID().uuidString
        let now = Date()
        let defaults = WatchSync.defaults
        defaults?.set(courseName, forKey: WatchSync.keyCourseName)
        defaults?.set(true, forKey: WatchSync.keySessionActive)
        defaults?.set(newID, forKey: WatchSync.keySessionID)
        defaults?.set(now.timeIntervalSince1970, forKey: WatchSync.keyStartDate)
        defaults?.set(false, forKey: WatchSync.keyIsPaused)
        defaults?.set(0, forKey: WatchSync.keyPausedSeconds)
        defaults?.set(false, forKey: WatchSync.keyStopRequested)

        // Icona e colore per le complicazioni
        if let data = defaults?.data(forKey: WatchSync.keyCourses),
           let courses = try? JSONDecoder().decode([WatchCourseLite].self, from: data),
           let course = courses.first(where: { $0.name == courseName }) {
            defaults?.set(course.icon, forKey: WatchSync.keyCourseIcon)
            defaults?.set(course.colorName, forKey: WatchSync.keyCourseColor)
        }

        if WCSession.default.activationState != .activated { WCSession.default.activate() }
        if WCSession.default.activationState == .activated {
            let message: [String: Any] = ["action": "start", "courseName": courseName, "sessionID": newID, "startDate": now.timeIntervalSince1970]
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                    WCSession.default.transferUserInfo(message)
                }
            } else {
                WCSession.default.transferUserInfo(message)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct WatchStopStudySessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Termina sessione"
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = WatchSync.defaults
        let sessionID = defaults?.string(forKey: WatchSync.keySessionID) ?? ""
        defaults?.set(false, forKey: WatchSync.keySessionActive)

        if WCSession.default.activationState == .activated {
            let message: [String: Any] = ["action": "stop", "sessionID": sessionID]
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                    WCSession.default.transferUserInfo(message)
                }
            } else {
                WCSession.default.transferUserInfo(message)
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
