import Foundation

extension Date {
    var startOfDayInCurrentCalendar: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeekInCurrentCalendar: Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: self)
        let weekday = calendar.component(.weekday, from: dayStart)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: dayStart) ?? dayStart
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

enum Formatters {
    static let dayAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    static let weekDayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter
    }()

    static let hourMinute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let trendDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

func rounded(_ value: Double, places: Int = 0) -> Double {
    let divisor = pow(10.0, Double(places))
    return (value * divisor).rounded() / divisor
}
