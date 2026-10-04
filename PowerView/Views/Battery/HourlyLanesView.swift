import Charts
import SwiftUI

struct HourlyLanesView: View {
    let day: DayReport
    let hourly: HourlyLanes
    @State private var selection: Double?

    private struct Lane: Identifiable {
        let name: String
        let values: [Double]
        let max: Double
        let color: Color
        let format: (Double) -> String
        let total: String
        var id: String { name }
    }

    private var lanes: [Lane] {
        func seconds(_ values: [Int]) -> [Double] { values.map(Double.init) }
        func mWh(_ v: Double) -> String { "\(Int(v)) mWh" }
        func whTotal(_ values: [Int]) -> String { Format.wh(Double(values.reduce(0, +)) / 1000, digits: 1) }
        let drain = day.hourlyDrain
        var lanes = [Lane(name: "Battery Used", values: drain, max: 15, color: .red,
                          format: { "\(Int($0.rounded()))%" }, total: "\(Int(drain.reduce(0, +).rounded()))%")]
        if day.hasUsageTime {
            lanes.append(Lane(name: "Screen On", values: seconds(hourly.screen), max: 3600, color: .indigo,
                              format: Format.minutes(fromSeconds:), total: Format.hours(fromSeconds: Double(hourly.screen.reduce(0, +)))))
        }
        let aodTotal = Double(hourly.aod.reduce(0, +))
        lanes.append(Lane(name: "Always-On Display", values: seconds(hourly.aod), max: 3600, color: .purple,
                          format: Format.minutes(fromSeconds:), total: aodTotal > 0 ? Format.hours(fromSeconds: aodTotal) : "Off"))
        lanes.append(Lane(name: "Audio Playing", values: seconds(hourly.audio), max: 3600, color: .pink,
                          format: Format.minutes(fromSeconds:), total: Format.hours(fromSeconds: Double(hourly.audio.reduce(0, +)))))
        if let notifications = day.notificationsByHour {
            lanes.append(Lane(name: "Notifications", values: notifications.map(Double.init), max: Double(max(10, notifications.max() ?? 0)), color: .red,
                              format: { "\(Int($0))" }, total: "\(notifications.reduce(0, +))"))
        }
        if let wakes = day.wakes {
            lanes.append(Lane(name: "Wakes from Sleep", values: wakes.byHour.map(Double.init), max: Double(max(10, wakes.byHour.max() ?? 0)), color: .mint,
                              format: { "\(Int($0))" }, total: "\(wakes.total)"))
        }
        lanes.append(Lane(name: "Cellular Modem", values: seconds(hourly.modem), max: 400, color: .green, format: mWh, total: whTotal(hourly.modem)))
        lanes.append(Lane(name: "Wi-Fi Radio", values: seconds(hourly.wifi), max: 400, color: .blue, format: mWh, total: whTotal(hourly.wifi)))
        lanes.append(Lane(name: "System CPU", values: seconds(hourly.systemCPU), max: 250, color: .orange, format: mWh, total: whTotal(hourly.systemCPU)))
        lanes.append(Lane(name: "Total Energy", values: seconds(hourly.total), max: 2500, color: .gray, format: mWh, total: whTotal(hourly.total)))
        return lanes
    }

    private var selectedHour: Int? {
        selection.map { min(23, max(0, Int($0))) }
    }

    private var highlight: ClosedRange<Double>? {
        selectedHour.map { Double($0)...Double($0 + 1) }
    }

    var body: some View {
        let lanes = lanes
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                if lane.name == "Cellular Modem" && day.hasKeepAlive {
                    connectionLane
                }
                LaneChart(title: lane.name, total: lane.total, domainMax: lane.max,
                          showsAxis: index == lanes.count - 1, highlight: highlight, selection: $selection) {
                    pluggedShading(max: lane.max)
                    ForEach(0..<24, id: \.self) { hour in
                        LaneBar(start: Double(hour) + 0.08, end: Double(hour) + 0.92, value: min(lane.values[hour], lane.max), style: lane.color.gradient)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            if selectedHour != nil {
                SelectionCard(hour: selectedHour, lanes: lanes, day: day, hourly: hourly)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selection == nil)
    }

    private var connectionLane: some View {
        let share = hourly.wifiShare
        return LaneChart(title: "Connection (Wi-Fi vs Cellular)", total: share.map { "\(Int(($0 * 100).rounded()))% Wi-Fi" } ?? "—",
                         domainMax: 1, highlight: highlight, selection: $selection) {
            pluggedShading(max: 1)
            ForEach(0..<24, id: \.self) { hour in
                let cellular = Double(hourly.keepAliveCellular[hour]), wifi = Double(hourly.keepAliveWiFi[hour])
                if cellular + wifi > 0 {
                    let cellularShare = cellular / (cellular + wifi)
                    LaneBar(start: Double(hour) + 0.08, end: Double(hour) + 0.92, value: cellularShare, style: Color.green)
                    RectangleMark(xStart: .value("Start", Double(hour) + 0.08), xEnd: .value("End", Double(hour) + 0.92),
                                  yStart: .value("Bottom", cellularShare), yEnd: .value("Top", 1))
                        .foregroundStyle(Color.blue)
                }
            }
        }
    }

    @ChartContentBuilder
    private func pluggedShading(max: Double) -> some ChartContent {
        ForEach(0..<24, id: \.self) { hour in
            if hourly.plugged[hour] >= 1800 {
                LaneBar(start: Double(hour), end: Double(hour + 1), value: max, style: Color.gray.opacity(0.18))
            }
        }
    }

    private struct SelectionCard: View {
        let hour: Int?
        let lanes: [Lane]
        let day: DayReport
        let hourly: HourlyLanes

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                if let hour {
                    HStack {
                        Text("\(Format.clock(Double(hour)))–\(Format.clock(Double(hour + 1)))")
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
                            row(lane.name, lane.format(lane.values[hour]), lane.color)
                        }
                        if day.hasKeepAlive {
                            row("Connection", hourly.connection(at: hour), .blue)
                        }
                    }
                }
            }
            .inspectorCardStyle()
        }

        private func row(_ name: String, _ value: String, _ color: Color) -> some View {
            GridRow {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(name)
                }
                Text(value)
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .gridColumnAlignment(.trailing)
            }
            .font(.footnote)
        }
    }
}
