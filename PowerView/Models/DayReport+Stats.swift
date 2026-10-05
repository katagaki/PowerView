import Foundation

nonisolated struct BatteryStats: Sendable {
    var used: Double
    var hoursOnBattery: Double
    var charged: Double
    var lowest: Int?
}

nonisolated extension DayReport {

    var stats: BatteryStats {
        var used = 0.0, onBattery = 0.0, charged = 0.0
        for (previous, sample) in zip(battery, battery.dropFirst()) {
            let delta = Double(sample.level - previous.level)
            let elapsed = sample.hour - previous.hour
            if delta < 0 { used -= delta } else { charged += delta }
            if !previous.charging && elapsed < 0.5 && (delta < 0 || previous.level < 100) { onBattery += elapsed }
        }
        return BatteryStats(used: used, hoursOnBattery: onBattery, charged: charged, lowest: battery.map(\.level).min())
    }

    var dateValue: Date? { DayReport.date(fromKey: date) }

    /// Parses a `yyyy-MM-dd` day key as midnight UTC, so it formats back to the same calendar date.
    static func date(fromKey key: String) -> Date? { parser.date(from: key) }

    /// Screen-on time in seconds: exact from backlight events where kept, otherwise from hourly usage.
    var screenOnSeconds: Double? {
        if let detail { return detail.screen.reduce(0) { $0 + ($1.end - $1.start) * 3600 } }
        if let hourly, hasUsageTime { return Double(hourly.screen.reduce(0, +)) }
        return nil
    }

    var alwaysOnSeconds: Double? { hourly.map { Double($0.aod.reduce(0, +)) } }

    /// Share of the day's energy used while the display was off.
    var backgroundShare: Double? {
        guard let energyWh, let screenEnergyWh, energyWh > 0 else { return nil }
        return 1 - screenEnergyWh / energyWh
    }

    var topOnScreenApp: AppEnergy? { apps?.max { $0.screen < $1.screen } }
    var topBackgroundApp: AppEnergy? { apps?.max { $0.background < $1.background } }

    /// Battery percentage lost in each hour.
    var hourlyDrain: [Double] {
        let hours = axis.hours
        var out = Array(repeating: 0.0, count: hours)
        for (previous, sample) in zip(battery, battery.dropFirst()) where sample.level < previous.level {
            out[min(hours - 1, max(0, Int(sample.hour)))] += Double(previous.level - sample.level)
        }
        return out
    }

    func isScreenOn(at hour: Double) -> Bool? {
        detail.map { $0.screen.contains { hour >= $0.start && hour <= $0.end } }
    }

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

nonisolated extension HourlyLanes {
    var wifiShare: Double? {
        let cellular = keepAliveCellular.reduce(0, +), wifi = keepAliveWiFi.reduce(0, +)
        return cellular + wifi > 0 ? Double(wifi) / Double(cellular + wifi) : nil
    }

    func connection(at hour: Int) -> String {
        let cellular = keepAliveCellular[hour], wifi = keepAliveWiFi[hour], total = cellular + wifi
        guard total > 0 else { return "—" }
        let share = Double(wifi) / Double(total)
        return share >= 0.6 ? "Mostly Wi-Fi" : share > 0.15 ? "Mixed" : "Cellular"
    }
}

/// How fast the battery drained with the screen off and on, and what that means for a full charge.
nonisolated struct DrainBreakdown: Sendable {
    /// Percent per hour while the screen was off (standby).
    var screenOffPerHour: Double?
    /// Percent per hour while the screen was on, including the standby baseline.
    var screenOnPerHour: Double?
    /// Percent per hour across all time on battery.
    var overallPerHour: Double
    var screenOnHours: Double
    var screenOffHours: Double
    /// True when based on exact screen events; false when estimated from hourly screen time.
    var isExact: Bool

    var screenShare: Double { screenOnHours / max(0.01, screenOnHours + screenOffHours) }
    var fullChargeHours: Double { 100 / overallPerHour }
    var fullChargeScreenOnHours: Double? { screenOnPerHour.map { 100 / $0 } }
    var fullChargeStandbyHours: Double? { screenOffPerHour.map { 100 / $0 } }
}

nonisolated extension DayReport {

    /// Least-squares fit of drop = onRate × screen-on time + offRate × screen-off time.
    /// Returns nil unless the result is physically sensible (screen on drains faster than standby).
    private static func fitRates(_ slices: [(drop: Double, on: Double, off: Double)]) -> (on: Double, off: Double)? {
        let ss = slices.reduce(0) { $0 + $1.on * $1.on }, oo = slices.reduce(0) { $0 + $1.off * $1.off }
        let so = slices.reduce(0) { $0 + $1.on * $1.off }
        let ds = slices.reduce(0) { $0 + $1.drop * $1.on }, dO = slices.reduce(0) { $0 + $1.drop * $1.off }
        let determinant = ss * oo - so * so
        guard abs(determinant) > 1e-6 else { return nil }
        let onRate = (ds * oo - dO * so) / determinant, offRate = (ss * dO - so * ds) / determinant
        return offRate > 0 && onRate > offRate ? (onRate, offRate) : nil
    }

    /// Splits on-battery drain into screen-off and screen-on rates. Screen-off periods give the
    /// standby rate directly; the screen-on rate is what's left of the total once standby is removed.
    var drain: DrainBreakdown? {
        struct Slice { var drop: Double; var on: Double; var off: Double }
        var slices: [Slice] = []
        var isExact = false

        if let detail {
            isExact = true
            for (previous, sample) in zip(battery, battery.dropFirst()) {
                let elapsed = sample.hour - previous.hour
                guard !previous.charging, !sample.charging, elapsed > 0, elapsed < 0.5 else { continue }
                let on = detail.screen.reduce(0) { $0 + max(0, min($1.end, sample.hour) - max($1.start, previous.hour)) }
                slices.append(Slice(drop: Double(max(0, previous.level - sample.level)), on: on, off: elapsed - on))
            }
        } else if let hourly, hasUsageTime {
            let drain = hourlyDrain
            for hour in 0..<min(drain.count, hourly.plugged.count) {
                let charging = battery.contains { Int($0.hour) == hour && $0.charging }
                let samples = battery.filter { Int($0.hour) == hour }
                guard hourly.plugged[hour] < 300, !charging, samples.count >= 6 else { continue }
                let on = min(1, Double(hourly.screen[hour]) / 3600)
                slices.append(Slice(drop: drain[hour], on: on, off: 1 - on))
            }
        }

        let drop = slices.reduce(0) { $0 + $1.drop }
        let on = slices.reduce(0) { $0 + $1.on }, off = slices.reduce(0) { $0 + $1.off }
        guard drop > 0, on + off >= 1 else { return nil }

        // Standby rate from periods with the screen essentially off.
        let standby = slices.filter { $0.on <= 0.05 * ($0.on + $0.off) }
        let standbyHours = standby.reduce(0) { $0 + $1.off + $1.on }
        var offRate = standbyHours >= 1 ? standby.reduce(0) { $0 + $1.drop } / standbyHours : nil
        var onRate: Double?
        if let offRate, on >= 0.25 {
            onRate = max(offRate, (drop - offRate * off) / on)
        } else if on >= 0.25, let fit = Self.fitRates(slices.map { ($0.drop, $0.on, $0.off) }) {
            // Busy days may have no screen-off stretch long enough; fit both rates across all periods instead.
            (onRate, offRate) = fit
        }
        return DrainBreakdown(screenOffPerHour: offRate, screenOnPerHour: onRate, overallPerHour: drop / (on + off),
                              screenOnHours: on, screenOffHours: off, isExact: isExact)
    }
}
