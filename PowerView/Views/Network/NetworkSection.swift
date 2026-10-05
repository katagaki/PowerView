import Charts
import SwiftUI

/// Second-by-second screen and cellular state, plus data use in 15-minute bins.
struct NetworkSection: View {
    let day: DayReport
    let detail: EventDetail
    @State private var selection: Double?

    private var bin: Int? { selection.map { min(day.axis.hours * 4 - 1, max(0, Int($0 * 4))) } }
    private var highlight: ClosedRange<Double>? { bin.map { Double($0) / 4...Double($0 + 1) / 4 } }

    private var wifiTotal: Double { detail.data.reduce(0) { $0 + $1.wifiMB } }
    private var cellularTotal: Double { detail.data.reduce(0) { $0 + $1.cellularMB } }
    private var wifiCap: Double {
        let peak = detail.data.map(\.wifiMB).max() ?? 1
        return peak > 800 ? 800 : max(50, (peak / 50).rounded(.up) * 50)
    }
    private var cellularCap: Double { max(0.5, detail.data.map(\.cellularMB).max() ?? 1) }
    private var lastHour: Double { min(Double(day.axis.hours), day.battery.last?.hour ?? Double(day.axis.hours)) }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                LaneChart(title: "Wi-Fi Data", total: Format.megabytes(wifiTotal), height: 44, domainMax: wifiCap,
                          axis: day.axis, highlight: highlight, selection: $selection) {
                    ForEach(detail.data, id: \.bin) { bin in
                        LaneBar(start: Double(bin.bin) / 4, end: Double(bin.bin + 1) / 4 - 0.02, value: min(bin.wifiMB, wifiCap), style: Color.blue.gradient)
                    }
                }
                LaneChart(title: "Cellular Data", total: String(format: "%.1f MB", cellularTotal), height: 28, domainMax: cellularCap,
                          axis: day.axis, highlight: highlight, selection: $selection) {
                    ForEach(detail.data, id: \.bin) { bin in
                        LaneBar(start: Double(bin.bin) / 4, end: Double(bin.bin + 1) / 4 - 0.02, value: bin.cellularMB, style: Color.green.gradient)
                    }
                }
                LaneChart(title: "Cellular Technology", total: detail.radio.count > 1 ? "\(detail.radio.count - 1) changes" : nil, height: 14,
                          axis: day.axis, highlight: highlight, selection: $selection) {
                    ForEach(detail.radio.indices, id: \.self) { index in
                        let change = detail.radio[index]
                        let end = index + 1 < detail.radio.count ? detail.radio[index + 1].hour : lastHour
                        LaneBar(start: change.hour, end: max(end, change.hour + 0.01), value: 1, style: Self.color(for: change.technology))
                    }
                }
                LaneChart(title: "Signal Bars", total: nil, height: 28, domainMax: 5, showsAxis: true,
                          axis: day.axis, highlight: highlight, selection: $selection) {
                    ForEach(detail.bars, id: \.bin) { bin in
                        LaneBar(start: Double(bin.bin) / 4, end: Double(bin.bin + 1) / 4 - 0.02, value: bin.bars, style: Color.gray.gradient)
                    }
                }
                legend
            }
            .padding(.vertical, 8)
            .overlay(alignment: .top) {
                if selection != nil {
                    selectionCard
                }
            }
            .animation(.easeOut(duration: 0.15), value: selection == nil)

            if !detail.dataApps.isEmpty {
                DisclosureGroup("Top Apps by Data") {
                    ForEach(detail.dataApps) { app in
                        LabeledContent {
                            Text(Format.megabytes(app.wifiMB))
                                .monospacedDigit()
                        } label: {
                            Text(app.name)
                            if app.cellularMB >= 0.1 {
                                Text(String(format: "%.1f MB cellular", app.cellularMB))
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Network")
        } footer: {
            Text("Touch and hold a lane to inspect 15 minutes. 5G/4G changes are exact; data and signal are in 15-minute bins.")
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach(["5G", "4G", "LTE", "3G"].filter { tech in detail.radio.contains { $0.technology == tech } }, id: \.self) { tech in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Self.color(for: tech)).frame(width: 10, height: 10)
                    Text(tech)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let bin {
                let start = Double(bin) / 4, end = start + 0.25
                let data = detail.data.first { $0.bin == bin }
                let bars = detail.bars.first { $0.bin == bin }
                let screenMinutes = detail.screen.reduce(0) { $0 + max(0, min($1.end, end) - max($1.start, start)) } * 60
                let changes = detail.radio.filter { $0.hour >= start && $0.hour < end }.count
                Text("\(day.axis.clock(start))–\(day.axis.clock(end))")
                    .font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                    row("Screen On", "\(Int(screenMinutes.rounded())) min")
                    row("Wi-Fi Data", data.map { $0.wifiMB >= 1000 ? Format.megabytes($0.wifiMB) : String(format: "%.1f MB", $0.wifiMB) } ?? "0 MB")
                    row("Cellular Data", String(format: "%.2f MB", data?.cellularMB ?? 0))
                    row("Cellular", (technology(at: start + 0.125) ?? "—") + (changes > 0 ? " · \(changes) changes" : ""))
                    row("Signal Bars", bars.map { String(format: "%.1f", $0.bars) } ?? "—")
                }
            }
        }
        .inspectorCardStyle()
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name)
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
                .gridColumnAlignment(.trailing)
        }
        .font(.footnote)
    }

    private func technology(at hour: Double) -> String? {
        detail.radio.last { $0.hour <= hour }?.technology
    }

    static func color(for technology: String) -> Color {
        switch technology {
        case "5G": .mint
        case "4G", "LTE": .yellow
        default: .gray
        }
    }
}
