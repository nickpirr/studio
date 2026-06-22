///
//  widgetstudio.swift
//  widgetstudio
//
//  Created by Niccolo Pirronello on 20/05/26.
//
import Foundation
import WidgetKit
import SwiftUI
import Charts

struct Presets {
    static let colorNames: [String] = [
        "blue", "brown", "gray", "green", "indigo", "orange",
        "red", "purple", "pink", "cyan", "mint", "teal"
    ]

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

    static func name(from color: Color) -> String {
        switch color {
        case .blue:   return "blue"
        case .brown:  return "brown"
        case .gray:   return "gray"
        case .green:  return "green"
        case .indigo: return "indigo"
        case .orange: return "orange"
        case .red:    return "red"
        case .purple: return "purple"
        case .pink:   return "pink"
        case .cyan:   return "cyan"
        case .mint:   return "mint"
        case .teal:   return "teal"
        default:      return "blue"
        }
    }
}

private struct AppleWidgetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private extension View {
    func appleWidgetBackground() -> some View {
        modifier(AppleWidgetBackground())
    }
}

private func widgetFormat(minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m) min" }
    if m == 0 { return "\(h) h" }
    return "\(h) h \(m)"
}

private func shortWidgetFormat(minutes: Int) -> String {
    minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

private struct TodayStudyEntry: TimelineEntry {
    let date: Date
    let todayMinutes: Int
    let weekTotalMinutes: Int
    let bestDayMinutes: Int
}

private struct TodayStudyProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayStudyEntry {
        TodayStudyEntry(date: Date(), todayMinutes: 95, weekTotalMinutes: 420, bestDayMinutes: 130)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayStudyEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayStudyEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> TodayStudyEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        return TodayStudyEntry(
            date: Date(),
            todayMinutes: defaults?.integer(forKey: "widgetTodayMinutes") ?? 0,
            weekTotalMinutes: defaults?.integer(forKey: "widgetWeekTotalMinutes") ?? 0,
            bestDayMinutes: defaults?.integer(forKey: "widgetBestDayMinutes") ?? 0
        )
    }
}

private struct TodayStudyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayStudyEntry

    private var progress: Double {
        guard entry.bestDayMinutes > 0 else { return 0 }
        return min(1, Double(entry.todayMinutes) / Double(entry.bestDayMinutes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text("Oggi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(widgetFormat(minutes: entry.todayMinutes))
                .font(.system(size: family == .systemSmall ? 34 : 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            ProgressView(value: progress)
                .tint(.blue)

            if family != .systemSmall {
                HStack(spacing: 18) {
                    metric("Settimana", entry.weekTotalMinutes)
                    metric("Miglior giorno", entry.bestDayMinutes)
                }
            } else {
                metric("Settimana", entry.weekTotalMinutes)
            }
        }
        .padding(14)
        .appleWidgetBackground()
    }

    private func metric(_ title: String, _ minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(shortWidgetFormat(minutes: minutes))
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
    }
}

struct widgetstudio: Widget {
    let kind: String = "widgetstudio"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayStudyProvider()) { entry in
            TodayStudyWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio - Oggi")
        .description("Minuti studiati oggi con riepilogo essenziale.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct GradeWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetGradeSummary
}

private struct GradeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GradeWidgetEntry {
        GradeWidgetEntry(
            date: Date(),
            summary: WidgetGradeSummary(
                averageEffort: 7.5,
                averageConcentration: 8.1,
                averageSatisfaction: 7.2,
                dailyPoints: [
                    WidgetGradePoint(dayIndex: 0, effort: 7, concentration: 8, satisfaction: 6),
                    WidgetGradePoint(dayIndex: 1, effort: 8, concentration: 8, satisfaction: 7),
                    WidgetGradePoint(dayIndex: 2, effort: 0, concentration: 0, satisfaction: 0),
                    WidgetGradePoint(dayIndex: 3, effort: 8, concentration: 9, satisfaction: 8),
                    WidgetGradePoint(dayIndex: 4, effort: 6, concentration: 7, satisfaction: 7),
                    WidgetGradePoint(dayIndex: 5, effort: 9, concentration: 8, satisfaction: 8),
                    WidgetGradePoint(dayIndex: 6, effort: 7, concentration: 8, satisfaction: 7)
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GradeWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GradeWidgetEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> GradeWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        if let data = defaults?.data(forKey: "widgetGradeSummaryThisWeek"),
           let summary = try? JSONDecoder().decode(WidgetGradeSummary.self, from: data) {
            return GradeWidgetEntry(date: Date(), summary: summary)
        }
        return GradeWidgetEntry(
            date: Date(),
            summary: WidgetGradeSummary(averageEffort: 0, averageConcentration: 0, averageSatisfaction: 0, dailyPoints: [])
        )
    }
}

private struct GradeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GradeWidgetEntry

    private var overall: Double {
        let values = [entry.summary.averageEffort, entry.summary.averageConcentration, entry.summary.averageSatisfaction].filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        Group {
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .appleWidgetBackground()
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            scoreText(size: 36)
            GradeBars(points: normalizedPoints, tint: .green)
                .frame(height: 52)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                titleRow
                scoreText(size: 42)
                HStack(spacing: 12) {
                    gradeMetric("Imp.", entry.summary.averageEffort, .mint)
                    gradeMetric("Conc.", entry.summary.averageConcentration, .orange)
                    gradeMetric("Sodd.", entry.summary.averageSatisfaction, .blue)
                }
            }
            .frame(width: 128, alignment: .leading)

            GradeBars(points: normalizedPoints, tint: .green)
                .frame(maxWidth: .infinity)
                .frame(height: 88)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            Text("Voti")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func scoreText(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(overall > 0 ? String(format: "%.1f", overall) : "--")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("/10")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private var normalizedPoints: [Double] {
        let points = entry.summary.dailyPoints.map(\.overall)
        return points.count == 7 ? points : Array(repeating: 0, count: max(0, 7 - points.count)) + points.suffix(7)
    }

    private func gradeMetric(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value > 0 ? String(format: "%.1f", value) : "--")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

private struct GradeBars: View {
    let points: [Double]
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, value in
                GeometryReader { proxy in
                    let ratio = min(1, max(0, value / 10))
                    let height = max(5, proxy.size.height * CGFloat(ratio))
                    VStack {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(value > 0 ? tint.gradient : Color.secondary.opacity(0.16).gradient)
                            .frame(height: height)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct StudioGradesWidget: Widget {
    let kind = "StudioGradesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GradeWidgetProvider()) { entry in
            GradeWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio - Voti")
        .description("Andamento di impegno, concentrazione e soddisfazione.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct CourseMixEntry: TimelineEntry {
    let date: Date
    let stats: [WidgetCourseStat]
    let totalMinutes: Int
}

private struct CourseMixProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseMixEntry {
        let stats = [
            WidgetCourseStat(name: "Matematica", icon: "function", colorName: "blue", minutes: 160),
            WidgetCourseStat(name: "Storia", icon: "book.closed.fill", colorName: "orange", minutes: 95),
            WidgetCourseStat(name: "Fisica", icon: "atom", colorName: "green", minutes: 70)
        ]
        return CourseMixEntry(date: Date(), stats: stats, totalMinutes: stats.reduce(0) { $0 + $1.minutes })
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseMixEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseMixEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> CourseMixEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        let stats: [WidgetCourseStat]
        if let data = defaults?.data(forKey: "widgetCourseStatsThisWeek"),
           let decoded = try? JSONDecoder().decode([WidgetCourseStat].self, from: data) {
            stats = decoded
        } else {
            stats = []
        }
        return CourseMixEntry(date: Date(), stats: stats, totalMinutes: stats.reduce(0) { $0 + $1.minutes })
    }
}

private struct CourseMixWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CourseMixEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.purple)
                Text("Materie")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if entry.stats.isEmpty {
                Spacer(minLength: 0)
                Text("Nessuna materia questa settimana")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            } else {
                if family != .systemSmall {
                    shareBar
                }
                courseRows(limit: family == .systemSmall ? 3 : 4)
            }
        }
        .padding(14)
        .appleWidgetBackground()
    }

    private var shareBar: some View {
        HStack(spacing: 4) {
            ForEach(entry.stats.prefix(5)) { stat in
                Capsule()
                    .fill(Presets.color(from: stat.colorName))
                    .frame(maxWidth: shareWidth(for: stat))
            }
        }
        .frame(height: 10)
    }

    private func courseRows(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.stats.prefix(limit)) { stat in
                HStack(spacing: 8) {
                    Image(systemName: stat.icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Presets.color(from: stat.colorName), in: Circle())
                    Text(stat.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(shortWidgetFormat(minutes: stat.minutes))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private func shareWidth(for stat: WidgetCourseStat) -> CGFloat? {
        guard entry.totalMinutes > 0 else { return nil }
        return max(18, CGFloat(stat.minutes) / CGFloat(entry.totalMinutes) * 160)
    }
}

struct StudioCourseMixWidget: Widget {
    let kind = "StudioCourseMixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseMixProvider()) { entry in
            CourseMixWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio - Materie")
        .description("Ripartizione del tempo per materia questa settimana.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
