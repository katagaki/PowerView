import SwiftUI

/// Pills that switch the report between everything, one hardware component, one app and one system process.
/// Each kind is picked from a dropdown, whose pill shows the current pick.
struct FocusPills: View {
    let options: FocusOptions
    @Binding var focus: ReportFocus

    private var selectedHardware: String? {
        if case .hardware(let name) = focus { name } else { nil }
    }

    private var selectedApp: FocusApp? {
        if case .app(let bundleID) = focus { options.app(bundleID) } else { nil }
    }

    var body: some View {
        // Sits at the leading edge, and scrolls when the row doesn't fit.
        ScrollView(.horizontal) {
            row(showsIcons: true)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: focus)
    }

    private func row(showsIcons: Bool) -> some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.snappy) { focus = .overall }
                } label: {
                    pillLabel(String(localized: "Overall", comment: "A pill that shows the whole report, not one component or app."),
                              systemImage: showsIcons ? "square.grid.2x2" : nil, isSelected: focus == .overall, hasMenu: false)
                }
                .buttonStyle(.plain)
                .glassPill(isSelected: focus == .overall)
                .accessibilityAddTraits(focus == .overall ? .isSelected : [])

                if !options.hardware.isEmpty {
                    hardwareMenu(showsIcon: showsIcons)
                }
                if !options.apps.isEmpty {
                    appMenu(options.apps, title: String(localized: "Apps", comment: "Apps someone opens, as opposed to parts of iOS. Shown in a small pill, so keep it short."),
                            systemImage: showsIcons ? "square.grid.3x3.fill" : nil, isSystem: false)
                }
                if !options.systemProcesses.isEmpty {
                    appMenu(options.systemProcesses, title: String(localized: "System", comment: "The operating system, in place of an app name."),
                            systemImage: showsIcons ? "gearshape.2" : nil, isSystem: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func hardwareMenu(showsIcon: Bool) -> some View {
        Menu {
            ForEach(options.hardware, id: \.self) { name in
                menuItem(.hardware(name), title: ComponentEnergy.displayName(for: name),
                         wh: options.hardwareEnergy[name] ?? 0, systemImage: ComponentEnergy.systemImage(for: name))
            }
        } label: {
            pillLabel(selectedHardware.map(ComponentEnergy.shortName(for:)) ?? String(localized: "Hardware", comment: "Hardware components, such as the display and the cellular modem."),
                      systemImage: showsIcon ? selectedHardware.map(ComponentEnergy.systemImage(for:)) ?? "cpu" : nil,
                      isSelected: selectedHardware != nil, hasMenu: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassPill(isSelected: selectedHardware != nil)
    }

    /// A dropdown of apps or of system processes, whose pill shows the pick when it's one of them.
    private func appMenu(_ apps: [FocusApp], title: String, systemImage: String?, isSystem: Bool) -> some View {
        let picked = selectedApp.flatMap { $0.isSystem == isSystem ? $0 : nil }
        return Menu {
            ForEach(apps) { app in
                menuItem(.app(app.bundleID), title: app.displayName, wh: Double(app.total) / 1000, systemImage: nil)
            }
        } label: {
            pillLabel(picked?.displayName ?? title, systemImage: picked == nil ? systemImage : nil,
                      isSelected: picked != nil, hasMenu: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassPill(isSelected: picked != nil)
    }

    /// A dropdown row with its energy across the period underneath, and a checkmark when it's the pick.
    /// A button rather than a picker, since menus only show a picker row's first line.
    private func menuItem(_ value: ReportFocus, title: String, wh: Double, systemImage: String?) -> some View {
        Button {
            withAnimation(.snappy) { focus = value }
        } label: {
            // Menus read the second Text as a subtitle only when it's directly in the button's label.
            Text(title)
            Text(Format.wh(wh, digits: 1))
            if focus == value {
                Image(systemName: "checkmark")
            } else if let systemImage {
                Image(systemName: systemImage)
            }
        }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(.capsule)
    }
}

private extension View {
    func glassPill(isSelected: Bool) -> some View {
        glassEffect(isSelected ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .capsule)
    }
}
