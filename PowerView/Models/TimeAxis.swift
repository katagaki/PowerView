import Foundation

/// The hours a report's charts cover: midnight to midnight for a day, or from the hour
/// it was unplugged in until it was plugged in again for a stretch on battery.
nonisolated struct TimeAxis: Sendable {
    var hours = 24
    /// Local hour of day that hour 0 falls on.
    var startHour = 0

    var domain: ClosedRange<Double> { 0...Double(hours) }

    /// Axis labels on round clock hours, closer together for short stretches and further apart for long ones.
    var marks: [Double] {
        let step = hours <= 4 ? 1 : hours <= 12 ? 3 : hours <= 30 ? 6 : hours <= 60 ? 12 : 24
        let first = (step - startHour % step) % step
        return stride(from: first, through: hours, by: step).map(Double.init)
    }

    /// The time of day `hour` hours after hour 0.
    func clock(_ hour: Double) -> String { Format.clock(Double(startHour) + hour) }
}

nonisolated extension DayReport {

    var axis: TimeAxis {
        stretch.map { TimeAxis(hours: $0.hours, startHour: $0.startHour) } ?? TimeAxis()
    }

    /// The date, plus the time it was unplugged for a stretch on battery.
    var title: String {
        guard let stretch else { return Format.shortDate(self) }
        return "\(Format.shortDate(self)), \(axis.clock(stretch.start))"
    }

    /// Whether `date` falls in this day, or in this stretch on battery.
    func contains(_ date: Date, timeZone: TimeZone) -> Bool {
        guard let stretch else { return Format.dayKey(date, in: timeZone) == self.date }
        return date >= stretch.unplugged && date < (stretch.pluggedIn ?? .distantFuture)
    }
}
