import SwiftUI

struct DayCell: View {
    let day: DayReport
    let maxUsed: Double
    let isSelected: Bool

    var body: some View {
        let used = day.stats.used
        VStack(spacing: 3) {
            Text(Format.weekday(day))
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            Text(Format.dayNumber(day))
                .font(.body.weight(.semibold))
                .monospacedDigit()
            Capsule()
                .fill(isSelected ? .white.opacity(0.3) : Color(.tertiarySystemFill))
                .frame(width: 6, height: 26)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(isSelected ? .white : meterColor(used))
                        .frame(width: 6, height: max(3, 26 * min(1, used / maxUsed)))
                }
            Text("\(Int(used.rounded()))%")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            Circle()
                .fill(tierColor)
                .frame(width: 5, height: 5)
        }
        .frame(width: 46)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? .white : .primary)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.longDate(day)), \(Int(used.rounded())) percent used, \(day.tier.title)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var tierColor: Color {
        if isSelected { return .white }
        switch day.tier {
        case .detailed: return .green
        case .hourly: return .blue
        case .daily: return .gray
        case .battery: return .clear
        }
    }

    private func meterColor(_ used: Double) -> Color {
        used >= 80 ? .red : used >= 50 ? .orange : .green
    }
}
