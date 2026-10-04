import Foundation

nonisolated enum Format {
    /// `hour` is hours since midnight, e.g. 13.5 → "13:30".
    static func clock(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded())
        return String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    static func hours(fromSeconds seconds: Double) -> String {
        String(format: "%.1f h", seconds / 3600)
    }

    static func minutes(fromSeconds seconds: Double) -> String {
        "\(Int((seconds / 60).rounded())) min"
    }

    static func wh(_ value: Double, digits: Int = 2) -> String {
        String(format: "%.\(digits)f Wh", value)
    }

    static func megabytes(_ value: Double) -> String {
        value >= 1000 ? String(format: "%.1f GB", value / 1000) : "\(Int(value.rounded())) MB"
    }

    static func shortDate(_ day: DayReport) -> String {
        shortDate(dayKey: day.date)
    }

    static func shortDate(dayKey: String) -> String {
        DayReport.date(fromKey: dayKey)?.formatted(utcStyle(month: .abbreviated, day: .defaultDigits, weekday: .abbreviated)) ?? dayKey
    }

    static func longDate(_ day: DayReport) -> String {
        day.dateValue?.formatted(utcStyle(month: .wide, day: .defaultDigits, weekday: .wide, year: .defaultDigits)) ?? day.date
    }

    static func weekday(_ day: DayReport) -> String {
        day.dateValue?.formatted(utcStyle(weekday: .abbreviated)) ?? ""
    }

    static func dayNumber(_ day: DayReport) -> String {
        day.dateValue?.formatted(utcStyle(day: .defaultDigits)) ?? ""
    }

    /// The `yyyy-MM-dd` key of the day containing `date` in the device's time zone, matching `DayReport.date`.
    static func dayKey(_ date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Hours since local midnight in the device's time zone.
    static func hourOfDay(_ date: Date, in timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    static func time(_ date: Date, in timeZone: TimeZone) -> String {
        clock(hourOfDay(date, in: timeZone))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    static func range(of summary: ReportSummary) -> String {
        guard let first = summary.firstDay, let last = summary.lastDay else { return "" }
        return "\(shortDate(dayKey: first)) – \(shortDate(dayKey: last))"
    }

    /// Day strings are calendar dates, so they're parsed and displayed in UTC to avoid shifting.
    private static func utcStyle(month: Date.FormatStyle.Symbol.Month? = nil, day: Date.FormatStyle.Symbol.Day? = nil,
                                 weekday: Date.FormatStyle.Symbol.Weekday? = nil, year: Date.FormatStyle.Symbol.Year? = nil) -> Date.FormatStyle {
        var style = Date.FormatStyle(timeZone: TimeZone(secondsFromGMT: 0)!)
        if let year { style = style.year(year) }
        if let month { style = style.month(month) }
        if let day { style = style.day(day) }
        if let weekday { style = style.weekday(weekday) }
        return style
    }
}
