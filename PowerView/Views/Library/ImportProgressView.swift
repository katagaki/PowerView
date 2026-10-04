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
                }
                Text("Large sysdiagnoses can take a minute. Keep PowerView open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding()
        }
        .animation(.default, value: progress)
    }
}
