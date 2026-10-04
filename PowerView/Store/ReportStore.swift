import Foundation
import Observation

/// Keeps imported reports on disk and runs imports in the background.
///
/// Only small summaries are loaded at launch. A full report is read from disk when it's opened,
/// and only the most recently opened one is kept in memory.
@Observable
final class ReportStore {

    static let appGroup = "group.com.tsubuzaki.PowerView"

    private(set) var summaries: [ReportSummary] = []
    private(set) var progress: ImportProgress?
    var importError: String?
    /// Set when an import finishes, so the UI can open the new report.
    var lastImportedID: UUID?

    /// The most recently opened report, so going back and forth doesn't re-read it from disk.
    private var openReport: PowerReport?

    var isImporting: Bool { progress != nil }

    init() {
        summaries = ReportFiles.loadSummaries()
    }

    // MARK: - Reading

    func loadReport(id: UUID) async throws -> PowerReport {
        if let openReport, openReport.id == id { return openReport }
        let report = try await Task.detached(priority: .userInitiated) {
            try ReportFiles.loadReport(id: id)
        }.value
        openReport = report
        return report
    }

    // MARK: - Import

    /// Imports a file. `accessSecurityScope` is for files picked from outside the sandbox.
    func importFile(at url: URL, accessSecurityScope: Bool = false, removeAfterImport: Bool = false) async {
        guard !isImporting else { return }
        progress = ImportProgress(stage: .extracting, fraction: 0)
        defer { progress = nil }

        let scoped = accessSecurityScope && url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let update: @Sendable (ImportProgress) -> Void = { value in
            Task { @MainActor in
                if self.progress != nil { self.progress = value }
            }
        }
        do {
            let report = try await Task.detached(priority: .userInitiated) {
                let report = try SysdiagnoseImporter().importFile(at: url, progress: update)
                try ReportFiles.save(report)
                return report
            }.value
            openReport = report
            summaries.insert(ReportSummary(report: report), at: 0)
            lastImportedID = report.id
        } catch {
            importError = error.localizedDescription
        }
        if removeAfterImport { try? FileManager.default.removeItem(at: url) }
    }

    /// Imports files the Share extension dropped into the shared container.
    func importSharedFiles() async {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else { return }
        let inbox = container.appending(path: "Inbox", directoryHint: .isDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where !file.lastPathComponent.hasPrefix(".") {
            await importFile(at: file, removeAfterImport: true)
        }
    }

    // MARK: - Deleting

    func delete(_ summary: ReportSummary) {
        ReportFiles.delete(id: summary.id)
        summaries.removeAll { $0.id == summary.id }
        if openReport?.id == summary.id { openReport = nil }
    }
}

/// Reads and writes report files. Each report is `<id>.json`, with its summary in `<id>.summary.json`.
nonisolated enum ReportFiles {

    enum LoadError: LocalizedError {
        case missing

        var errorDescription: String? { "This report's file couldn't be found. Try importing the sysdiagnose again." }
    }

    private static let summarySuffix = ".summary.json"

    private static let directory: URL = {
        let url = URL.applicationSupportDirectory.appending(path: "Reports", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static func reportURL(_ id: UUID) -> URL { directory.appending(path: "\(id.uuidString).json") }
    private static func summaryURL(_ id: UUID) -> URL { directory.appending(path: "\(id.uuidString)\(summarySuffix)") }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Reads every summary, newest first.
    static func loadSummaries() -> [ReportSummary] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names
            .filter { $0.hasSuffix(summarySuffix) }
            .compactMap { try? decoder.decode(ReportSummary.self, from: Data(contentsOf: directory.appending(path: $0))) }
            .sorted { $0.importedAt > $1.importedAt }
    }

    static func loadReport(id: UUID) throws -> PowerReport {
        guard FileManager.default.fileExists(atPath: reportURL(id).path) else { throw LoadError.missing }
        return try decoder.decode(PowerReport.self, from: Data(contentsOf: reportURL(id)))
    }

    /// Writes the report, then its summary. The summary goes last so it never points at a missing report.
    static func save(_ report: PowerReport) throws {
        try encoder.encode(report).write(to: reportURL(report.id), options: .atomic)
        try encoder.encode(ReportSummary(report: report)).write(to: summaryURL(report.id), options: .atomic)
    }

    static func delete(id: UUID) {
        try? FileManager.default.removeItem(at: summaryURL(id))
        try? FileManager.default.removeItem(at: reportURL(id))
    }
}
