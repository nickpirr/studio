//
//  StudioWatchShared.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//
import Foundation

struct WatchCourseLite: Codable, Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let colorName: String
}

enum WatchSync {
    static let suiteName = "group.studioso"

    // Chiavi condivise — stessi nomi usati già nell'App Group dell'iPhone
    static let keySessionActive = "sharedSessionActive"
    static let keyCourseName    = "sharedCourseName"
    static let keyStartDate     = "sharedStartDate"
    static let keyPausedSeconds = "sharedPausedSeconds"
    static let keyIsPaused      = "sharedIsPaused"
    static let keySessionID     = "sharedSessionID"
    static let keyStopRequested = "sharedStopRequested"
    static let keyStopSessionID = "sharedStopSessionID"
    static let keyCourses       = "watchCourses"
    static let keyWeeklyMinutes = "watchWeeklyMinutes"

    static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }
}
