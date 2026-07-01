//
//  StudioWatchShared.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//
import Foundation
import SwiftUI

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
    static let keyCourseIcon    = "sharedCourseIcon"
    static let keyCourseColor   = "sharedCourseColor"
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

/// Mappa dei colori delle materie, condivisa tra iPhone, Watch e complicazioni.
/// (Nome diverso da `Presets` per evitare conflitti con le definizioni per-target.)
enum WatchPalette {
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
}
