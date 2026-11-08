import SwiftUI

/// Details that apply to the whole report rather than any one day.
struct ReportInfoView: View {
    let report: PowerReport
    @Environment(\.dismiss) private var dismiss

    private var meta: ReportMeta { report.meta }

    var body: some View {
        NavigationStack {
            List {
                if let battery = meta.battery {
                    Section {
                        if let cycles = battery.cycleCount {
                            LabeledContent("Cycle Count", value: cycles.formatted())
                        }
                        if let maximum = battery.maximumCapacity {
                            LabeledContent("Full Charge Capacity", value: "\(maximum.formatted()) mAh")
                        }
                        if let design = battery.designCapacity {
                            LabeledContent("Design Capacity", value: "\(design.formatted()) mAh")
                        }
                    } header: {
                        Text("Battery")
                    } footer: {
                        Text("As of \(meta.captured.formatted(date: .abbreviated, time: .shortened)).")
                    }
                }

                Section {
                    LabeledContent("Device", value: DeviceNames.displayName(meta.deviceName))
                    LabeledContent("Captured", value: captured)
                    LabeledContent("Source File", value: report.sourceName)
                } header: {
                    Text("Source")
                } footer: {
                    Text("From the power log. Energy figures are the system's own per-component estimates. Percentages assume \(Format.decimal(meta.whPerPercent * 100)) Wh per full charge.")
                }
            }
            .navigationTitle("About This Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
        }
    }

    private var captured: String {
        meta.captured.formatted(.dateTime.year().month().day().hour().minute().timeZone(.localizedGMT(.short)).locale(.current))
    }
}
