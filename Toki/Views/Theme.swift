import SwiftUI
import TokiCore

/// Dark colours modelled on the look of classic iOS time trackers.
enum Theme {
    static let accent = Color(red: 0x4A / 255, green: 0x9B / 255, blue: 0xFF / 255)
    static let positive = Color(red: 0x5A / 255, green: 0xC7 / 255, blue: 0x77 / 255)
    static let negative = Color(red: 0xFF / 255, green: 0x5A / 255, blue: 0x52 / 255)
    static let weekend = Color(red: 0xF0 / 255, green: 0x94 / 255, blue: 0x3A / 255)
    static let card = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let secondaryText = Color(red: 0xA1 / 255, green: 0xA1 / 255, blue: 0xA6 / 255)

    /// Palette for categories (index stored in `EntryCategory.colorIndex`).
    static let categoryColors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]

    static func categoryColor(_ index: Int) -> Color { categoryColors[((index % categoryColors.count) + categoryColors.count) % categoryColors.count] }

    static func overtimeColor(_ seconds: Int) -> Color {
        if abs(seconds) < 30 { return secondaryText }
        return seconds > 0 ? positive : negative
    }
}

extension EntryKind {
    var localizedName: String {
        switch self {
        case .work: return String(localized: "Arbeit")
        case .vacation: return String(localized: "Urlaub")
        case .sick: return String(localized: "Krankheit")
        case .childSick: return String(localized: "Kind krank")
        case .publicHoliday: return String(localized: "Feiertag")
        case .specialLeave: return String(localized: "Sonderurlaub")
        case .overtimeReduction: return String(localized: "Überstundenabbau")
        case .separateTime: return String(localized: "Sonderzeit")
        }
    }

    var symbol: String {
        switch self {
        case .work: return "clock"
        case .vacation: return "beach.umbrella"
        case .sick: return "cross.case"
        case .childSick: return "figure.and.child.holdinghands"
        case .publicHoliday: return "calendar"
        case .specialLeave: return "gift"
        case .overtimeReduction: return "hourglass"
        case .separateTime: return "tag"
        }
    }
}

extension UncertainReason {
    var localizedName: String {
        switch self {
        case .missingEnd: return String(localized: "Ende fehlt")
        case .overnight: return String(localized: "über Mitternacht")
        case .longDay: return String(localized: "über 12 Stunden")
        case .unusualTime: return String(localized: "ungewöhnliche Uhrzeit")
        case .nonWorkday: return String(localized: "Wochenende/Feiertag")
        }
    }
}

enum DateText {
    static func weekdayShort(_ date: LocalDate) -> String {
        date.date().formatted(.dateTime.weekday(.abbreviated))
    }

    static func dayMonth(_ date: LocalDate) -> String {
        date.date().formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    static func long(_ date: LocalDate) -> String {
        date.date().formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    static func medium(_ date: LocalDate) -> String {
        date.date().formatted(date: .abbreviated, time: .omitted)
    }

    static func monthYear(_ date: LocalDate) -> String {
        date.date().formatted(.dateTime.month(.wide).year())
    }
}

/// Summary tile used on month, vacation and overview screens.
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum TimeOfDay {
    /// DatePicker binding for seconds from midnight on `date`. Sets hour/minute instead of adding
    /// seconds, so DST change days show the right time; values past midnight wrap.
    static func binding(_ seconds: Binding<Int>, on date: LocalDate) -> Binding<Date> {
        let midnight = date.date()
        return Binding(
            get: {
                let value = seconds.wrappedValue % 86400
                return Calendar.current.date(bySettingHour: value / 3600, minute: value % 3600 / 60,
                                             second: 0, of: midnight) ?? midnight
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                seconds.wrappedValue = (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60
            }
        )
    }
}

extension LocalDate {
    /// Numeric date in the user's language (16.11.2026 / 11/16/2026); files keep the German form.
    var display: String { date().formatted(date: .numeric, time: .omitted) }

    /// Bridge for SwiftUI DatePicker bindings.
    static func binding(_ source: Binding<LocalDate>) -> Binding<Date> {
        Binding(get: { source.wrappedValue.date() },
                set: { source.wrappedValue = LocalDate(date: $0, calendar: .current) })
    }
}
