import Charts
import SwiftUI

private let wokeLabel = String(localized: "Woke the Phone", comment: "Notifications that woke the phone.")
private let quietLabel = String(localized: "Delivered Quietly", comment: "Notifications that didn't wake the phone.")

/// Which apps sent notifications, and how often the phone woke from sleep.
struct NotificationsSection: View {
    let day: DayReport

    var body: some View {
        if day.notifications != nil || day.wakes != nil {
            Section {
                if let apps = day.notifications {
                    let top = Array(apps.prefix(6))
                    Text(verbatim: summary(apps))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .listRowSeparator(.hidden)
                    Chart(top) { app in
                        BarMark(x: .value("Notifications", app.wokePhone), y: .value("App", app.displayName))
                            .foregroundStyle(by: .value("Kind", wokeLabel))
                        BarMark(x: .value("Notifications", max(0, app.count - app.wokePhone)), y: .value("App", app.displayName))
                            .foregroundStyle(by: .value("Kind", quietLabel))
                            .annotation(position: .trailing, spacing: 4) {
                                Text("\(app.count)")
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .chartForegroundStyleScale([wokeLabel: Color.red, quietLabel: Color.gray.opacity(0.5)])
                    .chartLegend(position: .top, alignment: .leading)
                    .chartYAxis { AxisMarks(preset: .extended, position: .leading) { _ in AxisValueLabel(centered: true, horizontalSpacing: 8) } }
                    .chartXScale(range: .plotDimension(endPadding: 32))
                    .frame(height: CGFloat(top.count) * 30 + 50)
                    .padding(.bottom, 8)

                    if apps.count > top.count {
                        NavigationLink("All \(apps.count) Apps") {
                            NotificationListView(day: day, apps: apps)
                        }
                    }
                }
                if let wakes = day.wakes {
                    DisclosureGroup {
                        ForEach(wakes.reasons) { reason in
                            LabeledContent(reason.displayName) {
                                Text("\(reason.count)")
                                    .monospacedDigit()
                            }
                        }
                    } label: {
                        LabeledContent("Wakes from Sleep") {
                            Text("\(wakes.total) · \(Format.decimal(Double(wakes.total) / Double(max(1, day.axis.hours)))) per hour")
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                Text("Notifications & Wakes")
            }
        }
    }

    private func summary(_ apps: [NotificationApp]) -> String {
        let total = apps.reduce(0) { $0 + $1.count }, woke = apps.reduce(0) { $0 + $1.wokePhone }
        return "\(String(localized: "\(total) notifications", comment: "A number of notifications.")) · \(String(localized: "\(woke) woke the phone", comment: "How many notifications woke the phone."))"
    }
}
