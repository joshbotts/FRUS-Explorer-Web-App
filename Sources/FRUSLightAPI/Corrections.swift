// The curator's corrections (PLAN's S21g): rule 7's two writes, a document's classification and the person rollup's
// identities, under /api/v1/me's guard, each refused to anyone without the curator role (SPEC, Tenancy and roles).
// Each is made and undone as the app's controls make and undo it, the store keeping it first and logging who made
// it and when (UserCorrections.swift), and the index taking it second (IndexCorrections.swift): a Standalone server's
// at once, through a job of its one writer, which a request waits for, for a while; an Import server's at the next
// export it installs, since the export it serves is the Mac's, immutable.
//
// - The classification, the app's control in the rail's Document tools (`ClassificationInfoSection` and the rail's
//   `applyReclassification`, `DocumentView/ResearchRailView.swift`): GET …/classification, what the index says,
//   what FRUS says (the TEI's parse, as the rail reads it live) and the correction kept; PUT, Reclassify as
//   Document… or Reclassify as Editorial Note…, the flip of what the index says, kept with what the TEI says now;
//   DELETE, Restore FRUS's Classification, which puts back the TEI's parse.
// - The people, the app's sheet's corrections (`PersonIndexDetailSheet`, `Browser/PersonIndexView.swift`, and
//   `PersonCorrectionsSheet`, `Browser/PersonCorrectionsView.swift`): POST people/merges, a merge of two identities
//   by their representative records, the kit's `representativeMember(forRollupId:)`, as `mergeRollup` takes them;
//   POST people/separations, one record of an identity separated; GET people/corrections, the corrections kept, the
//   sheet's rows; DELETE people/corrections/{id}, Undo.
// - The log, an admin's: GET /api/v1/admin/corrections.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// Where a correction stands once it is kept.
struct CorrectionOutcome: Codable, Equatable, Sendable, ResponseEncodable {
    /// `applied`, the index holds it; `waiting`, a job of a Standalone server's will apply it; `nextExport`, an
    /// Import server's next export will be given it.
    let state: String
    /// The log's entry.
    let entryId: String
}

/// A document's classification, as the rail's Document tools show it.
struct DocumentClassification: Codable, Equatable, Sendable, ResponseEncodable {
    struct Correction: Codable, Equatable, Sendable {
        let isEditorialNote: Bool
        let madeBy: String?
        let madeAt: String?
    }

    /// Whether the served index holds the document, without which no correction can be applied anywhere.
    let indexed: Bool
    /// What the served index says, which search, its facet and the reader read.
    let isEditorialNote: Bool?
    /// What FRUS says: the TEI's parse, read now, or the correction's record of it.
    let parsedIsEditorialNote: Bool?
    /// The correction this server keeps, if any.
    let correction: Correction?
    /// A change made here the index has not taken: `correction` or `restore`.
    let waiting: String?
    let canCorrect: Bool
    /// `import` or `standalone`.
    let mode: String
}

/// The person corrections kept, as the Corrections sheet lists them.
struct PersonCorrectionList: Codable, Equatable, Sendable, ResponseEncodable {
    struct Item: Codable, Equatable, Sendable {
        let id: String
        /// `merge` or `split`.
        let kind: String
        /// The records' names, or their `volumeId/ref` where the served index no longer has them.
        let nameA: String
        let nameB: String?
        let madeBy: String?
        let madeAt: String?
        /// Whether the served index holds it; a correction an import brought, made on the Mac, is.
        let applied: Bool
    }

    let items: [Item]
    let mode: String
}

/// The log, as an admin reads it.
struct CorrectionLogList: Codable, Equatable, Sendable, ResponseEncodable {
    struct Entry: Codable, Equatable, Sendable {
        let id: String
        let correction: String
        let action: String
        let overrideId: String
        let volumeId: String?
        let documentId: String?
        let isEditorialNote: Bool?
        let kind: String?
        let volumeIdA: String?
        let refA: String?
        let volumeIdB: String?
        let refB: String?
        let userId: String
        let userName: String
        let madeAt: String
        let appliedAt: String?
        /// The document's head, from the served index, for a classification's entry.
        let title: String?
        /// The records' names, or their `volumeId/ref` where the served index no longer has them, for a person's.
        let nameA: String?
        let nameB: String?

        init(_ entry: CorrectionLogEntry, title: String? = nil, nameA: String? = nil, nameB: String? = nil) {
            id = entry.id
            correction = entry.correction.rawValue
            action = entry.action.rawValue
            overrideId = entry.overrideId
            volumeId = entry.volumeId
            documentId = entry.documentId
            isEditorialNote = entry.isEditorialNote
            kind = entry.kind?.rawValue
            volumeIdA = entry.volumeIdA
            refA = entry.refA
            volumeIdB = entry.volumeIdB
            refB = entry.refB
            userId = entry.userId
            userName = entry.userName
            madeAt = UserStoreDate.text(entry.madeAt)
            appliedAt = entry.appliedAt.map(UserStoreDate.text)
            self.title = title
            self.nameA = nameA
            self.nameB = nameB
        }
    }

    let entries: [Entry]
    /// `import` or `standalone`: whether an entry waits for a job or for the next export.
    let mode: String
}

enum CorrectionRoutes {
    /// How long a request waits for the job that applies its correction, which may wait behind another job.
    static let applyPatience: Duration = .seconds(30)

    struct NewClassification: Decodable { let isEditorialNote: Bool }
    struct NewMerge: Decodable { let rollupId: Int; let otherRollupId: Int; let version: String }
    struct NewSeparation: Decodable { let rollupId: Int; let volumeId: String; let ref: String; let version: String }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider, indexer: LibraryIndexer?) {
        let store = services.store
        let mode = indexer?.mode ?? .import

        /// Has the index take what the store keeps now: a Standalone server's job, waited for a while; an Import
        /// server's next export.
        @Sendable func apply(_ entry: CorrectionLogEntry, for user: RequestUser) async -> CorrectionOutcome {
            guard mode == .standalone, let indexer else { return CorrectionOutcome(state: "nextExport", entryId: entry.id) }
            do {
                let job = try await indexer.applyCorrections(requestedBy: user.id)
                let state = await settled(job.id, jobs: services.jobs, within: applyPatience)
                return CorrectionOutcome(state: state == .succeeded ? "applied" : "waiting", entryId: entry.id)
            } catch {
                // Kept in the store, the start's job or the next correction's applies it.
                return CorrectionOutcome(state: "waiting", entryId: entry.id)
            }
        }

        @Sendable func stored<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
            do {
                return try await Blocking.run(work)
            } catch CorrectionStoreError.selfMerge {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "otherRollupId: a person cannot be merged with themselves.")
            }
        }

        // MARK: The classification

        let classification: RouterPath = "volumes/:volumeId/documents/:documentId/classification"
        me.get(classification) { request, context -> EditedResponse<DocumentClassification> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try UserDataRoutes.document(context, resources: resources)
            let effective = await ReaderRoutes.classification(of: document.volumeId, document.documentId, provider: provider)
            let (correction, entries) = try await Blocking.run {
                (try store.classificationOverrides().last { $0.volumeId == document.volumeId && $0.documentId == document.documentId },
                 try store.correctionLog(of: document))
            }
            let parsed = await parse(document, reader: reader) ?? correction?.parsedIsEditorialNote ?? (correction == nil ? effective : nil)
            // Who made the correction kept: its own entry, since the newest made may be of one undone since, and a
            // correction an import of the Mac's research brought has none.
            let made = correction.flatMap { kept in entries.first { $0.action == .made && $0.overrideId == kept.id } }
            let waiting = entries.first.flatMap { $0.appliedAt == nil ? ($0.action == .made ? "correction" : "restore") : nil }
            let body = DocumentClassification(
                indexed: effective != nil, isEditorialNote: effective, parsedIsEditorialNote: parsed,
                correction: correction.map {
                    DocumentClassification.Correction(isEditorialNote: $0.isEditorialNote, madeBy: made?.userName,
                                                      madeAt: (made?.madeAt ?? $0.createdAt).map(UserStoreDate.text))
                },
                waiting: waiting, canCorrect: user.roles.contains(.curator), mode: mode.rawValue)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }

        // Reclassify as Document… or Reclassify as Editorial Note…: the flip of what the index says, kept with what
        // the TEI says now, as the rail's `applyReclassification` keeps it.
        me.put(classification) { request, context -> CorrectionOutcome in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            try user.require(.curator)
            let document = try UserDataRoutes.document(context, resources: resources)
            let body = try await JSONBody.decode(NewClassification.self, from: request, fields: ["isEditorialNote"])
            guard let effective = await ReaderRoutes.classification(of: document.volumeId, document.documentId, provider: provider) else {
                throw APIProblem(.conflict, code: "DOCUMENT_NOT_INDEXED",
                                 detail: "The served index does not hold \(document.volumeId)/\(document.documentId), so its classification cannot be corrected.")
            }
            let (kept, latest) = try await Blocking.run {
                (try store.classificationOverrides().contains { $0.volumeId == document.volumeId && $0.documentId == document.documentId },
                 try store.correctionLog(of: document).first)
            }
            guard !kept else {
                throw APIProblem(.conflict, code: "CORRECTION_EXISTS",
                                 detail: "This document's classification is corrected already: restore FRUS’s classification first.")
            }
            // What the index says once what waits is applied, as the rail's section shows it: a restore an Import
            // server keeps for its next export, or one a job has not applied yet, else what it says now. So a restore
            // waiting is taken back by the flip of the value it puts back.
            let pending = latest.flatMap { $0.appliedAt == nil ? $0.isEditorialNote : nil } ?? effective
            guard body.isEditorialNote != pending else {
                throw APIProblem(.conflict, code: "CLASSIFICATION_UNCHANGED",
                                 detail: "isEditorialNote: the index classifies the document so already.")
            }
            let parsed = await parse(document, reader: reader) ?? effective
            let time = services.now()
            let entry = try await stored {
                try store.recordClassification(
                    ClassificationOverride(volumeId: document.volumeId, documentId: document.documentId, isEditorialNote: body.isEditorialNote,
                                           parsedIsEditorialNote: parsed, createdAt: time), by: user.id, at: time)
            }
            return await apply(entry, for: user)
        }

        // Restore FRUS's Classification: the correction removed, and the TEI's parse put back.
        me.delete(classification) { request, context -> CorrectionOutcome in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            try user.require(.curator)
            let document = try UserDataRoutes.document(context, resources: resources)
            let kept = try await Blocking.run {
                try store.classificationOverrides().last { $0.volumeId == document.volumeId && $0.documentId == document.documentId }
            }
            guard let kept else {
                throw APIProblem(.notFound, code: "CORRECTION_NOT_FOUND", detail: "This document's classification is not corrected on this server.")
            }
            let parsed = await parse(document, reader: reader) ?? kept.parsedIsEditorialNote
            let time = services.now()
            guard let entry = try await stored({ try store.undoClassification(of: document, restoring: parsed, by: user.id, at: time) }) else {
                throw APIProblem(.notFound, code: "CORRECTION_NOT_FOUND", detail: "This document's classification is not corrected on this server.")
            }
            return await apply(entry, for: user)
        }

        // MARK: The people

        me.get("people/corrections") { request, context -> EditedResponse<PersonCorrectionList> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            try user.require(.curator)
            let (overrides, entries) = try await Blocking.run { (try store.personOverrides(), try store.correctionLog(of: .person)) }
            let served = try? await provider.servedIfReady()
            func name(_ volumeId: String?, _ ref: String?) async -> String? {
                guard let volumeId, let ref else { return nil }
                if let name = try? await served?.persons.personName(volumeId: volumeId, ref: ref), !name.isEmpty { return name }
                return "\(volumeId)/\(ref)"
            }
            var items: [PersonCorrectionList.Item] = []
            for override in overrides {
                let made = entries.first { $0.overrideId == override.id && $0.action == .made }
                items.append(PersonCorrectionList.Item(
                    id: override.id, kind: override.kind.rawValue,
                    nameA: await name(override.volumeIdA, override.refA) ?? "",
                    nameB: override.kind == .merge ? await name(override.volumeIdB, override.refB) : nil,
                    madeBy: made?.userName, madeAt: (made?.madeAt ?? override.createdAt).map(UserStoreDate.text),
                    applied: made.map { $0.appliedAt != nil } ?? true))
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: PersonCorrectionList(items: items, mode: mode.rawValue))
        }

        // Merge: two identities by their representative records, as the sheet's `mergeRollup` takes them, against the
        // rollup the page was given, since another's ids may name other people.
        me.post("people/merges") { request, context -> CorrectionOutcome in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            try user.require(.curator)
            let body = try await JSONBody.decode(NewMerge.self, from: request, fields: ["rollupId", "otherRollupId", "version"])
            let served = try await provider.served()
            let list = try await served.people.list(served.persons)
            try current(body.version, list)
            guard body.rollupId != body.otherRollupId else {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "otherRollupId: a person cannot be merged with themselves.")
            }
            for id in [body.rollupId, body.otherRollupId] where list.byRollup[id] == nil {
                throw APIProblem(.notFound, code: "PERSON_NOT_FOUND", detail: "The served index has no person \(id).")
            }
            guard let mine = try await served.persons.representativeMember(forRollupId: body.rollupId),
                  let theirs = try await served.persons.representativeMember(forRollupId: body.otherRollupId) else {
                throw APIProblem(.notFound, code: "PERSON_NOT_FOUND", detail: "The served index holds no record of one of the two people.")
            }
            // The records are read live, and on a Standalone server a job may have rebuilt the rollup under the
            // stack's list, which is opened again only once the job ends: the version is read again from the store,
            // after them, so that the ids are the ones the page was given.
            try current(body.version, served: try await ServedPeople.version(now: served.persons))
            let time = services.now()
            let entry = try await stored {
                try store.recordPersonMerge(PersonRecordKey(volumeId: mine.volumeId, ref: mine.ref),
                                            PersonRecordKey(volumeId: theirs.volumeId, ref: theirs.ref), by: user.id, at: time)
            }
            guard let entry else {
                throw APIProblem(.conflict, code: "CORRECTION_EXISTS", detail: "These two people are merged already on this server.")
            }
            return await apply(entry, for: user)
        }

        // Separate: one record of an identity, as the sheet's `separate` detaches it.
        me.post("people/separations") { request, context -> CorrectionOutcome in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            try user.require(.curator)
            let body = try await JSONBody.decode(NewSeparation.self, from: request, fields: ["rollupId", "volumeId", "ref", "version"])
            let served = try await provider.served()
            let list = try await served.people.list(served.persons)
            try current(body.version, list)
            guard list.byRollup[body.rollupId] != nil else {
                throw APIProblem(.notFound, code: "PERSON_NOT_FOUND", detail: "The served index has no person \(body.rollupId).")
            }
            let records = try await served.persons.members(forRollupId: body.rollupId)
            guard records.contains(where: { $0.volumeId == body.volumeId && $0.entry.ref == body.ref }) else {
                throw APIProblem(.notFound, code: "RECORD_NOT_FOUND",
                                 detail: "\(body.volumeId)/\(body.ref) is not a record of person \(body.rollupId).")
            }
            guard records.count > 1 else {
                throw APIProblem(.conflict, code: "RECORD_ALONE", detail: "This record is the only one in its identity, so it is a person of its own already.")
            }
            let time = services.now()
            guard let entry = try await stored({
                try store.recordPersonSplit(PersonRecordKey(volumeId: body.volumeId, ref: body.ref), by: user.id, at: time)
            }) else {
                throw APIProblem(.conflict, code: "CORRECTION_EXISTS", detail: "This record is separated already on this server.")
            }
            return await apply(entry, for: user)
        }

        // Undo, as the Corrections sheet's: a correction undone elsewhere is gone, which says so.
        me.delete("people/corrections/:correctionId") { request, context -> CorrectionOutcome in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            try user.require(.curator)
            let id = try context.parameters.require("correctionId")
            let time = services.now()
            guard let entry = try await stored({ try store.undoPersonCorrection(id, by: user.id, at: time) }) else {
                throw APIProblem(.notFound, code: "CORRECTION_NOT_FOUND", detail: "No person correction \(id) is kept on this server: it may have been undone already.")
            }
            return await apply(entry, for: user)
        }
    }

    /// The log, an admin's to read (`/api/v1/admin`'s guard and role), each entry named from the served index: a
    /// classification's document by its head, a person correction's records by their names.
    static func add(toAdmin admin: RouterGroup<APIRequestContext>, services: UserDataServices, provider: ServedIndexProvider?,
                    mode: ServerConfiguration.Mode) {
        let store = services.store
        admin.get("corrections") { request, _ -> EditedResponse<CorrectionLogList> in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["limit"])
            let limit = try query.optionalInteger("limit", in: 1...10_000) ?? 500
            let entries = try await Blocking.run { try store.correctionLog(limit: limit) }
            let served = try? await provider?.servedIfReady()
            func name(_ volumeId: String?, _ ref: String?) async -> String? {
                guard let volumeId, let ref else { return nil }
                if let name = try? await served?.persons.personName(volumeId: volumeId, ref: ref), !name.isEmpty { return name }
                return "\(volumeId)/\(ref)"
            }
            var named: [CorrectionLogList.Entry] = []
            for entry in entries {
                var title: String?
                if let document = entry.document {
                    title = (try? await served?.pipeline.documentHeader(volumeId: document.volumeId, documentId: document.documentId)) ?? nil
                }
                named.append(CorrectionLogList.Entry(entry, title: title, nameA: await name(entry.volumeIdA, entry.refA),
                                                     nameB: await name(entry.volumeIdB, entry.refB)))
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: CorrectionLogList(entries: named, mode: mode.rawValue))
        }
    }

    /// The document's classification as its TEI shapes it now (`isShapedAsEditorialNote`, the rule the indexer
    /// applies), read from the reader's parse, as the rail reads the parse it has; nil where the server holds no TEI
    /// of it.
    static func parse(_ document: DocumentKey, reader: ReaderService) async -> Bool? {
        guard let parsed = try? await reader.document(volume: document.volumeId, document: document.documentId) else { return nil }
        return parsed.ast.isShapedAsEditorialNote
    }

    /// Refuses a correction made against another rollup than the one served.
    static func current(_ version: String, _ list: ServedPeople.List) throws {
        try current(version, served: list.version)
    }

    /// Refuses a correction made against another rollup than the one whose version is `served`.
    static func current(_ version: String, served: String) throws {
        guard version == served else {
            throw APIProblem(.conflict, code: "PEOPLE_CHANGED",
                             detail: "The people have been rebuilt since the page was loaded, by a correction or an indexing, so their numbers may name others now: load them again.")
        }
    }

    /// The state `id` reached within `limit`, or nil while it still waits or runs.
    static func settled(_ id: String, jobs: any JobQueue, within limit: Duration) async -> Job.State? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: limit)
        while clock.now < deadline {
            guard let job = await jobs.job(id) else { return nil }
            if [.succeeded, .failed, .cancelled].contains(job.state) { return job.state }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return nil
    }
}
