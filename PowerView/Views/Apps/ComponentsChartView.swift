import Charts
import SwiftUI

struct ComponentsChartView: View {
    let components: [ComponentEnergy]
    let whPerPercent: Double

    var body: some View {
        Chart(components) { component in
            BarMark(x: .value("Energy", component.wh), y: .value("Component", component.name))
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, spacing: 4) {
                    Text("\(String(format: "%.1f", component.wh)) · ≈\(Int((component.wh / whPerPercent).rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Double.self) ?? 0, format: .number.precision(.fractionLength(0))) Wh") }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { _ in AxisValueLabel(anchor: .leading, horizontalSpacing: 8) }
        }
        .chartXScale(range: .plotDimension(endPadding: 56))
        .frame(height: CGFloat(components.count) * 34 + 24)
        .padding(.vertical, 8)
    }
}
