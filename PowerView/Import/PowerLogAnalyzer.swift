import Foundation

/// Turns an iOS power log (`.PLSQL`) into a per-day summary.
nonisolated struct PowerLogAnalyzer {

    enum AnalyzerError: LocalizedError {
        case noBatteryData

        var errorDescription: String? {
            "The power log has no battery history. It may be from an unsupported iOS version."
        }
    }

    let db: SQLiteDatabase
    let timeZone: TimeZone

    private static let batteryTable = "PLBatteryAgent_EventBackward_BatteryUI"
    private static let rootEnergy = "PLAccountingOperator_Aggregate_RootNodeEnergy"
    private static let qualificationEnergy = "PLAccountingOperator_Aggregate_QualificationEnergy"
    private static let appRunTime = "PLAppTimeService_Aggregate_AppRunTime"
    private static let usageTime = "PLAppTimeService_Aggregate_UsageTime"
    private static let keepAlive = "PLPushAgent_Aggregate_SentKeepAlive"
    private static let alwaysOnState = "PLScreenStateAgent_EventBackward_AlwaysOnEnableState"
    private static let lowPowerSource = "PLDuetService_EventForward_LpmSourceInformation"
    private static let backlight = "Backlight_BacklightStateChange_1_2"
    private static let registration = "PLBBAgent_EventForward_TelephonyRegistration"
    private static let telephonyActivity = "PLBBAgent_EventPoint_TelephonyActivity"
    private static let networkUsage = "PLProcessNetworkAgent_EventInterval_UsageDiff"

    /// Qualification 2 is energy the system tags as "display on".
    private static let displayOnQualification = 2

    /// Groups the accounting root nodes (hardware rails) into components.
    private static func componentName(forRootNode name: String) -> String {
        switch name {
        case "CPU", "GPU", "ANE": "Processor (CPU/GPU/NPU)"
        case "DRAM", "RestOfSOC", "APSOCBaseIOReport": "Memory & Rest of Chip"
        case _ where name.contains("Display"): "Display"
        case _ where name.hasPrefix("BB"): "Cellular Modem"
        case _ where name.hasPrefix("WiFi"): "Wi-Fi"
        default: "Other"
        }
    }

    private static let componentOrder = ["Processor (CPU/GPU/NPU)", "Memory & Rest of Chip", "Display", "Cellular Modem", "Wi-Fi", "Other"]

    func analyze(progress: (Double) -> Void) throws -> (days: [DayReport], captured: Date) {
        guard let first = db.scalar("select min(timestamp) from \(Self.batteryTable)")?.double,
              let last = db.scalar("select max(timestamp) from \(Self.batteryTable)")?.double else {
            throw AnalyzerError.noBatteryData
        }
        createIndexes()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let nodes = Dictionary(db.rows("select ID, Name from PLAccountingOperator_EventNone_Nodes").compactMap { row -> (Int, String)? in
            guard let id = row[0].int, let name = row[1].string else { return nil }
            return (id, name)
        }, uniquingKeysWith: { first, _ in first })
        let cpuNode = nodes.first { $0.value == "CPU" }?.key

        let captured = Date(timeIntervalSince1970: last)
        var day = calendar.startOfDay(for: Date(timeIntervalSince1970: first))
        let lastDay = calendar.startOfDay(for: captured)
        let totalDays = max(1, (calendar.dateComponents([.day], from: day, to: lastDay).day ?? 0) + 1)

        var days: [DayReport] = []
        while day <= lastDay {
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            days.append(analyzeDay(
                start: day.timeIntervalSince1970, end: next.timeIntervalSince1970,
                date: formatter.string(from: day), isPartial: day == lastDay,
                captured: last, nodes: nodes, cpuNode: cpuNode
            ))
            progress(Double(days.count) / Double(totalDays))
            day = next
        }
        return (days, captured)
    }

    /// Power logs aren't indexed by time, and each day queries every table, so index them once up front.
    private func createIndexes() {
        let tables = [Self.batteryTable, Self.rootEnergy, Self.qualificationEnergy, Self.appRunTime, Self.usageTime,
                      Self.keepAlive, Self.alwaysOnState, Self.lowPowerSource, Self.backlight, Self.registration,
                      Self.telephonyActivity, Self.networkUsage,
                      "PLSpringBoardAgent_Aggregate_SBNotifications_Aggregate", "PLSleepWakeAgent_EventForward_PowerState",
                      "PLBatteryAgent_EventBackward_Battery", "BatteryIntelligence_ThermalModel_Sample_7_2",
                      "PLScreenStateAgent_EventForward_ScreenState", "PLDisplayAgent_EventForward_Display"]
        db.execute("begin")
        for (index, table) in tables.enumerated() where db.tableExists(table) {
            db.execute("create index if not exists pv_time_\(index) on \"\(table)\"(timestamp)")
        }
        db.execute("commit")
    }

    // MARK: - One day

    private func analyzeDay(start a: Double, end b: Double, date: String, isPartial: Bool,
                            captured: Double, nodes: [Int: String], cpuNode: Int?) -> DayReport {
        func hour(_ t: Double) -> Double { ((t - a) / 3600 * 1000).rounded() / 1000 }
        func count(_ sql: String) -> Int { db.scalar(sql, a, b)?.int ?? 0 }

        // Battery level (5-minute UI samples)
        let battery = db.rows("select timestamp, Level, IsCharging from \(Self.batteryTable) where timestamp >= ? and timestamp < ? order by timestamp", a, b)
            .compactMap { row -> BatterySample? in
                guard let t = row[0].double, let level = row[1].double else { return nil }
                return BatterySample(hour: hour(t), level: Int(level.rounded()), charging: (row[2].int ?? 0) != 0)
            }

        var report = DayReport(date: date, battery: battery, tier: .battery, hasUsageTime: false, hasKeepAlive: false, partial: isPartial)

        let isHourly = count("select count(*) from \(Self.rootEnergy) where timeInterval=3600 and timestamp >= ? and timestamp < ?") > 0
        let interval = isHourly ? 3600 : 86400
        if count("select count(*) from \(Self.rootEnergy) where timestamp >= ? and timestamp < ?") > 0 {
            report.tier = isHourly ? .hourly : .daily
        }

        // Components and totals
        let rootRows = db.rows("select RootNodeID, sum(Energy) from \(Self.rootEnergy) where timeInterval=? and timestamp >= ? and timestamp < ? group by RootNodeID", interval, a, b)
        if !rootRows.isEmpty {
            var byComponent: [String: Double] = [:]
            var total = 0.0
            for row in rootRows {
                guard let id = row[0].int, let energy = row[1].double else { continue }
                byComponent[Self.componentName(forRootNode: nodes[id] ?? ""), default: 0] += energy
                total += energy
            }
            report.components = Self.componentOrder.map { ComponentEnergy(name: $0, wh: round2((byComponent[$0] ?? 0) / 1e6)) }
            report.energyWh = round2(total / 1e6)
        }

        // Apps: total, on-screen and background energy
        let totals = pairs(db.rows("select NodeID, sum(Energy) from \(Self.rootEnergy) where timeInterval=? and timestamp >= ? and timestamp < ? group by NodeID", interval, a, b))
        let onScreen = pairs(db.rows("select NodeID, sum(Energy) from \(Self.qualificationEnergy) where timeInterval=? and QualificationID=? and timestamp >= ? and timestamp < ? group by NodeID", interval, Self.displayOnQualification, a, b))
        var runTime: [String: (Double, Double, Double)] = [:]
        for row in db.rows("select BundleID, sum(ScreenOnTime), sum(BackgroundTime), sum(BackgroundAudioPlayingTime) from \(Self.appRunTime) where timeInterval=? and timestamp >= ? and timestamp < ? group by BundleID", interval, a, b) {
            guard let id = row[0].string else { continue }
            runTime[id] = (row[1].double ?? 0, row[2].double ?? 0, row[3].double ?? 0)
        }
        let apps = totals.sorted { $0.value > $1.value }.prefix(20).map { nodeID, total -> AppEnergy in
            let identifier = nodes[nodeID] ?? String(nodeID)
            let screen = min(onScreen[nodeID] ?? 0, total)
            let (foreground, background, audio) = runTime[identifier] ?? (0, 0, 0)
            return AppEnergy(bundleID: identifier, name: ProcessNames.name(for: identifier),
                             total: Int((total / 1e3).rounded()), screen: Int((screen / 1e3).rounded()),
                             background: Int(((total - screen) / 1e3).rounded()),
                             foregroundMinutes: Int((foreground / 60).rounded()), backgroundMinutes: Int((background / 60).rounded()),
                             audioMinutes: Int((audio / 60).rounded()))
        }
        if !apps.isEmpty {
            report.apps = apps
            if !onScreen.isEmpty {
                report.screenEnergyWh = round2(totals.reduce(0) { $0 + min(onScreen[$1.key] ?? 0, $1.value) } / 1e6)
                report.aodEnergyWh = round2(onScreen.filter { nodes[$0.key] == ProcessNames.alwaysOnDisplay }.values.reduce(0, +) / 1e6)
            }
        }

        // Hour-by-hour lanes
        if isHourly {
            report.hourly = hourlyLanes(start: a, end: b, cpuNode: cpuNode, nodes: nodes)
            report.hasUsageTime = count("select count(*) from \(Self.usageTime) where timestamp >= ? and timestamp < ?") > 0
            report.hasKeepAlive = count("select count(*) from \(Self.keepAlive) where timestamp >= ? and timestamp < ?") > 0
        }

        // Settings events: Always-On Display and Low Power Mode
        var events: [SettingEvent] = []
        var previous: (Int, Int?)?
        for row in db.rows("select timestamp, alwaysOnEnabledSetting, lowPowerMode from \(Self.alwaysOnState) where timestamp >= ? and timestamp < ? order by timestamp", a, b) {
            guard let t = row[0].double, let setting = row[1].int else { continue }
            let lowPower = row[2].int
            if previous == nil || previous!.0 != setting {
                events.append(SettingEvent(hour: hour(t), text: "Always-On Display \(setting != 0 ? "on" : "off")"))
            }
            if let lowPower, previous == nil || previous!.1 != lowPower {
                events.append(SettingEvent(hour: hour(t), text: "Low Power Mode \(lowPower != 0 ? "on" : "off")"))
            }
            previous = (setting, lowPower)
        }
        for row in db.rows("select timestamp, LpmEnabled, Source from \(Self.lowPowerSource) where timestamp >= ? and timestamp < ?", a, b) {
            guard let t = row[0].double else { continue }
            let source = row[2].string.map { " (\($0))" } ?? ""
            events.append(SettingEvent(hour: hour(t), text: "Low Power Mode \((row[1].int ?? 0) != 0 ? "on" : "off")\(source)"))
        }
        if !events.isEmpty { report.events = events.sorted { $0.hour < $1.hour } }
        if let setting = db.scalar("select alwaysOnEnabledSetting from \(Self.alwaysOnState) where timestamp < ? and alwaysOnEnabledSetting is not null order by timestamp desc limit 1", a)?.int {
            report.aodAtStart = setting != 0
        }

        // Event-level detail (only kept for the last couple of days)
        if count("select count(*) from \(Self.backlight) where timestamp >= ? and timestamp < ?") > 0 {
            report.detail = eventDetail(start: a, end: b, captured: captured, hour: hour)
            report.tier = .detailed
        }

        if let notifications = notifications(start: a, end: b) {
            report.notifications = notifications.apps
            report.notificationsByHour = notifications.byHour
        }
        report.wakes = wakes(start: a, end: b)
        if let screen = report.detail?.screen {
            report.screenApps = screenApps(start: a, end: b, screen: screen)
        }
        report.brightness = brightness(start: a, end: b)
        report.temperature = temperature(start: a, end: b)
        return report
    }

    private func hourlyLanes(start a: Double, end b: Double, cpuNode: Int?, nodes: [Int: String]) -> HourlyLanes {
        func lane(_ sql: String, _ args: Any...) -> [Int] {
            var values = Array(repeating: 0.0, count: 24)
            for row in db.rows(sql, arguments: args) {
                guard let t = row[0].double, let v = row[1].double, v != 0 else { continue }
                let h = Int((t - a) / 3600)
                if (0..<24).contains(h) { values[h] += v }
            }
            return values.map { Int($0.rounded()) }
        }
        func rootLane(_ match: (String) -> Bool) -> [Int] {
            let ids = nodes.filter { match($0.value) }.keys.map(String.init).joined(separator: ",")
            guard !ids.isEmpty else { return Array(repeating: 0, count: 24) }
            return lane("select timestamp, Energy/1e3 from \(Self.rootEnergy) where timeInterval=3600 and RootNodeID in (\(ids)) and timestamp >= ? and timestamp < ?", a, b)
        }

        // Audio: the longest any app played in that hour, so overlapping apps aren't double counted.
        var audio = Array(repeating: 0, count: 24)
        for row in db.rows("select timestamp, max(BackgroundAudioPlayingTime) from \(Self.appRunTime) where timeInterval=3600 and timestamp >= ? and timestamp < ? group by timestamp", a, b) {
            guard let t = row[0].double, let v = row[1].double else { continue }
            let h = Int((t - a) / 3600)
            if (0..<24).contains(h) { audio[h] = max(audio[h], Int(v.rounded())) }
        }

        return HourlyLanes(
            screen: lane("select timestamp, ScreenOn from \(Self.usageTime) where timestamp >= ? and timestamp < ?", a, b),
            plugged: lane("select timestamp, PluggedIn from \(Self.usageTime) where timestamp >= ? and timestamp < ?", a, b),
            aod: lane("select timestamp, ScreenOnTime from \(Self.appRunTime) where timeInterval=3600 and BundleID=? and timestamp >= ? and timestamp < ?", ProcessNames.alwaysOnDisplay, a, b),
            audio: audio,
            keepAliveCellular: lane("select timestamp, Count from \(Self.keepAlive) where ConnectionType=0 and timestamp >= ? and timestamp < ?", a, b),
            keepAliveWiFi: lane("select timestamp, Count from \(Self.keepAlive) where ConnectionType=1 and timestamp >= ? and timestamp < ?", a, b),
            systemCPU: cpuNode.map { lane("select timestamp, Energy/1e3 from \(Self.rootEnergy) where timeInterval=3600 and NodeID=? and timestamp >= ? and timestamp < ?", $0, a, b) } ?? Array(repeating: 0, count: 24),
            total: lane("select timestamp, Energy/1e3 from \(Self.rootEnergy) where timeInterval=3600 and timestamp >= ? and timestamp < ?", a, b),
            modem: rootLane { $0.hasPrefix("BB") },
            wifi: rootLane { $0.hasPrefix("WiFi") },
            display: rootLane { $0.contains("Display") }
        )
    }

    private func eventDetail(start a: Double, end b: Double, captured: Double, hour: (Double) -> Double) -> EventDetail {
        // Screen intervals. Start a day early so a screen session spanning midnight is included.
        let states = db.rows("select timestamp, state from \(Self.backlight) where timestamp >= ? and timestamp < ? order by timestamp", a - 86400, b)
            .compactMap { row -> (Double, String)? in
                guard let t = row[0].double, let state = row[1].string else { return nil }
                return (t, state)
            }
        var screen: [HourRange] = []
        for (index, (t0, state)) in states.enumerated() {
            let t1 = index + 1 < states.count ? states[index + 1].0 : min(b, captured)
            if state == "active" || state == "activeDimmed", t1 > a, t1 - t0 > 5 {
                screen.append(HourRange(start: hour(max(t0, a)), end: hour(min(t1, b))))
            }
        }

        // Cellular technology changes, starting from the state carried in from before midnight.
        var radio: [RadioChange] = []
        var previous: String?
        for row in db.rows("select timestamp, dataInd from \(Self.registration) where dataInd in ('4G','5G','3G','LTE') and timestamp < ? order by timestamp", b) {
            guard let t = row[0].double, let technology = row[1].string, technology != previous else { continue }
            if t >= a {
                radio.append(RadioChange(hour: hour(t), technology: technology))
            } else if radio.isEmpty {
                radio = [RadioChange(hour: 0, technology: technology)]
            } else {
                radio[0] = RadioChange(hour: 0, technology: technology)
            }
            previous = technology
        }

        let data = db.rows("select cast(((timestamp+timestampEnd)/2 - ?)/900 as int) k, sum(WifiIn+WifiOut), sum(CellIn+CellOut) from \(Self.networkUsage) where timestamp >= ? and timestamp < ? group by k order by k", a, a, b)
            .compactMap { row -> DataBin? in
                guard let bin = row[0].int, (0..<96).contains(bin) else { return nil }
                return DataBin(bin: bin, wifiMB: round2((row[1].double ?? 0) / 1e6), cellularMB: round3((row[2].double ?? 0) / 1e6))
            }
        let bars = db.rows("select cast((timestamp - ?)/900 as int) k, avg(signalBars) from \(Self.telephonyActivity) where signalBars is not null and timestamp >= ? and timestamp < ? group by k", a, a, b)
            .compactMap { row -> SignalBin? in
                guard let bin = row[0].int, let value = row[1].double, (0..<96).contains(bin) else { return nil }
                return SignalBin(bin: bin, bars: (value * 10).rounded() / 10)
            }
        let dataApps = db.rows("select coalesce(nullif(BundleName,''), ProcessName) n, sum(WifiIn+WifiOut) w, sum(CellIn+CellOut) c from \(Self.networkUsage) where timestamp >= ? and timestamp < ? group by n order by w+c desc limit 8", a, b)
            .compactMap { row -> DataApp? in
                guard let name = row[0].string else { return nil }
                return DataApp(name: ProcessNames.name(for: name), wifiMB: ((row[1].double ?? 0) / 1e5).rounded() / 10, cellularMB: round2((row[2].double ?? 0) / 1e6))
            }
        return EventDetail(screen: screen, radio: radio, data: data, bars: bars, dataApps: dataApps)
    }

    // MARK: - Device facts

    /// Rated capacity, cycle count and Wh per percent from the most recent battery record.
    func batteryInfo() -> (info: BatteryInfo?, whPerPercent: Double?) {
        let table = "PLBatteryAgent_EventBackward_Battery"
        guard db.tableExists(table) else { return (nil, nil) }
        let columns = db.columns(of: table)
        let wanted = ["CycleCount", "DesignCapacity", "AppleRawMaxCapacity", "NominalChargeCapacity"]
        let selected = wanted.map { columns.contains($0) ? "\"\($0)\"" : "null" }.joined(separator: ", ")
        guard let row = db.rows("select \(selected) from \(table) order by timestamp desc limit 1").first else { return (nil, nil) }
        let info = BatteryInfo(cycleCount: row[0].int, designCapacity: row[1].int, maximumCapacity: row[2].int ?? row[3].int)
        // Lithium-ion cells in iPhones are rated at about 3.85 V nominal.
        let capacity = row[3].int ?? row[2].int
        let whPerPercent = capacity.map { Double($0) * 3.85 / 1000 / 100 }
        return (info, whPerPercent)
    }

    /// The OS build and device board from the power log's config table.
    func config() -> (build: String?, device: String?) {
        let table = "PLConfigAgent_EventNone_Config"
        guard db.tableExists(table) else { return (nil, nil) }
        let row = db.rows("select Build, Device from \(table) order by timestamp desc limit 1").first
        return (row?[0].string, row?[1].string)
    }

    // MARK: - Helpers

    private func pairs(_ rows: [SQLiteDatabase.Row]) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for row in rows {
            if let id = row[0].int, let value = row[1].double { result[id, default: 0] += value }
        }
        return result
    }

    private func round2(_ value: Double) -> Double { (value * 100).rounded() / 100 }
    private func round3(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
}
