import Foundation

extension WeekSchedule {
    /// Minimum break under the German Working Time Act (§ 4 ArbZG):
    /// more than 6 h → 30 min, more than 9 h → 45 min.
    public static func legalBreakSeconds(forTarget target: Int) -> Int {
        if target > 9 * 3600 { return 2700 }
        if target > 6 * 3600 { return 1800 }
        return 0
    }

    /// Same target and start on the given weekdays (Apple numbering); end = start + target + legal break.
    public static func uniform(weekdays: Set<Int>, targetSeconds: Int, startSeconds: Int) -> WeekSchedule {
        let breakSeconds = legalBreakSeconds(forTarget: targetSeconds)
        let template = DayTemplate(targetSeconds: targetSeconds, startSeconds: startSeconds,
                                   endSeconds: startSeconds + targetSeconds + breakSeconds, breakSeconds: breakSeconds)
        return WeekSchedule(days: Dictionary(uniqueKeysWithValues: weekdays.map { ($0, template) }))
    }
}

extension VacationAnchor {
    /// "Vacation left today" as the starting value. The anchor is the end of yesterday, so
    /// entries from today on count; on 1 January it is today, because the entered value already
    /// contains this year's entitlement.
    public static func remaining(_ days: Double, today: LocalDate) -> VacationAnchor {
        let date = today.month == 1 && today.day == 1 ? today : today.adding(days: -1)
        return VacationAnchor(value: days, date: date, note: "Resturlaub bei der Einrichtung")
    }
}
