import XCTest

/// Automatic backup end to end: an empty app writes nothing, a change produces the files.
final class AutoBackupUITests: XCTestCase {
    func testChangeWritesBackupFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("toki-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchEnvironment = ["TOKI_BACKUP_FOLDER": folder.path]
        app.launch()

        let latest = folder.appendingPathComponent("Toki-Sicherung.json")
        sleep(2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: latest.path), "empty app must not write a backup")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        app.buttons["day-\(today)"].tap()
        app.buttons["quickWorkday"].tap()

        let deadline = Date().addingTimeInterval(15)
        while !FileManager.default.fileExists(atPath: latest.path) && Date() < deadline { usleep(250_000) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: latest.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Toki-Sicherung-\(today).json").path))

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: latest)) as? [String: Any]
        let days = json?["days"] as? [[String: Any]]
        XCTAssertEqual(days?.count, 1)
        XCTAssertEqual(days?.first?["date"] as? String, today)

        app.tabBars.buttons["Mehr"].tap()
        XCTAssertTrue(app.staticTexts["Letzte Sicherung"].waitForExistence(timeout: 5))
    }
}
