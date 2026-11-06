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
        }
    }
}
