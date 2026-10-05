import SwiftUI

struct ReportView: View {
    let report: PowerReport
    @State private var period = ReportPeriod.days
    @State private var selectedIndex: Int
    @State private var selectedStretch: Int

    init(report: PowerReport) {
        self.report = report
        // Open on the last full day; the capture day is usually partial.
        let lastFull = report.days.count - ((report.days.last?.partial ?? false) && report.days.count > 1 ? 2 : 1)
        _selectedIndex = State(initialValue: max(0, lastFull))
        // Stretches open on the one since it was last unplugged.
        _selectedStretch = State(initialValue: max(0, (report.unplugged?.count ?? 0) - 1))
    }

    private var reports: [DayReport] {
        let reports = period.reports(in: report)
        return reports.isEmpty ? report.days : reports
    }

    private var selection: Binding<Int> {
        period == .unplugged && report.unplugged?.isEmpty == false ? $selectedStretch : $selectedIndex
    }

    private var day: DayReport { reports[min(selection.wrappedValue, reports.count - 1)] }
    private var whPerPercent: Double { report.meta.whPerPercent }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .screenshotScene(report: report, day: selectedIndex, proxy: proxy)
        }
    }

    private var list: some View {
        List {
            SummarySection(day: day, whPerPercent: whPerPercent)
            HighlightsSection(day: day, report: report, others: comparableReports, stabilityEvents: dayStabilityEvents)

            Section {
                BatteryChartView(day: day)
                if let temperature = day.temperature {
                    TemperatureChartView(series: temperature, axis: day.axis)
                }
            } header: {
                Text("Battery Level")
            } footer: {
                Text(batteryFooter)
            }
            .id(ScreenshotScene.battery.rawValue)

            if let drain = day.drain {
                DrainSection(drain: drain)
            }

            if let hourly = day.hourly {
                Section {
                    HourlyLanesView(day: day, hourly: hourly)
                } header: {
                    Text("Hour by Hour")
                } footer: {
                    Text(hourlyFooter)
                }
                .id(ScreenshotScene.hourly.rawValue)
            }

            ScreenSection(day: day)
                .id(ScreenshotScene.screen.rawValue)

            NotificationsSection(day: day)
                .id(ScreenshotScene.notifications.rawValue)

            if let apps = day.apps {
                Section {
                    AppsChartView(apps: apps)
                    NavigationLink("All Apps & Processes") {
                        AppListView(day: day, apps: apps, whPerPercent: whPerPercent)
                    }
                } header: {
                    Text("What Drained the Battery")
                } footer: {
                    Text(day.tier == .daily ? "Covers 08:00 to 08:00 the next day." : "“On screen” is energy the system tags as display-on, which includes the Always-On Display.")
                }
                .id(ScreenshotScene.apps.rawValue)
            }

            if let components = day.components {
                Section("Energy by Component") {
                    ComponentsChartView(components: components, whPerPercent: whPerPercent)
                }
            }

            if let detail = day.detail {
                NetworkSection(day: day, detail: detail)
                    .id(ScreenshotScene.network.rawValue)
            }

            DayStabilitySection(report: report, day: day)

            if let events = day.events {
                Section("Setting Changes") {
                    ForEach(events) { event in
                        LabeledContent(event.text, value: day.axis.clock(event.hour))
                            .monospacedDigit()
                    }
                }
            }

            Section {
                if report.days.count > 1 {
                    NavigationLink {
                        CompareView(report: report, initialDay: selection.wrappedValue, period: period)
                    } label: {
                        Label {
                            Text("Compare Days")
                            Text(period == .unplugged ? "Two stretches on battery side by side" : "Two days side by side")
                        } icon: {
                            Image(systemName: "square.split.2x1.fill").foregroundStyle(.blue)
                        }
                    }
                }
                if let sessions = report.charging {
                    NavigationLink {
                        ChargingView(report: report)
                    } label: {
                        Label {
                            Text("Charging Habits")
                            Text("\(sessions.count) sessions")
                        } icon: {
                            Image(systemName: "bolt.fill").foregroundStyle(.green)
                        }
                    }
                }
                if let events = report.stability {
                    NavigationLink {
                        StabilityView(report: report)
                    } label: {
                        Label {
                            Text("Stability")
                            Text(stabilitySummary(events))
                        } icon: {
                            Image(systemName: "stethoscope").foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("All Days")
            }

            if report.charging == nil && report.stability == nil && report.days.allSatisfy({ $0.notifications == nil }) {
                Section {
                    Label("Import this sysdiagnose again to add charging habits, notifications, temperature and stability.",
                          systemImage: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
            }

            if let battery = report.meta.battery {
                Section {
                    if let cycles = battery.cycleCount {
                        LabeledContent("Cycle Count", value: cycles.formatted())
                    }
                    if let maximum = battery.maximumCapacity {
                        LabeledContent("Full Charge Capacity", value: "\(maximum.formatted()) mAh")
                    }
                    if let design = battery.designCapacity {
                        LabeledContent("Design Capacity", value: "\(design.formatted()) mAh")
                    }
                } header: {
                    Text("Battery")
                } footer: {
                    Text("As of \(report.meta.captured.formatted(date: .abbreviated, time: .shortened)).")
                }
            }

            Section {
            } footer: {
                Text(sourceNote)
            }
        }
        .contentMargins(.top, 8, for: .scrollContent)
        .animation(.default, value: selectedIndex)
        .animation(.default, value: selectedStretch)
        .animation(.default, value: period)
        .navigationTitle(day.title)
        .navigationSubtitle(report.meta.deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            DayStrip(days: reports, selection: selection)
                // A fresh strip per period, so it scrolls to that period's selection.
                .id(period)
        }
        .toolbar {
            if report.unplugged?.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Show", selection: $period) {
                            ForEach(ReportPeriod.allCases) { period in
                                Label(period.rawValue, systemImage: period.systemImage).tag(period)
                            }
                        }
                    } label: {
                        Label("Show", systemImage: period.systemImage)
                    }
                }
            }
        }
    }

    /// What the highlights call "usual". Stretches on battery vary in length, so only those
    /// at least half as long and at most twice as long are compared.
    private var comparableReports: [DayReport] {
        guard let stretch = day.stretch else { return reports }
        let length = stretch.end - stretch.start
        return reports.filter { other in
            guard let otherStretch = other.stretch else { return false }
            return (length / 2...length * 2).contains(otherStretch.end - otherStretch.start)
        }
    }

    private var dayStabilityEvents: [StabilityEvent] {
        (report.stability ?? []).filter { day.contains($0.date, timeZone: report.meta.timeZone) }
    }

    private var hourlyFooter: String {
        let footer = "Touch and hold a lane, then drag to inspect an hour. Shaded hours were mostly plugged in."
        guard day.stretch != nil else { return footer }
        return footer + " Hourly records cover whole hours, so the first and last hours can include time on the charger."
    }

    private func stabilitySummary(_ events: [StabilityEvent]) -> String {
        let crashes = events.filter { $0.kind == .crash }.count
        let kills = events.filter { $0.kind == .memoryKill }.count
        return events.isEmpty ? "No reports" : "\(crashes) crashes · \(kills) closed for memory · \(events.count) reports"
    }

    private var batteryFooter: String {
        var parts: [String] = []
        if let stretch = day.stretch {
            let length = String(format: "%.1f h", stretch.end - stretch.start)
            parts.append(stretch.pluggedIn == nil
                         ? "Unplugged at \(day.axis.clock(stretch.start)) and still on battery when captured, \(length) later."
                         : "Unplugged at \(day.axis.clock(stretch.start)) until plugged in at \(day.axis.clock(stretch.end)), \(length) later.")
        } else {
            parts.append("Green: charging.")
        }
        if day.detail != nil { parts.append("Purple bar: screen on.") }
        if day.events != nil { parts.append("Dashed lines: setting changes.") }
        return parts.joined(separator: " ")
    }

    private var sourceNote: String {
        let captured = report.meta.captured.formatted(.dateTime.year().month().day().hour().minute().timeZone(.localizedGMT(.short)).locale(.current))
        return "From the power log in \(report.sourceName), captured \(captured). Energy figures are the system's own per-component estimates. Percentages assume \(String(format: "%.1f", whPerPercent * 100)) Wh per full charge."
    }
}
