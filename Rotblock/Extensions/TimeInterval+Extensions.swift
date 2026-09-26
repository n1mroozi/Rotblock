import Foundation

extension TimeInterval {
    var formattedDigits: String {
        let sec = Duration.seconds(self)
        let pattern: Duration.TimeFormatStyle.Pattern = sec > .seconds(60 * 60) ? .hourMinuteSecond : .minuteSecond
        return sec.formatted(.time(pattern: pattern))

    }

    var formattedString: String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: self)
    }

    static func hms(_ h: Int, _ m: Int, _ s: Int) -> TimeInterval {
        return TimeInterval(h * 3600 + m * 60 + s)
    }

}
