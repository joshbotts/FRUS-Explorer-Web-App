// The corrections a curator makes on this server (PLAN's S21g), and their log, migration 8's `correction_log`:
// a document's classification, editorial note or document, kept as the app's `DocumentClassificationOverride`
// is in `classification_overrides`; and a person-identity correction, a merge or a separation, kept as the app's
// `PersonClusterOverride` is in `person_overrides`. Each is made and undone as the app's stores make and undo
// them (`DocumentClassificationOverrideStore`, `PersonClusterOverrideStore`), and each change is an entry of the
// log, written in the same transaction, naming who made it and when, and, once the index has taken it, when that
// was: at once on a Standalone server, through its one writer, and at the next export an Import server installs.
// Every method is written once, on `RelationalUserStore`, in SQL both stores read; none changes a row the kit's
// search reads, so none moves the search mark.

import FRUSCoreKit
import Foundation

/// A person-identity correction, as the store keeps the app's `PersonClusterOverride`: anchored on the stable
/// `(volumeId, ref)` of the persons-list records it names, never on a rollup's id, which every rebuild renumbers.
public struct PersonOverride: Sendable, Equatable {
    /// The app's id, an uppercase `uuidString`.
    public var id: String
    public var kind: PersonClusterOverrideKind
    /// The record acted on: for a separation, the one detached.
    public var volumeIdA: String
    public var refA: String
    /// The other record of a merge; nil for a separation.
    public var volumeIdB: String?
    public var refB: String?
    public var createdAt: Date?

    public init(id: String = UUID().uuidString, kind: PersonClusterOverrideKind, volumeIdA: String, refA: String,
                volumeIdB: String? = nil, refB: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.volumeIdA = volumeIdA
        self.refA = refA
        self.volumeIdB = volumeIdB
        self.refB = refB
        self.createdAt = createdAt.map(UserStoreDate.rounded)
    }

    /// The kit's value of it, which the rollup's consolidation takes, as the app's `snapshot` gives it.
    public var data: PersonClusterOverrideData {
        PersonClusterOverrideData(kind: kind, volumeIdA: volumeIdA, refA: refA, volumeIdB: volumeIdB, refB: refB)
    }
}

/// One entry of the log: a correction made or undone on this server.
public struct CorrectionLogEntry: Sendable, Equatable {
    public enum Correction: String, Sendable, Codable { case classification, person }
    public enum Action: String, Sendable, Codable { case made, undone }

    public var id: String
    public var correction: Correction
    public var action: Action
    /// The override row the entry made or removed.
    public var overrideId: String
    /// A classification's document.
    public var volumeId: String?
    public var documentId: String?
    /// A classification made: the correction; undone: the value restored, FRUS's own.
    public var isEditorialNote: Bool?
    /// A classification made: what the TEI said then.
    public var parsedIsEditorialNote: Bool?
    /// A person correction's kind, and the records it anchors on.
    public var kind: PersonClusterOverrideKind?
    public var volumeIdA: String?
    public var refA: String?
    public var volumeIdB: String?
    public var refB: String?
    /// Who, by their id, and their name as the store keeps it now.
    public var userId: String
    public var userName: String
    public var madeAt: Date
    /// When the index took it; nil while it waits.
    public var appliedAt: Date?

    /// The document a classification entry names.
    public var document: DocumentKey? {
        guard correction == .classification, let volumeId, let documentId else { return nil }
        return DocumentKey(volumeId: volumeId, documentId: documentId)
    }
}

/// Why a correction was not recorded.
public enum CorrectionStoreError: Error, Equatable, CustomStringConvertible {
    /// A merge of a record with itself.
    case selfMerge

    public var description: String {
        switch self {
        case .selfMerge: "A record cannot be merged with itself."
        }
    }
}

/// Where the corrections made on this server are kept, with their log.
public protocol CorrectionLogStore: Sendable {
    /// Every person correction, newest first, as the app's `PersonClusterOverrideStore.fetchAll` gives them, one of
    /// a kind the app does not know left out, as its `snapshot` leaves it.
    func personOverrides() throws -> [PersonOverride]
    /// Records that two records are one person, as the app's `PersonClusterOverrideStore.merge` does, and logs it,
    /// in one transaction: nil, with nothing written, when a merge of the two is kept already, either way round.
    /// Throws `CorrectionStoreError.selfMerge` for a record and itself.
    func recordPersonMerge(_ a: PersonRecordKey, _ b: PersonRecordKey, by user: String, at time: Date) throws -> CorrectionLogEntry?
    /// Records that a record is a different person, as the app's `split` does, and logs it: nil, with nothing
    /// written, when its separation is kept already.
    func recordPersonSplit(_ member: PersonRecordKey, by user: String, at time: Date) throws -> CorrectionLogEntry?
    /// Removes a person correction, as the app's Corrections sheet's Undo does, and logs it: nil when no correction
    /// has the id, as the sheet treats one undone elsewhere.
    func undoPersonCorrection(_ id: String, by user: String, at time: Date) throws -> CorrectionLogEntry?
    /// Records a document's classification, as `CorrectionStore.record` keeps one per document, and logs it.
    func recordClassification(_ correction: ClassificationOverride, by user: String, at time: Date) throws -> CorrectionLogEntry
    /// Removes a document's classification correction, as the rail's Restore FRUS's Classification does, and logs
    /// it with `parsed`, the value restored: nil, with nothing written, when the document has none.
    func undoClassification(of document: DocumentKey, restoring parsed: Bool, by user: String, at time: Date) throws -> CorrectionLogEntry?
    /// The log, newest first, `limit` entries at most.
    func correctionLog(limit: Int) throws -> [CorrectionLogEntry]
    /// A document's classification entries, newest first.
    func correctionLog(of document: DocumentKey) throws -> [CorrectionLogEntry]
    /// Every entry of one kind of correction, newest first.
    func correctionLog(of correction: CorrectionLogEntry.Correction) throws -> [CorrectionLogEntry]
    /// The entries the index has not taken, in the order they were made.
    func waitingCorrections() throws -> [CorrectionLogEntry]
    /// For each document whose classification was last restored on this server, and holds no correction now, the
    /// entry that restored it, in the order they were made: what an export, which may carry a correction the Mac
    /// keeps, is given again at each install.
    func standingRestores() throws -> [CorrectionLogEntry]
    /// Marks entries taken by the index at `time`; one taken already keeps its time.
    func markCorrectionsApplied(_ ids: [String], at time: Date) throws
}

/// A persons-list record, by its volume and its `xml:id`: what a person correction anchors on.
public struct PersonRecordKey: Sendable, Hashable, Codable {
    public var volumeId: String
    public var ref: String

    public init(volumeId: String, ref: String) {
        self.volumeId = volumeId
        self.ref = ref
    }
}

extension RelationalUserStore: CorrectionLogStore {
    private static let personColumns = "id, kind, volume_id_a, ref_a, volume_id_b, ref_b, created_at"
    private static let logColumns = """
        l.entry_id, l.correction, l.action, l.override_id, l.volume_id, l.document_id, l.is_editorial_note,
        l.parsed_is_editorial_note, l.kind, l.volume_id_a, l.ref_a, l.volume_id_b, l.ref_b, l.user_id,
        coalesce(u.display_name, l.user_id), l.made_at, l.applied_at
        """
    private static let logFrom = "correction_log AS l LEFT JOIN users AS u ON u.user_id = l.user_id"

    public func personOverrides() throws -> [PersonOverride] {
        try reading { db in try Self.personOverrides(in: db) }
    }

    private static func personOverrides(in db: UserStoreTransaction) throws -> [PersonOverride] {
        // Newest first, as the app's fetch sorts them; one with no time last, and two of one time the later made
        // first, as the store numbers its rows.
        try db.query("SELECT \(personColumns) FROM person_overrides ORDER BY created_at DESC NULLS LAST, rowid DESC", [])
            .compactMap { row in
                guard let kind = row[1].text.flatMap(PersonClusterOverrideKind.init(rawValue:)) else { return nil }
                return PersonOverride(id: row[0].text ?? "", kind: kind, volumeIdA: row[2].text ?? "", refA: row[3].text ?? "",
                                      volumeIdB: row[4].text, refB: row[5].text,
                                      createdAt: row[6].text.flatMap(UserStoreDate.date))
            }
    }

    public func recordPersonMerge(_ a: PersonRecordKey, _ b: PersonRecordKey, by user: String, at time: Date) throws -> CorrectionLogEntry? {
        guard a != b else { throw CorrectionStoreError.selfMerge }
        return try writing(outsideSearch: true) { db in
            let kept = try Self.personOverrides(in: db).contains { o in
                o.kind == .merge && (
                    (o.volumeIdA == a.volumeId && o.refA == a.ref && o.volumeIdB == b.volumeId && o.refB == b.ref)
                    || (o.volumeIdA == b.volumeId && o.refA == b.ref && o.volumeIdB == a.volumeId && o.refB == a.ref))
            }
            guard !kept else { return nil }
            let override = PersonOverride(kind: .merge, volumeIdA: a.volumeId, refA: a.ref, volumeIdB: b.volumeId, refB: b.ref,
                                          createdAt: time)
            try Self.insert(override, in: db)
            return try Self.log(person: override, action: .made, by: user, at: time, in: db)
        }
    }

    public func recordPersonSplit(_ member: PersonRecordKey, by user: String, at time: Date) throws -> CorrectionLogEntry? {
        try writing(outsideSearch: true) { db in
            let kept = try Self.personOverrides(in: db).contains {
                $0.kind == .split && $0.volumeIdA == member.volumeId && $0.refA == member.ref
            }
            guard !kept else { return nil }
            let override = PersonOverride(kind: .split, volumeIdA: member.volumeId, refA: member.ref, createdAt: time)
            try Self.insert(override, in: db)
            return try Self.log(person: override, action: .made, by: user, at: time, in: db)
        }
    }

    public func undoPersonCorrection(_ id: String, by user: String, at time: Date) throws -> CorrectionLogEntry? {
        try writing(outsideSearch: true) { db in
            guard let override = try Self.personOverrides(in: db).first(where: { $0.id == id }) else { return nil }
            _ = try db.query("DELETE FROM person_overrides WHERE id = ?", [.text(id)])
            return try Self.log(person: override, action: .undone, by: user, at: time, in: db)
        }
    }

    public func recordClassification(_ given: ClassificationOverride, by user: String, at time: Date) throws -> CorrectionLogEntry {
        try writing(outsideSearch: true) { db in
            let stored = try Self.storeClassification(given, in: db)
            return try Self.log(.classification, .made, overrideId: stored.id,
                                values: [.text(stored.volumeId), .text(stored.documentId), Self.flag(stored.isEditorialNote),
                                         Self.flag(stored.parsedIsEditorialNote), .null, .null, .null, .null, .null],
                                by: user, at: time, in: db)
        }
    }

    public func undoClassification(of document: DocumentKey, restoring parsed: Bool, by user: String, at time: Date) throws -> CorrectionLogEntry? {
        try writing(outsideSearch: true) { db in
            // The newest, which the rail's Restore removes; any older one an import brought with it goes too, since
            // the app keeps one per document and a restore leaves the document as FRUS classifies it.
            guard let newest = try db.query(
                """
                SELECT id FROM classification_overrides WHERE volume_id = ? AND document_id = ?
                    ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 1
                """, [.text(document.volumeId), .text(document.documentId)]).first?[0].text else { return nil }
            _ = try db.query("DELETE FROM classification_overrides WHERE volume_id = ? AND document_id = ?",
                             [.text(document.volumeId), .text(document.documentId)])
            return try Self.log(.classification, .undone, overrideId: newest,
                                values: [.text(document.volumeId), .text(document.documentId), Self.flag(parsed), .null,
                                         .null, .null, .null, .null, .null],
                                by: user, at: time, in: db)
        }
    }

    public func correctionLog(limit: Int) throws -> [CorrectionLogEntry] {
        try reading { db in
            try db.query("SELECT \(Self.logColumns) FROM \(Self.logFrom) ORDER BY l.rowid DESC LIMIT ?", [.integer(Int64(max(0, limit)))])
                .compactMap(Self.entry)
        }
    }

    public func correctionLog(of document: DocumentKey) throws -> [CorrectionLogEntry] {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.logColumns) FROM \(Self.logFrom)
                    WHERE l.correction = 'classification' AND l.volume_id = ? AND l.document_id = ? ORDER BY l.rowid DESC
                """, [.text(document.volumeId), .text(document.documentId)]).compactMap(Self.entry)
        }
    }

    public func correctionLog(of correction: CorrectionLogEntry.Correction) throws -> [CorrectionLogEntry] {
        try reading { db in
            try db.query("SELECT \(Self.logColumns) FROM \(Self.logFrom) WHERE l.correction = ? ORDER BY l.rowid DESC",
                         [.text(correction.rawValue)]).compactMap(Self.entry)
        }
    }

    public func waitingCorrections() throws -> [CorrectionLogEntry] {
        try reading { db in
            try db.query("SELECT \(Self.logColumns) FROM \(Self.logFrom) WHERE l.applied_at IS NULL ORDER BY l.rowid", [])
                .compactMap(Self.entry)
        }
    }

    public func standingRestores() throws -> [CorrectionLogEntry] {
        try reading { db in
            try db.query(
                """
                SELECT \(Self.logColumns) FROM \(Self.logFrom)
                    WHERE l.correction = 'classification' AND l.action = 'undone'
                        AND NOT EXISTS (SELECT 1 FROM classification_overrides AS o
                                            WHERE o.volume_id = l.volume_id AND o.document_id = l.document_id)
                        AND NOT EXISTS (SELECT 1 FROM correction_log AS later
                                            WHERE later.correction = 'classification' AND later.volume_id = l.volume_id
                                                AND later.document_id = l.document_id AND later.rowid > l.rowid)
                    ORDER BY l.rowid
                """, []).compactMap(Self.entry)
        }
    }

    public func markCorrectionsApplied(_ ids: [String], at time: Date) throws {
        guard !ids.isEmpty else { return }
        try writing(outsideSearch: true) { db in
            for id in ids {
                _ = try db.query("UPDATE correction_log SET applied_at = ? WHERE entry_id = ? AND applied_at IS NULL",
                                 [.text(UserStoreDate.text(time)), .text(id)])
            }
        }
    }

    // MARK: The rows

    /// `CorrectionStore.record`'s rule, in a transaction a caller holds: the document's newest correction takes the
    /// new value and time, keeping its id and what the TEI said, and a document with none gains the one given.
    static func storeClassification(_ given: ClassificationOverride, in db: UserStoreTransaction) throws -> ClassificationOverride {
        // To the store's precision, so what is returned is what is stored.
        var correction = given
        correction.createdAt = given.createdAt.map(UserStoreDate.rounded)
        let time: SQLiteValue = correction.createdAt.map { .text(UserStoreDate.text($0)) } ?? .null
        let columns = "id, volume_id, document_id, is_editorial_note, parsed_is_editorial_note, created_at"
        // The newest for the document, as the app's fetch sorted by createdAt, newest first, finds it: one with no
        // time last. Two of one time fall to their ids.
        let existing = try db.query(
            """
            SELECT \(columns) FROM classification_overrides WHERE volume_id = ? AND document_id = ?
                ORDER BY created_at DESC NULLS LAST, id DESC LIMIT 1
            """,
            [.text(correction.volumeId), .text(correction.documentId)]).first.map {
                ClassificationOverride(id: $0[0].text ?? "", volumeId: $0[1].text ?? "", documentId: $0[2].text ?? "",
                                       isEditorialNote: $0[3].integer == 1, parsedIsEditorialNote: $0[4].integer == 1,
                                       createdAt: $0[5].text.flatMap(UserStoreDate.date))
            }
        if var stored = existing {
            stored.isEditorialNote = correction.isEditorialNote
            stored.createdAt = correction.createdAt
            _ = try db.query("UPDATE classification_overrides SET is_editorial_note = ?, created_at = ? WHERE id = ?",
                             [flag(correction.isEditorialNote), time, .text(stored.id)])
            return stored
        }
        _ = try db.query(
            "INSERT INTO classification_overrides (\(columns)) VALUES (?, ?, ?, ?, ?, ?)",
            [.text(correction.id), .text(correction.volumeId), .text(correction.documentId), flag(correction.isEditorialNote),
             flag(correction.parsedIsEditorialNote), time])
        return correction
    }

    private static func insert(_ override: PersonOverride, in db: UserStoreTransaction) throws {
        _ = try db.query(
            "INSERT INTO person_overrides (\(personColumns)) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [.text(override.id), .text(override.kind.rawValue), .text(override.volumeIdA), .text(override.refA),
             override.volumeIdB.map { .text($0) } ?? .null, override.refB.map { .text($0) } ?? .null,
             override.createdAt.map { .text(UserStoreDate.text($0)) } ?? .null])
    }

    private static func log(person override: PersonOverride, action: CorrectionLogEntry.Action, by user: String, at time: Date,
                            in db: UserStoreTransaction) throws -> CorrectionLogEntry {
        try log(.person, action, overrideId: override.id,
                values: [.null, .null, .null, .null, .text(override.kind.rawValue), .text(override.volumeIdA), .text(override.refA),
                         override.volumeIdB.map { .text($0) } ?? .null, override.refB.map { .text($0) } ?? .null],
                by: user, at: time, in: db)
    }

    /// Writes an entry, its nine values those of `volume_id` to `ref_b`, and gives it as the store reads it.
    private static func log(_ correction: CorrectionLogEntry.Correction, _ action: CorrectionLogEntry.Action, overrideId: String,
                            values: [SQLiteValue], by user: String, at time: Date, in db: UserStoreTransaction) throws -> CorrectionLogEntry {
        let id = UUID().uuidString
        _ = try db.query(
            """
            INSERT INTO correction_log (entry_id, correction, action, override_id, volume_id, document_id, is_editorial_note,
                parsed_is_editorial_note, kind, volume_id_a, ref_a, volume_id_b, ref_b, user_id, made_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [.text(id), .text(correction.rawValue), .text(action.rawValue), .text(overrideId)] + values
                + [.text(user), .text(UserStoreDate.text(time))])
        guard let entry = try db.query("SELECT \(logColumns) FROM \(logFrom) WHERE l.entry_id = ?", [.text(id)]).first.flatMap(Self.entry) else {
            throw SQLiteError(code: 0, message: "the correction's log entry was not read back")
        }
        return entry
    }

    private static func flag(_ value: Bool) -> SQLiteValue { .integer(value ? 1 : 0) }

    private static func entry(_ row: [SQLiteValue]) -> CorrectionLogEntry? {
        guard let correction = row[1].text.flatMap(CorrectionLogEntry.Correction.init(rawValue:)),
              let action = row[2].text.flatMap(CorrectionLogEntry.Action.init(rawValue:)),
              let madeAt = row[15].text.flatMap(UserStoreDate.date) else { return nil }
        return CorrectionLogEntry(id: row[0].text ?? "", correction: correction, action: action, overrideId: row[3].text ?? "",
                                  volumeId: row[4].text, documentId: row[5].text, isEditorialNote: row[6].integer.map { $0 == 1 },
                                  parsedIsEditorialNote: row[7].integer.map { $0 == 1 },
                                  kind: row[8].text.flatMap(PersonClusterOverrideKind.init(rawValue:)),
                                  volumeIdA: row[9].text, refA: row[10].text, volumeIdB: row[11].text, refB: row[12].text,
                                  userId: row[13].text ?? "", userName: row[14].text ?? "", madeAt: madeAt,
                                  appliedAt: row[16].text.flatMap(UserStoreDate.date))
    }
}
