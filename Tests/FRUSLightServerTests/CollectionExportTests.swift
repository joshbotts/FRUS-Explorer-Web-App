// A collection's live preview, its exports and the quotation check through the API (PLAN's S18e): the
// preview is the HTML export's page for the editor's sandboxed frame, the first 20 documents until
// Render All, a volume the server's folder lacks as its citation card; each export is the file the
// app's sheet writes, named as it names it, and kept in the history while Log Research Sessions is on;
// Summary only takes the summaries stored and refuses the rest; the check warns and never blocks; a
// smart collection waits for S18f; and each user's collections are theirs alone. That each file is
// the kit's to the byte is FRUSParityTests' CollectionExportParityTests, over the kit's own index.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CollectionExportTests {
    static let volume = CollectionTests.volume
    static let base = CollectionTests.base

    static func export(_ browser: Browser, _ id: String, _ format: String, timeZone: String? = nil) async throws -> TestResponse {
        try await browser.send(.post, "\(base)/\(id)/export", try CollectionTests.json(["format": format, "timeZone": timeZone]))
    }

    static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// The preview is the HTML export's page for the frame: the kit's page, each document a section, one
    /// of a volume the folder lacks its citation card, under a policy that lets it load nothing, run
    /// nothing and be framed only by the app; the detail names that volume for the editor's bar. It
    /// shows the first 20 documents and every apparatus block until Render All; and what goes wrong is
    /// a page too, in the app's words.
    @Test func thePreviewIsTheHTMLExportsPageForTheEditorsFrame() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let berlin = try await CollectionTests.made(owner, "Berlin")
            let path = "\(Self.base)/\(berlin.id)"
            _ = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2"]))
            let added = try await CollectionTests.edit(owner, "\(path)/documents",
                                                       try CollectionTests.documents(["d1"], volume: "frus1894Nicaragua"))
            #expect(added.collection.volumesNotHeld == ["frus1894Nicaragua"], "the folder holds frus1961-63v06 alone")

            let preview = try await owner.get("\(path)/preview?timeZone=America/New_York")
            #expect(preview.status == .ok && preview.headers[.contentType] == "text/html; charset=utf-8")
            #expect(preview.headers[.contentSecurityPolicy] == CollectionExportRoutes.previewPolicy)
            #expect(preview.headers[.cacheControl] == "no-store" && preview.headers[.xContentTypeOptions] == "nosniff")
            let page = String(buffer: preview.body)
            #expect(page.hasPrefix("<!DOCTYPE html>") && page.contains("<title>Berlin</title>"))
            #expect(Self.count("<section id=\"doc-", in: page) == 3)
            #expect(Self.count("Volume not downloaded — citation only", in: page) == 1, "Nicaragua's d1, whose TEI is not mounted")
            #expect(page.contains("id=\"doc-frus1961-63v06-d1\"") && page.contains("Allow me to congratulate you"), "d1 parsed from the folder")

            // The first 20 documents and every apparatus block, until Render All.
            let many = try await CollectionTests.made(owner, "Many")
            _ = try await CollectionTests.edit(owner, "\(Self.base)/\(many.id)/documents",
                                               try CollectionTests.documents((1...22).map { "d\($0)" }))
            _ = try await CollectionTests.edit(owner, "\(Self.base)/\(many.id)/blocks", #"{"generatedBlockType": "bibliography"}"#)
            let capped = String(buffer: try await owner.get("\(Self.base)/\(many.id)/preview").body)
            #expect(Self.count("<section id=\"doc-", in: capped) == 20 && capped.contains("generated-block generated-bibliography"))
            #expect(capped.contains("id=\"doc-frus1961-63v06-d20\"") && !capped.contains("id=\"doc-frus1961-63v06-d21\""))
            let all = String(buffer: try await owner.get("\(Self.base)/\(many.id)/preview?renderAll=true").body)
            #expect(Self.count("<section id=\"doc-", in: all) == 22 && all.contains("generated-bibliography"))
            // The bibliography lists the whole collection, capped or not.
            #expect(capped.contains("Document 22"), "d22's section is past the cap, so its words are the bibliography's")

            // What goes wrong, in the frame: the app's Preview Unavailable over the problem's words.
            for (address, status, words) in [
                ("\(Self.base)/\(CollectionTests.stranger)/preview", HTTPResponse.Status.notFound, "You have no collection"),
                ("\(path)/preview?zoom=2", .badRequest, "zoom"),
                ("\(path)/preview?timeZone=Mars/Olympus", .badRequest, "not a time zone"),
            ] {
                let refused = try await owner.get(address)
                let text = String(buffer: refused.body)
                #expect(refused.status == status && refused.headers[.contentType] == "text/html; charset=utf-8", "\(address)")
                #expect(text.contains("<h1>Preview Unavailable</h1>") && text.contains(words), "\(address): \(text)")
            }
            try fixture.rows.run("UPDATE collections SET saved_search_id = '\(CollectionTests.stranger)' WHERE upper(id) = '\(berlin.id)'")
            let smart = try await owner.get("\(path)/preview")
            #expect(smart.status == .conflict && String(buffer: smart.body).contains("This is a smart collection."))
        }
    }

    /// Each format is the file the app's sheet writes, under the name its exporter gives it, in ASCII
    /// and whole; a format this server does not export, an empty collection, a smart one and a zone it
    /// does not know are refused; and RIS of no documents is the sheet's refusal, as BibTeX of none is
    /// an empty file.
    @Test func eachExportIsTheSheetsFileNamedAsItsExporterNamesIt() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let owner = Browser(client: client)
            let cafe = try await CollectionTests.made(owner, "Café / Berlin")
            _ = try await CollectionTests.edit(owner, "\(Self.base)/\(cafe.id)/documents", try CollectionTests.documents(["d1", "d2"]))
            for (format, type, suffix) in [("html", "text/html; charset=utf-8", ".html"),
                                           ("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".docx"),
                                           ("bibtex", "application/x-bibtex; charset=utf-8", ".bib"),
                                           ("zoteroJSON", "application/x-research-info-systems; charset=utf-8", "-zotero.ris")] {
                let response = try await Self.export(owner, cafe.id, format, timeZone: "Europe/London")
                #expect(response.status == .ok && response.headers[.contentType] == type, "\(format)")
                #expect(response.headers[.contentDisposition]
                    == "attachment; filename=\"Caf_ - Berlin\(suffix)\"; filename*=UTF-8''Caf%C3%A9%20-%20Berlin\(suffix)", "\(format)")
                #expect(response.headers[.cacheControl] == "no-store", "\(format)")
                let bytes = Data(buffer: response.body)
                switch format {
                case "html":
                    let page = String(decoding: bytes, as: UTF8.self)
                    #expect(page.hasPrefix("<!DOCTYPE html>") && page.contains("<title>Café / Berlin</title>"))
                    #expect(Self.count("<section id=\"doc-", in: page) == 2 && !page.contains("citation-card"), "no preview card in an export")
                case "docx":
                    #expect(bytes.starts(with: [0x50, 0x4B, 0x03, 0x04]), "a ZIP package")
                case "bibtex":
                    let text = String(decoding: bytes, as: UTF8.self)
                    #expect(text.hasPrefix("@incollection{frus1961-63v06_d1,") && text.contains("@incollection{frus1961-63v06_d2,"))
                default:
                    let text = String(decoding: bytes, as: UTF8.self)
                    #expect(Self.count("TY  - CHAP", in: text) == 2)
                }
            }

            for format in ["pdf", "fruscollection", "HTML"] {
                let refused = try await Self.export(owner, cafe.id, format)
                #expect(refused.status == .badRequest && problemCode(refused) == "INVALID_FIELD", "\(format)")
            }
            let zone = try await Self.export(owner, cafe.id, "html", timeZone: "Mars/Olympus")
            #expect(zone.status == .badRequest && problemCode(zone) == "INVALID_FIELD")
            let unknown = try await owner.send(.post, "\(Self.base)/\(cafe.id)/export", #"{"format": "html", "pages": 2}"#)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_FIELD")
            let gone = try await Self.export(owner, CollectionTests.stranger, "html")
            #expect(gone.status == .notFound && problemCode(gone) == "COLLECTION_NOT_FOUND")

            let empty = try await CollectionTests.made(owner, "Empty")
            let nothing = try await Self.export(owner, empty.id, "html")
            #expect(nothing.status == .conflict && problemCode(nothing) == "COLLECTION_EMPTY")
            _ = try await CollectionTests.edit(owner, "\(Self.base)/\(empty.id)/blocks", #"{"kind": "heading"}"#)
            let ris = try await Self.export(owner, empty.id, "zoteroJSON")
            #expect(ris.status == .conflict && problemCode(ris) == "NOTHING_TO_EXPORT")
            #expect(try decode(APIProblem.Body.self, ris).detail == "This collection has no documents to send.")
            let bib = try await Self.export(owner, empty.id, "bibtex")
            #expect(bib.status == .ok && bib.body.readableBytes == 0 && bib.headers[.contentDisposition]?.contains("Empty.bib") == true)

            try fixture.rows.run("UPDATE collections SET saved_search_id = '\(CollectionTests.stranger)' WHERE upper(id) = '\(cafe.id)'")
            let smart = try await Self.export(owner, cafe.id, "html")
            #expect(smart.status == .conflict && problemCode(smart) == "SMART_COLLECTION_NOT_RESOLVED")
        }
    }

    /// Each export is kept in the history as `ExportHistoryRecorder` keeps it: the format's raw value,
    /// the documents that went out, the name trimmed or none, the project the user works in; RIS as
    /// the app's Zotero file; and none while Log Research Sessions is off, nor for a refused export.
    @Test func eachExportIsKeptInTheHistoryAsTheAppKeepsIt() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let project = try decode(Project.self, try await owner.send(.post, "/api/v1/me/projects", #"{"name": "Berlin crisis"}"#))
            let briefing = try await CollectionTests.made(owner, "Briefing")
            let path = "\(Self.base)/\(briefing.id)"
            _ = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2"]))
            _ = try await CollectionTests.edit(owner, "\(path)/blocks", #"{"kind": "heading"}"#)
            #expect(try await Self.export(owner, briefing.id, "docx").status == .ok)
            #expect(try await Self.export(owner, briefing.id, "zoteroJSON").status == .ok)
            _ = try await CollectionTests.detail(owner, .patch, path, #"{"name": ""}"#)
            #expect(try await Self.export(owner, briefing.id, "html").status == .ok)

            let history = try decode(HistoryPage.self, try await owner.get("/api/v1/me/history"))
            #expect(history.exports.map(\.format) == ["html", "zoteroJSON", "docx"])
            #expect(history.exports.map(\.formatName) == ["HTML", "Zotero RIS (desktop)", "DOCX"])
            #expect(history.exports.map(\.documentCount) == [2, 2, 2])
            #expect(history.exports.map(\.collectionName) == [nil, "Briefing", "Briefing"], "an unnamed collection's export names none")
            #expect(history.exports.allSatisfy { $0.projectId == project.id && $0.exportedAt == UserStoreDate.text(UserDataFixture.now) })

            _ = try await owner.send(.patch, "/api/v1/me/preferences", #"{"researchLoggingEnabled": false}"#)
            #expect(try await Self.export(owner, briefing.id, "bibtex").status == .ok)
            let refused = try await Self.export(owner, briefing.id, "pdf")
            #expect(refused.status == .badRequest)
            _ = try await owner.send(.patch, "/api/v1/me/preferences", #"{"researchLoggingEnabled": true}"#)
            #expect(try decode(HistoryPage.self, try await owner.get("/api/v1/me/history")).totalExports == 3)
        }
    }

    /// Summary only takes each document's stored summary under the collection's prompt, with the kit's
    /// attribution; a document with none fails the export as the app's does where it cannot write one,
    /// and shows the kit's placeholder in the preview; and with no prompt it is the kit's refusal.
    @Test func summaryOnlyTakesTheSummariesStoredAndRefusesTheRest() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(fixture) {} }
        let prompt = "AA000000-0000-4000-8000-000000000001"
        try fixture.rows.addPrompt(prompt, name: "Brief")
        try fixture.rows.addSummary("5A000000-0000-4000-8000-000000000001", promptId: prompt, responseText: "Kennedy writes to Khrushchev.")
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let brief = try await CollectionTests.made(owner, "Brief")
            let path = "\(Self.base)/\(brief.id)"
            let both = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1", "d2"]))
            _ = try await CollectionTests.detail(owner, .patch, path, #"{"defaultBodyDepth": "summaryOnly"}"#)
            let missing = try await Self.export(owner, brief.id, "html")
            #expect(missing.status == .conflict && problemCode(missing) == "SUMMARY_PROMPT_MISSING")
            #expect(try decode(APIProblem.Body.self, missing).detail
                == "Choose a summarization prompt in the collection’s Composition section to export summaries.")

            _ = try await CollectionTests.detail(owner, .patch, path, #"{"summaryPromptId": "\#(prompt)"}"#)
            let unwritten = try await Self.export(owner, brief.id, "docx")
            #expect(unwritten.status == .conflict && problemCode(unwritten) == "EXPORT_NOT_RENDERED")
            #expect(try decode(APIProblem.Body.self, unwritten).detail == "The export could not be rendered.")
            let preview = String(buffer: try await owner.get("\(path)/preview").body)
            #expect(preview.contains("Kennedy writes to Khrushchev.") && preview.contains("Summary will be generated at export"))

            _ = try await owner.send(.delete, "\(path)/entries/\(both.entryIds[1])")
            let page = String(buffer: try await Self.export(owner, brief.id, "html").body)
            #expect(page.contains("Kennedy writes to Khrushchev.") && page.contains("AI-generated"))
            #expect(!page.contains("Summary will be generated at export"))
        }
    }

    /// The check of every quotation as the export sheet opens: each excerpt against its document's text
    /// as the served index holds it, found, not found, too short or not indexed, in the report's
    /// sentence; nothing to say for a collection with no excerpt; every one uncheckable while no index
    /// is served; and the export goes ahead whatever it says.
    @Test func theQuotationCheckWarnsAndNeverBlocks() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        let (_, flat) = try await HighlightTests.page(fixture)
        let phrase = "Allow me to congratulate you on the occasion of your election"
        let (start, end) = try HighlightTests.offsets(of: phrase, in: flat)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let quotes = try await CollectionTests.made(owner, "Quotations")
            let path = "\(Self.base)/\(quotes.id)"
            #expect(try decode(ExcerptCheck.self, try await owner.get("\(path)/excerpt-check")).summary == nil, "no excerpt")
            // From the TEI's page of d1, which the synthetic index stores with other words: not found.
            let version = try await HighlightTests.pageVersion(owner)
            _ = try await CollectionTests.edit(owner, "\(path)/excerpts", try CollectionTests.json([
                "volumeId": Self.volume, "documentId": "d1", "startOffset": start, "endOffset": end, "renderingVersion": version,
            ]))
            // Three more, their texts set as an import could leave them: d2's own words, too few words,
            // and a document the index does not hold.
            for (document, text) in [("d2", "Negotiating began in May… the treaties came."), ("d2", "in May"),
                                     ("d40", "A cable the index never stored.")] {
                let version = try await HighlightTests.pageVersion(owner, Self.volume, document)
                let added = try await CollectionTests.edit(owner, "\(path)/excerpts", try CollectionTests.json([
                    "volumeId": Self.volume, "documentId": document, "startOffset": 0, "endOffset": 12, "renderingVersion": version,
                ]))
                try fixture.rows.run("UPDATE collection_entries SET text = ? WHERE upper(id) = ?", [.text(text), .text(added.entryIds[0])])
            }
            let check = try decode(ExcerptCheck.self, try await owner.get("\(path)/excerpt-check"))
            #expect(check.summary == "One quotation was not found in the document it cites. 1 could not be checked — their volumes are not downloaded. 1 were too short to check.")
            #expect(check.hasFailures && check.verified == 1)
            #expect(check.notFound.map(\.documentId) == ["d1"] && check.notFound.first?.text == phrase)
            #expect(check.notIndexed.map(\.documentId) == ["d40"] && check.inconclusive.map(\.text) == ["in May"])
            _ = try await CollectionTests.edit(owner, "\(path)/documents", try CollectionTests.documents(["d1"]))
            #expect(try await Self.export(owner, quotes.id, "html").status == .ok, "the check never blocks")
        }
        // With no index served, nothing can be checked.
        let unserved = try await UserDataFixture(volumes: [Self.volume])
        defer { withExtendedLifetime(unserved) {} }
        try await unserved.app.test(.router) { client in
            let owner = Browser(client: client)
            let quotes = try await CollectionTests.made(owner, "Quotations")
            let version = try await HighlightTests.pageVersion(owner)
            _ = try await CollectionTests.edit(owner, "\(Self.base)/\(quotes.id)/excerpts", try CollectionTests.json([
                "volumeId": Self.volume, "documentId": "d1", "startOffset": start, "endOffset": end, "renderingVersion": version,
            ]))
            let check = try decode(ExcerptCheck.self, try await owner.get("\(Self.base)/\(quotes.id)/excerpt-check"))
            #expect(check.summary == "1 could not be checked — their volumes are not downloaded." && !check.hasFailures)
        }
    }

    /// Another user's collection has no preview, export or check for anyone else, live behind the proxy.
    @Test func eachUsersCollectionsAreTheirsAlone() async throws {
        let fixture = try await UserDataFixture(volumes: [Self.volume], auth: .header, trustedProxies: SignInTests.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let mine = try await CollectionTests.made(alice, "Mine")
            _ = try await CollectionTests.edit(alice, "\(Self.base)/\(mine.id)/documents", try CollectionTests.documents(["d1"]))
            #expect(try await Self.export(alice, mine.id, "html").status == .ok)
            let preview = try await bob.get("\(Self.base)/\(mine.id)/preview")
            #expect(preview.status == .notFound && String(buffer: preview.body).contains("Preview Unavailable"))
            let export = try await Self.export(bob, mine.id, "html")
            #expect(export.status == .notFound && problemCode(export) == "COLLECTION_NOT_FOUND")
            let check = try await bob.get("\(Self.base)/\(mine.id)/excerpt-check")
            #expect(check.status == .notFound && problemCode(check) == "COLLECTION_NOT_FOUND")
            #expect(try decode(HistoryPage.self, try await bob.get("/api/v1/me/history")).totalExports == 0)
            #expect(try decode(HistoryPage.self, try await alice.get("/api/v1/me/history")).totalExports == 1)
        }
    }

    /// A document is parsed once, as the app's resolver parses one its cache misses, and again only when
    /// its volume's file changes; a volume outside the manifest is never opened, and a document its
    /// volume lacks is none.
    @Test func aDocumentIsParsedOnceUntilItsVolumeChanges() async throws {
        let fixture = try await ServerFixture(volumes: [Self.volume])
        let parses = CollectionDocumentParses(volumesDirectory: fixture.files.volumesDirectory, resources: fixture.resources, capacity: 2)
        let first = try #require(await parses.document(volumeId: Self.volume, documentId: "d1"))
        let fresh = try await FRUSDocumentParser().parseDocument(documentId: "d1",
                                                                 volumeURL: fixture.files.volumesDirectory.appendingPathComponent("\(Self.volume).xml"))
        #expect(first.documentId == "d1" && first.nodes.count == fresh?.nodes.count)
        _ = await parses.document(volumeId: Self.volume, documentId: "d1")
        #expect(await parses.parseCount == 1)
        #expect(await parses.document(volumeId: Self.volume, documentId: "d999") == nil)
        #expect(await parses.document(volumeId: "frus1894Nicaragua", documentId: "d1") == nil, "not mounted")
        #expect(await parses.document(volumeId: "../\(Self.volume)", documentId: "d1") == nil, "no manifest id")
        #expect(await parses.parseCount == 2)
        // Two more documents push d1 out of a cache of two; and a changed file is parsed again.
        _ = await parses.document(volumeId: Self.volume, documentId: "d2")
        _ = await parses.document(volumeId: Self.volume, documentId: "d1")
        #expect(await parses.parseCount == 4)
        let file = fixture.files.volumesDirectory.appendingPathComponent("\(Self.volume).xml")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: file.path)
        _ = await parses.document(volumeId: Self.volume, documentId: "d1")
        #expect(await parses.parseCount == 5)
    }
}
