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
            }
        }
    }
}
