import Foundation

/// Names of the values plotted in charts, which VoiceOver reads out. Swift Charts doesn't look these up
/// in the string catalog, so they're passed already localized, and kept here so that a chart with
/// thousands of marks doesn't look one up for each mark.
nonisolated enum ChartLabel {
    static let app = String(localized: "App", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let bottom = String(localized: "Bottom", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let category = String(localized: "Category", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let component = String(localized: "Component", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let day = String(localized: "Day", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let end = String(localized: "End", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let energy = String(localized: "Energy", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let event = String(localized: "Event", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let floor = String(localized: "Floor", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let hour = String(localized: "Hour", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let kind = String(localized: "Kind", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let level = String(localized: "Level", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let low = String(localized: "Low", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let notifications = String(localized: "Notifications", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let segment = String(localized: "Segment", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let selected = String(localized: "Selected", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let series = String(localized: "Series", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let sessions = String(localized: "Sessions", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let start = String(localized: "Start", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let startingLevel = String(localized: "Starting Level", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let temperature = String(localized: "Temperature", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let top = String(localized: "Top", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let value = String(localized: "Value", comment: "A kind of value in a chart, read out by VoiceOver.")
    static let warm = String(localized: "Warm", comment: "A kind of value in a chart, read out by VoiceOver.")
}
