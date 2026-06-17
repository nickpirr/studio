//
//  WatchConnector.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import Foundation
import WatchConnectivity
import Combine

final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {

    @Published var sessionActive = false
    @Published var courseName = ""
    @Published var startDate = Date()
    @Published var pausedSeconds = 0
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
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadLocalState() {
        let defaults = WatchSync.defaults
        sessionActive = defaults?.bool(forKey: WatchSync.keySessionActive) ?? false
        courseName    = defaults?.string(forKey: WatchSync.keyCourseName) ?? ""
        sessionID     = defaults?.string(forKey: WatchSync.keySessionID) ?? ""
        pausedSeconds = defaults?.integer(forKey: WatchSync.keyPausedSeconds) ?? 0
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

        sendToPhone([
            "action": "start",
            "courseName": course.name,
            "sessionID": newID,
            "startDate": now.timeIntervalSince1970
        ])

        WidgetCenter.shared.reloadAllTimelines()
    }

    func stopSession() {
        let defaults = WatchSync.defaults
        defaults?.set(false, forKey: WatchSync.keySessionActive)
        defaults?.set("", forKey: WatchSync.keyCourseName)
        sessionActive = false

        sendToPhone(["action": "stop", "sessionID": sessionID])
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func sendToPhone(_ message: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { _ in
                WCSession.default.transferUserInfo(message)
            }
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }
}

import WidgetKit
