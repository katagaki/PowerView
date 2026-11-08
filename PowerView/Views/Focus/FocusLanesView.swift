import Charts
import SwiftUI

/// One row of hourly values in a `FocusLanesView`.
struct FocusLane: Identifiable {
    let name: LocalizedStringResource
    let values: [Double]
    let color: Color
    /// The smallest top of the scale, so quiet days don't look busy.
    let minimumMax: Double
    let format: (Double) -> String
    let total: String
    var id: String { name.key }

    var domainMax: Double { max(minimumMax, values.max() ?? 0) }
}

/// Hour-by-hour lanes for one component, with the plugged-in hours shaded.
struct FocusLanesView: View {
    let day: DayReport
    let hourly: HourlyLanes
    let lanes: [FocusLane]
    @State private var selection: Double?

    private var hours: Int { hourly.total.count }
    private var selectedHour: Int? { selection.map { min(hours - 1, max(0, Int($0))) } }
    private var highlight: ClosedRange<Double>? { selectedHour.map { Double($0)...Double($0 + 1) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                let domainMax = lane.domainMax
                LaneChart(title: lane.name, total: lane.total, domainMax: domainMax,
                          showsAxis: index == lanes.count - 1, axis: day.axis, highlight: highlight, selection: $selection) {
                    ForEach(0..<hours, id: \.self) { hour in
                        if hourly.plugged[hour] >= 1800 {
                            LaneBar(start: Double(hour), end: Double(hour + 1), value: domainMax, style: Color.gray.opacity(0.18))
                        }
                    }
                    ForEach(0..<min(hours, lane.values.count), id: \.self) { hour in
                        LaneBar(start: Double(hour) + 0.08, end: Double(hour) + 0.92, value: lane.values[hour], style: lane.color.gradient)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            if let hour = selectedHour {
                selectionCard(hour)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selection == nil)
    }

    private func selectionCard(_ hour: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(day.axis.clock(Double(hour)))–\(day.axis.clock(Double(hour + 1)))")
                    .font(.headline)
                Spacer()
                if hourly.plugged[hour] >= 1800 {
                    Label("Plugged In", systemImage: "powerplug.portrait.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                ForEach(lanes) { lane in
                    if hour < lane.values.count {
                        GridRow {
                            HStack(spacing: 6) {
                                Circle().fill(lane.color).frame(width: 7, height: 7)
                                Text(lane.name)
                            }
                            Text(lane.format(lane.values[hour]))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                                .gridColumnAlignment(.trailing)
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .inspectorCardStyle()
    }
}
