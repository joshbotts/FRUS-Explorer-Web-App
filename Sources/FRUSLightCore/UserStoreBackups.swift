// The user store's daily backup (PLAN's S14b): a copy of app.db through the backup API into
// /data/backups once a day at a set hour, and whenever the newest is more than 24 hours old; none
// when the store has not changed since the newest; seven kept. Each finished copy is also written
// to a second folder, the host folder Compose mounts at /backups, which outlives the Docker volume
// and which the host's own backup sees.

import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// When a backup is due: once a day when `hour` begins in `timeZone`, and whenever the newest is
/// more than 24 hours old, so one the hour finds asleep is taken soon after the machine wakes.
public struct BackupSchedule: Sendable, Equatable {
    /// 0 to 23.
    public var hour: Int
    public var timeZone: TimeZone

    /// How often a server asks whether a backup is due, beside the hour itself: a Mac that slept
    /// through the hour backs up within this of waking.
    public static let checkInterval: Duration = .seconds(300)
    /// How old the newest backup may grow before another is due, whatever the hour.
    public static let maximumAge: TimeInterval = 24 * 60 * 60

    public init(hour: Int = 3, timeZone: TimeZone = .current) {
        self.hour = hour
        self.timeZone = timeZone
    }

    /// The last time, at or before `date`, that the hour began: today's, or yesterday's before
    /// today's has come. On a day whose clocks skip the hour, the time they skip to.
    public func lastHour(atOrBefore date: Date) -> Date {
        for days in [0, -1, -2] {
            guard let day = calendar.date(byAdding: .day, value: days, to: date),
                  let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day, matchingPolicy: .nextTime)
            else { continue }
            if start <= date { return start }
        }
        return date.addingTimeInterval(-Self.maximumAge)
    }

    /// The next time after `date` that the hour begins.
    public func nextHour(after date: Date) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0, second: 0), matchingPolicy: .nextTime)
            ?? date.addingTimeInterval(Self.maximumAge)
    }

    /// Whether a backup is due at `date`, the newest having been taken at `newest`: there is none,
    /// the hour has begun since it was taken, or it is more than 24 hours old.
    public func isDue(at date: Date, newest: Date?) -> Bool {
        guard let newest else { return true }
        return newest < lastHour(atOrBefore: date) || date.timeIntervalSince(newest) > Self.maximumAge
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

/// The user store's backups: one taken when `schedule` says one is due and the store has changed
/// since the newest, the newest `keep` kept, and each also copied to `copyDirectory` when there is
/// one. The server asks every few minutes; `frus-light backup` asks for one now.
public actor UserStoreBackups {
    public nonisolated let store: URL
    public nonisolated let directory: URL
    public nonisolated let copyDirectory: URL?
    public nonisolated let schedule: BackupSchedule
    public nonisolated let keep: Int
    private let lock: URL
    /// The store's `SQLiteUserStore.changeMarker()`, in the process that holds it, so a look that
    /// finds the mark where it was reads nothing. Nil for another process, which reads the store.
    private let changeMarker: (@Sendable () throws -> UserStoreChangeMarker)?
    /// The backup the store was last found to hold the same as, and the store's mark then.
    private var sameAs: (name: String, marker: UserStoreChangeMarker)?
    /// The fingerprint of each backup read, by name, with the size and time the file had then.
    private var fingerprints: [String: (bytes: Int64, modified: Date, fingerprint: String)] = [:]

    /// How many daily backups are kept: SPEC's seven.
    public static let kept = 7

    public init(files: DataDirectory, copyDirectory: URL?, schedule: BackupSchedule, keep: Int = UserStoreBackups.kept,
                changeMarker: (@Sendable () throws -> UserStoreChangeMarker)? = nil) {
        store = files.userStore
        directory = files.backupsDirectory
        self.copyDirectory = copyDirectory
        self.schedule = schedule
        self.keep = keep
        lock = files.backupLock
        self.changeMarker = changeMarker
    }

    /// What a look at the backups did.
    public enum Outcome: Sendable, Equatable {
        /// None was due.
        case notDue
        /// One was due, or asked for, and the store holds no research yet: a new store's backup
        /// would hold nothing, and would hold off the first that does until the hour.
        case empty
        /// One was due, or asked for, and the store holds what the newest holds.
        case unchanged(newest: UserStoreBackupFile)
        /// One was taken, and `copy` says whether it reached `copyDirectory`.
        case taken(UserStoreBackupFile, copy: Copy)
    }

    /// Whether a backup reached the folder it is copied to.
    public enum Copy: Sendable, Equatable {
        /// There is no such folder.
        case none
        case copied
        /// It could not be written there, for this reason; the backup in `directory` stands.
        case failed(String)
    }

    /// The server's look, every few minutes and when the hour begins: a backup when one is due and
    /// the store has changed since the newest.
    public func check(at date: Date) async throws -> Outcome {
        try await look(at: date, asked: false)
    }

    /// `frus-light backup`'s: a backup now, unless the store holds what the newest does.
    public func backUp(at date: Date) async throws -> Outcome {
        try await look(at: date, asked: true)
    }

    /// The daily backups in `directory`, newest first.
    public func dailyBackups() -> [UserStoreBackupFile] {
        UserStoreBackup.files(in: directory).filter { $0.kind == .daily }
    }

    private func look(at date: Date, asked: Bool) async throws -> Outcome {
        // Without the lock first, so the look every few minutes reads only the folder's names.
        if !asked, !schedule.isDue(at: date, newest: dailyBackups().first?.takenAt) { return .notDue }
        let held = try FileLock(lock)
        try await held.lock(.exclusive)
        defer { held.unlock() }
        // Another process may have taken one in the meantime.
        let newest = dailyBackups().first
        if !asked, !schedule.isDue(at: date, newest: newest?.takenAt) { return .notDue }
        // Read before the store is, so a change that comes after it is found by the next look.
        let marker = try changeMarker?()
        if let newest, let marker, let sameAs, sameAs.name == newest.name, sameAs.marker == marker {
            return .unchanged(newest: newest)
        }
        let store = self.store
        // So a new store's first backup is taken at the look after its first import or note.
        if try await Blocking.run({ try UserStoreBackup.holdsNoResearch(store) }) { return .empty }
        if let newest {
            let now = try await Blocking.run { try UserStoreBackup.fingerprint(of: store) }
            if try await fingerprint(of: newest) == now {
                if let marker { sameAs = (newest.name, marker) }
                return .unchanged(newest: newest)
            }
        }
        let name = UserStoreBackup.dailyName(at: date, in: [directory] + (copyDirectory.map { [$0] } ?? []))
        let url = try await UserStoreBackup.copy(of: store, into: directory, named: name)
        guard let taken = UserStoreBackupFile(url) else { preconditionFailure("\(name) is not a backup's name") }
        _ = try await fingerprint(of: taken)
        if let marker { sameAs = (name, marker) }
        prune(directory)
        return .taken(taken, copy: copyOut())
    }

    /// A backup's fingerprint, read once while the file stays as it was.
    private func fingerprint(of backup: UserStoreBackupFile) async throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: backup.url.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        let modified = attributes[.modificationDate] as? Date ?? .distantPast
        if let known = fingerprints[backup.name], known.bytes == bytes, known.modified == modified { return known.fingerprint }
        let url = backup.url
        let fingerprint = try await Blocking.run { try UserStoreBackup.fingerprint(of: url, immutable: true) }
        fingerprints[backup.name] = (bytes, modified, fingerprint)
        return fingerprint
    }

    /// Removes from `folder` its daily backups older than the newest `keep`, beyond `keeping`, and
    /// the partial files a copy cut short left there more than an hour ago. Other copies stay.
    private func prune(_ folder: URL, keeping: Set<String>? = nil) {
        let manager = FileManager.default
        let daily = UserStoreBackup.files(in: folder).filter { $0.kind == .daily }
        let kept = keeping ?? Set(daily.prefix(keep).map(\.name))
        for file in daily where !kept.contains(file.name) {
            try? manager.removeItem(at: file.url)
            fingerprints[file.name] = nil
        }
        let hourAgo = Date().addingTimeInterval(-3_600)
        for name in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
        where name.hasPrefix("app-") && (name.hasSuffix(".partial") || name.hasSuffix(".partial-journal")) {
            let url = folder.appendingPathComponent(name)
            let modified = (try? manager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            if let modified, modified < hourAgo { try? manager.removeItem(at: url) }
        }
    }

    /// Brings `copyDirectory` to the newest `keep` daily backups of the two folders: each it lacks is
    /// copied from `directory`, and any older one is removed from it. So it keeps seven, the one
    /// just taken among them; one whose permissions are fixed is filled again; and one that holds
    /// newer backups than the volume, as after the volume was lost, gives up one for each taken.
    private func copyOut() -> Copy {
        guard let copyDirectory else { return .none }
        let ours = dailyBackups()
        let theirs = UserStoreBackup.files(in: copyDirectory).filter { $0.kind == .daily }
        let present = Set(theirs.map(\.name))
        var newest: [UserStoreBackupFile] = []
        for file in (ours + theirs).sorted(by: { $0.isNewer(than: $1) }) where !newest.contains(where: { $0.name == file.name }) {
            newest.append(file)
            if newest.count == keep { break }
        }
        var failure: String?
        for file in newest where !present.contains(file.name) {
            guard let source = ours.first(where: { $0.name == file.name }) else { continue }
            do {
                _ = try UserStoreBackup.copyFile(source.url, into: copyDirectory)
            } catch {
                failure = failure ?? "\(error)"
            }
        }
        prune(copyDirectory, keeping: Set(newest.map(\.name)))
        return failure.map(Copy.failed) ?? .copied
    }
}

extension UserStoreBackups {
    /// Whether `directory` can take a backup's copy now, or why not: what a server says at its start.
    public static func problem(writing directory: URL) -> String? {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return "\(directory.path) is not a folder: nothing is mounted there"
        }
        let probe = directory.appendingPathComponent(".frus-light-probe-\(UUID().uuidString)")
        guard manager.createFile(atPath: probe.path, contents: Data()) else {
            return "\(directory.path) cannot be written by the server's user, UID \(getuid())"
        }
        try? manager.removeItem(at: probe)
        return nil
    }
}
