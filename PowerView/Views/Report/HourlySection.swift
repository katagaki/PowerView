import SwiftUI

struct HourlySection: View {
    let day: DayReport

    var body: some View {
        if let hourly = day.hourly {
            Section {
                HourlyLanesView(day: day, hourly: hourly)
            } header: {
                Text("Hour by Hour")
            } footer: {
                Text(footer)
            }
        }
    }

    private var footer: String {
        let footer = "Touch and hold any lane on this page, then drag to inspect it. Shaded hours were mostly plugged in."
        guard day.stretch != nil else { return footer }
        return footer + " Hourly records cover whole hours, so the first and last hours can include time on the charger."
    }
}
