// Check 2 at full scale (PLAN's S25b): corrections made in the app, which its export carries, given to
// another index of the same files through the kit's own calls, so that the two compare row for row.
//
// The app keeps a reader's corrections of the index, a document reclassified and two records of people
// merged into one identity or one separated from it, as overrides it replays into its index
// (`DocumentClassificationOverride`, `PersonClusterOverride`), and an export carries what they made of the
// index. An index another host made of the same files holds none of them, so before the two are compared the
// same corrections are given to it as a Standalone server's curator gives them (`IndexCorrections.apply`,
// Sources/FRUSLightCore/IndexCorrections.swift): `applyClassificationOverrides`, which writes a document's
// classification into `document_cache.is_editorial_note`, and `consolidatePersonRollup(overrides:)`, which
// builds the person rollup again with each merge as a must-link and each separation as a detach. The file
// names each correction; what it makes of the index is the kit's.

import FRUSCoreKit
import FTS5Store
import Foundation

/// Corrections made in the app, as a file names them (`frus-parity apply-corrections --corrections <file>`).
public struct LibraryCorrections: Codable, Equatable, Sendable {
    /// A document reclassified: an editorial note, or a document.
    public struct Classification: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        public var isEditorialNote: Bool

        public init(volumeId: String, documentId: String, isEditorialNote: Bool) {
            self.volumeId = volumeId
            self.documentId = documentId
            self.isEditorialNote = isEditorialNote
        }
    }

    /// Two records of people made one identity (`merge`), or one record separated from its identity
    /// (`split`): the kit's `PersonClusterOverrideData`, by its names. Each record is a `persons` row's
    /// `(volume_id, ref)`.
    public struct Person: Codable, Equatable, Sendable {
        public var kind: String
        public var volumeIdA: String
        public var refA: String
        public var volumeIdB: String?
        public var refB: String?

        public init(kind: String, volumeIdA: String, refA: String, volumeIdB: String? = nil, refB: String? = nil) {
            self.kind = kind
            self.volumeIdA = volumeIdA
            self.refA = refA
            self.volumeIdB = volumeIdB
            self.refB = refB
        }
    }

    public var classifications: [Classification]
    public var people: [Person]

    public init(classifications: [Classification] = [], people: [Person] = []) {
        self.classifications = classifications
        self.people = people
    }

    /// What giving the corrections did to the index.
    public struct Applied: Sendable, Equatable {
        /// The documents whose classification the corrections changed.
        public var classificationsChanged: Int
        /// The person corrections given to the rollup, which is built again only when there is one.
        public var personCorrections: Int
        public var rollupsBefore: Int
        public var rollupsAfter: Int
    }

    /// Reads a corrections file.
    public static func read(from url: URL) throws -> LibraryCorrections {
        try JSONDecoder().decode(LibraryCorrections.self, from: Data(contentsOf: url))
    }

    /// The person corrections as the kit's values, each record checked to be a merge of two or a separation of one.
    func personOverrides() throws -> [PersonClusterOverrideData] {
        try people.map { person in
            guard let kind = PersonClusterOverrideKind(rawValue: person.kind) else {
                throw LibraryCorrectionsError("a person correction is \(person.kind), not merge or split")
            }
            switch kind {
            case .merge:
                guard let volumeIdB = person.volumeIdB, let refB = person.refB else {
                    throw LibraryCorrectionsError("a merge names two records; \(person.volumeIdA) \(person.refA) names one")
                }
                return PersonClusterOverrideData(kind: .merge, volumeIdA: person.volumeIdA, refA: person.refA,
                                                 volumeIdB: volumeIdB, refB: refB)
            case .split:
                guard person.volumeIdB == nil, person.refB == nil else {
                    throw LibraryCorrectionsError("a split names one record; \(person.volumeIdA) \(person.refA) names two")
                }
                return PersonClusterOverrideData(kind: .split, volumeIdA: person.volumeIdA, refA: person.refA)
            }
        }
    }

    /// Gives the corrections to the index at `database`, which it writes, with the app's data files in
    /// `resources`, as a Standalone server's curator gives them: every classification through
    /// `applyClassificationOverrides`, and, when there is a person correction, the rollup built again with
    /// every one through `consolidatePersonRollup(overrides:)`. It refuses a correction naming a document or a
    /// person the index does not hold, which the kit would pass over without a word, and folds the write-ahead
    /// log into the file before it returns, as the server's indexing job does, so that the summary reads it.
    public func apply(to database: URL, resources: URL) async throws -> Applied {
        let overrides = try personOverrides()
        // What the index holds before: each document's classification, the TEI's own as the index stores it,
        // which the kit keeps as the value a restore puts back; each person's record; the rollup's size.
        var classification: [DocumentClassificationOverrideData] = []
        var changed = 0
        let rollupsBefore: Int
        do {
            let db = try ParityDatabase.readOnly(database)
            for correction in classifications {
                let stored = try db.scalar("""
                    SELECT is_editorial_note FROM document_cache WHERE volume_id = \(Self.quoted(correction.volumeId)) \
                    AND document_id = \(Self.quoted(correction.documentId))
                    """)
                guard let current = stored?.integer else {
                    throw LibraryCorrectionsError("the index holds no document \(correction.volumeId)/\(correction.documentId)")
                }
                if (current != 0) != correction.isEditorialNote { changed += 1 }
                classification.append(DocumentClassificationOverrideData(
                    volumeId: correction.volumeId, documentId: correction.documentId,
                    isEditorialNote: correction.isEditorialNote, parsedIsEditorialNote: current != 0))
            }
            for override in overrides {
                for (volume, ref) in [(override.volumeIdA, override.refA), (override.volumeIdB, override.refB)] {
                    guard let volume, let ref else { continue }
                    let found = try db.scalar("""
                        SELECT count(*) FROM persons WHERE volume_id = \(Self.quoted(volume)) AND ref = \(Self.quoted(ref))
                        """)?.integer ?? 0
                    guard found == 1 else {
                        throw LibraryCorrectionsError("the index holds \(found) persons \(volume) \(Self.quoted(ref)), where a correction names one")
                    }
                }
            }
            rollupsBefore = Int(try db.scalar("SELECT count(*) FROM person_rollup")?.integer ?? 0)
        }

        // The kit's writer, released before the log is folded, which closes its connections.
        func give() async throws {
            let store = try FTS5Store(databaseURL: database)
            let pipeline = try IndexingPipeline(
                fts5Store: store, databaseURL: database, volumesDirectory: database.deletingLastPathComponent(),
                resources: try IndexingResources.loading(fromDirectory: resources), defaults: InMemoryIndexingStampStore())
            try await pipeline.applyClassificationOverrides(classification)
            if !overrides.isEmpty {
                // The gated launch's reload, as the passes after indexing call it: the writer holds no inputs yet.
                try await pipeline.consolidatePersonRollup(overrides: overrides, forceReload: true)
            }
        }
        try await give()

        let db = try ParityDatabase.create(database)
        let checkpoint = try db.rows("PRAGMA wal_checkpoint(TRUNCATE)").first ?? []
        guard checkpoint.first?.integer == 0 else {
            throw LibraryCorrectionsError("the write-ahead log could not be folded into \(database.lastPathComponent): another connection holds it")
        }
        for correction in classifications {
            let stored = try db.scalar("""
                SELECT is_editorial_note FROM document_cache WHERE volume_id = \(Self.quoted(correction.volumeId)) \
                AND document_id = \(Self.quoted(correction.documentId))
                """)?.integer
            guard let stored, (stored != 0) == correction.isEditorialNote else {
                throw LibraryCorrectionsError("\(correction.volumeId)/\(correction.documentId) is not \(correction.isEditorialNote ? "an editorial note" : "a document") after the correction")
            }
        }
        let rollupsAfter = Int(try db.scalar("SELECT count(*) FROM person_rollup")?.integer ?? 0)
        return Applied(classificationsChanged: changed, personCorrections: overrides.count,
                       rollupsBefore: rollupsBefore, rollupsAfter: rollupsAfter)
    }

    /// A text as an SQL literal.
    static func quoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
    }
}

/// Why corrections could not be given to an index.
public struct LibraryCorrectionsError: Error, CustomStringConvertible, Equatable, Sendable {
    public let description: String
    public init(_ description: String) { self.description = description }
}
