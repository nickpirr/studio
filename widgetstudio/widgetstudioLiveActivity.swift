
//
//  widgetstudioLiveActivity.swift
//  widgetstudio
//
//  Created by Niccoló Pirronello on 20/05/26.
//


// widgetstudioLiveActivity.swift

//
//  widgetstudioLiveActivity.swift
//  widgetstudio
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct StudyActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var startDate: Date?
        var accumulatedSeconds: Int
    }
    var courseName: String
    var courseColorHex: String
    var courseIcon: String
    var isFocusModeActive: Bool // NUOVO ATTRIBUTO AGGIUNTO
}

// Estensione per accedere ai nomi delle notifiche condivisi
extension Notification.Name {
    static let pauseSession = AppConstants.pauseSession
    static let resumeSession = AppConstants.resumeSession
    static let stopSession = AppConstants.stopSession
}

struct widgetstudioLiveActivity: Widget {
    
    func format(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            // SCHERMATA DI BLOCCO
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2))
                    Image(systemName: context.attributes.courseIcon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.courseName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let startDate = context.state.startDate {
                        let effectiveStart = startDate.addingTimeInterval(-TimeInterval(context.state.accumulatedSeconds))
                        Text(effectiveStart, style: .timer)
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("In pausa - \(format(seconds: context.state.accumulatedSeconds))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.yellow)
                    }
                }
                
                Spacer()
                
                // PULSANTE VISIBILE SOLO SE IL FOCUS NON È ATTIVO
                if !context.attributes.isFocusModeActive {
                    Button(intent: TogglePauseIntent()) {
                        Image(systemName: context.state.startDate == nil ? "play.fill" : "pause.fill")
                            .font(.title3)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.yellow)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .activityBackgroundTint(Color.black)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.courseIcon)
                            .foregroundColor(.yellow)
                        Text(context.attributes.courseName)
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let startDate = context.state.startDate {
                        let effectiveStart = startDate.addingTimeInterval(-TimeInterval(context.state.accumulatedSeconds))
                        Text(effectiveStart, style: .timer)
                            .font(.headline.monospacedDigit())
                            .foregroundColor(.yellow)
                    } else {
                        Text(format(seconds: context.state.accumulatedSeconds))
                            .font(.headline.monospacedDigit())
                            .foregroundColor(.yellow)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // PULSANTE VISIBILE SOLO SE IL FOCUS NON È ATTIVO
                    if !context.attributes.isFocusModeActive {
                        HStack {
                            Spacer()
                            Button(intent: TogglePauseIntent()) {
                                HStack {
                                    Image(systemName: context.state.startDate == nil ? "play.fill" : "pause.fill")
                                    Text(context.state.startDate == nil ? "Riprendi" : "Pausa")
                                }
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 8)
                                .background(Color.yellow.opacity(0.2))
                                .foregroundColor(.yellow)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, 12)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.courseIcon)
                    .foregroundColor(.yellow)
            } compactTrailing: {
                if let startDate = context.state.startDate {
                    let effectiveStart = startDate.addingTimeInterval(-TimeInterval(context.state.accumulatedSeconds))
                    Text(effectiveStart, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.yellow)
                } else {
                    Text("⏸")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            } minimal: {
                Image(systemName: context.attributes.courseIcon)
                    .foregroundColor(.yellow)
            }
            // Torna ad aprire l'app normalmente quando clicchi (visto che non puoi terminare da qui)
            .widgetURL(URL(string: "studio://start/\(context.attributes.courseName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"))
        }
    }
}
