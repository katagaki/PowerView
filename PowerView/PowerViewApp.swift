import SwiftUI

@main
struct PowerViewApp: App {
    @State private var store = ReportStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .onOpenURL { url in
                    Task { await store.importFile(at: url, accessSecurityScope: true) }
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        Task { await store.importSharedFiles() }
                    }
                }
        }
    }
}
