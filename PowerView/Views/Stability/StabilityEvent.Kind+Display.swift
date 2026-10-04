import SwiftUI

extension StabilityEvent.Kind {
    var title: String {
        switch self {
        case .crash: "Crash"
        case .memoryKill: "Closed for Memory"
        case .cpuLimit: "Heavy CPU Use"
        case .diskWriteLimit: "Heavy Disk Writes"
        case .memoryLimit: "Memory Limit"
        case .hang: "Hang"
        case .accessoryCrash: "Accessory Crash"
        case .panic: "Unexpected Restart"
        }
    }

    var pluralTitle: String {
        switch self {
        case .crash: "Crashes"
        case .memoryKill: "Closed for Memory"
        case .cpuLimit: "Heavy CPU Use"
        case .diskWriteLimit: "Heavy Disk Writes"
        case .memoryLimit: "Memory Limits"
        case .hang: "Hangs"
        case .accessoryCrash: "Accessory Crashes"
        case .panic: "Unexpected Restarts"
        }
    }

    var systemImage: String {
        switch self {
        case .crash: "xmark.octagon.fill"
        case .memoryKill: "memorychip.fill"
        case .cpuLimit: "cpu.fill"
        case .diskWriteLimit: "internaldrive.fill"
        case .memoryLimit: "gauge.with.dots.needle.67percent"
        case .hang: "hourglass"
        case .accessoryCrash: "earbuds"
        case .panic: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .crash, .panic: .red
        case .memoryKill, .memoryLimit: .purple
        case .cpuLimit, .diskWriteLimit: .orange
        case .hang: .yellow
        case .accessoryCrash: .blue
        }
    }

    /// Lower is more serious; used to show the important reports first.
    var severity: Int {
        switch self {
        case .panic: 0
        case .crash: 1
        case .cpuLimit: 2
        case .diskWriteLimit: 3
        case .hang: 4
        case .accessoryCrash: 5
        case .memoryKill: 6
        case .memoryLimit: 7
        }
    }

    /// CPU and disk-write reports matter for battery life; the rest are reliability.
    var affectsBattery: Bool { self == .cpuLimit || self == .diskWriteLimit }
}
