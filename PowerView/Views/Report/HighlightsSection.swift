import SwiftUI

struct HighlightsSection: View {
    let day: DayReport
    let report: PowerReport
    /// The days or stretches on battery to compare with.
    let others: [DayReport]
    let stabilityEvents: [StabilityEvent]

    var body: some View {
        let items = HighlightRanker.highlights(for: day, in: others, stability: stabilityEvents,
                                               whPerPercent: report.meta.whPerPercent)
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    Label {
                        Text((try? AttributedString(markdown: item.text)) ?? AttributedString(item.text))
                    } icon: {
                        Image(systemName: Self.icon(for: item.kind))
                            .foregroundStyle(Self.tint(for: item.kind))
                    }
                }
            } header: {
                Text("Highlights")
            } footer: {
                Text("Ranked by how much battery each cost. Lines that are typical for your other days are left out unless they cost a lot.")
            }
        }
    }

    private static func icon(for kind: Highlight.Kind) -> String {
        switch kind {
        case .alwaysOn: "clock.badge"
        case .onScreenApp: "hand.tap.fill"
        case .backgroundApp: "gearshape.2.fill"
        case .standbyDrain: "moon.zzz.fill"
        case .heavyBackground: "cpu"
        case .notifications: "bell.badge.fill"
        case .wakes: "alarm.fill"
        case .temperature: "thermometer.high"
        case .cellularSwitching: "antenna.radiowaves.left.and.right"
        }
    }

    private static func tint(for kind: Highlight.Kind) -> Color {
        switch kind {
        case .alwaysOn: .purple
        case .onScreenApp: .blue
        case .backgroundApp, .heavyBackground, .temperature: .orange
        case .standbyDrain, .wakes: .indigo
        case .notifications: .red
        case .cellularSwitching: .green
        }
    }
}
