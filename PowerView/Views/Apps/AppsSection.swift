import SwiftUI

struct AppsSection: View {
    let day: DayReport
    let whPerPercent: Double

    var body: some View {
        if let apps = day.apps {
            Section {
                AppsChartView(apps: apps)
                NavigationLink("All Apps & Processes") {
                    AppListView(day: day, apps: apps, whPerPercent: whPerPercent)
                }
            } header: {
                Text("What Drained the Battery")
            } footer: {
                Text(day.tier == .daily ? "Covers 08:00 to 08:00 the next day." : "“On screen” is energy the system tags as display-on, which includes the Always-On Display.")
            }
        }
    }
}
