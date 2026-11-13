// The update review (PLAN's S21f): what changed in a document since a user annotated it, and the review of it,
// as the app's `DocumentChangeBanner` and `DocumentChangeReviewSheet` show them, the sheet the web's own over the
// kit's rules. A change is the index's record of it, `document_revisions`, which the kit's `indexVolume` stamps
// when a corrected volume is indexed again (a Standalone server's Update), or, in Import mode, the comparison of
// the served export with the mounted TEI (`TEIChangeCheck`, the import's step 5). Each user's review is their row
// in the store's `annotation_reviews`, the app's ledger, read by the kit's rule for it (`AnnotationReviewLedger`),
// so that one user's review hides a change from no other; a Standalone server records it in its index too,
// through its one writer (ReviewStamps.swift). The sheet's rules are the kit's: a highlight's standing
// (`HighlightReview.status`), the search for its passage in the text as it reads now (`HighlightReanchor.locate`),
// a quotation's check (`ExcerptVerifier`, `ExcerptReview.lines`); its sentences, and the banner's, are the app's,
// mirrored below and held to the app's source by UpdateReviewParityTests.
//   GET  /api/v1/me/volumes/{v}/documents/{d}/change    the banner: the change, and whether highlights are stale
//   GET  /api/v1/me/volumes/{v}/documents/{d}/review    the review sheet
//   POST /api/v1/me/volumes/{v}/documents/{d}/review    Mark Reviewed
//   POST /api/v1/me/highlights/{id}/confirm             Confirm: the highlight kept where it is, at the text's version
//   POST /api/v1/me/highlights/{id}/move                Move Here: to where the kit's search found its passage

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

// MARK: - Where the changes are read

/// Where an update's changes are read: the served index's, and in Import mode the comparison with the TEI.
struct UpdateReviewSources: Sendable {
    let indexer: LibraryIndexer?
    let teiCheck: TEIChangeCheck?

    static func key(_ volumeId: String, _ documentId: String) -> String { "\(volumeId)/\(documentId)" }

    /// One document's change, and the comparison index that found it, for a change Import mode's step 5 found.
    struct Change: Sendable {
        let revision: IndexingPipeline.DocumentRevision
        let comparison: TEIComparison?
    }

    /// Every change stamped, by `"volumeId/documentId"`: the served index's, reviewed or not, of a volume it holds,
    /// and in Import mode each its step 5 found, which takes the place of the index's own for its document.
    func changes(_ served: ServedIndex?) async -> [String: Change] {
        var changes: [String: Change] = [:]
        if let served {
            let rows = ((try? await served.pipeline.unreviewedDocumentRevisions()) ?? [])
                + ((try? await served.pipeline.reviewedDocumentRevisions()) ?? [])
            for row in rows where row.changedAt != nil {
                changes[Self.key(row.volumeId, row.documentId)] = Change(revision: row, comparison: nil)
            }
        }
        if let comparison = await teiCheck?.comparison() {
            let changedVolumes = Set(comparison.record.changed)
            for row in (try? await comparison.pipeline.unreviewedDocumentRevisions()) ?? []
            where row.changedAt != nil && changedVolumes.contains(row.volumeId) {
                changes[Self.key(row.volumeId, row.documentId)] = Change(revision: row, comparison: comparison)
            }
        }
        return changes
    }

    /// One document's change, if one is stamped.
    func change(of document: DocumentKey, _ served: ServedIndex?) async -> Change? {
        // A volume the comparison found changed: one it could not compare holds no change of its.
        if let comparison = await teiCheck?.comparison(), comparison.record.changed.contains(document.volumeId),
           let row = try? await comparison.pipeline.documentRevision(volumeId: document.volumeId, documentId: document.documentId),
           row.changedAt != nil {
            return Change(revision: row, comparison: comparison)
        }
        guard let served,
              let row = try? await served.pipeline.documentRevision(volumeId: document.volumeId, documentId: document.documentId),
              row.changedAt != nil else { return nil }
        return Change(revision: row, comparison: nil)
    }

    /// The document's text as the index the check reads holds it, for its quotations' check: the comparison's,
    /// the TEI's as it reads now, for a change Import mode's step 5 found, else the served index's.
    func bodyTexts(of document: DocumentKey, change: Change?, _ served: ServedIndex?) async -> [String: String] {
        let keys = [WordCloudDocumentKey(volumeId: document.volumeId, documentId: document.documentId)]
        if let comparison = change?.comparison {
            return (try? await comparison.pipeline.documentBodyTextsByKey(forKeys: keys)) ?? [:]
        }
        return (try? await served?.pipeline.documentBodyTextsByKey(forKeys: keys)) ?? [:]
    }
}

// MARK: - The app's sentences

/// The banner's sentence and the sheet's lines, mirrored from the app's `DocumentChangeBanner.line(revision:
/// highlightsStale:)` and `DocumentChangeReviewSheet`'s `statusLine` and `searchLine` (app code, SwiftUI views'
/// static functions), held to their source by UpdateReviewParityTests. Where the app says "this device", the web
/// says "this server", its own.
enum DocumentChangeWords {
    /// The banner's sentence for a change `kind`, stamped and not yet reviewed by the user, or none, and whether a
    /// stored highlight is stale: the app's truth table, with the user's own review in place of the device's.
    static func bannerLine(kind: String?, highlightsStale: Bool) -> String? {
        switch (kind, highlightsStale) {
        case (nil, false):
            return nil
        case (nil, true):
            return "Some highlights may be misaligned — the document has been updated since they were created."
        case ("body", false):
            return "The text of this document changed in a volume update. Highlight positions may have moved."
        case ("body", true):
            return "The text of this document changed in a volume update. Some highlights may be misaligned."
        case ("apparatus", false):
            return "Footnotes, the source note, or the heading changed in a volume update. The text did not."
        case ("apparatus", true):
            return "Footnotes, the source note, or the heading changed in a volume update, and some highlights may be misaligned."
        case ("vanished", _):
            return "This document is no longer in the volume."
        case (_, true):
            // A kind this build does not know, with stale highlights: the hedge still holds.
            return "Some highlights may be misaligned — the document has been updated since they were created."
        case (_, false):
            return nil
        }
    }

    /// The sheet's change section for a document an update removed.
    static let vanished = "This document is no longer in the volume — either a volume update removed it, or a change to how the app reads the volume no longer finds it. Everything you attached to it is kept until you remove it."
    /// The sheet's change section with no change to say: the app's, of this server.
    static let noChange = "No change to this document is recorded on this server."

    /// A highlight's standing, in the sheet's words.
    static func statusLine(_ status: HighlightReview.Status, vanished: Bool) -> String {
        if vanished { return "The document it was made on is no longer in the volume." }
        switch status {
        case .aligned:
            return "Matches the current text."
        case .stale(hasPassage: true):
            return "Made against an earlier version of the text — its position may have moved."
        case .stale(hasPassage: false):
            return "Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye."
        case .unverifiable:
            return "This server has no record to compare it against."
        }
    }

    /// What the search for a highlight's passage found, in the sheet's words, or none.
    static func searchLine(_ search: HighlightReanchor.Search) -> String? {
        switch search {
        case .here:
            return "Found once, still in this position."
        case .moved:
            return "Found once, at a new position in the corrected text."
        case .foundFar:
            return "Found once, but far from where it was. This can mean the document was renumbered and this one is not the same document — check it before moving anything by hand."
        case .notFound:
            return "Not found in the current text. The passage may have been edited, or this document may have been renumbered."
        case .ambiguous(let count):
            return "Found \(count) times, so the app cannot tell which one is yours."
        case .refused(.tooShort):
            return "Too short to look for: a passage this brief can repeat, so finding it once would not prove anything."
        case .noPassage, .refused:
            return nil
        }
    }

    /// The move the sheet offers: one place, close to the stored one (`offeredMove`), never one far away.
    static func offeredMove(_ search: HighlightReanchor.Search?) -> HighlightReanchor.Match? {
        guard case .moved(let match)? = search else { return nil }
        return match
    }

    /// A note's row: its first line with words, trimmed, as the app's `noteRowTitle` reads it, or nil for none.
    static func noteRowTitle(_ bodyText: String) -> String? {
        let firstLine = bodyText
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        return firstLine.isEmpty ? nil : firstLine
    }

    /// The search's outcome, by name, for the browser app.
    static func name(_ search: HighlightReanchor.Search) -> String {
        switch search {
        case .noPassage: "noPassage"
        case .refused: "refused"
        case .notFound: "notFound"
        case .here: "here"
        case .moved: "moved"
        case .foundFar: "foundFar"
        case .ambiguous: "ambiguous"
        }
    }
}

// MARK: - The answers

/// `GET …/change`: what the banner says of a document, for the user.
public struct DocumentChange: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    /// The banner's sentence; absent when there is nothing to say.
    public var line: String?
    /// `body`, `apparatus` or `vanished`: the change stamped, while the user has not reviewed it.
    public var changeKind: String?
    /// When the change was stamped, and when the user reviewed it.
    public var changedAt: String?
    public var reviewedAt: String?
    /// The change's content hash, which Mark Reviewed sends back, so that it reviews the change the user was shown.
    public var contentHash: String?
    /// Whether one of the user's highlights on it was made against another version of its text.
    public var highlightsStale: Bool
    /// Whether an update removed the document from its volume (the kit's `recordsRemoval`).
    public var vanished: Bool
    /// Whether Mark Reviewed is offered: a change is stamped that the user has not reviewed.
    public var canMarkReviewed: Bool
    /// Whether Import mode's comparison with the TEI found the change, rather than the index's own record.
    public var foundInTEI: Bool
}

/// `GET …/review`: the review sheet.
public struct DocumentReview: Codable, Equatable, Sendable, ResponseEncodable {
    public var change: DocumentChange
    /// The version of the text the sheet judges by: the page's as it renders now, else the change's record.
    public var currentVersion: String?
    /// What the change section says: the banner's sentence, the vanished one, or that none is recorded.
    public var changeLine: String
    /// The user's highlights on it, where each starts.
    public var highlights: [ReviewHighlight]
    /// The quotations the user's collections took from it.
    public var excerpts: [ReviewExcerpt]
    public var others: ReviewOthers
}

public struct ReviewHighlight: Codable, Equatable, Sendable {
    public var id: String
    public var colorTag: String
    public var selectedText: String
    public var startOffset: Int
    public var endOffset: Int
    /// `aligned`, `stale` or `unverifiable`, the kit's `HighlightReview.Status`.
    public var status: String
    public var statusLine: String
    /// What the search for its passage found, by name, for a highlight not aligned; and in the sheet's words.
    public var search: String?
    public var searchLine: String?
    /// Where the search found it, with what surrounds it, for one found once.
    public var context: Context?
    /// Whether Move Here is offered, and Confirm.
    public var canMove: Bool
    public var canConfirm: Bool

    public struct Context: Codable, Equatable, Sendable {
        public var before: String
        public var found: String
        public var after: String
        public var start: Int
        public var end: Int
    }
}

public struct ReviewExcerpt: Codable, Equatable, Sendable {
    public var id: String
    public var collectionId: String
    /// The collection's name as its row prints it.
    public var collectionName: String
    public var text: String
    /// The kit's `ExcerptReview.lines`: what the check found, and which version the words were taken from.
    public var finding: String
    public var capture: String?
    /// The kit's `ExcerptReview.isWarning`.
    public var warning: Bool
}

public struct ReviewOthers: Codable, Equatable, Sendable {
    /// The notes on it, newest first, each with its first line, absent for one with none.
    public var notes: [Note]
    public var tagCount: Int
    /// The collections that hold it as a document.
    public var collectionCount: Int
    /// Its summaries, headnote drafts left out.
    public var summaryCount: Int
    public var inVisitPlan: Bool

    public struct Note: Codable, Equatable, Sendable {
        public var id: String
        public var title: String?
    }
}

// MARK: - The routes

enum ReviewRoutes {
    struct Version: Decodable {
        /// The version of the text the sheet judged by, which the server's must be.
        let renderingVersion: String
    }

    /// What Mark Reviewed reviews: the change the sheet showed.
    struct Reviewed: Decodable {
        let contentHash: String
        let changeKind: String?
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider, reviews: UpdateReviewSources) {
        let store = services.store
        let now = services.now

        me.get("volumes/:volumeId/documents/:documentId/change") { request, context -> EditedResponse<DocumentChange> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let key = try UserDataRoutes.document(context, resources: resources)
            let served = try? await provider.servedIfReady()
            let change = await reviews.change(of: key, served)
            let version = await currentVersion(of: key, reader: reader, change: change)
            let (highlights, ledger) = try await Blocking.run {
                (try store.highlights(of: key, for: user.id), try store.documentReviews(of: key, for: user.id))
            }
            let body = documentChange(key, change: change, ledger: ledger,
                                      highlightsStale: stale(highlights, currentVersion: version))
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }

        me.get("volumes/:volumeId/documents/:documentId/review") { request, context -> EditedResponse<DocumentReview> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let key = try UserDataRoutes.document(context, resources: resources)
            let body = try await review(key, user: user.id, store: store, reader: reader, provider: provider,
                                        resources: resources, reviews: reviews)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }

        // Mark Reviewed: the user's ledger row, from the change the user is dispositioning, the one the sheet showed, as
        // the app records it first; then, on a Standalone server, the index's own stamp, a job of its one writer.
        me.post("volumes/:volumeId/documents/:documentId/review") { request, context -> EditedResponse<DocumentChange> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let key = try UserDataRoutes.document(context, resources: resources)
            let shown = try await JSONBody.decode(Reviewed.self, from: request, fields: ["contentHash", "changeKind"])
            // While a job holds the index to itself, its 503, rather than nothing to review.
            let served = try await provider.served()
            guard let change = await reviews.change(of: key, served) else { throw nothingToReview(key) }
            let revision = change.revision
            guard revision.contentHash == shown.contentHash, revision.changeKind == shown.changeKind else {
                throw APIProblem(.conflict, code: "DOCUMENT_CHANGED",
                                 detail: "The change to \(key.volumeId)/\(key.documentId) is not the one the review showed: another update has changed the document since. Load the review again.")
            }
            let ledger = try await Blocking.run { try store.documentReviews(of: key, for: user.id) }
            guard !AnnotationReviewLedger.reviews(ledger, revision) else { throw nothingToReview(key) }
            guard !revision.contentHash.isEmpty else { throw nothingToReview(key) }
            let time = now()
            _ = try await Blocking.run {
                try store.recordDocumentReview(of: key, contentHash: revision.contentHash, changeKind: revision.changeKind,
                                               for: user.id, at: time)
            }
            if change.comparison == nil, let indexer = reviews.indexer, indexer.mode == .standalone {
                do {
                    try await indexer.recordReviews(requestedBy: user.id) { try await settledReviews(store: store) }
                } catch {
                    // The user's review is theirs already; the index's own record of it waits for the next.
                    context.logger.warning("A review of \(key.volumeId)/\(key.documentId) could not be queued for the index: \(error)")
                }
            }
            context.logger.info("\(user.id) marked \(key.volumeId)/\(key.documentId) reviewed")
            let version = await currentVersion(of: key, reader: reader, change: change)
            let (highlights, after) = try await Blocking.run {
                (try store.highlights(of: key, for: user.id), try store.documentReviews(of: key, for: user.id))
            }
            let body = documentChange(key, change: change, ledger: after, highlightsStale: stale(highlights, currentVersion: version))
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }

        // Confirm, as the app's: the highlight's version becomes the text's, its offsets as they were.
        me.post("highlights/:highlightId/confirm") { request, context -> Highlight in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("highlightId")
            let body = try await JSONBody.decode(Version.self, from: request, fields: ["renderingVersion"])
            guard let highlight = try await Blocking.run({ try store.highlight(id, of: user.id) }) else {
                throw HighlightRoutes.problem(.highlightNotFound(id))
            }
            let page = try await HighlightRoutes.page(of: highlight.document, reader: reader, provider: provider, resources: resources)
            try sameVersion(body.renderingVersion, page.renderingVersion)
            guard case .stale = HighlightReview.status(renderingVersion: highlight.renderingVersion, selectedText: highlight.selectedText,
                                                       currentVersion: page.renderingVersion) else {
                throw APIProblem(.conflict, code: "HIGHLIGHT_ALIGNED", detail: "The highlight matches the current text already.")
            }
            return Highlight(try await stored {
                try store.anchorHighlight(id, renderingVersion: page.renderingVersion, span: nil, for: user.id)
            }, currentVersion: page.renderingVersion)
        }

        // Move Here, as the app's: to the one place the kit's search found the highlight's passage, close to where it
        // was, searched again here so that a highlight moves only where the kit says.
        me.post("highlights/:highlightId/move") { request, context -> Highlight in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("highlightId")
            let body = try await JSONBody.decode(Version.self, from: request, fields: ["renderingVersion"])
            guard let highlight = try await Blocking.run({ try store.highlight(id, of: user.id) }) else {
                throw HighlightRoutes.problem(.highlightNotFound(id))
            }
            let page = try await HighlightRoutes.page(of: highlight.document, reader: reader, provider: provider, resources: resources)
            try sameVersion(body.renderingVersion, page.renderingVersion)
            let status = HighlightReview.status(renderingVersion: highlight.renderingVersion, selectedText: highlight.selectedText,
                                                currentVersion: page.renderingVersion)
            let search = status == .aligned ? nil : HighlightReanchor.locate(
                passage: highlight.selectedText, storedStart: highlight.startOffset, storedEnd: highlight.endOffset,
                in: buildFlatTextBlocks(from: page.model))
            guard let match = DocumentChangeWords.offeredMove(search) else {
                throw APIProblem(.conflict, code: "HIGHLIGHT_NOT_MOVABLE",
                                 detail: "The highlight's passage is not found once, close to where it was, in the current text, so it is not moved.")
            }
            return Highlight(try await stored {
                try store.anchorHighlight(id, renderingVersion: page.renderingVersion, span: (match.start, match.end), for: user.id)
            }, currentVersion: page.renderingVersion)
        }
    }

    // MARK: The sheet

    static func review(_ key: DocumentKey, user: String, store: any UserDataStore, reader: ReaderService,
                       provider: ServedIndexProvider, resources: ServerResources, reviews: UpdateReviewSources) async throws -> DocumentReview {
        let served = try? await provider.servedIfReady()
        let change = await reviews.change(of: key, served)
        let vanished = change?.revision.recordsRemoval ?? false
        // The text as it reads now, as the reader renders it, unless an update removed the document.
        var page: HighlightRoutes.Page?
        if !vanished {
            do {
                page = try await HighlightRoutes.page(of: key, reader: reader, provider: provider, resources: resources)
            } catch let problem as APIProblem where ["TEI_NOT_AVAILABLE", "DOCUMENT_NOT_FOUND"].contains(problem.code) {
                page = nil
            }
        }
        let version: String? = page?.renderingVersion ?? change.map(\.revision.bodyHash).flatMap { $0.isEmpty ? nil : $0 }
        let columns: [String: Set<String>] = [
            "notes": ["id", "volume_id", "document_id", "body_text", "last_modified"],
            "tag_assignments": ["volume_id", "document_id", "tag_id"],
            "collections": ["id", "name"],
            "collection_entries": ["id", "collection_id", "kind", "volume_id", "document_id", "text", "sort_order",
                                   "excerpt_rendering_version"],
            "summaries": ["volume_id", "document_id", "is_headnote_draft"],
            "visit_documents": ["document_key"],
        ]
        let (highlights, ledger, rows) = try await Blocking.run {
            (try store.highlights(of: key, for: user), try store.documentReviews(of: key, for: user),
             try store.researchRows(for: user, columns: columns))
        }
        let ofDocument = { (table: String) -> [ResearchExport.Fields] in
            rows[table].map { ResearchExport.Fields(table, $0) }
                .filter { $0.optionalText("volume_id") == key.volumeId && $0.optionalText("document_id") == key.documentId }
        }

        // The highlights, by where each starts, as the app's query sorts them; each with its standing and, for one not
        // aligned, the kit's search for its passage in the text as it reads now.
        let blocks = page.map { buildFlatTextBlocks(from: $0.model) }
        let rowsOfHighlights = highlights.sorted {
            $0.startOffset != $1.startOffset ? $0.startOffset < $1.startOffset : $0.id < $1.id
        }.map { highlight -> ReviewHighlight in
            let status = HighlightReview.status(renderingVersion: highlight.renderingVersion, selectedText: highlight.selectedText,
                                                currentVersion: version)
            var search: HighlightReanchor.Search?
            if !vanished, status != .aligned, let blocks {
                search = HighlightReanchor.locate(passage: highlight.selectedText, storedStart: highlight.startOffset,
                                                  storedEnd: highlight.endOffset, in: blocks)
            }
            var shown: ReviewHighlight.Context?
            if let blocks, let search {
                switch search {
                case .moved(let match), .foundFar(let match):
                    let radius = 100
                    shown = .init(before: flatTextExcerpt(blocks: blocks, start: max(0, match.start - radius), end: match.start) ?? "",
                                  found: flatTextExcerpt(blocks: blocks, start: match.start, end: match.end) ?? highlight.selectedText,
                                  after: flatTextExcerpt(blocks: blocks, start: match.end, end: match.end + radius) ?? "",
                                  start: match.start, end: match.end)
                default:
                    break
                }
            }
            let statusName = switch status {
            case .aligned: "aligned"
            case .stale: "stale"
            case .unverifiable: "unverifiable"
            }
            var staleNow = false
            if case .stale = status { staleNow = true }
            return ReviewHighlight(
                id: highlight.id, colorTag: highlight.colorTag, selectedText: highlight.selectedText,
                startOffset: highlight.startOffset, endOffset: highlight.endOffset, status: statusName,
                statusLine: DocumentChangeWords.statusLine(status, vanished: vanished),
                search: search.map(DocumentChangeWords.name), searchLine: search.flatMap(DocumentChangeWords.searchLine),
                context: shown,
                canMove: !vanished && page != nil && DocumentChangeWords.offeredMove(search) != nil,
                canConfirm: !vanished && staleNow && page != nil)
        }

        // The quotations, each checked against the text as the index the check reads holds it now, as the export's
        // check does, with the version it was taken from: the kit's sentences, composed by the kit.
        let collectionNames = Dictionary(rows["collections"].compactMap { row -> (String, String)? in
            let fields = ResearchExport.Fields("collections", row)
            guard let id = fields.optionalText("id") else { return nil }
            return (id.uppercased(), fields.optionalText("name") ?? "")
        }, uniquingKeysWith: { first, _ in first })
        let entries = ofDocument("collection_entries")
        struct Quotation { let id, collectionId, name, text: String; let sortOrder: Int; let version: String? }
        let quotations = entries.compactMap { entry -> Quotation? in
            guard entry.optionalText("kind") == CollectionEntryKind.excerpt.rawValue, let text = entry.optionalText("text"), !text.isEmpty,
                  let id = entry.optionalText("id"), let collection = entry.optionalText("collection_id") else { return nil }
            return Quotation(id: id, collectionId: collection, name: collectionNames[collection.uppercased()] ?? "", text: text,
                             sortOrder: (try? entry.int("sort_order")) ?? 0, version: entry.optionalText("excerpt_rendering_version"))
        }.sorted {
            let order = CollectionEditorNaming.listOrder($0.name, $1.name)
            if order != .orderedSame { return order == .orderedAscending }
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.id < $1.id
        }
        var excerpts: [ReviewExcerpt] = []
        if !quotations.isEmpty {
            let requests = quotations.map { ExcerptVerifier.Request(volumeId: key.volumeId, documentId: key.documentId, text: $0.text) }
            let bodies = await reviews.bodyTexts(of: key, change: change, served)
            let outcomes = ExcerptVerifier.upgradingVanished(
                ExcerptVerifier.verify(requests, bodyTexts: bodies),
                changeKinds: [UpdateReviewSources.key(key.volumeId, key.documentId): change?.revision.changeKind ?? ""])
            excerpts = zip(quotations, requests).compactMap { quotation, request in
                guard let outcome = outcomes[request] else { return nil }
                let lines = ExcerptReview.lines(outcome: outcome, storedVersion: quotation.version, currentVersion: version)
                return ReviewExcerpt(id: quotation.id, collectionId: quotation.collectionId,
                                     collectionName: CollectionEditorNaming.listName(savedName: quotation.name), text: quotation.text,
                                     finding: lines.finding, capture: lines.capture, warning: ExcerptReview.isWarning(outcome))
            }
        }

        // The other annotations, counted, and the notes, which the sheet opens.
        let notes = ofDocument("notes").sorted {
            let l = (try? $0.optionalDate("last_modified")) ?? nil, r = (try? $1.optionalDate("last_modified")) ?? nil
            let (left, right) = (l ?? .distantPast, r ?? .distantPast)
            return left != right ? left > right : ($0.optionalText("id") ?? "") < ($1.optionalText("id") ?? "")
        }.map { ReviewOthers.Note(id: $0.optionalText("id") ?? "", title: DocumentChangeWords.noteRowTitle($0.optionalText("body_text") ?? "")) }
        let summaries = ofDocument("summaries").filter { ((try? $0.bool("is_headnote_draft")) ?? false) == false }.count
        let documentKey = UpdateReviewSources.key(key.volumeId, key.documentId)
        let inVisitPlan = rows["visit_documents"].contains {
            ResearchExport.Fields("visit_documents", $0).optionalText("document_key") == documentKey
        }
        let others = ReviewOthers(notes: notes, tagCount: ofDocument("tag_assignments").count,
                                  collectionCount: entries.filter { $0.optionalText("kind") == CollectionEntryKind.document.rawValue }.count,
                                  summaryCount: summaries, inVisitPlan: inVisitPlan)

        let highlightsStale = rowsOfHighlights.contains { $0.status == "stale" }
        let state = documentChange(key, change: change, ledger: ledger, highlightsStale: highlightsStale)
        let line = vanished ? DocumentChangeWords.vanished
            : DocumentChangeWords.bannerLine(kind: state.changeKind, highlightsStale: highlightsStale) ?? DocumentChangeWords.noChange
        return DocumentReview(change: state, currentVersion: version, changeLine: line, highlights: rowsOfHighlights,
                              excerpts: excerpts, others: others)
    }

    // MARK: Helpers

    /// The reviews the index records (ReviewStamps.swift), and those Administration's tallies count, in both modes: a
    /// change every user whose research is on the document has reviewed, by their ledgers, or, on a document no one's
    /// research is on, one anyone has, one row for each, which the kit's `applyAnnotationReviews` matches to the change.
    static func settledReviews(store: any UserDataStore) async throws -> [AnnotationReviewData] {
        let ledgers = try await Blocking.run { try store.everyDocumentReview() }
        guard !ledgers.isEmpty else { return [] }
        return settledReviews(ledgers: ledgers, annotators: try await annotators(store: store))
    }

    /// The same, over every user's ledger and whose research is on each document.
    static func settledReviews(ledgers: [String: [AnnotationReviewRecord]], annotators: [String: Set<String>]) -> [AnnotationReviewData] {
        // Who reviewed each change, by its document, content hash and change kind.
        var reviewers: [AnnotationReviewData: Set<String>] = [:]
        for (user, rows) in ledgers {
            for row in rows where row.annotationType == AnnotationReviewLedger.documentKind {
                reviewers[row.data, default: []].insert(user)
            }
        }
        return reviewers.compactMap { change, users in
            let concerned = annotators[UpdateReviewSources.key(change.volumeId, change.documentId)] ?? []
            return concerned.isSubset(of: users) ? change : nil
        }
    }

    /// Whose research is on each document, by `"volumeId/documentId"`: every user's, as the Research page gathers it.
    static func annotators(store: any UserDataStore) async throws -> [String: Set<String>] {
        var annotators: [String: Set<String>] = [:]
        for account in try await Blocking.run({ try store.accounts() }) {
            for key in ResearchGroups(sources: try await ResearchSources.read(for: account.id, in: store)).allAnnotatedKeys {
                annotators[key, default: []].insert(account.id)
            }
        }
        return annotators
    }

    /// What the banner says, for the user: the change's kind while they have not reviewed it.
    static func documentChange(_ key: DocumentKey, change: UpdateReviewSources.Change?, ledger: [AnnotationReviewRecord],
                               highlightsStale: Bool) -> DocumentChange {
        let revision = change?.revision
        let reviewed = revision.map { AnnotationReviewLedger.reviews(ledger, $0) } ?? false
        let review = revision.flatMap { revision in
            ledger.first {
                $0.contentHash == revision.contentHash && $0.changeKind == revision.changeKind && $0.annotationType == AnnotationReviewLedger.documentKind
            }
        }
        let kind = revision != nil && !reviewed ? revision?.changeKind : nil
        return DocumentChange(volumeId: key.volumeId, documentId: key.documentId,
                              line: DocumentChangeWords.bannerLine(kind: kind, highlightsStale: highlightsStale),
                              changeKind: kind, changedAt: revision?.changedAt,
                              reviewedAt: reviewed ? review?.reviewedAt.map(UserStoreDate.text) : nil,
                              contentHash: revision?.contentHash,
                              highlightsStale: highlightsStale, vanished: revision?.recordsRemoval ?? false,
                              canMarkReviewed: revision != nil && !reviewed, foundInTEI: change?.comparison != nil)
    }

    /// Whether one of `highlights` is stale against the text's version, by the kit's status rule.
    static func stale(_ highlights: [HighlightRecord], currentVersion: String?) -> Bool {
        highlights.contains {
            if case .stale = HighlightReview.status(renderingVersion: $0.renderingVersion, selectedText: $0.selectedText,
                                                    currentVersion: currentVersion) { return true }
            return false
        }
    }

    /// The version of the text a highlight is judged by: the page's as the reader renders it now, else the change's
    /// record of it, for a document whose TEI the server cannot render.
    static func currentVersion(of key: DocumentKey, reader: ReaderService, change: UpdateReviewSources.Change?) async -> String? {
        if change?.revision.recordsRemoval != true,
           let version = try? await reader.renderingVersion(volume: key.volumeId, document: key.documentId) {
            return version
        }
        guard let bodyHash = change?.revision.bodyHash, !bodyHash.isEmpty else { return nil }
        return bodyHash
    }

    static func sameVersion(_ given: String, _ current: String) throws {
        guard given == current else {
            throw APIProblem(.conflict, code: "DOCUMENT_CHANGED",
                             detail: "renderingVersion: the document's text has changed since the review was loaded, from \(given) to \(current). Load it again.")
        }
    }

    static func nothingToReview(_ key: DocumentKey) -> APIProblem {
        APIProblem(.conflict, code: "NOTHING_TO_REVIEW",
                   detail: "No change to \(key.volumeId)/\(key.documentId) waits for your review.")
    }

    private static func stored<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        do {
            return try await Blocking.run(work)
        } catch let error as HighlightStoreError {
            throw HighlightRoutes.problem(error)
        }
    }
}

// MARK: - Administration's Volume updates

/// `GET /api/v1/admin/library/updates`: what the updates changed, at the grain an admin acts, per volume, by the
/// kit's `VolumeUpdateReview` over the changes that wait for review and every user's research (PLAN's S21f), a
/// change waiting until the index holds its review stamp or everyone whose research is on the document has reviewed
/// it, the same rule in both modes; and in Import mode, where the comparison of the served export with the TEI
/// folder stands.
public struct AdminUpdates: Codable, Equatable, Sendable, ResponseEncodable {
    public var mode: String
    public var totals: Totals
    public var volumes: [Volume]
    /// Import mode's comparison with the TEI folder; absent on a Standalone server.
    public var teiCheck: TEICheck?

    public struct Totals: Codable, Equatable, Sendable {
        public var changedDocuments: Int
        public var volumes: Int
        public var annotatedDocuments: Int
    }

    public struct Volume: Codable, Equatable, Sendable {
        public var volumeId: String
        public var title: String
        public var changedDocuments: Int
        public var annotatedDocuments: Int
        public var body: Int
        public var apparatus: Int
        public var vanished: Int
    }

    public struct TEICheck: Codable, Equatable, Sendable {
        /// Whether a comparison is under way, a job of the queue: queued, running, or waiting behind the jobs it gave
        /// way to (`waiting`), over every volume or over those whose file changed since (`recheck`).
        public var running: Bool
        public var waiting: Bool
        public var recheck: Bool
        public var volume: String?
        public var done: Int
        public var total: Int
        public var checkedAt: String?
        public var checked: Int?
        public var changed: [String]?
        public var unchecked: [Unchecked]?
        public var problem: String?

        public struct Unchecked: Codable, Equatable, Sendable {
            public var volumeId: String
            public var reason: String
        }
    }
}

enum AdminUpdateRoutes {
    static func add(to admin: RouterGroup<APIRequestContext>, services: UserDataServices, state: ServerState,
                    resources: ServerResources, provider: ServedIndexProvider?, reviews: UpdateReviewSources) {
        let store = services.store
        admin.get("library/updates") { request, _ -> EditedResponse<AdminUpdates> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let served = try? await provider?.servedIfReady()
            // The changes that wait for review, by one rule in both modes: a change the index holds no review stamp of
            // (a Standalone server's own, recorded by this rule, or one an export brought from the Mac) and that the
            // ledgers do not settle, everyone whose research is on the document having reviewed it. An Import server's
            // index holds no stamp of the server's, and its comparison with the TEI none at all, so there the ledgers
            // are all of it; on a Standalone server they count a review before its job records it.
            let unstamped = await reviews.changes(served).values.map(\.revision).filter { $0.reviewedAt == nil }
            // Every user's research: a document counts if it carries anyone's, as the app counts its reader's.
            var annotators: [String: Set<String>] = [:]
            var open: [IndexingPipeline.DocumentRevision] = []
            if !unstamped.isEmpty {
                annotators = try await ReviewRoutes.annotators(store: store)
                let ledgers = try await Blocking.run { try store.everyDocumentReview() }
                let settled = ReviewRoutes.settledReviews(ledgers: ledgers, annotators: annotators)
                open = unstamped.filter { !AnnotationReviewLedger.reviews(settled, $0) }
            }
            let summaries = VolumeUpdateReview.summaries(revisions: open, annotatedKeys: Set(annotators.keys))
            let totals = VolumeUpdateReview.totals(of: summaries)
            var check: AdminUpdates.TEICheck?
            if state.configuration.mode == .import, let teiCheck = reviews.teiCheck {
                let status = await teiCheck.status()
                check = AdminUpdates.TEICheck(
                    running: status.running, waiting: status.waiting, recheck: status.recheck, volume: status.volume,
                    done: status.done, total: status.total,
                    checkedAt: status.record.map { UserStoreDate.text($0.checkedAt) }, checked: status.record?.checked.count,
                    changed: status.record?.changed,
                    unchecked: status.record.map { $0.unchecked.sorted { $0.key < $1.key }.map { .init(volumeId: $0.key, reason: $0.value) } },
                    problem: status.problem)
            }
            let body = AdminUpdates(
                mode: state.configuration.mode.rawValue,
                totals: .init(changedDocuments: totals.changedDocuments, volumes: totals.volumes, annotatedDocuments: totals.annotatedDocuments),
                volumes: summaries.map {
                    AdminUpdates.Volume(volumeId: $0.volumeId, title: resources.volume($0.volumeId)?.title ?? $0.volumeId,
                                        changedDocuments: $0.changedDocuments, annotatedDocuments: $0.annotatedDocuments,
                                        body: $0.body, apparatus: $0.apparatus, vanished: $0.vanished)
                },
                teiCheck: check)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: body)
        }
    }
}
