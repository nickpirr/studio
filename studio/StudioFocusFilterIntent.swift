//
//  Untitled.swift
//  studio
//
//  Created by Niccoló Pirronello on 18/06/2026.
//

// MARK: - FOCUS FILTER INTENT
// Da mettere in un file separato "StudioFocusFilterIntent.swift" oppure in fondo al ContentView

import AppIntents

struct StudioFocusFilterIntent: SetFocusFilterIntent {

    static let title: LocalizedStringResource = "Studio"
    static let description: LocalizedStringResource? = "Attiva la modalità studio con Focus."

    @Parameter(title: "Materia attiva")
    var courseName: String?

    var displayRepresentation: DisplayRepresentation {
        if let name = courseName {
            return DisplayRepresentation(title: "Studio: \(name)")
        }
        return DisplayRepresentation(title: "Studio")
    }

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
