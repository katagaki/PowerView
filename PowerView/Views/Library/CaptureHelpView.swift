import SwiftUI

struct CaptureHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "Press and hold both volume buttons and the side button for about 1.5 seconds, then let go. You may feel a short vibration.")
                    step(2, "Wait about 10 minutes while the sysdiagnose is created.")
                    step(3, "Open Settings › Privacy & Security › Analytics & Improvements › Analytics Data.")
                    step(4, "Find the file that starts with sysdiagnose_, tap the Share button and choose PowerView. You can also save it to Files and import it here.")
                } header: {
                    Text("Capture")
                }
                Section {
                    Label("The power log keeps about a month of battery levels, about two weeks of hourly records and only the last day or two of second-by-second events. Capture soon after the day you want to look at.", systemImage: "clock.arrow.circlepath")
                    Label("A sysdiagnose contains personal data. PowerView reads only the power log and processes it on this device.", systemImage: "lock")
                } header: {
                    Text("Good to Know")
                }
            }
            .navigationTitle("Capture a Sysdiagnose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.tint)
        }
    }
}
