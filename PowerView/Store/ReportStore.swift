import Foundation
import Observation

/// Keeps imported reports on disk and runs imports in the background.
@Observable
final class ReportStore {

    static let appGroup = "group.com.tsubuzaki.PowerView"

    private(set) var reports: [PowerReport] = []
    private(set) var progress: ImportProgress?
    var importError: String?
    /// Set when an import finishes, so the UI can open the new report.
    var lastImportedID: UUID?

    private let directory: URL = {
        let url = URL.applicationSupportDirectory.appending(path: "Reports", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    var isImporting: Bool { progress != nil }

    init() {
        load()
    }

    func report(id: UUID) -> PowerReport? {
        reports.first { $0.id == id }
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
                try SysdiagnoseImporter().importFile(at: url, progress: update)
            }.value
            try save(report)
            reports.insert(report, at: 0)
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

    // MARK: - Persistence

    func delete(_ report: PowerReport) {
        try? FileManager.default.removeItem(at: fileURL(for: report.id))
        reports.removeAll { $0.id == report.id }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    private func save(_ report: PowerReport) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(report).write(to: fileURL(for: report.id), options: .atomic)
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        reports = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(PowerReport.self, from: Data(contentsOf: $0)) }
            .sorted { $0.importedAt > $1.importedAt }
    }
}
