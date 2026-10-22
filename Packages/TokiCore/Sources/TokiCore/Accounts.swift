import Foundation

public struct LedgerLine: Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case anchor, entitlement, vacation, credit }

    public var date: LocalDate
    public var change: Double
    public var kind: Kind
    public var note: String
    /// Balance after this line.
    public var balance: Double
}

/// Vacation account: anchor + entitlement every 1 January after the anchor − vacation days + credits.
/// Nothing expires. Only days after the anchor date count.
public struct VacationLedger {
    public let days: [DayRecord]
    public let settings: Settings

    public init(days: [DayRecord], settings: Settings) {
        self.days = days.filter { $0.date > settings.anchor.date }.sorted { $0.date < $1.date }
        self.settings = settings
    }

    public func balance(on date: LocalDate) -> Double {
        var value = settings.anchor.value + settings.entitlementPerYear * Double(newYears(through: date))
        for day in days where day.date <= date {
            value += Calculator.creditDays(day) - Calculator.vacationDays(day)
        }
        return value
    }

    /// Number of 1 January dates in (anchor date, `date`].
    private func newYears(through date: LocalDate) -> Int {
        guard date > settings.anchor.date else { return 0 }
        return max(0, date.year - settings.anchor.date.year)
    }

    public var lines: [LedgerLine] {
        lines(through: days.last?.date ?? settings.anchor.date)
    }

    /// Every booking from the anchor up to `end`, oldest first, each with the running balance.
    public func lines(through end: LocalDate) -> [LedgerLine] {
        let anchor = settings.anchor
        var events: [(date: LocalDate, order: Int, change: Double, kind: LedgerLine.Kind, note: String)] = []
        if end.year > anchor.date.year {
            for year in (anchor.date.year + 1)...end.year {
                events.append((LocalDate(year, 1, 1), 0, settings.entitlementPerYear, .entitlement, "Jahresanspruch \(year)"))
            }
        }
        for day in days where day.date <= end {
            for entry in day.entries where entry.kind == .vacation {
                events.append((day.date, 1, -1, .vacation, entry.note))
            }
            if let credit = day.credit {
                events.append((day.date, 2, 1, .credit, credit.note))
            }
        }
        events.sort { ($0.date, $0.order) < ($1.date, $1.order) }

        var balance = anchor.value
        var result = [LedgerLine(date: anchor.date, change: anchor.value, kind: .anchor, note: anchor.note, balance: balance)]
        for event in events {
            balance += event.change
            result.append(LedgerLine(date: event.date, change: event.change, kind: event.kind, note: event.note, balance: balance))
        }
        return result
    }

    /// Consecutive vacation lines (gaps of weekends/holidays allowed) folded into blocks for display.
    public func vacationBlocks(through end: LocalDate, maxGap: Int = 4) -> [VacationBlock] {
        var blocks: [VacationBlock] = []
        for line in lines(through: end) where line.kind == .vacation {
            if var last = blocks.last, last.end.days(until: line.date) <= maxGap {
                last.end = line.date
                last.days += 1
                last.balanceAfter = line.balance
                blocks[blocks.count - 1] = last
            } else {
                blocks.append(VacationBlock(start: line.date, end: line.date, days: 1, note: line.note,
                                            balanceAfter: line.balance))
            }
        }
        return blocks
    }
}

public struct VacationBlock: Hashable, Sendable {
    public var start: LocalDate
    public var end: LocalDate
    public var days: Double
    public var note: String
    public var balanceAfter: Double
}
