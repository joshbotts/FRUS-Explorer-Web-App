// Project Home's focus subjects (PLAN's S25c), the app's #377 Phase 2b.
// - The vocabulary a project's focus is chosen from is the kit's `VolumeSubjectProfiles` over the
//   bundled `volume-subject-profiles-index.json`, decoded as the app's `VolumeSubjectProfilesStore`
//   decodes it: a server whose file is missing or malformed has none, and Project Home leaves the
//   section out, as the app's view does. So does a server whose vocabulary names a subject twice,
//   the web's own refusal, since the kit's suggestions would trap on it.
// - The subjects a project chose are `ProjectHomeView.focusSubjectsSection`'s filter of the
//   vocabulary by the project's `defaultSubjectTagIds`, mirrored.
// - "Suggested from your volumes" is the kit's `ProjectFocusSuggestions` over the volumes the project
//   engages, which are `ProjectEngagedDocuments`' rule, mirrored: its notes on a document, the
//   documents read while it was active and its collections' document entries, and not its
//   highlights, which the coverage tiles' `DocumentEngagementService.gather` counts as well.
// - `GET /api/v1/me/focus-subjects` is the vocabulary whole, for the editor's All subjects and its
//   search, which the browser app filters as `ProjectFocusSubjectsEditor.filteredSubjects` does.
// ProjectHistoryParityTests holds each mirror to the app's source.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One subject of the vocabulary (`VolumeSubjectProfiles.SubjectOption`), as Project Home's chips
/// and the focus subjects editor's rows draw it.
public struct FocusSubject: Codable, Equatable, Sendable {
    /// What a project's `defaultSubjectTagIds` holds of it.
    public var ref: String
    public var name: String
    /// The row's second line, "category · subcategory".
    public var category: String
    public var subcategory: String
    /// How many volumes' profiles carry it, the row's "N volumes".
    public var volumeCount: Int

    init(_ subject: VolumeSubjectProfiles.SubjectOption) {
        ref = subject.ref
        name = subject.name
        category = subject.category
        subcategory = subject.subcategory
        volumeCount = subject.volumeCount
    }
}

/// The vocabulary, in its own order, by category, subcategory and name: the editor's All subjects.
public struct FocusSubjectList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [FocusSubject]
}

/// `volume-subject-profiles-index.json`, decoded the first time a project's page asks for it: a
/// server whose users keep no project never reads it.
final class SubjectProfilesFile: @unchecked Sendable {
    /// The file's name among the app's data files.
    static let name = "volume-subject-profiles-index.json"

    /// The vocabulary, or why the server has none.
    enum Read: Sendable {
        case loaded(VolumeSubjectProfiles)
        case unavailable(reason: String)

        /// The vocabulary, or nil for none, as `VolumeSubjectProfilesStore.shared` is nil.
        var profiles: VolumeSubjectProfiles? {
            if case .loaded(let profiles) = self { profiles } else { nil }
        }
    }

    private let lock = NSLock()
    private var held: Read?

    /// The file in `directory`, decoded once.
    func read(in directory: URL) -> Read {
        lock.lock()
        defer { lock.unlock() }
        if let held { return held }
        let read = Self.decode(directory.appendingPathComponent(Self.name))
        held = read
        return read
    }

    /// The file at `url` as the app's loader reads it, none for a file missing or malformed; and none
    /// for a vocabulary that lists a ref twice. The kit's `ProjectFocusSuggestions` builds a dictionary
    /// by ref with `Dictionary(uniqueKeysWithValues:)`, which traps on a repeated key, and a trap
    /// here would stop the server for every user. The generator writes each ref once, and the kit's
    /// own suite fails if the bundled file ever repeats one; this is for a file someone replaced.
    static func decode(_ url: URL) -> Read {
        guard let data = try? Data(contentsOf: url) else {
            return .unavailable(reason: "\(name) is missing from the app's data files, so projects have no focus subjects.")
        }
        guard let profiles = try? JSONDecoder().decode(VolumeSubjectProfiles.self, from: data) else {
            return .unavailable(reason: "\(name) does not decode, so projects have no focus subjects.")
        }
        var seen = Set<String>()
        if let repeated = profiles.allSubjects.first(where: { !seen.insert($0.ref).inserted }) {
            return .unavailable(reason: "\(name) lists the subject \(repeated.ref) twice, so projects have no focus subjects.")
        }
        return .loaded(profiles)
    }
}

enum ProjectFocusRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, resources: ServerResources) {
        // The subjects a project's focus is chosen from, for the editor's All subjects and its search.
        me.get("focus-subjects") { request, context -> FocusSubjectList in
            try FormQuery(request.uri.query).refuseUnknown([])
            _ = try context.requireUser()
            let items = try vocabulary(resources).allSubjects.map(FocusSubject.init)
            return FocusSubjectList(total: items.count, items: items)
        }
    }

    /// The vocabulary, or the problem that says why the server has none.
    static func vocabulary(_ resources: ServerResources) throws -> VolumeSubjectProfiles {
        switch resources.subjectProfiles {
        case .loaded(let profiles): return profiles
        case .unavailable(let reason): throw APIProblem(.serviceUnavailable, code: "SUBJECTS_UNAVAILABLE", detail: reason)
        }
    }

    /// The subjects `chosen` names, in the vocabulary's order (`ProjectHomeView.focusSubjectsSection`,
    /// and the editor's Focus subjects): a ref the vocabulary no longer names shows nothing.
    static func chosenSubjects(_ chosen: [String], in profiles: VolumeSubjectProfiles) -> [FocusSubject] {
        profiles.allSubjects.filter { chosen.contains($0.ref) }.map(FocusSubject.init)
    }

    /// "Suggested from your volumes": the kit's suggestions over the volumes a project engages, the
    /// subjects it chose left out, eight at most, the kit's default, which the app's editor takes.
    static func suggestedSubjects(engagedVolumeIds: Set<String>, excluding chosen: [String],
                                  in profiles: VolumeSubjectProfiles) -> [FocusSubject] {
        ProjectFocusSuggestions.suggestions(engagedVolumeIds: engagedVolumeIds, profiles: profiles, excluding: Set(chosen))
            .map(FocusSubject.init)
    }

    /// The documents a project engages (`ProjectEngagedDocuments.keys(collections:notes:visits:)`,
    /// mirrored), as `volumeId/documentId` keys, over the collections and notes filed under it and the
    /// visits made while it was active, each already the project's: a note on a document, a visit, and
    /// a collection's entry that is a document's. A project-level note and a heading or prose entry
    /// name no document and are passed over; an entry an older file left without a kind is a
    /// document's, as the app's model reads one.
    static func engagedKeys(collections: [CollectionExport], notes: [ResearchNoteExport],
                            visits: [ReadingHistoryEntryExport]) -> Set<String> {
        var result = Set<String>()
        for note in notes where !note.volumeId.isEmpty && !note.documentId.isEmpty {
            result.insert(key(note.volumeId, note.documentId))
        }
        for visit in visits where !visit.volumeId.isEmpty && !visit.documentId.isEmpty {
            result.insert(key(visit.volumeId, visit.documentId))
        }
        for collection in collections {
            for entry in collection.entries
            where (entry.kind ?? CollectionEntryKind.document.rawValue) == CollectionEntryKind.document.rawValue
                && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {
                result.insert(key(entry.volumeId, entry.documentId))
            }
        }
        return result
    }

    /// `ProjectEngagedDocuments.key(_:_:)`.
    static func key(_ volumeId: String, _ documentId: String) -> String {
        "\(volumeId)/\(documentId)"
    }

    /// The volumes of the documents a project engages (`ProjectEngagedDocuments.engagedVolumeIds`,
    /// mirrored): a key's volume is what comes before its first `/`.
    static func engagedVolumeIds(_ keys: Set<String>) -> Set<String> {
        Set(keys.compactMap { $0.split(separator: "/", maxSplits: 1).first.map(String.init) })
    }

    /// The focus subjects `refs` name, in the order given, once each, as the editor's toggles keep
    /// them. The editor adds only the vocabulary's subjects, and its toggle keeps what the project
    /// holds already, a ref the vocabulary no longer names among them, so each is one or the other:
    /// `SUBJECT_NOT_FOUND` for a ref that is neither, and, on a server with no vocabulary,
    /// `SUBJECTS_UNAVAILABLE` for one the project does not hold.
    static func focusSubjects(_ refs: [String], held: [String], resources: ServerResources) throws -> [String] {
        var chosen: [String] = []
        var known: Set<String>?
        for ref in refs where !chosen.contains(ref) {
            if !held.contains(ref) {
                if known == nil { known = Set(try vocabulary(resources).allSubjects.map(\.ref)) }
                guard known?.contains(ref) == true else {
                    throw APIProblem(.notFound, code: "SUBJECT_NOT_FOUND", detail: "The subject vocabulary has no subject with the ref \(ref).")
                }
            }
            chosen.append(ref)
        }
        return chosen
    }
}
