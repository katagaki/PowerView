import Foundation

/// A day-by-day power report built from one sysdiagnose.
nonisolated struct PowerReport: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var importedAt: Date
    var sourceName: String
    var meta: ReportMeta
    var days: [DayReport]
    /// Charging sessions across the whole log.
    var charging: [ChargingSession]?
    /// Crashes, memory kills and other diagnostic reports in the archive.
    var stability: [StabilityEvent]?

    static func == (lhs: PowerReport, rhs: PowerReport) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

nonisolated struct ReportMeta: Codable, Sendable {
    /// Time of the last battery sample in the log.
    var captured: Date
    var deviceName: String
    var productType: String?
    var build: String?
    /// Offset of the device's time zone when the sysdiagnose was taken.
    var timeZoneOffset: Int
    /// Energy per 1% of battery, from the battery's rated capacity.
    var whPerPercent: Double
    var battery: BatteryInfo?

    var timeZone: TimeZone { TimeZone(secondsFromGMT: timeZoneOffset) ?? .current }
}

nonisolated struct BatteryInfo: Codable, Sendable {
    var cycleCount: Int?
    var designCapacity: Int?
    var maximumCapacity: Int?

    var healthPercent: Int? {
        guard let designCapacity, let maximumCapacity, designCapacity > 0 else { return nil }
        return min(100, Int((Double(maximumCapacity) / Double(designCapacity) * 100).rounded()))
    }
}

/// How much detail the power log still kept for a day. Older days are summarised more coarsely.
nonisolated enum DetailTier: String, Codable, Sendable {
    case detailed, hourly, daily, battery

    var title: String {
        switch self {
        case .detailed: "Event Detail"
        case .hourly: "Hourly"
        case .daily: "Daily Totals"
        case .battery: "Battery Only"
        }
    }

    var explanation: String {
        switch self {
        case .detailed: "Hourly records plus second-by-second screen on/off, 5G/4G changes and data use."
        case .hourly: "Hourly records are available. Second-by-second network and screen events weren't kept this far back."
        case .daily: "Only daily totals were kept for this day, covering 08:00 to 08:00 the next morning, trimmed to the biggest consumers."
        case .battery: "Only the battery level was kept for this day."
        }
    }
}

nonisolated struct DayReport: Codable, Identifiable, Sendable {
    /// `yyyy-MM-dd` in the device's time zone.
    var date: String
    var battery: [BatterySample]
    var tier: DetailTier
    var components: [ComponentEnergy]?
    var energyWh: Double?
    var apps: [AppEnergy]?
    var screenEnergyWh: Double?
    var aodEnergyWh: Double?
    var hourly: HourlyLanes?
    var hasUsageTime: Bool
    var hasKeepAlive: Bool
    var events: [SettingEvent]?
    var aodAtStart: Bool?
    var detail: EventDetail?
    var partial: Bool
    /// Notifications per app, most first.
    var notifications: [NotificationApp]?
    /// Notifications delivered in each hour.
    var notificationsByHour: [Int]?
    /// Times the phone woke from sleep, only kept for the last couple of days.
    var wakes: WakeSummary?
    var temperature: TemperatureSeries?
    /// Which app was on screen, only kept for the last couple of days.
    var screenApps: ScreenAppTimeline?
    var brightness: [BrightnessBin]?

    var id: String { date }
}

/// `hour` is hours since local midnight.
nonisolated struct BatterySample: Codable, Sendable {
    var hour: Double
    var level: Int
    var charging: Bool
}

nonisolated struct ComponentEnergy: Codable, Sendable, Identifiable {
    var name: String
    var wh: Double
    var id: String { name }
}

/// Energy values are in mWh.
nonisolated struct AppEnergy: Codable, Sendable, Identifiable {
    var bundleID: String
    var name: String
    var total: Int
    var screen: Int
    var background: Int
    var foregroundMinutes: Int
    var backgroundMinutes: Int
    var audioMinutes: Int
    var id: String { bundleID }
}

/// 24 values per lane. Times are in seconds, energy in mWh, keep-alives are counts.
nonisolated struct HourlyLanes: Codable, Sendable {
    var screen: [Int]
    var plugged: [Int]
    var aod: [Int]
    var audio: [Int]
    var keepAliveCellular: [Int]
    var keepAliveWiFi: [Int]
    var systemCPU: [Int]
    var total: [Int]
    var modem: [Int]
    var wifi: [Int]
    var display: [Int]
}

nonisolated struct SettingEvent: Codable, Sendable, Identifiable {
    var hour: Double
    var text: String
    var id: String { "\(hour)-\(text)" }
}

nonisolated struct EventDetail: Codable, Sendable {
    /// Screen-on intervals in hours since midnight.
    var screen: [HourRange]
    /// Cellular radio technology changes.
    var radio: [RadioChange]
    /// Data use in 15-minute bins (MB).
    var data: [DataBin]
    /// Average signal bars in 15-minute bins.
    var bars: [SignalBin]
    var dataApps: [DataApp]
}

nonisolated struct HourRange: Codable, Sendable {
    var start: Double
    var end: Double
}

nonisolated struct RadioChange: Codable, Sendable {
    var hour: Double
    var technology: String
}

nonisolated struct DataBin: Codable, Sendable {
    var bin: Int
    var wifiMB: Double
    var cellularMB: Double
}

nonisolated struct SignalBin: Codable, Sendable {
    var bin: Int
    var bars: Double
}

nonisolated struct DataApp: Codable, Sendable, Identifiable {
    var name: String
    var wifiMB: Double
    var cellularMB: Double
    var id: String { name }
}

nonisolated struct NotificationApp: Codable, Sendable, Identifiable {
    var bundleID: String
    var name: String
    var count: Int
    /// Notifications that woke the phone while on battery.
    var wokePhone: Int
    var id: String { bundleID }
}

nonisolated struct WakeSummary: Codable, Sendable {
    var byHour: [Int]
    var reasons: [WakeReason]
    var total: Int { byHour.reduce(0, +) }
}

nonisolated struct WakeReason: Codable, Sendable, Identifiable {
    var name: String
    var count: Int
    var id: String { name }
}

nonisolated struct TemperatureSeries: Codable, Sendable {
    /// Readings grouped into 15-minute bins.
    var bins: [TemperatureBin]
    /// True when the readings were only taken around charging, so there are gaps.
    var isSparse: Bool
}

nonisolated struct TemperatureBin: Codable, Sendable {
    var bin: Int
    var average: Double
    var maximum: Double
}

nonisolated struct ChargingSession: Codable, Sendable, Identifiable {
    var start: Date
    var end: Date
    var startLevel: Int?
    var endLevel: Int?
    /// Minutes spent plugged in at 100%.
    var minutesAtFull: Int
    var watts: Int?
    var isWireless: Bool?
    var id: Date { start }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

nonisolated struct StabilityEvent: Codable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case crash, memoryKill, cpuLimit, diskWriteLimit, memoryLimit, hang, accessoryCrash, panic
    }

    var date: Date
    var kind: Kind
    var process: String
    var bundleID: String?
    var detail: String?
    var id: String { "\(date.timeIntervalSince1970)-\(kind.rawValue)-\(process)" }
}

nonisolated struct ScreenAppTimeline: Codable, Sendable {
    /// Consecutive on-screen periods, in hours since midnight.
    var segments: [AppSegment]
    /// Total minutes on screen per app, most first.
    var totals: [ScreenAppTotal]
}

nonisolated struct AppSegment: Codable, Sendable {
    var start: Double
    var end: Double
    var appID: String
}

nonisolated struct ScreenAppTotal: Codable, Sendable, Identifiable {
    var appID: String
    var name: String
    var minutes: Double
    var id: String { appID }
}

/// Screen brightness in a 15-minute bin, only while the screen was lit.
nonisolated struct BrightnessBin: Codable, Sendable {
    var bin: Int
    var nits: Double
    var maxNits: Double
    /// Ambient light the sensor measured.
    var lux: Double?
}
