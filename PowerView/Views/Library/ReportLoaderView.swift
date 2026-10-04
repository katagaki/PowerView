import SwiftUI

/// Reads a report from disk when it's opened, then shows it.
struct ReportLoaderView: View {
    let id: UUID
    @Environment(ReportStore.self) private var store
    @State private var report: PowerReport?
    @State private var error: String?

    var body: some View {
        Group {
            if let report {
                ReportView(report: report)
            } else if let error {
                ContentUnavailableView("Couldn't Open Report", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView()
            }
        }
        .task(id: id) {
            do {
                report = try await store.loadReport(id: id)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
