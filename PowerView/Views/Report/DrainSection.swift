import SwiftUI

/// How long a full charge would last at the day's screen-off and screen-on drain rates.
struct DrainSection: View {
    let drain: DrainBreakdown

    var body: some View {
        Section {
            LabeledContent {
                Text(Self.duration(drain.fullChargeHours))
            } label: {
                Text("At This Day's Pace")
                Text("≈\(Self.duration(drain.fullChargeHours * drain.screenShare)) of it with the screen on")
            }
            if let hours = drain.fullChargeScreenOnHours {
                LabeledContent {
                    Text(Self.duration(hours))
                } label: {
                    Text("Screen On Continuously")
                    Text("Using it without a break")
                }
            }
            if let hours = drain.fullChargeStandbyHours {
                LabeledContent {
                    Text(hours >= 48 ? String(localized: "\(Format.decimal(hours / 24)) days", comment: "A length of time in days, e.g. 2.5 days.") : Self.duration(hours))
                } label: {
                    Text("Standby Only")
                    Text("Screen off the whole time")
                }
            }
        } header: {
            Text("Full Charge Would Last")
        }
        .monospacedDigit()
    }

    static func duration(_ hours: Double) -> String {
        hours >= 10 ? Format.hours(whole: Int(hours.rounded())) : Format.hours(hours)
    }
}
