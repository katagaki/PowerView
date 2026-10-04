import Charts
import SwiftUI

private let onScreenLabel = "On Screen"
private let backgroundLabel = "Background"

/// Top apps and processes, split into on-screen and background energy.
struct AppsChartView: View {
    let apps: [AppEnergy]
    @State private var selectedName: String?

    private var top: [AppEnergy] { Array(apps.prefix(10)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(top) { app in
                BarMark(x: .value("Energy", Double(app.screen) / 1000), y: .value("App", app.name))
                    .foregroundStyle(by: .value("Kind", onScreenLabel))
                BarMark(x: .value("Energy", Double(app.background) / 1000), y: .value("App", app.name))
                    .foregroundStyle(by: .value("Kind", backgroundLabel))
                    .annotation(position: .trailing, spacing: 4) {
                        Text(String(format: "%.2f", Double(app.total) / 1000))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .opacity(selectedName == nil || selectedName == app.name ? 1 : 0.35)
            }
            .chartForegroundStyleScale([onScreenLabel: Color.blue, backgroundLabel: Color.orange])
            .chartLegend(position: .top, alignment: .leading)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Double.self) ?? 0, format: .number.precision(.fractionLength(0...1))) Wh") }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel(horizontalSpacing: 8)
                }
            }
            .chartXScale(range: .plotDimension(endPadding: 32))
            .chartYSelection(value: $selectedName)
            .frame(height: CGFloat(top.count) * 30 + 50)

            if let app = top.first(where: { $0.name == selectedName }) {
                AppSummary(app: app)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .animation(.default, value: selectedName)
    }
}
