// /api/v1/me/working-corpora (PLAN's S17e): the user's working corpora, each a fixed set of documents
// captured from the rows a search shows, as the Mac's Save as Working Corpus captures one
// (`SaveWorkingCorpusSheet` over `ResultSetScope`'s capture, app code mirrored in `CorpusCapture`);
// listed and opened as Browse's Working Corpora axis lists and opens them (`CorporaIndexView`,
// `CorpusDocumentsView`, with `CorporaAxis`' grouping and order, app code mirrored), each with what the
// served index reaches of it, by the kit's resolver (`WorkingCorpusResolver`), and its capture's
// truncation in the kit's words (`CorpusCaptureTruncation`); renamed and deleted. A search runs inside
// one (`SearchUsers.inside`). A row is written as the import writes a Mac's (`MacImport.corpus`) and
// read as the export reads one (`ResearchExport.corpus`).

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// One of the user's working corpora.
public struct WorkingCorpus: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    /// May be empty, as an import can leave one: a list names it Untitled Corpus.
    public var name: String
    /// How many documents it names (`WorkingCorpus.documentCount`).
    public var documentCount: Int
    public var capturedAt: String?
    /// The words it was captured from, and where it came from, as the capture recorded them.
    public var sourceQuery: String?
    /// Those words as a list quotes them, the kit's `QueryQuoting.quotable`: a query that is one
    /// phrase once, without its own marks, as `CorporaAxis.rowCaption` prints it.
    public var quotableSourceQuery: String?
    public var sourceDescription: String?
    public var indexedVolumeCountAtCapture: Int?
    public var wasTruncatedAtCapture: Bool?
    public var totalMatchCountAtCapture: Int?
    public var createdAt: String?
    public var lastModified: String?
    /// Whether its provenance says it is a Meaning search's closest matches
    /// (`WorkingCorpusProvenance.isMeaningCapture`).
    public var isMeaningCapture: Bool
    /// The kit's line for what is known of its capture's completeness
    /// (`CorpusCaptureTruncation.line(documentCount:isMeaningCapture:locale:)`), in US English; absent
    /// for a capture that was every match.
    public var truncationLine: String?
    /// Whether that line warns, as the Mac draws it in amber (`CorporaAxis.drawsTruncationLineInAmber`):
    /// a capture cut short of what its query matched, and not a Meaning search's.
    public var truncationWarns: Bool
    /// What the served index reaches of it; absent while no index is served.
    public var coverage: CorpusCoverage?

    init(_ corpus: WorkingCorpusExport, served: ServedIndex?) {
        id = corpus.id.uuidString
        name = corpus.name
        documentCount = corpus.documentKeys.count
        capturedAt = corpus.capturedAt.map(UserStoreDate.text)
        sourceQuery = corpus.sourceQuery
        quotableSourceQuery = corpus.sourceQuery.map(QueryQuoting.quotable)
        sourceDescription = corpus.sourceDescription
        indexedVolumeCountAtCapture = corpus.indexedVolumeCountAtCapture
        wasTruncatedAtCapture = corpus.wasTruncatedAtCapture
        totalMatchCountAtCapture = corpus.totalMatchCountAtCapture
        createdAt = corpus.createdAt.map(UserStoreDate.text)
        lastModified = corpus.lastModified.map(UserStoreDate.text)
        isMeaningCapture = WorkingCorpusProvenance.isMeaningCapture(corpus.sourceDescription)
        let truncation = CorpusCaptureTruncation(wasTruncated: corpus.wasTruncatedAtCapture,
                                                 totalMatchCount: corpus.totalMatchCountAtCapture)
        truncationLine = truncation.line(documentCount: corpus.documentKeys.count, isMeaningCapture: isMeaningCapture,
                                         locale: SearchItem.locale)
        if case .truncated = truncation { truncationWarns = !isMeaningCapture } else { truncationWarns = false }
        coverage = served.map {
            CorpusCoverage(WorkingCorpusResolver(indexedVolumeIds: $0.indexedVolumeIds).resolve(documentKeys: corpus.documentKeys))
        }
    }
}

/// What the served index reaches of a working corpus, the kit's `WorkingCorpusResolution`: the
/// documents of its volumes the index holds, of all it names, which a list says as "142 of 267
/// documents indexed on this server".
public struct CorpusCoverage: Codable, Equatable, Sendable {
    public var indexedCount: Int
    public var totalCount: Int
    /// The volumes it names that the index holds no documents of, by id.
    public var missingVolumeIds: [String]
    public var isComplete: Bool

    init(_ resolution: WorkingCorpusResolution) {
        indexedCount = resolution.indexedCount
        totalCount = resolution.totalCount
        missingVolumeIds = resolution.missingVolumeIds
        isComplete = resolution.isComplete
    }
}

/// The user's working corpora, the most recently captured first, as Browse lists them.
public struct WorkingCorpusList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [WorkingCorpus]
}

/// A working corpus opened, as Browse's drill shows it (`CorpusDocumentsView`): its documents in one
/// section a volume, the volumes by id, and each section's documents by date.
public struct WorkingCorpusDetail: Codable, Equatable, Sendable, ResponseEncodable {
    public struct Section: Codable, Equatable, Sendable {
        public var volumeId: String
        /// The volume's title in the catalogue, absent for a volume outside it.
        public var title: String?
        /// Whether the served index holds the volume's documents, which then open in the reader.
        public var indexed: Bool
        public var documents: [Document]
    }

    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// What a list calls it, from the index; absent for a document of a volume it does not hold.
        public var displayTitle: String?
        /// The day the index dates it by, `yyyy-MM-dd`, or absent.
        public var dateISO: String?
    }

    public var corpus: WorkingCorpus
    public var sections: [Section]
    public var coverage: Coverage
}

/// What a capture of a search's rows would save, as the Save Working Corpus sheet shows it before
/// Save: the documents, the words, what narrowed them, the volumes indexed now, and its warnings.
public struct CorpusCapturePreview: Codable, Equatable, Sendable, ResponseEncodable {
    public var documentCount: Int
    public var sourceQuery: String?
    /// What narrowed the search beyond its words, as phrases (`ResultSetScope.narrowing`).
    public var narrowing: [String]
    public var indexedVolumeCount: Int
    /// Why the set may not be the whole answer (`ResultSetScope.captureTruncationWarning`).
    public var truncationWarning: String?
    /// What Checklist Mode keeps out of it (`ResultSetScope.captureChecklistWarning`).
    public var checklistWarning: String?
    /// The sentence the corpus records of where it came from (`ResultSetScope.captureProvenanceDescription`).
    public var sourceDescription: String
    public var wasTruncated: Bool
    public var totalMatchCount: Int
}

/// A capture of the rows a search shows, as the Mac's Save as Working Corpus makes one: the whole
/// retained set of a keyword search, never the page, less the results Checklist Mode hides, with what
/// `ResultSetScope` says of it, app code mirrored here for the keyword route, the only one the web runs
/// (`CaptureParityTests` holds the words to the app's source).
struct CorpusCapture {
    /// The documents, `volumeId/documentId`, each once, in order, as `WorkingCorpus.init` keeps them.
    let keys: [String]
    /// `ResultSetScope.loaded`: the results the search kept.
    let loaded: Int
    /// `ResultSetScope.shown`: those Checklist Mode leaves.
    let shown: Int
    /// The search's exact count.
    let total: Int
    let sourceQuery: String?
    let narrowing: [String]
    /// Whether the search ran inside a corpus whose own capture was cut short.
    let insideTruncatedCorpus: Bool

    /// The Mac's search window's ceiling, `MacSearchViewModel.searchHardLimit`, under which it fetched.
    static let fetchLimit = SearchRequest.retainedLimit

    init(results: [SearchResult], total: Int, reviewed: Set<String>, sourceQuery: String?, narrowing: [String],
         insideTruncatedCorpus: Bool) {
        let shown = results.filter { !reviewed.contains("\($0.volumeId)/\($0.documentId)") }
        keys = Array(Set(shown.map { "\($0.volumeId)/\($0.documentId)" })).sorted()
        loaded = results.count
        self.shown = shown.count
        self.total = total
        self.sourceQuery = sourceQuery
        self.narrowing = narrowing
        self.insideTruncatedCorpus = insideTruncatedCorpus
    }

    /// `didHitFetchLimit`, the keyword route's: the fetch reached its ceiling, or the count exceeds it.
    var didHitFetchLimit: Bool { loaded >= Self.fetchLimit || total > loaded }

    /// `isCapturePartial`, which the corpus records: this fetch stopped short, or the corpus it ran
    /// inside was itself a capture cut short.
    var isCapturePartial: Bool { didHitFetchLimit || insideTruncatedCorpus }

    /// `hiddenByChecklist`.
    var hiddenByChecklist: Int { max(0, loaded - shown) }

    /// `captureTruncationWarning`, the keyword route's.
    var truncationWarning: String? {
        guard didHitFetchLimit else { return nil }
        return "These \(Self.grouped(loaded)) documents are the highest-scoring of \(Self.grouped(total)) matching documents. Counts taken inside this corpus are counts inside that subset."
    }

    /// `captureChecklistWarning`.
    var checklistWarning: String? {
        guard hiddenByChecklist > 0 else { return nil }
        return hiddenByChecklist == 1
            ? "Checklist mode is hiding 1 reviewed document. It will not be in this corpus."
            : "Checklist mode is hiding \(Self.grouped(hiddenByChecklist)) reviewed documents. They will not be in this corpus."
    }

    /// `captureProvenanceDescription`, the keyword route's.
    var provenance: String {
        var description = "Search results"
        if !narrowing.isEmpty { description = "\(description) (\(narrowing.joined(separator: "; ")))" }
        if didHitFetchLimit { description += " — the highest-scoring \(Self.grouped(loaded)) of \(Self.grouped(total)) matches" }
        if hiddenByChecklist > 0 {
            description += hiddenByChecklist == 1
                ? "; 1 reviewed document excluded" : "; \(Self.grouped(hiddenByChecklist)) reviewed documents excluded"
        }
        return description
    }

    var preview: CorpusCapturePreview {
        CorpusCapturePreview(documentCount: keys.count, sourceQuery: sourceQuery, narrowing: narrowing,
                             indexedVolumeCount: 0, truncationWarning: truncationWarning, checklistWarning: checklistWarning,
                             sourceDescription: provenance, wasTruncated: isCapturePartial, totalMatchCount: total)
    }

    /// `ResultSetScope.narrowing(ofRowsSignedBy:)`: what narrowed a list beyond its words, from the
    /// scope signature of the filters its rows were found under (`SearchScopeSignature.signature(for:)`),
    /// in the method appendix's words (`SearchScopeSignature.describe`), the fields searched said only
    /// when they are not every field, and a set of volumes or of documents in the capture's own words.
    static func narrowing(ofRowsSignedBy signature: String, resources: IndexingResources) -> [String] {
        var parts: [String: String] = [:]
        for part in signature.split(separator: ";") {
            guard let split = part.firstIndex(of: "=") else { return [] }
            parts[String(part[..<split])] = String(part[part.index(after: split)...])
        }
        func counted(_ key: String) -> Int? {
            guard let component = parts[key], let slash = component.firstIndex(of: "/") else { return nil }
            return Int(component[..<slash])
        }
        let volumes = counted("vols")
        let documents = counted("docs")
        let others = signature.split(separator: ";").map { part -> String in
            if part.hasPrefix("vols="), volumes != nil { return "vols=none" }
            if part.hasPrefix("docs="), documents != nil { return "docs=none" }
            return String(part)
        }.joined(separator: ";")
        guard var phrases = SearchScopeSignature.describe(others, resources: resources, locale: SearchItem.locale),
              !phrases.isEmpty else { return [] }
        if ["text", "summ", "notes", "front"].allSatisfy({ parts[$0] == "1" }) {
            phrases.removeFirst()
        }
        if let volumes {
            phrases.append(volumes == 1 ? "within 1 volume" : "within \(grouped(volumes)) volumes")
        }
        if let documents {
            phrases.append(documents == 1 ? "within a set of 1 document" : "within a set of \(grouped(documents)) documents")
        }
        return phrases
    }

    /// A count grouped as the browser app's words group one.
    static func grouped(_ count: Int) -> String { count.formatted(.number.locale(SearchItem.locale)) }
}

enum WorkingCorpusRoutes {
    struct Capture: Decodable {
        /// The search, as the query string `GET /api/v1/search` reads.
        let search: String
        /// The results Checklist Mode hides, which the capture leaves out.
        let reviewed: [String]?
    }

    struct Save: Decodable {
        let name: String
        let search: String
        let reviewed: [String]?
    }

    struct Rename: Decodable { let name: String }

    /// The largest body a capture may carry: room for every result a search keeps, as `reviewed`.
    static let bodyLimit = 1_024 * 1_024

    static func add(to me: RouterGroup<APIRequestContext>, captures: RouterGroup<APIRequestContext>, services: UserDataServices,
                    provider: ServedIndexProvider, resources: ServerResources) {
        let store = services.store
        let now = services.now

        me.get("working-corpora") { request, context -> WorkingCorpusList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let served = try await provider.servedIfReady()
            let corpora = try await corpora(of: user.id, in: store)
            return WorkingCorpusList(total: corpora.count, items: corpora.map { WorkingCorpus($0, served: served) })
        }
        me.get("working-corpora/:corpusId") { request, context -> WorkingCorpusDetail in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let corpus = try await corpus(try context.parameters.require("corpusId"), of: user.id, in: store)
            let served = try await provider.served()
            return try await detail(corpus, served: served, resources: resources)
        }
        me.patch("working-corpora/:corpusId") { request, context -> WorkingCorpus in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("corpusId")
            let body = try await JSONBody.decode(Rename.self, from: request, fields: ["name"])
            let name = try savedName(body.name)
            var corpus = try await corpus(id, of: user.id, in: store)
            // `WorkingCorpus.rename(to:)`: the name, and the time it changed.
            corpus.name = name
            corpus.lastModified = UserStoreDate.rounded(now())
            let values = MacImport.corpus(corpus).values.filter { ["name", "last_modified"].contains($0.key) }
            guard let row = try await Blocking.run({ try store.updateSearchSet(.workingCorpora, id: id, values, for: user.id) }) else {
                throw notFound(id)
            }
            return WorkingCorpus(try read(row), served: try await provider.servedIfReady())
        }
        me.delete("working-corpora/:corpusId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("corpusId")
            guard try await Blocking.run({ try store.deleteSearchSet(.workingCorpora, id: id, for: user.id) }) else { throw notFound(id) }
            return Response(status: .noContent)
        }

        // What Save would capture, for the sheet, and the capture saved: both carry the results
        // Checklist Mode hides, so their group takes a larger body.
        captures.post("working-corpora/capture") { request, context -> CorpusCapturePreview in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Capture.self, from: request, fields: ["search", "reviewed"], limit: bodyLimit)
            let (capture, served) = try await capture(body.search, reviewed: body.reviewed, for: user, services: services,
                                                      provider: provider, resources: resources, context: context)
            var preview = capture.preview
            preview.indexedVolumeCount = served.indexedVolumeIds.count
            return preview
        }
        captures.post("working-corpora") { request, context -> EditedResponse<WorkingCorpus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Save.self, from: request, fields: ["name", "search", "reviewed"], limit: bodyLimit)
            let name = try savedName(body.name)
            let (capture, served) = try await capture(body.search, reviewed: body.reviewed, for: user, services: services,
                                                      provider: provider, resources: resources, context: context)
            guard !capture.keys.isEmpty else {
                throw APIProblem(.badRequest, code: "NOTHING_TO_CAPTURE",
                                 detail: "The search shows no documents to save as a working corpus.")
            }
            // `WorkingCorpus.init`, as the sheet's Save makes it.
            let time = UserStoreDate.rounded(now())
            let corpus = WorkingCorpusExport(
                id: UUID(), name: name, documentKeys: capture.keys, capturedAt: time, sourceQuery: capture.sourceQuery,
                sourceDescription: capture.provenance, indexedVolumeCountAtCapture: served.indexedVolumeIds.count,
                wasTruncatedAtCapture: capture.isCapturePartial, totalMatchCountAtCapture: capture.total,
                createdAt: time, lastModified: time)
            try await Blocking.run { try store.addSearchSet(.workingCorpora, MacImport.corpus(corpus).values, for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/working-corpora/\(corpus.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location], response: WorkingCorpus(corpus, served: served))
        }
    }

    /// The name a corpus is saved or renamed with: the sheet's, without the spaces and new lines
    /// around it, and never empty.
    static func savedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "name: a working corpus's name, trimmed of spaces and new lines, cannot be empty.")
        }
        return trimmed
    }

    /// The capture of the search `query` says, for `user`, less `reviewed`: the search's results kept,
    /// run as the user's search, inside the corpus it names, with its count and what narrowed it.
    static func capture(_ query: String, reviewed: [String]?, for user: RequestUser, services: UserDataServices,
                        provider: ServedIndexProvider, resources: ServerResources,
                        context: APIRequestContext) async throws -> (CorpusCapture, ServedIndex) {
        var search = try SearchRequest(formEncoded: query)
        let hidden = try SearchRequest.reviewed(reviewed ?? [])
        let searcher = try await SearchUsers.user(user.id, searching: search.parameters, in: services.store)
        let served = try await provider.served()
        var truncatedCorpus = false
        if let corpusId = search.workingCorpusId {
            let corpus = try await corpus(corpusId, of: user.id, in: services.store)
            if case .truncated = CorpusCaptureTruncation(wasTruncated: corpus.wasTruncatedAtCapture,
                                                          totalMatchCount: corpus.totalMatchCountAtCapture) {
                truncatedCorpus = true
            }
        }
        let insideTruncated = truncatedCorpus
        search.parameters = try await SearchUsers.inside(search.workingCorpusId, search.parameters, for: user.id,
                                                         in: services.store, served: served)
        let scoped = try served.search(for: searcher)
        let parameters = search.parameters
        let words = (parameters.keywords ?? "").trimmingCharacters(in: .whitespaces)
        let narrowing = CorpusCapture.narrowing(ofRowsSignedBy: SearchScopeSignature.signature(for: parameters),
                                                resources: resources.indexing)
        do {
            let capture = try await context.whileClientConnected {
                async let results = served.retained.results(of: parameters, in: scoped)
                let total = try await served.recent.count(of: parameters, in: scoped)
                return CorpusCapture(results: try await results, total: total, reviewed: hidden,
                                     sourceQuery: words.isEmpty ? nil : words, narrowing: narrowing,
                                     insideTruncatedCorpus: insideTruncated)
            }
            return (capture, served)
        } catch let error as FTS5Error {
            throw SearchRoutes.refusal(error)
        }
    }

    /// The user's corpora, the most recently captured first, as `CorporaIndexView` sorts them, one
    /// never captured last; a tie in the store's order.
    static func corpora(of user: String, in store: any UserDataStore) async throws -> [WorkingCorpusExport] {
        let rows = try await Blocking.run { try store.searchSets(.workingCorpora, of: user) }
        let corpora = try rows.map(read)
        return corpora.enumerated().sorted { a, b in
            let (x, y) = (a.element.capturedAt ?? .distantPast, b.element.capturedAt ?? .distantPast)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    /// The user's corpus `id`, or `CORPUS_NOT_FOUND`.
    static func corpus(_ id: String, of user: String, in store: any UserDataStore) async throws -> WorkingCorpusExport {
        guard let row = try await Blocking.run({ try store.searchSet(.workingCorpora, id: id, of: user) }) else { throw notFound(id) }
        return try read(row)
    }

    static func read(_ row: ExportRow) throws -> WorkingCorpusExport {
        do {
            return try ResearchExport.corpus(ResearchExport.Fields("working_corpora", row))
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The working corpus could not be read: \(error.description)")
        }
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "CORPUS_NOT_FOUND", detail: "You have no working corpus with the id \(id).")
    }

    /// The drill: `CorporaAxis.volumeSections(from:)`, a section a volume by id and a key that is no
    /// `volumeId/documentId` passed over, each section's documents by `CorporaAxis.ordered`, the day the
    /// index dates each by, then its volume's first day of coverage, then none last, a tie by id.
    static func detail(_ corpus: WorkingCorpusExport, served: ServedIndex,
                       resources: ServerResources) async throws -> WorkingCorpusDetail {
        var byVolume: [String: [String]] = [:]
        for key in corpus.documentKeys {
            let parts = key.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { continue }
            byVolume[String(parts[0]), default: []].append(String(parts[1]))
        }
        var sections: [WorkingCorpusDetail.Section] = []
        for volumeId in byVolume.keys.sorted() {
            let documentIds = byVolume[volumeId] ?? []
            let entry = resources.volume(volumeId)
            let indexed = served.indexedVolumeIds.contains(volumeId)
            var titles: [String: String] = [:]
            var dates: [String: String] = [:]
            if indexed {
                let wanted = Set(documentIds)
                for document in try await served.pipeline.documents(forVolume: volumeId) where wanted.contains(document.documentId) {
                    titles[document.documentId] = DocumentEntry(document, inIndex: true, dateISO: nil).displayTitle
                }
                dates = try await served.pipeline.datesByDocumentKey(documentIds.map { (volumeId: volumeId, documentId: $0) })
            }
            let earliest = entry?.dateRange.earliest
            func sortKey(_ id: String) -> String { dates["\(volumeId)/\(id)"] ?? earliest ?? "9999" }
            let ordered = documentIds.sorted { a, b in
                let (x, y) = (sortKey(a), sortKey(b))
                return x != y ? x < y : a < b
            }
            sections.append(.init(volumeId: volumeId, title: entry?.title, indexed: indexed, documents: ordered.map {
                .init(volumeId: volumeId, documentId: $0, displayTitle: titles[$0], dateISO: dates["\(volumeId)/\($0)"])
            }))
        }
        return WorkingCorpusDetail(corpus: WorkingCorpus(corpus, served: served), sections: sections,
                                   coverage: Coverage(index: served.corpus, resources: resources))
    }
}
