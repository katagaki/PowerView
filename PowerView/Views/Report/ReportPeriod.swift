import Foundation

/// Whether reports are split by calendar day or by each stretch on battery.
enum ReportPeriod: String, CaseIterable, Identifiable {
    case days = "Calendar Days"
    case unplugged = "Since Unplugged"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .days: "calendar"
        case .unplugged: "powerplug.portrait"
        }
    }

    /// The reports for this period, oldest first.
    func reports(in report: PowerReport) -> [DayReport] {
        switch self {
        case .days: report.days
        case .unplugged: report.unplugged ?? []
        }
    }
}
