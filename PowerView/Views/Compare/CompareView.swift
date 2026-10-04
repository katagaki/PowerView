import Charts
import SwiftUI

/// Two days side by side: battery curves on one chart, then the numbers, components and apps.
struct CompareView: View {
    let report: PowerReport
    @State private var first: Int
    @State private var second: Int
    @State private var alignment = Alignment.sinceUnplugged

    enum Alignment: String, CaseIterable, Identifiable {
        case sinceUnplugged = "Since Unplugged"
        case timeOfDay = "Time of Day"
        var id: Self { self }
    }

    private static let firstColor = Color.blue
    private static let secondColor = Color.orange

    init(report: PowerReport, initialDay: Int) {
        self.report = report
        _first = State(initialValue: initialDay)
        // Default to the nearest other full day that mostly ran on battery, so the curves are worth comparing.
        let full = report.days.indices.filter { $0 != initialDay && !report.days[$0].partial }
        let onBattery = full.filter { report.days[$0].stats.hoursOnBattery >= 6 }
        let candidates = onBattery.isEmpty ? full : onBattery
        _second = State(initialValue: candidates.min { abs($0 - initialDay) < abs($1 - initialDay) } ?? max(0, initialDay - 1))
    }

    private var dayA: DayReport { report.days[first] }
    private var dayB: DayReport { report.days[second] }
    private var labelA: String { Format.shortDate(dayA) }
    private var labelB: String { labelA == Format.shortDate(dayB) ? "\(Format.shortDate(dayB)) " : Format.shortDate(dayB) }

    var body: some View {
        List {
            Section {
                dayPicker("First Day", selection: $first, color: Self.firstColor)
                dayPicker("Second Day", selection: $second, color: Self.secondColor)
            }

            Section {
                Picker("Align", selection: $alignment) {
                    ForEach(Alignment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                curveChart
                    .frame(height: 240)
                    .padding(.vertical, 8)
            } header: {
                Text("Battery Level")
            } footer: {
                Text(alignment == .sinceUnplugged
                     ? "Each day starts from the beginning of its longest stretch on battery, so tests started at different times line up."
                     : "Both days on the same 24-hour clock.")
            }

            metricsSection
            componentsSection
            appsSection
        }
        .navigationTitle("Compare Days")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: first)
        .animation(.default, value: second)
        .animation(.default, value: alignment)
    }

    private func dayPicker(_ title: String, selection: Binding<Int>, color: Color) -> some View {
        Picker(selection: selection) {
            ForEach(report.days.indices.reversed(), id: \.self) { index in
                let day = report.days[index]
                Text("\(Format.shortDate(day)) · \(Int(day.stats.used.rounded()))% used")
                    .tag(index)
            }
        } label: {
            Label {
                Text(title)
            } icon: {
                Circle().fill(color).frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - Battery curves

    private struct CurvePoint: Identifiable {
        let id: String
        let day: String
        let hour: Double
        let level: Int
        let segment: Int
    }

    /// The start of the longest run of on-battery samples, in hours since midnight.
    private func unplugHour(_ day: DayReport) -> Double {
        var best = (start: day.battery.first?.hour ?? 0, length: 0.0)
        var runStart: Double?
        for (index, sample) in day.battery.enumerated() {
            let continues = index > 0 && sample.hour - day.battery[index - 1].hour < 0.5 && !day.battery[index - 1].charging
            if sample.charging { runStart = nil; continue }
            if runStart == nil || !continues { runStart = sample.hour }
            if let runStart, sample.hour - runStart > best.length { best = (runStart, sample.hour - runStart) }
        }
        return best.start
    }

    private func points(for day: DayReport, label: String) -> [CurvePoint] {
        let offset = alignment == .sinceUnplugged ? unplugHour(day) : 0
        var segment = 0
        var previous: Double?
        return day.battery.enumerated().compactMap { index, sample in
            guard sample.hour >= offset else { return nil }
            if let previous, sample.hour - previous >= 0.5 { segment += 1 }
            previous = sample.hour
            return CurvePoint(id: "\(label)-\(index)", day: label, hour: sample.hour - offset, level: sample.level, segment: segment)
        }
    }

    private var curveChart: some View {
        let all = points(for: dayA, label: labelA) + points(for: dayB, label: labelB)
        return Chart(all) { point in
            LineMark(x: .value("Hour", point.hour), y: .value("Level", point.level),
                     series: .value("Series", "\(point.day)-\(point.segment)"))
                .foregroundStyle(by: .value("Day", point.day))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .chartForegroundStyleScale([labelA: Self.firstColor, labelB: Self.secondColor])
        .chartLegend(position: .top, alignment: .leading)
        .chartXScale(domain: 0...24)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                AxisGridLine()
                AxisValueLabel {
                    let hour = value.as(Double.self) ?? 0
                    Text(alignment == .timeOfDay ? Format.clock(hour) : "\(Int(hour)) h")
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
            }
        }
    }

    // MARK: - Numbers

    private struct Metric: Identifiable {
        let name: String
        let a: Double?
        let b: Double?
        let format: (Double) -> String
        /// Whether a lower value is the better one, for highlighting. Nil means neither is better.
        let lowerIsBetter: Bool?
        var id: String { name }
    }

    private var metrics: [Metric] {
        func rate(_ value: Double) -> String { String(format: "%.1f%%/h", value) }
        func hours(_ value: Double) -> String { String(format: "%.1f h", value) }
        let drainA = dayA.drain, drainB = dayB.drain
        let peakA = dayA.temperature?.bins.map(\.maximum).max(), peakB = dayB.temperature?.bins.map(\.maximum).max()
        func averageNits(_ day: DayReport) -> Double? {
            day.brightness.map { $0.map(\.nits).reduce(0, +) / Double(max(1, $0.count)) }
        }
        return [
            Metric(name: "Battery Used", a: dayA.stats.used, b: dayB.stats.used, format: { "\(Int($0.rounded()))%" }, lowerIsBetter: nil),
            Metric(name: "Time on Battery", a: dayA.stats.hoursOnBattery, b: dayB.stats.hoursOnBattery, format: hours, lowerIsBetter: nil),
            Metric(name: "Screen On", a: dayA.screenOnSeconds.map { $0 / 3600 }, b: dayB.screenOnSeconds.map { $0 / 3600 }, format: hours, lowerIsBetter: nil),
            Metric(name: "Screen-Off Drain", a: drainA?.screenOffPerHour, b: drainB?.screenOffPerHour, format: rate, lowerIsBetter: true),
            Metric(name: "Screen-On Drain", a: drainA?.screenOnPerHour, b: drainB?.screenOnPerHour, format: rate, lowerIsBetter: true),
            Metric(name: "Full Charge at Pace", a: drainA?.fullChargeHours, b: drainB?.fullChargeHours, format: hours, lowerIsBetter: false),
            Metric(name: "Always-On Display", a: dayA.alwaysOnSeconds.map { $0 / 3600 }, b: dayB.alwaysOnSeconds.map { $0 / 3600 },
                   format: { $0 > 0 ? hours($0) : "Off" }, lowerIsBetter: true),
            Metric(name: "Energy Used", a: dayA.energyWh, b: dayB.energyWh, format: { String(format: "%.1f Wh", $0) }, lowerIsBetter: nil),
            Metric(name: "Display-Off Energy", a: dayA.backgroundShare.map { $0 * 100 }, b: dayB.backgroundShare.map { $0 * 100 },
                   format: { "\(Int($0.rounded()))%" }, lowerIsBetter: true),
            Metric(name: "Push over Wi-Fi", a: dayA.hourly?.wifiShare.map { $0 * 100 }, b: dayB.hourly?.wifiShare.map { $0 * 100 },
                   format: { "\(Int($0.rounded()))%" }, lowerIsBetter: nil),
            Metric(name: "Notifications", a: dayA.notifications.map { Double($0.reduce(0) { $0 + $1.count }) },
                   b: dayB.notifications.map { Double($0.reduce(0) { $0 + $1.count }) }, format: { "\(Int($0))" }, lowerIsBetter: true),
            Metric(name: "Wakes from Sleep", a: dayA.wakes.map { Double($0.total) }, b: dayB.wakes.map { Double($0.total) },
                   format: { "\(Int($0))" }, lowerIsBetter: true),
            Metric(name: "Peak Temperature", a: peakA, b: peakB, format: { String(format: "%.1f °C", $0) }, lowerIsBetter: true),
            Metric(name: "Average Brightness", a: averageNits(dayA), b: averageNits(dayB), format: { "\(Int($0)) nits" }, lowerIsBetter: nil)
        ].filter { $0.a != nil || $0.b != nil }
    }

    private var metricsSection: some View {
        Section {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("")
                    Text(labelA).foregroundStyle(Self.firstColor).gridColumnAlignment(.trailing)
                    Text(labelB).foregroundStyle(Self.secondColor).gridColumnAlignment(.trailing)
                }
                .font(.caption.weight(.semibold))
                ForEach(metrics) { metric in
                    Divider()
                    GridRow {
                        Text(metric.name)
                            .font(.subheadline)
                        value(metric.a, metric: metric, other: metric.b)
                        value(metric.b, metric: metric, other: metric.a)
                    }
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Side by Side")
        } footer: {
            Text("Green marks the better value where one is clearly better.")
        }
    }

    private func value(_ value: Double?, metric: Metric, other: Double?) -> some View {
        let isBetter: Bool = {
            guard let value, let other, let lower = metric.lowerIsBetter, abs(value - other) > max(abs(value), abs(other)) * 0.05 else { return false }
            return lower ? value < other : value > other
        }()
        return Text(value.map(metric.format) ?? "—")
            .font(.subheadline.weight(isBetter ? .semibold : .regular))
            .foregroundStyle(isBetter ? .green : .primary)
            .monospacedDigit()
    }

    // MARK: - Components and apps

    private struct Bar: Identifiable {
        let id: String
        let category: String
        let day: String
        let value: Double
    }

    @ViewBuilder
    private var componentsSection: some View {
        let bars = (dayA.components ?? []).map { Bar(id: "a-\($0.name)", category: $0.name, day: labelA, value: $0.wh) }
            + (dayB.components ?? []).map { Bar(id: "b-\($0.name)", category: $0.name, day: labelB, value: $0.wh) }
        if !bars.isEmpty {
            Section("Energy by Component") {
                groupedChart(bars, unit: "Wh", categories: (dayA.components ?? dayB.components ?? []).map(\.name))
            }
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        let appsA = dayA.apps ?? [], appsB = dayB.apps ?? []
        let ids = topAppIDs(appsA, appsB)
        let names = Dictionary((appsA + appsB).map { ($0.bundleID, $0.name) }, uniquingKeysWith: { first, _ in first })
        let bars = ids.flatMap { id in
            [Bar(id: "a-\(id)", category: names[id] ?? id, day: labelA, value: Double(appsA.first { $0.bundleID == id }?.total ?? 0) / 1000),
             Bar(id: "b-\(id)", category: names[id] ?? id, day: labelB, value: Double(appsB.first { $0.bundleID == id }?.total ?? 0) / 1000)]
        }
        if !bars.isEmpty {
            Section {
                groupedChart(bars, unit: "Wh", categories: ids.map { names[$0] ?? $0 })
            } header: {
                Text("Top Apps & Processes")
            } footer: {
                Text("The biggest consumers on either day, with total energy on screen and in the background.")
            }
        }
    }

    /// The six biggest consumers from each day, biggest first, without duplicates.
    private func topAppIDs(_ appsA: [AppEnergy], _ appsB: [AppEnergy]) -> [String] {
        var ids: [String] = []
        for app in (appsA.prefix(6) + appsB.prefix(6)).sorted(by: { $0.total > $1.total }) where !ids.contains(app.bundleID) {
            ids.append(app.bundleID)
        }
        return ids
    }

    private func groupedChart(_ bars: [Bar], unit: String, categories: [String]) -> some View {
        Chart(bars) { bar in
            BarMark(x: .value("Energy", bar.value), y: .value("Category", bar.category))
                .foregroundStyle(by: .value("Day", bar.day))
                .position(by: .value("Day", bar.day))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale([labelA: Self.firstColor, labelB: Self.secondColor])
        .chartLegend(position: .top, alignment: .leading)
        .chartYScale(domain: categories)
        .chartYAxis { AxisMarks { _ in AxisValueLabel(horizontalSpacing: 8) } }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Double.self) ?? 0, format: .number.precision(.fractionLength(0...1))) \(unit)") }
            }
        }
        .frame(height: CGFloat(categories.count) * 44 + 40)
        .padding(.vertical, 8)
    }
}
