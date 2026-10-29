// A collection's `.fruscollection` file both ways, a smart collection, its link to a saved search and its
// snapshot, Summary only's refusal and the headnote card, through the API (PLAN's S18f): the file is the
// kit's of the collection's source, its prose RTF, its notes only when they are included, refused for a
// smart collection in the app's words; a file the web wrote imports as the app's Import Collection… makes
// it, and its export again is the same file; a smart collection resolves its saved search for the
// preview, each export and the preview's count, and a snapshot freezes its results; Summary only names the
// documents with no summary stored, with the app's reason; and the card writes the researcher's headnote,
// AI · edited over the model's, a draft of the entry's own in place of the last. That the file and a smart
// collection's exports are the kit's to the byte is FRUSParityTests' CollectionFileParityTests.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSRichText
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CollectionFileTests {
    static let volume = CollectionTests.volume
    static let base = CollectionTests.base

    static func native(_ browser: Browser, _ id: String, includeNotes: Bool? = nil) async throws -> TestResponse {
        try await browser.send(.post, "\(base)/\(id)/export", try CollectionTests.json(["format": "fruscollection", "includeNotes": includeNotes]))
    }

    static func file(_ response: TestResponse, sourceLocation: SourceLocation = #_sourceLocation) throws -> FRUSCollectionFile {
        #expect(response.status == .ok, "\(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try NativeCollectionSerializer.decode(Data(buffer: response.body))
    }

    static func importing(_ browser: Browser, _ body: Data) async throws -> TestResponse {
        try await browser.send(.post, "\(base)/import", String(decoding: body, as: UTF8.self))
    }

    static func note(_ browser: Browser, _ documentId: String, _ text: String) async throws -> Note {
        let response = try await browser.send(.post, "/api/v1/me/volumes/\(volume)/documents/\(documentId)/notes", try CollectionTests.json([
            "bodyText": text, "runs": nil, "userTagIds": [], "projectIds": [], "selectedSummaryIds": [],
        ]))
        #expect(response.status == .created, "\(String(buffer: response.body))")
        return try decode(Note.self, response)
    }

    /// The file a collection writes, as the app's sheet writes it: the kit's, at format 2 for a collection
    /// using its features, its entries in order with their levels, a note block's RTF as the codec wrote
    /// it and a pre-RTF blob healed to the codec's RTF of its text; no notes unless they are included,
    /// then each document entry's as the sheet resolves them; named as the app names it, kept in the
    /// history with its document entries; refused for a smart collection in the app's words.
    @Test func theFileIsTheKitsOfTheCollectionsSource() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let berlin = try await CollectionTests.made(owner, "Berlin")
            let path = "\(Self.base)/\(berlin.id)"
            let heading = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#)
            _ = try await owner.send(.patch, "\(path)/entries/\(heading.entryIds[0])", #"{"text": "Letters"}"#)
            let letters = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2"]))
            let prose = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "prose"}"#)
            _ = try await owner.send(.patch, "\(path)/entries/\(prose.entryIds[0])", try CollectionTests.json([
                "text": "Read together.", "runs": [["text": "Read ", "bold": false, "italic": false, "underline": false, "colorHex": nil, "linkURL": nil],
                                                   ["text": "together.", "bold": true, "italic": false, "underline": false, "colorHex": nil, "linkURL": nil]],
            ]))
            _ = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"generatedBlockType": "bibliography"}"#)
            _ = try await Self.note(owner, "d1", "Read beside the second letter.")
            let other = try await Self.note(owner, "d2", "Left out.")
            _ = try await Self.note(owner, "d2", "Chosen alone.")
            let excluded = try await owner.send(.patch, "\(path)/entries/\(letters.entryIds[1])",
                                                try CollectionTests.json(["note": ["id": other.id, "included": false]]))
            #expect(excluded.status == .ok, "\(String(buffer: excluded.body))")

            let plain = try await Self.native(owner, berlin.id)
            #expect(plain.headers[.contentType] == "application/json; charset=utf-8")
            #expect(plain.headers[.contentDisposition] == #"attachment; filename="Berlin.fruscollection"; filename*=UTF-8''Berlin.fruscollection"#)
            let file = try Self.file(plain)
            #expect(file.format == "fruscollection" && file.formatVersion == 2 && file.minimumReaderVersion == 1, "a bibliography is a v2 feature")
            #expect(file.name == "Berlin" && file.entries.map(\.kind) == ["heading", "document", "document", "prose", "generated"])
            #expect(file.entries.map(\.documentId) == [nil, "d1", "d2", nil, nil] && file.entries[0].text == "Letters")
            #expect(file.entries.allSatisfy { $0.notes == nil }, "no notes unless they are included")
            let rtf = try #require(file.entries[3].richText)
            let reading = try #require(RTFReader.read([UInt8](rtf)))
            #expect(reading.text == "Read together." && reading.runs.last?.bold == true && file.entries[3].text == "Read together.")

            // With the notes: d1's every note, d2's the selection, the note left out of it not among them.
            let shared = try Self.file(try await Self.native(owner, berlin.id, includeNotes: true))
            #expect(shared.entries[1].notes == ["Read beside the second letter."])
            #expect(shared.entries[2].notes == ["Chosen alone."])

            // A pre-RTF blob, July 2026's JSON, healed to RTF of its text.
            try fixture.rows.run("UPDATE collection_entries SET rich_text = ? WHERE upper(id) = ?",
                                 [.blob(Array(#"["Read together.",{}]"#.utf8)), .text(prose.entryIds[0])])
            let healed = try Self.file(try await Self.native(owner, berlin.id))
            #expect(RTFReader.read([UInt8](try #require(healed.entries[3].richText)))?.text == "Read together.")

            let history = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history"))
            #expect(history.exports.map(\.format) == ["fruscollection", "fruscollection", "fruscollection"])
            #expect(history.exports.map(\.documentCount) == [2, 2, 2] && history.exports.first?.formatName == "FRUS Collection (shareable)")

            let notes = try await owner.send(.post, "\(path)/export", #"{"format": "html", "includeNotes": true}"#)
            #expect(notes.status == .badRequest && problemCode(notes) == "INVALID_FIELD")
            try fixture.rows.run("UPDATE collections SET saved_search_id = '\(CollectionTests.stranger)' WHERE upper(id) = '\(berlin.id)'")
            let smart = try await Self.native(owner, berlin.id)
            #expect(smart.status == .conflict && problemCode(smart) == "SMART_COLLECTION_NOT_SHAREABLE")
            #expect(try decode(APIProblem.Body.self, smart).detail == "Smart collections can’t be shared as a file yet.")
            let empty = try await CollectionTests.made(owner, "Empty")
            #expect(problemCode(try await Self.native(owner, empty.id)) == "COLLECTION_EMPTY")
        }
    }

    /// A file the web wrote imports as the app's Import Collection… makes it: a new collection under new
    /// ids, in the project worked in, each entry as the file has it, the notes it carries made on their
    /// documents, with no project, and taken by their entries, where the search finds them at once; its
    /// export again is the same file. A file that is no collection, or needs a newer reader, is refused in
    /// the kit's words, and a text no field keeps in the editor's.
    @Test func aFileImportsAsTheAppsImportCollectionMakesIt() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let berlin = try await CollectionTests.made(owner, "Berlin")
            let path = "\(Self.base)/\(berlin.id)"
            let heading = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#)
            _ = try await owner.send(.patch, "\(path)/entries/\(heading.entryIds[0])", #"{"text": "Letters"}"#)
            let letters = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2"]))
            _ = try await owner.send(.patch, "\(path)/entries/\(letters.entryIds[0])", #"{"includeHeadnote": true, "titleOverride": "The first"}"#)
            _ = try await CollectionTests.detail(owner, .patch, path, #"{"subtitle": "A reader", "includeColophon": true}"#)
            _ = try await Self.note(owner, "d1", "Zanzibar, the first word.")
            let exported = Data(buffer: try await Self.native(owner, berlin.id, includeNotes: true).body)

            let project = try decode(Project.self, try await owner.send(.post, "/api/v1/me/projects", #"{"name": "Berlin crisis"}"#))
            let response = try await Self.importing(owner, exported)
            #expect(response.status == .created, "\(String(buffer: response.body))")
            let imported = try decode(CollectionDetail.self, response)
            #expect(response.headers[.location] == "/api/v1/me/collections/\(imported.id)")
            #expect(imported.id != berlin.id && imported.name == "Berlin" && imported.subtitle == "A reader" && imported.includeColophon)
            #expect(imported.projectIds == [project.id] && imported.createdAt == UserStoreDate.text(UserDataFixture.now))
            #expect(CollectionTests.outline(imported) == ["heading:Letters@1", "document:d1@1", "document:d2@1"])
            #expect(Set(imported.entries.map(\.id)).isDisjoint(with: letters.entryIds + heading.entryIds))
            #expect(imported.entries[1].titleOverride == "The first" && imported.entries[1].includeHeadnote == true)
            let brought = try #require(imported.entries[1].selectedNoteIds.first)
            #expect(imported.entries[1].selectedNoteIds == [brought] && imported.entries[2].selectedNoteIds.isEmpty)
            let note = try #require(try fixture.store.notes(for: "owner").first { $0.id == brought })
            #expect(note.bodyText == "Zanzibar, the first word." && note.projectIds.isEmpty && note.documentId == "d1")
            #expect(try fixture.rows.userSearchMatches("zanzibar") == ["d1"], "the import's note is searched at once")

            let again = Data(buffer: try await Self.native(owner, imported.id, includeNotes: true).body)
            #expect(again == exported, "the export of the imported file is the file")

            for (body, code) in [("not json", "NOT_A_COLLECTION_FILE"), (#"{"format": "frusnotes", "formatVersion": 1}"#, "NOT_A_COLLECTION_FILE"),
                                 (#"{"format": "fruscollection", "formatVersion": 3, "name": "N", "composition": {}, "entries": []}"#,
                                  "NOT_A_COLLECTION_FILE")] {
                let refused = try await Self.importing(owner, Data(body.utf8))
                #expect(refused.status == .unprocessableContent && problemCode(refused) == code, "\(body)")
                #expect(try decode(APIProblem.Body.self, refused).detail == "This file isn’t a FRUS Explorer collection.")
            }
            var newer = try NativeCollectionSerializer.decode(exported)
            newer.formatVersion = 3
            newer.minimumReaderVersion = 3
            let tooNew = try await Self.importing(owner, try NativeCollectionSerializer.encode(newer))
            #expect(tooNew.status == .unprocessableContent && problemCode(tooNew) == "COLLECTION_FILE_TOO_NEW")
            #expect(try decode(APIProblem.Body.self, tooNew).detail
                == "This collection was made with a newer version of FRUS Explorer (format 3). Update the app to open it.")
            var nul = try NativeCollectionSerializer.decode(exported)
            nul.entries[0].text = "Let\u{0}ters"
            let refusedText = try await Self.importing(owner, try NativeCollectionSerializer.encode(nul))
            #expect(refusedText.status == .badRequest && problemCode(refusedText) == "INVALID_FIELD")
            let plainText = try await owner.send(.post, "\(Self.base)/import", "{}", contentType: "text/plain")
            #expect(plainText.status == .unsupportedMediaType)
            #expect(try decode(CollectionList.self, try await owner.get(Self.base)).total == 2, "a refused file makes nothing")
        }
    }

    /// A smart collection, linked to a saved search from Collection settings, takes its saved search's
    /// results: in the preview, capped, with no volume named as missing; counted for its bar; in each
    /// export, whose history counts them; and a snapshot freezes them as a collection of their documents,
    /// filed under the project worked in, leaving the smart one as it is. A link names a search the user
    /// holds, Unlink takes it away, and a search gone is the kit's sentence.
    @Test func aSmartCollectionResolvesItsSavedSearch() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let search = try await SearchSetTests.saved(owner, "Treaties", "keywords=treaties")
            let treaties = try await CollectionTests.made(owner, "Treaties")
            let path = "\(Self.base)/\(treaties.id)"
            _ = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"generatedBlockType": "bibliography"}"#)
            let stranger = try await owner.send(.patch, path, try CollectionTests.json(["savedSearchId": SearchSetTests.stranger]))
            #expect(stranger.status == .badRequest && problemCode(stranger) == "INVALID_FIELD")
            let linked = try await CollectionTests.detail(owner, .patch, path, try CollectionTests.json(["savedSearchId": search.id.lowercased()]))
            #expect(linked.savedSearchId == search.id && linked.savedSearchName == "Treaties" && !linked.takesHandAddedEntries)
            #expect(linked.volumesNotHeld.isEmpty && linked.documentCount == 0)

            let results = try decode(CollectionExportRoutes.Results.self, try await owner.get("\(path)/results"))
            #expect(results.total == 2 && Set(results.items.map(\.documentId)) == ["d1", "d2"])
            let preview = String(buffer: try await owner.get("\(path)/preview").body)
            #expect(CollectionExportTests.count("<section id=\"doc-", in: preview) == 2 && preview.contains("generated-bibliography"))
            #expect(!preview.contains("citation only"))
            let html = try await CollectionExportTests.export(owner, treaties.id, "html")
            #expect(html.status == .ok && CollectionExportTests.count("<section id=\"doc-", in: String(buffer: html.body)) == 2)
            let ris = String(buffer: try await CollectionExportTests.export(owner, treaties.id, "zoteroJSON").body)
            #expect(CollectionExportTests.count("TY  - ", in: ris) == 2)
            #expect(try decode(HistoryPage.self, try await owner.get("/api/v1/me/history")).exports.map(\.documentCount) == [2, 2])

            let project = try decode(Project.self, try await owner.send(.post, "/api/v1/me/projects", #"{"name": "Berlin crisis"}"#))
            let response = try await owner.send(.post, "\(path)/snapshot")
            #expect(response.status == .created, "\(String(buffer: response.body))")
            let snapshot = try decode(CollectionDetail.self, response)
            #expect(snapshot.name == "Treaties (Snapshot)" && snapshot.savedSearchId == nil && snapshot.takesHandAddedEntries)
            #expect(CollectionTests.outline(snapshot) == ["document:d1@0", "document:d2@0"] && snapshot.projectIds == [project.id])
            #expect(try await CollectionTests.detail(owner, .get, path).savedSearchId == search.id, "the smart one is as it was")
            for route in ["snapshot", "results"] {
                let notSmart = route == "snapshot" ? try await owner.send(.post, "\(Self.base)/\(snapshot.id)/snapshot")
                    : try await owner.get("\(Self.base)/\(snapshot.id)/results")
                #expect(notSmart.status == .conflict && problemCode(notSmart) == "COLLECTION_NOT_SMART", "\(route)")
            }

            _ = try await owner.send(.delete, "/api/v1/me/saved-searches/\(search.id)")
            #expect(try await CollectionTests.detail(owner, .get, path).savedSearchName == nil)
            let gone = try await CollectionExportTests.export(owner, treaties.id, "html")
            #expect(gone.status == .conflict && problemCode(gone) == "SAVED_SEARCH_MISSING")
            #expect(try decode(APIProblem.Body.self, gone).detail == "The linked saved search could not be found. It may have been deleted.")
            #expect(String(buffer: try await owner.get("\(path)/preview").body).contains("The linked saved search could not be found."))
            let unlinked = try await CollectionTests.detail(owner, .patch, path, #"{"savedSearchId": null}"#)
            #expect(unlinked.savedSearchId == nil && unlinked.takesHandAddedEntries && unlinked.projectIds == [project.id])
        }
    }

    /// Remove These Entries takes a smart collection's entries from before its link, with their headnote
    /// drafts, keeping its apparatus, the outline renumbered; nothing for a collection with no link.
    @Test func removeTheseEntriesTakesWhatTheLinkLeavesOut() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let search = try await SearchSetTests.saved(owner, "Treaties", "keywords=treaties")
            let berlin = try await CollectionTests.made(owner, "Berlin")
            let path = "\(Self.base)/\(berlin.id)"
            _ = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#)
            let letters = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1"]))
            _ = try await owner.send(.patch, "\(path)/entries/\(letters.entryIds[0])", #"{"includeHeadnote": true}"#)
            _ = try await CollectionTests.detail(owner, .put, "\(path)/entries/\(letters.entryIds[0])/headnote", #"{"text": "Mine."}"#)
            _ = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"generatedBlockType": "bibliography"}"#)
            let unlinked = try await CollectionTests.detail(owner, .post, "\(path)/entries-from-before-link/remove")
            #expect(unlinked.entries.count == 3, "a collection with no link keeps them all")
            let linked = try await CollectionTests.detail(owner, .patch, path, try CollectionTests.json(["savedSearchId": search.id]))
            #expect(linked.entries.map(\.leftOut) == [true, true, false])
            let removed = try await CollectionTests.detail(owner, .post, "\(path)/entries-from-before-link/remove")
            #expect(removed.entries.map(\.kind) == ["generated"] && removed.entries.map(\.sortOrder) == [0])
            #expect(try fixture.rows.column("SELECT id FROM summaries WHERE is_headnote_draft = 1").isEmpty, "the entry's draft went with it")
        }
    }

    /// While no index is served a smart collection has no search to run, the kit's sentence, 503.
    @Test func aSmartCollectionWaitsForAnIndex() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let treaties = try await CollectionTests.made(owner, "Treaties")
            try fixture.rows.run("UPDATE collections SET saved_search_id = '\(CollectionTests.stranger)' WHERE upper(id) = '\(treaties.id)'")
            for response in [try await CollectionExportTests.export(owner, treaties.id, "html"),
                             try await owner.send(.post, "\(Self.base)/\(treaties.id)/snapshot")] {
                #expect(response.status == .serviceUnavailable && problemCode(response) == "SEARCH_NOT_READY")
                #expect(try decode(APIProblem.Body.self, response).detail == "Search is not ready yet. Try again in a moment.")
            }
        }
    }

    /// Summary only, refused where a document has no summary stored: an export names the documents with
    /// none, with the app's reason; a document's own Summary only is offered only where it has one; and
    /// the inspector says so.
    @Test func summaryOnlyIsRefusedWithTheAppsReason() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        let prompt = "AA000000-0000-4000-8000-000000000001"
        try fixture.rows.addPrompt(prompt, name: "Brief")
        try fixture.rows.addSummary("5A000000-0000-4000-8000-000000000001", promptId: prompt, responseText: "Kennedy writes to Khrushchev.")
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let brief = try await CollectionTests.made(owner, "Brief")
            let path = "\(Self.base)/\(brief.id)"
            let both = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2", "d3", "d4", "d5"]))
            let refused = try await owner.send(.patch, "\(path)/entries/\(both.entryIds[1])", #"{"bodyDepthOverride": "summaryOnly"}"#)
            #expect(refused.status == .conflict && problemCode(refused) == "DEPTH_NOT_OFFERED")
            #expect(try decode(APIProblem.Body.self, refused).detail
                == "Summary only shows this document's summary, and it has none stored. \(SummariesNotStored.appsReason)")
            let offered = try await owner.send(.patch, "\(path)/entries/\(both.entryIds[0])", #"{"bodyDepthOverride": "summaryOnly"}"#)
            #expect(offered.status == .ok, "d1 has one")
            let first = try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(both.entryIds[0])/inspector"))
            let second = try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(both.entryIds[1])/inspector"))
            #expect(first.summaryOnlyOffered == true && second.summaryOnlyOffered == false)

            _ = try await CollectionTests.detail(owner, .patch, path, #"{"defaultBodyDepth": "summaryOnly", "summaryPromptId": "\#(prompt)"}"#)
            let missing = try await CollectionExportTests.export(owner, brief.id, "docx")
            #expect(missing.status == .conflict && problemCode(missing) == "SUMMARY_NOT_STORED")
            let detail = try decode(APIProblem.Body.self, missing).detail
            #expect(detail.hasPrefix("“") && detail.hasSuffix(", and 1 other document have no summary stored for this prompt. \(SummariesNotStored.appsReason)"),
                    "\(detail)")
            #expect(SummariesNotStored.appsReason
                == "Summaries are generated on demand for documents that don’t already have one for this prompt. Requires Apple Intelligence.")
        }
    }

    /// The headnote card shows the summary the headnote takes, with who wrote it, an imported draft's
    /// too; Save writes the researcher's text as a draft of the entry's own in place of the one it named,
    /// AI · edited over the model's, Yours over nothing or their own; nothing for no text or the
    /// summary's own; and the preview shows it.
    @Test func theHeadnoteCardWritesTheResearchersOwn() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addSummary("5A000000-0000-4000-8000-000000000001", responseText: "The model's takeaway.")
        try fixture.rows.addSummary("5A000000-0000-4000-8000-000000000002", documentId: "d3", promptId: CollectionEditing.headnoteDraftPromptId.uuidString,
                                    responseText: "An imported headnote.", authorship: "userWritten", isHeadnoteDraft: true)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let berlin = try await CollectionTests.made(owner, "Berlin")
            let path = "\(Self.base)/\(berlin.id)"
            let made = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2", "d3"]))
            for entry in made.entryIds {
                _ = try await owner.send(.patch, "\(path)/entries/\(entry)", #"{"includeHeadnote": true}"#)
            }
            try fixture.rows.run("UPDATE collection_entries SET headnote_summary_id = '5A000000-0000-4000-8000-000000000002' WHERE upper(id) = ?",
                                 [.text(made.entryIds[2])])
            func card(_ entry: String) async throws -> EntryInspector.Headnote? {
                try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(entry)/inspector")).headnote
            }
            func save(_ entry: String, _ text: String) async throws -> CollectionDetail {
                try await CollectionTests.detail(owner, .put, "\(path)/entries/\(entry)/headnote", try CollectionTests.json(["text": text]))
            }
            func drafts() throws -> [String] {
                try fixture.rows.column("SELECT response_text || ' ' || authorship FROM summaries WHERE is_headnote_draft = 1 ORDER BY response_text")
            }
            #expect(try await card(made.entryIds[0]) == .init(summaryId: "5A000000-0000-4000-8000-000000000001", text: "The model's takeaway.",
                                                               authorship: "aiGenerated", isDraft: false))
            #expect(try await card(made.entryIds[1]) == nil)
            #expect(try await card(made.entryIds[2])?.authorship == "userWritten", "an imported headnote, with its authorship")

            let edited = try await save(made.entryIds[0], "  The model's takeaway, edited.  ")
            let draftId = try #require(edited.entries[0].headnoteSummaryId)
            #expect(try await card(made.entryIds[0]) == .init(summaryId: draftId, text: "The model's takeaway, edited.", authorship: "aiEdited", isDraft: true))
            let again = try await save(made.entryIds[0], "Edited again.")
            #expect(try drafts() == ["An imported headnote. userWritten", "Edited again. aiEdited"], "the draft it named is gone")
            let named = again.entries[0].headnoteSummaryId
            #expect(named != draftId)
            #expect(try await save(made.entryIds[0], "Edited again. ").entries[0].headnoteSummaryId == named, "the summary's own text saves nothing")
            #expect(try await save(made.entryIds[0], "   ").entries[0].headnoteSummaryId == named, "nor does no text")
            #expect(try drafts().count == 2)

            _ = try await save(made.entryIds[1], "Mine alone.")
            #expect(try await card(made.entryIds[1])?.authorship == "userWritten")
            _ = try await save(made.entryIds[2], "Mine over mine.")
            #expect(try await card(made.entryIds[2])?.authorship == "userWritten")
            #expect(try drafts() == ["Edited again. aiEdited", "Mine alone. userWritten", "Mine over mine. userWritten"])
            #expect(try fixture.rows.column("SELECT response_text FROM summaries WHERE is_headnote_draft = 0") == ["The model's takeaway."],
                    "a document's own summary stays")
            #expect(String(buffer: try await owner.get("\(path)/preview").body).contains("Mine alone."))

            let heading = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#)
            let refused = try await owner.send(.put, "\(path)/entries/\(heading.entryIds[0])/headnote", #"{"text": "No."}"#)
            #expect(refused.status == .conflict && problemCode(refused) == "NOT_A_DOCUMENT")
        }
    }
}
