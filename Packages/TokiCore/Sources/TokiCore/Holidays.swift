import Foundation

/// German federal states for public holidays; `nationwide` uses only the national ones.
public enum HolidayRegion: String, Codable, CaseIterable, Sendable {
    case nationwide, badenWuerttemberg, bavaria, berlin, brandenburg, bremen, hamburg, hesse,
         mecklenburgVorpommern, lowerSaxony, northRhineWestphalia, rhinelandPalatinate, saarland,
         saxony, saxonyAnhalt, schleswigHolstein, thuringia

    public var germanName: String {
        switch self {
        case .nationwide: return "Nur bundesweite"
        case .badenWuerttemberg: return "Baden-Württemberg"
        case .bavaria: return "Bayern"
        case .berlin: return "Berlin"
        case .brandenburg: return "Brandenburg"
        case .bremen: return "Bremen"
        case .hamburg: return "Hamburg"
        case .hesse: return "Hessen"
        case .mecklenburgVorpommern: return "Mecklenburg-Vorpommern"
        case .lowerSaxony: return "Niedersachsen"
        case .northRhineWestphalia: return "Nordrhein-Westfalen"
        case .rhinelandPalatinate: return "Rheinland-Pfalz"
        case .saarland: return "Saarland"
        case .saxony: return "Sachsen"
        case .saxonyAnhalt: return "Sachsen-Anhalt"
        case .schleswigHolstein: return "Schleswig-Holstein"
        case .thuringia: return "Thüringen"
        }
    }
}

public enum Holidays {
    /// Public holidays of `year` in `region`, keyed by date, valued by German name.
    /// Bavaria includes Mariä Himmelfahrt (valid in most Bavarian communities).
    public static func dates(year: Int, region: HolidayRegion) -> [LocalDate: String] {
        let easter = easterSunday(year)
        var result: [LocalDate: String] = [
            LocalDate(year, 1, 1): "Neujahr",
            easter.adding(days: -2): "Karfreitag",
            easter.adding(days: 1): "Ostermontag",
            LocalDate(year, 5, 1): "Tag der Arbeit",
            easter.adding(days: 39): "Christi Himmelfahrt",
            easter.adding(days: 50): "Pfingstmontag",
            LocalDate(year, 10, 3): "Tag der Deutschen Einheit",
            LocalDate(year, 12, 25): "1. Weihnachtstag",
            LocalDate(year, 12, 26): "2. Weihnachtstag",
        ]
        func add(_ date: LocalDate, _ name: String, _ regions: Set<HolidayRegion>) {
            if regions.contains(region) { result[date] = name }
        }
        add(LocalDate(year, 1, 6), "Heilige Drei Könige", [.badenWuerttemberg, .bavaria, .saxonyAnhalt])
        if year >= 2019 { add(LocalDate(year, 3, 8), "Internationaler Frauentag", [.berlin]) }
        if year >= 2023 { add(LocalDate(year, 3, 8), "Internationaler Frauentag", [.mecklenburgVorpommern]) }
        add(easter.adding(days: 60), "Fronleichnam",
            [.badenWuerttemberg, .bavaria, .hesse, .northRhineWestphalia, .rhinelandPalatinate, .saarland])
        add(LocalDate(year, 8, 15), "Mariä Himmelfahrt", [.bavaria, .saarland])
        if year >= 2019 { add(LocalDate(year, 9, 20), "Weltkindertag", [.thuringia]) }
        add(LocalDate(year, 10, 31), "Reformationstag",
            [.brandenburg, .bremen, .hamburg, .mecklenburgVorpommern, .lowerSaxony, .saxony, .saxonyAnhalt,
             .schleswigHolstein, .thuringia])
        add(LocalDate(year, 11, 1), "Allerheiligen",
            [.badenWuerttemberg, .bavaria, .northRhineWestphalia, .rhinelandPalatinate, .saarland])
        add(repentanceDay(year), "Buß- und Bettag", [.saxony])
        return result
    }

    /// Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    static func easterSunday(_ year: Int) -> LocalDate {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return LocalDate(year, month, day)
    }

    /// Wednesday before 23 November.
    static func repentanceDay(_ year: Int) -> LocalDate {
        var date = LocalDate(year, 11, 22)
        while date.weekday != 4 { date = date.adding(days: -1) }
        return date
    }
}
