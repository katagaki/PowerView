import SwiftUI

struct ReportRow: View {
    let summary: ReportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DeviceNames.displayName(summary.deviceName))
                    .font(.headline)
                if let build = summary.build {
                    Text(build)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text("Captured \(summary.captured.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
            Text(verbatim: "\(String(localized: "\(summary.dayCount) days", comment: "A number of days in a report.")) · \(Format.range(of: summary))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
