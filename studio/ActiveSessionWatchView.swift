//
//  ActiveSessionWatchView.swift
//  studio
//
//  Created by Niccoló Pirronello on 19/06/2026.
//

import SwiftUI

struct ActiveSessionWatchView: View {
    @EnvironmentObject var connector: WatchConnector

    var body: some View {
        VStack(spacing: 12) {
            Text(connector.courseName)
                .font(.headline)
                .lineLimit(1)

            Text(connector.startDate, style: .timer)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            Button(role: .destructive) {
                connector.stopSession()
            } label: {
                Label("Termina", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }
}
