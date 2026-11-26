// An Archives Visit's packet, and the ways into a plan that the server resolves (PLAN's S30d).
//
// The packet, `GET /api/v1/me/visits/{id}/packet`, is the app's `TripPacketSheet` over the plan: the kit's exporter
// (`TripPacketExporter`, S30a) over the plan's derivation, the editor's own (ArchiveVisits.swift), with the plan's
// deliverables and stored state, its seed coverage and the day, rendered once for the whole plan or a repository's slice,
// "a render filter, not a second pipeline"; the repositories the sheet's Options offer, with each one's inquiry draft as
// Copy inquiry draft copies it; and the topic the sheet's field opens on, with the project's question its caption reads.
// The sheet writes the topic and the deliverables to the plan through the editor's route (`PATCH …/visits/{id}`). The
// day is the header's stamp, `yyyy-MM-dd` in UTC as the kit prints it: the server's today, or the day the request gives,
// so that the file saved is the text the sheet showed.
//
// `GET …/packet/file` saves it: as text, the exporter's string as it is, which carries Markdown's marks (SPEC's Markdown is
// that text); or as PDF, through the server's PDF service, Gotenberg's Chromium (`FRUS_PDF_URL`), the same text as it is in
// a fixed-width face on US Letter at the app's margins, as the app's PDF is its text (`TripPacketPDFRenderer.render`: Menlo
// at 9 points, 54-point margins, a framesetter's lines). The page is the web's own, since the app's is drawn by CoreText:
// DejaVu Sans Mono, the face Menlo was made from, with its widths and its line height, which the PDF service's image holds,
// the text wrapped where it does not fit, as the framesetter wraps it, and nothing else on the page. Both files are named by
// the kit's rule (`TripPacketPDFRenderer.fileName(title:)`), the text's with `.txt`. A packet's export is kept in no
// history, as the app's sheet keeps none.
//
// The ways in the browser cannot resolve alone: Project Home's Plan a Visit (`POST /api/v1/me/projects/{id}/visit`), which
// opens the project's plan, the most recently changed that names it, or makes one from the project's engaged documents,
// Suggested Next's seed, named after the project, with both halves on (`planVisit(_:)`), and its gate
// (`GET …/visit`); and a collection's reading list (`GET /api/v1/me/collections/{id}/visit-documents`), the one membership
// rule every add from a collection shares (`TripPacketSeed.resolve`): a smart collection's saved search's results, in their
// order, else its documents and excerpts, by the kit's rule over its entries (`staticSeedDocuments(from:)`); and a
// collection authority's record's citing documents (`GET /api/v1/me/archival-collection/documents?id=`,
// `fetchCitingDocumentsForPlan(expected:)`), every document of the served index the record's own match finds, to the app's
// ceiling, under `/me` since only the add reads them.
//
// App code mirrored here, held to its source by ArchivePacketMirrorParityTests: `TripPacketSheet`'s `render(_:)`, its
// `facilities` and `copyDraft(for:)`, its `rebuild()`'s order of refusals, `applyTopicEdit()`'s write and
// `persistDeliverables()`; `TripPacketPDFRenderer.render`'s page; `ProjectHomeView.planVisit(_:)` and `projectPlan`; and
// `CollectionDetailView.fetchCitingDocumentsForPlan(expected:)`.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - Answers

/// The packet's sheet over a plan.
public struct VisitPacket: Codable, Equatable, Sendable, ResponseEncodable {
    /// Why there is no packet, as the sheet's states name the cause: `indexUnavailable`, no index is served, which the
    /// packet reads its source notes from; `noDocuments`, the plan seeds none. Absent with a packet.
    public var unavailable: String?
    /// The packet, the kit's exporter's text: the whole plan, or the slice of `repository`.
    public var text: String?
    /// The day the header's stamp prints, `yyyy-MM-dd`, in UTC as the exporter prints it.
    public var day: String
    /// The repository the packet is scoped to; none for the whole plan, and none for a repository it no longer covers.
    public var repository: String?
    /// The repositories the packet covers, in section order, the plan's exclusions applied: Options ▸ Repository's and
    /// Copy inquiry draft's (`TripPacketExporter.offeredRepositories`).
    public var repositories: [String]
    /// Each of those repositories' inquiry draft alone, as Copy inquiry draft puts it on the pasteboard.
    public var drafts: [Draft]
    /// The plan's topic as stored, which the sheet's field opens on.
    public var topic: String?
    /// What the drafts print for a plan with no topic, the field's placeholder.
    public var topicPlaceholder: String
    /// The research question of the project the plan belongs to, which the field's caption compares it to; none for a
    /// plan with no project the user holds.
    public var researchQuestion: String?
    /// The plan's four deliverables, which the sheet's What to Include writes.
    public var deliverables: VisitPlanDetail.Deliverables
    /// The packet's title, the plan's name as the app shows it, which names its files.
    public var title: String
    /// The PDF's file name, by the kit's rule, and the text's, by the same with `.txt`.
    public var fileName: String
    public var textFileName: String

    public struct Draft: Codable, Equatable, Sendable {
        public var repository: String
        public var text: String
    }
}

/// Project Home's Plan a Visit, before it is pressed: the project's plan, when one names it, and how many documents the
/// project engages, which a new plan would be seeded from. The button is offered with either.
public struct ProjectVisit: Codable, Equatable, Sendable, ResponseEncodable {
    public var planId: String?
    public var engagedDocuments: Int
}

/// What Plan a Visit did: opened the project's plan, or made one.
public struct ProjectVisitAnswer: Codable, Equatable, Sendable, ResponseEncodable {
    public var created: Bool
    public var plan: VisitPlanDetail
}

/// A collection authority's record's citing documents in the served index, every one, as its In Your Library's Add to an
/// Archives Visit seeds a plan from them.
public struct ArchivalCollectionDocuments: Codable, Equatable, Sendable, ResponseEncodable {
    /// The record's name, which the picker's basis quotes and a plan made from them takes.
    public var name: String
    /// How many documents cite it, which `documents` holds all of below the fetch's ceiling.
    public var totalCount: Int
    public var documents: [VisitSeedDocuments.Document]
}

/// A collection's reading list, as an add from it seeds a plan, with the names its picker reads.
public struct VisitSeedDocuments: Codable, Equatable, Sendable, ResponseEncodable {
    public var documents: [Document]
    /// The collection as every list row names it (`CollectionEditorNaming.listName(savedName:)`), the picker's basis.
    public var listName: String
    /// Its name trimmed, which a plan made from it takes; empty for an untitled one, which makes an untitled plan.
    public var suggestedName: String

    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
    }
}

// MARK: - Routes

enum ArchivePacketRoutes {
    /// The citing set's fetch ceiling (`planSeedFetchCeiling`): above the corpus's largest unit, 17,613, so the fetch is
    /// whole in practice; one capped by it says so, as the picker's basis does.
    static let planSeedFetchCeiling = 20_000

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        // The packet's sheet over the plan, rendered once for what it asks: the whole plan or a repository's slice, on a day.
        me.get("visits/:planId/packet") { request, context -> VisitPacket in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["repository", "day"])
            let user = try context.requireUser()
            let rows = try await ArchiveVisitRoutes.rows(try context.parameters.require("planId"), of: user.id, in: store)
            let projects = try await ArchiveVisitRoutes.projects(of: user.id, in: store)
            return try await packet(rows, projects: projects, repository: try query.single("repository"),
                                    day: try generationDay(try query.single("day"), now: now()), provider: provider, resources: resources)
        }

        // The packet saved: as text, or as PDF through the PDF service, for the slice and the day the sheet showed.
        me.get("visits/:planId/packet/file") { request, context -> Response in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["format", "repository", "day"])
            let format = try query.single("format") ?? ""
            guard ["text", "pdf"].contains(format) else {
                throw APIProblem.invalidParameter("format", "\(format) is not a format a packet is saved in: text, pdf.")
            }
            let user = try context.requireUser()
            let pdf = provider.state.pdf
            // Asked first, as the collections' export asks: a PDF with no service answering is refused before anything is
            // derived.
            if format == "pdf", await pdf?.isAvailable() != true { throw PDFRoutes.unavailable }
            let rows = try await ArchiveVisitRoutes.rows(try context.parameters.require("planId"), of: user.id, in: store)
            let projects = try await ArchiveVisitRoutes.projects(of: user.id, in: store)
            let packet = try await packet(rows, projects: projects, repository: try query.single("repository"),
                                          day: try generationDay(try query.single("day"), now: now()), provider: provider, resources: resources)
            guard let text = packet.text else {
                switch packet.unavailable {
                case "indexUnavailable": throw try await indexRefusal(provider)
                default: throw nothingToSave
                }
            }
            guard format == "pdf" else {
                return download(Data(text.utf8), named: packet.textFileName, type: "text/plain; charset=utf-8")
            }
            guard let pdf else { throw PDFRoutes.unavailable }
            do {
                let printed = try await pdf.pdf(fromHTML: page(packet: text, title: packet.title), fields: printFields)
                return download(printed, named: packet.fileName, type: "application/pdf")
            } catch let error as PDFServiceError {
                context.logger.error("The PDF service at \(pdf.url) made no PDF of an Archives Visit's packet: \(error)")
                throw PDFRoutes.problem(error)
            }
        }

        // Project Home's Plan a Visit, before it is pressed: the project's plan and its engaged documents, the gate's two halves.
        me.get("projects/:projectId/visit") { request, context -> ProjectVisit in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let project = try await project(try context.parameters.require("projectId"), of: user.id, in: store)
            let plans = try await ArchiveVisitRoutes.plans(of: user.id, in: store)
            let engaged = try await engagedDocuments(of: project, for: user.id, in: store)
            return ProjectVisit(planId: projectPlan(of: project, among: plans)?.id.uuidString, engagedDocuments: engaged.count)
        }

        // Plan a Visit: the project's plan opened, or made from its engaged documents with both halves on.
        me.post("projects/:projectId/visit") { request, context -> EditedResponse<ProjectVisitAnswer> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let project = try await project(try context.parameters.require("projectId"), of: user.id, in: store)
            let projects = try await ArchiveVisitRoutes.projects(of: user.id, in: store)
            if let existing = projectPlan(of: project, among: try await ArchiveVisitRoutes.plans(of: user.id, in: store)) {
                let rows = try await ArchiveVisitRoutes.rows(existing.id.uuidString, of: user.id, in: store)
                return EditedResponse(response: ProjectVisitAnswer(
                    created: false, plan: try await ArchiveVisitRoutes.answer(rows, projects: projects, provider: provider, resources: resources)))
            }
            // A fresh read of the engaged set, which an empty answer makes no plan from: the gate's promise, kept where the
            // plan is made (#1457 review).
            let engaged = try await engagedDocuments(of: project, for: user.id, in: store)
            guard !engaged.isEmpty else {
                throw APIProblem(.conflict, code: "NOTHING_TO_PLAN",
                                 detail: "This project engages no documents yet: add a collection, a note or a focus tag, then plan a visit.")
            }
            let time = UserStoreDate.rounded(now())
            var plan = ArchiveVisitPlanWrites.newPlan(name: project.name, projectId: project.id, researchQuestion: project.researchQuestion,
                                                      id: UUID(), now: time)
            ArchiveVisitRoutes.apply(ArchiveVisitPlanWrites.addingSeeds(engaged, includeSource: true, includeExternalRefs: true,
                                                                        to: plan.documents, planId: plan.id, now: time), to: &plan)
            let rows = try await ArchiveVisitRoutes.added(plan, for: user.id, in: store)
            let location = context.basePath.prefixing("/api/v1/me/visits/\(plan.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location], response: ProjectVisitAnswer(
                created: true, plan: try await ArchiveVisitRoutes.answer(rows, projects: projects, provider: provider, resources: resources)))
        }

        // `fetchCitingDocumentsForPlan(expected:)`: every indexed document drawn from the record, the match Archival
        // Neighbors runs over its own fields (`collectionNeighbors`), with the limit raised to the ceiling; a query that
        // fails gives none, as the app's `try?` gives no picker.
        me.get("archival-collection/documents") { request, context -> ArchivalCollectionDocuments in
            let query = try FormQuery(request.uri.query)
            try query.refuseUnknown(["id"])
            _ = try context.requireUser()
            guard let id = try query.single("id")?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                throw APIProblem.invalidParameter("id", "name a record of the collection authority")
            }
            // The authority is 2 MB of JSON, decoded once, off the cooperative pool.
            guard let record = try await Blocking.run({ try resources.collectionAuthorityRecord(id) }) else {
                throw APIProblem(.notFound, code: "COLLECTION_NOT_FOUND", detail: "The collection authority has no record \(id).")
            }
            let served = try await provider.served()
            let result = try await context.whileClientConnected {
                (try? await served.pipeline.collectionNeighbors(
                    lotFileNorm: record.lotFileNorm, repository: record.repository, recordGroup: record.recordGroup,
                    names: [record.name] + record.aliases, limit: planSeedFetchCeiling))
                    .map { Citing(documents: $0.documents.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) }, totalCount: $0.totalCount) }
                    ?? Citing(documents: [], totalCount: 0)
            }
            withExtendedLifetime(served) {}
            return ArchivalCollectionDocuments(name: record.name, totalCount: result.totalCount, documents: result.documents)
        }

        // A collection's reading list, as Add to Archives Visit… seeds a plan from it.
        me.get("collections/:collectionId/visit-documents") { request, context -> VisitSeedDocuments in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let collection = try await CollectionRoutes.collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            let documents = try await context.whileClientConnected {
                try await readingList(of: collection, for: user.id, in: store, provider: provider)
            }
            return VisitSeedDocuments(
                documents: documents.map { VisitSeedDocuments.Document(volumeId: $0.volumeId, documentId: $0.documentId) },
                listName: CollectionEditorNaming.listName(savedName: collection.name),
                suggestedName: collection.name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// What the record's match found, as the route carries it out of the client's watch.
    struct Citing: Sendable {
        let documents: [VisitSeedDocuments.Document]
        let totalCount: Int
    }

    // MARK: The packet

    /// The sheet's state over the plan its rows hold: `rebuild()`'s, each unavailable state for its cause, the index first;
    /// then `render(_:)`'s, the exporter over the derived model with the plan's deliverables, its overlay, its seed
    /// coverage and the day, scoped to `repository` while the packet covers it.
    static func packet(_ rows: VisitPlanRows, projects: [ProjectExport], repository: String?, day: (date: Date, text: String),
                       provider: ServedIndexProvider, resources: ServerResources) async throws -> VisitPacket {
        let plan = try ArchiveVisitRoutes.record(rows)
        let title = ArchiveVisitPlanWrites.displayName(of: plan.name)
        let fileName = TripPacketPDFRenderer.fileName(title: title)
        let question = plan.projectIds.first.flatMap { id in projects.first { $0.id == id } }?.researchQuestion
        let deliverables = VisitPlanDetail.Deliverables(
            includeLinks: plan.deliverables.includeLinks, includeTargets: plan.deliverables.includeTargets,
            includeInquiry: plan.deliverables.includeInquiry, includeCitationCrib: plan.deliverables.includeCitationCrib)
        var answer = VisitPacket(unavailable: nil, text: nil, day: day.text, repository: nil, repositories: [], drafts: [],
                                 topic: plan.inquiryText, topicPlaceholder: TripPacketTopicSentence.placeholder,
                                 researchQuestion: question, deliverables: deliverables, title: title, fileName: fileName,
                                 textFileName: String(fileName.dropLast(".pdf".count)) + ".txt")
        guard let served = try await provider.servedIfReady() else {
            answer.unavailable = "indexUnavailable"
            return answer
        }
        guard !plan.documents.isEmpty else {
            answer.unavailable = "noDocuments"
            return answer
        }
        let derived = try await ArchiveVisitRoutes.derivation(of: plan, served: served, resources: resources).derived
        let facilities = TripPacketExporter.offeredRepositories(model: derived.model, overlay: derived.overlay)
        // A re-derived plan can lose the scoped facility; the whole plan beats an empty slice under a stale heading.
        let scope = repository.flatMap { facilities.contains($0) ? $0 : nil }
        answer.repository = scope
        answer.repositories = facilities
        answer.drafts = facilities.map { facility in
            VisitPacket.Draft(repository: facility, text: TripPacketExporter.copiedInquiryDraft(
                model: derived.model, projectName: title, overlay: derived.overlay, repository: facility))
        }
        answer.text = render(derived, title: title, scope: scope, deliverables: plan.deliverables, on: day.date)
        return answer
    }

    /// `render(_:)`: one render path for build, edit, scope and deliverables, so that no pair can compose differently.
    static func render(_ derived: ArchiveVisitDerivation.Derived, title: String, scope: String?,
                       deliverables: ArchiveVisitDeliverables, on day: Date) -> String {
        var exporter = TripPacketExporter(model: derived.model, projectName: title)
        exporter.facilityScope = scope
        exporter.deliverables = deliverables
        exporter.overlay = derived.overlay
        exporter.seededDocumentCount = derived.seededDocumentCount
        exporter.resolvedDocumentCount = derived.indexedDocumentCount
        exporter.generatedOn = day
        return exporter.export()
    }

    /// The day the header's stamp prints, as the kit's exporter prints it, `yyyy-MM-dd` in UTC: the day `raw` names, or
    /// the one it is now; the moment given the exporter is that day's noon, which it prints as that day.
    static func generationDay(_ raw: String?, now: Date) throws -> (date: Date, text: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let parts: DateComponents
        if let raw {
            let fields = raw.split(separator: "-", omittingEmptySubsequences: false)
            guard raw.utf8.count == 10, fields.count == 3, fields.map(\.count) == [4, 2, 2],
                  let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2]) else {
                throw APIProblem.invalidParameter("day", "\(raw) is not a day, yyyy-MM-dd.")
            }
            parts = DateComponents(year: year, month: month, day: day)
        } else {
            parts = calendar.dateComponents([.year, .month, .day], from: now)
        }
        guard let noon = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) else {
            throw APIProblem.invalidParameter("day", "\(raw ?? "") is not a day, yyyy-MM-dd.")
        }
        // The exporter's stamp of that noon, its `stampFormatter`'s `yyyy-MM-dd` in UTC, with the Gregorian calendar.
        let stamped = calendar.dateComponents([.year, .month, .day], from: noon)
        func digits(_ value: Int?, _ width: Int) -> String {
            let text = String(value ?? 0)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        let text = "\(digits(stamped.year, 4))-\(digits(stamped.month, 2))-\(digits(stamped.day, 2))"
        // A day the calendar would roll over, the 31st of November, is none.
        if let raw, text != raw { throw APIProblem.invalidParameter("day", "\(raw) is not a day, yyyy-MM-dd.") }
        return (noon, text)
    }

    /// A plan with no documents has no packet to save, as the editor's Export packet is disabled for it.
    static let nothingToSave = APIProblem(.conflict, code: "NOTHING_TO_EXPORT",
                                          detail: "This plan seeds no documents, so it has no packet to save.")

    /// No index served: the refusal a read of the index answers while none is, as `served()` answers it.
    static func indexRefusal(_ provider: ServedIndexProvider) async throws -> any Error {
        do {
            _ = try await provider.served()
            return APIProblem(.serviceUnavailable, code: "INDEX_NOT_READY", detail: "The index is not ready yet.")
        } catch {
            return error
        }
    }

    /// The file as the browser saves it: its type, and its name as an attachment's.
    static func download(_ data: Data, named name: String, type: String) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = type
        headers[.contentDisposition] = CollectionExportRoutes.attachment(name)
        headers[.cacheControl] = "no-store"
        headers[.xContentTypeOptions] = "nosniff"
        return Response(status: .ok, headers: headers, body: .init(byteBuffer: ByteBuffer(bytes: data)))
    }

    // MARK: The PDF

    /// The app's page (`TripPacketPDFRenderer.render`): 612 by 792 points, US Letter, with 54 points of margin, in
    /// Gotenberg's inches; nothing in the background, which the app's page draws none of.
    static let printFields: [(name: String, value: String)] = [
        ("paperWidth", "8.5"), ("paperHeight", "11"),
        ("marginTop", "0.75"), ("marginBottom", "0.75"), ("marginLeft", "0.75"), ("marginRight", "0.75"),
    ]

    /// The page Chromium prints: the packet's text as it is, black, in a fixed-width face at 9 points, Menlo's own
    /// metrics in DejaVu Sans Mono, the face Menlo was drawn from, which the PDF service's image holds, each line as the
    /// text breaks it and one too long for the page wrapped where it does not fit, as the app's framesetter wraps it.
    /// Its title names the PDF as its file does. It loads nothing and runs nothing.
    static func page(packet: String, title: String) -> Data {
        let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <title>\(escaped(String(TripPacketPDFRenderer.fileName(title: title).dropLast(".pdf".count))))</title>
            <style>
            html, body { margin: 0; padding: 0; background: #fff; }
            pre { margin: 0; color: #000; font-family: "DejaVu Sans Mono", monospace; font-size: 9pt; line-height: normal;
                  white-space: pre-wrap; overflow-wrap: break-word; tab-size: 8; }
            </style>
            </head>
            <body><pre>\(escaped(packet))</pre></body>
            </html>

            """
        return Data(html.utf8)
    }

    /// `text` as HTML's text, its markup's three characters escaped.
    static func escaped(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(character)
            }
        }
        return out
    }

    // MARK: Plan a Visit

    /// The user's project `id`, as the export reads it; a 404 for one they do not hold.
    static func project(_ id: String, of user: String, in store: any UserDataStore) async throws -> ProjectExport {
        let projects = try await ArchiveVisitRoutes.projects(of: user, in: store)
        guard let project = projects.first(where: { $0.id.uuidString == UserSearchText.uuidString(id) }) else {
            throw APIProblem(.notFound, code: "PROJECT_NOT_FOUND", detail: "You have no project with the id \(id).")
        }
        return project
    }

    /// `projectPlan`: the project's plan, the most recently changed of the user's plans that name it, however it was made.
    static func projectPlan(of project: ProjectExport, among plans: [ArchiveVisitPlanExport]) -> ArchiveVisitPlanExport? {
        plans.first { $0.projectIds.contains(project.id) }
    }

    /// `engagedPacketDocuments(forProject:in:)`: the project's engaged documents, Suggested Next's seed, the union of its
    /// collections, its notes and its focus tags (`ProjectLeadsService.gatherSeed`), each key as a document's ids.
    static func engagedDocuments(of project: ProjectExport, for user: String, in store: any UserDataStore) async throws
        -> [(volumeId: String, documentId: String)] {
        let keys = try await ProjectLeadsSeed.gather(project.id.uuidString, of: user, in: store)?.seed ?? []
        return keys.compactMap { DocumentKey(compositeString: $0)?.tuple }
    }

    // MARK: A collection's reading list

    /// `TripPacketSeed.resolve(collection:appState:modelContext:)`: a smart collection's saved search's results, in their
    /// order; a static one's documents and excerpts, de-duplicated, by the kit's rule.
    static func readingList(of collection: CollectionExport, for user: String, in store: any UserDataStore,
                            provider: ServedIndexProvider) async throws -> [(volumeId: String, documentId: String)] {
        if collection.savedSearchId != nil {
            let refs = try await CollectionExportRoutes.smartRefs(of: collection, for: user, in: store, provider: provider)
            return refs.sorted { $0.sortOrder < $1.sortOrder }
                .map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        }
        return TripPacketSeed.staticSeedDocuments(from: collection.entries.map {
            (kind: $0.entryKind, volumeId: $0.volumeId, documentId: $0.documentId, sortOrder: $0.sortOrder)
        })
    }
}
