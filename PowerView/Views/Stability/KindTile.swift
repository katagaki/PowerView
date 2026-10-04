import SwiftUI

struct KindTile: View {
    let kind: StabilityEvent.Kind
    let count: Int
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: kind.systemImage)
                Spacer()
                Text("\(count)")
                    .monospacedDigit()
            }
            .font(.title2.weight(.semibold))
            .foregroundStyle(isSelected ? .white : kind.tint)
            Text(kind.pluralTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AnyShapeStyle(kind.tint) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                    in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
