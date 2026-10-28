// Sign-in through a trusted proxy (PLAN's S14e), on a real socket, so that each request has the peer
// the server sees: the user is the one the header names on a request from FRUS_TRUSTED_PROXIES,
// made the first time, an admin if FRUS_ADMIN_USERS names them; a request from any other peer is
// refused, whatever it names; and two users' data stay apart through every route under /api/v1/me,
// the import and the export included, and through every search (S17d).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct SignInTests {
    /// The tests' proxy: this machine, by either name a socket gives it.
    static let loopback = ["127.0.0.1", "::1"].compactMap(AddressRange.init)

    /// The done-when's second half: a header from a peer outside the list is refused, under /me and
    /// everywhere else but the health endpoints, and makes no user.
    @Test func aRequestFromAPeerOutsideTheListIsRefusedWhateverItNames() async throws {
        let fixture = try await UserDataFixture(auth: .header, trustedProxies: ["10.0.0.0/8", "fd00::/8"].compactMap(AddressRange.init),
                                                adminUsers: ["alice"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            for path in ["/api/v1/me", "/api/v1/me/tags", "/api/v1/status", "/api/v1/volumes?limit=1", "/reader/host.js",
                         "/search", "/api/v1/no-such-endpoint"] {
                let response = try await alice.get(path)
                #expect(response.status == .forbidden && problemCode(response) == "PROXY_NOT_TRUSTED", "\(path)")
            }
            let write = try await alice.send(.post, "/api/v1/me/tags", #"{"name": "Mine"}"#, token: String(repeating: "0", count: 64))
            #expect(write.status == .forbidden && problemCode(write) == "PROXY_NOT_TRUSTED")
            #expect(try await Browser(client: client).get("/api/v1/volumes?limit=1").status == .forbidden, "with no header too")
            // The health endpoints answer any peer, for the container's health check and a proxy's.
            #expect(try await alice.get("/healthz").status == .ok)
            #expect(try await alice.get("/readyz").status == .serviceUnavailable, "503 before an import, as anywhere")
        }
        #expect(try fixture.store.user("alice") == nil, "no user is made for a name from elsewhere")
        #expect(try fixture.store.tags(of: "alice").isEmpty)
        // A request whose peer is not known, as in the router's tests, is refused as well.
        try await fixture.app.test(.router) { client in
            let response = try await Browser(client: client, user: "alice").get("/api/v1/me")
            #expect(response.status == .forbidden && problemCode(response) == "PROXY_NOT_TRUSTED")
        }
    }

    /// The user is the header's value on a request from the proxy, made in the store the first time;
    /// one with no header, two of it or a name the server does not take is refused under /me, where
    /// the corpus needs no user; and each user's token is their own.
    @Test func theProxysHeaderNamesTheUserWhoIsMadeTheFirstTime() async throws {
        let fixture = try await UserDataFixture(auth: .header, trustedProxies: Self.loopback, adminUsers: ["root@example.org"])
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let nobody = Browser(client: client)
            let refused = try await nobody.get("/api/v1/me")
            #expect(refused.status == .forbidden && problemCode(refused) == "NOT_SIGNED_IN")
            #expect(try await nobody.get("/api/v1/volumes?limit=1").status == .ok, "the corpus needs no user")
            var twice = HTTPFields()
            twice.append(HTTPFields.Element(name: Browser.userHeader, value: "alice"))
            twice.append(HTTPFields.Element(name: Browser.userHeader, value: "bob"))
            #expect(problemCode(try await client.execute(uri: "/api/v1/me", method: .get, headers: twice)) == "NOT_SIGNED_IN")
            for name in ["", "   ", String(repeating: "a", count: ProxyHeaderResolver.longestName + 1)] {
                #expect(problemCode(try await Browser(client: client, user: name).get("/api/v1/me")) == "NOT_SIGNED_IN", "\(name.count)")
            }
            #expect(try fixture.store.user("alice") == nil && fixture.store.user("bob") == nil)

            let me = try await Browser(client: client, user: "alice").me()
            #expect(me.userId == "alice" && me.displayName == "alice" && me.auth == "header" && me.roles == [.reader] && me.userData)
            #expect(try fixture.store.user("alice") == UserAccount(id: "alice", displayName: "alice"), "made the first time")
            #expect(try await Browser(client: client, user: "alice").me() == me, "and the same user after")
            let root = try await Browser(client: client, user: "root@example.org").me()
            #expect(root.userId == "root@example.org" && root.roles == [.reader, .curator, .admin], "FRUS_ADMIN_USERS names the admins")
            let accented = try await Browser(client: client, user: "José Martí").me()
            #expect(accented.userId == "José Martí", "a name is UTF-8")
            #expect(Set([me.csrfToken, root.csrfToken, accented.csrfToken]).count == 3)
            // A user's token carries no one else's change.
            let crossed = try await Browser(client: client, user: "bob").send(.post, "/api/v1/me/tags", #"{"name": "Mine"}"#,
                                                                               token: me.csrfToken)
            #expect(crossed.status == .forbidden && problemCode(crossed) == "CSRF_TOKEN_INVALID")
        }
        #expect(try fixture.store.tags(of: "bob").isEmpty)
        #expect(try fixture.store.user("bob") != nil, "resolved before the token was checked")
        #expect(try fixture.store.user("owner")?.displayName == "Owner", "FRUS_AUTH=none's user stays, and no header names them here")
    }

    /// The done-when's first half: two users, signed in through the proxy, each write through every
    /// route under /me, and neither reads, changes or exports the other's, by list or by id; the
    /// same Mac export imported by both gives each a copy of their own under the Mac's ids. The
    /// search's own half is `eachUsersSearchReadsTheirWritingAlone`'s.
    @Test func twoUsersDataStayApartThroughTheAPI() async throws {
        let fixture = try await UserDataFixture(volumes: ["frus1961-63v06"], auth: .header, trustedProxies: Self.loopback)
        defer { withExtendedLifetime(fixture) {} }
        let d1 = "/api/v1/me/volumes/frus1961-63v06/documents/d1"
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")

            // Alice writes through each kind of route, and imports an export.
            let tag = try decode(UserTag.self, try await alice.send(.post, "/api/v1/me/tags", #"{"name": "Berlin"}"#))
            let other = try decode(UserTag.self, try await alice.send(.post, "/api/v1/me/tags", #"{"name": "Wall"}"#))
            #expect(try await alice.send(.put, "\(d1)/tags", #"{"tagIds": ["\#(tag.id)", "\#(other.id)"]}"#).status == .ok)
            let version = try await HighlightTests.pageVersion(alice)
            let highlight = try decode(Highlight.self, try await alice.send(.post, "\(d1)/highlights",
                                                                            HighlightTests.body(0, 9, "yellow", version)))
            var body = NoteJSON(bodyText: "Alice's note")
            body.userTagIds = [tag.id]
            body.linkedHighlightId = highlight.id
            let note = try decode(Note.self, try await alice.send(.post, "\(d1)/notes", body.json))
            let summary = try decode(Summary.self, try await alice.send(.post, "\(d1)/summaries", #"{"responseText": "Alice's summary."}"#))
            let started = try await alice.send(.post, ImportRouteTests.path, try ImportRouteTests.export())
            #expect(started.status == .accepted)
            let location = try #require(started.headers[.location])
            await fixture.jobs.waitUntilIdle()
            #expect(try decode(ImportStatus.self, try await alice.get(location)).state == .succeeded)
            let aliceTags = try decode(TagList.self, try await alice.get("/api/v1/me/tags"))
            #expect(aliceTags.items.map(\.name) == ["Berlin", "Cuba", "Wall"])

            // Bob's lists hold none of it.
            #expect(try decode(TagList.self, try await bob.get("/api/v1/me/tags")).total == 0)
            #expect(try decode(DocumentTags.self, try await bob.get("\(d1)/tags")).items.isEmpty)
            #expect(try decode(HighlightList.self, try await bob.get("/api/v1/me/highlights")).total == 0)
            #expect(try decode(DocumentHighlights.self, try await bob.get("\(d1)/highlights")).items.isEmpty)
            #expect(try decode(NoteList.self, try await bob.get("/api/v1/me/notes")).total == 0)
            #expect(try decode(DocumentNotes.self, try await bob.get("\(d1)/notes")).items.isEmpty)
            #expect(try decode(DocumentSummaries.self, try await bob.get("\(d1)/summaries")).items.isEmpty)
            #expect(try decode(ProjectList.self, try await bob.get("/api/v1/me/projects")).total == 0)
            #expect(try decode(ExportContents.self, try await bob.get("/api/v1/me/export/contents")).types.allSatisfy { $0.count == 0 })
            let bobsNotes = try await bob.get("/api/v1/me/notes/export")
            #expect(bobsNotes.status == .ok)
            #expect(try NotesExportTests.entries(of: Array(buffer: bobsNotes.body)).isEmpty)
            let bobsExport = try ExportRouteTests.object(try await bob.get("/api/v1/me/export"))
            for key in ["notes", "tags", "tagAssignments", "highlights", "projects", "summaries", "prompts"] {
                #expect((bobsExport[key] as? [Any])?.isEmpty == true, "\(key)")
            }

            // Nor does any route reach it by its id, to read, change, merge or delete it.
            let byId: [(TestResponse, String)] = [
                (try await bob.get("/api/v1/me/tags/\(tag.id)"), "TAG_NOT_FOUND"),
                (try await bob.send(.patch, "/api/v1/me/tags/\(tag.id)", #"{"name": "Bob's"}"#), "TAG_NOT_FOUND"),
                (try await bob.send(.post, "/api/v1/me/tags/\(tag.id)/merge", #"{"into": "\#(other.id)"}"#), "TAG_NOT_FOUND"),
                (try await bob.send(.delete, "/api/v1/me/tags/\(tag.id)"), "TAG_NOT_FOUND"),
                (try await bob.send(.put, "\(d1)/tags", #"{"tagIds": ["\#(tag.id)"]}"#), "TAG_NOT_FOUND"),
                (try await bob.send(.delete, "\(d1)/tags/\(tag.id)"), "TAG_NOT_FOUND"),
                (try await bob.get("/api/v1/me/highlights/\(highlight.id)"), "HIGHLIGHT_NOT_FOUND"),
                (try await bob.send(.patch, "/api/v1/me/highlights/\(highlight.id)", #"{"colorTag": "pink"}"#), "HIGHLIGHT_NOT_FOUND"),
                (try await bob.send(.delete, "/api/v1/me/highlights/\(highlight.id)"), "HIGHLIGHT_NOT_FOUND"),
                (try await bob.get(NoteTests.note(note.id)), "NOTE_NOT_FOUND"),
                (try await bob.send(.put, NoteTests.note(note.id), NoteJSON.lists().json), "NOTE_NOT_FOUND"),
                (try await bob.send(.delete, NoteTests.note(note.id)), "NOTE_NOT_FOUND"),
                (try await bob.get(SummaryTests.summary(summary.id)), "SUMMARY_NOT_FOUND"),
                (try await bob.send(.put, SummaryTests.summary(summary.id), #"{"responseText": "Bob's."}"#), "SUMMARY_NOT_FOUND"),
                (try await bob.send(.delete, SummaryTests.summary(summary.id)), "SUMMARY_NOT_FOUND"),
                (try await bob.get(location), "IMPORT_NOT_FOUND"),
            ]
            for (index, (response, code)) in byId.enumerated() {
                #expect(problemCode(response) == code, "\(index)")
            }
            // Bob's own note cannot name Alice's tag, or link her highlight.
            var bobs = NoteJSON(bodyText: "Bob's note")
            bobs.userTagIds = [tag.id]
            #expect(problemCode(try await bob.send(.post, "\(d1)/notes", bobs.json)) == "TAG_NOT_FOUND")
            bobs.userTagIds = []
            bobs.linkedHighlightId = highlight.id
            let bobsNote = try decode(Note.self, try await bob.send(.post, "\(d1)/notes", bobs.json))
            #expect(bobsNote.linkedHighlightIds.isEmpty, "her highlight takes no note of his")

            // The same export, imported by Bob: his copies, under the Mac's ids, apart from hers.
            let his = try await bob.send(.post, ImportRouteTests.path, try ImportRouteTests.export(noteText: "Bob's import."))
            await fixture.jobs.waitUntilIdle()
            #expect(try decode(ImportStatus.self, try await bob.get(try #require(his.headers[.location]))).state == .succeeded)
            let cuba = try #require(try decode(TagList.self, try await bob.get("/api/v1/me/tags")).items.first)
            #expect(cuba.name == "Cuba" && aliceTags.items.contains { $0.id == cuba.id }, "one id, two users")
            #expect(try await bob.send(.delete, "/api/v1/me/tags/\(cuba.id)").status == .noContent)
            #expect(try decode(UserTag.self, try await alice.get("/api/v1/me/tags/\(cuba.id)")).name == "Cuba", "hers stays")

            // Each export is its writer's.
            let aliceExport = try ExportRouteTests.object(try await alice.get("/api/v1/me/export"))
            let aliceNotes = try #require(aliceExport["notes"] as? [[String: Any]]).compactMap { $0["bodyText"] as? String }
            #expect(Set(aliceNotes) == ["Alice's note", "An imported note."])
            let bobExport = try ExportRouteTests.object(try await bob.get("/api/v1/me/export"))
            let bobNotes = try #require(bobExport["notes"] as? [[String: Any]]).compactMap { $0["bodyText"] as? String }
            #expect(Set(bobNotes) == ["Bob's note", "Bob's import."])
            let aliceArchive = try NotesExportTests.entries(of: Array(buffer: try await alice.get("/api/v1/me/notes/export").body))
            #expect(aliceArchive.count == 2 && aliceArchive.allSatisfy { !String(decoding: $0.bytes, as: UTF8.self).contains("Bob's") })

            // Alice's writing is as she left it.
            #expect(try decode(DocumentTags.self, try await alice.get("\(d1)/tags")).items.map(\.name) == ["Berlin", "Wall"])
            let kept = try decode(Highlight.self, try await alice.get("/api/v1/me/highlights/\(highlight.id)"))
            #expect(kept.colorTag == "yellow" && kept.noteId == note.id)
            #expect(try decode(Note.self, try await alice.get(NoteTests.note(note.id))).bodyText == "Alice's note")
            #expect(try decode(Summary.self, try await alice.get(SummaryTests.summary(summary.id))).responseText == "Alice's summary.")
            #expect(try decode(ProjectList.self, try await alice.get("/api/v1/me/projects")).items.map(\.name) == ["Bay of Pigs review"])
        }
        #expect(try fixture.store.notes(for: "owner").isEmpty && fixture.store.tags(of: "owner").isEmpty, "and the single user's none")
    }

    /// The same for the search's user half (S17d): one user's search finds none of another's notes,
    /// summaries or tags, through every route that reads a search's match, even just after the other
    /// asked the same search, whose answers the server keeps; the tag filter refuses another user's
    /// tag, and the tag a Mac export gives both, under one id, is each one's own. A request from the
    /// proxy that names no one searches the corpus alone.
    @Test func eachUsersSearchReadsTheirWritingAlone() async throws {
        let fixture = try await UserDataFixture(indexed: true, auth: .header, trustedProxies: Self.loopback)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.live) { client in
            let alice = Browser(client: client, user: "alice")
            let bob = Browser(client: client, user: "bob")
            let nobody = Browser(client: client)
            let hers = try await UserHalfSearchTests.write(alice)
            let tag = SearchUsers.caseFolded(hers.tag.id)

            // Hers first, so that each answer of hers is kept when the others ask the same search.
            let either = "keywords=zanzibar+OR+quixotic+OR+canal"
            let aliceAnswers = try await UserHalfSearchTests.answers(alice, either)
            #expect(aliceAnswers.total == 3 && aliceAnswers.retained == 3 && aliceAnswers.termCounts == [1, 1, 1])
            #expect(aliceAnswers.tags["\(UserHalfSearchTests.volume)/d1"] == [tag] && aliceAnswers.myTags == ["Berlin": 1])
            let corpusAlone = UserHalfSearchTests.Answers(total: 1, page: ["frus1894Nicaragua/d1"], tags: ["frus1894Nicaragua/d1": []],
                                                      byDate: ["frus1894Nicaragua/d1"], retained: 1, volumes: ["frus1894Nicaragua": 1],
                                                      termCounts: [0, 0, 1])
            var bobsAnswers = corpusAlone
            bobsAnswers.myTags = [:]
            #expect(try await UserHalfSearchTests.answers(bob, either) == bobsAnswers, "none of hers, though hers are kept")
            #expect(try await UserHalfSearchTests.answers(nobody, either, myTags: false) == corpusAlone)
            #expect(problemCode(try await nobody.get("/api/v1/me/search/tags?\(either)")) == "NOT_SIGNED_IN")
            for words in ["zanzibar", "%3Dzanzibar", "quixotic"] {
                #expect(try await UserHalfSearchTests.search(bob, "keywords=\(words)").total == 0, "\(words)")
            }
            let inspected = try await UserHalfSearchTests.answer(SearchInspection.self, bob,
                                                             "/api/v1/search/inspect?keywords=zanzibar+treaties&emptyConjuncts=true")
            #expect(inspected.emptyConjuncts?.map(\.text) == ["zanzibar"], "her note's word matches nothing of his")
            #expect(UserHalfSearchTests.rowTags(try await UserHalfSearchTests.search(bob, "keywords=treaties")).values.allSatisfy(\.isEmpty))

            // Her tag filters no search of his, nor of no one's, by any route.
            for browser in [bob, nobody] {
                for path in ["/api/v1/search?", "/api/v1/search/inspect?", "/api/v1/search/facets?section=volumes&",
                             "/api/v1/search/timeline?", "/api/v1/search/concordance?"] {
                    let refused = try await browser.get("\(path)keywords=treaties&userTagIds=\(hers.tag.id)")
                    #expect(refused.status == .notFound && problemCode(refused) == "TAG_NOT_FOUND", "\(path)")
                }
            }
            #expect(problemCode(try await bob.get("/api/v1/me/search/tags?keywords=treaties&userTagIds=\(hers.tag.id)")) == "TAG_NOT_FOUND")
            // His tag of the same name is his own, on none of her documents.
            let his = try decode(UserTag.self, try await bob.send(.post, "/api/v1/me/tags", #"{"name": "Berlin"}"#))
            #expect(try await UserHalfSearchTests.search(bob, "keywords=treaties&userTagIds=\(his.id)").total == 0)

            // One id, two users: a Mac export's tag, imported by each onto another document.
            for (browser, document) in [(alice, "d1"), (bob, "d2")] {
                let started = try await browser.send(.post, ImportRouteTests.path, try Self.export(tagging: document))
                #expect(started.status == .accepted)
                await fixture.jobs.waitUntilIdle()
                #expect(try decode(ImportStatus.self, try await browser.get(try #require(started.headers[.location]))).state == .succeeded)
            }
            let cuba = Self.sharedTag.uuidString
            #expect(UserHalfSearchTests.documents(try await UserHalfSearchTests.search(alice, "keywords=treaties&userTagIds=\(cuba)"))
                    == ["\(UserHalfSearchTests.volume)/d1"])
            #expect(UserHalfSearchTests.documents(try await UserHalfSearchTests.search(bob, "keywords=treaties&userTagIds=\(cuba)"))
                    == ["\(UserHalfSearchTests.volume)/d2"])
            #expect(try await UserHalfSearchTests.answer(SearchTagCounts.self, bob, "/api/v1/me/search/tags?keywords=treaties").items
                    .map(\.count) == [0, 1], "his Berlin on nothing, his Cuba on d2")

            // Hers are as she left them, imported tag aside.
            var after = aliceAnswers
            after.tags["\(UserHalfSearchTests.volume)/d1"] = [tag, cuba].sorted()
            after.myTags = ["Berlin": 1, "Cuba": 1]
            #expect(try await UserHalfSearchTests.answers(alice, either) == after)
        }
    }

    /// The tag every export of `export(tagging:)` holds, by one id.
    static let sharedTag = UUID(uuidString: "5E17D000-0000-4000-8000-000000000001")!

    /// A Mac export holding one tag, Cuba, on frus1961-63v06's `document`.
    static func export(tagging document: String) throws -> String {
        let time = ImportRouteTests.date("2026-10-24T20:00:00Z")
        let envelope = ResearchDataEnvelope(
            formatVersion: 7, exportedAt: time, notes: [],
            tags: [UserTagExport(id: sharedTag, name: "Cuba", createdAt: time)],
            tagAssignments: [DocumentTagAssignmentExport(id: UUID(), volumeId: "frus1961-63v06", documentId: document, tagId: sharedTag)],
            highlights: [], collections: [], prompts: [], projects: [], summaries: [], classificationOverrides: [])
        return String(decoding: try envelope.jsonData(), as: UTF8.self)
    }
}
