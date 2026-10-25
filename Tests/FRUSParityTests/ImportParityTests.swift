// The import's done-when in tests (PLAN's S16c): envelopes the kit writes with every type, at format
// version 6 and at 7, import through the server's route field for field, as the store read back by
// its own SQL shows them; so does each of the kit's own files of versions 1 to 7; a copy the store
// holds is replaced only by a newer one, and then only in what the file's version carries; and the
// browser suite's export is the kit's, as `frus-parity import-fixture` writes it. Then the few lines
// of the app's model code the mapping mirrors, held to the app's source: the headnote prompt every
// draft carries, the kind an inert entry is read as, the defaults a field an older file cannot carry
// takes, the saved search's columns and watermark, a plan's two blobs, and the synced settings the
// app reads.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// The server as it runs, its store empty, and what the browser app sends to import a file.
enum ImportServer {
    static func run<T: Sendable>(_ body: @escaping @Sendable (any TestClientProtocol, DataDirectory) async throws -> T) async throws -> T {
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let files = DataDirectory(root: directory.url.appendingPathComponent("data"))
        let app = try await buildApplication(configuration: ServerConfiguration(
            dataDirectory: files.root, importPollInterval: .milliseconds(50), resourcesDirectory: ServedFixture.resources))
        return try await app.test(.router) { client in try await body(client, files) }
    }

    /// POSTs `file` to /api/v1/me/import as the browser app does, then reads its status until the
    /// job has finished.
    static func importing(_ file: Data, with client: any TestClientProtocol,
                          sourceLocation: SourceLocation = #_sourceLocation) async throws -> ImportStatus {
        let me = try JSONDecoder().decode(Me.self, from: Data(try await client.execute(uri: "/api/v1/me", method: .get).body.readableBytesView))
        let posted = try await client.execute(
            uri: "/api/v1/me/import", method: .post,
            headers: [.origin: "http://localhost:8080", CSRFTokens.header: me.csrfToken, .contentType: "application/json"],
            body: ByteBuffer(bytes: file))
        #expect(posted.status == .accepted, "\(String(buffer: posted.body))", sourceLocation: sourceLocation)
        var status = try JSONDecoder().decode(ImportStatus.self, from: Data(posted.body.readableBytesView))
        let location = try #require(posted.headers[.location], sourceLocation: sourceLocation)
        for _ in 0..<1_000 where [.queued, .running].contains(status.state) {
            try await Task.sleep(for: .milliseconds(20))
            status = try JSONDecoder().decode(ImportStatus.self,
                                              from: Data(try await client.execute(uri: location, method: .get).body.readableBytesView))
        }
        return status
    }
}

@Suite struct ImportParityTests {
    static let layout = Repository.layout

    /// What `everyType` holds of each type, as the report counts the file.
    static func fileCounts(_ envelope: ResearchDataEnvelope) -> [String: Int] {
        [
            "ResearchNote": envelope.notes.count, "DocumentHighlight": envelope.highlights.count, "UserTag": envelope.tags.count,
            "DocumentTagAssignment": envelope.tagAssignments.count, "Collection": envelope.collections.count,
            "CollectionEntry": envelope.collections.flatMap(\.entries).count, "Project": envelope.projects.count,
            "ProjectLeadEntry": envelope.projectLeads.count, "SavedSearch": envelope.savedSearches.count,
            "WorkingCorpus": envelope.workingCorpora.count, "CustomVolumeScope": envelope.customVolumeScopes.count,
            "ReadingHistoryEntry": envelope.readingHistory.count, "SearchHistoryEntry": envelope.searchHistory.count,
            "ExportHistoryEntry": envelope.exportHistory.count, "ArchiveVisitPlan": envelope.archiveVisits.count,
            "ArchiveVisitDocument": envelope.archiveVisits.flatMap(\.documents).count,
            "ArchiveVisitTarget": envelope.archiveVisits.flatMap(\.targets).count, "GeneratedSummary": envelope.summaries.count,
            "SummarizationPrompt": envelope.prompts.count, "AnnotationReview": envelope.annotationReviews.count,
            "SyncedPreferences": envelope.syncedPreferences.count, "PersonClusterOverride": envelope.personClusterOverrides.count,
            "DocumentClassificationOverride": envelope.classificationOverrides.count,
        ]
    }

    /// The first version that carries each type, as the envelope's version history gives them.
    static let since: [String: Int] = [
        "ReadingHistoryEntry": 3, "SearchHistoryEntry": 3, "ExportHistoryEntry": 3, "ArchiveVisitPlan": 6,
        "ArchiveVisitDocument": 6, "ArchiveVisitTarget": 6, "ProjectLeadEntry": 7, "SavedSearch": 7, "WorkingCorpus": 7,
        "CustomVolumeScope": 7, "AnnotationReview": 7, "SyncedPreferences": 7, "PersonClusterOverride": 7,
        "DocumentClassificationOverride": 7,
    ]

    /// A fresh store's report: every record of the file came in, but what is set aside.
    static func expectEverythingCameIn(_ report: ResearchImportReport, _ envelope: ResearchDataEnvelope,
                                       sourceLocation: SourceLocation = #_sourceLocation) {
        let counts = fileCounts(envelope)
        #expect(report.types.map(\.type) == UserStoreSchema.tables.map(\.model), sourceLocation: sourceLocation)
        for type in report.types {
            #expect(type.carried == (envelope.formatVersion >= since[type.type, default: 1]), "\(type.type)", sourceLocation: sourceLocation)
            #expect(type.inFile == counts[type.type], "\(type.type)", sourceLocation: sourceLocation)
            #expect(type.added + type.setAside + type.repeated == type.inFile && type.replaced == 0 && type.kept == 0,
                    "\(type.type): \(type)", sourceLocation: sourceLocation)
        }
    }

    /// The done-when: an envelope the kit writes with every type, at 7 and at 6, imports through the
    /// route's job field for field, every record held as the file has it.
    @Test(arguments: [7, 6]) func anEnvelopeTheKitWritesWithEveryTypeImportsFieldForField(version: Int) async throws {
        let envelope = ImportFixtures.everyType(formatVersion: version)
        let file = try ImportFixtures.file(envelope)
        if version < 7 {
            let keys = Set((try JSONSerialization.jsonObject(with: file) as? [String: Any] ?? [:]).keys)
            #expect(keys.isDisjoint(with: ImportFixtures.version7Keys), "a version-6 file lacks what build 50 did not write")
        }
        try await ImportServer.run { client, files in
            let status = try await ImportServer.importing(file, with: client)
            #expect(status.state == .succeeded && status.formatVersion == version && status.problem == nil)
            let report = try #require(status.report)
            Self.expectEverythingCameIn(report, envelope)
            let decoded = try MacImport.envelope(of: file)
            let stored = try StoredResearch.envelope(at: files.userStore, user: "owner", formatVersion: version, header: decoded)
            let comparison = ResearchComparison.compare(file: decoded, stored: stored)
            #expect(comparison.isWhole, "\(comparison.types.filter { !$0.isWhole })")
            #expect(comparison.types.map(\.inFile) == report.types.map { $0.inFile - ($0.type == "SyncedPreferences" ? $0.setAside : 0) })

            // What the import made of what each version says.
            #expect(report.exportedAt == "2026-10-24T20:00:00.000Z")
            #expect(report.headnoteDrafts == 1, "by its flag at 7, and by its prompt before")
            #expect(report.summariesWithoutAuthorship == 0)
            #expect(report.formattedNotes == (version >= 7 ? 2 : 0) && report.formattingKept == (version >= 7 ? 1 : 0))
            #expect(report.inertEntries == (version >= 7 ? 0 : 1))
            let unlinked = version >= 7 ? [ImportFixtures.id(57)] : [ImportFixtures.id(56), ImportFixtures.id(57)]
            #expect(report.unlinkedCollections.map(\.id) == unlinked.map(\.uuidString))
            #expect(report.unlinkedCollections.map(\.name).last == "A deleted search's")
            #expect(report.searchableDocuments == 2, "d3 and d4 of frus1961-63v06")
            if version >= 7 {
                let preferences = try #require(report.types.first { $0.type == "SyncedPreferences" })
                #expect(preferences.inFile == 2 && preferences.added == 1 && preferences.setAside == 1)
                #expect(stored.syncedPreferences.map(\.citationStyleRaw) == ["chicago"], "the earliest made, as the app reads them")
            }

            // Read through the routes as the browser app reads them.
            let rows = try UserStoreRows(files.userStore)
            let inert = try rows.firstRow("SELECT kind, level, selected_highlight_ids FROM collection_entries WHERE id = ?",
                                          [ImportFixtures.id(52).uuidString])
            #expect(inert == (version >= 7 ? ["heading", "2", "[]"] : [MacImport.inertKind, "1", "[]"]))
            let draft = try #require(try rows.storedSummary(ImportFixtures.id(73).uuidString))
            #expect(draft["is_headnote_draft"] == "1")
            let summaries = try JSONDecoder().decode(DocumentSummaries.self, from: Data(try await client.execute(
                uri: "/api/v1/me/volumes/frus1961-63v06/documents/d3/summaries", method: .get).body.readableBytesView))
            #expect(summaries.items.map(\.id) == [ImportFixtures.id(71), ImportFixtures.id(70)].map(\.uuidString),
                    "the newest first, the headnote draft left out")
            #expect(summaries.items.map(\.authorship) == ["aiEdited", "aiGenerated"] && summaries.items.allSatisfy { !$0.editable })
            #expect(summaries.items.map(\.promptName) == [nil, "Cold War brief"], "a standard prompt the file does not name")
            let note = try JSONDecoder().decode(Note.self, from: Data(try await client.execute(
                uri: "/api/v1/me/notes/\(ImportFixtures.id(3).uuidString)", method: .get).body.readableBytesView))
            #expect(note.formattingKept == (version >= 7) && note.runs == nil)
            #expect(try rows.storedNote(ImportFixtures.id(3).uuidString)?.richText.map(Data.init)
                    == (version >= 7 ? envelope.notes[2].richText : nil), "its RTF as it came")
        }
    }

    /// Each of the kit's own files, one of each version from 1 to 7 with a record of every type it
    /// carried, imports whole: every record of every type held as the file has it.
    @Test func theKitsOwnFileOfEachVersionImportsWhole() async throws {
        let files = try KitExportFixtures.files(layout: Self.layout)
        #expect(files.map(\.version) == Array(MacImport.formatVersions))
        for (version, json) in files {
            let directory = try TemporaryDirectory()
            let outcome = try await ImportCheck.run(Data(json.utf8), in: directory.url)
            let decoded = try MacImport.envelope(of: Data(json.utf8))
            #expect(outcome.report.formatVersion == version)
            Self.expectEverythingCameIn(outcome.report, decoded)
            #expect(outcome.comparison.isWhole, "version \(version): \(outcome.comparison.types.filter { !$0.isWhole })")
            #expect(outcome.report.summariesWithoutAuthorship == (version < 5 ? decoded.summaries.count : 0))
            #expect(outcome.report.inertEntries == (version == 6 ? 1 : 0), "version 6's entry with no document")
            withExtendedLifetime(directory) {}
        }
    }

    /// A file imported again keeps every record; a newer copy replaces only its own row, and in a
    /// file of version 6 only the fields 6 carries, the rest kept as the store has them; an older one
    /// is kept.
    @Test func aRecordTheStoreHoldsIsReplacedOnlyByANewerCopy() async throws {
        let v7 = ImportFixtures.everyType(formatVersion: 7)
        try await ImportServer.run { client, files in
            #expect(try await ImportServer.importing(try ImportFixtures.file(v7), with: client).state == .succeeded)
            let again = try #require(try await ImportServer.importing(try ImportFixtures.file(v7), with: client).report)
            for type in again.types {
                #expect(type.kept + type.setAside == type.inFile && type.added == 0 && type.replaced == 0, "\(type)")
            }

            // A version-6 file in which the collection, its note and a tag changed later, and a
            // highlight the Mac made earlier: the newer three replaced, in what 6 carries.
            var v6 = ImportFixtures.everyType(formatVersion: 6)
            v6.collections[0].name = "Briefing book, revised"
            v6.collections[0].lastModified = ImportFixtures.date("2026-07-01T00:00:00Z")
            v6.notes[1].bodyText = "A bold note, edited."
            v6.notes[1].lastModified = ImportFixtures.date("2026-07-01T00:00:00Z")
            v6.tags[1].name = "Primary sources"
            v6.tags[1].lastModified = ImportFixtures.date("2026-07-01T00:00:00Z")
            v6.tags[0].name = "An older name"
            v6.tags[0].lastModified = ImportFixtures.date("2026-01-01T00:00:00Z")
            v6.highlights[0].colorTag = "green"
            let report = try #require(try await ImportServer.importing(try ImportFixtures.file(v6), with: client).report)
            let counts = Dictionary(uniqueKeysWithValues: report.types.map { ($0.type, $0) })
            #expect(counts["Collection"]?.replaced == 1 && counts["Collection"]?.kept == 2)
            #expect(counts["ResearchNote"]?.replaced == 1 && counts["UserTag"]?.replaced == 1 && counts["UserTag"]?.kept == 1)
            #expect(counts["DocumentHighlight"]?.replaced == 0, "a highlight's time is when it was made")
            #expect(counts["SavedSearch"]?.carried == false && counts["SavedSearch"]?.inFile == 0)

            let stored = try StoredResearch.envelope(at: files.userStore, user: "owner", formatVersion: 7, header: v7)
            var expected = v7
            expected.collections[0].name = "Briefing book, revised"
            expected.collections[0].lastModified = v6.collections[0].lastModified
            expected.notes[1].bodyText = "A bold note, edited."
            expected.notes[1].lastModified = v6.notes[1].lastModified
            expected.tags[1].name = "Primary sources"
            expected.tags[1].lastModified = v6.tags[1].lastModified
            let comparison = ResearchComparison.compare(file: expected, stored: stored)
            #expect(comparison.isWhole, "the newer copies written, and what 6 does not carry kept: \(comparison.types.filter { !$0.isWhole })")
            #expect(stored.notes.first { $0.id == ImportFixtures.id(2) }?.richText == v7.notes[1].richText,
                    "its RTF, which 6 does not carry, kept")
        }
    }

    /// A record the file gives twice, as the owner's export of build 50 did, is written once: the
    /// newer copy, or of two as new the first; and the report counts the repeat apart from what the
    /// store kept.
    @Test func aRecordTheFileGivesTwiceIsWrittenOnceAndCountedAsARepeat() async throws {
        var envelope = ImportFixtures.everyType(formatVersion: 6)
        envelope.notes.append(envelope.notes[0])
        envelope.readingHistory += [envelope.readingHistory[0], envelope.readingHistory[0]]
        var renamed = envelope.tags[0]
        renamed.name = "Cuba, renamed"
        renamed.lastModified = ImportFixtures.date("2026-08-01T00:00:00Z")
        var earlier = envelope.tags[0]
        earlier.name = "Cuba, before"
        earlier.lastModified = ImportFixtures.date("2026-01-15T00:00:00Z")
        envelope.tags += [renamed, earlier]
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let outcome = try await ImportCheck.run(try ImportFixtures.file(envelope), in: directory.url)
        let counts = Dictionary(uniqueKeysWithValues: outcome.report.types.map { ($0.type, $0) })
        #expect(counts["ResearchNote"].map { [$0.inFile, $0.added, $0.kept, $0.repeated] } == [4, 3, 0, 1])
        #expect(counts["ReadingHistoryEntry"].map { [$0.inFile, $0.added, $0.kept, $0.repeated] } == [4, 2, 0, 2])
        #expect(counts["UserTag"].map { [$0.inFile, $0.added, $0.kept, $0.repeated] } == [4, 2, 0, 2])
        Self.expectEverythingCameIn(outcome.report, envelope)
        let stored = try StoredResearch.envelope(at: outcome.store, user: "owner", formatVersion: 6, header: envelope)
        #expect(stored.tags.first { $0.id == ImportFixtures.id(20) }?.name == "Cuba, renamed", "the newest copy")
        #expect(outcome.comparison.isWhole)
        #expect(ImportCheck.describe(outcome).contains {
            $0.hasPrefix("ResearchNote: 4 in the file; 3 came in, 0 replaced, 0 kept, 0 set aside, 1 repeated in the file")
        })
    }

    /// The check sees what the store holds otherwise: a field changed beside the import is named,
    /// with its record's id and never its value, and a record gone is missing.
    @Test func theCheckNamesARecordTheStoreHoldsOtherwiseOrNotAtAll() async throws {
        let envelope = ImportFixtures.everyType(formatVersion: 7)
        let directory = try TemporaryDirectory()
        defer { withExtendedLifetime(directory) {} }
        let outcome = try await ImportCheck.run(try ImportFixtures.file(envelope), in: directory.url)
        #expect(outcome.comparison.isWhole)
        let rows = try UserStoreRows(outcome.store)
        _ = try rows.firstRow("UPDATE collection_entries SET excerpt_end = 20 WHERE id = ?", [ImportFixtures.id(54).uuidString])
        _ = try rows.firstRow("UPDATE notes SET rich_text = NULL WHERE id = ?", [ImportFixtures.id(2).uuidString])
        _ = try rows.firstRow("DELETE FROM visit_targets WHERE id = ?", [ImportFixtures.id(136).uuidString])
        let stored = try StoredResearch.envelope(at: outcome.store, user: "owner", formatVersion: 7, header: envelope)
        let comparison = ResearchComparison.compare(file: envelope, stored: stored)
        let broken = comparison.types.filter { !$0.isWhole }
        #expect(broken.map(\.type) == ["ResearchNote", "CollectionEntry", "ArchiveVisitTarget"])
        #expect(broken[0].different.map(\.id) == [ImportFixtures.id(2).uuidString] && broken[0].different[0].fields == ["richText"])
        #expect(broken[1].different.first?.fields == ["excerptEnd"])
        #expect(broken[2].missing == [ImportFixtures.id(136).uuidString] && broken[2].different.isEmpty)
        #expect(ImportCheck.describe(ImportCheck.Outcome(report: outcome.report, comparison: comparison, store: outcome.store))
            .contains("  differs: \(ImportFixtures.id(54).uuidString) in excerptEnd"))
    }

    /// The browser suite's export is the kit's envelope as `frus-parity import-fixture` writes it,
    /// byte for byte, its highlight over d3's own text in d3's version; and it imports whole.
    @Test func theBrowserSuitesExportIsTheOneTheFixtureCommandWrites() async throws {
        let committed = try Data(contentsOf: Self.layout.root.appendingPathComponent(ImportFixtures.browserSuitePath))
        let written = try await ImportFixtures.browserSuiteFile(layout: Self.layout)
        #expect(committed == written, "run frus-parity import-fixture")
        let directory = try TemporaryDirectory()
        let outcome = try await ImportCheck.run(committed, in: directory.url)
        #expect(outcome.comparison.isWhole && outcome.report.formatVersion == 7)
        let envelope = try MacImport.envelope(of: committed)
        let highlight = try #require(envelope.highlights.first)
        let model = try await ReaderRenderer(layout: Self.layout).fullParseModels(["frus1961-63v06"]) { model in
            (flat: buildFlatText(from: model), version: ASTToRenderNodeConverter.renderingVersion(for: model))
        }.first { $0.document == "d3" }?.value
        #expect(highlight.renderingVersion == model?.version)
        let units = Array((model?.flat ?? "").utf16)
        #expect(String(decoding: units[highlight.startOffset..<highlight.endOffset], as: UTF16.self) == highlight.selectedText)
        withExtendedLifetime(directory) {}
    }

    // MARK: Check 6 on an export's highlights

    /// The Swift half of check 6 on an export's highlights, over the fixture TEI: a highlight in the
    /// excerpt's form and one in the raw form of before 3 July pass; one in another version of the
    /// text, and one in a volume the folder lacks, go to review; one whose text is neither form fails;
    /// and one ending on a line break passes but is left out of the samples Chromium draws.
    @Test func check6OnAnExportsHighlightsHoldsEachToItsTwoForms() async throws {
        let models = try await ReaderRenderer(layout: Self.layout).fullParseModels(["frus1961-63v06"]) { model in
            (flat: buildFlatText(from: model), blocks: buildFlatTextBlocks(from: model),
             version: ASTToRenderNodeConverter.renderingVersion(for: model))
        }
        let d3 = try #require(models.first { $0.document == "d3" }?.value)
        let units = Array(d3.flat.utf16)
        let boundary = d3.blocks[0].utf16.count
        let lined = try #require(models.first { $0.value.flat.utf16.contains(0x0A) })
        let newline = try #require(Array(lined.value.flat.utf16).firstIndex(of: 0x0A))
        func highlight(_ number: Int, _ start: Int, _ end: Int, text: String, version: String, volume: String = "frus1961-63v06",
                       document: String = "d3") -> DocumentHighlightExport {
            DocumentHighlightExport(id: ImportFixtures.id(number), volumeId: volume, documentId: document, startOffset: start,
                                    endOffset: end, colorTag: "pink", selectedText: text, renderingVersion: version)
        }
        let span = (boundary - 4, boundary + 4)
        let excerpt = try #require(flatTextExcerpt(blocks: d3.blocks, start: span.0, end: span.1))
        let raw = String(decoding: units[span.0..<span.1], as: UTF16.self)
        #expect(excerpt != raw, "across two blocks")
        let result = try await ExportHighlights.check([
            highlight(1, span.0, span.1, text: excerpt, version: d3.version),
            highlight(2, span.0, span.1, text: raw, version: d3.version),
            highlight(3, span.0, span.1, text: excerpt, version: "0123456789abcdef"),
            highlight(4, 0, 4, text: "Text", version: d3.version, volume: "frus1999v99", document: "d1"),
            highlight(5, span.0, span.1, text: "Neither form", version: d3.version),
            highlight(6, newline - 2, newline + 1,
                      text: flatTextExcerpt(blocks: lined.value.blocks, start: newline - 2, end: newline + 1) ?? "",
                      version: lined.value.version, document: lined.document),
        ], layout: Self.layout, tei: Self.layout.tei)
        #expect(result.highlights == 6 && result.matched == 4 && result.passed == 3 && result.rawForm == 1)
        #expect(result.toReview.map(\.id) == [ImportFixtures.id(3), ImportFixtures.id(4)].map(\.uuidString))
        #expect(result.toReview.map(\.reason) == ["the text changed since it was made", "frus1999v99 is not in the TEI folder"])
        #expect(result.failures.map(\.id) == [ImportFixtures.id(5).uuidString])
        #expect(result.endingOnALineBreak == [ImportFixtures.id(6).uuidString])
        let row = try #require(result.samples.rows.first)
        #expect(result.samples.rows.count == 1 && row.document == "d3" && row.length == units.count && row.renderingVersion == d3.version)
        #expect(row.samples.map(\.text) == [raw, raw] && row.samples.map(\.selectedText) == [excerpt, nil])
    }

    /// Check 6's two forms are the kit's own test, `HighlightReanchor`'s `extracts`, private at the
    /// pin and public from FRUS-Explorer#1789: held here to its body, so a change to the kit's rule
    /// fails until the check follows it, and the pin move past #1789, whose signature differs, makes
    /// the check call the kit's.
    @Test func check6sTwoFormsAreTheKitsOwnTest() throws {
        let source = try String(contentsOf: Self.layout.upstream.appendingPathComponent(
            "FRUSCoreKit/DocumentView/HighlightReanchorSearch.swift"), encoding: .utf8)
        let body = try NotesAndSummariesParityTests.body(of: "private static func extracts(_ passage: String, start: Int, end: Int,",
                                                         in: source)
        #expect(body == [
            "if flatTextExcerpt(blocks: blocks, start: start, end: end) == passage { return true }",
            "guard end <= flat.count, end > start else { return false }",
            "return String(decoding: flat[start..<end], as: UTF16.self) == passage",
        ])
        let blocks = ["First paragraph.", "Second one."]
        let flat = Array(blocks.joined().utf16)
        #expect(ExportHighlights.extracts("paragraph.\n\nSecond", start: 6, end: 22, flat: flat, blocks: blocks))
        #expect(ExportHighlights.extracts("paragraph.Second", start: 6, end: 22, flat: flat, blocks: blocks))
        #expect(!ExportHighlights.extracts("paragraph. Second", start: 6, end: 22, flat: flat, blocks: blocks))
        #expect(!ExportHighlights.extracts("paragraph.", start: 6, end: 99, flat: flat, blocks: blocks))
    }

    // MARK: Mirrored, with a parity test

    static let app = Repository.layout.upstream.appendingPathComponent("FRUSExplorer")

    static func read(_ path: String) throws -> String {
        try String(contentsOf: app.appendingPathComponent(path), encoding: .utf8)
    }

    /// Every headnote draft the app makes carries the headnote prompt, which tells a draft apart in a
    /// file before version 7: the inspector's draft stamps it, and a collection's duplicate copies the
    /// source draft's.
    @Test func everyHeadnoteDraftCarriesTheHeadnotePrompt() throws {
        let inspector = try Self.read("Collections/CollectionEntryInspector.swift")
        #expect(inspector.contains(#"private static let headnoteDraftPromptId = UUID(uuidString: "\#(MacImport.headnoteDraftPromptId)")!"#))
        #expect(inspector.contains("promptId: Self.headnoteDraftPromptId, responseText: text,"))
        let summary = try Self.read("Models/GeneratedSummary.swift")
        #expect(summary.contains("promptId: draft.promptId,"), "a duplicate's draft keeps the prompt of the draft it copies")
        var sites = 0
        for file in try FileManager.default.subpathsOfDirectory(atPath: Self.app.path) where file.hasSuffix(".swift") {
            sites += try Self.read(file).components(separatedBy: "isHeadnoteDraft: true").count - 1
        }
        #expect(sites == 2, "a third place that makes a draft would need its prompt checked")
        #expect(OwnSummary.promptId != MacImport.headnoteDraftPromptId)
    }

    /// An entry of a kind the app does not know reads as `.unrecognized`, an inert row that resolve
    /// and export skip, and so does the raw value `unrecognized` itself.
    @Test func anInertEntryReadsAsTheAppsUnrecognizedKind() throws {
        let collection = try Self.read("Models/Collection.swift")
        #expect(collection.contains("get { CollectionEntryKind(rawValue: kind) ?? .unrecognized }"))
        #expect(collection.contains("    case unrecognized\n"), "its raw value is its name")
        #expect(MacImport.inertKind == "unrecognized")
    }

    /// A field a file before version 7 cannot carry takes, in a new row, the initial value the app's
    /// model gives the property.
    @Test func whatAnOlderFileCannotCarryTakesTheModelsDefault() throws {
        let collection = try Self.read("Models/Collection.swift")
        let project = try Self.read("Models/Project.swift")
        func initial(_ property: String, in source: String) -> String? {
            guard let match = source.firstMatch(of: try! Regex("\n    var \(property): [^=\n{]+?(?: = ([^\n{]+?))?\\s*(?:\\{|\n)")) else { return nil }
            return match.output.count > 1 ? (match.output[1].substring.map(String.init) ?? "nil") : "nil"
        }
        func expected(_ value: SQLiteValue) -> String {
            switch value {
            case .null: "nil"
            case .integer(let number): number == 0 ? "false" : number == 1 ? "true" : "\(number)"
            case .text(let text) where text == "[]": "[]"
            case .text(let text): "\"\(text)\""
            default: "?"
            }
        }
        for (column, value) in MacImport.collectionSettings(nil) {
            let property = try #require(UserStoreSchema.table(for: "Collection")?.columns.first { $0.name == column }?.property)
            #expect(initial(property, in: collection) == expected(value), "Collection.\(property)")
        }
        let entryClass = try #require(collection.range(of: "@Model final class CollectionEntry {")).upperBound
        let entry = String(collection[entryClass...])
        for (column, value) in MacImport.entryFields(nil) {
            let property = try #require(UserStoreSchema.table(for: "CollectionEntry")?.columns.first { $0.name == column }?.property)
            // `level` is an integer, written as one.
            let want = column == "level" ? "1" : expected(value)
            #expect(initial(property, in: entry) == want, "CollectionEntry.\(property)")
        }
        #expect(initial("defaultUserTagIds", in: project) == "[]" && initial("leadAxisWeights", in: project) == "nil")
    }

    /// The saved search's scalar columns are what `SavedSearch.init(name:parameters:)` writes from the
    /// parameters, and its watermark is `SavedSearchFreshness`, encoded as `recordRun` encodes it.
    @Test func aSavedSearchsColumnsAreWhatTheAppWritesFromItsParameters() throws {
        let source = try Self.read("Models/SavedSearch.swift")
        let initializer = try NotesAndSummariesParityTests.body(of: "init(name: String, parameters: SearchParameters) {", in: source)
        #expect(initializer == [
            "self.id = UUID()", "self.name = name", "self.queryText = parameters.keywords ?? \"\"",
            "self.phraseText = parameters.phrase ?? \"\"", "self.prefixWildcard = parameters.prefixWildcard ?? \"\"",
            "self.booleanModeRaw = parameters.booleanMode == .or ? \"or\" : \"and\"",
            "self.excludedTermsCSV = parameters.excludedTerms.joined(separator: \",\")", "var flags = 0",
            "if parameters.includeDocumentText { flags |= 1 }", "if parameters.includeSummaries { flags |= 2 }",
            "if parameters.includeNotes { flags |= 4 }", "self.scopeFlags = flags", "if let range = parameters.dateRange {",
            "let fmt = ISO8601DateFormatter()", "fmt.formatOptions = [.withFullDate]",
            "self.dateRangeStart = range.earliest.flatMap { fmt.date(from: $0) }",
            "self.dateRangeEnd = range.latest.flatMap { fmt.date(from: $0) }", "}",
            "self.subjectTagIdsCSV = parameters.subjectTagIds.joined(separator: \",\")", "switch parameters.documentTypeFilter {",
            "case .documentsOnly: self.documentTypeFilterRaw = \"documentsOnly\"",
            "case .editorialNotesOnly: self.documentTypeFilterRaw = \"editorialNotesOnly\"",
            "case .all: self.documentTypeFilterRaw = \"all\"", "}", "self.personRef = parameters.personRef ?? \"\"",
            "self.sortOrder = \"relevance\"", "self.createdAt = .now", "self.lastModified = .now",
            "self.parametersData = try? JSONEncoder().encode(parameters)",
        ])
        let scalars = SavedSearchColumns.scalars(of: SearchParameters(
            keywords: "a", phrase: "b c", booleanMode: .or, excludedTerms: ["d", "e"], prefixWildcard: "f",
            dateRange: DateRange(earliest: "1961-01-02", latest: "1961"), subjectTagIds: ["g", "h"], includeDocumentText: false,
            includeSummaries: true, includeNotes: false, documentTypeFilter: .editorialNotesOnly, personRef: "p"))
        #expect(scalars == [
            "query_text": .text("a"), "phrase_text": .text("b c"), "prefix_wildcard": .text("f"), "boolean_mode_raw": .text("or"),
            "excluded_terms_csv": .text("d,e"), "scope_flags": .integer(2), "date_range_start": .text("1961-01-02T00:00:00.000Z"),
            "date_range_end": .null, "subject_tag_ids_csv": .text("g,h"), "document_type_filter_raw": .text("editorialNotesOnly"),
            "person_ref": .text("p"), "sort_order": .text("relevance"),
        ])
        #expect(Set(scalars.keys).union(["id", "name", "created_at", "last_modified", "parameters_data", "freshness_data"])
                == Set(UserStoreSchema.table(for: "SavedSearch")?.columns.map(\.name) ?? []))

        let freshness = try #require(source.range(of: "struct SavedSearchFreshness: Codable, Equatable, Sendable {"))
        let fields = source[freshness.upperBound...].matches(of: /\n    var (\w+): ([^\n]+)\n/).map { "\($0.1): \($0.2)" }
        #expect(Array(fields.prefix(3)) == ["lastRunAt: Date?", "matchCountAtLastRun: Int?", "indexedVolumeCountAtLastRun: Int?"])
        #expect(source.contains("freshnessData = try? JSONEncoder().encode(mark)"))
        // The app's encoder sets no order of keys, so the blob is read, not compared byte for byte:
        // a date as seconds since 2001, and a field with no value left out.
        let run = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let blob = try #require(SavedSearchColumns.freshness(lastRunAt: run, matchCount: 3, indexedVolumeCount: nil).text)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(blob.utf8)) as? [String: Any])
        #expect(Set(object.keys) == ["lastRunAt", "matchCountAtLastRun"])
        #expect((object["lastRunAt"] as? NSNumber)?.doubleValue == 800_000_000 && (object["matchCountAtLastRun"] as? NSNumber)?.intValue == 3)
        #expect(SavedSearchColumns.freshness(lastRunAt: nil, matchCount: nil, indexedVolumeCount: nil) == .null)
    }

    /// A plan's tiers and toggles are kept as the app's setters encode them, and the store keeps the
    /// earliest-made set of synced settings, as the app's coordinator keeps it.
    @Test func aPlansBlobsAndTheSyncedSettingsAreKeptAsTheAppKeepsThem() throws {
        let plan = try Self.read("Models/ArchiveVisitPlan.swift")
        #expect(plan.contains("tiersData = try? JSONEncoder().encode(newValue.sorted { $0.order < $1.order })"))
        #expect(plan.contains("deliverableTogglesData = try? JSONEncoder().encode(newValue)"))
        let preferences = try Self.read("Models/SyncedPreferences.swift")
        #expect(preferences.contains("resolves that by treating the earliest-created record as canonical"))
    }
}
