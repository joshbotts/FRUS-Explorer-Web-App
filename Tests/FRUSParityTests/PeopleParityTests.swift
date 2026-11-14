// The People screen and the curators' corrections (PLAN's S21g), held to the app's source at the pin. The rules
// the app's views apply over the kit's rollup, `PersonIndexRow.subtitle`, `PersonIndexSection.makeSections`, the
// sheet's register role, Mentions, the gates of its Career and Subjects and a chip's pivot
// (`VolumeSubjectVolumesSheet.coveringVolumes(excluding:)`), mirrored in `PeopleRules` and `SubjectPivot` (People.swift),
// each where the app writes it; the kit's rules the sheet calls, the lifespan line's `PersonLifespan`, the subjects'
// `PersonSubjectAffinity` and a post's words, called by the server and never copied, and over the fixture index every
// sheet's lifespan line, Career, Subjects and each chip's pivot the app's sheet's over the same kit calls (S21g's
// follow-up); the corrections' sequence, the kit's calls the app's stores make; and the words the browser app takes,
// each where the app's source writes it under its key and in copy.ts's block, "syncs across your devices" the web's
// "for everyone on this server". A pin move that changes one fails here until the web follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct PeopleParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func kit(_ path: String) throws -> String { try SearchSetParityTests.kit(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    /// The rules the server mirrors, where the app's source writes them, and run over entries of each shape.
    @Test func theListsAndTheSheetsRulesAreTheApps() throws {
        let view = try Self.app("Browser/PersonIndexView.swift")
        NoteViewParityTests.expect(view, holds: [
            // PersonIndexRow.subtitle
            "if let roleEra = indexEntry.entry.roleEraSubtitle { parts.append(roleEra) }",
            "if indexEntry.volumeCount > 1 {",
            #"parts.append(String(localized: "people.row.volumeCount", defaultValue: "\(indexEntry.volumeCount) volumes"))"#,
            #"return parts.isEmpty ? nil : parts.joined(separator: " · ")"#,
            // PersonIndexSection.makeSections
            ##"let letter = e.entry.name.isEmpty ? "#" : String(e.entry.name.prefix(1).uppercased())"##,
            "return dict.keys.sorted().map { PersonIndexSection(letter: $0, entries: dict[$0]!) }",
            // The sheet: the register's role where it adds to the description; Mentions; Active; the VIAF link.
            #"&& role.caseInsensitiveCompare(indexEntry.entry.description ?? "") != .orderedSame"#,
            #"Text("\(displayCount) document\(displayCount == 1 ? "" : "s")")"#,
            "if let era = indexEntry.entry.eraText {",
            #"URL(string: "https://viaf.org/viaf/\(viaf)")"#,
            "if let url = authorityEntry?.wikidataURL {",
            // The merge's anchors: each identity's representative record.
            "let mine = try? await store.representativeMember(forRollupId: myRollup)",
            "let theirs = try? await store.representativeMember(forRollupId: otherRollupId)",
            "if members.count > 1 {",
            // The lifespan line: the kit's rule over the authority's entry and the register's career for its slug.
            "guard let slug = authorityEntry?.s, !slug.isEmpty else { return nil }",
            "return POCOMIndexStore.shared?.career(forSlug: slug)",
            "let lifespan = PersonLifespan.text(authority: authorityEntry, career: career)",
            // Career: drawn for a career with a post, the posts in order, each its title, its dates and a note it has.
            "if let career, !career.a.isEmpty { careerSection(career) }",
            "ForEach(career.a) { assignment in",
            "Text(assignment.titleText)",
            "if let range = assignment.dateRangeText {",
            "if let note = assignment.nt, !note.isEmpty {",
            // Subjects: the kit's ranking of the person's mentions over the profiles, eight at most, shown when it has one.
            "let profiles = VolumeSubjectProfilesStore.shared,",
            "let counts = try? await store.volumeMentionCounts(forRollupId: rollupId),",
            "!counts.isEmpty else { return }",
            "subjectAffinities = PersonSubjectAffinity.rank(mentionCounts: counts, topSubjectsByVolume: profiles.topSubjects(forVolumeId:), limit: 8)",
            "if !subjectAffinities.isEmpty {",
            // A chip opens the shared pivot sheet, excluding no volume.
            #"VolumeSubjectVolumesSheet(subject: subject, currentVolumeId: "","#,
        ], file: "PersonIndexView.swift")
        // The server's: the kit's rules called, the view's gates mirrored, and no copy of the lifespan rule, which is the
        // kit's since FRUS-Explorer#1906; the subjects ranked over the profiles, the producer the ranking's sum needs.
        let people = try Self.server("Sources/FRUSLightAPI/People.swift")
        NoteViewParityTests.expect(people, holds: [
            "lifespan: PersonLifespan.text(authority: authority, career: career),",
            "guard let slug = authority?.s, !slug.isEmpty else { return nil }",
            "return register?.career(forSlug: slug)",
            "guard let career, !career.a.isEmpty else { return [] }",
            "title = assignment.titleText",
            "dates = assignment.dateRangeText",
            "note = assignment.nt.flatMap { $0.isEmpty ? nil : $0 }",
            "static let subjectLimit = 8",
            "let counts = try? await persons.volumeMentionCounts(forRollupId: rollupId),",
            "!counts.isEmpty else { return [] }",
            "return PersonSubjectAffinity.rank(mentionCounts: counts, topSubjectsByVolume: profiles.topSubjects(forVolumeId:), limit: subjectLimit)",
        ], file: "People.swift")
        #expect(!people.contains(#""Born \("#) && !people.contains(#""Died \("#), "the lifespan line is the kit's call, not a copy")
        #expect(!people.contains("subjectsByVolume"), "the subjects are ranked over the profiles, never the document index")

        func entry(_ name: String, role: String? = nil, start: Int? = nil, end: Int? = nil, volumes: Int = 1) -> PersonIndexEntry {
            PersonIndexEntry(entry: PersonEntry(ref: "p_X", name: name, description: role, role: role, startYear: start, endYear: end),
                             mentionCount: 3, rollupId: 1, volumeCount: volumes)
        }
        #expect(PeopleRules.subtitle(entry("A", role: "Ambassador", start: 1961, end: 1963, volumes: 2)) == "Ambassador · 1961–1963 · 2 volumes")
        #expect(PeopleRules.subtitle(entry("A", start: 1953)) == "1953")
        #expect(PeopleRules.subtitle(entry("A", volumes: 3)) == "3 volumes")
        #expect(PeopleRules.subtitle(entry("A")) == nil)
        #expect(PeopleRules.letter(of: "adenauer") == "A" && PeopleRules.letter(of: "") == "#")
        #expect(PeopleRules.sections([entry("Bundy"), entry("Acheson"), entry("Ball"), entry("")]).map(\.letter) == ["#", "A", "B"])
        #expect(PeopleRules.sections([entry("Bundy"), entry("Ball")]).first?.entries.map(\.entry.name) == ["Bundy", "Ball"], "the store's order")
        #expect(PeopleRules.registerRole("Ambassador", description: "ambassador") == nil && PeopleRules.registerRole("Ambassador", description: nil) == "Ambassador")
        #expect(PeopleRules.mentions(1) == "1 document" && PeopleRules.mentions(12) == "12 documents")
    }

    /// The sheet's gates that the bundled files never meet, over the kit's own values decoded as its files decode: a
    /// slug left empty names no career; a career with no post draws no Career and still gives the lifespan line its
    /// year; a post with no date gives none, and an empty note draws none.
    @Test func theSheetsGatesHoldOverValuesTheBundledFilesLack() throws {
        let register = try JSONDecoder().decode(POCOMIndex.self, from: Data(#"""
            {"careers": {"b-a": {"n": "B, A", "b": 1900, "a": []},
                         "d-c": {"n": "D, C", "a": [{"r": "Counselor", "nt": ""},
                                                    {"r": "Ambassador", "p": "France", "st": "1961", "nt": "Left post on"}]}}}
            """#.utf8))
        func authority(_ slug: String) throws -> PersonAuthorityIndex.AuthorityEntry {
            try JSONDecoder().decode(PersonAuthorityIndex.AuthorityEntry.self, from: Data(#"{"n": "B, A", "s": "\#(slug)"}"#.utf8))
        }
        let unslugged = try authority(""), unposted = try authority("b-a"), posted = try authority("d-c")
        #expect(PeopleRules.career(unslugged, in: register) == nil, "an empty slug names no career")
        #expect(PeopleRules.career(nil, in: register) == nil && PeopleRules.career(unposted, in: nil) == nil)
        let bare = try #require(PeopleRules.career(unposted, in: register))
        #expect(PeopleRules.posts(bare).isEmpty, "a career with no post draws no Career")
        #expect(PersonLifespan.text(authority: unposted, career: bare) == "Born 1900", "and still fills the lifespan line")
        let full = try #require(PeopleRules.career(posted, in: register))
        #expect(PeopleRules.posts(full).map { [$0.title, $0.dates ?? "-", $0.note ?? "-"] }
            == [["Counselor", "-", "-"], ["Ambassador — France", "from 1961", "Left post on"]])
    }

    /// A chip's pivot, the app's `VolumeSubjectVolumesSheet.coveringVolumes(excluding:)`: the server's two branches are
    /// the app's, in the app's order, the bundled document index first and the profiles only without it, with the
    /// stores passed in; and over the bundled files each branch answers the kit's call, sorted by volume id.
    @Test func theChipsPivotIsTheAppSheetsTwoBranchesInItsOrder() throws {
        let sheet = try Self.app("Browser/VolumeSubjectsView.swift")
        let app = """
            func coveringVolumes(excluding excluded: String) -> [String] { if let index = DocumentSubjectStore.shared { \
            return index.volumeIds(forSubjectRef: subject.ref) .filter { $0 != excluded } .sorted() } \
            guard let profiles = VolumeSubjectProfilesStore.shared else { return [] } \
            return profiles.otherVolumes(forSubjectRef: subject.ref, excluding: excluded).sorted() }
            """
        #expect(sheet.contains(app), "VolumeSubjectsView.swift holds coveringVolumes(excluding:) whole")
        NoteViewParityTests.expect(sheet, holds: [
            // The rows: the volumes but the one in hand, which the person sheet's pivot leaves as none, by their titles.
            "var otherVolumeIds: [String] { coveringVolumes(excluding: currentVolumeId) }",
            "Text(appState.manifestStore.entry(forVolumeId: volumeId)?.title ?? volumeId)",
        ], file: "VolumeSubjectsView.swift")
        // The server's body is the app's, the two stores its parameters.
        let mirrored = app
            .replacingOccurrences(of: "func coveringVolumes(excluding excluded: String) -> [String] {", with: "-> [String] {")
            .replacingOccurrences(of: "if let index = DocumentSubjectStore.shared {", with: "if let index = documents {")
            .replacingOccurrences(of: "subject.ref", with: "ref")
            .replacingOccurrences(of: "guard let profiles = VolumeSubjectProfilesStore.shared else", with: "guard let profiles else")
        #expect(try Self.server("Sources/FRUSLightAPI/People.swift").contains(mirrored), "SubjectPivot.coveringVolumes is the app's body")

        let resources = ServedFixture.resources
        let documents = try JSONDecoder().decode(DocumentSubjectIndex.self,
                                                 from: Data(contentsOf: resources.appendingPathComponent("document-subject-index.json")))
        let profiles = try JSONDecoder().decode(VolumeSubjectProfiles.self,
                                                from: Data(contentsOf: resources.appendingPathComponent("volume-subject-profiles-index.json")))
        var widened = 0
        for subject in profiles.allSubjects {
            let complete = SubjectPivot.coveringVolumes(ref: subject.ref, excluding: "", documents: documents, profiles: profiles)
            #expect(complete == documents.volumeIds(forSubjectRef: subject.ref).sorted(), "\(subject.ref): the document index's")
            let ranked = SubjectPivot.coveringVolumes(ref: subject.ref, excluding: "", documents: nil, profiles: profiles)
            #expect(ranked == profiles.otherVolumes(forSubjectRef: subject.ref, excluding: "").sorted(), "\(subject.ref): the profiles'")
            if complete.count > ranked.count { widened += 1 }
            if let first = complete.first {
                #expect(SubjectPivot.coveringVolumes(ref: subject.ref, excluding: first, documents: documents, profiles: profiles)
                    == Array(complete.dropFirst()), "\(subject.ref): the volume in hand left out")
            }
        }
        #expect(widened > 0, "the document index reaches volumes the profiles' top fifteen do not")
        #expect(SubjectPivot.coveringVolumes(ref: profiles.allSubjects[0].ref, excluding: "", documents: nil, profiles: nil).isEmpty)
    }

    /// The done-when, in Swift: over the fixture index served as the Mac's export, every identity's sheet has the
    /// lifespan line, Career and Subjects the app's sheet computes with the kit's calls over the same index and the
    /// bundled files, each read here apart from the server, and each chip's pivot lists the volumes the app's pivot
    /// sheet lists, in its order, by the catalogue's titles.
    @Test func eachSheetsLifespanCareerSubjectsAndPivotAreTheAppSheetsOverTheFixtures() async throws {
        let resources = ServedFixture.resources
        func file<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            try JSONDecoder().decode(type, from: Data(contentsOf: resources.appendingPathComponent(name)))
        }
        let authorities = try file(PersonAuthorityIndex.self, "person-authority-index.json")
        let register = try POCOMIndex(contentsOf: resources.appendingPathComponent("pocom-index.json"))
        let profiles = try file(VolumeSubjectProfiles.self, "volume-subject-profiles-index.json")
        let documents = try file(DocumentSubjectIndex.self, "document-subject-index.json")
        let catalogue = try FixedVolumeCatalogue(contentsOf: resources.appendingPathComponent("manifest.json")).citableEntries
        let titles = Dictionary(catalogue.map { ($0.volumeId, $0.title) }, uniquingKeysWith: { first, _ in first })
        let persons = try PersonMentionStore(readingDatabaseAt: try await FixtureIndex.value().copy)

        let (sheets, pivots) = try await ServedFixture.run { client, _ in
            let list = try ServedFixture.decode(PeopleList.self, try await client.execute(uri: "/api/v1/people", method: .get))
            var sheets: [PersonSheet] = []
            for row in list.sections.flatMap(\.people) {
                sheets.append(try ServedFixture.decode(PersonSheet.self,
                                                       try await client.execute(uri: "/api/v1/people/\(row.rollupId)", method: .get)))
            }
            var pivots: [String: SubjectVolumes] = [:]
            for ref in Set(sheets.flatMap { $0.subjects.map(\.ref) }) {
                pivots[ref] = try ServedFixture.decode(SubjectVolumes.self,
                                                       try await client.execute(uri: "/api/v1/subjects/\(ref)/volumes", method: .get))
            }
            return (sheets, pivots)
        }
        #expect(sheets.count > 50, "the fixture volumes' people")

        var filled = 0
        for sheet in sheets {
            // `authorityEntry` and `career`, as the app's sheet reads them, then its header's lifespan line.
            let authority = sheet.authorityId.flatMap { authorities.entry(for: $0) }
            let career = authority?.s.flatMap { $0.isEmpty ? nil : register.career(forSlug: $0) }
            #expect(sheet.lifespan == PersonLifespan.text(authority: authority, career: career), "\(sheet.name)'s lifespan line")
            if sheet.lifespan != PersonLifespan.text(born: authority?.b, died: authority?.d) { filled += 1 }
            // `careerSection`, drawn for a career with a post: each post's title, its dates and its note where it has one.
            let posts = (career.map { $0.a.isEmpty ? [] : $0.a } ?? []).map {
                [$0.titleText, $0.dateRangeText ?? "-", $0.nt.flatMap { $0.isEmpty ? nil : $0 } ?? "-"]
            }
            #expect(sheet.career.map { [$0.title, $0.dates ?? "-", $0.note ?? "-"] } == posts, "\(sheet.name)'s Career")
            // `loadSubjectAffinities`: the kit's ranking of the person's mentions in each volume over the profiles.
            let counts = try await persons.volumeMentionCounts(forRollupId: sheet.rollupId)
            let ranked = counts.isEmpty ? [] : PersonSubjectAffinity.rank(mentionCounts: counts,
                                                                          topSubjectsByVolume: profiles.topSubjects(forVolumeId:), limit: 8)
            #expect(sheet.subjects.map { [$0.ref, $0.name, $0.category, String($0.volumeCount)] }
                == ranked.map { [$0.subject.ref, $0.subject.name, $0.subject.category, String($0.volumeCount)] }, "\(sheet.name)'s Subjects")
        }
        // Each chip's pivot: `coveringVolumes(excluding: "")`, the bundled document index's volumes, by volume id.
        for (ref, pivot) in pivots {
            let covering = documents.volumeIds(forSubjectRef: ref).sorted()
            #expect(pivot.ref == ref && pivot.volumes.map(\.volumeId) == covering, "\(ref)'s volumes")
            #expect(pivot.volumes.map(\.title) == covering.map { titles[$0] }, "\(ref)'s titles")
        }

        // Not vacuous: careers, lifespan lines, one with a year the register filled, subjects and a pivot of many volumes.
        let careers = sheets.filter { !$0.career.isEmpty }
        #expect(careers.count > 0 && sheets.contains { $0.lifespan != nil } && pivots.values.contains { $0.volumes.count > 1 })
        #expect(filled > 0, "a year the name authority lacks, filled from the register, as the app's sheet fills it")
        #expect(sheets.filter { !$0.subjects.isEmpty }.count > sheets.count / 2, "most people have subjects")
        print("PeopleParityTests: \(sheets.count) sheets, \(sheets.filter { $0.lifespan != nil }.count) with a lifespan line, "
              + "\(filled) of them with a year the register filled, \(careers.count) with Career, "
              + "\(sheets.filter { !$0.subjects.isEmpty }.count) with Subjects, \(pivots.count) pivots")
    }

    /// The corrections' calls, the app's stores' over the kit's, and the server's over the same calls.
    @Test func theCorrectionsCallTheKitAsTheAppsStoresCallIt() throws {
        let persons = try Self.app("Models/PersonClusterOverrideStore.swift")
        let classification = try Self.app("Models/DocumentClassificationOverride.swift")
        let rail = try Self.app("DocumentView/ResearchRailView.swift")
        NoteViewParityTests.expect(persons, holds: [
            "guard a.volumeId != b.volumeId || a.ref != b.ref else { return nil }",
            "(o.volumeIdA == a.volumeId && o.refA == a.ref && o.volumeIdB == b.volumeId && o.refB == b.ref) ||",
            "(o.volumeIdA == b.volumeId && o.refA == b.ref && o.volumeIdB == a.volumeId && o.refB == a.ref)",
            "$0.overrideKind == .split && $0.volumeIdA == member.volumeId && $0.refA == member.ref",
            "try? await pipeline.consolidatePersonRollup(overrides: overrides, forceReload: false)",
            "sortBy: [SortDescriptor(\\.createdAt, order: .reverse)])",
        ], file: "PersonClusterOverrideStore.swift")
        NoteViewParityTests.expect(classification, holds: [
            "isEditorialNote: restore.parsedIsEditorialNote,",
            "try? await pipeline.applyClassificationOverrides([restoreEntry], volumeId: restore.volumeId)",
            "try? await pipeline.applyClassificationOverrides(snapshot(context: context))",
            "fetchAll(context: context).reversed().map(\\.snapshot)",
        ], file: "DocumentClassificationOverride.swift")
        NoteViewParityTests.expect(rail, holds: [
            "isEditorialNote: !effective,",
            "parsedIsEditorialNote: displayedParsedIsEditorialNote ?? effective,",
            "parsedIsEditorialNote: displayedParsedIsEditorialNote ?? override.parsedIsEditorialNote)",
        ], file: "ResearchRailView.swift")
        let kit = try Self.kit("FRUSCoreKit/TEI/FRUSASTNode.swift")
        #expect(kit.contains("public var isShapedAsEditorialNote: Bool {"), "the rule the indexer applies, which a restore reads")
        // The server's: the same calls, each where the server writes it (the order is `IndexCorrections.apply`'s, read there).
        let corrections = try Self.server("Sources/FRUSLightCore/IndexCorrections.swift")
        NoteViewParityTests.expect(corrections, holds: [
            "isEditorialNote: value, parsedIsEditorialNote: value)], volumeId: document.volumeId)",
            "try await pipeline.applyClassificationOverrides(classification)",
            "try await pipeline.consolidatePersonRollup(overrides: person, forceReload: false)",
            "return ast.isShapedAsEditorialNote",
            "await pipeline.runPostIndexPasses(overrides: person)",
        ], file: "IndexCorrections.swift")
        let store = try Self.server("Sources/FRUSLightCore/UserCorrections.swift")
        NoteViewParityTests.expect(store, holds: [
            "(o.volumeIdA == a.volumeId && o.refA == a.ref && o.volumeIdB == b.volumeId && o.refB == b.ref)",
            "|| (o.volumeIdA == b.volumeId && o.refA == b.ref && o.volumeIdB == a.volumeId && o.refB == a.ref))",
            "$0.kind == .split && $0.volumeIdA == member.volumeId && $0.refA == member.ref",
            "FROM person_overrides ORDER BY created_at DESC NULLS LAST, rowid DESC",
        ], file: "UserCorrections.swift")
        let routes = try Self.server("Sources/FRUSLightAPI/Corrections.swift")
        NoteViewParityTests.expect(routes, holds: [
            "guard let mine = try await served.persons.representativeMember(forRollupId: body.rollupId),",
            "let theirs = try await served.persons.representativeMember(forRollupId: body.otherRollupId) else {",
            "let parsed = await parse(document, reader: reader) ?? effective",
            "let parsed = await parse(document, reader: reader) ?? kept.parsedIsEditorialNote",
        ], file: "Corrections.swift")
    }

    /// The words the browser app takes, where the app's source writes each under its key, and in copy.ts's block.
    @Test func theWebsWordsAreTheApps() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let people = try NoteViewParityTests.block("people", of: raw)
        let classification = try NoteViewParityTests.block("classification", of: raw)
        let view = try Self.app("Browser/PersonIndexView.swift")
        let corrections = try Self.app("Browser/PersonCorrectionsView.swift")
        let rail = try Self.app("DocumentView/ResearchRailView.swift")
        let tagging = try Self.app("Browser/AnnotationsAxisViews.swift")
        let pivot = try Self.app("Browser/VolumeSubjectsView.swift")
        let words: [(source: String, key: String, value: String, block: String, web: String)] = [
            // S21g's follow-up: Subjects, Career and a chip's pivot from a person, which excludes no volume.
            (view, "people.detail.subjects.header", "Subjects", people, "subjectsHeader: 'Subjects'"),
            (view, "people.detail.subjects.note",
             "Volume-level: subjects characteristic of the volumes where this person is mentioned — not per-document tags.", people,
             "subjectsNote: 'Volume-level: subjects characteristic of the volumes where this person is mentioned — not per-document tags.'"),
            (view, "browser.volume.subjectChip.hint", "Shows other volumes covering this subject", people,
             "subjectChipHint: 'Shows other volumes covering this subject'"),
            (view, "people.detail.subjectChip.help", "Subject of volumes where this person is mentioned — click to see all volumes covering it",
             people, "subjectChipHelp: 'Subject of volumes where this person is mentioned — click to see all volumes covering it'"),
            (view, "people.detail.career", "Career", people, "careerHeader: 'Career'"),
            (view, "people.detail.career.source", "From the Department’s Principal Officers and Chiefs of Mission register.", people,
             "careerSource: 'From the Department’s Principal Officers and Chiefs of Mission register.'"),
            (pivot, "browser.volume.subjectVolumes.header.all.one", "1 volume covers this subject", people,
             "subjectVolumesOne: (count: string) => `${count} volume covers this subject`"),
            (pivot, "browser.volume.subjectVolumes.row.hint", "Opens this volume in the browser", people,
             "subjectVolumeHint: 'Opens this volume in the browser'"),
            (pivot, "browser.volume.subjectVolumes.empty.title.none", "No volumes", people, "subjectVolumesEmptyTitle: 'No volumes'"),
            (pivot, "browser.volume.subjectVolumes.empty.message.none", "No volume in the series carries documents on this subject.", people,
             "subjectVolumesEmptyDetail: 'No volume in the series carries documents on this subject.'"),
            (pivot, "common.done", "Done", people, "done: 'Done'"),
            (view, "people.title", "People", people, "title: 'People'"),
            (view, "people.loading", "Loading people\\u{2026}", people, "loading: 'Loading people…'"),
            (view, "people.empty.title", "No People Indexed", people, "emptyTitle: 'No People Indexed'"),
            (view, "people.search.prompt", "Search people", people, "searchPrompt: 'Search people'"),
            (view, "people.corrections.toolbar", "Corrections", people, "corrections: 'Corrections'"),
            (view, "people.row.candidate.a11y", "Possible duplicate", people, "possibleDuplicate: 'Possible duplicate'"),
            (view, "people.row.candidate.help", "May be the same as another person — open to review", people,
             "candidateHelp: 'May be the same as another person — open to review'"),
            (view, "people.detail.reconciled", "Reconciled identity", people, "reconciled: 'Reconciled identity'"),
            (view, "people.detail.reconciled.help", "Matched to the bundled name-authority data", people,
             "reconciledHelp: 'Matched to the bundled name-authority data'"),
            (view, "people.detail.mentions", "Mentions", people, "mentions: 'Mentions'"),
            (view, "people.detail.active", "Active", people, "active: 'Active'"),
            (view, "people.detail.findMentions", "Find all mentions", people, "findMentions: 'Find all mentions'"),
            (view, "people.detail.findMentions.help", "Open Search filtered to documents that mention this person", people,
             "findMentionsHelp: 'Open Search filtered to documents that mention this person'"),
            (view, "people.detail.findMentions.noMentions",
             "This person has no indexed document mentions to open — they appear only in a volume’s front-matter person list.", people,
             "noMentions: 'This person has no indexed document mentions to open — they appear only in a volume’s front-matter person list.'"),
            (view, "people.detail.viaf", "View on VIAF", people, "viaf: 'View on VIAF'"),
            (view, "people.detail.viaf.help", "Open this person’s VIAF authority record", people, "viafHelp: 'Open this person’s VIAF authority record'"),
            (view, "people.detail.wikidata", "View on Wikidata", people, "wikidata: 'View on Wikidata'"),
            (view, "people.detail.wikidata.help", "Open this person’s Wikidata item", people, "wikidataHelp: 'Open this person’s Wikidata item'"),
            (view, "people.detail.mergeManual", "Merge with another person…", people, "mergeManual: 'Merge with another person…'"),
            (view, "people.detail.mergeManual.help", "Combine this identity with another person you choose", people,
             "mergeManualHelp: 'Combine this identity with another person you choose'"),
            (view, "people.detail.possiblySame.header", "Possibly the Same Person", people, "possiblySameHeader: 'Possibly the Same Person'"),
            (view, "people.detail.merge", "Merge", people, "merge: 'Merge'"),
            (view, "people.detail.records.footer", "Separate a record if it refers to a different person.", people,
             "recordsFooter: 'Separate a record if it refers to a different person.'"),
            (view, "people.detail.separate", "Separate", people, "separate: 'Separate'"),
            (view, "people.detail.mergeConfirm.title", "Merge these identities?", people, "mergeConfirmTitle: 'Merge these identities?'"),
            (view, "people.detail.mergeConfirm.action", "Merge", people, "mergeConfirmAction: 'Merge'"),
            (view, "people.detail.mergeConfirm.authorityWarning",
             "These records match different entries in the bundled name-authority data, so they may be distinct. Merge only if you’re sure.", people,
             "mergeAuthorityWarning: 'These records match different entries in the bundled name-authority data, so they may be distinct. Merge only if you’re sure.'"),
            (view, "people.detail.correction.inProgress", "Applying correction…", people, "inProgress: 'Applying correction…'"),
            (tagging, "people.tagging.link", "Volumes that tag people", people, "taggingLink: 'Volumes that tag people'"),
            (corrections, "people.mergePicker.title", "Merge With…", people, "pickerTitle: 'Merge With…'"),
            (corrections, "people.mergePicker.row.hint", "Merges this person into the current identity", people,
             "pickerHint: 'Merges this person into the current identity'"),
            (corrections, "people.corrections.title", "Corrections", people, "correctionsTitle: 'Corrections'"),
            (corrections, "people.corrections.empty.title", "No Corrections", people, "correctionsEmptyTitle: 'No Corrections'"),
            (corrections, "people.corrections.undo", "Undo", people, "undo: 'Undo'"),
            (corrections, "people.corrections.undo.inProgress", "Undoing correction…", people, "undoInProgress: 'Undoing correction…'"),
            (corrections, "people.corrections.undo.done", "Correction undone", people, "undoDone: 'Correction undone'"),
            (rail, "panel.classification.title", "Classification", classification, "title: 'Classification'"),
            (rail, "panel.classification.note", "Editorial note", classification, "note: 'Editorial note'"),
            (rail, "panel.classification.document", "Document", classification, "document: 'Document'"),
            (rail, "panel.classification.restore", "Restore FRUS’s Classification", classification, "restore: 'Restore FRUS’s Classification'"),
            (rail, "panel.classification.toDocument", "Reclassify as Document…", classification, "toDocument: 'Reclassify as Document…'"),
            (rail, "panel.classification.toNote", "Reclassify as Editorial Note…", classification, "toNote: 'Reclassify as Editorial Note…'"),
            (rail, "panel.classification.note.inline", "an editorial note", classification, "noteInline: 'an editorial note'"),
            (rail, "panel.classification.document.inline", "a document", classification, "documentInline: 'a document'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "the app writes \(word.key) as \(word.value)")
            #expect(word.block.contains(NoteViewParityTests.flattened(word.web)), "copy.ts holds \(word.web)")
        }
        // The app's sentences with a value, as copy.ts's functions say them.
        let formats: [(source: String, app: String, block: String, web: String)] = [
            (view, #"defaultValue: "%lld mentions"), Int64(indexEntry.mentionCount))"#, people, "mentionCountSpoken: (count: number) => `${count} mentions`"),
            (view, #"defaultValue: "Merge %@ into this person"), candidate.name))"#, people, "mergeSpoken: (name: string) => `Merge ${name} into this person`"),
            (view, #"defaultValue: "Records in This Identity (\(members.count))"))"#, people,
             "recordsHeader: (count: number) => `Records in This Identity (${count})`"),
            (view, #"defaultValue: "Separate %@ into its own identity"), member.entry.name))"#, people,
             "separateSpoken: (name: string) => `Separate ${name} into its own identity`"),
            (view, #"defaultValue: "Merged %1$@ into %2$@"), otherName, indexEntry.entry.name)"#, people, "mergeDone: (a: string, b: string) => `Merged ${a} into ${b}`"),
            (view, #"defaultValue: "Separated %@"), member.entry.name)"#, people, "separateDone: (name: string) => `Separated ${name}`"),
            (view, #"defaultValue: "“%1$@” and “%2$@” will become a single identity. Merging is transitive — if you later merge a third record with either one, all three become one identity. You can undo this from Corrections."), target.entry.name, indexEntry.entry.name)"#,
             people, "`“${a}” and “${b}” will become a single identity. Merging is transitive — if you later merge a third record with either one, all three become one identity. You can undo this from Corrections.`"),
            (corrections, #"defaultValue: "%1$@ and %2$@ — merged"), nameA, nameB)"#, people, "correctionMerged: (a: string, b: string) => `${a} and ${b} — merged`"),
            (corrections, #"defaultValue: "%@ — separated"), nameA)"#, people, "correctionSeparated: (a: string) => `${a} — separated`"),
            (corrections, #"defaultValue: "Undo: %@"), row.title))"#, people, "undoSpoken: (title: string) => `Undo: ${title}`"),
            (view, #"defaultValue: "People are tagged in %@, and only those volumes' people appear here. In the others, search for the names.")"#,
             people, "`People are tagged in ${volumes}, and only those volumes' people appear here. In the others, search for the names.`"),
            // A chip's value, its count's word the one form at exactly one; and the pivot's count, its many form.
            (view, #"defaultValue: "\(affinity.subject.category), in \(affinity.volumeCount) volume\(affinity.volumeCount == 1 ? "" : "s") mentioning this person"))"#,
             people, "subjectChipValue: (category: string, volumes: string) => `${category}, in ${volumes} mentioning this person`"),
            (view, #"volume\(affinity.volumeCount == 1 ? "" : "s")"#, people, "subjectChipVolumeOne: (count: string) => `${count} volume`"),
            (view, #"volume\(affinity.volumeCount == 1 ? "" : "s")"#, people, "subjectChipVolumeMany: (count: string) => `${count} volumes`"),
            (pivot, #"defaultValue: "%lld volumes cover this subject"), Int64(otherVolumeIds.count))"#, people,
             "subjectVolumesMany: (count: string) => `${count} volumes cover this subject`"),
        ]
        for format in formats {
            let source = format.app.contains("People are tagged") ? tagging : format.source
            #expect(source.contains(NoteViewParityTests.flattened(format.app)), "the app holds \(format.app.prefix(50))")
            #expect(format.block.contains(NoteViewParityTests.flattened(format.web)), "copy.ts holds \(format.web.prefix(50))")
        }
        // "Syncs across your devices", "you" and "Settings ▸ Search": everyone on this server, and here.
        let adapted: [(source: String, app: String, web: String)] = [
            (view, "Use this when one person appears under different names and the app kept them apart. The change syncs across your devices and can be undone from Corrections.",
             "Use this when one person appears under different names and the index kept them apart. The change is for everyone on this server and can be undone from Corrections."),
            (view, "Merge if these records refer to the same person. The change syncs across your devices.",
             "Merge if these records refer to the same person. The change is for everyone on this server."),
            (corrections, "Undoing a correction rebuilds the affected identities and syncs across your devices.",
             "Undoing a correction rebuilds the affected identities for everyone on this server."),
            (rail, "FRUS tags this as %@ — reclassified by you.", "FRUS tags this as ${what} — reclassified on this server."),
            (rail, "FRUS now tags this the same way, so your correction no longer changes anything. You can restore FRUS’s classification.",
             "FRUS now tags this the same way, so this server’s correction no longer changes anything. You can restore FRUS’s classification."),
            (rail, "The document’s body styling, badges, search filters, counts, and exports will follow the new classification on all your devices. Bundled series-analytics dashboards are computed from the published corpus and cannot see this change, and other open windows reflect it when reopened. You can restore FRUS’s own classification at any time from here or from Settings ▸ Search.",
             "The document’s body styling, badges, search filters, counts, and exports will follow the new classification for everyone on this server. Bundled series-analytics dashboards are computed from the published corpus and cannot see this change, and other open pages reflect it when reloaded. You can restore FRUS’s own classification at any time from here."),
        ]
        for line in adapted {
            #expect(line.source.contains(line.app), "the app holds \(line.app.prefix(50))")
            #expect((people + classification).contains(line.web), "copy.ts holds \(line.web.prefix(50))")
        }
    }
}
