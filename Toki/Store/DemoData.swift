#if DEBUG
import Foundation
import TokiCore

/// Made-up sample data for App Store screenshots (`TOKI_DEMO=1` with `-uiTesting`). No real data.
enum DemoData {
    /// German or English sample texts, following the app language of the screenshot run.
    private static let german = Locale.preferredLanguages.first?.hasPrefix("de") ?? true
    private static func text(_ de: String, _ en: String) -> String { german ? de : en }

    @MainActor
    static func seed(into store: AppStore, today: LocalDate = .today()) {
        var settings = Settings.default
        settings.jobName = text("Muster GmbH", "Example Ltd")
        settings.entitlementPerYear = 30
        settings.anchor = VacationAnchor(value: 4, date: LocalDate(today.year - 1, 12, 31), note: text("Übertrag Vorjahr", "Carried over"))
        settings.initialOvertimeSeconds = 2 * 3600
        settings.schedule = .uniform(weekdays: [2, 3, 4, 5, 6], targetSeconds: 8 * 3600, startSeconds: 8 * 3600)
        settings.holidayRegion = .bavaria
        settings.office = OfficeLocation(latitude: 48.1236, longitude: 11.6036, radius: 150, name: text("Büro", "Office"), notify: true,
                                         since: today.adding(days: -60).date())
        store.saveSettings(settings)

        let holidays = Holidays.dates(year: today.year, region: .bavaria)
        // Start/end variations in minutes, repeating; deterministic so screenshots are stable.
        let starts = [-5, 10, 0, -15, 5, 20, -10, 0, 15, -5, 0, 10, -20]
        let ends = [25, 50, 0, 70, 10, -20, 40, 15, 95, 5, -35, 30, 55]
        var index = 0
        var date = LocalDate(today.year, 1, 2)
        while date < today {
            defer { date = date.adding(days: 1) }
            guard (2...6).contains(date.weekday) else { continue }
            if holidays[date] != nil {
                store.save(DayRecord(date: date, targetSeconds: 0, entries: [TimeEntry(kind: .publicHoliday)]))
                continue
            }
            index += 1
            let start = 8 * 3600 + starts[index % starts.count] * 60
            let end = 16 * 3600 + 30 * 60 + ends[index % ends.count] * 60
            var entry = TimeEntry.work(start: start, end: end, breakSeconds: 1800)
            if today.days(until: date) >= -12 && index % 2 == 0 {
                entry.origin = EntryOrigin(source: .location, uncertain: [])
            }
            store.save(DayRecord(date: date, targetSeconds: 8 * 3600, entries: [entry]))
        }

        // A few special days.
        for day in workdays(from: LocalDate(today.year, 2, 10), count: 2) { replace(store, day, [TimeEntry(kind: .sick)]) }
        replace(store, previous(.friday, before: LocalDate(today.year, 3, 20)), [TimeEntry(kind: .overtimeReduction)])
        for day in workdays(from: LocalDate(today.year, 8, 3), count: 10) {
            replace(store, day, [TimeEntry(kind: .vacation, note: text("Sommerurlaub", "Summer holiday"))])
        }
        for day in workdays(from: today.adding(days: -44), count: 3) {
            replace(store, day, [TimeEntry(kind: .vacation, note: text("Brückentage", "Bridge days"))])
        }

        let saturday = previous(.saturday, before: today.adding(days: -9))
        store.save(DayRecord(date: saturday, targetSeconds: 0,
                             entries: [TimeEntry.work(start: 9 * 3600, end: 15 * 3600 + 30 * 60, breakSeconds: 1800,
                                                      note: text("Messe-Aufbau", "Trade fair setup"))],
                             credit: Credit(note: text("Wochenend-Einsatz Messe", "Weekend trade fair"))))

        let trip = VacationPlanner.plan(from: today.adding(days: 23), workdays: 8, schedule: settings.schedule,
                                        region: .bavaria, existing: store.days)
        store.bookVacation(trip.filter { $0.status == .book }.map(\.date), note: text("Gardasee", "Lake Garda"))

        // Today: at the office since 08:05.
        if (2...6).contains(today.weekday) {
            store.recordArrival(at: Calendar.current.date(bySettingHour: 8, minute: 5, second: 0, of: today.date()) ?? Date())
        }
    }

    private enum Weekday: Int { case friday = 6, saturday = 7 }

    private static func previous(_ weekday: Weekday, before date: LocalDate) -> LocalDate {
        var day = date
        while day.weekday != weekday.rawValue { day = day.adding(days: -1) }
        return day
    }

    /// `count` weekdays (Mon–Fri) starting at `date`.
    private static func workdays(from date: LocalDate, count: Int) -> [LocalDate] {
        var result: [LocalDate] = []
        var day = date
        while result.count < count {
            if (2...6).contains(day.weekday) { result.append(day) }
            day = day.adding(days: 1)
        }
        return result
    }

    @MainActor
    private static func replace(_ store: AppStore, _ date: LocalDate, _ entries: [TimeEntry]) {
        var record = store.day(date)
        record.entries = entries
        store.save(record)
    }
}
#endif
