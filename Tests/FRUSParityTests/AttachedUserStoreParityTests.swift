// The kit's own suite for a search's user half from an attached store (FRUS-Explorer#1806's
// `SearchUserSourceTests`), run over this server's user stores (PLAN's S17d): the store the kit
// attaches is each store's search database, app.db itself or the PostgreSQL store's local copy, written
// through the store's own methods, where the kit's suite writes a stand-in. The first reader's notes,
// summaries and tags are also in the index's own columns of a second copy, as the app's writers keep
// them, so every route through the store, the search, its count and keys, the facets and the tag
// counts the Query Inspector and the filter read, is held to the app's answers over the same text.
// S14d checked it once by hand over the PostgreSQL copy; it runs here on every store
// `UserStoreKind.available` names. Scores of the user half are not compared: they are BM25 over
// `user_search`, whose statistics are its rows, where `user_content`'s are every document of the index.

import CSQLite
@testable import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

/// A search whose user half is one user's rows of a user store attached to a read-only index, over the
/// kit's twelve-document fixture and two users.
@Suite struct AttachedUserStoreParityTests {

    static let volume = "frus1970v01"
    static let tagA = "AAAAAAAA-0000-4000-8000-000000000001"
    static let tagB = "BBBBBBBB-0000-4000-8000-000000000002"
    static let reader = "reader-a"
    static let other = "reader-b"

    /// One user's text for a document, as `user_search` holds it and the app's index columns do.
    struct UserText {
        let user: String
        let document: String
        let summary: String?
        let note: String?
    }

    /// The first reader's: a note on d2 and d6, a summary on d4, both on d5, and a note on d99, a
    /// document the index does not hold. The other reader's on d3 and d6.
    static let texts: [UserText] = [
        UserText(user: reader, document: "d2", summary: nil, note: "Zanzibar cable on the Berlin talks"),
        UserText(user: reader, document: "d4", summary: "A quixotic proposal about Berlin", note: nil),
        UserText(user: reader, document: "d5", summary: "Nothing of the kind", note: "Two zanzibars, and a quixotic aside"),
        UserText(user: reader, document: "d6", summary: nil, note: "Telegram about Zanzibar"),
        UserText(user: reader, document: "d99", summary: nil, note: "Zanzibar again"),
        UserText(user: other, document: "d3", summary: "Zanzibar, quixotic", note: "zanzibar"),
        UserText(user: other, document: "d6", summary: "The other reader's quixotic summary", note: nil),
    ]

    /// Assignments of a tag, `(user, document, tag)`. The first reader's ids are written in lower case
    /// on d6, twice on d1, and on d2 the later id first, as a store may hold them; the other reader
    /// carries the same tag on d3 and d9.
    static let assignments: [(user: String, document: String, tag: String)] = [
        (reader, "d1", tagA), (reader, "d1", tagA), (reader, "d2", tagB), (reader, "d2", tagA),
        (reader, "d6", tagA.lowercased()), (reader, "d99", tagA),
        (other, "d3", tagA), (other, "d9", tagA), (other, "d2", tagB),
    ]

    /// The first reader's tags as the app's reconcile writes `user_tag_ids`: each id once, in upper
    /// case, sorted, joined by a space.
    static let readerTagColumn: [String: String] = ["d1": tagA, "d2": "\(tagA) \(tagB)", "d6": tagA]

    /// The person d1, d2, d6 and d7 mention, so a search by a person alone, the filter-only path,
    /// finds tagged documents and untagged ones.
    static let person = "p_ONE"

    /// `SearchStatementTextTests`' twelve documents, with a persons list in the front matter and a
    /// mention of its one person in d1, d2, d6 and d7.
    static func writeVolume(in volumes: URL) throws {
        let documents = (1...12).map { n in
            let mention = [1, 2, 6, 7].contains(n) ? " <persName corresp=\"#\(person)\">One</persName> wrote." : ""
            return "<div type=\"document\" xml:id=\"d\(n)\" n=\"\(n)\"><head>\(n). \(n % 5 == 1 ? "Telegram" : "Memorandum")</head>"
                + "<p>Text \(n) on Berlin and \(n % 3 == 0 ? "telegrams" : "talks").\(mention)</p></div>"
        }.joined(separator: "\n")
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
              <teiHeader><fileDesc><titleStmt><title>\(volume)</title></titleStmt>
              <publicationStmt><date>1970</date></publicationStmt>
              <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
              <text>
                <front>
                  <div type="section" subtype="index" xml:id="persons"><head>Persons</head>
                    <list><item><persName xml:id="\(person)">One, A.</persName>, a correspondent</item></list>
                  </div>
                </front>
                <body><div type="compilation" xml:id="comp1">\(documents)</div></body>
              </text>
            </TEI>
            """
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volume).xml"))
    }

    // MARK: Fixture

    /// The index served, read-only, with the store attached; the app's copy with the first reader's
    /// half in its own columns; and the store's writer, kept open as the host keeps one.
    struct Fixture {
        let dir: URL
        let served: URL
        let store: URL
        let pipeline: IndexingPipeline
        let fts5: FTS5Store
        let app: SearchService
        let appPipeline: IndexingPipeline
        let test: TestUserStore

        func service(_ user: String) -> SearchService {
            SearchService(fts5Store: fts5, pipeline: pipeline, userSource: .attachedStore(userId: user))
        }

        func close() {
            test.close()
            try? FileManager.default.removeItem(at: dir)
        }
    }

    static func exec(_ db: OpaquePointer?, _ sql: String, _ binds: [String?] = []) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw IndexingError.sqliteError(code: sqlite3_errcode(db), message: String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in binds.enumerated() {
            if let value { sqlite3_bind_text(stmt, Int32(index + 1), value, -1, transient) } else { sqlite3_bind_null(stmt, Int32(index + 1)) }
        }
        // A pragma answers with a row, as `journal_mode` does with the mode it set.
        var rc = sqlite3_step(stmt)
        while rc == SQLITE_ROW { rc = sqlite3_step(stmt) }
        guard rc == SQLITE_DONE else {
            throw IndexingError.sqliteError(code: rc, message: String(cString: sqlite3_errmsg(db)))
        }
    }

    /// A store of `kind`, holding `texts` and `assignments`, each written through the store's own
    /// methods: a note, a summary of the reader's own, and the assignments through an import, which
    /// keeps their ids and their case. Its search database is what the pipeline attaches.
    static func makeStore(_ kind: UserStoreKind) async throws -> TestUserStore {
        let test = try await TestUserStore.open(kind)
        let store = test.store
        try test.rows.addUser(reader)
        try test.rows.addUser(other)
        let time = Date(timeIntervalSince1970: 1_792_800_000)
        for text in texts {
            let document = FRUSLightCore.DocumentKey(volumeId: volume, documentId: text.document)
            if let note = text.note {
                _ = try store.createNote(in: document, bodyText: note, richText: nil, projectIds: [], userTagIds: [],
                                         selectedSummaryIds: [], linkedHighlightId: nil, for: text.user, at: time)
            }
            if let summary = text.summary {
                _ = try store.createOwnSummary(in: document, text: summary, responseFormat: #"{"general":{}}"#, for: text.user, at: time)
            }
        }
        for user in [reader, other] {
            let rows = assignments.enumerated().filter { $0.element.user == user }.map { index, assignment in
                ImportRow(values: ["id": .text("assignment-\(index)"), "volume_id": .text(volume), "document_id": .text(assignment.document),
                                   "tag_id": .text(assignment.tag), "created_at": .text("2026-01-01T00:00:00.000Z")])
            }
            _ = try store.importResearch(ResearchImportBatch(rows: ["tag_assignments": rows]), for: user)
        }
        return test
    }

    /// A copy of `built` page for page through SQLite's backup API, out of write-ahead-log mode, as an
    /// export is made, alone in a folder of its own.
    static func exportCopy(of built: URL, to copy: URL) throws {
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        var source: OpaquePointer?, target: OpaquePointer?
        try #require(sqlite3_open_v2(built.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        try #require(sqlite3_open_v2(copy.path, &target, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK)
        let backup = try #require(sqlite3_backup_init(target, "main", source, "main"))
        #expect(sqlite3_backup_step(backup, -1) == SQLITE_DONE)
        sqlite3_backup_finish(backup)
        #expect(sqlite3_exec(target, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_close(target) == SQLITE_OK && sqlite3_close(source) == SQLITE_OK)
        try? FileManager.default.removeItem(at: copy.deletingLastPathComponent().appendingPathComponent("\(copy.lastPathComponent)-shm"))
    }

    static func makeFixture(_ kind: UserStoreKind) async throws -> Fixture {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSUserSource-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try writeVolume(in: volumes)
        let built = dir.appendingPathComponent("built.db")
        do {
            let store = try FTS5Store(databaseURL: built)
            let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: built, volumesDirectory: volumes,
                                                resources: .none, defaults: InMemoryIndexingStampStore())
            try await pipeline.indexVolume(volume)
        }
        let served = dir.appendingPathComponent("served/frus.db")
        try exportCopy(of: built, to: served)

        // The app's copy: the first reader's half in the index's own columns, as its writers keep them,
        // for the documents the index holds.
        let appDatabase = dir.appendingPathComponent("app/frus.db")
        try exportCopy(of: built, to: appDatabase)
        let appStore = try FTS5Store(databaseURL: appDatabase)
        let appPipeline = try IndexingPipeline(fts5Store: appStore, databaseURL: appDatabase, volumesDirectory: volumes,
                                               resources: .none, defaults: InMemoryIndexingStampStore())
        for text in texts where text.user == reader && text.document != "d99" {
            if let note = text.note {
                try await appPipeline.updateNoteText(volumeId: volume, documentId: text.document, bodyText: note)
            }
            if let summary = text.summary {
                try await appPipeline.updateSummaryText(volumeId: volume, documentId: text.document, responseText: summary)
            }
        }
        for (document, column) in readerTagColumn {
            try await appPipeline.updateUserTagIds(volumeId: volume, documentId: document, userTagIds: column)
        }

        let test = try await makeStore(kind)
        let storeURL = test.store.searchDatabase
        let fts5 = try FTS5Store(readingDatabaseAt: served)
        let pipeline = try IndexingPipeline(readingIndexAt: served, fts5Store: fts5, resources: .none,
                                            volumesDirectory: volumes, userStore: storeURL)
        return Fixture(dir: dir, served: served, store: storeURL, pipeline: pipeline, fts5: fts5,
                       app: SearchService(fts5Store: appStore, pipeline: appPipeline), appPipeline: appPipeline,
                       test: test)
    }

    static func search(_ keywords: String?, documents: Bool = true, summaries: Bool = true, notes: Bool = true,
                       _ edit: (inout SearchParameters) -> Void = { _ in }) -> SearchParameters {
        var parameters = SearchParameters(keywords: keywords, includeDocumentText: documents,
                                          includeSummaries: summaries, includeNotes: notes)
        edit(&parameters)
        return parameters
    }

    /// A search's documents, as `"volumeId/documentId"`, in its order.
    static func keys(_ results: [SearchResult]) -> [String] {
        results.map { "\($0.volumeId)/\($0.documentId)" }
    }

    static func key(_ document: String) -> String { "\(volume)/\(document)" }

    // MARK: Tests

    @Test("A reader's notes and summaries are found through the store, theirs alone, in each scope, and a document the index lacks is left out", arguments: UserStoreKind.available)
    func aReadersTextIsFoundThroughTheStore(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        let reader = fixture.service(Self.reader)
        let other = fixture.service(Self.other)

        // Notes and summaries: "zanzibar" stems alike in d2, d5 and d6, the reader's; d99 is not indexed.
        let both = Self.search("zanzibar", documents: false)
        #expect(Set(Self.keys(try await reader.search(parameters: both, limit: 50))) == Set(["d2", "d5", "d6"].map(Self.key)))
        #expect(try await reader.searchCount(parameters: both) == 3)
        #expect(Set(try await reader.matchKeys(parameters: both)) == Set(["d2", "d5", "d6"].map(Self.key)))
        #expect(Self.keys(try await other.search(parameters: both, limit: 50)) == [Self.key("d3")])
        // Each column alone: the summary of d4 is quixotic, and the note of d5.
        #expect(Self.keys(try await reader.search(parameters: Self.search("quixotic", documents: false, notes: false), limit: 50))
                == [Self.key("d4")])
        #expect(Self.keys(try await reader.search(parameters: Self.search("quixotic", documents: false, summaries: false), limit: 50))
                == [Self.key("d5")])
        // With the corpus: the six "telegram" documents, and none more, since d6's note is on one of them.
        let telegram = Self.search("telegram")
        #expect(try await reader.searchCount(parameters: telegram) == 6)
        let rows = try await reader.search(parameters: telegram, limit: 50)
        #expect(Set(Self.keys(rows)).count == 6)
        // The index's own columns are empty in the served copy, so the index as the source finds nothing there.
        let index = SearchService(fts5Store: fixture.fts5, pipeline: fixture.pipeline)
        #expect(try await index.searchCount(parameters: both) == 0)
    }

    @Test("Through the store, every route answers as the app's index answers over the same notes, summaries and tags", arguments: UserStoreKind.available)
    func theStoreAnswersAsTheIndexsOwnColumns(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        let reader = fixture.service(Self.reader)
        let searches: [SearchParameters] = [
            Self.search("telegram"),
            Self.search("telegram", summaries: false, notes: false),
            Self.search("zanzibar"),
            Self.search("zanzibar", documents: false),
            Self.search("zanzibar", documents: false, summaries: false),
            Self.search("quixotic", documents: false, notes: false),
            Self.search("quixotic OR telegram", notes: false),
            Self.search("berlin -zanzibar"),
            Self.search("=Zanzibar"),
            Self.search("=Zanzibar", documents: false),
            Self.search("=zanzibars =quixotic", documents: false),
            Self.search("=Telegram", summaries: false),
            Self.search("berlin") { $0.userTagIds = [Self.tagA] },
            Self.search("berlin") { $0.userTagIds = [Self.tagA, Self.tagB] },
            Self.search("berlin") { $0.userTagIds = [Self.tagB.lowercased()] },
            Self.search("zanzibar", documents: false) { $0.userTagIds = [Self.tagA] },
            Self.search("berlin") { $0.documentIds = [Self.key("d2"), Self.key("d5"), Self.key("d6")]; $0.userTagIds = [Self.tagA] },
            Self.search("=Berlin", summaries: false) { $0.documentIds = [Self.key("d2"), Self.key("d4"), Self.key("d6")] },
            // The filter-only path: a person alone, and with a tag.
            Self.search(nil) { $0.personRef = Self.person },
            Self.search(nil) { $0.personRef = Self.person; $0.userTagIds = [Self.tagA] },
        ]
        let tags = [Self.tagA, Self.tagB, "CCCCCCCC-0000-4000-8000-000000000003"]
        for parameters in searches {
            let label = "\(parameters.keywords ?? "-") documents \(parameters.includeDocumentText) summaries \(parameters.includeSummaries) notes \(parameters.includeNotes) tags \(parameters.userTagIds) gate \(parameters.documentIds ?? [])"
            let appRows = try await fixture.app.search(parameters: parameters, limit: 100)
            let rows = try await reader.search(parameters: parameters, limit: 100)
            // The same documents, each once and with the same tags, the reader's alone.
            let tagged = { (rows: [SearchResult]) in rows.map { "\($0.volumeId)/\($0.documentId) \($0.userTagIds)" }.sorted() }
            #expect(tagged(rows) == tagged(appRows), "\(label)")
            #expect(try await reader.searchCount(parameters: parameters) == fixture.app.searchCount(parameters: parameters), "\(label)")
            #expect(try await reader.matchKeys(parameters: parameters).sorted() == fixture.app.matchKeys(parameters: parameters).sorted(),
                    "\(label)")
            #expect(try await reader.filterKeySet(parameters: parameters) == fixture.app.filterKeySet(parameters: parameters), "\(label)")
            #expect(try await reader.resultSetFacets(parameters: parameters, request: .all)
                    == fixture.app.resultSetFacets(parameters: parameters, request: .all), "\(label)")
            #expect(try await reader.userTagCounts(parameters: parameters, tagIds: tags)
                    == fixture.app.userTagCounts(parameters: parameters, tagIds: tags), "\(label)")
            // A search of the corpus alone reads nothing of the user half: its rows, scores and order are the app's.
            if !parameters.includeSummaries, !parameters.includeNotes, parameters.userTagIds.isEmpty {
                #expect(rows.map { "\($0.volumeId)/\($0.documentId) \($0.bm25Score.bitPattern)" }
                        == appRows.map { "\($0.volumeId)/\($0.documentId) \($0.bm25Score.bitPattern)" }, "\(label)")
            }
        }
        // A meaning search's routes, over keys: its tag counts, its rows' tags, and a tag's documents.
        let keys = ["d1", "d2", "d3", "d6", "d40"].map { (volumeId: Self.volume, documentId: $0) }
        let counts = try await reader.userTagCounts(parameters: SearchParameters(), tagIds: tags, documentKeys: keys)
        let appCounts = try await fixture.app.userTagCounts(parameters: SearchParameters(), tagIds: tags, documentKeys: keys)
        #expect(counts == [Self.tagA: 3, Self.tagB: 1])
        #expect(counts == appCounts)
        let semantic = try await reader.semanticResultRows(forKeys: keys)
        let appSemantic = try await fixture.app.semanticResultRows(forKeys: keys)
        #expect(semantic.mapValues(\.userTagIds) == appSemantic.mapValues(\.userTagIds))
        #expect(semantic[Self.key("d2")]?.userTagIds == "\(Self.tagA) \(Self.tagB)")
        for tag in [Self.tagA, Self.tagB.lowercased()] {
            let tagged = try await fixture.pipeline.documentKeys(forUserTagId: tag, userSource: .attachedStore(userId: Self.reader))
            let appTagged = try await fixture.appPipeline.documentKeys(forUserTagId: tag)
            #expect(tagged.count == Set(tagged).count && Set(tagged) == Set(appTagged), "\(tag)")
        }
        for document in ["d1", "d2", "d3", "d6", "d40"] {
            let documentTags = try await fixture.pipeline.currentUserTagIds(volumeId: Self.volume, documentId: document,
                                                                            userSource: .attachedStore(userId: Self.reader))
            let appDocumentTags = try await fixture.appPipeline.currentUserTagIds(volumeId: Self.volume, documentId: document)
            #expect(documentTags == appDocumentTags, "\(document)")
        }
    }

    @Test("A tag filter, a row's tags and the tag counts read the reader's assignments, whatever their case, and not another reader's", arguments: UserStoreKind.available)
    func tagsAreTheReadersAssignments(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        let reader = fixture.service(Self.reader)
        let other = fixture.service(Self.other)
        let berlin = Self.search("berlin")
        // Every document is on Berlin; the reader's tag A is on d1 (twice), d2 and d6 (in lower case).
        let tagged = Self.search("berlin") { $0.userTagIds = [Self.tagA] }
        #expect(Set(Self.keys(try await reader.search(parameters: tagged, limit: 50))) == Set(["d1", "d2", "d6"].map(Self.key)))
        #expect(Set(Self.keys(try await other.search(parameters: tagged, limit: 50))) == Set(["d3", "d9"].map(Self.key)))
        let lowered = Self.search("berlin") { $0.userTagIds = [Self.tagA.lowercased(), Self.tagB] }
        #expect(Self.keys(try await reader.search(parameters: lowered, limit: 50)) == [Self.key("d2")])
        // A row names the reader's tags as the app's column does: uppercase, sorted, once each.
        let rows = try await reader.search(parameters: berlin, limit: 50)
        #expect(Set(rows.map(\.documentId)).count == rows.count, "\(Self.keys(rows))")
        let rowTags = Dictionary(rows.map { ($0.documentId, $0.userTagIds) }, uniquingKeysWith: { first, _ in first })
        #expect(rowTags["d1"] == [Self.tagA] && rowTags["d2"] == [Self.tagA, Self.tagB] && rowTags["d6"] == [Self.tagA])
        #expect(rowTags["d3"] == [] && rowTags["d9"] == [])
        #expect(try await reader.userTagCounts(parameters: berlin, tagIds: [Self.tagA, Self.tagB.lowercased()])
                == [Self.tagA: 3, Self.tagB.lowercased(): 1])
        #expect(try await other.userTagCounts(parameters: berlin, tagIds: [Self.tagA, Self.tagB]) == [Self.tagA: 2, Self.tagB: 1])
        // The filter-only path, a person alone: d1, d2, d6 and d7 mention them, and the tag keeps three,
        // each row with the reader's tags; the tag count and the key set take the same path.
        let mentions = try await reader.search(parameters: Self.search(nil) { $0.personRef = Self.person }, limit: 50)
        #expect(mentions.map { "\($0.documentId) \($0.userTagIds)" }
                == ["d1 \([Self.tagA])", "d2 \([Self.tagA, Self.tagB])", "d6 \([Self.tagA])", "d7 []"])
        let mentioned = Self.search(nil) { $0.personRef = Self.person; $0.userTagIds = [Self.tagA] }
        #expect(Self.keys(try await reader.search(parameters: mentioned, limit: 50)) == ["d1", "d2", "d6"].map(Self.key))
        #expect(try await reader.matchKeys(parameters: mentioned).sorted() == ["d1", "d2", "d6"].map(Self.key))
        #expect(try await reader.userTagCounts(parameters: Self.search(nil) { $0.personRef = Self.person }, tagIds: [Self.tagB])
                == [Self.tagB: 1])
    }

    @Test("The exact-word filter reads the reader's notes and summaries in the store, literally, in the scopes searched", arguments: UserStoreKind.available)
    func exactWordsReadTheReadersText(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        let reader = fixture.service(Self.reader)
        // "zanzibar" stems alike in d2, d5 and d6; the word itself is in d2's and d6's notes alone.
        #expect(Set(Self.keys(try await reader.search(parameters: Self.search("=Zanzibar", documents: false), limit: 50)))
                == Set(["d2", "d6"].map(Self.key)))
        #expect(Self.keys(try await reader.search(parameters: Self.search("=zanzibars", documents: false), limit: 50))
                == [Self.key("d5")])
        // Notes off: d5's quixotic is in its note, so only d4's summary has it.
        #expect(Self.keys(try await reader.search(parameters: Self.search("=quixotic", documents: false, notes: false), limit: 50))
                == [Self.key("d4")])
        // With the corpus too: no document's text has the word, so the reader's two notes alone count,
        // and the other reader's d3, whose note and summary have it, counts for them alone.
        #expect(try await reader.searchCount(parameters: Self.search("=Zanzibar")) == 2)
        #expect(try await fixture.service(Self.other).searchCount(parameters: Self.search("=Zanzibar")) == 1)
    }

    @Test("The store is attached read-only, and the next search reads what its host has written since", arguments: UserStoreKind.available)
    func theStoreIsReadOnlyAndLive(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        #expect(fixture.pipeline.attachedUserStoreAccessForTesting() == 1)
        let reader = fixture.service(Self.reader)
        let note = Self.search("zanzibar", documents: false)
        #expect(try await reader.searchCount(parameters: note) == 3)
        // The host writes a note and a tag through its own connection, and the next search has them.
        _ = try fixture.test.store.createNote(in: FRUSLightCore.DocumentKey(volumeId: Self.volume, documentId: "d7"), bodyText: "A last zanzibar",
                                              richText: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [],
                                              linkedHighlightId: nil, for: Self.reader, at: Date())
        _ = try fixture.test.store.importResearch(ResearchImportBatch(rows: ["tag_assignments": [ImportRow(values: [
            "id": .text("assignment-new"), "volume_id": .text(Self.volume), "document_id": .text("d7"), "tag_id": .text(Self.tagB),
            "created_at": .text("2026-01-02T00:00:00.000Z"),
        ])]]), for: Self.reader)
        #expect(Set(Self.keys(try await reader.search(parameters: note, limit: 50))) == Set(["d2", "d5", "d6", "d7"].map(Self.key)))
        #expect(try await reader.userTagCounts(parameters: note, tagIds: [Self.tagB]) == [Self.tagB: 2])
        // The index folder holds the index alone: the store's log and shared memory are the host's, beside it.
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.served.deletingLastPathComponent().path) == ["frus.db"])
    }

    @Test("A read-only open refuses a store it cannot attach, and an index with none attached refuses a search that names one", arguments: UserStoreKind.available)
    func aMissingStoreIsRefused(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        let missing = fixture.dir.appendingPathComponent("missing/app.db")
        do {
            _ = try IndexingPipeline(readingIndexAt: fixture.served, fts5Store: fixture.fts5, resources: .none,
                                     userStore: missing)
            Issue.record("the pipeline attached a missing store")
        } catch IndexingError.databaseOpenFailed {
        } catch {
            Issue.record("a missing store was refused with \(error), not databaseOpenFailed")
        }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
        let bare = try IndexingPipeline(readingIndexAt: fixture.served, fts5Store: fixture.fts5, resources: .none)
        #expect(bare.attachedUserStoreAccessForTesting() == -1)
        let service = SearchService(fts5Store: fixture.fts5, pipeline: bare, userSource: .attachedStore(userId: Self.reader))
        await #expect(throws: IndexingError.self) {
            _ = try await service.search(parameters: Self.search("zanzibar", documents: false), limit: 10)
        }
    }

    @Test("The store's rows are read once a statement, not once a matched row: its tag and exact-word sets are uncorrelated, and its tag counts are driven from the reader's assignments", arguments: UserStoreKind.available)
    func theStoresRowsAreReadOnceAStatement(_ kind: UserStoreKind) async throws {
        let fixture = try await Self.makeFixture(kind)
        defer { fixture.close() }
        let source = SearchUserSource.attachedStore(userId: Self.reader)
        let filters = SearchSQLFilters(userTagIds: [Self.tagA], exactTerms: ["Zanzibar"],
                                       exactColumns: ["header", "dateline", "source_note", "body_text", "summary_text", "note_text"],
                                       userSource: source)
        let plan = try await fixture.pipeline.searchDocumentsPlanForTesting(
            corpusMatch: "zanzibar", userContentMatch: "zanzibar", filters: filters, limit: 20, offset: 0)
        #expect(plan.contains("LIST SUBQUERY") && !plan.contains("CORRELATED LIST SUBQUERY"), "\(plan)")
        // The user half's match is read through `user_search`'s full-text index, and each of its rows
        // finds its document by the index's key.
        // FTS5 names a `MATCH` constraint in its index string with an M; the exact-word set's scan of
        // `user_search` has none.
        #expect(plan.range(of: #"SCAN us VIRTUAL TABLE INDEX [0-9]+:M"#, options: .regularExpression) != nil, "\(plan)")
        #expect(plan.contains("SEARCH dc USING COVERING INDEX sqlite_autoindex_document_cache_1 (volume_id=? AND document_id=?)"), "\(plan)")
        // Not driven from the match, which can be most of the index: each assignment finds its document,
        // and the document its place in the match by rowid.
        let counts = try await fixture.pipeline.userTagCountPlanForTesting(tagIds: [Self.tagA, Self.tagB], userSource: source)
        #expect(!counts.contains("SCAN ms") && counts.contains("SEARCH ms USING INTEGER PRIMARY KEY (rowid=?)"), "\(counts)")
        #expect(counts.contains("SEARCH dc USING COVERING INDEX sqlite_autoindex_document_cache_1 (volume_id=? AND document_id=?)"),
                "\(counts)")
    }
}
