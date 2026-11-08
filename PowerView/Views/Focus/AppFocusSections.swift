import Charts
import SwiftUI

private let onScreenLabel = String(localized: "On Screen")
private let backgroundLabel = String(localized: "Background")

/// Everything the report knows about one app or process, for the selected day or stretch.
struct AppFocusSections: View {
    let app: FocusApp
    let day: DayReport
    let reports: [DayReport]
    @Binding var selection: Int
    let report: PowerReport
    @State private var timelineSelection: Double?

    private var whPerPercent: Double { report.meta.whPerPercent }
    private var timeZone: TimeZone { report.meta.timeZone }

    private static func energy(of bundleID: String, in day: DayReport) -> AppEnergy? {
        day.apps?.first { $0.bundleID == bundleID }
    }

    private var energy: AppEnergy? { Self.energy(of: app.bundleID, in: day) }
    private var notifications: NotificationApp? { day.notifications?.first { $0.bundleID == app.bundleID } }
    private var screenTime: ScreenAppTotal? { day.screenApps?.totals.first { $0.appID == app.bundleID } }
    private var data: DataApp? { day.detail?.dataApps.first { $0.name == app.name } }

    private var stability: [StabilityEvent] {
        (report.stability ?? []).filter { $0.belongs(to: app) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        Section {
            tiles
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if energy == nil {
                    Text("Not among the day's top energy users, or the power log didn't keep energy by app for this day.")
                }
                Text(app.bundleID)
                    .font(.caption2.monospaced())
            }
        }

        if reports.count > 1 {
            Section {
                DayTrendChart(reports: reports,
                              series: [
                                TrendSeries(name: onScreenLabel, color: .blue) { day in
                                    Self.energy(of: app.bundleID, in: day).map { Double($0.screen) / 1000 }
                                },
                                TrendSeries(name: backgroundLabel, color: .orange) { day in
                                    Self.energy(of: app.bundleID, in: day).map { Double($0.background) / 1000 }
                                }
                              ],
                              format: { Format.wh($0, digits: $0 < 1 ? 2 : 1) },
                              selection: $selection)
            } header: {
                Text("Day by Day")
            }
        }

        if let energy {
            Section {
                LabeledContent("On Screen") {
                    Text(Format.wh(Double(energy.screen) / 1000)).monospacedDigit()
                }
                LabeledContent("Background") {
                    Text(Format.wh(Double(energy.background) / 1000)).monospacedDigit()
                }
                if energy.backgroundMinutes > 0 {
                    LabeledContent("Running in Background") {
                        Text(Format.minutes(energy.backgroundMinutes)).monospacedDigit()
                    }
                }
                if energy.audioMinutes > 0 {
                    LabeledContent("Audio Playing") {
                        Text(Format.minutes(energy.audioMinutes)).monospacedDigit()
                    }
                }
            } header: {
                Text("Energy")
            }
        }

        if let timeline = day.screenApps, let screenTime {
            Section {
                LaneChart(title: "App on Screen", total: Format.duration(screenTime.minutes * 60), height: 22, showsAxis: true,
                          axis: day.axis, highlight: nil, selection: $timelineSelection) {
                    ForEach(timeline.segments.indices, id: \.self) { index in
                        let segment = timeline.segments[index]
                        if segment.appID == app.bundleID {
                            LaneBar(start: segment.start, end: max(segment.end, segment.start + 0.02), value: 1, style: Color.blue)
                        }
                    }
                }
                .padding(.vertical, 8)
                LabeledContent("Times Opened") {
                    Text("\(timeline.segments.filter { $0.appID == app.bundleID }.count)").monospacedDigit()
                }
            } header: {
                Text("Screen")
            }
        }

        if notifications != nil || data != nil {
            Section {
                if let notifications {
                    LabeledContent {
                        Text(notifications.count.formatted()).monospacedDigit()
                    } label: {
                        Text("Notifications")
                        if notifications.wokePhone > 0 {
                            Text("\(notifications.wokePhone) woke the phone")
                        }
                    }
                }
                if let data {
                    LabeledContent("Wi-Fi Data") {
                        Text(Format.megabytes(data.wifiMB)).monospacedDigit()
                    }
                    LabeledContent("Cellular Data") {
                        Text(Format.megabytes(data.cellularMB, digits: 1)).monospacedDigit()
                    }
                }
            } header: {
                Text("Notifications & Network")
            }
        }

        let dayEvents = stability.filter { day.contains($0.date, timeZone: timeZone) }
        if !stability.isEmpty {
            Section {
                ForEach(dayEvents.prefix(5)) { event in
                    StabilityRow(event: event, timeZone: timeZone)
                }
                if dayEvents.isEmpty {
                    Text("No reports on this day.")
                        .foregroundStyle(.secondary)
                }
                NavigationLink {
                    AppStabilityList(title: app.displayName, events: stability, timeZone: timeZone)
                } label: {
                    LabeledContent("All Days") {
                        Text("\(stability.count) reports", comment: "A number of diagnostic reports.")
                    }
                }
            } header: {
                Text("Stability")
            }
        }
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "Energy Used", systemImage: "bolt.fill", tint: .orange,
                       value: energy.map { Format.decimal(Double($0.total) / 1000, digits: 2) }, unit: "Wh",
                       detail: usualDetail)
            MetricTile(title: "Battery Used", systemImage: "battery.25percent", tint: .red,
                       value: energy.map { "≈\(Int((Double($0.total) / 1000 / whPerPercent).rounded()))" }, unit: "%",
                       detail: share.map { String(localized: "\(Int(($0 * 100).rounded()))% of all energy", comment: "An app's share of the day's energy. Shown in a small tile, so keep it short.") })
            MetricTile(title: "Screen On", systemImage: "iphone.gen3", tint: .indigo,
                       value: screenMinutes.map { Format.decimal($0 / 60) }, unit: Format.hoursUnit,
                       detail: energy.map { String(localized: "\(Format.wh(Double($0.screen) / 1000)) on screen", comment: "An app's energy or time with the display on.") })
            MetricTile(title: "Background", systemImage: "gearshape.2.fill", tint: .purple,
                       value: energy.map { Format.decimal(Double($0.backgroundMinutes) / 60) }, unit: Format.hoursUnit,
                       detail: energy.map { String(localized: "\(Format.wh(Double($0.background) / 1000)) background", comment: "An app's energy with the display off.") })
        }
    }

    private var screenMinutes: Double? {
        screenTime?.minutes ?? energy.map { Double($0.foregroundMinutes) }
    }

    private var share: Double? {
        guard let energy, let total = day.energyWh, total > 0 else { return nil }
        return Double(energy.total) / 1000 / total
    }

    private var usualDetail: String? {
        let others = reports.filter { $0.id != day.id }.compactMap { Self.energy(of: app.bundleID, in: $0) }
        guard !others.isEmpty else { return nil }
        let average = Double(others.reduce(0) { $0 + $1.total }) / Double(others.count) / 1000
        return String(localized: "Usually \(Format.wh(average))", comment: "Average energy across the other days or stretches. Shown in a small tile, so keep it short.")
    }
}

/// Every diagnostic report for one app, newest first.
private struct AppStabilityList: View {
    let title: String
    let events: [StabilityEvent]
    let timeZone: TimeZone

    var body: some View {
        List(events) { event in
            StabilityRow(event: event, timeZone: timeZone, showsDate: true)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
