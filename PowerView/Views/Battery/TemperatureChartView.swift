import Charts
import SwiftUI

/// Battery temperature through the day on the same 0–24 h axis as the battery chart.
struct TemperatureChartView: View {
    let series: TemperatureSeries
    @State private var selectedHour: Double?

    /// Above this, iOS starts managing charging and performance to protect the battery.
    static let warmThreshold = 35.0

    private var peak: TemperatureBin? { series.bins.max { $0.maximum < $1.maximum } }

    private var selected: TemperatureBin? {
        guard let selectedHour else { return nil }
        let bin = Int(selectedHour * 4)
        return series.bins.min { abs($0.bin - bin) < abs($1.bin - bin) }.flatMap { abs($0.bin - bin) <= 2 ? $0 : nil }
    }

    private var domain: ClosedRange<Double> {
        let low = series.bins.map(\.average).min() ?? 20, high = series.bins.map(\.maximum).max() ?? 40
        return (min(20, low - 2).rounded(.down))...(max(Self.warmThreshold + 5, high + 2).rounded(.up))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label("Battery Temperature", systemImage: "thermometer.medium")
                    .labelStyle(.compact)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                if let peak {
                    Text("Peak \(peak.maximum, format: .number.precision(.fractionLength(1))) °C at \(Format.clock(Double(peak.bin) / 4))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Chart {
                RuleMark(y: .value("Warm", Self.warmThreshold))
                    .foregroundStyle(.red.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("\(Int(Self.warmThreshold)) °C")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                ForEach(series.bins, id: \.bin) { bin in
                    let hour = Double(bin.bin) / 4 + 0.125
                    if series.isSparse {
                        PointMark(x: .value("Hour", hour), y: .value("Temperature", bin.average))
                            .foregroundStyle(Color.orange)
                            .symbolSize(20)
                    } else {
                        AreaMark(x: .value("Hour", hour), yStart: .value("Low", domain.lowerBound), yEnd: .value("Temperature", bin.average))
                            .foregroundStyle(LinearGradient(colors: [.orange.opacity(0.3), .orange.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Hour", hour), y: .value("Temperature", bin.average))
                            .foregroundStyle(Color.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected", Double(selected.bin) / 4 + 0.125))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Format.clock(Double(selected.bin) / 4))–\(Format.clock(Double(selected.bin + 1) / 4))")
                                    .font(.caption.weight(.semibold))
                                Text("\(selected.average, format: .number.precision(.fractionLength(1))) °C")
                                    .font(.headline)
                                Text("Max \(selected.maximum, format: .number.precision(.fractionLength(1))) °C")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .monospacedDigit()
                            .padding(8)
                            .background(.regularMaterial, in: .rect(cornerRadius: 10))
                        }
                }
            }
            .chartXScale(domain: 0...24)
            .chartYScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(Format.clock(value.as(Double.self) ?? 0)) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)°") }
                }
            }
            .chartXSelection(value: $selectedHour)
            .frame(height: 120)
            if series.isSparse {
                Text("Only readings taken around charging were kept for this day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
