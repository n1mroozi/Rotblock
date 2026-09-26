import Foundation

extension DateComponents {
    var withCalendarTimeZone: DateComponents {
        var new = self
        new.timeZone = .current
        new.calendar = .current
        return new
    }
}
