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

            if connector.isPaused {
                Text(formatTime(connector.pausedSeconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(connector.startDate, style: .timer)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

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

    private func formatTime(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
