import SwiftUI

/// A day's diagnostic events inside the day report.
struct DayStabilitySection: View {
    let report: PowerReport
    let day: DayReport

    var body: some View {
        let events = (report.stability ?? [])
            .filter { Format.dayKey($0.date, in: report.meta.timeZone) == day.date }
            .sorted { ($0.kind.severity, $1.date) < ($1.kind.severity, $0.date) }
        if !events.isEmpty {
            Section {
                ForEach(events.prefix(5)) { event in
                    StabilityRow(event: event, timeZone: report.meta.timeZone)
                }
                NavigationLink(events.count > 5 ? "All \(events.count) Reports" : "Diagnostics for All Days") {
                    StabilityView(report: report)
                }
            } header: {
                Text("Stability")
            }
        }
    }
}
