import SwiftUI

struct ReportView: View {
    let report: PowerReport
    @State private var period = ReportPeriod.days
    @State private var selectedIndex: Int
    @State private var selectedStretch: Int
    @State private var destination: ReportDestination?
    @State private var isShowingInfo = false

    init(report: PowerReport) {
        self.report = report
        // Open on the last full day; the capture day is usually partial.
        let lastFull = report.days.count - ((report.days.last?.partial ?? false) && report.days.count > 1 ? 2 : 1)
        _selectedIndex = State(initialValue: max(0, lastFull))
        // Stretches open on the one since it was last unplugged.
        _selectedStretch = State(initialValue: max(0, (report.unplugged?.count ?? 0) - 1))
    }

    private var hasStretches: Bool { report.unplugged?.isEmpty == false }

    private var reports: [DayReport] {
        let reports = period.reports(in: report)
        return reports.isEmpty ? report.days : reports
    }

    private var selection: Binding<Int> {
        period == .unplugged && hasStretches ? $selectedStretch : $selectedIndex
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
            BatterySection(day: day)
                .id(ScreenshotScene.battery.rawValue)
            if let drain = day.drain {
                DrainSection(drain: drain)
            }
            HourlySection(day: day)
                .id(ScreenshotScene.hourly.rawValue)
            ScreenSection(day: day)
                .id(ScreenshotScene.screen.rawValue)
            NotificationsSection(day: day)
                .id(ScreenshotScene.notifications.rawValue)
            AppsSection(day: day, whPerPercent: whPerPercent)
                .id(ScreenshotScene.apps.rawValue)
            if let components = day.components {
                Section("Energy by Component") {
                    ComponentsChartView(components: components, whPerPercent: whPerPercent)
                }
            }
            if let detail = day.detail {
                NetworkSection(day: day, detail: detail)
                    .id(ScreenshotScene.network.rawValue)
            }
            DayStabilitySection(events: dayStabilityEvents, report: report)
            SettingChangesSection(day: day)
        }
        .contentMargins(.top, 8, for: .scrollContent)
        .animation(.default, value: selectedIndex)
        .animation(.default, value: selectedStretch)
        .animation(.default, value: period)
        .navigationTitle(day.title)
        .navigationSubtitle(DeviceNames.displayName(report.meta.deviceName))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DayStrip(days: reports, selection: selection)
                // A fresh strip per period, so it scrolls to that period's selection.
                .id(period)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ReportMenu(report: report, period: period, destination: $destination, isShowingInfo: $isShowingInfo)
            }
            if hasStretches {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Show", selection: $period) {
                            ForEach(ReportPeriod.allCases) { period in
                                Label {
                                    Text(period.title)
                                } icon: {
                                    Image(systemName: period.systemImage)
                                }
                                .tag(period)
                            }
                        }
                    } label: {
                        Label("Show", systemImage: period.systemImage)
                    }
                }
            }
        }
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .compare: CompareView(report: report, initialDay: selection.wrappedValue, period: period)
            case .charging: ChargingView(report: report)
            case .stability: StabilityView(report: report)
            }
        }
        .sheet(isPresented: $isShowingInfo) { ReportInfoView(report: report) }
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
}
