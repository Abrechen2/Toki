import XCTest
@testable import TokiCore

final class BackupRotationTests: XCTestCase {
    func testFileNames() {
        XCTAssertEqual(BackupRotation.latestName, "Toki-Sicherung.json")
        XCTAssertEqual(BackupRotation.dailyName(LocalDate(2026, 10, 21)), "Toki-Sicherung-2026-10-21.json")
    }

    func testKeepsThirtyDaysAndIgnoresOtherFiles() {
        let today = LocalDate(2026, 10, 21)
        let names = [
            "Toki-Sicherung.json",
            "Toki-Sicherung-2026-10-21.json",
            "Toki-Sicherung-2026-09-22.json", // 29 days ago: keep (30 files incl. today)
            "Toki-Sicherung-2026-09-21.json", // 30 days ago: delete
            "Toki-Sicherung-2025-01-01.json",
            "Toki-Sicherung-kaputt.json",
            "Notizen.txt",
        ]
        XCTAssertEqual(BackupRotation.namesToDelete(existing: names, today: today),
                       ["Toki-Sicherung-2025-01-01.json", "Toki-Sicherung-2026-09-21.json"])
    }

    func testEmptyDataIsNeverWrittenAutomatically() {
        XCTAssertFalse(BackupRotation.shouldWrite(Snapshot(settings: .default, days: [])))
        let day = DayRecord(date: LocalDate(2026, 10, 21), targetSeconds: 0, entries: [TimeEntry(kind: .vacation)])
        XCTAssertTrue(BackupRotation.shouldWrite(Snapshot(settings: .default, days: [day])))
    }
}
