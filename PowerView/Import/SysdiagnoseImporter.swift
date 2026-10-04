import Foundation

nonisolated struct ImportProgress: Sendable, Equatable {
    enum Stage: Sendable, Equatable {
        case extracting, analyzing, saving
    }

    var stage: Stage
    var fraction: Double

    var title: String {
        switch stage {
        case .extracting: "Extracting Power Log"
        case .analyzing: "Analyzing Days"
        case .saving: "Saving Report"
        }
    }
}

/// Imports a sysdiagnose archive (`.tar.gz` or `.tar`) or a bare power log (`.PLSQL`) into a `PowerReport`.
nonisolated struct SysdiagnoseImporter {

    enum ImportError: LocalizedError {
        case noPowerLog
        case unsupportedFile

        var errorDescription: String? {
            switch self {
            case .noPowerLog: "This archive doesn't contain a power log. Make sure it's a sysdiagnose from an iPhone or iPad."
            case .unsupportedFile: "PowerView can open sysdiagnose archives (.tar.gz) and power logs (.PLSQL)."
            }
        }
    }

    func importFile(at url: URL, progress: @escaping @Sendable (ImportProgress) -> Void) throws -> PowerReport {
        let workDirectory = FileManager.default.temporaryDirectory.appending(path: "import-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        // Files from the Share extension carry a timestamp prefix.
        let name = url.lastPathComponent.replacing(/^\d+-(?=sysdiagnose|powerlog)/, with: "")
        let timeZone = Self.timeZone(fromArchiveName: name) ?? .current
        let powerLog: URL
        var productType: String?
        var stability: [StabilityEvent]?
        if Self.isSQLite(url) {
            powerLog = workDirectory.appending(path: "powerlog.PLSQL")
            try FileManager.default.copyItem(at: url, to: powerLog)
        } else {
            let extracted = try extractArchive(url, into: workDirectory, progress: progress)
            guard let log = extracted.powerLog else { throw ImportError.noPowerLog }
            powerLog = log
            productType = extracted.productType
            stability = (extracted.reports.flatMap(DiagnosticReportParser.events(fromReport:))
                + extracted.memoryExceptionNames.compactMap { DiagnosticReportParser.memoryLimitEvent(fromFileName: $0, timeZone: timeZone) })
                .sorted { $0.date > $1.date }
        }

        progress(ImportProgress(stage: .analyzing, fraction: 0))
        let db = try SQLiteDatabase(url: powerLog)
        let analyzer = PowerLogAnalyzer(db: db, timeZone: timeZone)
        let (days, captured) = try analyzer.analyze { progress(ImportProgress(stage: .analyzing, fraction: $0)) }
        let config = analyzer.config()
        let battery = analyzer.batteryInfo()
        let charging = analyzer.chargingSessions()

        progress(ImportProgress(stage: .saving, fraction: 1))
        let meta = ReportMeta(
            captured: captured,
            deviceName: productType.map(DeviceNames.name(for:)) ?? Self.deviceKind(fromArchiveName: name) ?? "iPhone",
            productType: productType,
            build: Self.build(fromArchiveName: name) ?? config.build,
            timeZoneOffset: timeZone.secondsFromGMT(for: captured),
            whPerPercent: battery.whPerPercent ?? 0.187,
            battery: battery.info
        )
        return PowerReport(id: UUID(), importedAt: .now, sourceName: name, meta: meta, days: days,
                           charging: charging.isEmpty ? nil : charging, stability: stability)
    }

    // MARK: - Archive

    private struct ExtractedArchive {
        var powerLog: URL?
        var productType: String?
        var reports: [URL]
        var memoryExceptionNames: [String]
    }

    private func extractArchive(_ url: URL, into directory: URL,
                                progress: @escaping @Sendable (ImportProgress) -> Void) throws -> ExtractedArchive {
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init) ?? 0
        let source: ByteReader
        let bytesRead: () -> UInt64
        if GzipReader.isGzip(url) {
            let gzip = try GzipReader(url: url)
            source = gzip
            bytesRead = { gzip.compressedBytesRead }
        } else {
            let file = try FileByteReader(url: url)
            source = file
            bytesRead = { file.bytesRead }
        }

        var powerLogs: [(path: String, url: URL)] = []
        var dumpState: URL?
        var reports: [URL] = []
        var memoryExceptionNames: [String] = []
        var sawTarEntry = false
        var lastReported = 0.0
        do {
            try TarReader(source: source).forEachEntry { entry in
                sawTarEntry = true
                if fileSize > 0 {
                    let fraction = Double(bytesRead()) / Double(fileSize)
                    if fraction - lastReported > 0.01 {
                        lastReported = fraction
                        progress(ImportProgress(stage: .extracting, fraction: fraction))
                    }
                }
                let fileName = (entry.path as NSString).lastPathComponent
                if entry.path.contains("powerlogs/"), fileName.hasSuffix(".PLSQL") || fileName.hasSuffix(".PLSQL.gz") {
                    let destination = directory.appending(path: "\(powerLogs.count)-\(fileName)")
                    powerLogs.append((entry.path, destination))
                    return .extract(to: destination)
                }
                if DiagnosticReportParser.isDiagnosticReport(path: entry.path), entry.size < 16 << 20 {
                    let destination = directory.appending(path: "report-\(reports.count).ips")
                    reports.append(destination)
                    return .extract(to: destination)
                }
                if entry.path.contains("crashes_and_spins/"), fileName.hasPrefix("MREException") {
                    memoryExceptionNames.append(fileName)
                    return .skip
                }
                if fileName == "remotectl_dumpstate.txt", entry.size < 8 << 20 {
                    let destination = directory.appending(path: fileName)
                    dumpState = destination
                    return .extract(to: destination)
                }
                return .skip
            }
        } catch where !sawTarEntry && (error is GzipReader.GzipError || error is TarReader.TarError) {
            throw ImportError.unsupportedFile
        }
        guard sawTarEntry else { throw ImportError.unsupportedFile }

        // The newest power log has the most recent data; file names start with the capture date.
        var powerLog = powerLogs.max { ($0.path as NSString).lastPathComponent < ($1.path as NSString).lastPathComponent }?.url
        if let compressed = powerLog, compressed.pathExtension == "gz" {
            let output = directory.appending(path: "powerlog.PLSQL")
            try decompress(compressed, to: output)
            powerLog = output
        }
        return ExtractedArchive(powerLog: powerLog, productType: dumpState.flatMap(Self.productType(fromDumpState:)),
                                reports: reports, memoryExceptionNames: memoryExceptionNames)
    }

    private func decompress(_ url: URL, to output: URL) throws {
        let reader = try GzipReader(url: url)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        let capacity = 1 << 20
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        while true {
            let count = try reader.read(into: buffer, count: capacity)
            if count == 0 { break }
            try handle.write(contentsOf: Data(bytesNoCopy: buffer, count: count, deallocator: .none))
        }
    }

    // MARK: - Metadata

    static func isSQLite(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 16)) == Data("SQLite format 3\0".utf8)
    }

    private static func productType(fromDumpState url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let match = text.firstMatch(of: /ProductType => (\S+)/) else { return nil }
        return String(match.1)
    }

    /// Sysdiagnose names look like `sysdiagnose_2026.10.04_01-01-12+0900_iPhone-OS_iPhone_24B5089g.tar.gz`.
    static func timeZone(fromArchiveName name: String) -> TimeZone? {
        guard let match = name.firstMatch(of: /_\d{2}-\d{2}-\d{2}([+-])(\d{2})(\d{2})_/),
              let hours = Int(match.2), let minutes = Int(match.3) else { return nil }
        let seconds = (hours * 3600 + minutes * 60) * (match.1 == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }

    private static func build(fromArchiveName name: String) -> String? {
        name.firstMatch(of: /_([0-9]{2}[A-Z][0-9]+[a-z]?)(?:\.tar)?(?:\.gz)?$/).map { String($0.1) }
    }

    private static func deviceKind(fromArchiveName name: String) -> String? {
        name.firstMatch(of: /-OS_([A-Za-z]+)_/).map { String($0.1) }
    }
}
