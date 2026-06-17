//
//  Studio_Watch_AppApp.swift
//  Studio Watch App Watch App
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import SwiftUI

@main
struct StudioWatchAppApp: App {
    @StateObject private var connector = WatchConnector()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(connector)
        }
    }
}
