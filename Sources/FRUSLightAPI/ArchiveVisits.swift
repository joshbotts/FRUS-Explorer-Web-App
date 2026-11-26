// /api/v1/me/visits (PLAN's S30c): the user's Archives Visit plans, the Mac's `ArchiveVisitPlan` with its seeds and stored
// targets, each row written as the import writes a Mac's (`MacImport.plan`, `.seed`, `.target`) and read as the export reads
// one (`ResearchExport.plan`), over the store's three tables (UserVisitPlans.swift). The list is the app's
// (`ArchiveVisitListView`): most recently changed first, each plan's line the kit's count of what it derives
// (`ArchiveVisitCounts.listSummary`). Every write is the kit's rule (`ArchiveVisitPlanWrites`, S30b): New
// (`newPlan`, under the user's active project with its research question), Rename (`name(fromDraft:)`), Duplicate
// (`duplicate(of:id:now:)`), Delete (`deletion(of:)`), Re-seed from Project (`reseed(_:fromProject:now:)` over the server's
// own gather of the project's seed, `ProjectLeadsSeed`, with its topic's confirmation), a target's tier, exclusion and note
// (`settingTier`, `settingIncluded`, `settingNote(fromDraft:)`) and a stored row's Remove (`removingState`), each through the
// overlay of the plan as it stands, and the tiers' add, rename, step and removal; a seed's two switches and its Remove are
// plain writes of one row, as the app's are. Each changed row is stamped as the app's save stamps the models it changed
// (`ModelModificationStamper`): a seed or target whose fields change, and the plan when its own fields change or a seed or
// target joins or leaves it. The editor's state is the kit's derivation (`ArchiveVisitDerivation.derive`) over the served
// index's source notes and footnote citations and the six bundled files the packet reads (`TripPacketIndexes`), computed
// once for what it reads of a plan and kept while the index is served, for two minutes at most, the stored state read again
// over it at each answer (`overlay(for:over:)`); its sections, their order and the words the server writes are the app's view's, mirrored and held
// to its source by `ArchiveVisitMirrorParityTests`. A duplicated plan's targets are created anew, as the app's are, so a
// target several rows answer for, none under its own key, can show another of them in the copy (FRUS-Explorer#1989).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
import Synchronization

// MARK: - Answers

/// The user's Archives Visit plans, the most recently changed first.
public struct VisitPlanList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [VisitPlanItem]
}

/// A plan as the app's list draws its row.
public struct VisitPlanItem: Codable, Equatable, Sendable {
    public var id: String
    /// As stored; empty for an untitled plan.
    public var name: String
    /// The name, or "Untitled Archives Visit" (`ArchiveVisitPlanWrites.displayName(of:)`).
    public var displayName: String
    public var lastModified: String?
    /// How many documents seed it.
    public var documentCount: Int
    /// How many of them are in volumes the served index holds; 0 while none is served.
    public var indexedDocumentCount: Int
    /// "6 targets · 3 repositories", the kit's count of what the plan derives (`ArchiveVisitCounts.listSummary`), for a plan
    /// with documents over a served index; absent otherwise, when the row says how many documents seed it.
    public var summary: String?
}

/// A plan as the app's editor draws it: its Targets and its Documents, and its tiers.
public struct VisitPlanDetail: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String
    public var displayName: String
    /// The inquiry's topic, as stored: copied from the project's research question when the plan was made, and offered
    /// again by Re-seed from Project.
    public var inquiryText: String?
    public var projectIds: [String]
    /// The project the plan belongs to, its first, when the user still holds it: what Re-seed from Project reads, and
    /// offered only then (`owningProject(among:)`).
    public var project: Project?
    public var createdAt: String?
    public var lastModified: String?
    public var deliverables: Deliverables
    /// The plan's tiers, as it stores them.
    public var tiers: [Tier]
    /// How many documents seed it, and how many of them the served index holds, the kit's counts.
    public var documentCount: Int
    public var indexedDocumentCount: Int
    /// Whether an index is served, over which the targets derive; with none, no target does.
    public var served: Bool
    /// "6 targets across 3 repositories.", the kit's (`ArchiveVisitCounts.editorSummary`), for a plan with documents over a
    /// served index.
    public var summary: String?
    /// The Targets list's sections in drawing order: each repository, then "Confirm before you travel"
    /// (`ArchiveVisitCounts.sectionHeadings(of:)`).
    public var sections: [Section]
    /// The stored targets the derivation does not show: the orphans, then the rows another stored row is shown over.
    public var storedTargets: [StoredTarget]
    /// The seeds, by their keys, as the Documents tab lists them.
    public var documents: [Seed]
    /// The served index's own count of documents whose footnotes cite unprinted material (`externalCitationSparsity()`).
    public var sparsity: Sparsity?

    public struct Project: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
    }

    public struct Deliverables: Codable, Equatable, Sendable {
        public var includeLinks: Bool
        public var includeTargets: Bool
        public var includeInquiry: Bool
        public var includeCitationCrib: Bool
    }

    public struct Tier: Codable, Equatable, Sendable {
        public var id: String
        public var label: String?
        /// Its label, or "Priority N" by its place (`ArchiveVisitOverlay.displayName(for:)`).
        public var displayName: String
        public var order: Int
        /// How many of the plan's stored targets it holds, as the tiers' sheet counts them.
        public var members: Int
    }

    public struct Section: Codable, Equatable, Sendable {
        public var heading: String
        /// Whether it is the group no repository serves, "Confirm before you travel".
        public var unplaced: Bool
        /// The repository's verified links, as the section's header draws them.
        public var links: [Link]
        /// Its targets, by tier, Unprioritized last, then by label: the app's order within a section.
        public var targets: [Target]
    }

    public struct Link: Codable, Equatable, Sendable {
        public var label: String
        public var url: String
    }

    public struct Target: Codable, Equatable, Sendable {
        /// The claim-free key the stored state is written under.
        public var key: String
        public var label: String
        /// `decimalClass`, `lotFile`, `collection` or `raw`.
        public var form: String
        /// RG · entry · series · NAID · years, the kit's.
        public var recordsLine: String?
        /// The documents published from it, the first eight, the packet's cap, and how many in all.
        public var drawnFrom: [DrawnFrom]
        public var drawnFromCount: Int
        /// The footnotes citing it unprinted, the first eight, and how many in all.
        public var pointedAt: [PointedAt]
        public var pointedAtCount: Int
        /// Whether part of it is digitized or filmed, to be read that way instead of pulled.
        public var substitute: Bool
        /// The packet's access lines, its own English sentences (`TripPacketExporter.restrictionLines`).
        public var accessLines: [String]
        /// Each lot its documents cite, when they do not all cite one.
        public var lots: [Lot]
        /// Its tier, or none for Unprioritized, a tier no longer among the plan's included.
        public var tierId: String?
        public var excluded: Bool
        public var note: String?
    }

    public struct DrawnFrom: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// The citation, with the series' title in Markdown's italics, as the kit's formatter writes it.
        public var citation: String
        /// The source note as printed.
        public var sourceNote: String
    }

    public struct PointedAt: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// The citation and the footnote the volume printed (`TripPacketExporter.footnoteLine(for:)`).
        public var line: String
        /// The footnote's citation as printed.
        public var rawText: String
        /// Whether an Ibid. supplied it.
        public var inherited: Bool
    }

    public struct Lot: Codable, Equatable, Sendable {
        /// "Lot 61 D 21 — 3 documents", the app's line.
        public var title: String
        public var recordsLine: String?
        public var accessLines: [String]
    }

    public struct StoredTarget: Codable, Equatable, Sendable {
        /// The key the row was minted under, which its writes name.
        public var key: String
        /// The key's identity, past its form, as the app labels a stored row.
        public var label: String
        /// `orphan`: no target derives under its key; `superseded`: it answers for a target another row is shown on.
        public var kind: String
        public var tierId: String?
        public var note: String?
        /// For a superseded row, the label of the target it is now part of.
        public var partOf: String?
        /// For a superseded row, whether it excluded its target when that was one of its own.
        public var excludedWhenOwn: Bool
    }

    public struct Seed: Codable, Equatable, Sendable {
        /// `volumeId/documentId`.
        public var key: String
        public var volumeId: String?
        public var documentId: String?
        /// The document's head, as the served index holds it.
        public var header: String?
        public var volumeTitle: String?
        /// Whether it carries a source note, and how many of its footnotes cite unprinted material; absent while no index
        /// is served, when the row offers both switches.
        public var hasSourceNote: Bool?
        public var referenceCount: Int?
        public var includeSource: Bool
        public var includeExternalRefs: Bool
    }

    public struct Sparsity: Codable, Equatable, Sendable {
        public var withReferences: Int
        public var indexed: Int
    }
}

/// What Re-seed from Project did: the seeds it added, its topic's outcome, and the plan as it then stands.
public struct VisitReseedAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    /// `unchanged`, `filled`, the question written into an empty topic, or `needsConfirmation`, which writes nothing and
    /// asks, the question and the topic in `question` and `current`.
    public var topic: String
    public var question: String?
    public var current: String?
    /// How many documents it added as seeds.
    public var added: Int
    public var plan: VisitPlanDetail
}

// MARK: - The derivation, kept while its index is served

/// What a plan's derivation reads of it, past its stored state: its seeds with their switches, its topic, and which of
/// their volumes the index holds; and the window of two minutes it was asked in. Two plans that read the same in one
/// window derive the same model.
struct VisitDerivationKey: Hashable, Sendable {
    let seeds: [ArchiveVisitDerivation.InputSignature.Seed: Int]
    let inquiryText: String?
    let indexedSeedVolumes: Set<String>
    let window: Int
}

/// What the server keeps of a plan's derivation while its index is served (`ServedIndex.visits`), each for a window of
/// two minutes at most: the kit's data source answers a read of the index that fails as no rows, so a model or a seed's
/// facts that a failed read emptied are kept no longer than the window, where the app derives again at its next write.
enum VisitKeptKey: Hashable, Sendable {
    /// A plan's model, by what it reads.
    case model(VisitDerivationKey)
    /// The Documents tab's facts of the seeds these keys name, and the index's sparsity.
    case facts(seedKeys: [String], window: Int)
}

enum VisitKept: Sendable {
    case model(ArchiveVisitDerivation.Derived)
    case facts([String: SeedFacts], VisitPlanDetail.Sparsity?)
}

/// A plan's derivation over the served index, with the Documents tab's facts of each seed and the index's sparsity where
/// the answer reads them, the editor's, and none for the list's.
struct VisitDerivation: Sendable {
    let derived: ArchiveVisitDerivation.Derived
    let facts: [String: SeedFacts]
    let sparsity: VisitPlanDetail.Sparsity?
}

/// What the Documents tab says of a seed: its head and volume, and which of its halves exist.
struct SeedFacts: Equatable, Sendable {
    let header: String?
    let volumeTitle: String?
    let hasSourceNote: Bool
    let referenceCount: Int
}

/// The index's own sparsity read failed: the seeds' facts read beside it are kept for no one.
struct VisitIndexReadFailed: Error {}

// MARK: - Routes

enum ArchiveVisitRoutes {
    struct Create: Decodable {
        let name: String?
    }

    struct Edit: Decodable {
        let name: String?
        let inquiryText: String?
    }

    /// A target's write: its key, and one of a tier (none for Unprioritized), its exclusion or its note.
    struct TargetEdit: Decodable {
        enum Change: Equatable {
            case tier(UUID?)
            case included(Bool)
            case note(String)
        }

        let key: String
        let change: Change

        enum CodingKeys: String, CodingKey { case key, tierId, included, note }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            key = try container.decode(String.self, forKey: .key)
            var changes: [Change] = []
            if container.contains(.tierId) {
                if let raw = try container.decodeIfPresent(String.self, forKey: .tierId) {
                    guard let id = UUID(uuidString: raw) else { throw APIProblem.invalidParameter("tierId", "\(raw) is not a tier's id") }
                    changes.append(.tier(id))
                } else {
                    changes.append(.tier(nil))
                }
            }
            if let included = try container.decodeIfPresent(Bool.self, forKey: .included) { changes.append(.included(included)) }
            if let note = try container.decodeIfPresent(String.self, forKey: .note) { changes.append(.note(note)) }
            guard changes.count == 1, let change = changes.first else {
                throw APIProblem.invalidParameter("tierId", "a target's write names one of tierId, included and note")
            }
            self.change = change
        }
    }

    struct SeedEdit: Decodable {
        let key: String
        let includeSource: Bool?
        let includeExternalRefs: Bool?
    }

    struct TierEdit: Decodable {
        let label: String?
    }

    struct TierMove: Decodable {
        let by: Int
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        me.get("visits") { request, context -> VisitPlanList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let served = try await provider.servedIfReady()
            let plans = try await plans(of: user.id, in: store)
            var items: [VisitPlanItem] = []
            for plan in plans {
                var summary: String?
                if let served, !plan.documents.isEmpty {
                    summary = ArchiveVisitCounts.listSummary(of: try await derivation(of: plan, served: served, resources: resources).derived.model)
                }
                items.append(VisitPlanItem(
                    id: plan.id.uuidString, name: plan.name, displayName: ArchiveVisitPlanWrites.displayName(of: plan.name),
                    lastModified: plan.lastModified.map(UserStoreDate.text), documentCount: plan.documents.count,
                    indexedDocumentCount: indexedCount(plan, served: served), summary: summary))
            }
            return VisitPlanList(total: items.count, items: items)
        }
        // New Archives Visit: `ArchiveVisitPlan.make(name:activeProjectId:in:)`, under the user's active project with its
        // research question as the topic, or none in the Global Context, untitled unless the body names it.
        me.post("visits") { request, context -> EditedResponse<VisitPlanDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Create.self, from: request, fields: ["name"])
            let time = UserStoreDate.rounded(now())
            let projects = try await projects(of: user.id, in: store)
            let active = try await Blocking.run { try store.activeProjectId(of: user.id) }
            let project = active.flatMap { id in projects.first { $0.id.uuidString == UserSearchText.uuidString(id) } }
            let plan = ArchiveVisitPlanWrites.newPlan(name: body.name ?? "", projectId: project?.id,
                                                      researchQuestion: project?.researchQuestion, id: UUID(), now: time)
            let rows = try await added(plan, for: user.id, in: store)
            let location = context.basePath.prefixing("/api/v1/me/visits/\(plan.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: try await answer(rows, projects: projects, provider: provider, resources: resources))
        }
        me.get("visits/:planId") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let rows = try await rows(try context.parameters.require("planId"), of: user.id, in: store)
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // Rename, from the reader's draft (`name(fromDraft:)`: an empty commit writes nothing), and the topic, which the
        // confirmed half of Re-seed from Project writes (`replaceInquiryTopic(with:)`), a blank one as none.
        me.patch("visits/:planId") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Edit.self, from: request, fields: ["name", "inquiryText"])
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                if let draft = body.name, let name = ArchiveVisitPlanWrites.name(fromDraft: draft) { plan.name = name }
                if let topic = body.inquiryText { plan.inquiryText = TripPacketTopicSentence.written(topic) }
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // Delete: the plan and every seed and target it holds (`deletion(of:)`).
        me.delete("visits/:planId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("planId")
            let deletion = ArchiveVisitPlanWrites.deletion(of: try record(try await rows(id, of: user.id, in: store)))
            guard try await Blocking.run({ try store.deleteVisitPlan(deletion.planId.uuidString, for: user.id) }) else { throw notFound(id) }
            return Response(status: .noContent)
        }
        // Duplicate: an independent copy under "<name> copy", its seeds and targets under the copy's derived ids, its tiers
        // kept (`duplicate(of:id:now:)`).
        me.post("visits/:planId/duplicate") { request, context -> EditedResponse<VisitPlanDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let time = UserStoreDate.rounded(now())
            let source = try record(try await rows(try context.parameters.require("planId"), of: user.id, in: store))
            var copy = ArchiveVisitPlanWrites.duplicate(of: source, id: UUID(), now: time)
            // Two rows of one key would take one derived id, which the store keys a row by: the first of a key is kept.
            copy.documents = firstOfEachId(copy.documents, \.id)
            copy.targets = firstOfEachId(copy.targets, \.id)
            let rows = try await added(copy, for: user.id, in: store)
            let location = context.basePath.prefixing("/api/v1/me/visits/\(copy.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: try await answer(rows, projects: try await projects(of: user.id, in: store),
                                                             provider: provider, resources: resources))
        }
        // Re-seed from Project: the project's seed as Suggested Next gathers it, added with both halves on, and its research
        // question offered to the topic, written into an empty one and asked about before it replaces another.
        me.post("visits/:planId/reseed") { request, context -> VisitReseedAnswer in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("planId")
            let time = UserStoreDate.rounded(now())
            let held = try record(try await rows(id, of: user.id, in: store))
            let projects = try await projects(of: user.id, in: store)
            let seed = try await projectSeed(of: held, among: projects, for: user.id, in: store)
            let outcome = Mutex<ArchiveVisitPlanWrites.Reseed?>(nil)
            let rows = try await changed(id, for: user.id, in: store, at: time) { plan in
                let reseed = ArchiveVisitPlanWrites.reseed(plan, fromProject: seed, now: time)
                apply(reseed.seeds, to: &plan)
                if case .filled(let question) = reseed.topic { plan.inquiryText = question }
                outcome.withLock { $0 = reseed }
            }
            let reseed = outcome.withLock { $0 }
            let detail = try await answer(rows, projects: projects, provider: provider, resources: resources)
            switch reseed?.topic ?? .unchanged {
            case .unchanged:
                return VisitReseedAnswer(topic: "unchanged", added: reseed?.seeds.mintedCount ?? 0, plan: detail)
            case .filled(let question):
                return VisitReseedAnswer(topic: "filled", question: question, added: reseed?.seeds.mintedCount ?? 0, plan: detail)
            case .needsConfirmation(let question, let current):
                return VisitReseedAnswer(topic: "needsConfirmation", question: question, current: current,
                                         added: reseed?.seeds.mintedCount ?? 0, plan: detail)
            }
        }
        // A target's tier, exclusion or note, through the overlay of the plan as it stands, minting its row (§2a).
        me.patch("visits/:planId/targets") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("planId")
            let body = try await JSONBody.decode(TargetEdit.self, from: request, fields: ["key", "tierId", "included", "note"])
            let time = UserStoreDate.rounded(now())
            let model = try await derivedModel(id, of: user.id, in: store, provider: provider, resources: resources)
            let rows = try await changed(id, for: user.id, in: store, at: time) { plan in
                let overlay = ArchiveVisitDerivation.overlay(for: plan, over: model)
                let shown = Set(model.targets.map(\.key))
                let stored = Set(overlay.orphanKeys).union(overlay.superseded.keys)
                guard shown.contains(body.key) || stored.contains(body.key) else { throw targetNotFound(body.key) }
                switch body.change {
                case .tier(let tierId):
                    if let tierId, !plan.tiers.contains(where: { $0.id == tierId }) { throw tierNotFound(tierId.uuidString) }
                    switch ArchiveVisitPlanWrites.settingTier(tierId, forKey: body.key, resolvedBy: overlay, among: plan.targets,
                                                              planId: plan.id, now: time) {
                    case .stored(let row): plan.targets[row.index].tierId = row.record.tierId
                    case .minted(let record): plan.targets.append(record)
                    }
                case .included(let included):
                    // Only a target the plan derives is kept or excluded; a stored row's exclusion is not applied.
                    guard shown.contains(body.key) else { throw targetNotFound(body.key) }
                    switch ArchiveVisitPlanWrites.settingIncluded(included, forKey: body.key, resolvedBy: overlay,
                                                                  among: plan.targets, planId: plan.id, now: time) {
                    case .stored(let row): plan.targets[row.index].included = row.record.included
                    case .minted(let record): plan.targets.append(record)
                    }
                case .note(let draft):
                    switch ArchiveVisitPlanWrites.settingNote(fromDraft: draft, forKey: body.key, resolvedBy: overlay,
                                                              among: plan.targets, planId: plan.id, now: time) {
                    case .stored(let row): plan.targets[row.index].userNote = row.record.userNote
                    case .minted(let record): plan.targets.append(record)
                    }
                }
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // Remove Stored State: an orphan's or a superseded row's, by its own key (`removingState`).
        me.delete("visits/:planId/targets") { request, context -> VisitPlanDetail in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["key"])
            guard let key = try query.single("key") else { throw APIProblem.invalidParameter("key", "name the stored target's key") }
            let user = try context.requireUser()
            let id = try context.parameters.require("planId")
            let time = UserStoreDate.rounded(now())
            let model = try await derivedModel(id, of: user.id, in: store, provider: provider, resources: resources)
            let rows = try await changed(id, for: user.id, in: store, at: time) { plan in
                let overlay = ArchiveVisitDerivation.overlay(for: plan, over: model)
                guard overlay.orphanKeys.contains(key) || overlay.superseded[key] != nil,
                      let row = ArchiveVisitPlanWrites.removingState(forKey: key, resolvedBy: overlay, among: plan.targets) else {
                    throw targetNotFound(key)
                }
                plan.targets.remove(at: row.index)
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // A seed's two switches: a plain write of one row, the half the body names.
        me.patch("visits/:planId/documents") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(SeedEdit.self, from: request, fields: ["key", "includeSource", "includeExternalRefs"])
            guard body.includeSource != nil || body.includeExternalRefs != nil else {
                throw APIProblem.invalidParameter("includeSource", "a seed's write names includeSource or includeExternalRefs")
            }
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                guard let index = plan.documents.firstIndex(where: { $0.documentKey == body.key }) else { throw seedNotFound(body.key) }
                if let on = body.includeSource { plan.documents[index].includeSource = on }
                if let on = body.includeExternalRefs { plan.documents[index].includeExternalRefs = on }
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // A seed's Remove: a plain delete of its row.
        me.delete("visits/:planId/documents") { request, context -> VisitPlanDetail in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["key"])
            guard let key = try query.single("key") else { throw APIProblem.invalidParameter("key", "name the seed's key") }
            let user = try context.requireUser()
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                guard let index = plan.documents.firstIndex(where: { $0.documentKey == key }) else { throw seedNotFound(key) }
                plan.documents.remove(at: index)
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // The tiers' sheet: Add a priority tier, an unlabeled one at the end (`addingTier`).
        me.post("visits/:planId/tiers") { request, context -> EditedResponse<VisitPlanDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                plan.tiers = ArchiveVisitPlanWrites.addingTier(to: plan.tiers, id: UUID())
            }
            return EditedResponse(status: .created, response: try await answer(rows, projects: try await projects(of: user.id, in: store),
                                                                                 provider: provider, resources: resources))
        }
        // Rename Tier, from the reader's draft: an empty one clears the label (`relabelingTier`).
        me.patch("visits/:planId/tiers/:tierId") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(TierEdit.self, from: request, fields: ["label"])
            let tier = try tierId(try context.parameters.require("tierId"))
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                guard let relabeled = ArchiveVisitPlanWrites.relabelingTier(tier, toDraft: body.label ?? "", in: plan.tiers) else {
                    throw tierNotFound(tier.uuidString)
                }
                plan.tiers = relabeled
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // A tier moved a step up or down, for a keyboard (`movingTier(at:by:in:)`).
        me.post("visits/:planId/tiers/:tierId/move") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(TierMove.self, from: request, fields: ["by"])
            let tier = try tierId(try context.parameters.require("tierId"))
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                guard let index = plan.tiers.firstIndex(where: { $0.id == tier }) else { throw tierNotFound(tier.uuidString) }
                // The kit adds the step to the tier's place before it clamps to the list's ends, so a step past the list,
                // which moves the tier no further, is clamped here first: `Int.max` would overflow the sum.
                let steps = min(max(body.by, -plan.tiers.count), plan.tiers.count)
                plan.tiers = ArchiveVisitPlanWrites.movingTier(at: index, by: steps, in: plan.tiers)
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
        // Delete Tier: its members drop to Unprioritized, and nothing leaves the plan (`removingTier`).
        me.delete("visits/:planId/tiers/:tierId") { request, context -> VisitPlanDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let tier = try tierId(try context.parameters.require("tierId"))
            let time = UserStoreDate.rounded(now())
            let rows = try await changed(try context.parameters.require("planId"), for: user.id, in: store, at: time) { plan in
                guard plan.tiers.contains(where: { $0.id == tier }) else { throw tierNotFound(tier.uuidString) }
                let removal = ArchiveVisitPlanWrites.removingTier(tier, from: plan.tiers, targets: plan.targets)
                plan.tiers = removal.tiers
                for cleared in removal.clearedTargets { plan.targets[cleared.index].tierId = cleared.record.tierId }
            }
            return try await answer(rows, projects: try await projects(of: user.id, in: store), provider: provider, resources: resources)
        }
    }

    // MARK: Reading

    /// The user's plans, the most recently changed first, as `@Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)`
    /// lists them, one never changed last; a tie in the store's order.
    static func plans(of user: String, in store: any UserDataStore) async throws -> [ArchiveVisitPlanExport] {
        let (plans, documents, targets) = try await Blocking.run { try store.visitPlanRows(of: user) }
        var seeds: [String: [ExportRow]] = [:]
        var stored: [String: [ExportRow]] = [:]
        for row in documents { if let plan = row.values["plan_id"]?.text { seeds[UserSearchText.uuidString(plan), default: []].append(row) } }
        for row in targets { if let plan = row.values["plan_id"]?.text { stored[UserSearchText.uuidString(plan), default: []].append(row) } }
        let records = try plans.map { row in
            let key = UserSearchText.uuidString(row.values["id"]?.text ?? "")
            return try record(VisitPlanRows(plan: row, documents: seeds[key] ?? [], targets: stored[key] ?? []))
        }
        return records.enumerated().sorted { a, b in
            let (x, y) = (a.element.lastModified ?? .distantPast, b.element.lastModified ?? .distantPast)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    static func rows(_ id: String, of user: String, in store: any UserDataStore) async throws -> VisitPlanRows {
        guard let rows = try await Blocking.run({ try store.visitPlanRows(id, of: user) }) else { throw notFound(id) }
        return rows
    }

    /// The plan its rows hold, as the export reads one (`ResearchExport.archiveVisits`): its seeds and targets by their
    /// keys, each tie in the store's order.
    static func record(_ rows: VisitPlanRows) throws -> ArchiveVisitPlanExport {
        do {
            return try ResearchExport.plan(
                ResearchExport.Fields("visit_plans", rows.plan),
                documents: try ResearchExport.ordered(rows.documents, in: "visit_documents") { try $0.text("document_key") },
                targets: try ResearchExport.ordered(rows.targets, in: "visit_targets") { try $0.text("target_key") })
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The Archives Visit could not be read: \(error.description)")
        }
    }

    /// The user's projects, as the export reads them.
    static func projects(of user: String, in store: any UserDataStore) async throws -> [ProjectExport] {
        let rows = try await Blocking.run { try store.researchRows(for: user, tables: ["projects"]) }
        do {
            return try ResearchExport.records(rows, "projects", ResearchExport.project)
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "A project could not be read: \(error.description)")
        }
    }

    /// The project a plan is re-seeded from, its first, as the server reads it: its research question and its seed, gathered
    /// as Suggested Next gathers it (`ProjectLeadsService.gatherSeed`); nil when the user no longer holds it, when Re-seed
    /// from Project changes nothing.
    static func projectSeed(of plan: ArchiveVisitPlanExport, among projects: [ProjectExport], for user: String,
                            in store: any UserDataStore) async throws -> ArchiveVisitPlanWrites.ProjectSeed? {
        guard let projectId = plan.projectIds.first, projects.contains(where: { $0.id == projectId }),
              let found = try await ProjectLeadsSeed.gather(projectId.uuidString, of: user, in: store) else { return nil }
        return ArchiveVisitPlanWrites.ProjectSeed(researchQuestion: found.project.researchQuestion, seedKeys: found.seed)
    }

    /// How many of the plan's seeds are in volumes the served index holds, as the list's row counts them; 0 with none.
    static func indexedCount(_ plan: ArchiveVisitPlanExport, served: ServedIndex?) -> Int {
        guard let served else { return 0 }
        return plan.documents.filter { seed in
            ArchiveVisitDerivation.volumeId(ofSeedKey: seed.documentKey).map(served.indexedVolumeIds.contains) ?? false
        }.count
    }

    // MARK: The derivation

    /// The six bundled files the packet reads, as the app's `TripPacketIndexes.bundled` passes its stores: the archival
    /// three, the series facts, the digitized ranges and the roll scans, each decoded once and none for a file missing.
    static func packetIndexes(_ resources: ServerResources) -> TripPacketIndexes {
        TripPacketIndexes(archival: resources.archivalIndexes, seriesFacts: resources.sourceExplorer(\.seriesFacts),
                          digitizedRanges: resources.sourceExplorer(\.digitizedRanges), rollScans: resources.sourceExplorer(\.rollScans))
    }

    /// The catalogue the citation formatter reads, the app's `diffResult?.known ?? bundledEntries`: the published
    /// catalogue's volumes, and the side-loaded ones its overlay holds.
    static func manifestMap(_ resources: ServerResources) -> [String: VolumeManifestEntry] {
        Dictionary((resources.manifest + resources.localVolumes).map { ($0.volumeId, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// How long a derivation is kept: the window its key names.
    static let keptSeconds: TimeInterval = 120

    /// The plan's derivation over `served`, the kit's: its model kept for what it reads of the plan (`VisitDerivationKey`)
    /// in a window of two minutes while the index is served, and the stored state read again over it
    /// (`overlay(for:over:)`), which a write of stored state alone leaves the model as it was; with `facts`, the editor's
    /// facts of each seed and the index's sparsity, kept apart, by the seeds' keys.
    static func derivation(of plan: ArchiveVisitPlanExport, served: ServedIndex, resources: ServerResources,
                           facts wanted: Bool = false) async throws -> VisitDerivation {
        let window = Int(Date().timeIntervalSince1970 / keptSeconds)
        let signature = ArchiveVisitDerivation.inputSignature(plan: plan, indexedVolumeIds: served.indexedVolumeIds)
        let key = VisitDerivationKey(seeds: signature.seeds, inquiryText: plan.inquiryText,
                                     indexedSeedVolumes: signature.indexedSeedVolumes, window: window)
        let kept = try await served.visits.value(for: .model(key)) {
            // Decoded off the main actor, the first time, where the derivation runs.
            let (indexes, manifest) = try await Blocking.run { (packetIndexes(resources), manifestMap(resources)) }
            return .model(await derive(plan, served: served, indexes: indexes, manifest: manifest))
        }
        guard case .model(let once) = kept else { preconditionFailure("a model's key keeps a model") }
        let derived = ArchiveVisitDerivation.Derived(
            model: once.model, overlay: ArchiveVisitDerivation.overlay(for: plan, over: once.model),
            seededDocumentCount: once.seededDocumentCount, indexedDocumentCount: once.indexedDocumentCount)
        guard wanted else { return VisitDerivation(derived: derived, facts: [:], sparsity: nil) }
        let seedKeys = Set(plan.documents.map(\.documentKey)).sorted()
        let known = try await served.visits.value(for: .facts(seedKeys: seedKeys, window: window)) {
            let manifest = try await Blocking.run { manifestMap(resources) }
            return try await seedFacts(seedKeys, served: served, manifest: manifest)
        }
        guard case .facts(let facts, let sparsity) = known else { preconditionFailure("the facts' key keeps facts") }
        return VisitDerivation(derived: derived, facts: facts, sparsity: sparsity)
    }

    /// `ArchiveVisitDerivation.derive` over the served index and the bundled files.
    @MainActor
    static func derive(_ plan: ArchiveVisitPlanExport, served: ServedIndex, indexes: TripPacketIndexes,
                       manifest: [String: VolumeManifestEntry]) async -> ArchiveVisitDerivation.Derived {
        await ArchiveVisitDerivation.derive(plan: plan, indexedVolumeIds: served.indexedVolumeIds,
                                            dataSource: TripPacketDataSource(pipeline: served.pipeline, manifestMap: manifest),
                                            indexes: indexes)
    }

    /// The Documents tab's facts of each seed, through the builder's data source and its two batched queries, as the app's
    /// editor reads them with each derivation, and the index's sparsity, whose read failing keeps nothing.
    @MainActor
    static func seedFacts(_ seedKeys: [String], served: ServedIndex,
                          manifest: [String: VolumeManifestEntry]) async throws -> VisitKept {
        let dataSource = TripPacketDataSource(pipeline: served.pipeline, manifestMap: manifest)
        let measured: (documentsWithReferences: Int, indexedDocuments: Int)
        do {
            measured = try await served.pipeline.externalCitationSparsity()
        } catch {
            throw VisitIndexReadFailed()
        }
        let seeds = seedKeys.compactMap { ArchiveVisitDerivation.documentTuple(fromKey: $0) }
        let records = await dataSource.documentSources(for: seeds)
        let noteKeys = Set(records.map { "\($0.volumeId)/\($0.documentId)" })
        let citations = await dataSource.externalCitations(for: seeds)
        var facts: [String: SeedFacts] = [:]
        for seed in seeds {
            let key = "\(seed.volumeId)/\(seed.documentId)"
            let relevant = (citations[key] ?? []).filter { $0.anchor != "centralFileClass" }
            facts[key] = SeedFacts(header: await dataSource.documentHeader(volumeId: seed.volumeId, documentId: seed.documentId),
                                   volumeTitle: dataSource.volumeTitle(volumeId: seed.volumeId),
                                   hasSourceNote: noteKeys.contains(key), referenceCount: relevant.count)
        }
        return .facts(facts, .init(withReferences: measured.documentsWithReferences, indexed: measured.indexedDocuments))
    }

    /// The model the plan derives over the served index, which a target's write reads its overlay over: the editor's,
    /// rendered before the write. A 503 while no index is served, when no target derives.
    static func derivedModel(_ id: String, of user: String, in store: any UserDataStore, provider: ServedIndexProvider,
                             resources: ServerResources) async throws -> TripPacketModel {
        let plan = try record(try await rows(id, of: user, in: store))
        let served = try await provider.served()
        return try await derivation(of: plan, served: served, resources: resources).derived.model
    }

    // MARK: Writing

    /// Adds `plan` with its seeds and targets, as the import writes a Mac's rows.
    static func added(_ plan: ArchiveVisitPlanExport, for user: String, in store: any UserDataStore) async throws -> VisitPlanRows {
        let change = VisitPlanChange(plan: MacImport.plan(plan).values,
                                     documents: plan.documents.map { MacImport.seed($0, of: plan.id).values },
                                     targets: plan.targets.map { MacImport.target($0, of: plan.id).values })
        do {
            return try await Blocking.run { try store.addVisitPlan(change, for: user) }
        } catch let error as ResearchRowStoreError {
            throw APIProblem(.internalServerError, code: "STORE_REFUSED", detail: error.description)
        }
    }

    /// Changes the user's plan in one write: `edit` makes what it becomes from its record as the write finds it, by the
    /// kit's rules, and each row it changes is stamped `time` as the app's save stamps the models it changed. Throws what
    /// `edit` throws, writing nothing; a 404 for a plan the user does not have.
    static func changed(_ id: String, for user: String, in store: any UserDataStore, at time: Date,
                        _ edit: @escaping @Sendable (inout ArchiveVisitPlanExport) throws -> Void) async throws -> VisitPlanRows {
        let rows: VisitPlanRows?
        do {
            rows = try await Blocking.run {
                try store.changeVisitPlan(id, for: user) { held in
                    let before = try record(held)
                    var after = before
                    try edit(&after)
                    return change(stamped(after, from: before, at: time), from: before)
                }
            }
        } catch let error as ResearchRowStoreError {
            throw APIProblem(.internalServerError, code: "STORE_REFUSED", detail: error.description)
        }
        guard let rows else { throw notFound(id) }
        return rows
    }

    /// `after` with `lastModified` at `time` on each seed and target whose fields differ from `before`'s, and on the plan
    /// when its own fields differ or a seed or target joined or left it, as `ModelModificationStamper` stamps each model a
    /// save changed; a row a rule minted carries the time it was minted at.
    static func stamped(_ after: ArchiveVisitPlanExport, from before: ArchiveVisitPlanExport, at time: Date) -> ArchiveVisitPlanExport {
        var after = after
        let seeds = Dictionary(before.documents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in after.documents.indices {
            guard var held = seeds[after.documents[index].id] else { continue }
            held.lastModified = after.documents[index].lastModified
            if held != after.documents[index] { after.documents[index].lastModified = time }
        }
        let targets = Dictionary(before.targets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in after.targets.indices {
            guard var held = targets[after.targets[index].id] else { continue }
            held.lastModified = after.targets[index].lastModified
            if held != after.targets[index] { after.targets[index].lastModified = time }
        }
        let joinedOrLeft = Set(before.documents.map(\.id)) != Set(after.documents.map(\.id))
            || Set(before.targets.map(\.id)) != Set(after.targets.map(\.id))
        func own(_ plan: ArchiveVisitPlanExport) -> ArchiveVisitPlanExport {
            var plan = plan
            plan.documents = []
            plan.targets = []
            plan.lastModified = nil
            return plan
        }
        if joinedOrLeft || own(after) != own(before) { after.lastModified = time }
        return after
    }

    /// What `after` makes of the rows `before` was read from: every seed and target it keeps, by its id, with the columns
    /// that differ, each new one whole, and the plan's columns that differ, so a column no rule changed is never written.
    static func change(_ after: ArchiveVisitPlanExport, from before: ArchiveVisitPlanExport) -> VisitPlanChange {
        func only(_ values: [String: SQLiteValue], differingFrom held: [String: SQLiteValue]?) -> [String: SQLiteValue] {
            guard let held else { return values }
            return values.filter { $0.key == "id" || held[$0.key] != $0.value }
        }
        let seeds = Dictionary(before.documents.map { ($0.id, MacImport.seed($0, of: before.id).values) }, uniquingKeysWith: { first, _ in first })
        let targets = Dictionary(before.targets.map { ($0.id, MacImport.target($0, of: before.id).values) }, uniquingKeysWith: { first, _ in first })
        return VisitPlanChange(
            plan: only(MacImport.plan(after).values, differingFrom: MacImport.plan(before).values),
            documents: after.documents.map { only(MacImport.seed($0, of: after.id).values, differingFrom: seeds[$0.id]) },
            targets: after.targets.map { only(MacImport.target($0, of: after.id).values, differingFrom: targets[$0.id]) })
    }

    /// Writes `addition` to the plan's seeds, as the app's `apply(_:to:in:)` does: each stored seed it names in the halves
    /// the add turns on, and those alone, and each new record a seed of its own.
    static func apply(_ addition: ArchiveVisitPlanWrites.SeedAddition, to plan: inout ArchiveVisitPlanExport) {
        for update in addition.updated {
            if addition.turnsOnSource { plan.documents[update.index].includeSource = update.record.includeSource }
            if addition.turnsOnExternalRefs { plan.documents[update.index].includeExternalRefs = update.record.includeExternalRefs }
        }
        plan.documents.append(contentsOf: addition.inserted)
    }

    /// `rows` with each id once, the first.
    static func firstOfEachId<Row>(_ rows: [Row], _ id: KeyPath<Row, UUID>) -> [Row] {
        var seen = Set<UUID>()
        return rows.filter { seen.insert($0[keyPath: id]).inserted }
    }

    // MARK: The answer

    /// The editor's state of the plan its rows hold, over the served index, when there is one.
    static func answer(_ rows: VisitPlanRows, projects: [ProjectExport], provider: ServedIndexProvider,
                       resources: ServerResources) async throws -> VisitPlanDetail {
        let plan = try record(rows)
        let served = try await provider.servedIfReady()
        var derivation: VisitDerivation?
        if let served { derivation = try await self.derivation(of: plan, served: served, resources: resources, facts: true) }
        return detail(plan, derivation: derivation, projects: projects)
    }

    /// A stored row's label, the identity segment of its form-aware key (`orphanLabel(forKey:)`, app code).
    static func storedLabel(_ key: String) -> String {
        guard let bar = key.firstIndex(of: "|") else { return key }
        return String(key[key.index(after: bar)...])
    }

    /// The editor's state: the plan, its tiers, and, over a derivation, its sections in the app's order, its stored
    /// targets and each seed's facts.
    static func detail(_ plan: ArchiveVisitPlanExport, derivation: VisitDerivation?, projects: [ProjectExport]) -> VisitPlanDetail {
        let overlay = derivation?.derived.overlay ?? ArchiveVisitOverlay(tiers: plan.tiers)
        let tiers = plan.tiers.map { tier in
            VisitPlanDetail.Tier(id: tier.id.uuidString, label: tier.label, displayName: overlay.displayName(for: tier), order: tier.order,
                                 members: plan.targets.filter { $0.tierId == tier.id }.count)
        }
        let project = plan.projectIds.first.flatMap { id in projects.first { $0.id == id } }
        var sections: [VisitPlanDetail.Section] = []
        var stored: [VisitPlanDetail.StoredTarget] = []
        var summary: String?
        if let derived = derivation?.derived {
            let model = derived.model
            if !plan.documents.isEmpty { summary = ArchiveVisitCounts.editorSummary(of: model) }
            sections = ArchiveVisitCounts.sectionHeadings(of: model.targets).map { heading in
                // Within a repository: tier groups in order, Unprioritized last (§5), label-sorted within a group.
                let members = model.targets.filter { ArchiveVisitCounts.sectionHeading(for: $0) == heading }
                    .sorted {
                        let l = overlay.tierOrderIndex(for: $0.key)
                        let r = overlay.tierOrderIndex(for: $1.key)
                        if l != r { return l < r }
                        return $0.label < $1.label
                    }
                let links = RepositoryFactTable.current.row(forHeading: heading)?.links.filter(\.isPrintable) ?? []
                return VisitPlanDetail.Section(
                    heading: heading, unplaced: heading == ArchiveVisitCounts.unplacedSectionHeading,
                    links: links.map { VisitPlanDetail.Link(label: $0.label, url: $0.url) },
                    targets: members.map { target(of: $0, model: model, overlay: overlay) })
            }
            stored = overlay.orphanKeys.map { key in
                VisitPlanDetail.StoredTarget(key: key, label: storedLabel(key), kind: "orphan", tierId: overlay.tier(for: key)?.id.uuidString,
                                             note: overlay.notes[key], partOf: nil, excludedWhenOwn: false)
            }
            for key in overlay.superseded.keys.sorted() {
                guard let entry = overlay.superseded[key] else { continue }
                stored.append(VisitPlanDetail.StoredTarget(
                    key: key, label: storedLabel(key), kind: "superseded", tierId: overlay.tier(for: key)?.id.uuidString,
                    note: overlay.notes[key],
                    partOf: model.targets.first { $0.key == entry.targetKey }?.label ?? storedLabel(entry.targetKey),
                    excludedWhenOwn: entry.excluded))
            }
        }
        let facts = derivation?.facts ?? [:]
        let documents = plan.documents.map { seed in
            let tuple = ArchiveVisitDerivation.documentTuple(fromKey: seed.documentKey)
            let known = facts[seed.documentKey]
            return VisitPlanDetail.Seed(key: seed.documentKey, volumeId: tuple?.volumeId, documentId: tuple?.documentId,
                                        header: known?.header, volumeTitle: known?.volumeTitle, hasSourceNote: known?.hasSourceNote,
                                        referenceCount: known?.referenceCount, includeSource: seed.includeSource,
                                        includeExternalRefs: seed.includeExternalRefs)
        }
        return VisitPlanDetail(
            id: plan.id.uuidString, name: plan.name, displayName: ArchiveVisitPlanWrites.displayName(of: plan.name),
            inquiryText: plan.inquiryText, projectIds: plan.projectIds.map(\.uuidString),
            project: project.map { VisitPlanDetail.Project(id: $0.id.uuidString, name: $0.name) },
            createdAt: plan.createdAt.map(UserStoreDate.text), lastModified: plan.lastModified.map(UserStoreDate.text),
            deliverables: .init(includeLinks: plan.deliverables.includeLinks, includeTargets: plan.deliverables.includeTargets,
                                includeInquiry: plan.deliverables.includeInquiry, includeCitationCrib: plan.deliverables.includeCitationCrib),
            tiers: tiers, documentCount: plan.documents.count,
            indexedDocumentCount: derivation?.derived.indexedDocumentCount ?? 0, served: derivation != nil, summary: summary,
            sections: sections, storedTargets: stored, documents: documents, sparsity: derivation?.sparsity)
    }

    /// A target's row, as the app's `targetRow` draws it: its lines, its claims' first eight each, its lots, and its
    /// tier, exclusion and note from the overlay.
    static func target(of target: TripPacketModel.Target, model: TripPacketModel, overlay: ArchiveVisitOverlay) -> VisitPlanDetail.Target {
        let limit = TripPacketExporter.seedingRowLimit
        return VisitPlanDetail.Target(
            key: target.key, label: target.label, form: target.form.rawValue, recordsLine: target.recordsLine,
            drawnFrom: target.drawnFrom.prefix(limit).map {
                VisitPlanDetail.DrawnFrom(volumeId: $0.volumeId, documentId: $0.documentId, citation: $0.citation, sourceNote: $0.sourceNote)
            },
            drawnFromCount: target.drawnFrom.count,
            pointedAt: target.pointedAt.prefix(limit).map {
                VisitPlanDetail.PointedAt(volumeId: $0.volumeId, documentId: $0.documentId, line: TripPacketExporter.footnoteLine(for: $0),
                                          rawText: $0.rawText, inherited: $0.inherited)
            },
            pointedAtCount: target.pointedAt.count,
            substitute: target.drawnFrom.contains { model.substitutes.matchesByDocument[$0.id] != nil },
            accessLines: TripPacketExporter.restrictionLines(target.restriction),
            lots: target.lots.map { lot in
                VisitPlanDetail.Lot(title: String(format: "Lot %1$@ — %2$@", lot.lotAsPrinted, CountCopy.documents(lot.documentCount, locale: locale)),
                                    recordsLine: lot.recordsLine, accessLines: TripPacketExporter.restrictionLines(lot.restriction))
            },
            tierId: overlay.tier(for: target.key)?.id.uuidString, excluded: overlay.excludedKeys.contains(target.key),
            note: overlay.notes[target.key])
    }

    /// The locale the server's counts are grouped in, the web's.
    static let locale = Locale(identifier: "en_US")

    // MARK: Refusals

    static func tierId(_ raw: String) throws -> UUID {
        guard let id = UUID(uuidString: raw) else { throw tierNotFound(raw) }
        return id
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "VISIT_NOT_FOUND", detail: "You have no Archives Visit with the id \(id).")
    }

    static func targetNotFound(_ key: String) -> APIProblem {
        APIProblem(.notFound, code: "TARGET_NOT_FOUND", detail: "The plan shows no target and stores no row under the key \(key).")
    }

    static func tierNotFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "TIER_NOT_FOUND", detail: "The plan has no tier with the id \(id).")
    }

    static func seedNotFound(_ key: String) -> APIProblem {
        APIProblem(.notFound, code: "SEED_NOT_FOUND", detail: "No document \(key) seeds the plan.")
    }
}
