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
        RectangleMark(xStart: .value(ChartLabel.start, start), xEnd: .value(ChartLabel.end, end),
                      yStart: .value(ChartLabel.bottom, 0), yEnd: .value(ChartLabel.value, value))
            .foregroundStyle(style)
    }
}
