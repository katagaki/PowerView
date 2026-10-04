import Foundation

/// The few fields the report list needs, saved next to each report so the list can load
/// without decoding every report's day-by-day data.
nonisolated struct ReportSummary: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var importedAt: Date
    var sourceName: String
    var deviceName: String
    var build: String?
    var captured: Date
    var dayCount: Int
    /// `yyyy-MM-dd` keys of the first and last day, matching `DayReport.date`.
    var firstDay: String?
    var lastDay: String?

    init(report: PowerReport) {
        id = report.id
        importedAt = report.importedAt
        sourceName = report.sourceName
        deviceName = report.meta.deviceName
        build = report.meta.build
        captured = report.meta.captured
        dayCount = report.days.count
        firstDay = report.days.first?.date
        lastDay = report.days.last?.date
    }
}
