import Foundation

nonisolated enum DeviceNames {
    static func name(for productType: String) -> String {
        table[productType] ?? productType
    }

    /// `name` as saved in a report, for display.
    static func displayName(_ name: String) -> String {
        name == "iPhone SE (3rd generation)" ? String(localized: "iPhone SE (3rd generation)", comment: "Device name.") : name
    }

    private static let table: [String: String] = [
        "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13", "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air"
    ]
}

/// Readable names for the bundle IDs and processes that show up in the energy accounting.
nonisolated enum ProcessNames {
    static let alwaysOnDisplay = "com.apple.lock-screen.aod"

    static func name(for identifier: String) -> String {
        if let known = table[identifier] { return known }
        let parts = identifier.split(separator: ".")
        guard parts.count >= 3, let last = parts.last else { return identifier }
        // Bundle IDs like com.hammerandchisel.discord end in lowercase; capitalise for display.
        return last.prefix(1).uppercased() + last.dropFirst()
    }

    /// The name to show for `identifier`. Only names from `table` are translated; for anything else
    /// it's `stored`, the name saved in the report, if there is one.
    static func displayName(for identifier: String, stored: String? = nil) -> String {
        guard let name = table[identifier] else { return stored ?? name(for: identifier) }
        return localized(name)
    }

    /// The name to show for a name saved in a report, for records that didn't keep the identifier.
    static func displayName(stored name: String) -> String {
        localized(name)
    }

    /// `name(for:)` stays in English because its result is saved in reports. This translates it for display.
    private static func localized(_ name: String) -> String {
        switch name {
        case "Always-On Display": String(localized: "Always-On Display")
        case "Lock Screen": String(localized: "Lock Screen")
        case "Home Screen": String(localized: "Home Screen")
        case "Control Center": String(localized: "Control Center")
        case "System (unattributed CPU)": String(localized: "System (unattributed CPU)", comment: "CPU energy that isn't attributed to any app.")
        case "GPU (unattributed)": String(localized: "GPU (unattributed)", comment: "GPU energy that isn't attributed to any app.")
        case "Memory (unattributed)": String(localized: "Memory (unattributed)", comment: "Memory energy that isn't attributed to any app.")
        case "SpringBoard (Home/Lock)": String(localized: "SpringBoard (Home/Lock)", comment: "The iOS process that draws the Home Screen and Lock Screen.")
        case "Phone Call": String(localized: "Phone Call", comment: "The in-call screen.")
        case "Widgets & Live Activities": String(localized: "Widgets & Live Activities")
        case "sharingd (AirDrop/Continuity)": String(localized: "sharingd (AirDrop/Continuity)", comment: "System process name, then what it does.")
        case "geod (Maps data)": String(localized: "geod (Maps data)", comment: "System process name, then what it does.")
        case "CommCenter (cellular)": String(localized: "CommCenter (cellular)", comment: "System process name, then what it does.")
        case "apsd (push)": String(localized: "apsd (push)", comment: "System process name, then what it does.")
        case "nsurlsessiond (downloads)": String(localized: "nsurlsessiond (downloads)", comment: "System process name, then what it does.")
        case "backboardd (input/display)": String(localized: "backboardd (input/display)", comment: "System process name, then what it does.")
        case "Wi-Fi Idle": String(localized: "Wi-Fi Idle", comment: "Energy used by the Wi-Fi radio while idle.")
        case "Cellular (standby)": String(localized: "Cellular (standby)", comment: "Energy used by the cellular radio on standby.")
        case "Mail": String(localized: "Mail", comment: "The Mail app.")
        case "Music": String(localized: "Music", comment: "The Music app.")
        case "Podcasts": String(localized: "Podcasts", comment: "The Podcasts app.")
        case "Camera": String(localized: "Camera", comment: "The Camera app.")
        case "Photos": String(localized: "Photos", comment: "The Photos app.")
        case "Maps": String(localized: "Maps", comment: "The Maps app.")
        case "Messages": String(localized: "Messages", comment: "The Messages app.")
        case "Settings": String(localized: "Settings", comment: "The Settings app.")
        case "Reminders": String(localized: "Reminders", comment: "The Reminders app.")
        case "Calendar": String(localized: "Calendar", comment: "The Calendar app.")
        case "Phone": String(localized: "Phone", comment: "The Phone app.")
        case "Health": String(localized: "Health", comment: "The Health app.")
        case "Weather": String(localized: "Weather", comment: "The Weather app.")
        case "News": String(localized: "News", comment: "The News app.")
        case "Fitness": String(localized: "Fitness", comment: "The Fitness app.")
        case "Wallet": String(localized: "Wallet", comment: "The Wallet app.")
        default: name
        }
    }

    /// Folds the many system screen identifiers into a few readable groups for the screen timeline.
    static func screenGroup(for identifier: String) -> String {
        switch identifier {
        case "com.apple.lock-screen", "com.apple.SleepLockScreen", "com.apple.springboard.passcode",
             "com.apple.LocalAuthenticationUIService":
            "com.apple.lock-screen"
        case _ where identifier.hasPrefix("com.apple.springboard"):
            "com.apple.springboard.home-screen"
        default:
            identifier
        }
    }

    private static let table: [String: String] = [
        alwaysOnDisplay: "Always-On Display",
        "com.apple.lock-screen": "Lock Screen", "com.apple.springboard.home-screen": "Home Screen",
        "com.apple.control-center": "Control Center", "com.apple.Siri": "Siri",
        "CPU": "System (unattributed CPU)", "GPU": "GPU (unattributed)", "DRAM": "Memory (unattributed)",
        "com.apple.springboard": "SpringBoard (Home/Lock)", "com.apple.mobilemail": "Mail", "com.apple.Music": "Music",
        "com.apple.mobilesafari": "Safari", "com.apple.TestFlight": "TestFlight", "com.apple.podcasts": "Podcasts",
        "com.apple.camera": "Camera", "com.apple.mobileslideshow": "Photos", "com.apple.Maps": "Maps",
        "com.apple.MobileSMS": "Messages", "com.apple.Preferences": "Settings", "com.apple.InCallService": "Phone Call",
        "com.apple.chrono.WidgetRenderer-Activities": "Widgets & Live Activities", "com.apple.MercuryPoster": "MercuryPoster",
        "com.apple.sharingd": "sharingd (AirDrop/Continuity)", "com.apple.geod": "geod (Maps data)",
        "com.apple.CommCenter": "CommCenter (cellular)", "com.apple.apsd": "apsd (push)", "apsd": "apsd (push)",
        "com.apple.nsurlsessiond": "nsurlsessiond (downloads)", "nsurlsessiond": "nsurlsessiond (downloads)",
        "backboardd": "backboardd (input/display)", "mDNSResponder": "mDNSResponder (DNS)", "kernel_task": "kernel_task",
        "locationd": "locationd", "WiFi-Idle": "Wi-Fi Idle", "BB-Standard": "Cellular (standby)",
        "com.atebits.Tweetie2": "X", "com.hammerandchisel.discord": "Discord", "com.apple.reminders": "Reminders",
        "com.apple.mobilecal": "Calendar", "com.apple.mobilephone": "Phone", "com.apple.Health": "Health",
        "com.apple.weather": "Weather", "com.apple.news": "News", "com.apple.Fitness": "Fitness", "com.apple.Wallet": "Wallet",
        "com.google.ios.youtube": "YouTube", "net.whatsapp.WhatsApp": "WhatsApp",
        "jp.naver.line": "LINE", "com.burbn.instagram": "Instagram", "com.anthropic.claude": "Claude",
        "com.valvesoftware.SteamLink17": "Steam Link", "jp.konami.bm2dxum": "beatmania IIDX UM",
        "com.fiberlink.maas360forios": "MaaS360", "com.t3tools.t3code": "T3 Code", "com.t3tools.t3code.widgets": "T3 Code Widgets"
    ]
}
