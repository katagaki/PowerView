import SwiftUI

struct SettingChangesSection: View {
    let day: DayReport

    var body: some View {
        if let events = day.events {
            Section("Setting Changes") {
                ForEach(events) { event in
                    LabeledContent(event.text, value: day.axis.clock(event.hour))
                        .monospacedDigit()
                }
            }
        }
    }
}
