//
//  WatchConnector.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import Foundation
import WatchConnectivity
import Combine
import WidgetKit

final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {

    @Published var sessionActive = false
    @Published var courseName = ""
    @Published var startDate = Date()
    @Published var pausedSeconds = 0
    @Published var isPaused = false
    @Published var sessionID = ""
    @Published var courses: [WatchCourseLite] = []
    @Published var weeklyMinutes: [Int] = Array(repeating: 0, count: 7)

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        loadLocalState()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.loadLocalState()
            if !session.receivedApplicationContext.isEmpty {
                self.applyContext(session.receivedApplicationContext)
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.applyContext(applicationContext) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async { self.applyContext(userInfo) }
    }

    private func applyContext(_ context: [String: Any]) {
        let defaults = WatchSync.defaults

        if let coursesData = context["courses"] as? Data,
           let decoded = try? JSONDecoder().decode([WatchCourseLite].self, from: coursesData) {
            courses = decoded
            defaults?.set(coursesData, forKey: WatchSync.keyCourses)
        }

        if let weekly = context["weeklyMinutes"] as? [Int] {
            weeklyMinutes = weekly
            defaults?.set(weekly, forKey: WatchSync.keyWeeklyMinutes)
        }

        if let active = context["sessionActive"] as? Bool {
            sessionActive = active
            defaults?.set(active, forKey: WatchSync.keySessionActive)
        }

        if let name = context["courseName"] as? String {
            courseName = name
            defaults?.set(name, forKey: WatchSync.keyCourseName)
        }

        if let sid = context["sessionID"] as? String {
            sessionID = sid
            defaults?.set(sid, forKey: WatchSync.keySessionID)
        }

        if let start = context["startDate"] as? Double, start > 0 {
            startDate = Date(timeIntervalSince1970: start)
            defaults?.set(start, forKey: WatchSync.keyStartDate)
        }

        if let paused = context["isPaused"] as? Bool {
            isPaused = paused
            defaults?.set(paused, forKey: WatchSync.keyIsPaused)
        }

        if let pSeconds = context["pausedSeconds"] as? Int {
            pausedSeconds = pSeconds
            defaults?.set(pSeconds, forKey: WatchSync.keyPausedSeconds)
        }

        if let action = context["action"] as? String {
            switch action {
            case "start":
                sessionActive = true
                isPaused = false
                pausedSeconds = 0
                defaults?.set(true, forKey: WatchSync.keySessionActive)
                defaults?.set(false, forKey: WatchSync.keyIsPaused)
                defaults?.set(0, forKey: WatchSync.keyPausedSeconds)

            case "pause":
                let pSeconds = context["pausedSeconds"] as? Int ?? pausedSeconds
                pausedSeconds = pSeconds
                isPaused = true
                defaults?.set(true, forKey: WatchSync.keyIsPaused)
                defaults?.set(pSeconds, forKey: WatchSync.keyPausedSeconds)

            case "resume":
                if let start = context["startDate"] as? Double, start > 0 {
                    startDate = Date(timeIntervalSince1970: start)
                    defaults?.set(start, forKey: WatchSync.keyStartDate)
                }
                isPaused = false
                defaults?.set(false, forKey: WatchSync.keyIsPaused)

            case "stop":
                sessionActive = false
                courseName = ""
                isPaused = false
                pausedSeconds = 0
                defaults?.set(false, forKey: WatchSync.keySessionActive)
                defaults?.set("", forKey: WatchSync.keyCourseName)
                defaults?.set(false, forKey: WatchSync.keyIsPaused)
                defaults?.set(0, forKey: WatchSync.keyPausedSeconds)

            default:
                break
            }
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadLocalState() {
        let defaults = WatchSync.defaults
        sessionActive = defaults?.bool(forKey: WatchSync.keySessionActive) ?? false
        courseName    = defaults?.string(forKey: WatchSync.keyCourseName) ?? ""
        sessionID     = defaults?.string(forKey: WatchSync.keySessionID) ?? ""
        pausedSeconds = defaults?.integer(forKey: WatchSync.keyPausedSeconds) ?? 0
        isPaused      = defaults?.bool(forKey: WatchSync.keyIsPaused) ?? false

        let startInterval = defaults?.double(forKey: WatchSync.keyStartDate) ?? 0
        startDate = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()

        if let coursesData = defaults?.data(forKey: WatchSync.keyCourses),
           let decoded = try? JSONDecoder().decode([WatchCourseLite].self, from: coursesData) {
            courses = decoded
        }

        weeklyMinutes = defaults?.array(forKey: WatchSync.keyWeeklyMinutes) as? [Int] ?? Array(repeating: 0, count: 7)
    }

    // MARK: - Azioni utente
    func startSession(course: WatchCourseLite) {
        let newID = UUID().uuidString
        let now = Date()

        let defaults = WatchSync.defaults
        defaults?.set(course.name, forKey: WatchSync.keyCourseName)
        defaults?.set(true, forKey: WatchSync.keySessionActive)
        defaults?.set(newID, forKey: WatchSync.keySessionID)
        defaults?.set(now.timeIntervalSince1970, forKey: WatchSync.keyStartDate)
        defaults?.set(false, forKey: WatchSync.keyIsPaused)
        defaults?.set(0, forKey: WatchSync.keyPausedSeconds)
        defaults?.set(false, forKey: WatchSync.keyStopRequested)

        sessionActive = true
        courseName = course.name
        sessionID = newID
        startDate = now
        isPaused = false
        pausedSeconds = 0

        sendToPhone([
            "action": "start",
            "courseName": course.name,
            "sessionID": newID,
            "startDate": now.timeIntervalSince1970,
            "sessionActive": true,
            "isPaused": false,
            "pausedSeconds": 0
        ])

        WidgetCenter.shared.reloadAllTimelines()
    }

    func pauseSession() {
        let pSeconds = Int(Date().timeIntervalSince(startDate))
        pausedSeconds = pSeconds
        isPaused = true
        WatchSync.defaults?.set(true, forKey: WatchSync.keyIsPaused)
        WatchSync.defaults?.set(pSeconds, forKey: WatchSync.keyPausedSeconds)
        sendToPhone(["action": "pause", "isPaused": true, "pausedSeconds": pSeconds])
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resumeSession() {
        let resumedStartDate = Date().addingTimeInterval(-TimeInterval(pausedSeconds))
        startDate = resumedStartDate
        isPaused = false
        WatchSync.defaults?.set(false, forKey: WatchSync.keyIsPaused)
        WatchSync.defaults?.set(resumedStartDate.timeIntervalSince1970, forKey: WatchSync.keyStartDate)
        sendToPhone([
            "action": "resume",
            "isPaused": false,
            "startDate": resumedStartDate.timeIntervalSince1970,
            "pausedSeconds": pausedSeconds
        ])
        WidgetCenter.shared.reloadAllTimelines()
    }

    func stopSession() {
        let defaults = WatchSync.defaults
        let stoppedSessionID = sessionID

        defaults?.set(false, forKey: WatchSync.keySessionActive)
        defaults?.set("", forKey: WatchSync.keyCourseName)
        defaults?.set(false, forKey: WatchSync.keyIsPaused)
        defaults?.set(0, forKey: WatchSync.keyPausedSeconds)

        sessionActive = false
        courseName = ""
        isPaused = false
        pausedSeconds = 0

        sendToPhone(["action": "stop", "sessionID": stoppedSessionID, "sessionActive": false])
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func sendToPhone(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            try WCSession.default.updateApplicationContext(message)
        } catch {
            // updateApplicationContext può fallire se il payload non è valido; in quel caso resta transferUserInfo/sendMessage.
        }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }
}
