//
//  StudioWatchComplication.swift
//  StudioWatchComplication
//
//  Created by Niccoló Pirronello on 19/06/2026.
//
//  Complicazioni ridisegnate: colori della materia attiva, gradienti,
//  gauge e grafico settimanale con il giorno corrente evidenziato.
//

import WidgetKit
import SwiftUI

// MARK: - DATI CONDIVISI
struct StudioComplicationEntry: TimelineEntry {
    let date: Date
    let sessionActive: Bool
    let courseName: String
    let courseIcon: String
    let courseColorName: String
    let startDate: Date
    let isPaused: Bool
    let pausedSeconds: Int
    let weeklyMinutes: [Int]

    var courseColor: Color { WatchPalette.color(from: courseColorName) }
    var todayMinutes: Int { weeklyMinutes.last ?? 0 }
    var bestDayMinutes: Int { max(weeklyMinutes.max() ?? 0, 1) }
    var totalWeekMinutes: Int { weeklyMinutes.reduce(0, +) }
}

struct StudioComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioComplicationEntry {
        StudioComplicationEntry(
            date: Date(), sessionActive: false,
            courseName: "Matematica", courseIcon: "function", courseColorName: "blue",
            startDate: Date(), isPaused: false, pausedSeconds: 0,
            weeklyMinutes: [20, 40, 10, 60, 30, 0, 50]
        )
    }
    func getSnapshot(in context: Context, completion: @escaping (StudioComplicationEntry) -> Void) {
        completion(currentEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioComplicationEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextUpdate)))
    }
    private func currentEntry() -> StudioComplicationEntry {
        let defaults = WatchSync.defaults
        let active = defaults?.bool(forKey: WatchSync.keySessionActive) ?? false
        let name = defaults?.string(forKey: WatchSync.keyCourseName) ?? ""
        let icon = defaults?.string(forKey: WatchSync.keyCourseIcon) ?? "book.fill"
        let colorName = defaults?.string(forKey: WatchSync.keyCourseColor) ?? "blue"
        let startInterval = defaults?.double(forKey: WatchSync.keyStartDate) ?? 0
        let start = startInterval > 0 ? Date(timeIntervalSince1970: startInterval) : Date()
        let isPaused = defaults?.bool(forKey: WatchSync.keyIsPaused) ?? false
        let pausedSeconds = defaults?.integer(forKey: WatchSync.keyPausedSeconds) ?? 0
        let weekly = defaults?.array(forKey: WatchSync.keyWeeklyMinutes) as? [Int] ?? Array(repeating: 0, count: 7)
        return StudioComplicationEntry(
            date: Date(), sessionActive: active,
            courseName: name, courseIcon: icon, courseColorName: colorName,
            startDate: start, isPaused: isPaused, pausedSeconds: pausedSeconds,
            weeklyMinutes: weekly
        )
    }
}

// MARK: - HELPERS CONDIVISI

private func formatShortMinutes(_ minutes: Int) -> String {
    let h = minutes / 60; let m = minutes % 60
    if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
    return "\(m)m"
}

/// Iniziali degli ultimi 7 giorni (il grafico termina con oggi).
private func lastSevenDayInitials() -> [String] {
    let cal = Calendar.current
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    return (0..<7).reversed().map { offset in
        guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return "" }
        let symbol = formatter.veryShortWeekdaySymbols[cal.component(.weekday, from: day) - 1]
        return symbol.uppercased()
    }
}

// MARK: - COMPLICAZIONE 1: TIMER SESSIONE

struct StudioTimerView: View {
    let entry: StudioComplicationEntry
    @Environment(\.widgetFamily) var family

    private var pausedTimeText: String {
        let h = entry.pausedSeconds / 3600
        let m = (entry.pausedSeconds % 3600) / 60
        let s = entry.pausedSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner:   corner
        case .accessoryInline:   inline
        default:                 rectangular
        }
    }

    // MARK: Rettangolare
    private var rectangular: some View {
        Group {
            if entry.sessionActive {
                HStack(spacing: 8) {
                    // Tile colorato con l'icona della materia
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(entry.courseColor.gradient)
                            .frame(width: 36, height: 36)
                        Image(systemName: entry.courseIcon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .widgetAccentable()

                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.courseName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entry.courseColor)
                            .lineLimit(1)

                        if entry.isPaused {
                            Text(pausedTimeText)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        } else {
                            Text(entry.startDate, style: .timer)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 3) {
                            Circle()
                                .fill(entry.isPaused ? Color.orange : Color.green)
                                .frame(width: 5, height: 5)
                            Text(entry.isPaused ? "In pausa" : "In corso")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.blue.gradient)
                            .frame(width: 36, height: 36)
                        Image(systemName: "book.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .widgetAccentable()

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Studio")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.cyan)
                        Text("Nessuna sessione")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Oggi: \(formatShortMinutes(entry.todayMinutes))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Circolare
    private var circular: some View {
        Group {
            if entry.sessionActive {
                ZStack {
                    AccessoryWidgetBackground()
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [entry.courseColor.opacity(0.35), entry.courseColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .padding(2)
                        .widgetAccentable()

                    VStack(spacing: 0) {
                        Image(systemName: entry.isPaused ? "pause.fill" : entry.courseIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(entry.courseColor)
                        if entry.isPaused {
                            Text(pausedTimeText)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.55)
                        } else {
                            Text(entry.startDate, style: .timer)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.55)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 5)
                }
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.cyan)
                            .widgetAccentable()
                        Text(formatShortMinutes(entry.todayMinutes))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Angolo
    private var corner: some View {
        Group {
            if entry.sessionActive {
                Image(systemName: entry.isPaused ? "pause.circle.fill" : entry.courseIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(entry.courseColor.gradient)
                    .symbolRenderingMode(.hierarchical)
                    .widgetAccentable()
                    .widgetLabel {
                        if entry.isPaused {
                            Text("\(entry.courseName) · \(pausedTimeText)")
                        } else {
                            Text(entry.startDate, style: .timer)
                                .monospacedDigit()
                        }
                    }
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.cyan.gradient)
                    .symbolRenderingMode(.hierarchical)
                    .widgetAccentable()
                    .widgetLabel {
                        Text("Oggi \(formatShortMinutes(entry.todayMinutes))")
                    }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Inline
    private var inline: some View {
        Group {
            if entry.sessionActive {
                if entry.isPaused {
                    Text("\(Image(systemName: "pause.fill")) \(entry.courseName) · \(pausedTimeText)")
                } else {
                    Text("\(Image(systemName: entry.courseIcon)) \(entry.courseName) \(entry.startDate, style: .timer)")
                }
            } else {
                Text("\(Image(systemName: "book.fill")) Oggi \(formatShortMinutes(entry.todayMinutes))")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioTimerWatchComplication: Widget {
    let kind = "StudioTimerWatchComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioComplicationProvider()) { entry in
            StudioTimerView(entry: entry)
        }
        .configurationDisplayName("Studio — Timer")
        .description("Timer live con icona e colore della materia in corso.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - COMPLICAZIONE 2: GRAFICO SETTIMANALE

struct StudioChartView: View {
    let entry: StudioComplicationEntry
    @Environment(\.widgetFamily) var family

    private var totalText: String { formatShortMinutes(entry.totalWeekMinutes) }

    /// Colore della barra: gradiente blu per i giorni passati, colore pieno per oggi.
    private func barStyle(index: Int) -> LinearGradient {
        let isToday = index == entry.weeklyMinutes.count - 1
        if isToday {
            return LinearGradient(colors: [.cyan, .mint], startPoint: .bottom, endPoint: .top)
        }
        return LinearGradient(colors: [.blue.opacity(0.75), .blue.opacity(0.45)], startPoint: .bottom, endPoint: .top)
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner:   corner
        case .accessoryInline:   inline
        default:                 rectangular
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Settimana")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
                Spacer()
                Text(totalText)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            let dayLabels = lastSevenDayInitials()
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(entry.weeklyMinutes.enumerated()), id: \.offset) { index, minutes in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(barStyle(index: index))
                            .frame(height: max(3, CGFloat(minutes) / CGFloat(entry.bestDayMinutes) * 26))
                            .widgetAccentable()
                        Text(index < dayLabels.count ? dayLabels[index] : "")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(index == entry.weeklyMinutes.count - 1 ? .cyan : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 38, alignment: .bottom)
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var circular: some View {
        Gauge(value: Double(entry.todayMinutes), in: 0...Double(entry.bestDayMinutes)) {
            Image(systemName: "book.fill")
        } currentValueLabel: {
            VStack(spacing: -1) {
                Text(formatShortMinutes(entry.todayMinutes))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text("oggi")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.blue, .cyan, .mint]))
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }

    private var corner: some View {
        Text(formatShortMinutes(entry.todayMinutes))
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.cyan.gradient)
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: Double(entry.todayMinutes), in: 0...Double(entry.bestDayMinutes)) {
                    Text("Oggi")
                }
                .tint(Gradient(colors: [.blue, .cyan, .mint]))
            }
            .containerBackground(for: .widget) { Color.clear }
    }

    private var inline: some View {
        Text("\(Image(systemName: "chart.bar.fill")) Settimana: \(totalText)")
            .containerBackground(for: .widget) { Color.clear }
    }
}

struct StudioChartWatchComplication: Widget {
    let kind = "StudioChartWatchComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioComplicationProvider()) { entry in
            StudioChartView(entry: entry)
        }
        .configurationDisplayName("Studio — Grafico")
        .description("Gli ultimi 7 giorni di studio, con oggi in evidenza.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}
