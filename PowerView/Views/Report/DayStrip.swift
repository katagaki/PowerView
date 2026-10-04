import SwiftUI

/// A floating Liquid Glass strip of days, each with a small meter showing how much battery was used.
struct DayStrip: View {
    let days: [DayReport]
    @Binding var selection: Int
    @Namespace private var selectionNamespace

    private let cornerRadius: CGFloat = 30
    private let inset: CGFloat = 6

    var body: some View {
        let maxUsed = max(1, days.map(\.stats.used).max() ?? 1)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 2) {
                    ForEach(days.indices, id: \.self) { index in
                        DayCell(day: days[index], maxUsed: maxUsed, isSelected: index == selection)
                            .background {
                                if index == selection {
                                    // Concentric with the container: its radius minus the inset.
                                    RoundedRectangle(cornerRadius: cornerRadius - inset, style: .continuous)
                                        .fill(.tint)
                                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                                }
                            }
                            .id(index)
                            .onTapGesture { selection = index }
                    }
                }
                .padding(inset)
                // Slides the selection pill to the tapped day.
                .animation(.snappy, value: selection)
            }
            .scrollIndicators(.hidden)
            // Horizontal scroll views otherwise grow to fill all vertical space.
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, index in
                withAnimation(.snappy) { proxy.scrollTo(index, anchor: .center) }
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
