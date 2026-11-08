import SwiftUI

/// Horizontally scrolling pills that switch the report between everything, one hardware component and one app.
struct FocusPills: View {
    let options: FocusOptions
    @Binding var focus: ReportFocus

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        pill(.overall, title: String(localized: "Overall", comment: "A pill that shows the whole report, not one component or app."),
                             systemImage: "square.grid.2x2")
                        if !options.hardware.isEmpty {
                            separator
                            ForEach(options.hardware, id: \.self) { name in
                                pill(.hardware(name), title: ComponentEnergy.shortName(for: name),
                                     systemImage: ComponentEnergy.systemImage(for: name))
                            }
                        }
                        if !options.apps.isEmpty {
                            separator
                            ForEach(options.apps) { app in
                                pill(.app(app.bundleID), title: app.displayName, systemImage: nil)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
            .scrollIndicators(.hidden)
            // Horizontal scroll views otherwise grow to fill all vertical space.
            .fixedSize(horizontal: false, vertical: true)
            .onAppear { proxy.scrollTo(focus, anchor: .center) }
            .onChange(of: focus) { _, focus in
                withAnimation(.snappy) { proxy.scrollTo(focus, anchor: .center) }
            }
        }
        .sensoryFeedback(.selection, trigger: focus)
    }

    private var separator: some View {
        Capsule()
            .fill(.separator)
            .frame(width: 1, height: 20)
    }

    private func pill(_ value: ReportFocus, title: String, systemImage: String?) -> some View {
        let isSelected = focus == value
        return Button {
            withAnimation(.snappy) { focus = value }
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
        .id(value)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
