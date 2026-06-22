//
//  StudioWeeklyWidget.swift
//  studio
//
//  Created by Niccolo Pirronello on 20/06/2026.
//

import WidgetKit
import SwiftUI

struct StudioWeeklyEntry: TimelineEntry {
    let date: Date
    let weeklyMinutes: [Int]
}

struct StudioWeeklyProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudioWeeklyEntry {
        StudioWeeklyEntry(date: Date(), weeklyMinutes: [30, 45, 0, 60, 20, 90, 15])
    }

    func getSnapshot(in context: Context, completion: @escaping (StudioWeeklyEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudioWeeklyEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(next)))
    }

    private func currentEntry() -> StudioWeeklyEntry {
        let defaults = UserDefaults(suiteName: "group.studioso")
        let source = defaults?.array(forKey: "weeklyMinutesByDay") as? [Int] ?? []
        let weekly: [Int]
        if source.count == 7 {
            weekly = source
        } else if source.count > 7 {
            weekly = Array(source.suffix(7))
        } else {
            weekly = Array(repeating: 0, count: 7 - source.count) + source
        }
        return StudioWeeklyEntry(date: Date(), weeklyMinutes: weekly)
    }
}

struct StudioWeeklyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudioWeeklyEntry
    private let dayLabels = ["L", "M", "M", "G", "V", "S", "D"]

    private var total: Int { entry.weeklyMinutes.reduce(0, +) }
    private var average: Int { entry.weeklyMinutes.isEmpty ? 0 : total / entry.weeklyMinutes.count }
    private var maxMinutes: Int { max(entry.weeklyMinutes.max() ?? 0, 1) }

    var body: some View {
        Group {
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            Text(format(minutes: total))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            WeeklyBars(values: entry.weeklyMinutes, labels: dayLabels, maxValue: maxMinutes, tint: .blue)
                .frame(height: 64)
            metricRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var mediumLayout: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    titleRow
                    Text(format(minutes: total))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Media")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(shortFormat(minutes: average))
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
            }

            HStack(spacing: 16) {
                WeeklyBars(values: entry.weeklyMinutes, labels: dayLabels, maxValue: maxMinutes, tint: .blue)
                    .frame(maxWidth: .infinity)
                WeeklySparkline(values: entry.weeklyMinutes.map(Double.init), maxValue: Double(maxMinutes), tint: .green)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 72)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(.blue)
            Text("Andamento")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var metricRow: some View {
        HStack {
            Text("Media")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(shortFormat(minutes: average))
                .font(.caption.weight(.bold))
                .monospacedDigit()
        }
    }

    private func format(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m)"
    }

    private func shortFormat(minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

private struct WeeklyBars: View {
    let values: [Int]
    let labels: [String]
    let maxValue: Int
    let tint: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        let height = max(4, proxy.size.height * CGFloat(value) / CGFloat(maxValue))
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(tint.gradient)
                                .frame(height: height)
                        }
                    }
                    Text(labels[index])
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct WeeklySparkline: View {
    let values: [Double]
    let maxValue: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .position(point)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let width = max(1, size.width)
        let height = max(1, size.height)
        return values.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(values.count - 1) * width
            let y = height - (CGFloat(value / max(maxValue, 1)) * (height - 8)) - 4
            return CGPoint(x: x, y: y)
        }
    }
}

struct StudioWeeklyWidget: Widget {
    let kind = "StudioWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StudioWeeklyProvider()) { entry in
            StudioWeeklyWidgetView(entry: entry)
        }
        .configurationDisplayName("Studio - Andamento")
        .description("Barre e trend degli ultimi 7 giorni di studio.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
