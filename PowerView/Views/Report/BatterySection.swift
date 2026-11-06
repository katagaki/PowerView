import SwiftUI

/// The day's battery level, with its temperature when that was kept.
struct BatterySection: View {
    let day: DayReport

    var body: some View {
        Section {
            BatteryChartView(day: day)
            if let temperature = day.temperature {
                TemperatureChartView(series: temperature, axis: day.axis)
            }
        } header: {
            Text("Battery Level")
        } footer: {
            if let stretch = day.stretch {
                Text(footer(for: stretch))
            }
        }
    }

    private func footer(for stretch: BatteryStretch) -> String {
        let start = day.axis.clock(stretch.start)
        let length = Format.hours(stretch.end - stretch.start)
        return stretch.pluggedIn == nil
            ? "Unplugged at \(start) and still on battery when captured, \(length) later."
            : "Unplugged at \(start) until plugged in at \(day.axis.clock(stretch.end)), \(length) later."
    }
}
