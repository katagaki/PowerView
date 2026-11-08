import Foundation

nonisolated struct Highlight: Identifiable, Sendable {
    enum Kind: Sendable {
        case alwaysOn, onScreenApp, backgroundApp, standbyDrain, heavyBackground, notifications, wakes, temperature, cellularSwitching
    }

    let kind: Kind
    /// Text with `**bold**` runs.
    let text: String
    let score: Double
    var id: Kind { kind }
}

/// Picks a day's highlights by how much each finding cost and how unusual it was.
///
/// Energy findings are scored by their estimated share of the battery, multiplied by how far above
/// your usual they were (capped at 3×). Findings without an energy figure (notifications, wakes,
/// temperature, 5G/4G switching) only count when they're unusual and above a minimum count, and are
/// scored by that factor alone. "Usual" is the median across the other full days in the same sysdiagnose.
nonisolated enum HighlightRanker {

    /// At or above this, a finding is shown even when it's typical for you.
    static let alwaysShowPercent = 10.0
    /// Below this, an energy finding isn't worth a line.
    static let minimumPercent = 1.0
    /// How far above your median a value must be to count as unusual.
    static let unusualRatio = 1.25
    /// Below these, a context finding isn't worth a line, even with no other days to compare with.
    static let minimumNotifications = 20
    static let minimumWakes = 20
    static let minimumRadioSwitches = 10

    struct Comparison {
        /// 1 when typical, rising to 3 for far above usual.
        let factor: Double
        let isUnusual: Bool
        /// Nil when there weren't enough other days to compare with.
        let median: Double?

        /// "2.3× your usual", only when it's notably above.
        var note: String? {
            guard median != nil, factor >= HighlightRanker.unusualRatio else { return nil }
            return factor >= 3
                ? String(localized: "far above your usual", comment: "Added to the end of a highlight, after a comma.")
                : String(localized: "\(Format.decimal(factor))× your usual", comment: "Added to the end of a highlight, after a comma, e.g. 2.3× your usual.")
        }
    }

    static func highlights(for day: DayReport, in days: [DayReport], stability: [StabilityEvent],
                           whPerPercent: Double, limit: Int = 5) -> [Highlight] {
        let others = days.filter { $0.id != day.id && !$0.partial }
        var candidates: [Highlight] = []

        func percent(_ wh: Double) -> Double { wh / whPerPercent }
        func withNote(_ text: String, _ comparison: Comparison) -> String {
            comparison.note.map {
                String(localized: "highlight.withNote", defaultValue: "\(text), \($0)",
                       comment: "A highlight sentence, then how it compares with the usual, e.g. “Always-On Display used ≈12% of the battery, 2.3× your usual”.")
            } ?? text
        }
        func addEnergy(_ kind: Highlight.Kind, impact: Double, _ comparison: Comparison, _ text: String, showsNote: Bool = true) {
            guard impact >= minimumPercent, comparison.isUnusual || impact >= alwaysShowPercent else { return }
            candidates.append(Highlight(kind: kind, text: showsNote ? withNote(text, comparison) : text, score: impact * comparison.factor))
        }
        func addContext(_ kind: Highlight.Kind, _ comparison: Comparison, _ text: String) {
            guard comparison.isUnusual else { return }
            candidates.append(Highlight(kind: kind, text: withNote(text, comparison), score: comparison.factor))
        }

        // Always-On Display
        if let aod = day.aodEnergyWh, aod > 0 {
            let comparison = compare(aod, to: others.compactMap(\.aodEnergyWh))
            addEnergy(.alwaysOn, impact: percent(aod), comparison,
                      String(localized: "Always-On Display used **≈\(Int(percent(aod).rounded()))%** of the battery",
                             comment: "Highlight. Text between ** is shown in bold; keep the ** in the translation."))
        }

        // Biggest apps, compared with the same app on other days. The Always-On Display has its own line.
        let apps = (day.apps ?? []).filter { $0.bundleID != ProcessNames.alwaysOnDisplay }
        if let app = apps.max(by: { $0.screen < $1.screen }), app.screen > 0 {
            let wh = Double(app.screen) / 1000
            let baseline = others.compactMap { usual(\.screen, of: app.bundleID, on: $0) }
            let share = Int(percent(wh).rounded())
            addEnergy(.onScreenApp, impact: percent(wh), compare(wh, to: baseline), app.foregroundMinutes > 0
                ? String(localized: "**\(app.displayName)** used the most on screen: ≈\(share)% in \(Format.minutes(app.foregroundMinutes))",
                         comment: "Highlight: an app, its share of the battery and its time on screen. Text between ** is shown in bold; keep the ** in the translation.")
                : String(localized: "**\(app.displayName)** used the most on screen: ≈\(share)%",
                         comment: "Highlight: an app and its share of the battery. Text between ** is shown in bold; keep the ** in the translation."))
        }
        if let app = apps.max(by: { $0.background < $1.background }), app.background > 0 {
            let wh = Double(app.background) / 1000
            let baseline = others.compactMap { usual(\.background, of: app.bundleID, on: $0) }
            addEnergy(.backgroundApp, impact: percent(wh), compare(wh, to: baseline),
                      String(localized: "**\(app.displayName)** used the most in the background: ≈\(Int(percent(wh).rounded()))%",
                             comment: "Highlight: an app and its share of the battery. Text between ** is shown in bold; keep the ** in the translation."))
        }

        // Standby drain above your usual: the extra battery it cost is the impact.
        if let drain = day.drain, let rate = drain.screenOffPerHour {
            let comparison = compare(rate, to: others.compactMap { $0.drain?.screenOffPerHour })
            if let median = comparison.median, comparison.isUnusual {
                let extra = (rate - median) * drain.screenOffHours
                addEnergy(.standbyDrain, impact: extra, comparison,
                          String(localized: "Standby drain was **\(Format.percentPerHour(rate))** against your usual \(Format.percentPerHour(median)), costing ≈\(Int(extra.rounded()))% extra",
                                 comment: "Highlight: this day's rate, the usual rate, then the extra battery used. Text between ** is shown in bold; keep the ** in the translation."),
                          showsNote: false)
            }
        }

        // Apps iOS flagged for heavy background CPU or disk use. Always unusual; the impact is
        // that app's background energy where it can be matched.
        let flagged = stability.filter { $0.kind == .cpuLimit || $0.kind == .diskWriteLimit }
        if !flagged.isEmpty {
            let names = Array(Set(flagged.map(\.displayProcess))).sorted()
            let impact = Set(flagged.compactMap(\.bundleID)).reduce(0.0) { total, id in
                total + percent(Double(day.apps?.first { $0.bundleID == id }?.background ?? 0) / 1000)
            }
            let comparison = Comparison(factor: 2, isUnusual: true, median: nil)
            let text = String(localized: "**\(names.prefix(2).formatted(.list(type: .and)))** used heavy background CPU or disk",
                              comment: "Highlight: one or two app names. Text between ** is shown in bold; keep the ** in the translation.")
            candidates.append(Highlight(kind: .heavyBackground, text: text, score: max(impact, minimumPercent) * comparison.factor))
        }

        // Context findings, shown only when unusual for you
        if let apps = day.notifications, let top = apps.first,
           case let total = apps.reduce(0, { $0 + $1.count }), total >= minimumNotifications {
            let comparison = compare(Double(total), to: others.compactMap { $0.notifications.map { Double($0.reduce(0) { $0 + $1.count }) } })
            addContext(.notifications, comparison,
                       String(localized: "**\(total) notifications**, most from **\(top.displayName)** (\(top.count))",
                              comment: "Highlight: the day's notifications, then the app that sent the most and how many. Text between ** is shown in bold; keep the ** in the translation."))
        }
        if let wakes = day.wakes, wakes.total >= minimumWakes, let reason = wakes.reasons.first {
            let comparison = compare(Double(wakes.total), to: others.compactMap { $0.wakes.map { Double($0.total) } })
            addContext(.wakes, comparison,
                       String(localized: "Woke from sleep **\(wakes.total) times**, mostly for \(reason.inlineName)",
                              comment: "Highlight: the number of wakes, then the main cause, such as “scheduled timer”. Text between ** is shown in bold; keep the ** in the translation."))
        }
        if let peak = day.temperature?.bins.max(by: { $0.maximum < $1.maximum }), peak.maximum >= 35 {
            let comparison = compare(peak.maximum, to: others.compactMap { $0.temperature?.bins.map(\.maximum).max() })
            addContext(.temperature, comparison,
                       String(localized: "Battery peaked at **\(Format.celsius(peak.maximum))** around \(day.axis.clock(Double(peak.bin) / 4))",
                              comment: "Highlight: the highest temperature and the time it happened. Text between ** is shown in bold; keep the ** in the translation."))
        }
        if let detail = day.detail, detail.radio.count - 1 >= minimumRadioSwitches {
            let switches = Double(detail.radio.count - 1)
            let comparison = compare(switches, to: others.compactMap { $0.detail.map { Double(max(0, $0.radio.count - 1)) } })
            addContext(.cellularSwitching, comparison,
                       String(localized: "Switched between 5G and 4G **\(Int(switches)) times**",
                              comment: "Highlight. Text between ** is shown in bold; keep the ** in the translation."))
        }

        return Array(candidates.sorted { $0.score > $1.score }.prefix(limit))
    }

    /// An app's energy (Wh) on another day. App lists only hold the biggest consumers, so an app
    /// that isn't listed used at most as much as the smallest listed one; that's used as its estimate.
    private static func usual(_ value: KeyPath<AppEnergy, Int>, of bundleID: String, on day: DayReport) -> Double? {
        guard let apps = day.apps, !apps.isEmpty else { return nil }
        let mWh = apps.first { $0.bundleID == bundleID }?[keyPath: value] ?? apps.map { $0[keyPath: value] }.min() ?? 0
        return Double(mWh) / 1000
    }

    /// Compares a value with the median of the same measure on other days.
    static func compare(_ value: Double, to baseline: [Double]) -> Comparison {
        guard baseline.count >= 2 else { return Comparison(factor: 1, isUnusual: true, median: nil) }
        let sorted = baseline.sorted()
        let median = sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        guard median > 0 else {
            return Comparison(factor: value > 0 ? 3 : 1, isUnusual: value > 0, median: median)
        }
        let ratio = value / median
        return Comparison(factor: min(3, max(1, ratio)), isUnusual: ratio >= unusualRatio, median: median)
    }
}
