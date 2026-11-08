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
                           detail: stats.lowest.map { String(localized: "Lowest \($0)%", comment: "The day's lowest battery level.") })
                MetricTile(title: "On Battery", systemImage: "powerplug.portrait", tint: .green,
                           value: Format.decimal(stats.hoursOnBattery), unit: Format.hoursUnit,
                           detail: stats.charged > 3 ? String(localized: "Charged +\(Int(stats.charged.rounded()))%", comment: "How much battery was added by charging.") : String(localized: "No charging"))
                MetricTile(title: "Screen On", systemImage: "iphone.gen3", tint: .indigo,
                           value: screen.map { Format.decimal($0 / 3600) }, unit: Format.hoursUnit,
                           detail: alwaysOnDetail)
                MetricTile(title: "Energy Used", systemImage: "bolt.fill", tint: .orange,
                           value: day.energyWh.map { Format.decimal($0) }, unit: "Wh",
                           detail: day.backgroundShare.map { String(localized: "\(Int(($0 * 100).rounded()))% with display off", comment: "The share of energy used while the display was off.") })
                if let drain {
                    MetricTile(title: "Standby Drain", systemImage: "moon.fill", tint: .purple,
                               value: drain.screenOffPerHour.map { Format.decimal($0) }, unit: Format.percentPerHourUnit,
                               detail: String(localized: "Screen off · \(Format.hours(drain.screenOffHours))"))
                    MetricTile(title: "In-Use Drain", systemImage: "sun.max.fill", tint: .yellow,
                               value: drain.screenOnPerHour.map { Format.decimal($0) }, unit: Format.percentPerHourUnit,
                               detail: String(localized: "Screen on · \(Format.hours(drain.screenOnHours))"))
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    private var alwaysOnDetail: String {
        if let seconds = day.alwaysOnSeconds, seconds > 0 {
            return String(localized: "Always-On \(Format.hours(fromSeconds: seconds))", comment: "How long the Always-On Display was on. Shown in a small tile, so keep it short.")
        }
        if day.alwaysOnSeconds != nil || day.aodAtStart == false {
            return String(localized: "Always-On off", comment: "The Always-On Display was off. Shown in a small tile, so keep it short.")
        }
        return day.detail != nil ? String(localized: "From backlight events", comment: "Where the screen-on time came from. Shown in a small tile, so keep it short.") : " "
    }
}
