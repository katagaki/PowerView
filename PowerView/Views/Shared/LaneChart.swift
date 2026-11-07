import Charts
import SwiftUI

/// One row of a lane chart: a title, a total, and a short chart on a shared time axis.
struct LaneChart<Content: ChartContent>: View {
    let title: LocalizedStringResource
    var total: String?
    var height: CGFloat = 30
    var domainMax: Double = 1
    var showsAxis = false
    var axis = TimeAxis()
    /// The time range to highlight, in hours.
    var highlight: ClosedRange<Double>?
    @Binding var selection: Double?
    @ChartContentBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if let total {
                    Text(total)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
            }
            Chart {
                content()
                if let highlight {
                    RectangleMark(xStart: .value(ChartLabel.start, highlight.lowerBound), xEnd: .value(ChartLabel.end, highlight.upperBound),
                                  yStart: .value(ChartLabel.bottom, 0), yEnd: .value(ChartLabel.top, domainMax))
                        .foregroundStyle(.primary.opacity(0.1))
                }
            }
            .chartXScale(domain: axis.domain)
            .chartYScale(domain: 0...domainMax)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: showsAxis ? axis.marks : []) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(axis.clock(value.as(Double.self) ?? 0)) }
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color(.tertiarySystemFill).opacity(0.5))
            }
            .chartXSelection(value: $selection)
            .frame(height: height + (showsAxis ? 22 : 0))
        }
        .accessibilityElement(children: .combine)
    }
}
