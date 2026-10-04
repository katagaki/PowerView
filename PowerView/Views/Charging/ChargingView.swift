import Charts
import SwiftUI

/// Charging habits across every day in the sysdiagnose.
struct ChargingView: View {
    let report: PowerReport

    private var sessions: [ChargingSession] { report.charging ?? [] }
    private var timeZone: TimeZone { report.meta.timeZone }

    /// Session pieces split at midnight, for the calendar chart.
    private struct Segment: Identifiable {
        let id: Int
        let day: String
        let start: Double
        let end: Double
        let style: String
    }

    private var segments: [Segment] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var out: [Segment] = []
        for session in sessions {
            var start = session.start
            while start < session.end {
                let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: start))!
                let end = min(session.end, nextMidnight)
                out.append(Segment(id: out.count, day: Format.dayKey(start, in: timeZone),
                                   start: Format.hourOfDay(start, in: timeZone),
                                   end: end == nextMidnight ? 24 : Format.hourOfDay(end, in: timeZone),
                                   style: session.isWireless.map { $0 ? "Wireless" : "Wired" } ?? "Charger Unknown"))
                start = end
            }
        }
        return out
    }

    private var overnight: [ChargingSession] {
        sessions.filter { session in
            let hour = Format.hourOfDay(session.start, in: timeZone)
            return (hour >= 20 || hour < 5) && session.duration >= 3 * 3600
        }
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                ContentUnavailableView("No Charging History", systemImage: "bolt.slash",
                                       description: Text("The power log in this sysdiagnose didn't record any charging sessions."))
            } else {
                summary
                calendarSection
                startLevelSection
                Section {
                    ForEach(sessions.reversed()) { session in
                        SessionRow(session: session, timeZone: timeZone)
                    }
                } header: {
                    Text("Sessions")
                } footer: {
                    Text("Charger details are only kept for the last few days.")
                }
            }
        }
        .navigationTitle("Charging Habits")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var summary: some View {
        let days = max(1, report.days.count)
        let totalHours = sessions.reduce(0) { $0 + $1.duration } / 3600
        let fullHours = Double(sessions.reduce(0) { $0 + $1.minutesAtFull }) / 60
        let startLevels = sessions.compactMap(\.startLevel), endLevels = sessions.compactMap(\.endLevel)
        let topUps = sessions.filter { $0.duration < 30 * 60 }.count
        let maxWatts = sessions.compactMap(\.watts).max()
        return Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                tile("Sessions", "bolt.fill", .green, "\(sessions.count)", "", "\(topUps) under 30 min")
                tile("Plugged In", "powerplug.portrait.fill", .green, String(format: "%.1f", totalHours / Double(days)), "h/day",
                     String(format: "%.0f h in total", totalHours))
                tile("Typical Range", "battery.75percent", .blue,
                     "\(average(startLevels))→\(average(endLevels))", "%", "Average start and end level")
                tile("Held at 100%", "battery.100percent", .orange, String(format: "%.1f", fullHours), "h",
                     totalHours > 0 ? "\(Int((fullHours / totalHours * 100).rounded()))% of plugged-in time" : nil)
                tile("Overnight", "moon.zzz.fill", .indigo, "\(overnight.count)", "", "Sessions of 3 h or more starting at night")
                tile("Fastest Charger", "bolt.badge.clock.fill", .yellow, maxWatts.map(String.init) ?? "—", maxWatts == nil ? "" : "W",
                     maxWatts == nil ? "Not recorded" : wirelessSummary)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            Text("Keeping a battery at 100% for hours, especially when it's warm, ages it faster. Optimized Charging or an 80% limit in Settings › Battery › Charging reduces this.")
        }
    }

    private var wirelessSummary: String {
        let known = sessions.compactMap(\.isWireless)
        let wireless = known.filter { $0 }.count
        return "\(wireless) wireless · \(known.count - wireless) wired"
    }

    private func average(_ values: [Int]) -> String {
        values.isEmpty ? "—" : "\(values.reduce(0, +) / values.count)"
    }

    private func tile(_ title: String, _ image: String, _ tint: Color, _ value: String, _ unit: String, _ detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: image)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            Text(detail ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Charts

    private var calendarSection: some View {
        let byDay = Dictionary(grouping: segments, by: \.day)
        return Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 14) {
                    legendItem("Wired", .green)
                    legendItem("Wireless", .teal)
                    legendItem("Charger Unknown", Self.unknownColor)
                }
                .padding(.bottom, 6)
                ForEach(report.days.reversed()) { day in
                    HStack(spacing: 8) {
                        Text(Format.shortDate(day))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: Self.labelWidth, alignment: .leading)
                        CalendarRow(segments: byDay[day.date] ?? [])
                    }
                    .frame(height: 16)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(rowLabel(day, segments: byDay[day.date] ?? []))
                }
                HStack(spacing: 8) {
                    Color.clear.frame(width: Self.labelWidth, height: 1)
                    GeometryReader { proxy in
                        ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                            Text(Format.clock(Double(hour)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .position(x: proxy.size.width * Double(hour) / 24, y: 8)
                        }
                    }
                    .frame(height: 16)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 8)
        } header: {
            Text("When You Charge")
        }
    }

    private static let labelWidth: CGFloat = 76
    fileprivate static let unknownColor = Color.green.opacity(0.55)

    private func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func rowLabel(_ day: DayReport, segments: [Segment]) -> String {
        guard !segments.isEmpty else { return "\(Format.longDate(day)): no charging" }
        let ranges = segments.map { "\(Format.clock($0.start)) to \(Format.clock($0.end))" }.joined(separator: ", ")
        return "\(Format.longDate(day)): charged \(ranges)"
    }

    /// One day of the charging calendar: a faint track with a bar per charging period.
    private struct CalendarRow: View {
        let segments: [Segment]

        var body: some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 4)
                    ForEach(segments) { segment in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(segment.style))
                            .frame(width: max(2, width * (segment.end - segment.start) / 24), height: 12)
                            .offset(x: width * segment.start / 24)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }

        private func color(_ style: String) -> Color {
            switch style {
            case "Wired": .green
            case "Wireless": .teal
            default: ChargingView.unknownColor
            }
        }
    }

    private var startLevelSection: some View {
        let buckets = ["0–19%", "20–39%", "40–59%", "60–79%", "80–100%"]
        let counts = buckets.indices.map { index in
            sessions.filter { session in
                guard let level = session.startLevel, session.duration >= 10 * 60 else { return false }
                return min(4, level / 20) == index
            }.count
        }
        return Section {
            Chart(buckets.indices, id: \.self) { index in
                BarMark(x: .value("Starting Level", buckets[index]), y: .value("Sessions", counts[index]))
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(counts[index])")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYAxis(.hidden)
            .frame(height: 160)
            .padding(.vertical, 8)
        } header: {
            Text("Battery Level When Plugged In")
        } footer: {
            Text("Sessions of 10 minutes or more.")
        }
    }
}
