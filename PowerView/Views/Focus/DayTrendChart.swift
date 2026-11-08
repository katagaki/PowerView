import Charts
import SwiftUI

/// One stacked part of a bar in a `DayTrendChart`.
struct TrendSeries {
    let name: String
    let color: Color
    /// The value for a day or stretch, nil when it wasn't recorded.
    let value: (DayReport) -> Double?
}

/// A bar for each day or stretch in view, with the selected one picked out. Tapping a bar selects it.
struct DayTrendChart: View {
    let reports: [DayReport]
    let series: [TrendSeries]
    let format: (Double) -> String
    @Binding var selection: Int

    private struct Point: Identifiable {
        let id: String
        let index: Int
        let series: String
        let value: Double
    }

    private var points: [Point] {
        reports.indices.flatMap { index in
            series.compactMap { series in
                series.value(reports[index]).map { Point(id: "\(reports[index].id)-\(series.name)", index: index, series: series.name, value: $0) }
            }
        }
    }

    private func total(at index: Int) -> Double? {
        let values = series.compactMap { $0.value(reports[index]) }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    /// Labels every few bars, so long reports don't crowd the axis.
    private var labeledIDs: Set<String> {
        let step = max(1, Int((Double(reports.count) / 7).rounded(.up)))
        return Set(reports.indices.filter { ($0 - selection) % step == 0 }.map { reports[$0].id })
    }

    var body: some View {
        let totals = reports.indices.compactMap(total(at:))
        let average = totals.isEmpty ? nil : totals.reduce(0, +) / Double(totals.count)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reports[selection].title)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(total(at: selection).map(format) ?? "—")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                if let average {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Average", comment: "The average across every day or stretch on battery.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(format(average))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Chart {
                ForEach(points) { point in
                    BarMark(x: .value(ChartLabel.day, reports[point.index].id), y: .value(ChartLabel.value, point.value))
                        .foregroundStyle(by: .value(ChartLabel.series, point.series))
                        .opacity(point.index == selection ? 1 : 0.35)
                }
                if let average {
                    RuleMark(y: .value(ChartLabel.value, average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartForegroundStyleScale(domain: series.map(\.name), range: series.map(\.color))
            .chartLegend(series.count > 1 ? .visible : .hidden)
            .chartLegend(position: .top, alignment: .leading, spacing: 12)
            .chartXScale(domain: reports.map(\.id))
            .chartXAxis {
                // A category axis labels every bar whatever values it's given, so the rest are left blank.
                AxisMarks { value in
                    if let id = value.as(String.self), labeledIDs.contains(id), let day = reports.first(where: { $0.id == id }) {
                        AxisValueLabel {
                            Text(day.stretch.map { _ in Format.weekday(day) } ?? Format.dayNumber(day))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(format(value.as(Double.self) ?? 0)) }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            let x = location.x - geometry[plot].origin.x
                            if let id: String = proxy.value(atX: x), let index = reports.firstIndex(where: { $0.id == id }) {
                                selection = index
                            }
                        }
                }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 8)
    }
}
