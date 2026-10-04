import SwiftUI

/// Every diagnostic report in the sysdiagnose, filterable by kind.
struct StabilityView: View {
    let report: PowerReport
    @State private var filter: StabilityEvent.Kind?

    private var events: [StabilityEvent] { report.stability ?? [] }
    private var filtered: [StabilityEvent] { events.filter { filter == nil || $0.kind == filter } }

    var body: some View {
        let tz = report.meta.timeZone
        List {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(StabilityEvent.Kind.allCases, id: \.self) { kind in
                        let count = events.filter { $0.kind == kind }.count
                        if count > 0 {
                            Button {
                                withAnimation { filter = filter == kind ? nil : kind }
                            } label: {
                                KindTile(kind: kind, count: count, isSelected: filter == kind)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("Heavy CPU use and disk writes are reported when an app works far harder than iOS expects in the background, and usually cost battery. Memory limit warnings are common and often harmless.")
            }

            let byProcess = Dictionary(grouping: filtered, by: \.process).map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
            if byProcess.count > 1 {
                Section("Most Reports") {
                    ForEach(byProcess.prefix(5), id: \.0) { name, count in
                        LabeledContent(name, value: count.formatted())
                    }
                }
            }

            let days = Dictionary(grouping: filtered) { Format.dayKey($0.date, in: tz) }.sorted { $0.key > $1.key }
            ForEach(days, id: \.key) { key, dayEvents in
                Section(dayTitle(key, events: dayEvents)) {
                    ForEach(dayEvents) { event in
                        StabilityRow(event: event, timeZone: tz)
                    }
                }
            }
        }
        .overlay {
            if events.isEmpty {
                ContentUnavailableView("No Reports", systemImage: "checkmark.seal",
                                       description: Text("This sysdiagnose has no crash, hang or memory reports."))
            }
        }
        .navigationTitle("Stability")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if filter != nil {
                Button("Show All") { withAnimation { filter = nil } }
            }
        }
    }

    private func dayTitle(_ key: String, events: [StabilityEvent]) -> String {
        let date = events.first?.date ?? .now
        return date.formatted(Date.FormatStyle(date: .complete, time: .omitted, timeZone: report.meta.timeZone))
    }
}
