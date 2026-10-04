import SwiftUI

struct NotificationListView: View {
    let day: DayReport
    let apps: [NotificationApp]

    var body: some View {
        List(apps) { app in
            LabeledContent {
                VStack(alignment: .trailing) {
                    Text(app.count.formatted())
                        .monospacedDigit()
                    if app.wokePhone > 0 {
                        Text("\(app.wokePhone) woke the phone")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } label: {
                Text(app.name)
                Text(app.bundleID)
                    .font(.caption2.monospaced())
            }
        }
        .navigationTitle("Notifications")
        .navigationSubtitle(Format.shortDate(day))
        .navigationBarTitleDisplayMode(.inline)
    }
}
