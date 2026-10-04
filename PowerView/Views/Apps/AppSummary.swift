import SwiftUI

struct AppSummary: View {
    let app: AppEnergy

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.name).font(.headline)
            Text(app.bundleID).font(.caption.monospaced()).foregroundStyle(.secondary)
            Text(AppListView.usageLine(app))
                .font(.footnote)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
}
