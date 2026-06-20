//
//  AppConstants.swift
//  studio
//
//  Created by Niccoló Pirronello on 21/05/26.
//
// AppConstants.swift
import Foundation

enum AppConstants {
    // Sostituisci qui il tuo Suite Name per App Groups
    static let suiteName = "group.studioso"
    
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    }
    
    // Chiave speciale per passare i dati della sessione terminata in background
    static let sharedSessionEndedToCompleteKey = "sharedSessionEndedToComplete"
    
    // Nomi delle notifiche per gli aggiornamenti in background
    static let pauseSession = Notification.Name("pauseSession")
    static let resumeSession = Notification.Name("resumeSession")
    static let stopSession = Notification.Name("stopSession")
}
