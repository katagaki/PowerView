import SwiftUI

struct AppListView: View {
    let day: DayReport
    let apps: [AppEnergy]
    let whPerPercent: Double
    @State private var sort = Sort.total

    enum Sort: String, CaseIterable, Identifiable {
        case total = "Total", screen = "On Screen", background = "Background"
        var id: Self { self }
    }

    private var sorted: [AppEnergy] {
        switch sort {
        case .total: apps.sorted { $0.total > $1.total }
        case .screen: apps.sorted { $0.screen > $1.screen }
        case .background: apps.sorted { $0.background > $1.background }
        }
    }

    var body: some View {
        let maxTotal = Double(apps.map(\.total).max() ?? 1)
        List {
            Section {
                Picker("Sort By", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                ForEach(sorted) { app in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(app.name)
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text("≈\(Int((Double(app.total) / 1000 / whPerPercent).rounded()))%")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            let width = proxy.size.width / maxTotal
                            HStack(spacing: 1) {
                                Capsule().fill(.blue).frame(width: max(0, Double(app.screen) * width))
                                Capsule().fill(.orange).frame(width: max(0, Double(app.background) * width))
                            }
                        }
                        .frame(height: 6)
                        Text(Self.usageLine(app))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(app.bundleID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("Blue is energy used while the display was on, orange while it was off. Percentages assume \(String(format: "%.1f", whPerPercent * 100)) Wh per full charge.")
            }
        }
        .navigationTitle("Apps & Processes")
        .navigationSubtitle(Format.shortDate(day))
        .navigationBarTitleDisplayMode(.inline)
    }

    static func usageLine(_ app: AppEnergy) -> String {
        var parts = [
            "\(Format.wh(Double(app.total) / 1000)) total",
            "\(Format.wh(Double(app.screen) / 1000)) on screen",
            "\(Format.wh(Double(app.background) / 1000)) background"
        ]
        if app.foregroundMinutes > 0 { parts.append("\(app.foregroundMinutes) min on screen") }
        if app.backgroundMinutes > 0 { parts.append("\(app.backgroundMinutes) min running in background") }
        if app.audioMinutes > 0 { parts.append("\(app.audioMinutes) min audio") }
        return parts.joined(separator: " · ")
    }
}
