import Charts
import SwiftUI

private let wokeLabel = "Woke the Phone"
private let quietLabel = "Delivered Quietly"

/// Which apps sent notifications, and how often the phone woke from sleep.
struct NotificationsSection: View {
    let day: DayReport

    var body: some View {
        if day.notifications != nil || day.wakes != nil {
            Section {
                if let apps = day.notifications {
                    let top = Array(apps.prefix(6))
                    Text("\(apps.reduce(0) { $0 + $1.count }) notifications · \(apps.reduce(0) { $0 + $1.wokePhone }) woke the phone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .listRowSeparator(.hidden)
                    Chart(top) { app in
                        BarMark(x: .value("Notifications", app.wokePhone), y: .value("App", app.name))
                            .foregroundStyle(by: .value("Kind", wokeLabel))
                        BarMark(x: .value("Notifications", max(0, app.count - app.wokePhone)), y: .value("App", app.name))
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
                    .chartYAxis { AxisMarks(preset: .extended, position: .leading) { _ in AxisValueLabel(horizontalSpacing: 8) } }
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
                            LabeledContent(reason.name) {
                                Text("\(reason.count)")
                                    .monospacedDigit()
                            }
                        }
                    } label: {
                        LabeledContent("Wakes from Sleep") {
                            Text("\(wakes.total) · \(wakes.total / 24) per hour")
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                Text("Notifications & Wakes")
            } footer: {
                Text("Frequent wakes with the screen off drain the battery even when you're not using the phone.")
            }
        }
    }
}
