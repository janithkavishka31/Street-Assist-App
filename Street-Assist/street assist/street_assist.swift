//
//  street_assist.swift
//  street assist
//
//  Created by COBSCCOMP242P-050 on 2026-05-05.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            totalPoints: 120,
            streakDays: 5,
            updatedAt: Date().addingTimeInterval(-300)
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = makeEntry(for: configuration)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func makeEntry(for configuration: ConfigurationAppIntent) -> SimpleEntry {
        let defaults = UserDefaults(suiteName: WidgetDataStore.appGroupSuite)
        let totalPoints = defaults?.integer(forKey: WidgetDataStore.Key.totalPoints) ?? 0
        let streakDays = min(max(defaults?.integer(forKey: WidgetDataStore.Key.streakDays) ?? 0, 0), 7)

        var updatedAt = Date()
        if let interval = defaults?.double(forKey: WidgetDataStore.Key.updatedAt), interval > 0 {
            updatedAt = Date(timeIntervalSince1970: interval)
        }

        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            totalPoints: totalPoints,
            streakDays: streakDays,
            updatedAt: updatedAt
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let totalPoints: Int
    let streakDays: Int
    let updatedAt: Date
}

struct street_assistEntryView : View {
    var entry: Provider.Entry

    private var streakProgress: Double {
        Double(entry.streakDays) / 7.0
    }

    private var updatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: entry.updatedAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: streakProgress)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(entry.streakDays)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("/7")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(width: 66, height: 66)

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Points")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(entry.totalPoints)")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 0)

            Text("Updated \(updatedText)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(14)
        .containerBackground(
            LinearGradient(
                colors: [Color(red: 0.22, green: 0.46, blue: 0.98), Color(red: 0.15, green: 0.71, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            for: .widget
        )
    }
}

struct street_assist: Widget {
    let kind: String = "street_assist"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            street_assistEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private enum WidgetDataStore {
    static let appGroupSuite = "group.streetassist"

    enum Key {
        static let totalPoints = "widget.total_points"
        static let streakDays = "widget.streak_days"
        static let updatedAt = "widget.updated_at"
    }
}

#Preview(as: .systemSmall) {
    street_assist()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        totalPoints: 120,
        streakDays: 5,
        updatedAt: Date().addingTimeInterval(-420)
    )
}
