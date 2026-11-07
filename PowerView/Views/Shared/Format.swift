import Foundation

nonisolated enum Format {
    /// `hour` is hours since midnight, e.g. 13.5 → "13:30". Always 24-hour, whatever the locale prefers,
    /// so chart axes and the times in the text around them match.
    static func clock(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded())
        return String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// One decimal place by default, e.g. 3.14 → "3.1", with the locale's decimal separator.
    static func decimal(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).grouping(.never))
    }

    /// The unit shown beside a number of hours, when the two are styled separately.
    static var hoursUnit: String {
        String(localized: "h", comment: "Short unit for hours, shown after a number in a large metric tile.")
    }

    /// The unit shown beside a drain rate, when the two are styled separately.
    static var percentPerHourUnit: String {
        String(localized: "unit.percentPerHour", defaultValue: "%/h",
               comment: "Short unit for battery percent per hour, shown after a number in a large metric tile.")
    }

    static func hours(_ hours: Double) -> String {
        String(localized: "\(decimal(hours)) h", comment: "A length of time in hours, e.g. 3.1 h.")
    }

    static func hours(whole hours: Int) -> String {
        String(localized: "\(hours) h", comment: "A whole number of hours, e.g. 12 h.")
    }

    static func hours(fromSeconds seconds: Double) -> String {
        hours(seconds / 3600)
    }

    static func minutes(_ minutes: Int) -> String {
        String(localized: "\(minutes) min", comment: "A length of time in minutes, e.g. 45 min.")
    }

    static func minutes(fromSeconds seconds: Double) -> String {
        minutes(Int((seconds / 60).rounded()))
    }

    /// A drain rate, e.g. "1.2%/h".
    static func percentPerHour(_ value: Double) -> String {
        String(localized: "\(decimal(value))%/h", comment: "A battery drain rate in percent per hour, e.g. 1.2%/h.")
    }

    static func wh(_ value: Double, digits: Int = 2) -> String {
        "\(decimal(value, digits: digits)) Wh"
    }

    static func megabytes(_ value: Double) -> String {
        value >= 1000 ? "\(decimal(value / 1000)) GB" : "\(Int(value.rounded())) MB"
    }

    static func megabytes(_ value: Double, digits: Int) -> String {
        "\(decimal(value, digits: digits)) MB"
    }

    static func nits(_ value: Double) -> String {
        String(localized: "\(Int(value)) nits", comment: "Screen brightness in nits.")
    }

    static func lux(_ value: Double) -> String {
        String(localized: "\(Int(value)) lux", comment: "Ambient light level in lux.")
    }

    static func celsius(_ value: Double) -> String {
        "\(decimal(value)) °C"
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
        // From the key, since a date style adds "日" to the number in Japanese and Chinese.
        Int(day.date.suffix(2)).map(String.init) ?? ""
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
        guard minutes >= 60 else { return self.minutes(minutes) }
        return String(localized: "\(minutes / 60) h \(minutes % 60) min", comment: "A length of time in hours and minutes, e.g. 2 h 5 min.")
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
