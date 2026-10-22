import Foundation
import Observation
import TokiCore
import UIKit

/// Writes the full snapshot into a folder the owner picked once (e.g. iCloud Drive/Toki):
/// `Toki-Sicherung.json` plus one file per day, 30 days kept. The folder is remembered as a
/// security-scoped bookmark; failures are shown in the UI, never swallowed.
@MainActor
@Observable
final class AutoBackup {
    private(set) var folderName: String?
    private(set) var lastBackup: Date?
    private(set) var lastError: String?
    private(set) var isWriting = false

    @ObservationIgnored private let defaults: UserDefaults
    /// Newest snapshot that arrived while a write was running; written right after it.
    @ObservationIgnored private var pending: Snapshot?
    private static let bookmarkKey = "autoBackup.bookmark"
    private static let lastBackupKey = "autoBackup.last"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastBackup = defaults.object(forKey: Self.lastBackupKey) as? Date
        folderName = (try? resolveFolder())?.lastPathComponent
    }

    var isEnabled: Bool { defaults.data(forKey: Self.bookmarkKey) != nil }

    /// Remembers the folder picked in the document picker and writes a first backup.
    func setFolder(_ url: URL, snapshot: Snapshot) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Self.bookmarkKey)
            folderName = url.lastPathComponent
            lastError = nil
        } catch {
            lastError = String(localized: "Ordner kann nicht gemerkt werden: \(error.localizedDescription)")
            return
        }
        backup(snapshot)
    }

    func disable() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        folderName = nil
        lastError = nil
    }

    /// Writes latest + today's file and removes daily files older than 30 days.
    func backup(_ snapshot: Snapshot) {
        guard isEnabled, BackupRotation.shouldWrite(snapshot) else { return }
        guard !isWriting else {
            pending = snapshot
            return
        }
        let folder: URL
        let data: Data
        do {
            folder = try resolveFolder()
            data = try snapshot.encoded()
        } catch {
            lastError = error.localizedDescription
            return
        }
        isWriting = true
        let today = LocalDate.today()
        // Lets the write finish when the app is just being sent to the background.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Toki backup")
        Task.detached(priority: .utility) {
            let result = Result { try Self.write(data, to: folder, today: today) }
            await MainActor.run {
                self.isWriting = false
                UIApplication.shared.endBackgroundTask(backgroundTask)
                switch result {
                case .success:
                    let now = Date()
                    self.lastBackup = now
                    self.lastError = nil
                    self.defaults.set(now, forKey: Self.lastBackupKey)
                case .failure(let error):
                    self.lastError = error.localizedDescription
                }
                if let next = self.pending {
                    self.pending = nil
                    self.backup(next)
                }
            }
        }
    }

    private func resolveFolder() throws -> URL {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var stale = false
        let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(fresh, forKey: Self.bookmarkKey)
            }
        }
        return url
    }

    nonisolated private static func write(_ data: Data, to folder: URL, today: LocalDate) throws {
        guard folder.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        let coordinator = NSFileCoordinator()
        for name in [BackupRotation.latestName, BackupRotation.dailyName(today)] {
            var coordinationError: NSError?
            var writeError: Error?
            coordinator.coordinate(writingItemAt: folder.appendingPathComponent(name), options: .forReplacing,
                                   error: &coordinationError) { url in
                do { try data.write(to: url, options: .atomic) } catch { writeError = error }
            }
            if let error = coordinationError ?? writeError { throw error }
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        for name in BackupRotation.namesToDelete(existing: names, today: today) {
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: folder.appendingPathComponent(name), options: .forDeleting,
                                   error: &coordinationError) { url in
                try? FileManager.default.removeItem(at: url) // a leftover old file is harmless
            }
        }
    }
}
