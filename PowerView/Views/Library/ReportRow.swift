import SwiftUI

struct ReportRow: View {
    let summary: ReportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(summary.deviceName)
                    .font(.headline)
                if let build = summary.build {
                    Text(build)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            Text("Captured \(summary.captured.formatted(date: .abbreviated, time: .shortened))")
                .font(.subheadline)
            Text("\(summary.dayCount) days · \(Format.range(of: summary))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
