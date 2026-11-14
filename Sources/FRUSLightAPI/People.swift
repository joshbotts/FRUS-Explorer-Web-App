// The People screen (PLAN's S21g), `/people`, which phase 1 left: the kit's person rollup over the served index,
// as the app's `PersonIndexView` lists it (`Browser/PersonIndexView.swift`, app code), and an identity's sheet,
// its `PersonIndexDetailSheet`. GET /api/v1/people gives every identity, the kit's
// `PersonMentionStore.allPersonsSortedByName()` in its order, grouped by the first letter of the name as the app's
// `PersonIndexSection.makeSections` groups them, each row's line the app's `PersonIndexRow.subtitle` (the kit's
// `roleEraSubtitle` and the volume count), its mention count and whether a "possibly the same person" suggestion
// waits (`rollupIdsWithCandidates()`); GET /api/v1/people/{rollupId} gives the sheet: the name, the volumes'
// description; the lifespan line, the kit's `PersonLifespan.text(authority:career:)`, the bundled name authority's
// years with a year it lacks filled from the register of principal officers and chiefs of mission (POCOM), with the
// authority's role and the reconciled mark, as the app's sheet reads them; the mentions and Active (the kit's
// `eraText`); Subjects, the kit's `PersonSubjectAffinity.rank` of the person's mentions in each volume over the
// bundled volume profiles; the VIAF and Wikidata links; Career, the register's posts for the authority's slug
// (`POCOMIndex.career(forSlug:)`), each its kit title, dates and note; the suggestions and the records the identity
// holds (S21g's follow-up, after FRUS-Explorer#1906). GET /api/v1/subjects/{ref}/volumes is a subject chip's pivot,
// the app's `VolumeSubjectVolumesSheet` (`Browser/VolumeSubjectsView.swift`): every volume covering the subject.
// The rules the views apply are the app's, mirrored as `PeopleRules` and `SubjectPivot` and held to its source by
// `PeopleParityTests`; the kit's rules are called, never copied (CLAUDE.md, rule 4).
//
// A rollup's ids are renumbered whenever it is built again, so each answer carries `version`, a digest of the list
// it came from, which a correction sends back (Corrections.swift): one made against another rollup is refused,
// since its ids may name other people now.

import Crypto
import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The app's views' rules over the rollup's rows and the sheet's sections, mirrored from `Browser/PersonIndexView.swift`.
/// The kit's rules the sheet reads, the lifespan line's, the subjects' ranking and a post's words, are the kit's calls.
enum PeopleRules {
    /// `PersonIndexRow.subtitle`: `role · era · N volumes`, leaving out whichever is absent, the count only past one.
    static func subtitle(_ entry: PersonIndexEntry) -> String? {
        var parts: [String] = []
        if let roleEra = entry.entry.roleEraSubtitle { parts.append(roleEra) }
        if entry.volumeCount > 1 { parts.append("\(entry.volumeCount) volumes") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// `PersonIndexSection.makeSections`'s letter: the name's first character, uppercased; `#` for no name.
    static func letter(of name: String) -> String {
        name.isEmpty ? "#" : String(name.prefix(1).uppercased())
    }

    /// `PersonIndexSection.makeSections`: the entries by their letter, the letters in order, each section's entries
    /// in the order the store gave them.
    static func sections(_ entries: [PersonIndexEntry]) -> [(letter: String, entries: [PersonIndexEntry])] {
        var byLetter: [String: [PersonIndexEntry]] = [:]
        for entry in entries { byLetter[letter(of: entry.entry.name), default: []].append(entry) }
        return byLetter.keys.sorted().map { ($0, byLetter[$0]!) }
    }

    /// The sheet's `career`: the register's entry for the slug the name authority gives the person, none without one.
    static func career(_ authority: PersonAuthorityIndex.AuthorityEntry?, in register: POCOMIndex?) -> POCOMCareer? {
        guard let slug = authority?.s, !slug.isEmpty else { return nil }
        return register?.career(forSlug: slug)
    }

    /// Career's rows, drawn only for a career that holds a post (`if let career, !career.a.isEmpty`), in the
    /// register's order, each the kit's title and dates and the register's note where it has one.
    static func posts(_ career: POCOMCareer?) -> [PersonSheet.Post] {
        guard let career, !career.a.isEmpty else { return [] }
        return career.a.map(PersonSheet.Post.init)
    }

    /// How many subjects the sheet's Subjects shows (`loadSubjectAffinities`).
    static let subjectLimit = 8

    /// The sheet's Subjects (`loadSubjectAffinities`): the kit's ranking of the person's mentions in each volume
    /// over the bundled volume profiles, the producer its ranking needs, never the document subject index, whose
    /// scores are another measure (`ResolvedSubject.score`); none without the profiles or a mention, and none when
    /// the store cannot count them, as the app's `try?` shows none.
    static func subjects(_ persons: PersonMentionStore, rollupId: Int,
                         profiles: VolumeSubjectProfiles?) async -> [PersonSubjectAffinity.Ranked] {
        guard let profiles,
              let counts = try? await persons.volumeMentionCounts(forRollupId: rollupId),
              !counts.isEmpty else { return [] }
        return PersonSubjectAffinity.rank(mentionCounts: counts, topSubjectsByVolume: profiles.topSubjects(forVolumeId:),
                                          limit: subjectLimit)
    }

    /// The register's role, as the sheet shows it: only when it says something the volumes' own description does not.
    static func registerRole(_ role: String?, description: String?) -> String? {
        guard let role, !role.isEmpty, role.caseInsensitiveCompare(description ?? "") != .orderedSame else { return nil }
        return role
    }

    /// The sheet's Mentions: "1 document", "12 documents".
    static func mentions(_ count: Int) -> String { "\(count) document\(count == 1 ? "" : "s")" }

    /// The digest a list's rows give, which says whether two answers came from one rollup.
    static func version(_ entries: [PersonIndexEntry]) -> String {
        var hasher = SHA256()
        for entry in entries {
            let line = "\(entry.rollupId.map(String.init) ?? "-")\u{1F}\(entry.entry.name)\u{1F}\(entry.mentionCount)\u{1F}\(entry.volumeCount)\u{1F}\(entry.authorityId.map(String.init) ?? "-")\n"
            hasher.update(data: Data(line.utf8))
        }
        return hasher.finalize().prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

/// The served rollup's list, read once for the stack that keeps it (`ServedIndex.people`), as its facets are.
public actor ServedPeople {
    struct List: Sendable {
        let entries: [PersonIndexEntry]
        let byRollup: [Int: PersonIndexEntry]
        let candidates: Set<Int>
        let version: String
    }

    private var list: List?

    public init() {}

    /// The version of the rollup `persons` reads now, uncached: on a Standalone server a writer's job may have
    /// rebuilt it under a stack's list, which is read again only once the stack is opened again after the job.
    static func version(now persons: PersonMentionStore) async throws -> String {
        PeopleRules.version(try await persons.allPersonsSortedByName().filter { $0.rollupId != nil })
    }

    /// The kit's list of the rollup `persons` reads, read on first use.
    func list(_ persons: PersonMentionStore) async throws -> List {
        if let list { return list }
        let entries = try await persons.allPersonsSortedByName().filter { $0.rollupId != nil }
        let candidates = (try? await persons.rollupIdsWithCandidates()) ?? []
        var byRollup: [Int: PersonIndexEntry] = [:]
        for entry in entries { if let id = entry.rollupId { byRollup[id] = entry } }
        let read = List(entries: entries, byRollup: byRollup, candidates: candidates, version: PeopleRules.version(entries))
        list = read
        return read
    }
}

/// One identity in the list.
struct PersonRow: Codable, Equatable, Sendable {
    let rollupId: Int
    let name: String
    let subtitle: String?
    let mentionCount: Int
    let volumeCount: Int
    /// The bundled name authority's id, which a merge's confirmation compares.
    let authorityId: Int?
    /// Whether a "possibly the same person" suggestion waits for it.
    let possibleDuplicate: Bool

    init(_ entry: PersonIndexEntry, candidates: Set<Int>) {
        rollupId = entry.rollupId ?? 0
        name = entry.entry.name
        subtitle = PeopleRules.subtitle(entry)
        mentionCount = entry.mentionCount
        volumeCount = entry.volumeCount
        authorityId = entry.authorityId
        possibleDuplicate = entry.rollupId.map(candidates.contains) ?? false
    }
}

/// The list, its sections the app's.
struct PeopleList: ResponseEncodable, Codable, Equatable, Sendable {
    struct Section: Codable, Equatable, Sendable {
        let letter: String
        let people: [PersonRow]
    }

    /// The digest of the rollup it came from, which a correction sends back.
    let version: String
    let count: Int
    let sections: [Section]
}

/// An identity's sheet.
struct PersonSheet: ResponseEncodable, Codable, Equatable, Sendable {
    struct Candidate: Codable, Equatable, Sendable {
        let rollupId: Int
        let name: String
        let reason: String?
    }

    struct Record: Codable, Equatable, Sendable {
        let volumeId: String
        let ref: String
        let name: String
    }

    /// A subject chip: a subject of the volumes the person is mentioned in (`PersonSubjectAffinity.Ranked`).
    struct Subject: Codable, Equatable, Sendable {
        /// The subject's ref, which its pivot is asked by.
        let ref: String
        let name: String
        let category: String
        /// How many of the volumes the person is mentioned in carry it, which the chip's spoken value says.
        let volumeCount: Int

        init(_ ranked: PersonSubjectAffinity.Ranked) {
            ref = ranked.subject.ref
            name = ranked.subject.name
            category = ranked.subject.category
            volumeCount = ranked.volumeCount
        }
    }

    /// A post of Career (`POCOMAssignment`), known by its place in the list: the kit's `id` is not one, since the
    /// register gives one career two posts of one title, place and dates that end apart (`taylor-francis-xavier`).
    struct Post: Codable, Equatable, Sendable {
        /// The kit's `titleText`: "Under Secretary of State" or "Ambassador — France".
        let title: String
        /// The kit's `dateRangeText`, the register's dates as it writes them; nil where it has none.
        let dates: String?
        /// The register's note on the post's end ("Left Tehran on"), nil where it has none.
        let note: String?

        init(_ assignment: POCOMAssignment) {
            title = assignment.titleText
            dates = assignment.dateRangeText
            note = assignment.nt.flatMap { $0.isEmpty ? nil : $0 }
        }
    }

    let version: String
    let rollupId: Int
    let name: String
    /// The volumes' own words, from their lists of persons.
    let description: String?
    /// The lifespan line, the kit's `PersonLifespan.text(authority:career:)`: the name authority's years, a year it
    /// lacks filled from the register's career; and the authority's role where it adds to the description.
    let lifespan: String?
    let registerRole: String?
    /// Whether the identity is matched to the bundled name authority.
    let reconciled: Bool
    let authorityId: Int?
    let mentionCount: Int
    /// "12 documents", the sheet's Mentions.
    let mentions: String
    /// The volumes' years, the kit's `eraText`.
    let active: String?
    /// Subjects, the kit's ranking in its order, at most eight; empty where the sheet shows no Subjects section.
    let subjects: [Subject]
    let viafURL: String?
    let wikidataURL: String?
    /// Career, the register's posts in its order; empty where the sheet shows no Career section.
    let career: [Post]
    /// "Possibly the Same Person".
    let candidates: [Candidate]
    /// "Records in This Identity", each a volume's persons-list record, which Separate names.
    let records: [Record]
}

/// A subject's covering volumes, which its chip opens, each with the catalogue's title.
struct SubjectVolumes: ResponseEncodable, Codable, Equatable, Sendable {
    struct Volume: Codable, Equatable, Sendable {
        let volumeId: String
        /// The catalogue's title; nil for a volume the catalogue does not list, whose row names it by its id.
        let title: String?
    }

    let ref: String
    /// The sheet's order, by volume id.
    let volumes: [Volume]
}

/// A subject chip's pivot, the app's `VolumeSubjectVolumesSheet` (`Browser/VolumeSubjectsView.swift`), mirrored.
enum SubjectPivot {
    /// `coveringVolumes(excluding:)`: every volume whose documents carry the subject, from the bundled document
    /// subject index, which is complete; else from the volume profiles, whose reach is each volume's top fifteen; the
    /// volume `excluded` left out, `""` leaving out none, as the person sheet's pivot passes; sorted by volume id.
    static func coveringVolumes(ref: String, excluding excluded: String, documents: DocumentSubjectIndex?,
                                profiles: VolumeSubjectProfiles?) -> [String] {
        if let index = documents {
            return index.volumeIds(forSubjectRef: ref)
                .filter { $0 != excluded }
                .sorted()
        }
        guard let profiles else { return [] }
        return profiles.otherVolumes(forSubjectRef: ref, excluding: excluded).sorted()
    }
}

extension ServerResources {
    /// `PersonAuthorityIndexStore.shared`, app code: the bundled name authority the sheet reads the register's life
    /// years, role and Wikidata link from, decoded once on first use; nil for a file missing or malformed, and the
    /// sheet then shows what the volumes say alone.
    var personAuthority: PersonAuthorityIndex? { people.personAuthority.value(in: directory) }

    /// `POCOMIndexStore.shared`, app code: the register of principal officers and chiefs of mission, whose careers the
    /// sheet's Career draws and whose life years fill the lifespan line's gaps, decoded once on first use by the kit's
    /// loader; nil for a file missing or malformed, and the sheet then has no Career and the authority's years alone.
    var careerRegister: POCOMIndex? { people.careerRegister.value(in: directory) }
}

/// The bundled files the People screen reads.
final class PeopleFiles: Sendable {
    let personAuthority = DecodedFile("person-authority-index.json") { url -> PersonAuthorityIndex in
        try JSONDecoder().decode(PersonAuthorityIndex.self, from: Data(contentsOf: url))
    }
    let careerRegister = DecodedFile("pocom-index.json") { try POCOMIndex(contentsOf: $0) }
}

enum PeopleRoutes {
    static func add(to router: Router<APIRequestContext>, provider: ServedIndexProvider, resources: ServerResources) {
        router.get("/api/v1/people") { request, _ -> PeopleList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let served = try await provider.served()
            let list = try await served.people.list(served.persons)
            let sections = PeopleRules.sections(list.entries).map {
                PeopleList.Section(letter: $0.letter, people: $0.entries.map { PersonRow($0, candidates: list.candidates) })
            }
            return PeopleList(version: list.version, count: sections.reduce(0) { $0 + $1.people.count }, sections: sections)
        }

        router.get("/api/v1/people/:rollupId") { request, context -> PersonSheet in
            try FormQuery(request.uri.query).refuseUnknown([])
            let served = try await provider.served()
            let list = try await served.people.list(served.persons)
            let entry = try person(context, in: list)
            let rollupId = entry.rollupId ?? 0
            let candidates = (try await served.persons.candidates(forRollupId: rollupId)).map {
                PersonSheet.Candidate(rollupId: $0.rollupId, name: $0.name, reason: $0.reason)
            }
            let records = try await served.persons.members(forRollupId: rollupId).map {
                PersonSheet.Record(volumeId: $0.volumeId, ref: $0.entry.ref, name: $0.entry.name)
            }
            // The three bundled files, each decoded once, the first time off the cooperative pool.
            let (authorities, register, profiles) = try await Blocking.run {
                (resources.personAuthority, resources.careerRegister, resources.subjectProfiles.profiles)
            }
            let authority = entry.authorityId.flatMap { authorities?.entry(for: $0) }
            let career = PeopleRules.career(authority, in: register)
            let subjects = await PeopleRules.subjects(served.persons, rollupId: rollupId, profiles: profiles)
            return PersonSheet(
                version: list.version, rollupId: rollupId, name: entry.entry.name,
                description: entry.entry.description.flatMap { $0.isEmpty ? nil : $0 },
                lifespan: PersonLifespan.text(authority: authority, career: career),
                registerRole: PeopleRules.registerRole(authority?.r, description: entry.entry.description),
                reconciled: entry.authorityId != nil, authorityId: entry.authorityId,
                mentionCount: entry.mentionCount, mentions: PeopleRules.mentions(entry.mentionCount),
                active: entry.entry.eraText,
                subjects: subjects.map(PersonSheet.Subject.init),
                viafURL: entry.viafId.flatMap { $0.isEmpty ? nil : URL(string: "https://viaf.org/viaf/\($0)")?.absoluteString },
                wikidataURL: authority?.wikidataURL?.absoluteString,
                career: PeopleRules.posts(career),
                candidates: candidates, records: records)
        }

        // A subject chip's pivot (S21g's follow-up): every volume covering the subject, from the bundled files alone,
        // so it answers whatever the served index holds, as the app's sheet lists volumes the reader has not downloaded.
        router.get("/api/v1/subjects/:ref/volumes") { request, context -> SubjectVolumes in
            try FormQuery(request.uri.query).refuseUnknown([])
            // The path gives the ref percent-encoded, as the browser app writes every segment.
            let given = try context.parameters.require("ref")
            let ref = given.removingPercentEncoding ?? given
            guard ref.utf8.count <= 256 else { throw APIProblem.invalidParameter("ref", "\(given.prefix(64))… is not a subject's ref.") }
            let (documents, profiles) = try await Blocking.run { (resources.documentSubjectIndex, resources.subjectProfiles.profiles) }
            let ids = SubjectPivot.coveringVolumes(ref: ref, excluding: "", documents: documents, profiles: profiles)
            return SubjectVolumes(ref: ref, volumes: ids.map { SubjectVolumes.Volume(volumeId: $0, title: resources.volume($0)?.title) })
        }
    }

    /// The identity the path names in `list`, or the problem that says it is not one.
    static func person(_ context: APIRequestContext, in list: ServedPeople.List) throws -> PersonIndexEntry {
        let raw = try context.parameters.require("rollupId")
        guard let id = Int(raw), let entry = list.byRollup[id] else {
            throw APIProblem(.notFound, code: "PERSON_NOT_FOUND",
                             detail: "The served index has no person \(raw): the people are numbered again whenever a correction or an indexing rebuilds them, so load them again.")
        }
        return entry
    }
}
