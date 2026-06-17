//
//  AppIntent.swift
//  widgetstudio
//
//  Created by Niccoló Pirronello on 20/05/26.
//

// AppIntent.swift
import WidgetKit
import AppIntents
import Foundation
import ActivityKit

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
            defaults.set(false, forKey: "sharedIsPaused")
            defaults.set(now.timeIntervalSince1970, forKey: "sharedStartDate")
            let accumulated = defaults.integer(forKey: "sharedPausedSeconds")
            
            // Aggiorna Live Activity DIRETTAMENTE dal background
            for activity in Activity<StudyActivityAttributes>.activities {
                let state = StudyActivityAttributes.ContentState(startDate: now, accumulatedSeconds: accumulated)
                await activity.update(.init(state: state, staleDate: nil))
            }
            // Notifica l'app via MainActor
            await MainActor.run {
                NotificationCenter.default.post(name: AppConstants.resumeSession, object: nil)
            }
            
        } else {
            // PAUSA
            defaults.set(true, forKey: "sharedIsPaused")
            
            let startDouble = defaults.double(forKey: "sharedStartDate")
            let startDate = Date(timeIntervalSince1970: startDouble)
            let elapsed = Int(now.timeIntervalSince(startDate))
            
            let currentPaused = defaults.integer(forKey: "sharedPausedSeconds")
            let totalPaused = currentPaused + elapsed
            
            defaults.set(totalPaused, forKey: "sharedPausedSeconds")
            
            // Aggiorna Live Activity DIRETTAMENTE dal background
            for activity in Activity<StudyActivityAttributes>.activities {
                let state = StudyActivityAttributes.ContentState(startDate: nil, accumulatedSeconds: totalPaused)
                await activity.update(.init(state: state, staleDate: nil))
            }
            // Notifica l'app via MainActor
            await MainActor.run {
                NotificationCenter.default.post(name: AppConstants.pauseSession, object: nil)
            }
        }
        
        return .result()
    }
}

// 3. Intent Termina (FUORI da ConfigurationAppIntent)
struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Termina"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        let defaults = AppConstants.sharedDefaults
        defaults.set(true, forKey: "sharedStopRequested")
        
        // CALCOLA E SALVA I DATI DELLA SESSIONE PRIMA DI CHIUDERE
        if defaults.bool(forKey: "sharedSessionActive"), let courseName = defaults.string(forKey: "sharedCourseName") {
            let startDouble = defaults.double(forKey: "sharedStartDate")
            let pausedSeconds = defaults.integer(forKey: "sharedPausedSeconds")
            let isPaused = defaults.bool(forKey: "sharedIsPaused")
            
            let startDate = Date(timeIntervalSince1970: startDouble)
            let now = Date()
            let elapsed = isPaused ? pausedSeconds : pausedSeconds + Int(now.timeIntervalSince(startDate))
            let minutes = max(1, elapsed / 60)
            
            // Passiamo i dati al UserDefaults condiviso per l'app
            let sessionData = ["courseName": courseName, "minutes": minutes] as [String : Any]
            defaults.set(sessionData, forKey: AppConstants.sharedSessionEndedToCompleteKey)
        }
        
        // Chiudi Live Activity
        for activity in Activity<StudyActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        // Notifica via MainActor
        await MainActor.run {
            NotificationCenter.default.post(name: AppConstants.stopSession, object: nil)
        }
        return .result()
    }
}
