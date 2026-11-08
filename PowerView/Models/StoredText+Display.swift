import Foundation

// Reports save some text at import time, always in English, so a report reads correctly after the
// language changes and older reports keep decoding. These map the values the importer writes to
// localized text when they're shown. Anything else came from the system and is shown as saved.

nonisolated extension SettingEvent {
    var displayText: String {
        guard let match = text.wholeMatch(of: /(Always-On Display|Low Power Mode) (on|off)(?: \((.+)\))?/) else { return text }
        let isOn = match.2 == "on"
        if match.1 == "Always-On Display" {
            return isOn ? String(localized: "Always-On Display on", comment: "A setting change.")
                        : String(localized: "Always-On Display off", comment: "A setting change.")
        }
        guard let source = match.3.map(String.init) else {
            return isOn ? String(localized: "Low Power Mode on", comment: "A setting change.")
                        : String(localized: "Low Power Mode off", comment: "A setting change.")
        }
        return isOn ? String(localized: "Low Power Mode on (\(source))", comment: "A setting change, then what made it, as named by the system.")
                    : String(localized: "Low Power Mode off (\(source))", comment: "A setting change, then what made it, as named by the system.")
    }
}

nonisolated extension ComponentEnergy {
    var displayName: String { Self.displayName(for: name) }

    static func displayName(for name: String) -> String {
        switch name {
        case "Processor (CPU/GPU/NPU)": String(localized: "Processor (CPU/GPU/NPU)", comment: "A hardware component.")
        case "Memory & Rest of Chip": String(localized: "Memory & Rest of Chip", comment: "A hardware component.")
        case "Display": String(localized: "Display", comment: "A hardware component.")
        case "Cellular Modem": String(localized: "Cellular Modem", comment: "A hardware component.")
        case "Wi-Fi": "Wi-Fi"
        case "Other": String(localized: "Other", comment: "Everything not listed separately.")
        default: name
        }
    }
}

nonisolated extension WakeReason {
    var displayName: String {
        switch name {
        case "Touch, Button or Raise": String(localized: "Touch, Button or Raise", comment: "Why the phone woke from sleep.")
        case "Cellular": String(localized: "Cellular", comment: "Cellular network.")
        case "Bluetooth": String(localized: "Bluetooth", comment: "Why the phone woke from sleep.")
        case "Wi-Fi or Bluetooth": String(localized: "Wi-Fi or Bluetooth", comment: "Why the phone woke from sleep.")
        case "Scheduled Timer": String(localized: "Scheduled Timer", comment: "Why the phone woke from sleep.")
        case "Other": String(localized: "Other", comment: "Everything not listed separately.")
        default: name
        }
    }

    /// The name as it reads in the middle of a sentence.
    var inlineName: String {
        switch name {
        case "Touch, Button or Raise": String(localized: "touch, button or raise", comment: "Why the phone woke from sleep, in the middle of a sentence: “mostly for …”.")
        case "Cellular": String(localized: "cellular", comment: "Why the phone woke from sleep, in the middle of a sentence: “mostly for …”.")
        case "Scheduled Timer": String(localized: "scheduled timer", comment: "Why the phone woke from sleep, in the middle of a sentence: “mostly for …”.")
        case "Other": String(localized: "other reasons", comment: "Why the phone woke from sleep, in the middle of a sentence: “mostly for …”.")
        default: displayName
        }
    }
}

nonisolated extension StabilityEvent {
    var displayProcess: String {
        switch process {
        case "Unknown": String(localized: "Unknown", comment: "A diagnostic report that doesn't name its app.")
        case "System": String(localized: "System", comment: "The operating system, in place of an app name.")
        case "Accessory Accessory": String(localized: "Accessory", comment: "An accessory of an unknown type.")
        case let name where name.hasSuffix(" Accessory"):
            String(localized: "\(String(name.dropLast(" Accessory".count))) Accessory", comment: "The type of accessory, as named by the system, e.g. Headphones Accessory.")
        default: ProcessNames.displayName(stored: process)
        }
    }

    var displayDetail: String? {
        switch detail {
        case "The phone restarted unexpectedly.": String(localized: "The phone restarted unexpectedly.")
        case "Went over its memory limit in the background and was stopped": String(localized: "Went over its memory limit in the background and was stopped")
        case "Went over its memory limit while active and was stopped": String(localized: "Went over its memory limit while active and was stopped")
        case "Reached its memory warning level in the background": String(localized: "Reached its memory warning level in the background")
        case "Reached its memory warning level while active": String(localized: "Reached its memory warning level while active")
        case "Used more memory than it's allowed": String(localized: "Used more memory than it's allowed")
        case "Over its memory allowance while memory was low": String(localized: "Over its memory allowance while memory was low")
        case "Closed to free memory for other apps": String(localized: "Closed to free memory for other apps")
        case "Closed because memory was under heavy pressure": String(localized: "Closed because memory was under heavy pressure")
        case "Stopped by the watchdog for not responding": String(localized: "Stopped by the watchdog for not responding")
        default: detail
        }
    }
}

nonisolated extension AppEnergy {
    var displayName: String { ProcessNames.displayName(for: bundleID, stored: name) }
}

nonisolated extension NotificationApp {
    var displayName: String { ProcessNames.displayName(for: bundleID, stored: name) }
}

nonisolated extension ScreenAppTotal {
    var displayName: String { ProcessNames.displayName(for: appID, stored: name) }
}

nonisolated extension DataApp {
    var displayName: String { ProcessNames.displayName(stored: name) }
}
