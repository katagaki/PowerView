import SwiftUI

struct ReportRow: View {
    let report: PowerReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(report.meta.deviceName)
                    .font(.headline)
                if let build = report.meta.build {
                    Text(build)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text("Captured \(report.meta.captured.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
            Text("\(report.days.count) days · \(Format.range(of: report))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
