import Charts
import SwiftUI

struct BatteryChartView: View {
    let day: DayReport
    @State private var selectedHour: Double?

    private struct Point: Identifiable {
        let id: Int
        let sample: BatterySample
        let segment: Int
    }

    /// Splits the line where samples are more than 30 minutes apart, so gaps aren't drawn as straight lines.
    private var points: [Point] {
        var segment = 0
        return day.battery.enumerated().map { index, sample in
            if index > 0, sample.hour - day.battery[index - 1].hour >= 0.5 { segment += 1 }
            return Point(id: index, sample: sample, segment: segment)
        }
    }

    private var chargingBands: [HourRange] {
        var bands: [HourRange] = []
        var start: Double?
        for (index, sample) in day.battery.enumerated() {
            if sample.charging && start == nil { start = sample.hour }
            if let begin = start, !sample.charging || index == day.battery.count - 1 {
                bands.append(HourRange(start: begin, end: sample.hour))
                start = nil
            }
        }
        return bands
    }

    private var selected: BatterySample? {
        guard let selectedHour else { return nil }
        let nearest = day.battery.min { abs($0.hour - selectedHour) < abs($1.hour - selectedHour) }
        return nearest.flatMap { abs($0.hour - selectedHour) <= 0.5 ? $0 : nil }
    }

    private var hasScreenBar: Bool { day.detail != nil }

    var body: some View {
        if day.battery.isEmpty {
            Text("No battery samples for this day.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                chart
                    .frame(height: 240)
                if !legendItems.isEmpty {
                    FlowLegend(items: legendItems)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var legendItems: [(String, Color)] {
        var items: [(String, Color)] = []
        if !chargingBands.isEmpty { items.append((String(localized: "Charging"), Color.green.opacity(0.3))) }
        if hasScreenBar { items.append((String(localized: "Screen On"), .indigo)) }
        if day.events?.isEmpty == false { items.append((String(localized: "Setting Change"), .secondary)) }
        return items
    }

    private var chart: some View {
        Chart {
            chargingMarks
            screenMarks
            levelMarks
            eventMarks
            selectionMarks
        }
        .chartXScale(domain: day.axis.domain)
        .chartYScale(domain: 0...(hasScreenBar ? 110 : 100))
        .chartXAxis {
            AxisMarks(values: day.axis.marks) { value in
                AxisGridLine()
                AxisValueLabel { Text(day.axis.clock(value.as(Double.self) ?? 0)) }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
            }
        }
        .chartXSelection(value: $selectedHour)
        .accessibilityLabel("Battery level on \(Format.longDate(day))")
        .accessibilityValue("Used \(Int(day.stats.used.rounded())) percent, lowest \(day.stats.lowest ?? 0) percent")
    }

    @ChartContentBuilder
    private var chargingMarks: some ChartContent {
        ForEach(chargingBands.indices, id: \.self) { index in
            LaneBar(start: chargingBands[index].start, end: chargingBands[index].end, value: 100, style: Color.green.opacity(0.15))
        }
    }

    @ChartContentBuilder
    private var screenMarks: some ChartContent {
        let intervals = day.detail?.screen ?? []
        ForEach(intervals.indices, id: \.self) { index in
            RectangleMark(xStart: .value(ChartLabel.start, intervals[index].start),
                          xEnd: .value(ChartLabel.end, max(intervals[index].end, intervals[index].start + 0.03)),
                          yStart: .value(ChartLabel.bottom, 104), yEnd: .value(ChartLabel.top, 110))
                .foregroundStyle(Color.indigo)
        }
    }

    @ChartContentBuilder
    private var levelMarks: some ChartContent {
        let fill = LinearGradient(colors: [.green.opacity(0.35), .green.opacity(0.02)], startPoint: .top, endPoint: .bottom)
        ForEach(points) { point in
            AreaMark(x: .value(ChartLabel.hour, point.sample.hour), yStart: .value(ChartLabel.floor, 0), yEnd: .value(ChartLabel.level, point.sample.level),
                     series: .value(ChartLabel.segment, point.segment))
                .foregroundStyle(fill)
                // The line below reads out the same values, without Swift Charts' untranslated "to" between range ends.
                .accessibilityHidden(true)
            LineMark(x: .value(ChartLabel.hour, point.sample.hour), y: .value(ChartLabel.level, point.sample.level),
                     series: .value(ChartLabel.segment, point.segment))
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var eventMarks: some ChartContent {
        ForEach(day.events ?? []) { event in
            RuleMark(x: .value(ChartLabel.event, event.hour))
                .foregroundStyle(Color.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    @ChartContentBuilder
    private var selectionMarks: some ChartContent {
        if let selected {
            RuleMark(x: .value(ChartLabel.selected, selected.hour))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    callout(for: selected)
                }
            PointMark(x: .value(ChartLabel.hour, selected.hour), y: .value(ChartLabel.level, selected.level))
                .foregroundStyle(Color.green)
                .symbolSize(80)
        }
    }

    private func callout(for sample: BatterySample) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.axis.clock(sample.hour))
                .font(.caption.weight(.semibold))
            Text("\(sample.level)%")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(sample.charging ? "Charging" : "On battery")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let on = day.isScreenOn(at: sample.hour) {
                Text(on ? "Screen on" : "Screen off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}
