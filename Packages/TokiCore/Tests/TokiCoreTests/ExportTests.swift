import XCTest
@testable import TokiCore

final class ExportTests: XCTestCase {
    private let saturday = DayRecord(date: LocalDate(2030, 1, 12), targetSeconds: 0,
                                     entries: [TimeEntry(kind: .work, startSeconds: 9 * 3600, endSeconds: 11 * 3600,
                                                         note: "Aufbau; Halle \"B\"")])
    private let monday = DayRecord(date: LocalDate(2030, 1, 14), targetSeconds: 8 * 3600,
                                   entries: [TimeEntry(kind: .work, startSeconds: 8 * 3600, endSeconds: 16 * 3600,
                                                       note: "Urlaub verschoben")])

    func testCreditCandidates() {
        let credited = DayRecord(date: LocalDate(2030, 1, 13), targetSeconds: 0,
                                 entries: [TimeEntry(kind: .work, startSeconds: 0, endSeconds: 3600)],
                                 credit: Credit(note: "x"))
        let candidates = CreditCandidates.find(in: [saturday, credited, monday])
        XCTAssertEqual(candidates.map(\.date), [LocalDate(2030, 1, 12), LocalDate(2030, 1, 14)])
        XCTAssertEqual(candidates.map(\.reason), [.weekendWork, .noteMentionsVacation])
    }

    func testVacationNotesAreNoCreditCandidates() {
        let vacation = DayRecord(date: LocalDate(2030, 8, 5), targetSeconds: 0,
                                 entries: [TimeEntry(kind: .vacation, note: "Sommerurlaub")])
        let holiday = DayRecord(date: LocalDate(2030, 5, 1), targetSeconds: 0,
                                entries: [TimeEntry(kind: .publicHoliday, note: "+1 Urlaubstag")])
        XCTAssertEqual(CreditCandidates.find(in: [vacation, holiday]).map(\.date), [LocalDate(2030, 5, 1)])
    }

    func testCSVEscapesAndUsesGermanDecimals() {
        let csv = CSVExport.make(days: [saturday, monday])
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "Datum;Wochentag;Art;Beginn;Ende;Pause;Soll;Ist;Überstunden;Gutschrift;Notiz")
        XCTAssertEqual(lines[1], "12.01.2030;Sa;Arbeit;09:00;11:00;0,00;0,00;2,00;2,00;;\"Aufbau; Halle \"\"B\"\"\"")
        XCTAssertEqual(lines.count, 3)
    }

    func testCreditShowsInCSV() {
        var day = saturday
        day.credit = Credit(note: "WE")
        let line = CSVExport.make(days: [day]).split(separator: "\n")[1]
        XCTAssertTrue(line.contains(";2,00;0,00;1;"))
    }

    func testSnapshotRoundTrip() throws {
        let snapshot = Snapshot(settings: .default, days: [saturday, monday])
        let decoded = try Snapshot.decode(snapshot.encoded())
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.version, 1)
    }

    func testMergeReplacesSameDayAndIsIdempotent() {
        let replacement = DayRecord(date: monday.date, targetSeconds: 0, entries: [TimeEntry(kind: .vacation)])
        let once = DayMerge.merge(existing: [saturday, monday], incoming: [replacement])
        let twice = DayMerge.merge(existing: once, incoming: [replacement])
        XCTAssertEqual(once.count, 2)
        XCTAssertEqual(twice, once)
        XCTAssertEqual(once.last?.entries.first?.kind, .vacation)
    }

    func testMergeKeepsExistingCredit() {
        var credited = saturday
        credited.credit = Credit(note: "behalten")
        let merged = DayMerge.merge(existing: [credited], incoming: [saturday])
        XCTAssertEqual(merged.first?.credit?.note, "behalten")
    }
}
