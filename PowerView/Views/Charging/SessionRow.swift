import SwiftUI

struct SessionRow: View {
    let session: ChargingSession
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.start.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: timeZone)))
                    .font(.body.weight(.semibold))
                Spacer()
                if let start = session.startLevel, let end = session.endLevel {
                    Text("\(start)% → \(end)%")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
            }
            HStack {
                Text("\(Format.time(session.start, in: timeZone))–\(Format.time(session.end, in: timeZone)) · \(Format.duration(session.duration))")
                Spacer()
                if let watts = session.watts {
                    Label("\(watts) W\(session.isWireless == true ? " wireless" : "")", systemImage: session.isWireless == true ? "wave.3.up" : "cable.connector")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            if session.minutesAtFull > 0 {
                Text("Held at 100% for \(Format.duration(Double(session.minutesAtFull) * 60))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
