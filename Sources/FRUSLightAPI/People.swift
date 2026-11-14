// The People screen (PLAN's S21g), `/people`, which phase 1 left: the kit's person rollup over the served index,
// as the app's `PersonIndexView` lists it (`Browser/PersonIndexView.swift`, app code), and an identity's sheet,
// its `PersonIndexDetailSheet`. GET /api/v1/people gives every identity, the kit's
// `PersonMentionStore.allPersonsSortedByName()` in its order, grouped by the first letter of the name as the app's
// `PersonIndexSection.makeSections` groups them, each row's line the app's `PersonIndexRow.subtitle` (the kit's
// `roleEraSubtitle` and the volume count), its mention count and whether a "possibly the same person" suggestion
// waits (`rollupIdsWithCandidates()`); GET /api/v1/people/{rollupId} gives the sheet: the name, the volumes'
// description, the register's life years and role and the reconciled mark (the bundled name authority, as the
// app's sheet reads it), the mentions, Active (the kit's `eraText`), the VIAF and Wikidata links, the suggestions
// and the records the identity holds. The rules the views apply are the app's, mirrored as `PeopleRules` and held
// to its source by `PeopleParityTests`.
//
// A rollup's ids are renumbered whenever it is built again, so each answer carries `version`, a digest of the list
// it came from, which a correction sends back (Corrections.swift): one made against another rollup is refused,
// since its ids may name other people now. The career the register gives (POCOM) and the subjects of the volumes a
// person is mentioned in read kit members internal at the pin, and wait for an upstream pull request that makes them
// public (the log's entry, Session 21g).

import Crypto
import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// The app's rules over the rollup's rows, mirrored from `Browser/PersonIndexView.swift`.
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

    /// `PersonLifespan.text(born:died:)`: "1893–1971", "Born 1893", "Died 1971", or nil; a year never grouped.
    static func lifespan(born: Int?, died: Int?) -> String? {
        switch (born, died) {
        case let (born?, died?): "\(born)–\(died)"
        case let (born?, nil): "Born \(born)"
        case let (nil, died?): "Died \(died)"
        case (nil, nil): nil
        }
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

    let version: String
    let rollupId: Int
    let name: String
    /// The volumes' own words, from their lists of persons.
    let description: String?
    /// The register's life years, the name authority's (`PersonLifespan`), and its role where it adds to the description.
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
    let viafURL: String?
    let wikidataURL: String?
    /// "Possibly the Same Person".
    let candidates: [Candidate]
    /// "Records in This Identity", each a volume's persons-list record, which Separate names.
    let records: [Record]
}

extension ServerResources {
    /// `PersonAuthorityIndexStore.shared`, app code: the bundled name authority the sheet reads the register's life
    /// years, role and Wikidata link from, decoded once on first use; nil for a file missing or malformed, and the
    /// sheet then shows what the volumes say alone.
    var personAuthority: PersonAuthorityIndex? { people.personAuthority.value(in: directory) }
}

/// The bundled files the People screen reads.
final class PeopleFiles: Sendable {
    let personAuthority = DecodedFile("person-authority-index.json") { url -> PersonAuthorityIndex in
        try JSONDecoder().decode(PersonAuthorityIndex.self, from: Data(contentsOf: url))
    }
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
            let authority = entry.authorityId.flatMap { resources.personAuthority?.entry(for: $0) }
            return PersonSheet(
                version: list.version, rollupId: rollupId, name: entry.entry.name,
                description: entry.entry.description.flatMap { $0.isEmpty ? nil : $0 },
                lifespan: PeopleRules.lifespan(born: authority?.b, died: authority?.d),
                registerRole: PeopleRules.registerRole(authority?.r, description: entry.entry.description),
                reconciled: entry.authorityId != nil, authorityId: entry.authorityId,
                mentionCount: entry.mentionCount, mentions: PeopleRules.mentions(entry.mentionCount),
                active: entry.entry.eraText,
                viafURL: entry.viafId.flatMap { $0.isEmpty ? nil : URL(string: "https://viaf.org/viaf/\($0)")?.absoluteString },
                wikidataURL: authority?.wikidataURL?.absoluteString,
                candidates: candidates, records: records)
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
