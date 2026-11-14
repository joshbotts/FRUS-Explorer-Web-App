// Send to Zotero Library (PLAN's S22e): a document, from Cite, as the app's Share menu and the Mac's Share
// popover send one, and a collection, from its export sheet, as the app's sheet sends one, each through the
// kit's `ZoteroAPIClient` with the user's own Zotero key, which the server keeps (`SecretVault`, PLAN's
// S20c) and hands to the client for the one request alone. The client resolves the key's account
// (`GET /keys/{key}`), then writes the items in batches of fifty and their notes; the items are the kit's
// exporter's: a document's `ZoteroJSONExporter.makeItem` over Cite's metadata with the user's tags and
// notes, a collection's those its resolve gives each document, as its RIS file takes them. A collection's
// send is kept in its history as the app keeps it, `zotero-api` with the items added.
//
// App code mirrored here, held to its source by `LookUpParityTests`: `ZoteroJSONExporter.fetchTagsAndNotes`
// (the names of the document's tags and its notes' tags, sorted, and its notes' bodies that are not empty),
// the document's send with no collection, and the collection's, its documents in their order, its name the
// kit's `zoteroCollectionName`, and its history row.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What a send added (`ZoteroSendResult`): the items and notes Zotero took, those it refused, and the address
/// of the collection or library on zotero.org, the app's View in Zotero.
public struct ZoteroSent: Codable, Equatable, Sendable, ResponseEncodable {
    public var addedItems: Int
    public var failedItems: Int
    public var addedNotes: Int
    public var webURL: String?
}

extension ZoteroSent {
    init(_ result: ZoteroSendResult) {
        self.init(addedItems: result.addedItems, failedItems: result.failedItems, addedNotes: result.addedNotes,
                  webURL: result.webURL?.absoluteString)
    }
}

enum ZoteroRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources,
                    reader: ReaderService, provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now
        let parses = CollectionDocumentParses(reader: reader, resources: resources)

        // Cite's: the document, with no collection, into the user's library.
        me.post("volumes/:volumeId/documents/:documentId/zotero") { request, context -> EditedResponse<ZoteroSent> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let key = try await zoteroKey(of: user, services: services)
            let cited = try await CitationRoutes.cite(context: context, reader: reader, provider: provider, resources: resources)
            let document = DocumentKey(volumeId: cited.volumeId, documentId: cited.documentId)
            let (tags, notes) = try await tagsAndNotes(of: document, for: user.id, in: store)
            let item = ZoteroJSONExporter.makeItem(document: cited.document, volume: cited.volume, year: cited.year,
                                                   url: cited.canonicalURL, isEditorialNote: cited.isEditorialNote,
                                                   tags: tags, notes: notes)
            let result = try await send([item], collectionName: nil, key: key, services: services)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: ZoteroSent(result))
        }

        // The export sheet's: the collection's documents, in their order, into a new Zotero collection of its name.
        me.post("collections/:collectionId/zotero") { request, context -> EditedResponse<ZoteroSent> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let collection = try await CollectionRoutes.collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            let key = try await zoteroKey(of: user, services: services)
            let research = try await Blocking.run { try CollectionResearch.read(for: user.id, in: store) }
            let served = try await provider.servedIfReady()
            try await CollectionExportRoutes.warm(collection, resources: resources)
            // As the RIS file's: the documents alone, with no summary phase (`resolvedZoteroDocuments()`).
            let documents = try await context.whileClientConnected {
                let refs = collection.savedSearchId == nil ? nil
                    : try await CollectionExportRoutes.smartRefs(of: collection, for: user.id, in: store, provider: provider)
                return try await CollectionExportRoutes.resolveDocuments(collection, smartRefs: refs, research: research, served: served,
                                                                         resources: resources, parses: parses)
            }
            let items = documents.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\.zoteroItem)
            guard !items.isEmpty else {
                throw APIProblem(.conflict, code: "NOTHING_TO_EXPORT", detail: "This collection has no documents to send.")
            }
            let result = try await send(items, collectionName: CollectionExportNaming.zoteroCollectionName(savedName: collection.name),
                                        key: key, services: services)
            // The app's only memory that the send happened: its history row, the items Zotero took.
            try await CollectionExportRoutes.recordKept(format: "zotero-api", documents: result.addedItems, of: collection,
                                                        for: user.id, in: store, at: now(), context: context)
            return EditedResponse(headers: [.cacheControl: "no-store"], response: ZoteroSent(result))
        }
    }

    /// The user's own Zotero key, the only one a send takes; `ZoteroAPIError.missingCredentials`, in the web's
    /// words, for none. Refused first under `FRUS_OFFLINE`.
    static func zoteroKey(of user: RequestUser, services: UserDataServices) async throws -> String {
        if services.outside.offline { throw OutsideServices.offlineProblem("Zotero") }
        let vault = services.secrets
        let key: String?
        do {
            key = try await Blocking.run { try vault.value(named: .zotero, for: .user(user.id)) }
        } catch is SecretError {
            throw APIProblem(.internalServerError, code: "KEY_UNREADABLE",
                             detail: "Your stored Zotero key cannot be opened with this server’s key file. Add it again in \(OutsideServices.keysPlace).")
        }
        guard let key else { throw problem(.missingCredentials) }
        return key
    }

    /// `ZoteroJSONExporter.fetchTagsAndNotes`: the names of the tags the document carries and of its notes' tags,
    /// each once, sorted; and its notes' bodies that are not empty.
    static func tagsAndNotes(of document: DocumentKey, for user: String,
                             in store: any UserDataStore) async throws -> (tags: [String], notes: [String]) {
        let (notes, assigned, tags) = try await Blocking.run {
            (try store.notes(of: document, for: user), try store.tags(of: document, for: user), try store.tags(of: user))
        }
        let names = Dictionary(tags.map { (UserSearchText.uuidString($0.id), $0.name) }, uniquingKeysWith: { first, _ in first })
        var tagNames = Set(assigned.map(\.name))
        for note in notes {
            for id in note.userTagIds { if let name = names[UserSearchText.uuidString(id)] { tagNames.insert(name) } }
        }
        return (tagNames.sorted(), notes.map(\.bodyText).filter { !$0.isEmpty })
    }

    /// The kit's send: the key's account, then the items, in a collection when one is named.
    static func send(_ items: [ZoteroJSONExporter.Item], collectionName: String?, key: String,
                     services: UserDataServices) async throws -> ZoteroSendResult {
        let client = ZoteroAPIClient(session: services.outside.zoteroSession)
        do {
            let account = try await client.resolveAccount(key: key)
            return try await client.send(items: items, collectionName: collectionName, apiKey: key,
                                         userID: account.userID, username: account.username)
        } catch let error as ZoteroAPIError {
            throw problem(error)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Nothing of the error is said or logged: the key is in the address a transport's error can name.
            throw problem(.network(""))
        }
    }

    /// A Zotero error, in the kit's sentence, which names the web's place for keys where the app's names its own;
    /// never the error's cause.
    static func problem(_ error: ZoteroAPIError) -> APIProblem {
        let detail = OutsideServices.webPlace(error.errorDescription ?? "")
        switch error {
        case .missingCredentials: return APIProblem(.conflict, code: "ZOTERO_KEY_REQUIRED", detail: detail)
        case .invalidKey: return APIProblem(.conflict, code: "ZOTERO_KEY_REJECTED", detail: detail)
        case .insufficientPermissions: return APIProblem(.conflict, code: "ZOTERO_KEY_CANNOT_WRITE", detail: detail)
        case .rateLimited: return APIProblem(.serviceUnavailable, code: "ZOTERO_RATE_LIMITED", detail: detail)
        case .network: return APIProblem(.badGateway, code: "ZOTERO_UNREACHABLE", detail: detail)
        case .http, .decoding: return APIProblem(.badGateway, code: "ZOTERO_UNEXPECTED_ANSWER", detail: detail)
        }
    }
}
