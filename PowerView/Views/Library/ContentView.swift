import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ReportStore.self) private var store
    @State private var isPickingFile = false
    @State private var isShowingHelp = false
    @State private var path: [UUID] = []

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $path) {
            Group {
                if store.reports.isEmpty && !store.isImporting {
                    ContentUnavailableView {
                        Label("No Reports", systemImage: "battery.100percent.bolt")
                    } description: {
                        Text("Import a sysdiagnose to see battery, screen time, apps and network for each day.")
                    } actions: {
                        Button("Import Sysdiagnose") { isPickingFile = true }
                            .buttonStyle(.borderedProminent)
                        Button("How to Capture a Sysdiagnose") { isShowingHelp = true }
                    }
                } else {
                    reportList
                }
            }
            .navigationTitle("PowerView")
            .navigationDestination(for: UUID.self) { id in
                if let report = store.report(id: id) {
                    ReportView(report: report)
                } else {
                    ContentUnavailableView("Report Not Found", systemImage: "questionmark.folder")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("How to Capture", systemImage: "questionmark.circle") { isShowingHelp = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import", systemImage: "plus") { isPickingFile = true }
                        .disabled(store.isImporting)
                }
            }
        }
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: Self.importTypes) { result in
            if case .success(let url) = result {
                Task { await store.importFile(at: url, accessSecurityScope: true) }
            }
        }
        .sheet(isPresented: $isShowingHelp) { CaptureHelpView() }
        .overlay {
            if let progress = store.progress {
                ImportProgressView(progress: progress)
            }
        }
        .alert("Couldn't Import", isPresented: Binding(get: { store.importError != nil }, set: { if !$0 { store.importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.importError ?? "")
        }
        .onChange(of: store.lastImportedID) { _, id in
            if let id { path = [id] }
        }
    }

    private var reportList: some View {
        List {
            Section {
                ForEach(store.reports) { report in
                    NavigationLink(value: report.id) {
                        ReportRow(report: report)
                    }
                }
                .onDelete { offsets in
                    offsets.map { store.reports[$0] }.forEach(store.delete)
                }
            } footer: {
                Text("Reports are created on this device and never leave it.")
            }
        }
    }

    static let importTypes: [UTType] = [.gzip, .tarArchive, .archive, UTType(filenameExtension: "PLSQL") ?? .database, .data]
}

#Preview {
    ContentView()
        .environment(ReportStore())
}
