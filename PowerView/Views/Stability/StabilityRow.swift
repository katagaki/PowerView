import SwiftUI

struct StabilityRow: View {
    let event: StabilityEvent
    let timeZone: TimeZone
    var showsDate = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.kind.systemImage)
                .foregroundStyle(event.kind.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.process)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(showsDate ? event.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: timeZone))
                                   : Format.time(event.date, in: timeZone))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(event.kind.title)
                    .font(.footnote)
                    .foregroundStyle(event.kind.tint)
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
