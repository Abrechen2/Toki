import Foundation

public struct CreditCandidate: Hashable, Sendable, Identifiable {
    public enum Reason: Hashable, Sendable { case weekendWork, noteMentionsVacation }

    public var date: LocalDate
    public var reason: Reason
    public var id: LocalDate { date }
}

/// Days that may deserve a vacation credit; computed, never stored. Credited days are left out.
public enum CreditCandidates {
    public static func find(in days: [DayRecord]) -> [CreditCandidate] {
        days.sorted { $0.date < $1.date }.compactMap { day in
            guard day.credit == nil else { return nil }
            if day.date.isWeekend && Calculator.worked(day) > 0 {
                return CreditCandidate(date: day.date, reason: .weekendWork)
            }
            // Notes on vacation entries naturally mention vacation; only other entries count.
            if day.entries.contains(where: { $0.kind != .vacation && $0.note.lowercased().contains("urlaub") }) {
                return CreditCandidate(date: day.date, reason: .noteMentionsVacation)
            }
            return nil
        }
    }
}
