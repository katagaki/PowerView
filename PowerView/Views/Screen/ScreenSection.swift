import Charts
import SwiftUI

/// Which app was on screen, how bright the screen was and how bright the room was.
struct ScreenSection: View {
    let day: DayReport
    @State private var selection: Double?

    /// Colors for the apps with the most screen time; everything else is gray.
    private static let palette: [Color] = [.blue, .orange, .purple, .pink, .teal, .yellow]

    private var colors: [String: Color] {
        let top = (day.screenApps?.totals ?? []).filter { !Self.isSystem($0.appID) }.prefix(Self.palette.count)
        return Dictionary(uniqueKeysWithValues: zip(top.map(\.appID), Self.palette))
    }

    private static func isSystem(_ appID: String) -> Bool {
        appID == "com.apple.lock-screen" || appID == "com.apple.springboard.home-screen"
    }

    private var highlight: ClosedRange<Double>? {
        selection.map { (($0 * 4).rounded(.down) / 4)...(($0 * 4).rounded(.down) / 4 + 0.25) }
    }

    var body: some View {
        if day.screenApps != nil || day.brightness != nil {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    if let timeline = day.screenApps {
                        LaneChart(title: "App on Screen", total: day.screenOnSeconds.map(Format.hours(fromSeconds:)), height: 22,
                                  highlight: highlight, selection: $selection) {
                            ForEach(timeline.segments.indices, id: \.self) { index in
                                let segment = timeline.segments[index]
                                LaneBar(start: segment.start, end: max(segment.end, segment.start + 0.02), value: 1,
                                        style: colors[segment.appID] ?? Color.gray.opacity(0.45))
                            }
                        }
                    }
                    if let bins = day.brightness {
                        let peak = max(100, bins.map(\.nits).max() ?? 100)
                        LaneChart(title: "Screen Brightness", total: "avg \(Int(averageNits(bins))) nits", height: 36, domainMax: peak,
                                  highlight: highlight, selection: $selection) {
                            ForEach(bins, id: \.bin) { bin in
                                LaneBar(start: Double(bin.bin) / 4, end: Double(bin.bin + 1) / 4 - 0.02, value: bin.nits, style: Color.yellow.gradient)
                            }
                        }
                        let luxBins = bins.filter { ($0.lux ?? 0) > 0 }
                        if !luxBins.isEmpty {
                            let luxPeak = max(100, luxBins.compactMap(\.lux).max() ?? 100)
                            LaneChart(title: "Ambient Light", total: "peak \(Int(luxPeak)) lux", height: 28, domainMax: luxPeak, showsAxis: true,
                                      highlight: highlight, selection: $selection) {
                                ForEach(luxBins, id: \.bin) { bin in
                                    LaneBar(start: Double(bin.bin) / 4, end: Double(bin.bin + 1) / 4 - 0.02, value: bin.lux ?? 0, style: Color.gray.gradient)
                                }
                            }
                        }
                    }
                    legend
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) {
                    if selection != nil {
                        selectionCard
                    }
                }
                .animation(.easeOut(duration: 0.15), value: selection == nil)

                if let totals = day.screenApps?.totals {
                    let maxMinutes = totals.first?.minutes ?? 1
                    ForEach(totals.prefix(5)) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent(app.name, value: Format.duration(app.minutes * 60))
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(colors[app.appID] ?? Color.gray.opacity(0.45))
                                    .frame(width: max(4, proxy.size.width * app.minutes / maxMinutes))
                            }
                            .frame(height: 5)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Screen")
            } footer: {
                Text("Touch and hold a lane to see what was on screen. Brightness is the screen's actual output in nits; higher brightness is one of the biggest causes of screen-on drain.")
            }
        }
    }

    @ViewBuilder
    private var legend: some View {
        let entries = (day.screenApps?.totals ?? []).filter { colors[$0.appID] != nil }
        if !entries.isEmpty {
            FlowLegend(items: entries.map { ($0.name, colors[$0.appID]!) } + [("Other", Color.gray.opacity(0.45))])
        }
    }

    private func averageNits(_ bins: [BrightnessBin]) -> Double {
        bins.map(\.nits).reduce(0, +) / Double(max(1, bins.count))
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let selection {
                let bin = min(95, max(0, Int(selection * 4)))
                let brightness = day.brightness?.first { $0.bin == bin }
                let app = day.screenApps?.segments.last { $0.start <= selection && $0.end >= selection }
                Text(Format.clock(selection))
                    .font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 3) {
                    row("On Screen", app.map { ProcessNames.name(for: $0.appID) } ?? "Screen off")
                    row("Brightness", brightness.map { "\(Int($0.nits)) nits (max \(Int($0.maxNits)))" } ?? "—")
                    row("Ambient Light", brightness?.lux.map { "\(Int($0)) lux" } ?? "—")
                }
            }
        }
        .inspectorCardStyle()
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name)
            Text(value)
                .monospacedDigit()
                .fontWeight(.semibold)
                .gridColumnAlignment(.trailing)
        }
        .font(.footnote)
    }
}
