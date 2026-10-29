// /api/v1/me/notes and a document's notes through the router (PLAN's S15d): a note is made, saved and
// deleted as the app's editor does it, its formatting going as runs and kept as the codec's RTF; a
// save that leaves the body keeps the stored RTF byte for byte, Apple's own included, as the app's
// editor rewrites it only on an edit; every value a GET gives can be sent back, a link the note holds
// whatever its scheme, while a new link must be one a browser may follow; ids name what the user
// has unless the note carries them already; Add Note to Highlight links the highlight; and what the
// editor could not send is refused, storing nothing.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSRichText
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A note's body as the browser app sends it, with `runs` left out, null or runs, as a case needs.
struct NoteJSON: Encodable {
    enum Runs {
        case omitted, plain
        case formatted([RichTextRun])
    }

    var bodyText: String?
    var runs = Runs.plain
    var userTagIds: [String] = []
    var projectIds: [String] = []
    var selectedSummaryIds: [String] = []
    var linkedHighlightId: String?

    enum CodingKeys: String, CodingKey {
        case bodyText, runs, userTagIds, projectIds, selectedSummaryIds, linkedHighlightId
    }

    /// A save of the lists alone, as the editor sends one when the body was not edited.
    static func lists(tags: [String] = [], projects: [String] = [], summaries: [String] = []) -> NoteJSON {
        NoteJSON(bodyText: nil, runs: .omitted, userTagIds: tags, projectIds: projects, selectedSummaryIds: summaries)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(bodyText, forKey: .bodyText)
        switch runs {
        case .omitted: break
        case .plain: try container.encodeNil(forKey: .runs)
        case .formatted(let runs): try container.encode(runs, forKey: .runs)
        }
        try container.encode(userTagIds, forKey: .userTagIds)
        try container.encode(projectIds, forKey: .projectIds)
        try container.encode(selectedSummaryIds, forKey: .selectedSummaryIds)
        try container.encodeIfPresent(linkedHighlightId, forKey: .linkedHighlightId)
    }

    var json: String { (try? JSONEncoder().encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "" }
}

@Suite struct NoteTests {
    static let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1/notes"
    static let macId = "A0000000-0000-4000-8000-00000000000A"

    static func note(_ id: String) -> String { "/api/v1/me/notes/\(id)" }

    /// A case's RTF in the golden spans, as Apple's writer wrote it on the owner's Mac.
    static func golden(_ id: String) throws -> [UInt8] {
        let url = RepositoryFiles.root.appendingPathComponent("fixtures/golden/rich-text/spans.json")
        let golden = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let cases = try #require(golden["cases"] as? [[String: Any]])
        let rtf = try #require(cases.first { $0["id"] as? String == id }?["rtf"] as? String, "no golden case \(id)")
        return Array(rtf.utf8)
    }

    /// The done-when on the server: a note made with formatting, read, listed, saved three ways
    /// and deleted, as the app's editor makes, saves and deletes one.
    @Test func aNoteIsMadeSavedAndDeletedAsTheAppsEditorDoesIt() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let tag = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Laos"}"#))
            let runs = [RichTextRun(text: "A "), RichTextRun(text: "bold", bold: true), RichTextRun(text: " word,\n"),
                        RichTextRun(text: "blue", colorHex: "0000FF"), RichTextRun(text: " and "),
                        RichTextRun(text: "a link", underline: true, linkURL: "https://history.state.gov/")]
            let text = RichTextRuns.text(runs)
            let made = try await browser.send(.post, Self.d1, NoteJSON(bodyText: text, runs: .formatted(runs), userTagIds: [tag.id]).json)
            #expect(made.status == .created)
            let note = try decode(Note.self, made)
            #expect(made.headers[.location] == "/api/v1/me/notes/\(note.id)")
            #expect(UUID(uuidString: note.id)?.uuidString == note.id)
            #expect(note.volumeId == "frus1961-63v06" && note.documentId == "d1" && note.bodyText == text)
            #expect(note.runs == runs && !note.formattingKept, "the codec's reading of what it wrote")
            #expect(note.userTagIds == [tag.id] && note.projectIds.isEmpty && note.selectedSummaryIds.isEmpty)
            #expect(note.linkedHighlightIds.isEmpty)
            #expect(note.createdAt == "2026-10-24T00:00:00.000Z" && note.lastModified == note.createdAt)
            let stored = try #require(try fixture.rows.storedNote(note.id))
            #expect(stored.richText == RTFWriter.write(runs) && stored.bodyText == text, "the codec's RTF, and the plain text")
            #expect(try decode(Note.self, try await browser.get(Self.note(note.id.lowercased()))) == note)

            // The lists carry no formatting, and write every field, a time with none as null.
            let listed = try await browser.get(Self.d1)
            let document = try decode(DocumentNotes.self, listed)
            #expect(document.volumeId == "frus1961-63v06" && document.documentId == "d1" && document.items.map(\.id) == [note.id])
            #expect(document.items[0].bodyText == text && document.items[0].userTagIds == [tag.id])
            let raw = try #require(try JSONSerialization.jsonObject(with: Data(buffer: listed.body)) as? [String: Any])
            let item = try #require((raw["items"] as? [[String: Any]])?.first)
            #expect(Set(item.keys) == ["id", "volumeId", "documentId", "bodyText", "projectIds", "userTagIds", "selectedSummaryIds",
                                       "linkedHighlightIds", "createdAt", "lastModified", "fromResearchDatabase"])
            let all = try decode(NoteList.self, try await browser.get("/api/v1/me/notes"))
            #expect(all.total == 1 && all.items == document.items)

            // A save of the lists alone keeps the body and its RTF; a plain-mode edit drops the RTF;
            // a formatted one writes the codec's.
            let retagged = try await browser.send(.put, Self.note(note.id), NoteJSON.lists().json)
            #expect(retagged.status == .ok)
            #expect(try decode(Note.self, retagged).runs == runs && decode(Note.self, retagged).userTagIds.isEmpty)
            #expect(try fixture.rows.storedNote(note.id)?.richText == RTFWriter.write(runs))
            let plain = try decode(Note.self, try await browser.send(.put, Self.note(note.id), NoteJSON(bodyText: "Plain now.").json))
            #expect(plain.bodyText == "Plain now." && plain.runs == nil && !plain.formattingKept)
            #expect(try fixture.rows.storedNote(note.id)?.richText == nil)
            let rawPlain = try #require(try JSONSerialization.jsonObject(with: Data(buffer: try await browser.get(Self.note(note.id)).body))
                as? [String: Any])
            #expect(rawPlain["runs"] is NSNull && rawPlain["formattingKept"] as? Bool == false, "runs null, not left out")
            let italic = [RichTextRun(text: "Italic", italic: true), RichTextRun(text: " now.")]
            let formatted = try decode(Note.self, try await browser.send(
                .put, Self.note(note.id), NoteJSON(bodyText: "Italic now.", runs: .formatted(italic)).json))
            #expect(formatted.runs == italic && formatted.bodyText == "Italic now.")

            let deleted = try await browser.send(.delete, Self.note(note.id))
            #expect(deleted.status == .noContent && deleted.body.readableBytes == 0)
            for response in [try await browser.get(Self.note(note.id)), try await browser.send(.delete, Self.note(note.id)),
                             try await browser.send(.put, Self.note(note.id), NoteJSON.lists().json),
                             try await browser.get(Self.note("not-a-uuid"))] {
                #expect(response.status == .notFound && problemCode(response) == "NOTE_NOT_FOUND")
            }
            #expect(try decode(NoteList.self, try await browser.get("/api/v1/me/notes")).total == 0)
        }
    }

    /// Runs in canonical form: a line break formatted as the text before it, plain at the start,
    /// neighbours of one formatting joined, none empty; an empty formatted body is `[]`, and a new
    /// note with no text keeps no RTF, as the app's editor stores none until something is typed.
    @Test func runsAreMadeCanonicalBeforeTheyAreWritten() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let given = [RichTextRun(text: "\n"), RichTextRun(text: "Bold", bold: true), RichTextRun(text: "\n\nnext"),
                         RichTextRun(text: ""), RichTextRun(text: "!"), RichTextRun(text: "\n", italic: true)]
            let text = RichTextRuns.text(given)
            let note = try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(bodyText: text, runs: .formatted(given)).json))
            let canonical = [RichTextRun(text: "\n"), RichTextRun(text: "Bold\n\n", bold: true), RichTextRun(text: "next!\n")]
            #expect(note.runs == canonical && note.bodyText == text)
            #expect(try fixture.rows.storedNote(note.id)?.richText == RTFWriter.write(canonical))
            #expect(RichTextRuns.canonical(canonical) == canonical, "canonical runs are their own canonical form")

            let empty = try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(bodyText: "", runs: .formatted([])).json))
            #expect(empty.runs == nil && !empty.formattingKept && empty.bodyText == "")
            #expect(try fixture.rows.storedNote(empty.id)?.richText == nil)
            // Emptied by an edit, the note keeps the codec's RTF of nothing, as the app's editor reports one.
            let emptied = try decode(Note.self, try await browser.send(.put, Self.note(note.id), NoteJSON(bodyText: "", runs: .formatted([])).json))
            #expect(emptied.runs == [] && !emptied.formattingKept)
            #expect(try fixture.rows.storedNote(note.id)?.richText == RTFWriter.write([]))
        }
    }

    /// The app rewrites a note's RTF only when its editor reports an edit, so a change of tags keeps
    /// Apple's RTF, with what the codec ignores (strikethrough, superscript, a background colour),
    /// byte for byte; so too a note whose RTF reads as other text than its body, or as its body with
    /// runs a save could not send back, which answers with no runs and `formattingKept`. Every value
    /// a GET gives a save can send back.
    @Test func aSaveThatLeavesTheBodyKeepsTheMacsRTFByteForByte() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let apple = try Self.golden("paste-other-attributes")
        let text = "strike super sub raised background shadow kern obliqueness expansion stroke end"
        try fixture.rows.addNote(Self.macId, bodyText: text, richText: apple)
        // Apple's writer folds a paragraph separator and a carriage return into a line break, so a
        // body that holds one reads otherwise from its RTF.
        let separated = "B0000000-0000-4000-8000-00000000000B"
        try fixture.rows.addNote(separated, bodyText: "one\u{2029}two", richText: try Self.golden("paragraph-separator"))
        let returns = "C0000000-0000-4000-8000-00000000000C"
        try fixture.rows.addNote(returns, bodyText: "one\r\ntwo\rthree", richText: try Self.golden("carriage-returns"))
        let unreadable = "D0000000-0000-4000-8000-00000000000D"
        try fixture.rows.addNote(unreadable, bodyText: "Not RTF.", richText: Array("Not RTF.".utf8))
        // RTF another writer made, which reads as the body but holds what a save could not send
        // back: a link longer than a link may be once AppKit has escaped it, and a control character.
        // A link with a space is not one: the app reads it escaped, and so the codec offers it so.
        let long = "E0000000-0000-4000-8000-00000000000E"
        let longURL = "https://example.org/" + String(repeating: "|", count: 700)
        let longRTF = Array(#"{\rtf1\ansi A {\field{\*\fldinst{HYPERLINK ""#.utf8) + Array(longURL.utf8) + Array(#""}}{\fldrslt link}}.}"#.utf8)
        try fixture.rows.addNote(long, bodyText: "A link.", richText: longRTF)
        let control = "F0000000-0000-4000-8000-00000000000F"
        let controlRTF = Array(#"{\rtf1\ansi a\'0bb}"#.utf8)
        try fixture.rows.addNote(control, bodyText: "a\u{0B}b", richText: controlRTF)
        #expect(RTFReader.read(longRTF)?.text == "A link." && RTFReader.read(controlRTF)?.text == "a\u{0B}b",
                "each reads as its body, so only the runs' rules keep it")
        #expect(RTFReader.read(longRTF)?.runs.compactMap(\.linkURL).first.map { RichTextRuns.linkProblem($0) != nil } == true)
        let spaced = "A1000000-0000-4000-8000-0000000000A1"
        let spacedRTF = Array(#"{\rtf1\ansi A {\field{\*\fldinst{HYPERLINK "https://example.org/a b"}}{\fldrslt link}}.}"#.utf8)
        try fixture.rows.addNote(spaced, bodyText: "A link.", richText: spacedRTF)
        #expect(RTFReader.read(spacedRTF)?.runs.compactMap(\.linkURL) == ["https://example.org/a%20b"])
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let tag = try decode(UserTag.self, try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Laos"}"#))
            let mac = try decode(Note.self, try await browser.get(Self.note(Self.macId)))
            #expect(mac.runs == [RichTextRun(text: text)] && !mac.formattingKept, "none of it is a run's formatting")
            let retagged = try decode(Note.self, try await browser.send(.put, Self.note(Self.macId), NoteJSON.lists(tags: [tag.id]).json))
            #expect(retagged.userTagIds == [tag.id] && retagged.runs == mac.runs && retagged.lastModified == "2026-10-24T00:00:00.000Z")
            #expect(try fixture.rows.storedNote(Self.macId)?.richText == apple, "Apple's bytes, byte for byte")
            #expect(try fixture.rows.storedNote(Self.macId)?.bodyText == text)

            for (id, body, bytes) in [(separated, "one\u{2029}two", try Self.golden("paragraph-separator")),
                                      (returns, "one\r\ntwo\rthree", try Self.golden("carriage-returns")),
                                      (unreadable, "Not RTF.", Array("Not RTF.".utf8)),
                                      (long, "A link.", longRTF), (control, "a\u{0B}b", controlRTF)] {
                let kept = try decode(Note.self, try await browser.get(Self.note(id)))
                #expect(kept.runs == nil && kept.formattingKept && kept.bodyText == body, "\(id)")
                let saved = try decode(Note.self, try await browser.send(.put, Self.note(id), NoteJSON.lists(tags: [tag.id]).json))
                #expect(saved.formattingKept && saved.bodyText == body && saved.userTagIds == [tag.id])
                #expect(try fixture.rows.storedNote(id)?.richText == bytes && fixture.rows.storedNote(id)?.bodyText == body)
            }
            // A link with a space is offered as the app reads it, and a change of tags keeps its bytes.
            let offered = try decode(Note.self, try await browser.get(Self.note(spaced)))
            #expect(offered.runs == [RichTextRun(text: "A "), RichTextRun(text: "link", linkURL: "https://example.org/a%20b"), RichTextRun(text: ".")]
                    && !offered.formattingKept)
            _ = try await browser.send(.put, Self.note(spaced), NoteJSON.lists(tags: [tag.id]).json)
            #expect(try fixture.rows.storedNote(spaced)?.richText == spacedRTF)
            // A GET's values sent back: the Mac note's runs, as a formatted edit, which writes the
            // codec's RTF; a kept note's body, as a plain one, which any text but a NUL may be.
            let resent = try decode(Note.self, try await browser.send(
                .put, Self.note(Self.macId), NoteJSON(bodyText: mac.bodyText, runs: .formatted(mac.runs ?? [])).json))
            #expect(resent.runs == mac.runs)
            #expect(try fixture.rows.storedNote(Self.macId)?.richText == RTFWriter.write(mac.runs ?? []))
            let plain = try decode(Note.self, try await browser.send(.put, Self.note(separated), NoteJSON(bodyText: "one\u{2029}two").json))
            #expect(plain.bodyText == "one\u{2029}two" && plain.runs == nil && !plain.formattingKept)
            #expect(try fixture.rows.storedNote(separated)?.richText == nil)
        }
    }

    /// The app links any text its reader types, so a Mac note may hold a link no browser should
    /// follow, or one with no scheme: GET gives it, and a save may send it back. A link the note
    /// does not hold must be http, https or mailto.
    @Test func aLinkTheNoteHoldsIsAcceptedBackAndANewOneMustBeFollowable() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addNote(Self.macId, bodyText: "A script link.", richText: try Self.golden("link-javascript"))
        let schemeless = "B0000000-0000-4000-8000-00000000000B"
        try fixture.rows.addNote(schemeless, bodyText: "Not a URL here.", richText: try Self.golden("link-not-a-url"))
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let script = try decode(Note.self, try await browser.get(Self.note(Self.macId)))
            let runs = [RichTextRun(text: "A "), RichTextRun(text: "script", linkURL: "javascript:alert(1)"), RichTextRun(text: " link.")]
            #expect(script.runs == runs && !script.formattingKept)
            let resent = try await browser.send(.put, Self.note(Self.macId), NoteJSON(bodyText: "A script link.", runs: .formatted(runs)).json)
            #expect(try resent.status == .ok && decode(Note.self, resent).runs == runs)
            #expect(try decode(Note.self, try await browser.send(.put, Self.note(Self.macId), NoteJSON(
                bodyText: "A script link.", runs: .formatted(runs)).json)).runs == runs, "and again, from the codec's RTF")
            for url in ["javascript:alert(2)", "JAVASCRIPT:alert(1)", "data:text/html,x", "zotero://select/items/1_ABC", "www.state.gov"] {
                var changed = runs
                changed[1].linkURL = url
                let refused = try await browser.send(.put, Self.note(Self.macId), NoteJSON(bodyText: "A script link.", runs: .formatted(changed)).json)
                #expect(refused.status == .badRequest && problemCode(refused) == "INVALID_FIELD", "\(url)")
                let new = try await browser.send(.post, Self.d1, NoteJSON(bodyText: "A script link.", runs: .formatted(changed)).json)
                #expect(new.status == .badRequest && problemCode(new) == "INVALID_FIELD", "a new note's \(url)")
            }
            for url in ["https://history.state.gov/historicaldocuments/frus1961-63v06/d1?x=1#p2", "HTTP://example.org", "mailto:office@state.gov"] {
                var changed = runs
                changed[1].linkURL = url
                let accepted = try await browser.send(.put, Self.note(Self.macId), NoteJSON(bodyText: "A script link.", runs: .formatted(changed)).json)
                #expect(try accepted.status == .ok && decode(Note.self, accepted).runs?[1].linkURL == url, "\(url)")
            }
            // A stale editor's save, after another took the script link out, is held to the note as
            // the save finds it, which no longer holds the link.
            let stale = try await browser.send(.put, Self.note(Self.macId), NoteJSON(bodyText: "A script link.", runs: .formatted(runs)).json)
            #expect(stale.status == .badRequest && problemCode(stale) == "INVALID_FIELD")
            #expect(try decode(Note.self, try await browser.get(Self.note(Self.macId))).runs?[1].linkURL == "mailto:office@state.gov")
            let percent = try decode(Note.self, try await browser.get(Self.note(schemeless)))
            #expect(percent.runs?[1] == RichTextRun(text: "URL", linkURL: "not%20a%20url%20at%20all"))
            let back = try await browser.send(.put, Self.note(schemeless), NoteJSON(bodyText: percent.bodyText, runs: .formatted(percent.runs ?? [])).json)
            #expect(back.status == .ok)
        }
    }

    /// What the editor could not send is refused, and nothing is stored: runs that are not the body,
    /// a colour that is not `RRGGBB` or is (near-)black, a link the codec cannot write, a character a
    /// run may not hold, an id that is no UUID or names nothing the user has, a body that is not the
    /// route's, and a save that is neither the lists alone nor the body with its runs.
    @Test func aNoteTheEditorCouldNotSendIsRefused() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            func refused(_ json: String, _ code: String, _ status: HTTPResponse.Status = .badRequest, _ method: HTTPRequest.Method = .post,
                         path: String = Self.d1, sourceLocation: SourceLocation = #_sourceLocation) async throws {
                let response = try await browser.send(method, path, json)
                #expect(response.status == status && problemCode(response) == code, "\(json): \(String(buffer: response.body))",
                        sourceLocation: sourceLocation)
            }
            func formatted(_ runs: [RichTextRun], body: String? = nil) -> String {
                NoteJSON(bodyText: body ?? RichTextRuns.text(runs), runs: .formatted(runs)).json
            }
            try await refused(formatted([RichTextRun(text: "abd")], body: "abc"), "INVALID_FIELD")
            try await refused(formatted([RichTextRun(text: "ab")], body: "abc"), "INVALID_FIELD")
            for hex in ["0000ff", "131313", "000000", "GGGGGG", "FFF", "#0000FF"] {
                try await refused(formatted([RichTextRun(text: "x", colorHex: hex)]), "INVALID_FIELD")
            }
            for url in ["https://example.org/a b", "https://example.org/\"q\"", "https://example.org/{x}", "https://example.org/é",
                        "https://example.org/" + String(repeating: "a", count: 2_048), ""] {
                try await refused(formatted([RichTextRun(text: "x", linkURL: url)]), "INVALID_FIELD")
            }
            for character in ["\r", "\u{2029}", "\u{0085}", "\u{0}", "\u{1F}", "\u{7F}", "\u{0B}"] {
                try await refused(formatted([RichTextRun(text: "a\(character)b")]), "INVALID_FIELD")
            }
            try await refused(NoteJSON(bodyText: "a\u{0}b").json, "INVALID_FIELD")
            let unknown = UUID().uuidString
            try await refused(NoteJSON(bodyText: "x", userTagIds: [unknown]).json, "TAG_NOT_FOUND", .notFound)
            try await refused(NoteJSON(bodyText: "x", userTagIds: ["Laos"]).json, "INVALID_FIELD")
            try await refused(NoteJSON(bodyText: "x", projectIds: [unknown]).json, "INVALID_FIELD")
            try await refused(NoteJSON(bodyText: "x", selectedSummaryIds: [unknown]).json, "INVALID_FIELD")
            try await refused(NoteJSON(bodyText: "x", linkedHighlightId: "not-a-uuid").json, "INVALID_FIELD")
            let lists = #""userTagIds": [], "projectIds": [], "selectedSummaryIds": []"#
            try await refused(#"{"bodyText": "x", \#(lists)}"#, "INVALID_FIELD")
            try await refused(#"{"bodyText": "x", "runs": null, "userTagIds": [], "projectIds": []}"#, "INVALID_FIELD")
            try await refused(#"{"bodyText": 5, "runs": null, \#(lists)}"#, "INVALID_FIELD")
            try await refused(#"{"bodyText": "x", "runs": "x", \#(lists)}"#, "INVALID_FIELD")
            try await refused(#"{"bodyText": "x", "runs": null, \#(lists), "richText": "e1xydGYxfQ=="}"#, "UNKNOWN_FIELD")
            try await refused(#"{"bodyText": "x", "runs": [{"text": "x", "bold": false, "italic": false, "underline": false, "color": "0000FF"}], \#(lists)}"#,
                              "INVALID_FIELD")
            try await refused(#"{"bodyText": "x", "runs": [{"text": "x", "italic": false, "underline": false}], \#(lists)}"#, "INVALID_FIELD")
            try await refused(NoteJSON(bodyText: "x").json, "VOLUME_NOT_FOUND", .notFound,
                              path: "/api/v1/me/volumes/frus9999v99/documents/d1/notes")
            try await refused(NoteJSON(bodyText: "x").json, "INVALID_PARAMETER", .badRequest,
                              path: "/api/v1/me/volumes/frus1961-63v06/documents/\(String(repeating: "d", count: 300))/notes")

            // A save: the lists alone, or the body with its runs, null for a plain edit.
            let note = try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(bodyText: "Kept.").json))
            let path = Self.note(note.id)
            try await refused(#"{"runs": null, \#(lists)}"#, "INVALID_FIELD", .badRequest, .put, path: path)
            try await refused(#"{"runs": [], \#(lists)}"#, "INVALID_FIELD", .badRequest, .put, path: path)
            try await refused(#"{"bodyText": "x", \#(lists)}"#, "INVALID_FIELD", .badRequest, .put, path: path)
            try await refused(#"{"bodyText": null, "runs": null, \#(lists)}"#, "INVALID_FIELD", .badRequest, .put, path: path)
            try await refused(#"{"userTagIds": [], "projectIds": []}"#, "INVALID_FIELD", .badRequest, .put, path: path)
            try await refused(#"{"userTagIds": [], "projectIds": [], "selectedSummaryIds": [], "linkedHighlightId": null}"#,
                              "UNKNOWN_FIELD", .badRequest, .put, path: path)
            try await refused(formatted([RichTextRun(text: "x", colorHex: "131313")]), "INVALID_FIELD", .badRequest, .put, path: path)
            try await refused(NoteJSON.lists(tags: [unknown]).json, "TAG_NOT_FOUND", .notFound, .put, path: path)
            try await refused(NoteJSON.lists().json, "NOTE_NOT_FOUND", .notFound, .put, path: Self.note(unknown))
            let tokenless = try await browser.send(.put, path, NoteJSON.lists().json, token: "")
            #expect(tokenless.status == .forbidden && problemCode(tokenless) == "CSRF_TOKEN_INVALID")
            #expect(try decode(Note.self, try await browser.get(path)) == note, "unchanged")

            // What the rules allow: any text but a NUL in a plain body, and a colour just above near-black.
            let anything = "line\r\nbreaks\u{2029}and\u{0085}more\u{0B}"
            #expect(try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(bodyText: anything).json)).bodyText == anything)
            let dark = try await browser.send(.post, Self.d1, formatted([RichTextRun(text: "dark", colorHex: "141414")]))
            #expect(try dark.status == .created && decode(Note.self, dark).runs == [RichTextRun(text: "dark", colorHex: "141414")])
        }
        #expect(try fixture.store.notes(for: "owner").count == 3)
    }

    /// A new id must name one of the user's tags, projects or summaries; an id the note already
    /// carries is accepted back whatever it names, as the app's picker keeps an id its list lacks.
    @Test func idsNameWhatTheUserHasUnlessTheNoteCarriesThem() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let dangling = "d0000000-0000-4000-8000-00000000000d"
        let gone = "E0000000-0000-4000-8000-00000000000E"
        try fixture.rows.addNote(Self.macId, tagIds: [dangling], projectIds: ["not-a-uuid"], selectedSummaryIds: [gone])
        try fixture.rows.addProject("aa000000-0000-4000-8000-000000000001", name: "Laos")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let mac = try decode(Note.self, try await browser.get(Self.note(Self.macId)))
            #expect(mac.userTagIds == [dangling.uppercased()] && mac.projectIds == ["not-a-uuid"] && mac.selectedSummaryIds == [gone],
                    "a UUID in uppercase, and anything else as stored")
            let saved = try await browser.send(.put, Self.note(Self.macId), NoteJSON.lists(
                tags: mac.userTagIds, projects: mac.projectIds + ["AA000000-0000-4000-8000-000000000001"], summaries: mac.selectedSummaryIds).json)
            #expect(saved.status == .ok)
            #expect(try decode(Note.self, saved).projectIds == ["not-a-uuid", "AA000000-0000-4000-8000-000000000001"])
            let stored = try #require(try fixture.rows.storedNote(Self.macId))
            #expect(stored.userTagIds == UserStoreRows.json([dangling.uppercased()]) && stored.selectedSummaryIds == UserStoreRows.json([gone]))
            let other = UUID().uuidString
            for (json, code) in [(NoteJSON.lists(tags: [other]).json, "TAG_NOT_FOUND"), (NoteJSON.lists(projects: [other]).json, "INVALID_FIELD"),
                                 (NoteJSON.lists(summaries: [other]).json, "INVALID_FIELD"),
                                 (NoteJSON.lists(projects: ["also-not-a-uuid"]).json, "INVALID_FIELD")] {
                #expect(problemCode(try await browser.send(.put, Self.note(Self.macId), json)) == code, "\(json)")
            }
            // On a new note, the user's own: a project an import left and a summary they wrote.
            let summary = try decode(Summary.self, try await browser.send(
                .post, "/api/v1/me/volumes/frus1961-63v06/documents/d1/summaries", #"{"responseText": "Mine."}"#))
            let made = try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(
                bodyText: "x", projectIds: ["aa000000-0000-4000-8000-000000000001"], selectedSummaryIds: [summary.id]).json))
            #expect(made.projectIds == ["AA000000-0000-4000-8000-000000000001"] && made.selectedSummaryIds == [summary.id])
            let carried = try await browser.send(.post, Self.d1, NoteJSON(bodyText: "x", userTagIds: [dangling]).json)
            #expect(problemCode(carried) == "TAG_NOT_FOUND", "a new note carries nothing yet")
        }
    }

    /// Add Note to Highlight: the new note's Save sets the highlight's `noteId`, as
    /// `linkNoteToHighlight` does; one that has gone links nothing; a delete leaves the link.
    @Test func addNoteToHighlightSetsTheHighlightsNoteId() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let highlight = "A1000000-0000-4000-8000-0000000000A1"
        try fixture.rows.addHighlight(highlight)
        try fixture.rows.addUser("reader")
        let theirs = "B1000000-0000-4000-8000-0000000000B1"
        try fixture.rows.addHighlight(theirs, user: "reader")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let note = try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(bodyText: "On it.", linkedHighlightId: highlight.lowercased()).json))
            #expect(note.linkedHighlightIds == [highlight])
            #expect(try fixture.rows.highlightNoteId(highlight) == note.id)
            #expect(try decode(Highlight.self, try await browser.get("/api/v1/me/highlights/\(highlight)")).noteId == note.id)
            #expect(try decode(NoteList.self, try await browser.get("/api/v1/me/notes")).items.first?.linkedHighlightIds == [highlight])
            for id in [UUID().uuidString, theirs] {
                let unlinked = try await browser.send(.post, Self.d1, NoteJSON(bodyText: "Unlinked.", linkedHighlightId: id).json)
                #expect(try unlinked.status == .created && decode(Note.self, unlinked).linkedHighlightIds == [])
            }
            #expect(try fixture.rows.highlightNoteId(theirs, user: "reader") == nil)
            _ = try await browser.send(.delete, Self.note(note.id))
            #expect(try fixture.rows.highlightNoteId(highlight) == note.id, "the highlight keeps the note's id")
        }
    }

    /// Each write rewrites the document's row of user_search, through the routes as in the store.
    @Test func everyNoteWriteRewritesTheDocumentsSearchText() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let row = { (notes: String?) in UserSearchRow(volumeId: "frus1961-63v06", documentId: "d1", summaryText: nil, noteText: notes) }
            let note = try decode(Note.self, try await browser.send(.post, Self.d1, NoteJSON(
                bodyText: "Negotiating in Geneva.", runs: .formatted([RichTextRun(text: "Negotiating in Geneva.", bold: true)])).json))
            #expect(try fixture.rows.userSearch() == [row("Negotiating in Geneva.")])
            _ = try await browser.send(.put, Self.note(note.id), NoteJSON(bodyText: "Talks in Geneva.").json)
            #expect(try fixture.rows.userSearch() == [row("Talks in Geneva.")])
            #expect(try fixture.rows.userSearchMatches("talk") == ["d1"])
            _ = try await browser.send(.delete, Self.note(note.id))
            #expect(try fixture.rows.userSearch().isEmpty)
        }
    }

    /// A note's text may be 1 MiB, in UTF-8, and a note's routes take a body of 4 MiB, so that a
    /// text that long can be sent again formatted, twice in the body, as a GET gives it, while its
    /// runs' own fields fit in the rest, some 36,000 runs; in many more, the body is refused whole,
    /// its text within the limit or not. The other routes keep 64 KiB.
    @Test func aNotesTextMayBeOneMebibyte() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let (limit, textLimit) = (UserDataServices.noteBodyLimit, UserDataServices.noteTextLimit)
        #expect(limit == 4 * 1_048_576 && textLimit == 1_048_576)
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            func words(_ count: Int) -> String { String(String(repeating: "lorem ", count: count / 6 + 1).prefix(count)) }
            let longest = words(textLimit)
            // A new note of the longest text, plain, more than any other route takes.
            let made = try await browser.send(.post, Self.d1, NoteJSON(bodyText: longest).json)
            #expect(made.status == .created)
            let note = try decode(Note.self, made)
            #expect(note.bodyText.utf8.count == textLimit)
            // The request's own limit: a save of 4 MiB is read, and a byte more is not.
            let lists = NoteJSON.lists().json
            func padded(_ size: Int) -> String { lists + String(repeating: " ", count: size - lists.utf8.count) }
            let full = try await browser.send(.put, Self.note(note.id), padded(limit))
            #expect(full.status == .ok)
            for (method, path) in [(HTTPRequest.Method.put, Self.note(note.id)), (.post, Self.d1)] {
                let refused = try await browser.send(method, path, padded(limit + 1))
                #expect(refused.status == .contentTooLarge && problemCode(refused) == "CONTENT_TOO_LARGE", "\(method)")
            }
            #expect(try fixture.rows.storedNote(note.id)?.bodyText == longest, "a save of the lists keeps the body")
            // Sent again formatted, its text twice: the answer is the note as a GET gives it, its runs
            // the ones sent, so a GET's values can be sent back.
            let runs = [RichTextRun(text: String(longest.prefix(6)), bold: true), RichTextRun(text: String(longest.dropFirst(6)), italic: true)]
            let formatted = try await browser.send(.put, Self.note(note.id), NoteJSON(bodyText: longest, runs: .formatted(runs)).json)
            #expect(try formatted.status == .ok && decode(Note.self, formatted).runs == runs)
            #expect(try fixture.rows.storedNote(note.id)?.richText == RTFWriter.write(runs))
            // In runs of a few words each, bold and plain by turns: some 36,000 of them fit, and in
            // 65,536 their fields take the body past 4 MiB, so the save is refused, its text no
            // longer than the one just saved, and the note is kept as it was.
            let bytes = Array(longest.utf8)
            func split(_ size: Int) -> [RichTextRun] {
                stride(from: 0, to: bytes.count, by: size).enumerated().map { index, start in
                    RichTextRun(text: String(decoding: bytes[start..<min(start + size, bytes.count)], as: UTF8.self),
                                bold: index.isMultiple(of: 2))
                }
            }
            let fitting = split(29)
            let fittingJSON = NoteJSON(bodyText: longest, runs: .formatted(fitting)).json
            #expect(fitting.count > 36_000 && fittingJSON.utf8.count <= limit)
            let fits = try await browser.send(.put, Self.note(note.id), fittingJSON)
            #expect(try fits.status == .ok && decode(Note.self, fits).runs == fitting)
            let many = split(16)
            let manyJSON = NoteJSON(bodyText: longest, runs: .formatted(many)).json
            #expect(many.count == 65_536 && manyJSON.utf8.count > limit && RichTextRuns.text(many) == longest)
            let tooMany = try await browser.send(.put, Self.note(note.id), manyJSON)
            #expect(tooMany.status == .contentTooLarge && problemCode(tooMany) == "CONTENT_TOO_LARGE")
            #expect(try fixture.rows.storedNote(note.id)?.richText == RTFWriter.write(fitting), "kept as it was")
            // A byte more is refused, new or saved, plain or formatted.
            let longer = words(textLimit + 1)
            for (method, path, json) in [(HTTPRequest.Method.post, Self.d1, NoteJSON(bodyText: longer).json),
                                         (.put, Self.note(note.id), NoteJSON(bodyText: longer).json),
                                         (.put, Self.note(note.id), NoteJSON(bodyText: longer, runs: .formatted([RichTextRun(text: longer)])).json)] {
                let refused = try await browser.send(method, path, json)
                #expect(refused.status == .badRequest && problemCode(refused) == "INVALID_FIELD", "\(method) \(path)")
            }
            #expect(try fixture.rows.storedNote(note.id)?.bodyText == longest)
            let tag = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "\#(String(repeating: "x", count: 64 * 1_024))"}"#)
            #expect(tag.status == .contentTooLarge, "64 KiB elsewhere")
        }
        #expect(try fixture.store.notes(for: "owner").count == 1, "nothing refused was made")
    }

    @Test func eachUsersNotesAreTheirsAlone() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addUser("reader")
        try fixture.rows.addNote(Self.macId, user: "reader")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            #expect(try decode(DocumentNotes.self, try await browser.get(Self.d1)).items.isEmpty)
            #expect(try decode(NoteList.self, try await browser.get("/api/v1/me/notes")).total == 0)
            for response in [try await browser.get(Self.note(Self.macId)),
                             try await browser.send(.put, Self.note(Self.macId), NoteJSON.lists().json),
                             try await browser.send(.delete, Self.note(Self.macId))] {
                #expect(problemCode(response) == "NOTE_NOT_FOUND")
            }
        }
        #expect(try fixture.rows.storedNote(Self.macId, user: "reader")?.bodyText == "A note.")
    }

    @Test func notesAreRefusedWhileUserDataIsOffAndAnswerUnderThePath() async throws {
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await off.app.test(.router) { client in
            let browser = Browser(client: client)
            for response in [try await browser.get(Self.d1), try await browser.get("/api/v1/me/notes"),
                             try await browser.get("/api/v1/me/notes/export"), try await browser.get("/api/v1/me/projects"),
                             try await browser.send(.post, Self.d1, NoteJSON(bodyText: "x").json),
                             try await browser.send(.put, Self.note(Self.macId), NoteJSON.lists().json)] {
                #expect(response.status == .forbidden && problemCode(response) == "USER_DATA_OFF")
            }
        }
        #expect(try off.store.notes(for: "owner").isEmpty)
        let under = try await UserDataFixture(publicURL: "http://localhost:8080/frus-explorer/")
        defer { withExtendedLifetime(under) {} }
        try await under.app.test(.router) { client in
            let browser = Browser(client: client, base: "/frus-explorer")
            let made = try await browser.send(.post, Self.d1, NoteJSON(bodyText: "Under the path.").json)
            let note = try decode(Note.self, made)
            #expect(made.headers[.location] == "/frus-explorer/api/v1/me/notes/\(note.id)")
            #expect(try decode(Note.self, try await browser.get(Self.note(note.id))) == note)
            let missing = try await browser.get(Self.note(UUID().uuidString))
            #expect(try decode(APIProblem.Body.self, missing).instance.hasPrefix("/frus-explorer/api/v1/me/notes/"))
            let export = try await browser.get("/api/v1/me/notes/export")
            #expect(export.status == .ok && export.headers[.contentType] == "application/zip")
        }
    }

    /// The projects a note may name, by name; none until an import or New Project (S17f), whose tests
    /// are ProjectHistoryTests'.
    @Test func projectsAreListedByName() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try fixture.rows.addUser("reader")
        try fixture.rows.addProject("bb000000-0000-4000-8000-000000000002", name: "Laos 10")
        try fixture.rows.addProject("AA000000-0000-4000-8000-000000000001", name: "Laos 9")
        try fixture.rows.addProject("CC000000-0000-4000-8000-000000000003", user: "reader", name: "Theirs")
        try await fixture.app.test(.router) { client in
            let browser = Browser(client: client)
            let list = try decode(ProjectList.self, try await browser.get("/api/v1/me/projects"))
            #expect(list.total == 2 && list.items.map(\.name) == ["Laos 9", "Laos 10"])
            #expect(list.items.map(\.id) == ["AA000000-0000-4000-8000-000000000001", "BB000000-0000-4000-8000-000000000002"])
            #expect(problemCode(try await browser.get("/api/v1/me/projects?x=1")) == "UNKNOWN_PARAMETER")
        }
        let empty = try await UserDataFixture()
        defer { withExtendedLifetime(empty) {} }
        try await empty.app.test(.router) { client in
            let none = try decode(ProjectList.self, try await Browser(client: client).get("/api/v1/me/projects"))
            #expect(none == ProjectList(total: 0, items: [], activeProjectId: nil))
        }
    }
}
