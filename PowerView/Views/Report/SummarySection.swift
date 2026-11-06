import SwiftUI

struct SummarySection: View {
    let day: DayReport
    let whPerPercent: Double

    var body: some View {
        let stats = day.stats
        let screen = day.screenOnSeconds
        let drain = day.drain
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                MetricTile(title: "Battery Used", systemImage: "battery.25percent", tint: .red,
                           value: "\(Int(stats.used.rounded()))", unit: "%",
                           detail: stats.lowest.map { "Lowest \($0)%" })
                MetricTile(title: "On Battery", systemImage: "powerplug.portrait", tint: .green,
                           value: Format.decimal(stats.hoursOnBattery), unit: "h",
                           detail: stats.charged > 3 ? "Charged +\(Int(stats.charged.rounded()))%" : "No charging")
                MetricTile(title: "Screen On", systemImage: "iphone.gen3", tint: .indigo,
                           value: screen.map { Format.decimal($0 / 3600) }, unit: "h",
                           detail: alwaysOnDetail)
                MetricTile(title: "Energy Used", systemImage: "bolt.fill", tint: .orange,
                           value: day.energyWh.map(Format.decimal), unit: "Wh",
                           detail: day.backgroundShare.map { "\(Int(($0 * 100).rounded()))% with display off" })
                if let drain {
                    MetricTile(title: "Standby Drain", systemImage: "moon.fill", tint: .purple,
                               value: drain.screenOffPerHour.map(Format.decimal), unit: "%/h",
                               detail: String(format: "Screen off · %.1f h", drain.screenOffHours))
                    MetricTile(title: "In-Use Drain", systemImage: "sun.max.fill", tint: .yellow,
                               value: drain.screenOnPerHour.map(Format.decimal), unit: "%/h",
                               detail: String(format: "Screen on · %.1f h", drain.screenOnHours))
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    private var alwaysOnDetail: String {
        if let seconds = day.alwaysOnSeconds, seconds > 0 { return "Always-On \(Format.hours(fromSeconds: seconds))" }
        if day.alwaysOnSeconds != nil || day.aodAtStart == false { return "Always-On off" }
        return day.detail != nil ? "From backlight events" : " "
    }
}
