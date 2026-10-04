import Charts
import SwiftUI

/// A rectangle covering `start..<end` hours, from 0 to `value`.
struct LaneBar: ChartContent {
    let start: Double
    let end: Double
    let value: Double
    let style: AnyShapeStyle

    init(start: Double, end: Double, value: Double, style: some ShapeStyle) {
        self.start = start
        self.end = end
        self.value = value
        self.style = AnyShapeStyle(style)
    }

    var body: some ChartContent {
        RectangleMark(xStart: .value("Start", start), xEnd: .value("End", end),
                      yStart: .value("Bottom", 0), yEnd: .value("Value", value))
            .foregroundStyle(style)
    }
}
