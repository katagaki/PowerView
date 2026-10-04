import SwiftUI

/// Screens the App Store screenshot script opens on launch with `-screenshot <scene>`.
/// Debug builds only; Release builds ignore the argument.
enum ScreenshotScene: String, Hashable {
    case library, report, battery, hourly, screen, notifications, apps, network, charging, stability, compare

    static var current: ScreenshotScene? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "screenshot").flatMap(ScreenshotScene.init)
        #else
        nil
        #endif
    }

    /// The `ReportView` section to scroll to, for scenes within the report.
    var sectionID: String? {
        switch self {
        case .battery, .hourly, .screen, .notifications, .apps, .network: rawValue
        default: nil
        }
    }

    /// True for scenes pushed on top of the report.
    var isPushed: Bool { self == .charging || self == .stability || self == .compare }

    /// Tells the screenshot script the screen has settled, by writing `Library/Caches/screenshot-ready`.
    static func markReady() async {
        try? await Task.sleep(for: .seconds(1.5))
        let url = URL.cachesDirectory.appending(path: "screenshot-ready")
        try? Data().write(to: url)
    }
}

extension View {
    /// Scrolls to, or pushes, the screen the screenshot script asked for.
    func screenshotScene(report: PowerReport, day: Int, proxy: ScrollViewProxy) -> some View {
        modifier(ScreenshotSceneModifier(report: report, day: day, proxy: proxy))
    }
}

private struct ScreenshotSceneModifier: ViewModifier {
    let report: PowerReport
    let day: Int
    let proxy: ScrollViewProxy
    @State private var pushed: ScreenshotScene?

    func body(content: Content) -> some View {
        content
            .task {
                guard let scene = ScreenshotScene.current, scene != .library else { return }
                try? await Task.sleep(for: .seconds(1))
                if let id = scene.sectionID {
                    // Again once the rows above have been measured, so it lands exactly.
                    for _ in 0..<3 {
                        proxy.scrollTo(id, anchor: .top)
                        try? await Task.sleep(for: .seconds(0.5))
                    }
                } else if scene.isPushed {
                    pushed = scene
                }
                await ScreenshotScene.markReady()
            }
            .navigationDestination(item: $pushed) { scene in
                switch scene {
                case .charging: ChargingView(report: report)
                case .stability: StabilityView(report: report)
                default: CompareView(report: report, initialDay: day)
                }
            }
    }
}
