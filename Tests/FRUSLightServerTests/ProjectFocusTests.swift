// Project Home's focus subjects and a lead's line through the API (PLAN's S25c): the vocabulary is
// the kit's `VolumeSubjectProfiles` of the bundled file; the subjects a project chose are the
// vocabulary's, in its order, as `ProjectHomeView` filters them; the editor's suggestions are the kit's
// `ProjectFocusSuggestions` over the volumes `ProjectEngagedDocuments` takes, which leave the
// highlights out; the editor's write is the whole list, each ref the vocabulary's or one the project
// holds already; a lead's line is the kit's snippet of the served index, and none while no index is
// served; and a vocabulary the server cannot use, missing, malformed or naming a subject twice, leaves
// the section out while the server answers on.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct ProjectFocusTests {
    static let volume = UserHalfSearchTests.volume

    static func entry(_ n: Int) -> String { String(format: "5C25C000-0000-4000-8000-%012d", n) }

    /// The bundled vocabulary, as the kit decodes it.
    static func bundled() throws -> VolumeSubjectProfiles {
        try JSONDecoder().decode(VolumeSubjectProfiles.self,
                                 from: Data(contentsOf: RepositoryFiles.resources.appendingPathComponent(SubjectProfilesFile.name)))
    }

    static func home(_ browser: Browser, _ project: Project, sourceLocation: SourceLocation = #_sourceLocation) async throws -> ProjectHome {
        let response = try await browser.get("/api/v1/me/projects/\(project.id)/home")
        #expect(response.status == .ok, "\(String(buffer: response.body))", sourceLocation: sourceLocation)
        return try decode(ProjectHome.self, response)
    }

    static func subjects(_ browser: Browser, _ project: Project, _ refs: [String]) async throws -> TestResponse {
        try await browser.send(.patch, "/api/v1/me/projects/\(project.id)", try ProjectHistoryTests.json(["defaultSubjectTagIds": refs]))
    }

    /// The vocabulary is the bundled file's, each subject once, in the kit's order; a project's subjects
    /// are those it chose, in that order, whatever the order they were chosen in; the editor's write
    /// keeps the order given, once each, and is refused a ref the vocabulary does not name, unless the
    /// project holds it already, as the app's toggle keeps what the project holds.
    @Test func theVocabularyIsTheKitsAndAProjectsSubjectsAreItsChoiceInItsOrder() async throws {
        let profiles = try Self.bundled()
        #expect(profiles.allSubjects.count == 380, "the bundled file's vocabulary at the pin")
        #expect(Set(profiles.allSubjects.map(\.ref)).count == profiles.allSubjects.count, "each ref once")
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        #expect(fixture.server.resources.subjectProfiles.profiles?.allSubjects == profiles.allSubjects)
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let vocabulary = try decode(FocusSubjectList.self, try await owner.get("/api/v1/me/focus-subjects"))
            #expect(vocabulary.total == 380 && vocabulary.items == profiles.allSubjects.map(FocusSubject.init))
            #expect(problemCode(try await owner.get("/api/v1/me/focus-subjects?q=war")) == "UNKNOWN_PARAMETER")

            let grain = try await ProjectHistoryTests.made(owner, "Grain")
            let empty = try await Self.home(owner, grain)
            #expect(empty.focusSubjects == [] && empty.focusSuggestions == [], "the section shows, with nothing chosen or suggested")

            let all = profiles.allSubjects.map(\.ref)
            let (first, second, third) = (all[3], all[10], all[200])
            let chosen = try decode(Project.self, try await Self.subjects(owner, grain, [third, first, second, first]))
            #expect(chosen.defaultSubjectTagIds == [third, first, second], "the order given, once each")
            let home = try await Self.home(owner, grain)
            #expect(home.focusSubjects?.map(\.ref) == [first, second, third], "the vocabulary's order")
            #expect(home.project == chosen && home.focusSubjects?.first == FocusSubject(profiles.allSubjects[3]))

            let unknown = try await Self.subjects(owner, grain, [first, "no-such-subject"])
            #expect(unknown.status == .notFound && problemCode(unknown) == "SUBJECT_NOT_FOUND")
            #expect(try decode(Project.self, try await owner.get("/api/v1/me/projects/\(grain.id)")).defaultSubjectTagIds
                    == [third, first, second], "nothing written")
            let typed = try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"defaultSubjectTagIds": "\#(first)"}"#)
            #expect(typed.status == .badRequest && problemCode(typed) == "INVALID_FIELD")

            // A subject a Mac's export holds that the vocabulary no longer names: never shown, and kept by
            // the editor's write as the app's toggle keeps it; another such ref is refused.
            try fixture.rows.run("UPDATE projects SET default_subject_tag_ids = ?, last_modified = ? WHERE user_id = 'owner' AND upper(id) = upper(?)",
                                 [.text(TagReferences.encode(["retired-subject", second])), .text("2026-01-01T00:00:00.000Z"),
                                  .text(grain.id)])
            #expect(try await Self.home(owner, grain).focusSubjects?.map(\.ref) == [second])
            let kept = try decode(Project.self, try await Self.subjects(owner, grain, ["retired-subject", second, third]))
            #expect(kept.defaultSubjectTagIds == ["retired-subject", second, third])
            #expect(kept.lastModified == UserStoreDate.text(UserDataFixture.now), "a change stamps it")
            #expect(problemCode(try await Self.subjects(owner, grain, ["another-retired-subject"])) == "SUBJECT_NOT_FOUND")

            // The same list again writes nothing, as a toggle that changes nothing would.
            try fixture.rows.run("UPDATE projects SET last_modified = ? WHERE user_id = 'owner' AND upper(id) = upper(?)",
                                 [.text("2026-01-01T00:00:00.000Z"), .text(grain.id)])
            let same = try decode(Project.self, try await Self.subjects(owner, grain, ["retired-subject", second, third]))
            #expect(same.lastModified == "2026-01-01T00:00:00.000Z", "nothing written")
            let cleared = try decode(Project.self, try await Self.subjects(owner, grain, []))
            #expect(cleared.defaultSubjectTagIds.isEmpty && cleared.lastModified == UserStoreDate.text(UserDataFixture.now))
            #expect(try await Self.home(owner, grain).focusSubjects == [])
        }
    }

    /// "Suggested from your volumes" is the kit's suggestions over the volumes the project engages, as
    /// the app's `ProjectEngagedDocuments` gathers them: the documents read while it was active, its
    /// notes on a document and its collections' document entries; not another project's visit, a
    /// collection not filed under it, a heading's entry or a highlight, which the coverage tiles count
    /// and the app's editor does not; eight at most, the subjects chosen left out.
    @Test func theEditorSuggestsTheKitsSubjectsFromTheVolumesTheProjectEngages() async throws {
        let profiles = try Self.bundled()
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let berlin = try await ProjectHistoryTests.made(owner, "Berlin")
            _ = try await ProjectHistoryTests.visit(owner, "d1", volume: "frus1964-68v14")
            let grain = try await ProjectHistoryTests.made(owner, "Grain")
            _ = try await ProjectHistoryTests.visit(owner, "d1")
            var note = NoteJSON(bodyText: "Filed under Grain")
            note.projectIds = [grain.id]
            let filed = try decode(Note.self, try await owner.send(.post, "/api/v1/me/volumes/frus1894Nicaragua/documents/d1/notes", note.json))

            // A collection under Grain, with a document's entry and a heading's, and one under no project;
            // and a highlight that names Grain's note, on a document of a volume nothing else engages.
            let version = ResearchDataEnvelope.currentFormatVersion
            let filedUnder = try #require(UUID(uuidString: grain.id))
            let collected = CollectionExport(
                id: UUID(uuidString: Self.entry(1))!, name: "Grain", projectIds: [filedUnder],
                entries: [CollectionEntryExport(id: UUID(uuidString: Self.entry(2))!, documentId: "d1", volumeId: "frus1969-76v01",
                                                sortOrder: 0, selectedNoteIds: [], kind: "document"),
                          CollectionEntryExport(id: UUID(uuidString: Self.entry(3))!, documentId: "d1", volumeId: "frus1969-76v12",
                                                sortOrder: 1, selectedNoteIds: [], kind: "heading", text: "Heading")])
            let unfiled = CollectionExport(
                id: UUID(uuidString: Self.entry(4))!, name: "Elsewhere", projectIds: [],
                entries: [CollectionEntryExport(id: UUID(uuidString: Self.entry(5))!, documentId: "d1", volumeId: "frus1945v03",
                                                sortOrder: 0, selectedNoteIds: [], kind: "document")])
            let collections = try #require(UserStoreSchema.table(for: "Collection"))
            let entries = try #require(UserStoreSchema.table(for: "CollectionEntry"))
            for collection in [collected, unfiled] {
                try fixture.store.addResearchRow(collections, MacImport.collection(collection, version: version).values, for: "owner",
                                                 outsideSearch: true)
                for entry in collection.entries {
                    try fixture.store.addResearchRow(entries, MacImport.entry(entry, of: collection, version: version).values,
                                                     for: "owner", outsideSearch: true)
                }
            }
            let highlight = DocumentHighlightExport(id: UUID(uuidString: Self.entry(6))!, volumeId: "frus1977-80v24", documentId: "d1",
                                                    startOffset: 0, endOffset: 4, colorTag: "yellow",
                                                    noteId: UUID(uuidString: filed.id), selectedText: "Text", renderingVersion: "v1")
            try fixture.store.addResearchRow(try #require(UserStoreSchema.table(for: "DocumentHighlight")),
                                             MacImport.highlight(highlight).values, for: "owner", outsideSearch: true)

            let engaged: Set<String> = [Self.volume, "frus1894Nicaragua", "frus1969-76v01"]
            let expected = ProjectFocusSuggestions.suggestions(engagedVolumeIds: engaged, profiles: profiles, excluding: [])
            #expect(expected.count == 8, "the kit's default, which the app's editor takes")
            let home = try await Self.home(owner, grain)
            #expect(home.focusSuggestions == expected.map(FocusSubject.init))
            // Each volume the app's rule leaves out would change them: the test would see one counted.
            for outside in ["frus1964-68v14", "frus1945v03", "frus1969-76v12", "frus1977-80v24"] {
                let counted = ProjectFocusSuggestions.suggestions(engagedVolumeIds: engaged.union([outside]), profiles: profiles, excluding: [])
                #expect(counted.map(\.ref) != expected.map(\.ref), "\(outside) changes the suggestions")
            }
            // The coverage tiles' gatherer counts the highlight of Grain's note, as the app's tiles do; the editor does not.
            let grainsNote = ResearchNoteExport(id: try #require(UUID(uuidString: filed.id)), documentId: "d1", volumeId: "frus1894Nicaragua",
                                                bodyText: "", projectIds: [filedUnder], userTagIds: [], selectedSummaryIds: [],
                                                linkedHighlightIds: [])
            let gathered = DocumentEngagementService.gather(
                among: ProjectHomeRoutes.engagementSources(visits: [], notes: [grainsNote], highlights: [highlight], collections: []),
                forProject: filedUnder)
            #expect(gathered.annotated == ["frus1894Nicaragua/d1", "frus1977-80v24/d1"])

            // Two chosen: the suggestions leave them out and take the next, as the kit ranks them.
            let picked = [expected[0].ref, expected[2].ref]
            #expect(try await Self.subjects(owner, grain, picked).status == .ok)
            let after = try await Self.home(owner, grain)
            #expect(after.focusSubjects?.map(\.ref) == profiles.allSubjects.map(\.ref).filter(picked.contains))
            #expect(after.focusSuggestions == ProjectFocusSuggestions.suggestions(engagedVolumeIds: engaged, profiles: profiles,
                                                                                  excluding: Set(picked)).map(FocusSubject.init))
            #expect(after.focusSuggestions?.contains { picked.contains($0.ref) } == false)
            // Berlin's own: its visit's volume alone.
            #expect(try await Self.home(owner, berlin).focusSuggestions
                    == ProjectFocusSuggestions.suggestions(engagedVolumeIds: ["frus1964-68v14"], profiles: profiles, excluding: [])
                        .map(FocusSubject.init))
        }
    }

    /// The app's rule over a project's records, mirrored, with what its records can hold: a note on no
    /// document, a heading's or a prose block's entry and an older file's entry with no kind.
    @Test func theEngagedDocumentsAreProjectEngagedDocumentsRule() throws {
        let project = UUID()
        let note = { (volume: String, document: String) in
            ResearchNoteExport(id: UUID(), documentId: document, volumeId: volume, bodyText: "", projectIds: [project], userTagIds: [],
                               selectedSummaryIds: [], linkedHighlightIds: [])
        }
        let entry = { (volume: String, document: String, kind: String?) in
            CollectionEntryExport(id: UUID(), documentId: document, volumeId: volume, sortOrder: 0, selectedNoteIds: [], kind: kind)
        }
        let keys = ProjectFocusRoutes.engagedKeys(
            collections: [CollectionExport(id: UUID(), name: "A", projectIds: [project],
                                           entries: [entry("v3", "d3", "document"), entry("v4", "d4", nil), entry("v5", "d5", "heading"),
                                                     entry("v6", "d6", "excerpt"), entry("", "d7", "document"), entry("v8", "", "document")])],
            notes: [note("v1", "d1"), note("", ""), note("v9", "")],
            visits: [ReadingHistoryEntryExport(id: UUID(), documentId: "d2", volumeId: "v2", projectId: project),
                     ReadingHistoryEntryExport(id: UUID(), documentId: "", volumeId: "v10", projectId: project)])
        #expect(keys == ["v1/d1", "v2/d2", "v3/d3", "v4/d4"])
        #expect(ProjectFocusRoutes.engagedVolumeIds(keys.union(["v1/d9/x"])) == ["v1", "v2", "v3", "v4"], "a key's volume is what comes before its first /")
    }

    /// A lead's line is the kit's snippet of the served index, for the leads shown, and none for a lead
    /// the index does not hold or while no index is served.
    @Test func aLeadsLineIsTheKitsSnippetOfTheServedIndex() async throws {
        for indexed in [true, false] {
            let fixture = try await UserDataFixture(indexed: indexed)
            defer { withExtendedLifetime(fixture) {} }
            try await fixture.app.test(.router) { client in
                let owner = Browser(client: client)
                let grain = try await ProjectHistoryTests.made(owner, "Grain")
                for (n, volume, document) in [(1, Self.volume, "d1"), (2, Self.volume, "d3"), (3, "frus1894Nicaragua", "d1")] {
                    try fixture.rows.run(
                        """
                        INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score, contributing_seed_keys,
                                                   header, is_editorial_note, first_surfaced_at, last_computed_at, dismissed)
                            VALUES ('owner', ?, ?, ?, ?, ?, '[]', 'Lead', 0, ?, ?, 0)
                        """, [.text(Self.entry(10 + n)), .text(grain.id), .text(volume), .text(document), .real(Double(10 - n)),
                              .text(UserStoreDate.text(UserDataFixture.now)), .text(UserStoreDate.text(UserDataFixture.now))])
                }
                let leads = try await Self.home(owner, grain).leads
                #expect(leads.map(\.documentId) == ["d1", "d3", "d1"])
                guard indexed else {
                    #expect(leads.allSatisfy { $0.snippet == nil }, "no index served, no lines")
                    return
                }
                let served = try await ServedIndexProvider(state: fixture.server.state, resources: fixture.server.resources,
                                                           volumesDirectory: fixture.server.files.volumesDirectory).served()
                let lines = try await served.pipeline.documentSnippets(forKeys: leads.map { (volumeId: $0.volumeId, documentId: $0.documentId) })
                #expect(leads.map(\.snippet) == [lines["\(Self.volume)/d1"], nil, lines["frus1894Nicaragua/d1"]])
                #expect(leads[0].snippet == SyntheticExport.documents[0].body, "the document's text, as the index holds it")
                #expect(leads[2].snippet == SyntheticExport.documents[2].body)
            }
        }
    }

    /// A vocabulary that is missing, does not decode, or names a subject twice, on which the kit's
    /// suggestions would trap, leaves the section and its suggestions out of Project Home and refuses
    /// the vocabulary's route and a new subject, while every other part of Project Home, the project's
    /// other fields, a ref the project holds and the server itself answer on.
    @Test func aVocabularyTheServerCannotUseLeavesTheSectionOut() async throws {
        let repeated = #"""
            {"generated": "2026-11-10", "provenance": "a test", "vocab": [{"r": "repeated", "n": "Once", "c": "C", "s": "S"},
             {"r": "repeated", "n": "Twice", "c": "C", "s": "S"}],
             "profiles": [{"v": "frus1961-63v06", "e": [{"i": 0, "w": 1.0}, {"i": 1, "w": 0.5}]}]}
            """#
        // The kit reads both rows as subjects, which its suggestions' dictionary by ref would trap on.
        let decoded = try JSONDecoder().decode(VolumeSubjectProfiles.self, from: Data(repeated.utf8))
        #expect(decoded.allSubjects.map(\.ref) == ["repeated", "repeated"])
        let cases: [(name: String, contents: String?, reason: String)] = [
            ("a repeated ref", repeated, "lists the subject repeated twice"),
            ("no file", nil, "is missing from the app's data files"),
            ("no JSON", "{\"vocab\": [", "does not decode"),
        ]
        let base = try TestResources.value()
        for broken in cases {
            let directory = try TemporaryDirectory()
            let file = directory.url.appendingPathComponent(SubjectProfilesFile.name)
            if let contents = broken.contents { try Data(contents.utf8).write(to: file) }
            guard case .unavailable(let reason) = SubjectProfilesFile.decode(file) else {
                Issue.record("\(broken.name): the server would use it")
                continue
            }
            #expect(reason.contains(broken.reason), "\(broken.name): \(reason)")
            let resources = ServerResources(directory: directory.url, manifest: base.manifest, brokenRefs: base.brokenRefs,
                                            citedPages: base.citedPages, indexing: base.indexing)
            let fixture = try await UserDataFixture()
            defer { withExtendedLifetime((fixture, directory)) {} }
            let app = Application(router: ServedRouter(base: .root, router: buildRouter(
                state: fixture.server.state, resources: resources, reader: fixture.server.reader, userData: fixture.services)))
            try await app.test(.router) { client in
                let owner = Browser(client: client)
                let grain = try await ProjectHistoryTests.made(owner, "Grain")
                try fixture.rows.run("UPDATE projects SET default_subject_tag_ids = ? WHERE user_id = 'owner' AND upper(id) = upper(?)",
                                     [.text(TagReferences.encode(["held"])), .text(grain.id)])
                let home = try await Self.home(owner, grain)
                #expect(home.focusSubjects == nil && home.focusSuggestions == nil, "\(broken.name): no section")
                #expect(home.project.defaultSubjectTagIds == ["held"] && home.project.name == "Grain")
                let vocabulary = try await owner.get("/api/v1/me/focus-subjects")
                #expect(vocabulary.status == .serviceUnavailable && problemCode(vocabulary) == "SUBJECTS_UNAVAILABLE", "\(broken.name)")
                let added = try await Self.subjects(owner, grain, ["held", "repeated"])
                #expect(added.status == .serviceUnavailable && problemCode(added) == "SUBJECTS_UNAVAILABLE", "\(broken.name)")
                #expect(try decode(Project.self, try await Self.subjects(owner, grain, ["held"])).defaultSubjectTagIds == ["held"])
                #expect(try decode(Project.self, try await Self.subjects(owner, grain, [])).defaultSubjectTagIds.isEmpty)
                #expect(try await owner.send(.patch, "/api/v1/me/projects/\(grain.id)", #"{"name": "Grain trade"}"#).status == .ok)
                #expect(try await client.execute(uri: "/healthz", method: .get).status == .ok, "the server answers on")
            }
        }
    }
}
