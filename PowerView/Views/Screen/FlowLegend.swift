import SwiftUI

/// A wrapping row of colored legend entries.
struct FlowLegend: View {
    let items: [(String, Color)]

    var body: some View {
        FlowLayout(spacing: 12, lineSpacing: 6) {
            ForEach(items, id: \.0) { name, color in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                    Text(name)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
