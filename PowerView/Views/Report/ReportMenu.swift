import SwiftUI

/// Screens covering every day in the report, reached from its toolbar.
enum ReportDestination: Hashable {
    case compare, charging, stability
}

/// The report's More menu, for what doesn't change with the selected day.
struct ReportMenu: View {
    let report: PowerReport
    let period: ReportPeriod
    @Binding var destination: ReportDestination?
    @Binding var isShowingInfo: Bool

    var body: some View {
        Menu {
            Section("All Days") {
                if report.days.count > 1 {
                    item("Compare Days", detail: period == .unplugged ? "Two stretches on battery side by side" : "Two days side by side",
                         systemImage: "square.split.2x1", destination: .compare)
                }
                if let sessions = report.charging {
                    item("Charging Habits", detail: Format.count(sessions.count, "session"),
                         systemImage: "bolt", destination: .charging)
                }
                if let events = report.stability {
                    item("Stability", detail: stabilitySummary(events), systemImage: "stethoscope", destination: .stability)
                }
            }
            Section {
                Button("About This Report", systemImage: "info.circle") { isShowingInfo = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private func item(_ title: String, detail: String, systemImage: String, destination: ReportDestination) -> some View {
        Button {
            self.destination = destination
        } label: {
            // Menus read the second Text as a subtitle only when it's directly in the button's label.
            Text(title)
            Text(detail)
            Image(systemName: systemImage)
        }
    }

    private func stabilitySummary(_ events: [StabilityEvent]) -> String {
        let crashes = events.filter { $0.kind == .crash }.count
        let kills = events.filter { $0.kind == .memoryKill }.count
        return events.isEmpty ? "No reports" : "\(Format.count(crashes, "crash", plural: "crashes")) · \(kills) closed for memory · \(Format.count(events.count, "report"))"
    }
}
