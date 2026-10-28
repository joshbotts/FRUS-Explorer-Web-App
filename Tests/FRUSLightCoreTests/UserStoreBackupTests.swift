// The user store's daily backup (S14b): due when the hour begins and when the newest is a day old,
// so one is taken soon after a missed hour; none when the store has not changed since the newest;
// seven kept, beside every other copy; each copied to a second folder, which keeps its own seven.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserStoreBackupTests {
    static let utc = TimeZone(identifier: "UTC")!
    /// 2026-10-27T03:00:00Z, the hour of the fixture's daily backup.
    static let hour = Date(timeIntervalSince1970: 1_793_070_000)
    static let day: TimeInterval = 24 * 60 * 60
    static let minute: TimeInterval = 60

    /// A store, its backups folder and a second folder for their copies.
    struct Fixture {
        let directory: TemporaryDirectory
        let files: DataDirectory
        let copies: URL
        let store: SQLiteUserStore
        let rows: UserStoreRows

        init() async throws {
            directory = try TemporaryDirectory()
            files = DataDirectory(root: directory.url.appendingPathComponent("data"))
            try files.prepare()
            copies = directory.url.appendingPathComponent("host-backups")
            try FileManager.default.createDirectory(at: copies, withIntermediateDirectories: true)
            store = try await SQLiteUserStore(url: files.userStore, backupsDirectory: files.backupsDirectory)
            rows = try UserStoreRows(files.userStore)
        }

        /// The server's backups, with the store's mark, or a second process's without it.
        func backups(copyingTo copies: URL? = nil, keep: Int = UserStoreBackups.kept, marked: Bool = true) -> UserStoreBackups {
            let store = self.store
            let marker: (@Sendable () throws -> UserStoreChangeMarker)? = marked ? { @Sendable in try store.changeMarker() } : nil
            return UserStoreBackups(files: files, copyDirectory: copies,
                                    schedule: BackupSchedule(hour: 3, timeZone: UserStoreBackupTests.utc),
                                    keep: keep, changeMarker: marker)
        }

        /// A change to the store, made as another connection makes one.
        func change(_ name: String = UUID().uuidString) throws {
            try rows.run("INSERT INTO tags (user_id, id, name) VALUES ('owner', ?, ?)", [.text(UUID().uuidString), .text(name)])
        }

        /// The daily backups' names in `folder`, newest first.
        func daily(in folder: URL? = nil) -> [String] {
            UserStoreBackup.files(in: folder ?? files.backupsDirectory).filter { $0.kind == .daily }.map(\.name)
        }
    }

    static func name(_ date: Date) -> String { "app-\(UserStoreBackup.timestamp(date)).db" }

    @Test func aBackupIsDueWhenTheHourBeginsAndWhenTheNewestIsADayOld() throws {
        let schedule = BackupSchedule(hour: 3, timeZone: Self.utc)
        let hour = Self.hour
        #expect(schedule.isDue(at: hour, newest: nil), "the first, at once")
        #expect(!schedule.isDue(at: hour.addingTimeInterval(-Self.minute), newest: hour.addingTimeInterval(-Self.day)),
                "02:59, the day's hour not yet come")
        #expect(schedule.isDue(at: hour, newest: hour.addingTimeInterval(-Self.day)), "03:00")
        #expect(!schedule.isDue(at: hour.addingTimeInterval(6 * 3_600), newest: hour), "09:00, after the day's backup")
        // A Mac asleep from 02:00 to 09:00: the backup is due when it wakes.
        #expect(schedule.isDue(at: hour.addingTimeInterval(6 * 3_600), newest: hour.addingTimeInterval(-Self.day)))
        #expect(schedule.lastHour(atOrBefore: hour.addingTimeInterval(-1)) == hour.addingTimeInterval(-Self.day))
        #expect(schedule.lastHour(atOrBefore: hour) == hour)
        #expect(schedule.nextHour(after: hour) == hour.addingTimeInterval(Self.day))
        #expect(schedule.nextHour(after: hour.addingTimeInterval(-1)) == hour)
        // One taken at 03:30 by hand: the next day's hour is due, and nothing before it.
        let byHand = hour.addingTimeInterval(30 * Self.minute)
        #expect(!schedule.isDue(at: hour.addingTimeInterval(Self.day - 1), newest: byHand))
        #expect(schedule.isDue(at: hour.addingTimeInterval(Self.day), newest: byHand))
    }

    /// In New York: the hour of a day whose clocks fall back comes 25 hours after the last, so the
    /// day-old rule comes first; and an hour the clocks skip is the time they skip to.
    @Test func theHourIsTheContainersTimeZones() throws {
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        let schedule = BackupSchedule(hour: 3, timeZone: newYork)
        let saturday = Date(timeIntervalSince1970: 1_793_430_000)  // 2026-10-31T03:00:00-04:00
        #expect(schedule.lastHour(atOrBefore: saturday) == saturday)
        let sunday = Date(timeIntervalSince1970: 1_793_520_000)  // 2026-11-01T03:00:00-05:00
        #expect(schedule.nextHour(after: saturday) == sunday, "25 hours on")
        let dayOld = saturday.addingTimeInterval(Self.day + 30 * Self.minute)  // 02:30 on Sunday
        #expect(schedule.lastHour(atOrBefore: dayOld) == saturday)
        #expect(schedule.isDue(at: dayOld, newest: saturday), "a day old before the hour comes")
        let skipped = BackupSchedule(hour: 2, timeZone: newYork)
        let springing = Date(timeIntervalSince1970: 1_805_005_800)  // 2027-03-14T01:30:00-05:00
        #expect(skipped.nextHour(after: springing) == Date(timeIntervalSince1970: 1_805_007_600),
                "03:00 EDT, where 02:00 never comes")
    }

    /// The done-when's first half: a look when one is due takes none while the store holds what
    /// the newest holds, whether the server's, which knows the store's mark, or another process's.
    @Test func noBackupIsTakenWhenNothingChanged() async throws {
        let fixture = try await Fixture()
        try fixture.change()
        let backups = fixture.backups()
        guard case .taken(let first, .none) = try await backups.check(at: Self.hour) else {
            Issue.record("the first look takes one")
            return
        }
        #expect(first.name == Self.name(Self.hour) && first.kind == .daily)
        #expect(try StoreDump(first.url) == StoreDump(fixture.files.userStore))
        #expect(try await backups.check(at: Self.hour.addingTimeInterval(Self.minute)) == .notDue)

        let nextDay = Self.hour.addingTimeInterval(Self.day)
        #expect(try await backups.check(at: nextDay) == .unchanged(newest: first))
        #expect(try await backups.check(at: nextDay.addingTimeInterval(5 * Self.minute)) == .unchanged(newest: first),
                "and at each look after, by the store's mark")
        #expect(try await fixture.backups(marked: false).backUp(at: nextDay) == .unchanged(newest: first),
                "nor by frus-light backup, which reads the store")
        #expect(fixture.daily() == [first.name])

        try fixture.change()
        guard case .taken(let second, _) = try await backups.check(at: nextDay.addingTimeInterval(10 * Self.minute)) else {
            Issue.record("a change is backed up at the next look, the newest being a day old")
            return
        }
        #expect(try StoreDump(second.url) == StoreDump(fixture.files.userStore))
        #expect(fixture.daily() == [second.name, first.name])
    }

    /// A new store holds nothing to restore: its first backup is taken at the first look after it
    /// holds research, rather than at its start, which would hold off the first that does until
    /// the hour. A store emptied since its last backup is not backed up over it.
    @Test func noBackupIsTakenOfAStoreThatHoldsNoResearch() async throws {
        let fixture = try await Fixture()
        #expect(try UserStoreBackup.holdsNoResearch(fixture.files.userStore))
        let backups = fixture.backups()
        #expect(try await backups.check(at: Self.hour) == .empty)
        #expect(try await fixture.backups(marked: false).backUp(at: Self.hour) == .empty)
        #expect(fixture.daily().isEmpty)
        try fixture.rows.addNote("N1")
        try fixture.rows.run("INSERT INTO user_search (user_id, document_id, volume_id, note_text) VALUES ('owner', 'd1', 'frus1961-63v06', 'A note.')")
        #expect(try !UserStoreBackup.holdsNoResearch(fixture.files.userStore))
        guard case .taken(let first, _) = try await backups.check(at: Self.hour.addingTimeInterval(5 * Self.minute)) else {
            Issue.record("the look after the first note takes one")
            return
        }
        try fixture.rows.run("DELETE FROM notes")
        #expect(try !UserStoreBackup.holdsNoResearch(fixture.files.userStore), "a full-text table is read as itself")
        try fixture.rows.run("DELETE FROM user_search")
        #expect(try UserStoreBackup.holdsNoResearch(fixture.files.userStore), "and not by its own tables, which an empty one has rows in")
        #expect(try await backups.check(at: Self.hour.addingTimeInterval(Self.day)) == .empty)
        #expect(fixture.daily() == [first.name])
    }

    /// The done-when's second half: a Mac that slept through the hour backs up at the first look
    /// after it wakes, and then not again until the next day's hour.
    @Test func aBackupIsTakenSoonAfterAMissedHour() async throws {
        let fixture = try await Fixture()
        let backups = fixture.backups()
        try fixture.change("Written in the morning")
        _ = try await backups.check(at: Self.hour)
        try fixture.change("Written in the evening")
        let nextDay = Self.hour.addingTimeInterval(Self.day)
        #expect(try await backups.check(at: nextDay.addingTimeInterval(-60 * Self.minute)) == .notDue, "02:00, and then it sleeps")
        let waking = nextDay.addingTimeInterval(6 * 3_600 + 2 * Self.minute)  // 09:02
        guard case .taken(let missed, _) = try await backups.check(at: waking) else {
            Issue.record("the look after waking takes the missed backup")
            return
        }
        #expect(missed.name == Self.name(waking))
        try fixture.change("Written the next morning")
        #expect(try await backups.check(at: waking.addingTimeInterval(5 * Self.minute)) == .notDue)
        #expect(try await backups.check(at: nextDay.addingTimeInterval(Self.day - Self.minute)) == .notDue)
        guard case .taken = try await backups.check(at: nextDay.addingTimeInterval(Self.day)) else {
            Issue.record("the next day's hour takes the next")
            return
        }
        #expect(fixture.daily().count == 3)
    }

    @Test func theNewestSevenAreKeptBesideEveryOtherCopy() async throws {
        let fixture = try await Fixture()
        let folder = fixture.files.backupsDirectory
        let migration = try await fixture.store.backUp(
            into: folder, named: UserStoreBackup.nameBeforeMigration(3, at: Self.hour.addingTimeInterval(-30 * Self.day), in: folder))
        let restore = try await fixture.store.backUp(
            into: folder, named: UserStoreBackup.nameBeforeRestore(at: Self.hour.addingTimeInterval(-20 * Self.day), in: [folder]))
        let backups = fixture.backups()
        var taken: [String] = []
        for day in 0..<9 {
            try fixture.change()
            let date = Self.hour.addingTimeInterval(Double(day) * Self.day)
            guard case .taken(let backup, _) = try await backups.check(at: date) else {
                Issue.record("day \(day) takes one")
                return
            }
            taken.append(backup.name)
        }
        #expect(fixture.daily() == Array(taken.suffix(7).reversed()), "the newest seven, newest first")
        let left = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
        #expect(left.contains(migration.lastPathComponent) && left.contains(restore.lastPathComponent),
                "the copies before a migration and a restore stay until removed by hand")
        #expect(left.count == 9 && !left.contains { $0.hasSuffix(".partial") })
    }

    @Test func eachBackupIsCopiedToTheSecondFolderWhichKeepsItsOwnSeven() async throws {
        let fixture = try await Fixture()
        let backups = fixture.backups(copyingTo: fixture.copies, keep: 3)
        for day in 0..<4 {
            try fixture.change()
            guard case .taken(let backup, .copied) = try await backups.check(at: Self.hour.addingTimeInterval(Double(day) * Self.day)) else {
                Issue.record("day \(day) is taken and copied")
                return
            }
            let copy = fixture.copies.appendingPathComponent(backup.name)
            #expect(FileManager.default.contentsEqual(atPath: copy.path, andPath: backup.url.path), "byte for byte")
        }
        #expect(fixture.daily(in: fixture.copies) == fixture.daily())
        #expect(fixture.daily().count == 3)
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.copies.path).count == 3, "no partial file is left")
    }

    /// The second folder outlives the volume. Its backups are never all given up for a new store's:
    /// each backup taken replaces the oldest of the folder's seven.
    @Test func aNewVolumesBackupGivesUpOnlyTheOldestOfTheSecondFolders() async throws {
        let earlier = try await Fixture()
        let old = earlier.backups(copyingTo: earlier.copies, keep: 3)
        for day in 0..<3 {
            try earlier.change()
            _ = try await old.check(at: Self.hour.addingTimeInterval(Double(day) * Self.day))
        }
        let kept = earlier.daily(in: earlier.copies)
        #expect(kept.count == 3)

        // The volume is lost, and a new one starts on the same host folder, then holds research.
        let later = try await Fixture()
        let backups = later.backups(copyingTo: earlier.copies, keep: 3)
        #expect(try await backups.check(at: Self.hour.addingTimeInterval(10 * Self.day)) == .empty)
        #expect(later.daily(in: earlier.copies) == kept, "an empty store's backup gives up none of the folder's")
        try later.change()
        guard case .taken(let first, .copied) = try await backups.check(at: Self.hour.addingTimeInterval(10 * Self.day)) else {
            Issue.record("the new store is backed up and copied")
            return
        }
        #expect(later.daily(in: earlier.copies) == [first.name] + kept.prefix(2), "the oldest of the three gives way")
    }

    /// A second folder that cannot be written does not stop the backup, and is filled once it can be.
    @Test func aSecondFolderThatCannotBeWrittenIsFilledOnceItCan() async throws {
        let fixture = try await Fixture()
        let missing = fixture.directory.url.appendingPathComponent("not-mounted")
        #expect(UserStoreBackups.problem(writing: missing)?.contains("not a folder") == true)
        #expect(UserStoreBackups.problem(writing: fixture.copies) == nil)
        let backups = fixture.backups(copyingTo: missing)
        try fixture.change()
        guard case .taken(let first, .failed) = try await backups.check(at: Self.hour) else {
            Issue.record("the backup stands though its copy fails")
            return
        }
        #expect(FileManager.default.fileExists(atPath: first.url.path))
        try FileManager.default.createDirectory(at: missing, withIntermediateDirectories: true)
        try fixture.change()
        guard case .taken(let second, .copied) = try await backups.check(at: Self.hour.addingTimeInterval(Self.day)) else {
            Issue.record("the next is taken and copied")
            return
        }
        #expect(fixture.daily(in: missing) == [second.name, first.name], "with the one it missed")
    }

    /// The server's backups and `frus-light backup`'s take one lock, so asked at once they take one
    /// backup between them.
    @Test func twoAskingAtOnceTakeOneBackup() async throws {
        let fixture = try await Fixture()
        try fixture.change()
        _ = try await fixture.backups().check(at: Self.hour)
        try fixture.change()
        let date = Self.hour.addingTimeInterval(Self.day)
        async let server = fixture.backups().backUp(at: date)
        async let command = fixture.backups(marked: false).backUp(at: date)
        let outcomes = try await [server, command]
        #expect(outcomes.filter { if case .taken = $0 { true } else { false } }.count == 1)
        #expect(outcomes.filter { if case .unchanged = $0 { true } else { false } }.count == 1)
        #expect(fixture.daily().count == 2)
    }

    /// The fingerprint is what `holdTheSame` compares: the store's committed rows, its `-wal`'s
    /// among them, against a copy's.
    @Test func aFingerprintTellsWhetherTwoStoresHoldTheSame() async throws {
        let fixture = try await Fixture()
        try fixture.change("Before")
        let folder = fixture.files.backupsDirectory
        let copy = try await fixture.store.backUp(into: folder, named: UserStoreBackup.dailyName(at: Self.hour, in: [folder]))
        let store = fixture.files.userStore
        #expect(try UserStoreBackup.fingerprint(of: store) == UserStoreBackup.fingerprint(of: copy, immutable: true))
        #expect(try UserStoreBackup.holdTheSame(store, copy))
        try fixture.change("After")
        #expect(FileManager.default.fileExists(atPath: store.path + "-wal"), "the change is in the write-ahead log")
        #expect(try UserStoreBackup.fingerprint(of: store) != UserStoreBackup.fingerprint(of: copy, immutable: true))
        #expect(try !UserStoreBackup.holdTheSame(store, copy))
    }

    /// The store's mark moves with its own writes and with another connection's, and with nothing
    /// else.
    @Test func theStoresMarkMovesWithEachWrite() async throws {
        let fixture = try await Fixture()
        let first = try fixture.store.changeMarker()
        _ = try fixture.store.classificationOverrides()
        #expect(try fixture.store.changeMarker() == first, "a read moves nothing")
        try fixture.store.record(ClassificationOverride(volumeId: "frus1961-63v06", documentId: "d1", isEditorialNote: true,
                                                        parsedIsEditorialNote: false))
        let second = try fixture.store.changeMarker()
        #expect(second != first, "its own write")
        try fixture.change()
        #expect(try fixture.store.changeMarker() != second, "another connection's")
    }

    @Test func aBackupsNameSaysWhatItIsAndWhenItWasTaken() throws {
        let folder = URL(fileURLWithPath: "/data/backups")
        let daily = try #require(UserStoreBackupFile(folder.appendingPathComponent("app-20261027T030000Z.db")))
        #expect(daily.kind == .daily && daily.takenAt == Self.hour)
        let second = try #require(UserStoreBackupFile(folder.appendingPathComponent("app-20261027T030000Z-2.db")))
        #expect(second.kind == .daily && second.isNewer(than: daily))
        #expect(UserStoreBackupFile(folder.appendingPathComponent("app-20261024T000000Z-2-before-migration-3.db"))?.kind == .beforeMigration)
        #expect(UserStoreBackupFile(folder.appendingPathComponent("app-20261027T150000Z-before-restore.db"))?.kind == .beforeRestore)
        for name in ["app.db", "app-20261027T030000Z.db.1A2B.partial", "app-20261331T030000Z.db", "notes.db", "app-20261027T030000Z.db-wal"] {
            #expect(UserStoreBackupFile(folder.appendingPathComponent(name)) == nil, "\(name)")
        }
    }
}
