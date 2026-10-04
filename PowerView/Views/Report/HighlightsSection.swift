import SwiftUI

struct HighlightsSection: View {
    let day: DayReport
    let whPerPercent: Double
    let stabilityEvents: [StabilityEvent]

    var body: some View {
        let items = highlights
        if !items.isEmpty {
            Section("Highlights") {
                ForEach(items, id: \.text) { item in
                    Label {
                        Text((try? AttributedString(markdown: item.text)) ?? AttributedString(item.text))
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.tint)
                    }
                }
            }
        }
    }

    /// At most five, in order of how much they explain the day's battery use.
    private var highlights: [(icon: String, tint: Color, text: String)] {
        var out: [(String, Color, String)] = []
        if let aod = day.aodEnergyWh, aod > 0.05 {
            out.append(("clock.badge", .purple, "Always-On Display used **≈\(Int((aod / whPerPercent).rounded()))%** of the battery"))
        }
        if let app = day.topOnScreenApp, app.screen > 0 {
            let minutes = app.foregroundMinutes > 0 ? " in \(app.foregroundMinutes) min" : ""
            out.append(("hand.tap.fill", .blue, "**\(app.name)** used the most on screen: \(Format.wh(Double(app.screen) / 1000))\(minutes)"))
        }
        if let app = day.topBackgroundApp, app.background > 0 {
            out.append(("gearshape.2.fill", .orange, "**\(app.name)** used the most in the background: \(Format.wh(Double(app.background) / 1000))"))
        }
        let battery = stabilityEvents.filter(\.kind.affectsBattery)
        if !battery.isEmpty {
            let names = Set(battery.map(\.process)).sorted().prefix(2).joined(separator: " and ")
            out.append(("cpu", .orange, "**\(names)** used heavy background CPU or disk"))
        }
        if let top = day.notifications?.first, top.count >= 20 {
            let woke = top.wokePhone > 0 ? " and woke the phone \(top.wokePhone) times" : ""
            out.append(("bell.badge.fill", .red, "**\(top.name)** sent \(top.count) notifications\(woke)"))
        }
        if let wakes = day.wakes, let reason = wakes.reasons.first {
            out.append(("alarm.fill", .indigo, "Woke from sleep **\(wakes.total) times**, mostly for \(reason.name.lowercased().replacing("wi-fi", with: "Wi-Fi"))"))
        }
        if let peak = day.temperature?.bins.max(by: { $0.maximum < $1.maximum }), peak.maximum >= TemperatureChartView.warmThreshold + 3 {
            out.append(("thermometer.high", .orange, "Battery peaked at **\(String(format: "%.1f", peak.maximum)) °C** around \(Format.clock(Double(peak.bin) / 4))"))
        }
        if let detail = day.detail, detail.radio.count > 2 {
            out.append(("antenna.radiowaves.left.and.right", .green, "Switched between 5G and 4G **\(detail.radio.count - 1) times**"))
        }
        return Array(out.prefix(5))
    }
}
