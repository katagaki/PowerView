import SwiftUI

/// Pills that switch the report between everything, one hardware component and one app.
/// Components and apps are each picked from a dropdown, whose pill shows the current pick.
struct FocusPills: View {
    let options: FocusOptions
    @Binding var focus: ReportFocus

    private var selectedHardware: String? {
        if case .hardware(let name) = focus { name } else { nil }
    }

    private var selectedApp: FocusApp? {
        if case .app(let bundleID) = focus { options.apps.first { $0.bundleID == bundleID } } else { nil }
    }

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.snappy) { focus = .overall }
                    } label: {
                        pillLabel(String(localized: "Overall", comment: "A pill that shows the whole report, not one component or app."),
                                  systemImage: "square.grid.2x2", isSelected: focus == .overall, hasMenu: false)
                    }
                    .buttonStyle(.plain)
                    .glassPill(isSelected: focus == .overall)
                    .accessibilityAddTraits(focus == .overall ? .isSelected : [])

                    if !options.hardware.isEmpty {
                        hardwareMenu
                    }
                    if !options.apps.isEmpty {
                        appsMenu
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .scrollIndicators(.hidden)
        // Horizontal scroll views otherwise grow to fill all vertical space.
        .fixedSize(horizontal: false, vertical: true)
        .sensoryFeedback(.selection, trigger: focus)
    }

    private var hardwareMenu: some View {
        Menu {
            Picker(String(localized: "Hardware", comment: "Hardware components, such as the display and the cellular modem."), selection: selection) {
                ForEach(options.hardware, id: \.self) { name in
                    Label {
                        Text(ComponentEnergy.displayName(for: name))
                        Text(Format.wh(options.hardwareEnergy[name] ?? 0, digits: 1))
                    } icon: {
                        Image(systemName: ComponentEnergy.systemImage(for: name))
                    }
                    .tag(ReportFocus.hardware(name))
                }
            }
        } label: {
            pillLabel(selectedHardware.map(ComponentEnergy.shortName(for:)) ?? String(localized: "Hardware", comment: "Hardware components, such as the display and the cellular modem."),
                      systemImage: selectedHardware.map(ComponentEnergy.systemImage(for:)) ?? "cpu",
                      isSelected: selectedHardware != nil, hasMenu: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassPill(isSelected: selectedHardware != nil)
    }

    private var appsMenu: some View {
        Menu {
            Picker(String(localized: "Apps & Processes"), selection: selection) {
                ForEach(options.apps) { app in
                    Label {
                        Text(app.displayName)
                        Text(Format.wh(Double(app.total) / 1000, digits: 1))
                    } icon: {
                        EmptyView()
                    }
                    .tag(ReportFocus.app(app.bundleID))
                }
            }
        } label: {
            pillLabel(selectedApp?.displayName ?? String(localized: "Apps & Processes"),
                      systemImage: selectedApp == nil ? "square.stack.3d.up" : nil,
                      isSelected: selectedApp != nil, hasMenu: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassPill(isSelected: selectedApp != nil)
    }

    /// Picking from a dropdown animates the switch, like tapping a pill.
    private var selection: Binding<ReportFocus> {
        Binding { focus } set: { value in withAnimation(.snappy) { focus = value } }
    }

    private func pillLabel(_ title: String, systemImage: String?, isSelected: Bool, hasMenu: Bool) -> some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(title)
                .lineLimit(1)
            if hasMenu {
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .font(.caption.weight(.bold))
                    .opacity(0.7)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(.capsule)
    }
}

private extension View {
    func glassPill(isSelected: Bool) -> some View {
        glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
    }
}
