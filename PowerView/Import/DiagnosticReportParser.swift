import Foundation

/// Reads the crash, hang, memory and resource reports from a sysdiagnose's `crashes_and_spins` folder.
/// `.ips` files start with a one-line JSON header; the rest is JSON or plain text depending on the type.
nonisolated enum DiagnosticReportParser {

    static func isDiagnosticReport(path: String) -> Bool {
        path.contains("crashes_and_spins/") && path.hasSuffix(".ips")
    }

    /// Parses an `.ips` file. Analytics-only reports return no events.
    static func events(fromReport url: URL) -> [StabilityEvent] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let headerLine = parts.first,
              let header = try? JSONSerialization.jsonObject(with: Data(headerLine.utf8)) as? [String: Any],
              let bugType = header["bug_type"] as? String,
              let date = (header["timestamp"] as? String).flatMap(parseDate) else { return [] }
        let body = parts.count > 1 ? String(parts[1]) : ""
        let json = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: Any]
        let appName = header["app_name"] as? String
        let bundleID = header["bundleID"] as? String

        switch bugType {
        case "109", "309":
            if header["is_simulated"] as? Int == 1 { return [] }
            let name = appName ?? json?["procName"] as? String ?? "Unknown"
            return [StabilityEvent(date: date, kind: .crash, process: name, bundleID: bundleID ?? bundleIdentifier(json),
                                   detail: crashDetail(json))]
        case "298":
            return memoryKills(json, date: date)
        case "202":
            return [StabilityEvent(date: date, kind: .cpuLimit, process: appName ?? "Unknown", bundleID: bundleID,
                                   detail: textField("CPU", in: body))]
        case "145":
            return [StabilityEvent(date: date, kind: .diskWriteLimit, process: appName ?? "Unknown", bundleID: bundleID,
                                   detail: textField("Writes", in: body))]
        case "223", "228":
            return [StabilityEvent(date: date, kind: .hang, process: appName ?? "Unknown", bundleID: bundleID,
                                   detail: textField("Event", in: body).map { event in
                                       textField("Duration", in: body).map { "\(event), \($0)" } ?? event
                                   })]
        case "305":
            let type = (json?["accessory_type"] as? String).map { $0.capitalized } ?? "Accessory"
            return [StabilityEvent(date: date, kind: .accessoryCrash, process: "\(type) Accessory", detail: nil)]
        case "210":
            return [StabilityEvent(date: date, kind: .panic, process: "System", detail: "The phone restarted unexpectedly.")]
        default:
            return []
        }
    }

    /// Memory exception reports are named `MREException<Kind>_<process>_<yyyy-MM-dd>_<HHmmss>.*`.
    /// The name has everything needed, so these files aren't extracted.
    static func memoryLimitEvent(fromFileName name: String, timeZone: TimeZone) -> StabilityEvent? {
        guard let match = name.firstMatch(of: /^MREException([A-Za-z]+)_(.+)_(\d{4}-\d{2}-\d{2})_(\d{6})\./) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        guard let date = formatter.date(from: "\(match.3) \(match.4)") else { return nil }
        let fatal = match.1.hasPrefix("Fatal")
        let state = match.1.hasSuffix("Inactive") ? "in the background" : "while active"
        return StabilityEvent(date: date, kind: .memoryLimit, process: String(match.2),
                              detail: fatal ? "Went over its memory limit \(state) and was stopped" : "Reached its memory warning level \(state)")
    }

    // MARK: - Details

    private static func memoryKills(_ json: [String: Any]?, date: Date) -> [StabilityEvent] {
        guard let json else { return [] }
        let processes = json["processes"] as? [[String: Any]] ?? []
        let killed = processes.compactMap { process -> StabilityEvent? in
            // Idle exits are iOS tidying up processes nobody is using; they aren't a problem.
            guard let reason = process["reason"] as? String, !reason.contains("idle-exit"),
                  let name = process["name"] as? String else { return nil }
            return StabilityEvent(date: date, kind: .memoryKill, process: name, detail: jetsamReason(reason))
        }
        return killed
    }

    private static func jetsamReason(_ reason: String) -> String {
        switch reason {
        case "per-process-limit": "Used more memory than it's allowed"
        case "highwater": "Over its memory allowance while memory was low"
        case "vm-pageshortage", "vnode-limit": "Closed to free memory for other apps"
        case "fc-thrashing", "vm-compressor-thrashing", "vm-compressor-space-shortage": "Closed because memory was under heavy pressure"
        default: reason
        }
    }

    private static func crashDetail(_ json: [String: Any]?) -> String? {
        guard let json else { return nil }
        let exception = json["exception"] as? [String: Any]
        let termination = json["termination"] as? [String: Any]
        let reasons = (termination?["reasons"] as? [String])?.joined(separator: " ") ?? ""
        if reasons.contains("0x8BADF00D") { return "Stopped by the watchdog for not responding" }
        if let indicator = termination?["indicator"] as? String { return indicator }
        let type = exception?["type"] as? String
        let signal = exception?["signal"] as? String
        return [type, signal].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    private static func bundleIdentifier(_ json: [String: Any]?) -> String? {
        (json?["bundleInfo"] as? [String: Any])?["CFBundleIdentifier"] as? String
    }

    /// Reads `Name:   value` from a text report.
    private static func textField(_ name: String, in body: String) -> String? {
        for line in body.split(separator: "\n", omittingEmptySubsequences: true).prefix(80) where line.hasPrefix("\(name):") {
            return line.dropFirst(name.count + 1).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd HH:mm:ss.SS Z", "yyyy-MM-dd HH:mm:ss Z"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

nonisolated private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
