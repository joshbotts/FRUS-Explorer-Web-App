// /api/v1/me/add-documents (PLAN's S25d): Add Documents' Citations and Tags tabs, as the app's
// `CollectionAddDocumentsSheet` fills them, beside the Search and Browse it already has (S18d). A paste
// is resolved line by line by the kit's `CollectionCitationLineResolver`, over the matcher Citation
// Lookup asks and bounded as its Batch is; a tag's documents are the kit's union of the user's notes
// and tag assignments (`CollectionGeneratedBlocks.tagDocumentRefs`), which the Thematic Index reads
// too. Nothing here reads a citation, ranks a match or gathers a tag: the kit does each, public since
// FRUS-Explorer#1814. Neither route changes anything: a document chosen is added by S18d's
// `POST /me/collections/{id}/documents`.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// Each line of a paste, as the kit's resolver buckets it, in the paste's order: every line has a row,
/// as the app's sheet lists one for each.
public struct AddDocumentsCitations: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [Line]

    public struct Line: Codable, Equatable, Sendable {
        /// The line as the resolver read it, trimmed (`CollectionCitationLineResolver.lines(from:)`).
        public var line: String
        /// `resolved`, `ambiguous` or `unresolved` (`CollectionCitationLineResolver.Outcome`).
        public var outcome: String
        /// The document a resolved or an ambiguous line names, always in a volume the published catalogue
        /// lists: for a link to a numbered document (`d12`) in a catalogued volume the served index does not
        /// hold, the document the link names, by its id, as the app adds one from a volume it has not
        /// downloaded.
        public var volumeId: String?
        public var documentId: String?
        /// A resolved line's correction note, absent for none, or an ambiguous line's rank note, which it
        /// always has.
        public var note: String?
        /// Why an unresolved line names no document, which it always has.
        public var reason: String?
        /// The document's head as the served index holds it, as the app's sheet reads it from its own
        /// index (`documentHeaders(for:)`): absent while none is served, for a document it does not hold
        /// and for an empty one.
        public var header: String?
        /// The volume's title in the published catalogue.
        public var volumeTitle: String?
    }
}

/// The user's tags, in `GET /me/tags`' order, each with how many documents the kit's union gathers for it:
/// the Tags tab's list, as the app's sheet counts each row (`tagRefCount(_:)`).
public struct AddDocumentsTags: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [Tag]

    public struct Tag: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var count: Int
    }
}

/// One tag's documents, the kit's union in its order, each with its head and its volume's title: the Tags
/// tab's drill-in, which the app's sheet gathers and chooses at once (`openTag(_:)`).
public struct AddDocumentsTag: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String
    public var total: Int
    public var items: [Document]

    public struct Document: Codable, Equatable, Sendable {
        public var volumeId: String
        public var documentId: String
        /// As a citation's line's: the served index's head, absent for none.
        public var header: String?
        /// The volume's title in the published catalogue, absent for a volume it does not list.
        public var volumeTitle: String?
        /// Whether the published catalogue lists the volume, without which a collection here takes no
        /// document (`POST …/documents` answers `VOLUME_NOT_FOUND`): false for a volume only a Mac's export
        /// can name, one side-loaded there, which the app's sheet adds and the web's offers to no one.
        public var catalogued: Bool
    }
}

/// What the kit's tag union reads of one user's store, as the app's sheet hands it its notes and its
/// assignments (`CollectionDocumentDiscovery.tagDocumentRefs`): each note's document and tags, newest
/// first, as the app's editor queries its notes, and each assignment in the order the store took them.
/// The ids are the store's text and the kit's `UUID`s; one that does not parse names no tag, and a note
/// with no document, a project's, gives no document to add, so it is passed over, as
/// `ProjectEngagedDocuments` passes it over.
struct TagUnion: Sendable {
    typealias NoteTags = (volumeId: String, documentId: String, tagIds: [UUID])
    typealias Assignment = (volumeId: String, documentId: String, tagId: UUID)

    let noteTags: [NoteTags]
    let assignments: [Assignment]
    /// Each tag's own notes and assignments, in their order: the kit passes over an entry that does not
    /// carry the tag it is asked for, so handing it a tag's own gives the answer the whole lists give, and
    /// the list's counts take one pass over the store's rows rather than one for each tag.
    private let byTag: [UUID: (notes: [NoteTags], assignments: [Assignment])]

    init(notes: [NoteRecord], assignments: [TagAssignmentRecord]) {
        noteTags = notes.filter { !$0.volumeId.isEmpty && !$0.documentId.isEmpty }.map {
            (volumeId: $0.volumeId, documentId: $0.documentId, tagIds: $0.userTagIds.compactMap(UUID.init(uuidString:)))
        }
        self.assignments = assignments.compactMap { assignment in
            UUID(uuidString: assignment.tagId).map {
                (volumeId: assignment.volumeId, documentId: assignment.documentId, tagId: $0)
            }
        }
        var byTag: [UUID: (notes: [NoteTags], assignments: [Assignment])] = [:]
        for note in noteTags {
            for tag in Set(note.tagIds) { byTag[tag, default: ([], [])].notes.append(note) }
        }
        for assignment in self.assignments { byTag[assignment.tagId, default: ([], [])].assignments.append(assignment) }
        self.byTag = byTag
    }

    /// The user's, read from the store at one go each.
    static func read(for user: String, in store: any UserDataStore) throws -> TagUnion {
        TagUnion(notes: try store.notes(for: user), assignments: try store.tagAssignments(of: user))
    }

    /// The documents carrying the tag `id` names, the kit's union, which answers `(documentId, volumeId)`.
    func documents(of id: String) -> [(documentId: String, volumeId: String)] {
        guard let tag = UUID(uuidString: id), let own = byTag[tag] else { return [] }
        return CollectionGeneratedBlocks.tagDocumentRefs(tagId: tag, noteTags: own.notes, assignments: own.assignments)
    }
}

enum AddDocumentsRoutes {
    /// A paste, as the Citations tab sends its text.
    struct Paste: Decodable { let text: String }

    /// A paste's lines, as the kit buckets them, with what the served index holds of their documents.
    struct Resolution: Sendable {
        let lines: [CollectionCitationLineResolver.LineResult]
        let facts: [String: DocumentDisplayTitle.Facts]
    }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    provider: ServedIndexProvider) {
        let store = services.store
        let matcher = CitationLookupRoutes.matcher(provider: provider, resources: resources)

        // Resolve: each line of the paste, bounded as Batch is, by its count of lines and its size, and the
        // heads of the documents they name, all stopped when the client goes.
        me.post("add-documents/citations") { request, context -> AddDocumentsCitations in
            try FormQuery(request.uri.query).refuseUnknown([])
            _ = try context.requireUser()
            let body = try await JSONBody.decode(Paste.self, from: request, fields: ["text"], limit: CitationLookupRoutes.bodyLimit)
            let lines = CollectionCitationLineResolver.lines(from: body.text)
            guard lines.count <= CitationLookupRoutes.batchLimit else {
                throw APIProblem(.badRequest, code: "TOO_MANY_CITATIONS",
                                 detail: "Add Documents resolves at most \(CitationLookupRoutes.batchLimit) lines at a time, and this text holds \(lines.count). Paste it in parts.")
            }
            let engine = try await matcher()
            let resolution = try await context.whileClientConnected {
                let results = try await resolve(lines, engine: engine)
                try Task.checkCancellation()
                return Resolution(lines: results, facts: await heads(of: results.compactMap { document(of: $0.outcome) }, provider: provider))
            }
            return AddDocumentsCitations(total: resolution.lines.count, items: resolution.lines.map { result in
                var line = AddDocumentsCitations.Line(line: result.line, outcome: "unresolved")
                switch result.outcome {
                case .resolved(let volumeId, let documentId, let note):
                    line.outcome = "resolved"
                    line.note = note
                    (line.volumeId, line.documentId) = (volumeId, documentId)
                case .ambiguous(let volumeId, let documentId, let note):
                    line.outcome = "ambiguous"
                    line.note = note
                    (line.volumeId, line.documentId) = (volumeId, documentId)
                case .unresolved(let reason):
                    line.reason = reason
                }
                if let volumeId = line.volumeId, let documentId = line.documentId {
                    line.header = resolution.facts["\(volumeId)/\(documentId)"]?.header
                    line.volumeTitle = resources.volume(volumeId)?.title
                }
                return line
            })
        }
        // The tag list, each tag with its union's count, over all of the user's notes and assignments, as
        // the app's sheet takes them, whatever project they are filed under.
        me.get("add-documents/tags") { request, context -> AddDocumentsTags in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            return try await Blocking.run {
                let (tags, union) = (try store.tags(of: user.id), try TagUnion.read(for: user.id, in: store))
                return AddDocumentsTags(total: tags.count, items: tags.map {
                    AddDocumentsTags.Tag(id: $0.id, name: $0.name, count: union.documents(of: $0.id).count)
                })
            }
        }
        // A tag's documents, the union in its order.
        me.get("add-documents/tags/:tagId") { request, context -> AddDocumentsTag in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("tagId")
            let (tag, refs) = try await Blocking.run {
                let tag = try store.tag(id, of: user.id)
                return (tag, try tag.map { try TagUnion.read(for: user.id, in: store).documents(of: $0.id) } ?? [])
            }
            guard let tag else { throw TagRoutes.problem(TagStoreError.tagNotFound(id)) }
            let facts = await heads(of: refs.map { DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) }, provider: provider)
            return AddDocumentsTag(id: tag.id, name: tag.name, total: refs.count, items: refs.map { ref in
                let volume = resources.volume(ref.volumeId)
                return AddDocumentsTag.Document(volumeId: ref.volumeId, documentId: ref.documentId,
                                                header: facts["\(ref.volumeId)/\(ref.documentId)"]?.header,
                                                volumeTitle: volume?.title, catalogued: volume != nil)
            })
        }
    }

    /// Each line resolved in turn by the kit's resolver over `engine`, with the kit's parser, as the app's
    /// sheet resolves a paste (`resolveCitations()`). The resolver turns a lookup that throws into an
    /// unresolved line and goes on, a stopped one among them, so the task is asked between lines whether
    /// it is stopped: a paste whose client has gone stops at the next line.
    static func resolve(_ lines: [String], engine: CitationMatchingEngine) async throws -> [CollectionCitationLineResolver.LineResult] {
        let parser = CitationLookupRoutes.parser
        let resolver = CollectionCitationLineResolver(parse: { parser.parse($0) }, match: { try await engine.match(input: $0) })
        var results: [CollectionCitationLineResolver.LineResult] = []
        for line in lines {
            try Task.checkCancellation()
            results.append(CollectionCitationLineResolver.LineResult(line: line, outcome: await resolver.resolve(line: line)))
        }
        return results
    }

    /// The document a resolved or an ambiguous line names.
    static func document(of outcome: CollectionCitationLineResolver.Outcome) -> DocumentKey? {
        switch outcome {
        case .resolved(let volumeId, let documentId, _), .ambiguous(let volumeId, let documentId, _):
            DocumentKey(volumeId: volumeId, documentId: documentId)
        case .unresolved:
            nil
        }
    }

    /// What the served index holds of each document, for its head, as the app's sheet reads its heads
    /// (`CrossReferenceStore.documentHeaders(for:)`): the Research page's read of a row's title facts, the
    /// documents' rows alone, a volume's ids at a time; nothing while no index is served.
    static func heads(of documents: [DocumentKey], provider: ServedIndexProvider) async -> [String: DocumentDisplayTitle.Facts] {
        await ResearchRoutes.titleFacts(documents.map { (volumeId: $0.volumeId, documentId: $0.documentId) }, provider: provider)
    }
}
