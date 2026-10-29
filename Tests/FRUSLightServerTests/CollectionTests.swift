// Collections and their editor through the API (PLAN's S18d): a collection is made, listed, changed
// and deleted as the app's editor and Collections list do; its sections nest three deep by the kit's
// outline, moved, indented, outdented and deleted as the editors do; documents, note blocks, apparatus
// and frozen excerpts are added as the app adds them; the presets are the kit's recipes, Briefing
// packet offered only where a summary is stored; Sort by Date orders by the index's days; the inspector
// shows and writes what the app's does; a duplicate is the app's copy; the Research rail lists the
// collections holding a document; and each user's collections are theirs alone.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSRichText
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CollectionTests {
    static let volume = UserHalfSearchTests.volume
    static let base = "/api/v1/me/collections"
    static let stranger = "C0110000-0000-4000-8000-0000000000FF"

    static func json(_ object: [String: Any?]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object.mapValues { $0 ?? NSNull() }), as: UTF8.self)
    }

    static func made(_ browser: Browser, _ name: String) async throws -> CollectionDetail {
        let response = try await browser.send(.post, base, try json(["name": name]))
        #expect(response.status == .created, "\(String(buffer: response.body))")
        return try decode(CollectionDetail.self, response)
    }

    static func detail(_ browser: Browser, _ method: HTTPRequest.Method, _ path: String, _ body: String? = nil,
                       sourceLocation: SourceLocation = #_sourceLocation) async throws -> CollectionDetail {
        let response = try await browser.send(method, path, body ?? (method == .post ? "{}" : nil))
        #expect(response.status == .ok, "\(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try decode(CollectionDetail.self, response)
    }

    static func edit(_ browser: Browser, _ path: String, _ body: String,
                     sourceLocation: SourceLocation = #_sourceLocation) async throws -> CollectionEdit {
        let response = try await browser.send(.post, path, body)
        #expect(response.status == .ok, "\(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try decode(CollectionEdit.self, response)
    }

    static func documents(_ ids: [String], volume: String = volume) throws -> String {
        try json(["documents": ids.map { ["volumeId": volume, "documentId": $0] }])
    }

    /// Each entry as `kind:text-or-document@depth`, the outline at a glance.
    static func outline(_ detail: CollectionDetail) -> [String] {
        detail.entries.map { "\($0.kind):\($0.kind == "document" || $0.kind == "excerpt" ? $0.documentId : $0.text ?? $0.generatedBlockType ?? "")@\($0.depth)" }
    }

    static func entryId(_ detail: CollectionDetail, _ text: String) throws -> String {
        try #require(detail.entries.first { $0.text == text || $0.documentId == text }).id
    }

    /// New Collection names it, trimmed and never empty, in the project the user works in; the list
    /// reads the most recently changed first; each field commits as the editor's does, a text trimmed
    /// and none when empty, an edit of the editor's own fields filing the collection under the project
    /// worked in; the footnote switches write the flags and the legacy style that best fits them; and
    /// the Collections list's delete takes the collection.
    @Test func aCollectionIsMadeListedChangedAndDeletedAsTheAppDoes() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let empty = try await owner.send(.post, Self.base, #"{"name": "  "}"#)
            #expect(empty.status == .badRequest && problemCode(empty) == "INVALID_FIELD")
            let berlin = try await Self.made(owner, "  Berlin\n")
            #expect(berlin.name == "Berlin" && berlin.listName == "Berlin" && berlin.projectIds.isEmpty, "Global Context")
            #expect(berlin.entries.isEmpty && berlin.documentCount == 0 && berlin.takesHandAddedEntries)
            #expect(berlin.defaultBodyDepth == "full" && berlin.includeFootnotes && !berlin.includeSourceNote && berlin.includeNotes)
            #expect(berlin.tocStyle == "citation" && !berlin.applyHighlights && !berlin.includeWordCloud && !berlin.defaultIncludeHeadnote)
            #expect(berlin.createdAt == UserStoreDate.text(UserDataFixture.now) && berlin.lastModified == berlin.createdAt)
            #expect(!berlin.summariesAvailable && berlin.bodyDepths == ["full", "index"])
            #expect(berlin.presets.map(\.id) == ["teachingReader", "sourceDossier", "scholarlyEdition"], "Briefing packet only with summaries")

            // In the project the user works in, from creation and from an edit of its own fields.
            let project = try decode(Project.self, try await owner.send(.post, "/api/v1/me/projects", #"{"name": "Cold War"}"#))
            let cuba = try await Self.made(owner, "Cuba")
            #expect(cuba.projectIds == [project.id])
            let list = try decode(CollectionList.self, try await owner.get(Self.base))
            #expect(list.items.map(\.name) == ["Berlin", "Cuba"], "a tie in the store's order")
            let noted = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id.lowercased())",
                                              #"{"note": "  The wall  ", "subtitle": "", "authorLine": " J. Doe "}"#)
            #expect(noted.note == "The wall" && noted.subtitle == nil && noted.authorLine == "J. Doe")
            #expect(noted.projectIds == [project.id], "recordEdit() files it under the project worked in")
            let unnamed = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)", #"{"name": "   "}"#)
            #expect(unnamed.name == "" && unnamed.listName == "Untitled Collection")
            let renamed = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)", #"{"name": "Berlin 1961"}"#)
            #expect(renamed.name == "Berlin 1961")

            // The composition, as its controls write it, and nothing filed by it.
            try fixture.rows.run("UPDATE collections SET project_ids = '[]' WHERE name = 'Berlin 1961'")
            let composed = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)", """
                {"defaultBodyDepth": "index", "includeFootnotes": false, "includeSourceNote": true, "tocStyle": "headerAndDateline",
                 "applyHighlights": true, "includeNotes": false, "includeWordCloud": true, "defaultIncludeHeadnote": true}
                """)
            #expect(composed.defaultBodyDepth == "index" && !composed.includeFootnotes && composed.includeSourceNote)
            #expect(composed.tocStyle == "headerAndDateline" && composed.applyHighlights && !composed.includeNotes)
            #expect(composed.includeWordCloud && composed.defaultIncludeHeadnote && composed.projectIds.isEmpty)
            #expect(try fixture.rows.column("SELECT footnote_style FROM collections WHERE name = 'Berlin 1961'") == ["sourceNoteOnly"],
                    "the legacy style that best fits the flags")
            let both = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)", #"{"includeFootnotes": true}"#)
            #expect(both.includeFootnotes && both.includeSourceNote)
            #expect(try fixture.rows.column("SELECT footnote_style FROM collections WHERE name = 'Berlin 1961'") == ["all"])

            // The front matter's switches commit, and the introduction keeps its formatting as RTF.
            let flagged = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)",
                                                #"{"includeColophon": true, "includeMethodAppendix": true}"#)
            #expect(flagged.includeColophon && flagged.includeMethodAppendix && !flagged.includeProjectProvenance)
            let introduced = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)", """
                {"introductionText": "Read this first.", "introductionRuns": [{"text": "Read this ", "bold": false, "italic": false, "underline": false}, {"text": "first", "bold": true, "italic": false, "underline": false}, {"text": ".", "bold": false, "italic": false, "underline": false}]}
                """)
            #expect(introduced.introductionText == "Read this first." && introduced.introductionRuns?.count == 3)
            #expect(introduced.introductionRuns?[1] == RichTextRun(text: "first", bold: true))
            let blank = try await Self.detail(owner, .patch, "\(Self.base)/\(berlin.id)", #"{"introductionText": "  ", "introductionRuns": null}"#)
            #expect(blank.introductionText == nil && blank.introductionRuns == nil, "an introduction of spaces is none")

            // Refusals.
            for (body, code) in [(#"{"defaultBodyDepth": "most"}"#, "INVALID_FIELD"), (#"{"tocStyle": "list"}"#, "INVALID_FIELD"),
                                 (#"{"summaryPromptId": "\#(Self.stranger)"}"#, "INVALID_FIELD"), (#"{"colour": "red"}"#, "UNKNOWN_FIELD"),
                                 (#"{"introductionText": "Runs?"}"#, "INVALID_FIELD")] {
                let refused = try await owner.send(.patch, "\(Self.base)/\(berlin.id)", body)
                #expect(refused.status == .badRequest && problemCode(refused) == code, "\(body)")
            }
            let missing = try await owner.get("\(Self.base)/\(Self.stranger)")
            #expect(missing.status == .notFound && problemCode(missing) == "COLLECTION_NOT_FOUND")

            // Delete.
            #expect(try await owner.send(.delete, "\(Self.base)/\(cuba.id)").status == .noContent)
            #expect(try await owner.get("\(Self.base)/\(cuba.id)").status == .notFound)
            #expect(try decode(CollectionList.self, try await owner.get(Self.base)).items.map(\.id) == [berlin.id])
        }
    }

    /// Sections nest three deep by the kit's outline: a heading indents one level below the heading
    /// before it, at most to level 3, and outdents to 1; a heading moves with its section, and never
    /// into it; Delete Heading Only leaves its contents and lifts its sub-headings; Delete Section takes
    /// the heading and its section; and every change renumbers the entries in their order.
    @Test func sectionsNestThreeDeepAndMoveAsTheEditorMovesThem() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let made = try await Self.made(owner, "Outline")
            let path = "\(Self.base)/\(made.id)"
            var detail = made
            // Add Section Heading and Add Note Block: an empty block at the end, renumbered.
            for kind in ["heading", "heading", "prose", "heading"] {
                let added = try await Self.edit(owner, "\(path)/blocks", #"{"kind": "\#(kind)"}"#)
                #expect(added.entryIds.count == 1)
                detail = added.collection
            }
            #expect(detail.entries.map(\.text) == ["", "", "", ""] && detail.entries.map(\.sortOrder) == [0, 1, 2, 3])
            for (index, title) in ["Europe", "Berlin", "", "Asia"].enumerated() where !title.isEmpty {
                detail = try await Self.detail(owner, .patch, "\(path)/entries/\(detail.entries[index].id)", try Self.json(["text": title]))
            }
            detail = try await Self.detail(owner, .patch, "\(path)/entries/\(detail.entries[2].id)",
                                           #"{"text": "A note.", "runs": [{"text": "A note.", "bold": false, "italic": true, "underline": false}]}"#)
            #expect(detail.entries[2].runs == [RichTextRun(text: "A note.", italic: true)] && !detail.entries[2].formattingKept)
            let documents = try await Self.edit(owner, "\(path)/documents", try Self.documents(["d1", "d2"]))
            detail = documents.collection
            #expect(Self.outline(detail) == ["heading:Europe@1", "heading:Berlin@1", "prose:A note.@1", "heading:Asia@1",
                                             "document:d1@1", "document:d2@1"])
            #expect(detail.entries[0].canIndent == false, "the first heading never indents")
            #expect(detail.entries[1].canIndent && !detail.entries[1].canOutdent)

            // Berlin under Europe, then a level deeper is refused, as the heading before it is at 1.
            let berlin = try Self.entryId(detail, "Berlin")
            detail = try await Self.detail(owner, .post, "\(path)/entries/\(berlin)/indent")
            #expect(Self.outline(detail)[1] == "heading:Berlin@2" && detail.entries[0].sectionEnd == 3)
            #expect(detail.entries[1].sectionEnd == 3, "Berlin's section ends at Asia, as Europe's does")
            let deeper = try await owner.send(.post, "\(path)/entries/\(berlin)/indent", "{}")
            #expect(deeper.status == .conflict && problemCode(deeper) == "OUTLINE_REFUSED")
            // Asia under Berlin, level 3, the cap.
            let asia = try Self.entryId(detail, "Asia")
            detail = try await Self.detail(owner, .post, "\(path)/entries/\(asia)/indent")
            detail = try await Self.detail(owner, .post, "\(path)/entries/\(asia)/indent")
            #expect(Self.outline(detail) == ["heading:Europe@1", "heading:Berlin@2", "prose:A note.@2", "heading:Asia@3",
                                             "document:d1@3", "document:d2@3"])
            #expect(!detail.entries[3].canIndent, "at the cap")
            #expect(try fixture.rows.column("SELECT CAST(level AS TEXT) FROM collection_entries WHERE kind = 'heading' ORDER BY sort_order") == ["1", "2", "3"])

            // A heading moves with its section: Berlin to the end takes the note, Asia and the documents.
            let refused = try await Self.detail(owner, .post, "\(path)/move", try Self.json(["entryId": berlin, "before": asia]))
            #expect(Self.outline(refused) == Self.outline(detail), "into its own section, nothing")
            detail = try await Self.detail(owner, .post, "\(path)/move", try Self.json(["entryId": try Self.entryId(detail, "d2"),
                                                                                   "before": berlin]))
            #expect(Self.outline(detail) == ["heading:Europe@1", "document:d2@1", "heading:Berlin@2", "prose:A note.@2",
                                             "heading:Asia@3", "document:d1@3"])
            #expect(detail.entries.map(\.sortOrder) == Array(0..<6))

            // Outdent Berlin: its sub-section shifts with it.
            detail = try await Self.detail(owner, .post, "\(path)/entries/\(berlin)/outdent")
            #expect(Self.outline(detail) == ["heading:Europe@1", "document:d2@1", "heading:Berlin@1", "prose:A note.@1",
                                             "heading:Asia@2", "document:d1@2"])
            let top = try await owner.send(.post, "\(path)/entries/\(berlin)/outdent", "{}")
            #expect(top.status == .conflict && problemCode(top) == "OUTLINE_REFUSED")

            // Delete Heading Only: Asia's document stays, under Berlin.
            detail = try await Self.detail(owner, .delete, "\(path)/entries/\(asia)")
            #expect(Self.outline(detail) == ["heading:Europe@1", "document:d2@1", "heading:Berlin@1", "prose:A note.@1", "document:d1@1"])
            // Delete Section: Berlin and everything in it.
            detail = try await Self.detail(owner, .post, "\(path)/entries/\(berlin)/delete-section")
            #expect(Self.outline(detail) == ["heading:Europe@1", "document:d2@1"] && detail.entries.map(\.sortOrder) == [0, 1])
            let notHeading = try await owner.send(.post, "\(path)/entries/\(detail.entries[1].id)/delete-section", "{}")
            #expect(notHeading.status == .conflict && problemCode(notHeading) == "NOT_A_HEADING")
            // Each kind takes its own fields alone.
            let title = try await owner.send(.patch, "\(path)/entries/\(detail.entries[0].id)", #"{"titleOverride": "No"}"#)
            #expect(title.status == .badRequest && problemCode(title) == "INVALID_FIELD")
            let missing = try await owner.send(.delete, "\(path)/entries/\(Self.stranger)")
            #expect(missing.status == .notFound && problemCode(missing) == "ENTRY_NOT_FOUND")
        }
    }

    /// Add Documents adds a document the collection holds again, badged; the picker's add takes it once,
    /// an excerpt of it not counting; the reader's Excerpt freezes the page's own text between the
    /// selection's offsets, refused when the page has changed; highlights' excerpts take their passages,
    /// colours and anchors; the apparatus goes where its type goes; and a smart collection takes none
    /// of the hand-added kinds, but its apparatus.
    @Test func documentsExcerptsAndApparatusAreAddedAsTheAppAddsThem() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        let (_, flat) = try await HighlightTests.page(fixture)
        let phrase = "Allow me to congratulate you on the occasion of your election"
        let (start, end) = try HighlightTests.offsets(of: phrase, in: flat)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let made = try await Self.made(owner, "Sources")
            let path = "\(Self.base)/\(made.id)"
            let twice = try await Self.edit(owner, "\(path)/documents", try Self.documents(["d1", "d1"]))
            #expect(twice.entryIds.count == 2 && twice.collection.entries.allSatisfy(\.isDuplicate) && twice.collection.documentCount == 2)
            #expect(twice.collection.entries.map(\.sortOrder) == [0, 1])
            #expect(twice.collection.entries[0].volumeTitle?.isEmpty == false, "the volume's title from the manifest")

            // The picker's add: a document it holds is not added again.
            let held = try decode(CollectionAddResult.self, try await owner.send(.post, "\(path)/document",
                                                                                 #"{"volumeId": "\#(Self.volume)", "documentId": "d1"}"#))
            #expect(!held.added && held.collection.documentCount == 2)

            // The reader's Excerpt, the page's text between the offsets, block-aware, with its version.
            let version = try await HighlightTests.pageVersion(owner)
            let other = try await HighlightTests.page(fixture, Self.volume, "d2")
            let passage2 = try #require(flatTextExcerpt(from: other.model, start: 0, end: 40))
            let version2 = try await HighlightTests.pageVersion(owner, Self.volume, "d2")
            let excerpt = try await Self.edit(owner, "\(path)/excerpts", try Self.json([
                "volumeId": Self.volume, "documentId": "d2", "startOffset": 0, "endOffset": 40, "renderingVersion": version2,
            ]))
            let frozen = try #require(excerpt.collection.entries.last)
            #expect(excerpt.entryIds == [frozen.id] && frozen.kind == "excerpt" && frozen.documentId == "d2")
            #expect(frozen.text == passage2 && frozen.excerptStart == 0 && frozen.excerptEnd == 40)
            #expect(frozen.excerptRenderingVersion == version2 && frozen.excerptColorTag == nil && frozen.sortOrder == 2)
            let stale = try await owner.send(.post, "\(path)/excerpts", try Self.json([
                "volumeId": Self.volume, "documentId": "d1", "startOffset": start, "endOffset": end, "renderingVersion": "0000000000000000",
            ]))
            #expect(stale.status == .conflict && problemCode(stale) == "DOCUMENT_CHANGED")
            // The picker counts documents, not excerpts: d2's excerpt does not hold d2.
            let added = try decode(CollectionAddResult.self, try await owner.send(.post, "\(path)/document",
                                                                                  #"{"volumeId": "\#(Self.volume)", "documentId": "d2"}"#))
            #expect(added.added && added.collection.documentCount == 3)

            // Highlights' excerpts, as `CollectionExcerpts.capture(from:)` takes them.
            let highlight = try decode(Highlight.self, try await owner.send(.post, HighlightTests.d1,
                                                                            HighlightTests.body(start, end, "green", version)))
            let passage = try await Self.edit(owner, "\(path)/excerpts", try Self.json(["highlightIds": [highlight.id.lowercased()]]))
            let fromHighlight = try #require(passage.collection.entries.last)
            #expect(fromHighlight.text == phrase && fromHighlight.excerptColorTag == "green" && fromHighlight.documentId == "d1")
            #expect(fromHighlight.excerptStart == start && fromHighlight.excerptRenderingVersion == version)
            try fixture.rows.addHighlight("B0000000-0000-0000-0000-000000000000", renderingVersion: version, createdAt: nil)
            let wordless = try await owner.send(.post, "\(path)/excerpts", #"{"highlightIds": ["B0000000-0000-0000-0000-000000000000"]}"#)
            #expect(wordless.status == .conflict && problemCode(wordless) == "HIGHLIGHT_HAS_NO_PASSAGE")

            // The apparatus: a chronology opens the collection, a bibliography closes it.
            let chronology = try await Self.edit(owner, "\(path)/blocks", #"{"generatedBlockType": "chronology"}"#)
            #expect(chronology.collection.entries.first?.generatedBlockType == "chronology")
            let bibliography = try await Self.edit(owner, "\(path)/blocks", #"{"generatedBlockType": "bibliography"}"#)
            #expect(bibliography.collection.entries.last?.generatedBlockType == "bibliography")
            #expect(bibliography.collection.entries.map(\.sortOrder) == Array(0..<bibliography.collection.entries.count))
            let unknown = try await owner.send(.post, "\(path)/blocks", #"{"generatedBlockType": "index"}"#)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "INVALID_FIELD")

            // A smart collection takes no document, block or passage by hand, and keeps its apparatus.
            try fixture.rows.run("UPDATE collections SET saved_search_id = '\(Self.stranger)'")
            for (route, body) in [("documents", try Self.documents(["d2"])), ("document", #"{"volumeId": "\#(Self.volume)", "documentId": "d2"}"#),
                                  ("blocks", #"{"kind": "heading"}"#), ("excerpts", #"{"highlightIds": ["\#(highlight.id)"]}"#)] {
                let refused = try await owner.send(.post, "\(path)/\(route)", body)
                #expect(refused.status == .conflict && problemCode(refused) == "COLLECTION_IS_SMART", "\(route)")
            }
            let smart = try await Self.edit(owner, "\(path)/blocks", #"{"generatedBlockType": "personsIndex"}"#)
            #expect(!smart.collection.takesHandAddedEntries && smart.entryIds.count == 1)
            #expect(smart.collection.entries.filter(\.leftOut).map(\.kind) == ["document", "document", "excerpt", "document", "excerpt"])
            #expect(try decode(CollectionList.self, try await owner.get(Self.base)).items.first?.isSmart == true)
        }
    }

    /// A preset writes its recipe's fields and adds the apparatus it calls for that the collection does
    /// not carry, at each type's place; Briefing packet, and Summary only, are offered once a document of
    /// the collection has a summary stored; and Sort by Date orders the documents by the index's days,
    /// across the collection or within each section, every other entry staying put.
    @Test func presetsAndSortByDateAreTheAppsOverTheIndex() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let made = try await Self.made(owner, "Reader")
            let path = "\(Self.base)/\(made.id)"
            _ = try await Self.edit(owner, "\(path)/documents", try Self.documents(["d2", "d1"]))
            let teaching = try await Self.detail(owner, .post, "\(path)/preset", #"{"preset": "teachingReader"}"#)
            #expect(teaching.defaultBodyDepth == "full" && !teaching.includeFootnotes && teaching.includeSourceNote)
            #expect(teaching.includeNotes && teaching.tocStyle == "headerAndDateline")
            #expect(teaching.presets.first { $0.id == "teachingReader" }?.active == true)
            #expect(Self.outline(teaching) == ["generated:chronology@0", "document:d2@0", "document:d1@0", "generated:personsIndex@0"])
            let again = try await Self.detail(owner, .post, "\(path)/preset", #"{"preset": "scholarlyEdition"}"#)
            #expect(Self.outline(again) == ["generated:chronology@0", "document:d2@0", "document:d1@0", "generated:personsIndex@0",
                                            "generated:bibliography@0", "generated:archivalSources@0", "generated:thematicIndex@0"],
                    "only the blocks it does not carry")
            #expect(again.presets.first { $0.id == "teachingReader" }?.active == false)
            let briefing = try await owner.send(.post, "\(path)/preset", #"{"preset": "briefingPacket"}"#)
            #expect(briefing.status == .conflict && problemCode(briefing) == "PRESET_NOT_OFFERED")

            // A summary of one of its documents offers both.
            try fixture.rows.addSummary("5A000000-0000-4000-8000-000000000001", documentId: "d1", responseText: "A summary.")
            let summarized = try decode(CollectionDetail.self, try await owner.get(path))
            #expect(summarized.summariesAvailable && summarized.bodyDepths == ["full", "summaryOnly", "index"])
            #expect(summarized.presets.map(\.id) == ["teachingReader", "briefingPacket", "sourceDossier", "scholarlyEdition"])
            let packet = try await Self.detail(owner, .post, "\(path)/preset", #"{"preset": "briefingPacket"}"#)
            #expect(packet.defaultBodyDepth == "summaryOnly" && packet.defaultIncludeHeadnote && !packet.includeNotes)

            // Sort by Date: d1 (9 November 1960) before d2 (10 November), the apparatus where it was.
            let sorted = try await Self.detail(owner, .post, "\(path)/sort", #"{"scope": "wholeCollection"}"#)
            #expect(Self.outline(sorted).prefix(3) == ["generated:chronology@0", "document:d1@0", "document:d2@0"])
            #expect(sorted.entries[1].dateISO == "1960-11-09" && sorted.entries[2].dateISO == "1960-11-10")
            // Within sections: a heading between them keeps each in its run.
            var detail = try await Self.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#).collection
            detail = try await Self.detail(owner, .post, "\(path)/move", try Self.json(["entryId": detail.entries.last!.id,
                                                                                   "before": try Self.entryId(sorted, "d2")]))
            detail = try await Self.detail(owner, .post, "\(path)/move", try Self.json(["entryId": try Self.entryId(detail, "d1"),
                                                                                   "before": nil]))
            #expect(Self.outline(detail).filter { !$0.hasPrefix("generated") } == ["heading:@1", "document:d2@1", "document:d1@1"])
            let within = try await Self.detail(owner, .post, "\(path)/sort", #"{"scope": "withinSections"}"#)
            #expect(Self.outline(within).filter { !$0.hasPrefix("generated") } == ["heading:@1", "document:d1@1", "document:d2@1"])
            let refused = try await owner.send(.post, "\(path)/sort", #"{"scope": "byTitle"}"#)
            #expect(refused.status == .badRequest && problemCode(refused) == "INVALID_FIELD")
        }
    }

    /// The inspector shows a document's notes and highlights with what the entry includes, and writes
    /// an inclusion as the app's does: deselecting one stores the rest, selecting all is the empty set
    /// again, and deselecting the last turns the override off; each override shows what it resolves to
    /// at Default, a section's default first; and a section heading's inspector is its defaults.
    @Test func theInspectorShowsAndWritesWhatTheAppsDoes() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let notes = ["A0000000-0000-4000-8000-000000000001", "A0000000-0000-4000-8000-000000000002"]
        let long = "  The first note, which runs on well past sixty characters before it stops"
        try fixture.rows.addNote(notes[0], bodyText: long, lastModified: "2026-10-01T00:00:00.000Z")
        try fixture.rows.addNote(notes[1], bodyText: "   ", lastModified: "2026-10-02T00:00:00.000Z")
        let highlights = ["B0000000-0000-4000-8000-000000000001", "B0000000-0000-4000-8000-000000000002"]
        try fixture.rows.addHighlight(highlights[0], renderingVersion: "", createdAt: "2026-10-01T00:00:00.000Z")
        try fixture.rows.addHighlight(highlights[1], renderingVersion: "", createdAt: "2026-10-02T00:00:00.000Z")
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let made = try await Self.made(owner, "Inspected")
            let path = "\(Self.base)/\(made.id)"
            var detail = try await Self.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#).collection
            detail = try await Self.edit(owner, "\(path)/documents", try Self.documents(["d1"])).collection
            let heading = detail.entries[0].id
            let document = detail.entries[1].id
            #expect(detail.entries[1].noteCount == 2 && detail.entries[1].header == "1. Telegram From the Embassy in the Soviet Union")

            var inspector = try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(document)/inspector"))
            #expect(inspector.kind == "document" && inspector.notes.map(\.id) == [notes[1], notes[0]], "the last changed first")
            #expect(inspector.notes.map(\.preview) == ["Untitled Note", long.prefix(60).trimmingCharacters(in: .whitespaces)],
                    "the first 60 characters, trimmed")
            #expect(inspector.notes.allSatisfy(\.included) && inspector.highlights.map(\.id) == highlights)
            #expect(inspector.resolved?.highlights == false && inspector.resolved?.notes == true && inspector.resolved?.bodyDepth == "full")
            #expect(inspector.derivedTitle?.isEmpty == false && inspector.excerpts.isEmpty)
            let section = try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(heading)/inspector"))
            #expect(section.kind == "heading" && section.sectionTitle == "Untitled section" && section.resolved == nil)

            // A section default, which the document's Default resolves to.
            _ = try await Self.detail(owner, .patch, "\(path)/entries/\(heading)", #"{"applyHighlightsOverride": true, "bodyDepthOverride": "index"}"#)
            inspector = try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(document)/inspector"))
            #expect(inspector.resolved?.highlights == true && inspector.resolved?.bodyDepth == "index")

            // Inclusions, as `setHighlightIncluded` and `setNoteIncluded` write them.
            detail = try await Self.detail(owner, .patch, "\(path)/entries/\(document)", #"{"highlight": {"id": "\#(highlights[0])", "included": false}}"#)
            #expect(detail.entries[1].selectedHighlightIds == [highlights[1]])
            detail = try await Self.detail(owner, .patch, "\(path)/entries/\(document)", #"{"highlight": {"id": "\#(highlights[0])", "included": true}}"#)
            #expect(detail.entries[1].selectedHighlightIds.isEmpty && detail.entries[1].applyHighlightsOverride == nil, "all is the empty set")
            for id in highlights {
                detail = try await Self.detail(owner, .patch, "\(path)/entries/\(document)", #"{"highlight": {"id": "\#(id)", "included": false}}"#)
            }
            #expect(detail.entries[1].selectedHighlightIds.isEmpty && detail.entries[1].applyHighlightsOverride == false,
                    "none is highlights turned off")
            detail = try await Self.detail(owner, .patch, "\(path)/entries/\(document)", #"{"note": {"id": "\#(notes[1])", "included": false}}"#)
            #expect(detail.entries[1].selectedNoteIds == [notes[0]])
            inspector = try decode(EntryInspector.self, try await owner.get("\(path)/entries/\(document)/inspector"))
            #expect(inspector.notes.map(\.included) == [false, true])
            let foreign = try await owner.send(.patch, "\(path)/entries/\(document)", #"{"note": {"id": "\#(Self.stranger)", "included": false}}"#)
            #expect(foreign.status == .badRequest && problemCode(foreign) == "INVALID_FIELD")

            // Overrides and the title override, Default as null, an emptied title none.
            detail = try await Self.detail(owner, .patch, "\(path)/entries/\(document)", """
                {"titleOverride": "The telegram", "includeHeadnote": true, "includeRelatedDocuments": true, "bodyDepthOverride": "full"}
                """)
            #expect(detail.entries[1].titleOverride == "The telegram" && detail.entries[1].includeHeadnote == true)
            #expect(detail.entries[1].includeRelatedDocuments == true && detail.entries[1].bodyDepthOverride == "full")
            detail = try await Self.detail(owner, .patch, "\(path)/entries/\(document)",
                                           #"{"titleOverride": "", "includeHeadnote": null, "bodyDepthOverride": null}"#)
            #expect(detail.entries[1].titleOverride == nil && detail.entries[1].includeHeadnote == nil && detail.entries[1].bodyDepthOverride == nil)
            let summaryOnly = try await owner.send(.patch, "\(path)/entries/\(document)", #"{"bodyDepthOverride": "abstract"}"#)
            #expect(summaryOnly.status == .badRequest && problemCode(summaryOnly) == "INVALID_FIELD")
            let headnoteOnHeading = try await owner.send(.patch, "\(path)/entries/\(heading)", #"{"includeHeadnote": true}"#)
            #expect(headnoteOnHeading.status == .badRequest, "a section has no headnote default")
        }
    }

    /// The list's Duplicate is the app's copy: "copy" after the name, every entry and field copied under
    /// new ids, each entry's headnote draft copied for it and a document's own summary left shared, and
    /// the two export stamps left at their defaults.
    @Test func aDuplicateIsTheAppsCopy() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let made = try await Self.made(owner, "Original")
            let path = "\(Self.base)/\(made.id)"
            _ = try await Self.detail(owner, .patch, path, #"{"subtitle": "A reader", "includeProjectProvenance": true, "includeColophon": true, "tocStyle": "headerAndDateline"}"#)
            let detail = try await Self.edit(owner, "\(path)/documents", try Self.documents(["d1", "d2"])).collection
            let draft = "D2AF0000-0000-4000-8000-000000000001"
            try fixture.rows.addSummary(draft, documentId: "d1", responseText: "A draft.", isHeadnoteDraft: true)
            try fixture.rows.run("UPDATE collection_entries SET headnote_summary_id = '\(draft)', include_headnote = 1 WHERE id = '\(detail.entries[0].id)'")

            let response = try await owner.send(.post, "\(path)/duplicate", "{}")
            #expect(response.status == .created)
            let copy = try decode(CollectionDetail.self, response)
            #expect(copy.name == "Original copy" && copy.id != made.id && copy.subtitle == "A reader")
            #expect(copy.includeColophon && !copy.includeProjectProvenance && copy.tocStyle == "headerAndDateline")
            #expect(copy.entries.map(\.documentId) == ["d1", "d2"] && Set(copy.entries.map(\.id)).isDisjoint(with: detail.entries.map(\.id)))
            let copiedDraft = try #require(copy.entries[0].headnoteSummaryId)
            #expect(copiedDraft != draft && copy.entries[0].includeHeadnote == true)
            #expect(try fixture.rows.column("SELECT response_text FROM summaries WHERE is_headnote_draft = 1 ORDER BY id") .count == 2)
            // Deleting the original takes its draft, and leaves the copy's.
            #expect(try await owner.send(.delete, path).status == .noContent)
            #expect(try fixture.rows.column("SELECT id FROM summaries WHERE is_headnote_draft = 1") == [copiedDraft])

            // An unnamed collection's copy is "Untitled Collection copy".
            _ = try await Self.detail(owner, .patch, "\(Self.base)/\(copy.id)", #"{"name": ""}"#)
            let untitled = try decode(CollectionDetail.self, try await owner.send(.post, "\(Self.base)/\(copy.id)/duplicate", "{}"))
            #expect(untitled.name == "Untitled Collection copy")
        }
    }

    /// The Research rail lists the collections that hold a document among their documents, by the name
    /// each row prints; and two users' collections stay apart, live behind the proxy.
    @Test func theRailListsADocumentsCollectionsAndEachUsersAreTheirsAlone() async throws {
        let fixture = try await UserDataFixture(auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let zebra = try await Self.made(alice, "zebra")
            let apple = try await Self.made(alice, "Apple")
            let untitled = try await Self.made(alice, "Later")
            _ = try await Self.detail(alice, .patch, "\(Self.base)/\(untitled.id)", #"{"name": ""}"#)
            for collection in [zebra, apple, untitled] {
                _ = try await Self.edit(alice, "\(Self.base)/\(collection.id)/documents", try Self.documents(["d1"]))
            }
            let rail = try decode(DocumentCollections.self, try await alice.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/collections"))
            #expect(rail.items.map(\.listName) == ["Apple", "Untitled Collection", "zebra"], "by the name each row prints, case aside")
            #expect(try decode(DocumentCollections.self, try await bob.get("/api/v1/me/volumes/\(Self.volume)/documents/d1/collections")).items.isEmpty)
            #expect(try decode(CollectionList.self, try await bob.get(Self.base)).total == 0)
            for (method, path) in [(HTTPRequest.Method.get, "\(Self.base)/\(zebra.id)"), (.patch, "\(Self.base)/\(zebra.id)"),
                                   (.delete, "\(Self.base)/\(zebra.id)"), (.post, "\(Self.base)/\(zebra.id)/duplicate"),
                                   (.post, "\(Self.base)/\(zebra.id)/blocks")] {
                let body: String? = switch method {
                case .patch: #"{"name": "Mine"}"#
                case .post: path.hasSuffix("blocks") ? #"{"kind": "heading"}"# : "{}"
                default: nil
                }
                let response = method == .get ? try await bob.get(path) : try await bob.send(method, path, body)
                #expect(response.status == .notFound && problemCode(response) == "COLLECTION_NOT_FOUND", "\(method) \(path)")
            }
            #expect(try decode(CollectionDetail.self, try await alice.get("\(Self.base)/\(zebra.id)")).name == "zebra")
        }
    }
}
