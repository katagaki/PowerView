import SwiftUI

struct ReportView: View {
    let report: PowerReport
    @State private var selectedIndex: Int

    init(report: PowerReport) {
        self.report = report
        // Open on the last full day; the capture day is usually partial.
        let lastFull = report.days.count - ((report.days.last?.partial ?? false) && report.days.count > 1 ? 2 : 1)
        _selectedIndex = State(initialValue: max(0, lastFull))
    }

    private var day: DayReport { report.days[selectedIndex] }
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
            HighlightsSection(day: day, report: report, stabilityEvents: dayStabilityEvents)

            Section {
                BatteryChartView(day: day)
                if let temperature = day.temperature {
                    TemperatureChartView(series: temperature)
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
                    Text("Touch and hold a lane, then drag to inspect an hour. Shaded hours were mostly plugged in.")
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
                        LabeledContent(event.text, value: Format.clock(event.hour))
                            .monospacedDigit()
                    }
                }
            }

            Section {
                if report.days.count > 1 {
                    NavigationLink {
                        CompareView(report: report, initialDay: selectedIndex)
                    } label: {
                        Label {
                            Text("Compare Days")
                            Text("Two days side by side")
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
        .navigationTitle(Format.shortDate(day))
        .navigationSubtitle(report.meta.deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            DayStrip(days: report.days, selection: $selectedIndex)
        }
    }

    private var dayStabilityEvents: [StabilityEvent] {
        (report.stability ?? []).filter { Format.dayKey($0.date, in: report.meta.timeZone) == day.date }
    }

    private func stabilitySummary(_ events: [StabilityEvent]) -> String {
        let crashes = events.filter { $0.kind == .crash }.count
        let kills = events.filter { $0.kind == .memoryKill }.count
        return events.isEmpty ? "No reports" : "\(crashes) crashes · \(kills) closed for memory · \(events.count) reports"
    }

    private var batteryFooter: String {
        var parts = ["Green: charging."]
        if day.detail != nil { parts.append("Purple bar: screen on.") }
        if day.events != nil { parts.append("Dashed lines: setting changes.") }
        return parts.joined(separator: " ")
    }

    private var sourceNote: String {
        let captured = report.meta.captured.formatted(.dateTime.year().month().day().hour().minute().timeZone(.localizedGMT(.short)).locale(.current))
        return "From the power log in \(report.sourceName), captured \(captured). Energy figures are the system's own per-component estimates. Percentages assume \(String(format: "%.1f", whPerPercent * 100)) Wh per full charge."
    }
}
