import Foundation

// Cached formatters to avoid repeated allocation (DateFormatter is expensive to create)
private let shortTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
}()

private let mediumDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()

private let shortDayOfWeekFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEE"
    return f
}()

private let shortDateLabelFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M/d"
    return f
}()

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var shortTimeString: String {
        shortTimeFormatter.string(from: self)
    }

    var mediumDateString: String {
        mediumDateFormatter.string(from: self)
    }

    var sectionHeaderString: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        return mediumDateString
    }

    var shortDayOfWeek: String {
        shortDayOfWeekFormatter.string(from: self)
    }

    var shortDateLabel: String {
        shortDateLabelFormatter.string(from: self)
    }
}
