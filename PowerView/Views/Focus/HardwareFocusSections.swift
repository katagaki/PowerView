import SwiftUI

/// Everything the report knows about one hardware component, for the selected day or stretch.
struct HardwareFocusSections: View {
    /// A `ComponentEnergy.name`.
    let name: String
    let day: DayReport
    let reports: [DayReport]
    @Binding var selection: Int
    let whPerPercent: Double

    private var displayName: String { ComponentEnergy.displayName(for: name) }

    private static func energy(of name: String, in day: DayReport) -> Double? {
        day.components?.first { $0.name == name }?.wh
    }

    var body: some View {
        let energy = Self.energy(of: name, in: day)
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                MetricTile(title: "Energy Used", systemImage: "bolt.fill", tint: .orange,
                           value: energy.map { Format.decimal($0, digits: 2) }, unit: "Wh",
                           detail: usualDetail)
                MetricTile(title: "Battery Used", systemImage: "battery.25percent", tint: .red,
                           value: energy.map { "≈\(Int(($0 / whPerPercent).rounded()))" }, unit: "%",
                           detail: String(localized: "Of a full charge", comment: "A share of a full battery charge. Shown in a small tile, so keep it short."))
                MetricTile(title: "Share of Energy", systemImage: "chart.pie.fill", tint: .blue,
                           value: share(energy).map { "\(Int(($0 * 100).rounded()))" }, unit: "%",
                           detail: rank.map { String(localized: "#\($0) of \(day.components?.count ?? 0) components", comment: "Where a component ranks by energy used. Shown in a small tile, so keep it short.") })
                extraTile
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } footer: {
            if energy == nil {
                Text("The power log didn't keep energy by component for this day.")
            }
        }

        if reports.count > 1 {
            Section {
                DayTrendChart(reports: reports,
                              series: [TrendSeries(name: displayName, color: .orange) { Self.energy(of: name, in: $0) }],
                              format: { Format.wh($0, digits: $0 < 1 ? 2 : 1) },
                              selection: $selection)
            } header: {
                Text("Day by Day")
            }
        }

        if let hourly = day.hourly, !lanes(hourly).isEmpty {
            Section {
                FocusLanesView(day: day, hourly: hourly, lanes: lanes(hourly))
            } header: {
                Text("Hour by Hour")
            }
        }

        switch name {
        case "Display":
            ScreenSection(day: day)
        case "Cellular Modem", "Wi-Fi":
            if let detail = day.detail {
                NetworkSection(day: day, detail: detail)
            }
        default:
            EmptyView()
        }
    }

    private func share(_ energy: Double?) -> Double? {
        guard let energy, let total = day.energyWh, total > 0 else { return nil }
        return energy / total
    }

    private var rank: Int? {
        guard let components = day.components, Self.energy(of: name, in: day) != nil else { return nil }
        let sorted = components.sorted { $0.wh > $1.wh }
        return sorted.firstIndex { $0.name == name }.map { $0 + 1 }
    }

    private var usualDetail: String? {
        let others = reports.filter { $0.id != day.id }.compactMap { Self.energy(of: name, in: $0) }
        guard !others.isEmpty else { return nil }
        return String(localized: "Usually \(Format.wh(others.reduce(0, +) / Double(others.count)))", comment: "Average energy across the other days or stretches. Shown in a small tile, so keep it short.")
    }

    /// A fourth tile about how the component was used.
    @ViewBuilder
    private var extraTile: some View {
        switch name {
        case "Display":
            MetricTile(title: "Screen On", systemImage: "iphone.gen3", tint: .indigo,
                       value: day.screenOnSeconds.map { Format.decimal($0 / 3600) }, unit: Format.hoursUnit,
                       detail: day.aodEnergyWh.flatMap { $0 > 0 ? String(localized: "Always-On \(Format.wh($0))", comment: "Energy the Always-On Display used. Shown in a small tile, so keep it short.") : nil })
        case "Cellular Modem":
            let data = Self.data(day.detail.map { $0.data.reduce(0) { $0 + $1.cellularMB } })
            MetricTile(title: "Cellular Data", systemImage: "antenna.radiowaves.left.and.right", tint: .green,
                       value: data.value, unit: data.unit,
                       detail: day.hourly?.wifiShare.map { String(localized: "\(Int(((1 - $0) * 100).rounded()))% of pushes", comment: "The share of push connections made over cellular. Shown in a small tile, so keep it short.") })
        case "Wi-Fi":
            let data = Self.data(day.detail.map { $0.data.reduce(0) { $0 + $1.wifiMB } })
            MetricTile(title: "Wi-Fi Data", systemImage: "wifi", tint: .blue,
                       value: data.value, unit: data.unit,
                       detail: day.hourly?.wifiShare.map { String(localized: "\(Int(($0 * 100).rounded()))% of pushes", comment: "The share of push connections made over Wi-Fi. Shown in a small tile, so keep it short.") })
        case "Processor (CPU/GPU/NPU)":
            MetricTile(title: "System CPU", systemImage: "gearshape.2.fill", tint: .orange,
                       value: day.hourly.map { Format.decimal(Double($0.systemCPU.reduce(0, +)) / 1000, digits: 2) }, unit: "Wh",
                       detail: String(localized: "Not counted to an app", comment: "CPU energy that isn't attributed to any app. Shown in a small tile, so keep it short."))
        default:
            MetricTile(title: "Energy Used", systemImage: "bolt.fill", tint: .gray,
                       value: day.energyWh.map { Format.decimal($0, digits: 2) }, unit: "Wh",
                       detail: String(localized: "All components", comment: "The total across every hardware component. Shown in a small tile, so keep it short."))
        }
    }

    /// Megabytes split into a number and its unit, for a metric tile.
    static func data(_ megabytes: Double?) -> (value: String?, unit: String) {
        guard let megabytes else { return (nil, "MB") }
        return megabytes >= 1000 ? (Format.decimal(megabytes / 1000), "GB") : (Format.decimal(megabytes), "MB")
    }

    private func lanes(_ hourly: HourlyLanes) -> [FocusLane] {
        func mWh(_ v: Double) -> String { "\(Int(v)) mWh" }
        func total(_ values: [Int]) -> String { Format.wh(Double(values.reduce(0, +)) / 1000, digits: 1) }
        func doubles(_ values: [Int]) -> [Double] { values.map(Double.init) }
        func count(_ values: [Int]) -> String { "\(values.reduce(0, +))" }
        let drain = day.hourlyDrain
        let battery = FocusLane(name: "Battery Used", values: drain, color: .red, minimumMax: 15,
                                format: { "\(Int($0.rounded()))%" }, total: "\(Int(drain.reduce(0, +).rounded()))%")
        var lanes: [FocusLane] = []
        switch name {
        case "Display":
            lanes.append(FocusLane(name: "Display Energy", values: doubles(hourly.display), color: .indigo, minimumMax: 400, format: mWh, total: total(hourly.display)))
            if day.hasUsageTime {
                lanes.append(FocusLane(name: "Screen On", values: doubles(hourly.screen), color: .indigo, minimumMax: 3600,
                                       format: Format.minutes(fromSeconds:), total: Format.hours(fromSeconds: Double(hourly.screen.reduce(0, +)))))
            }
            lanes.append(FocusLane(name: "Always-On Display", values: doubles(hourly.aod), color: .purple, minimumMax: 3600,
                                   format: Format.minutes(fromSeconds:), total: Format.hours(fromSeconds: Double(hourly.aod.reduce(0, +)))))
        case "Cellular Modem":
            lanes.append(FocusLane(name: "Cellular Modem", values: doubles(hourly.modem), color: .green, minimumMax: 400, format: mWh, total: total(hourly.modem)))
            if day.hasKeepAlive {
                lanes.append(FocusLane(name: "Push Connections over Cellular", values: doubles(hourly.keepAliveCellular), color: .green, minimumMax: 10,
                                       format: { "\(Int($0))" }, total: count(hourly.keepAliveCellular)))
            }
        case "Wi-Fi":
            lanes.append(FocusLane(name: "Wi-Fi Radio", values: doubles(hourly.wifi), color: .blue, minimumMax: 400, format: mWh, total: total(hourly.wifi)))
            if day.hasKeepAlive {
                lanes.append(FocusLane(name: "Push Connections over Wi-Fi", values: doubles(hourly.keepAliveWiFi), color: .blue, minimumMax: 10,
                                       format: { "\(Int($0))" }, total: count(hourly.keepAliveWiFi)))
            }
        case "Processor (CPU/GPU/NPU)":
            lanes.append(FocusLane(name: "System CPU", values: doubles(hourly.systemCPU), color: .orange, minimumMax: 250, format: mWh, total: total(hourly.systemCPU)))
        default:
            return []
        }
        lanes.append(FocusLane(name: "Total Energy", values: doubles(hourly.total), color: .gray, minimumMax: 2500, format: mWh, total: total(hourly.total)))
        return [battery] + lanes
    }
}
