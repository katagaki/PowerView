import SwiftUI

struct HourlySection: View {
    let day: DayReport

    var body: some View {
        if let hourly = day.hourly {
            Section {
                HourlyLanesView(day: day, hourly: hourly)
            } header: {
                Text("Hour by Hour")
            }
        }
    }
}
