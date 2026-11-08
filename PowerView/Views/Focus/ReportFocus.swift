import Foundation

/// What the report shows: everything, one hardware component, or one app or process.
enum ReportFocus: Hashable {
    case overall
    /// A `ComponentEnergy.name`.
    case hardware(String)
    /// An `AppEnergy.bundleID`.
    case app(String)
}

/// An app or process that can be focused on, with its energy added up across the period.
struct FocusApp: Identifiable, Hashable {
    var bundleID: String
    /// The name saved in the report, which other records name it by.
    var name: String
    var displayName: String
    /// mWh across every day or stretch.
    var total: Int
    var id: String { bundleID }
}

/// The hardware components and apps worth a pill, for the days or stretches in view.
struct FocusOptions {
    var hardware: [String]
    var apps: [FocusApp]

    init(reports: [DayReport]) {
        var energy: [String: Double] = [:]
        var order: [String] = []
        var apps: [String: FocusApp] = [:]
        for day in reports {
            for component in day.components ?? [] {
                if energy[component.name] == nil { order.append(component.name) }
                energy[component.name, default: 0] += component.wh
            }
            for app in day.apps ?? [] {
                apps[app.bundleID, default: FocusApp(bundleID: app.bundleID, name: app.name, displayName: app.displayName, total: 0)].total += app.total
            }
        }
        hardware = order.filter { (energy[$0] ?? 0) > 0 }.sorted { (energy[$0] ?? 0) > (energy[$1] ?? 0) }
        self.apps = apps.values.sorted { ($0.total, $1.displayName) > ($1.total, $0.displayName) }
    }

    func contains(_ focus: ReportFocus) -> Bool {
        switch focus {
        case .overall: true
        case .hardware(let name): hardware.contains(name)
        case .app(let bundleID): apps.contains { $0.bundleID == bundleID }
        }
    }
}

nonisolated extension ComponentEnergy {
    /// A short name for a pill.
    static func shortName(for name: String) -> String {
        switch name {
        case "Processor (CPU/GPU/NPU)": String(localized: "Processor", comment: "A hardware component, the CPU, GPU and Neural Engine. Shown in a small pill, so keep it short.")
        case "Memory & Rest of Chip": String(localized: "Memory & Chip", comment: "A hardware component, memory and the rest of the chip. Shown in a small pill, so keep it short.")
        case "Cellular Modem": String(localized: "Cellular", comment: "Cellular network.")
        default: displayName(for: name)
        }
    }

    static func systemImage(for name: String) -> String {
        switch name {
        case "Processor (CPU/GPU/NPU)": "cpu"
        case "Memory & Rest of Chip": "memorychip"
        case "Display": "iphone.gen3"
        case "Cellular Modem": "antenna.radiowaves.left.and.right"
        case "Wi-Fi": "wifi"
        default: "square.stack.3d.up"
        }
    }
}

nonisolated extension StabilityEvent {
    func belongs(to app: FocusApp) -> Bool {
        bundleID == app.bundleID || process == app.name || process == app.bundleID
    }
}
