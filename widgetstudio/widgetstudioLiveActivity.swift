//
//  widgetstudioLiveActivity.swift
//  widgetstudio
//
//  Created by Niccolo Pirronello on 20/05/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct StudyActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var startDate: Date?
        var accumulatedSeconds: Int
        var isEnded: Bool = false
    }

    var courseName: String
    var courseColorHex: String
    var courseIcon: String
    var isFocusModeActive: Bool
}

extension Notification.Name {
    static let pauseSession = AppConstants.pauseSession
    static let resumeSession = AppConstants.resumeSession
    static let stopSession = AppConstants.stopSession
}

private struct LiveTimerText: View {
    let startDate: Date?
    let accumulatedSeconds: Int
    var size: CGFloat = 34

    var body: some View {
        Group {
            if let startDate {
                Text(startDate, style: .timer)
                    .foregroundStyle(.white)
            } else {
                Text(format(seconds: accumulatedSeconds))
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func format(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let h = safeSeconds / 3600
        let m = (safeSeconds % 3600) / 60
        let s = safeSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

private struct LiveIconButton<Intent: AppIntent>: View {
    let systemName: String
    let tint: Color
    let intent: Intent

    var body: some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(tint.opacity(0.42), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct widgetstudioLiveActivity: Widget {
    private func statusText(for state: StudyActivityAttributes.ContentState) -> String {
        if state.isEnded { return "Terminata" }
        return state.startDate == nil ? "Pausa" : "Studio"
    }

    private func statusColor(for state: StudyActivityAttributes.ContentState) -> Color {
        if state.isEnded { return .green }
        return state.startDate == nil ? .orange : .white.opacity(0.62)
    }

    private func compactStatusIcon(for state: StudyActivityAttributes.ContentState) -> String {
        if state.isEnded { return "checkmark" }
        return state.startDate == nil ? "pause.fill" : "timer"
    }

    private func compactStatusColor(for state: StudyActivityAttributes.ContentState) -> Color {
        if state.isEnded { return .green }
        return state.startDate == nil ? .orange : .yellow
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: context.attributes.courseIcon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(.yellow, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.courseName)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(statusText(for: context.state))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(statusColor(for: context.state))
                    }

                    Spacer(minLength: 4)

                    LiveTimerText(
                        startDate: context.state.startDate,
                        accumulatedSeconds: context.state.accumulatedSeconds,
                        size: 30
                    )
                    .frame(minWidth: 84, alignment: .trailing)
                }

                if !context.attributes.isFocusModeActive && !context.state.isEnded {
                    HStack(spacing: 10) {
                        LiveIconButton(
                            systemName: context.state.startDate == nil ? "play.fill" : "pause.fill",
                            tint: context.state.startDate == nil ? .green : .yellow,
                            intent: TogglePauseIntent()
                        )

                        LiveIconButton(systemName: "stop.fill", tint: .red, intent: EndSessionIntent())
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .activityBackgroundTint(.black.opacity(0.9))
            .activitySystemActionForegroundColor(.yellow)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: context.attributes.courseIcon)
                            .font(.headline)
                            .foregroundStyle(.yellow)
                        Text(context.attributes.courseName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    LiveTimerText(
                        startDate: context.state.startDate,
                        accumulatedSeconds: context.state.accumulatedSeconds,
                        size: 22
                    )
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: 92, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if !context.attributes.isFocusModeActive && !context.state.isEnded {
                        HStack(spacing: 8) {
                            Button(intent: TogglePauseIntent()) {
                                Label(context.state.startDate == nil ? "Riprendi" : "Pausa", systemImage: context.state.startDate == nil ? "play.fill" : "pause.fill")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(context.state.startDate == nil ? .green : .yellow)

                            Button(intent: EndSessionIntent()) {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.red)
                        }
                        .padding(.top, 6)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.courseIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
            } compactTrailing: {
                Image(systemName: compactStatusIcon(for: context.state))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(compactStatusColor(for: context.state))
            } minimal: {
                Image(systemName: context.attributes.courseIcon)
                    .foregroundStyle(.yellow)
            }
            .widgetURL(URL(string: "studio://start/\(context.attributes.courseName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")"))
        }
    }
}
