import Foundation

/// Notifications, wakes, temperature and charging sessions.
nonisolated extension PowerLogAnalyzer {

    private static let notificationTable = "PLSpringBoardAgent_Aggregate_SBNotifications_Aggregate"
    private static let powerStateTable = "PLSleepWakeAgent_EventForward_PowerState"
    private static let wakeReasonTable = "PLSleepWakeAgent_EventForward_PowerState_Array_Reason"
    private static let batteryDetailTable = "PLBatteryAgent_EventBackward_Battery"
    private static let thermalModelTable = "BatteryIntelligence_ThermalModel_Sample_7_2"
    private static let chargingTable = "PLBatteryAgent_EventInterval_Charging"
    private static let adapterTable = "PLBatteryAgent_EventForward_AdapterDetails"

    // MARK: - Notifications

    func notifications(start a: Double, end b: Double, hours: Int = 24) -> (apps: [NotificationApp], byHour: [Int])? {
        let rows = db.rows("""
            select timestamp, NotificationBundleID, Count, coalesce(BgWakingCount, 0) + coalesce(FgWakingCount, 0)
            from \(Self.notificationTable) where timestamp >= ? and timestamp < ?
            """, a, b)
        guard !rows.isEmpty else { return nil }
        var byHour = Array(repeating: 0, count: hours)
        var totals: [String: (count: Int, woke: Int)] = [:]
        for row in rows {
            guard let t = row[0].double, let bundleID = row[1].string, let count = row[2].int, count > 0 else { continue }
            let hour = Int((t - a) / 3600)
            if (0..<hours).contains(hour) { byHour[hour] += count }
            totals[bundleID, default: (0, 0)].count += count
            totals[bundleID, default: (0, 0)].woke += row[3].int ?? 0
        }
        let apps = totals
            .map { NotificationApp(bundleID: $0.key, name: ProcessNames.name(for: $0.key), count: $0.value.count, wokePhone: $0.value.woke) }
            .sorted { $0.count > $1.count }
        return apps.isEmpty ? nil : (apps, byHour)
    }

    // MARK: - Wakes

    /// Wakes from sleep, grouped by hour and by the hardware that triggered them.
    func wakes(start a: Double, end b: Double, from s: Double? = nil, hours: Int = 24) -> WakeSummary? {
        guard db.tableExists(Self.powerStateTable) else { return nil }
        let s = s ?? a
        let wakes = db.rows("select ID, timestamp from \(Self.powerStateTable) where Event = 0 and timestamp >= ? and timestamp < ?", s, b)
        guard !wakes.isEmpty else { return nil }
        var reasonsByWake: [Int: [String]] = [:]
        for row in db.rows("""
            select r.FK_ID, r.value from \(Self.wakeReasonTable) r join \(Self.powerStateTable) p on p.ID = r.FK_ID
            where p.Event = 0 and p.timestamp >= ? and p.timestamp < ?
            """, s, b) {
            if let id = row[0].int, let value = row[1].string { reasonsByWake[id, default: []].append(value) }
        }
        var byHour = Array(repeating: 0, count: hours)
        var reasons: [String: Int] = [:]
        for row in wakes {
            guard let id = row[0].int, let t = row[1].double else { continue }
            let hour = Int((t - a) / 3600)
            if (0..<hours).contains(hour) { byHour[hour] += 1 }
            reasons[Self.wakeCategory(reasonsByWake[id] ?? []), default: 0] += 1
        }
        return WakeSummary(byHour: byHour, reasons: reasons.map { WakeReason(name: $0.key, count: $0.value) }.sorted { $0.count > $1.count })
    }

    /// Reduces the raw interrupt names to the most specific cause.
    private static func wakeCategory(_ reasons: [String]) -> String {
        let lowered = reasons.map { $0.lowercased() }
        func has(_ needle: String) -> Bool { lowered.contains { $0.contains(needle) } }
        if has("multi-touch") || has("hold") || has("gesture") || has("button") || has("dock") { return "Touch, Button or Raise" }
        if has("baseband") { return "Cellular" }
        if has("wlan") { return "Wi-Fi" }
        if has("bluetooth") { return "Bluetooth" }
        if has("wifibt") { return "Wi-Fi or Bluetooth" }
        if has("rtc") { return "Scheduled Timer" }
        return "Other"
    }

    // MARK: - Temperature

    /// Battery temperature in 15-minute bins. Uses the continuous battery log where kept,
    /// otherwise the sparser thermal model samples recorded around charging.
    func temperature(start a: Double, end b: Double, from s: Double? = nil, hours: Int = 24) -> TemperatureSeries? {
        func bins(_ sql: String) -> [TemperatureBin] {
            db.rows(sql, a, s ?? a, b).compactMap { row in
                guard let bin = row[0].int, (0..<hours * 4).contains(bin), let average = row[1].double, let maximum = row[2].double,
                      average > 0, average < 80 else { return nil }
                return TemperatureBin(bin: bin, average: (average * 10).rounded() / 10, maximum: (maximum * 10).rounded() / 10)
            }
        }
        let continuous = bins("""
            select cast((timestamp - ?) / 900 as int) k, avg(Temperature), max(Temperature)
            from \(Self.batteryDetailTable) where Temperature is not null and timestamp >= ? and timestamp < ? group by k
            """)
        if continuous.count >= 8 { return TemperatureSeries(bins: continuous, isSparse: false) }
        let sparse = bins("""
            select cast((timestamp - ?) / 900 as int) k, avg(Temp), max(Temp)
            from \(Self.thermalModelTable) where Temp is not null and timestamp >= ? and timestamp < ? group by k
            """)
        return sparse.isEmpty ? nil : TemperatureSeries(bins: sparse, isSparse: true)
    }

    // MARK: - Charging

    /// Charging sessions across the whole log. Intervals less than 5 minutes apart are merged,
    /// since a phone briefly lifted off a charger logs several intervals.
    func chargingSessions() -> [ChargingSession] {
        let intervals = db.rows("select timestamp, timestampEnd from \(Self.chargingTable) where timestampEnd > timestamp order by timestamp")
            .compactMap { row -> (Double, Double)? in
                guard let start = row[0].double, let end = row[1].double else { return nil }
                return (start, end)
            }
        var merged: [(Double, Double)] = []
        for interval in intervals {
            if let last = merged.last, interval.0 - last.1 < 300 {
                merged[merged.count - 1].1 = max(last.1, interval.1)
            } else {
                merged.append(interval)
            }
        }
        let levels = db.rows("select timestamp, Level from PLBatteryAgent_EventBackward_BatteryUI order by timestamp")
            .compactMap { row -> (Double, Int)? in
                guard let t = row[0].double, let level = row[1].double else { return nil }
                return (t, Int(level.rounded()))
            }
        let adapters = db.tableExists(Self.adapterTable)
            ? db.rows("select timestamp, Watts, isWireless from \(Self.adapterTable) where Watts > 0 order by timestamp")
            : []

        return merged.filter { $0.1 - $0.0 >= 120 }.map { start, end in
            let inside = levels.filter { $0.0 >= start - 300 && $0.0 <= end + 300 }
            var secondsAtFull = 0.0
            for (previous, sample) in zip(inside, inside.dropFirst()) where previous.1 >= 100 && previous.0 >= start {
                secondsAtFull += min(sample.0, end) - previous.0
            }
            let sessionAdapters = adapters.filter { ($0[0].double ?? 0) >= start - 60 && ($0[0].double ?? 0) <= end }
            return ChargingSession(
                start: Date(timeIntervalSince1970: start),
                end: Date(timeIntervalSince1970: end),
                startLevel: inside.first?.1,
                endLevel: inside.last?.1,
                minutesAtFull: max(0, Int(secondsAtFull / 60)),
                watts: sessionAdapters.compactMap { $0[1].int }.max(),
                isWireless: sessionAdapters.last.flatMap { $0[2].int }.map { $0 != 0 }
            )
        }
    }
}

// MARK: - Screen

nonisolated extension PowerLogAnalyzer {

    private static let screenStateTable = "PLScreenStateAgent_EventForward_ScreenState"
    private static let displayTable = "PLDisplayAgent_EventForward_Display"

    /// Which app was in front during each screen-on interval.
    func screenApps(start a: Double, end b: Double, from s: Double? = nil, hours: Int = 24, screen: [HourRange]) -> ScreenAppTimeline? {
        guard !screen.isEmpty, db.tableExists(Self.screenStateTable) else { return nil }
        // Role 5 is Picture in Picture: a floating video over another app, not the app on screen.
        let mainScreen = db.columns(of: Self.screenStateTable).contains("AppRole")
            ? "Display = 0 and coalesce(AppRole, 1) != 5" : "Display = 0"
        // Include the last change before the start so the first interval has an app.
        let changes = db.rows("""
            select timestamp, bundleID from \(Self.screenStateTable)
            where \(mainScreen) and bundleID is not null and timestamp < ?
              and timestamp >= coalesce((select max(timestamp) from \(Self.screenStateTable) where \(mainScreen) and timestamp < ?), ?)
            order by timestamp
            """, b, s ?? a, s ?? a)
            .compactMap { row -> (Double, String)? in
                guard let t = row[0].double, let id = row[1].string else { return nil }
                return ((t - a) / 3600, ProcessNames.screenGroup(for: id))
            }
        guard !changes.isEmpty else { return nil }

        var segments: [AppSegment] = []
        for interval in screen {
            for (index, change) in changes.enumerated() {
                let changeEnd = index + 1 < changes.count ? changes[index + 1].0 : Double(hours)
                let start = max(interval.start, change.0), end = min(interval.end, changeEnd)
                guard end - start > 2.0 / 3600 else { continue }
                if let last = segments.last, last.appID == change.1, start - last.end < 1.0 / 60 {
                    segments[segments.count - 1].end = end
                } else {
                    segments.append(AppSegment(start: start, end: end, appID: change.1))
                }
            }
        }
        var minutes: [String: Double] = [:]
        for segment in segments { minutes[segment.appID, default: 0] += (segment.end - segment.start) * 60 }
        let totals = minutes.map { ScreenAppTotal(appID: $0.key, name: ProcessNames.name(for: $0.key), minutes: ($0.value * 10).rounded() / 10) }
            .sorted { $0.minutes > $1.minutes }
        return segments.isEmpty ? nil : ScreenAppTimeline(segments: segments, totals: totals)
    }

    /// Display brightness in nits and ambient light, averaged over 15 minutes while the screen was lit.
    func brightness(start a: Double, end b: Double, from s: Double? = nil, hours: Int = 24) -> [BrightnessBin]? {
        guard db.tableExists(Self.displayTable) else { return nil }
        let bins = db.rows("""
            select cast((timestamp - ?) / 900 as int) k, avg(mNits) / 1000, max(mNits) / 1000, avg(case when lux >= 0 then lux end)
            from \(Self.displayTable) where mNits > 0 and timestamp >= ? and timestamp < ? group by k
            """, a, s ?? a, b)
            .compactMap { row -> BrightnessBin? in
                guard let bin = row[0].int, (0..<hours * 4).contains(bin), let nits = row[1].double, let maxNits = row[2].double else { return nil }
                return BrightnessBin(bin: bin, nits: nits.rounded(), maxNits: maxNits.rounded(), lux: row[3].double.map { $0.rounded() })
            }
        return bins.isEmpty ? nil : bins
    }
}
