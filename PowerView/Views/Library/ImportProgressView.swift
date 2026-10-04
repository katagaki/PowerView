import SwiftUI

struct ImportProgressView: View {
    let progress: ImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView(value: progress.fraction) {
                    Text(progress.title)
                        .font(.headline)
                } currentValueLabel: {
                    Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                        .contentTransition(.identity)
                }
                Text("Large sysdiagnoses can take a minute. Keep PowerView open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32, style: .continuous))
            .padding()
        }
        .animation(.default, value: progress)
    }
}
