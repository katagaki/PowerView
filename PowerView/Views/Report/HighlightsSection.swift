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
                        Text(Self.attributed(item.text))
                    } icon: {
                        Image(systemName: Self.icon(for: item.kind))
                            .foregroundStyle(Self.tint(for: item.kind))
                    }
                }
            } header: {
                Text("Highlights")
            }
        }
    }

    /// Bolds the `**bold**` runs. Not parsed as Markdown, which won't close a bold run after punctuation
    /// directly followed by a letter, as in "**約12%**を", and would treat "_" in app names as markup.
    private static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in text.components(separatedBy: "**").enumerated() {
            var run = AttributedString(part)
            if !index.isMultiple(of: 2) { run.inlinePresentationIntent = .stronglyEmphasized }
            result += run
        }
        return result
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
