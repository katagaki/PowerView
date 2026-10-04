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
                    Text(hours >= 48 ? String(format: "%.1f days", hours / 24) : Self.duration(hours))
                } label: {
                    Text("Standby Only")
                    Text("Screen off the whole time")
                }
            }
        } header: {
            Text("Full Charge Would Last")
        } footer: {
            Text(drain.isExact
                 ? "From 100% to 0%, based on this day's drain with the screen on and off."
                 : "From 100% to 0%. Approximate, because only hourly screen time was kept for this day.")
        }
        .monospacedDigit()
    }

    static func duration(_ hours: Double) -> String {
        hours >= 10 ? "\(Int(hours.rounded())) h" : String(format: "%.1f h", hours)
    }
}
