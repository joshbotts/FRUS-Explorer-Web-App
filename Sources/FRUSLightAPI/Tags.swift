// /api/v1/me/tags and a document's tags (PLAN's S14c): the user's tags, made, renamed, deleted and
// merged as the app's Settings ▸ Tags does them, and the tags of one document, set as the tag
// picker's Done sets them and taken off one at a time as the Research rail's × takes them, each by
// the store's rules (`TagStore`), which are the app's.

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One of the user's tags.
public struct UserTag: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    public var name: String
    /// When it was made and last renamed, as the store keeps dates.
    public var createdAt: String?
    public var lastModified: String?

    init(_ record: UserTagRecord) {
        id = record.id
        name = record.name
        createdAt = record.createdAt.map(UserStoreDate.text)
        lastModified = record.lastModified.map(UserStoreDate.text)
    }
}

/// The user's tags, by name.
public struct TagList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [UserTag]
}

/// The tags one document carries, in the tag list's order.
public struct DocumentTags: Codable, Equatable, Sendable, ResponseEncodable {
    public var volumeId: String
    public var documentId: String
    public var items: [UserTag]
}

enum TagRoutes {
    struct Named: Decodable { let name: String }
    struct Merge: Decodable { let into: String }
    struct TagSet: Decodable { let tagIds: [String] }

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, resources: ServerResources) {
        let store = services.store
        let now = services.now

        me.get("tags") { request, context -> TagList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let tags = try await Blocking.run { try store.tags(of: user.id) }
            return TagList(total: tags.count, items: tags.map(UserTag.init))
        }
        me.post("tags") { request, context -> EditedResponse<UserTag> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Named.self, from: request, fields: ["name"])
            let tag = try await stored { try store.createTag(named: body.name, for: user.id, at: now()) }
            let location = context.basePath.prefixing("/api/v1/me/tags/\(tag.id)")
            return EditedResponse(status: .created, headers: [.location: location], response: UserTag(tag))
        }
        me.get("tags/:tagId") { request, context -> UserTag in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("tagId")
            guard let tag = try await Blocking.run({ try store.tag(id, of: user.id) }) else {
                throw problem(TagStoreError.tagNotFound(id))
            }
            return UserTag(tag)
        }
        me.patch("tags/:tagId") { request, context -> UserTag in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("tagId")
            let body = try await JSONBody.decode(Named.self, from: request, fields: ["name"])
            return UserTag(try await stored { try store.renameTag(id, to: body.name, for: user.id, at: now()) })
        }
        me.delete("tags/:tagId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("tagId")
            _ = try await stored { try store.deleteTag(id, for: user.id, at: now()) }
            return Response(status: .noContent)
        }
        // Merge Tag: this tag's notes, projects and documents take the tag it is merged into, and
        // it is deleted. Answers the tag that remains.
        me.post("tags/:tagId/merge") { request, context -> UserTag in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("tagId")
            let body = try await JSONBody.decode(Merge.self, from: request, fields: ["into"])
            return try await stored { () -> UserTag in
                try store.mergeTag(id, into: body.into, for: user.id, at: now())
                guard let survivor = try store.tag(body.into, of: user.id) else { throw TagStoreError.tagNotFound(body.into) }
                return UserTag(survivor)
            }
        }

        let documentTags: RouterPath = "volumes/:volumeId/documents/:documentId/tags"
        me.get(documentTags) { request, context -> DocumentTags in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try self.document(context, resources: resources)
            let tags = try await Blocking.run { try store.tags(of: document, for: user.id) }
            return DocumentTags(document, tags)
        }
        // The tag picker's Done: the document carries exactly these tags.
        me.put(documentTags) { request, context -> DocumentTags in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try self.document(context, resources: resources)
            let body = try await JSONBody.decode(TagSet.self, from: request, fields: ["tagIds"])
            return DocumentTags(document, try await stored { try store.setTags(body.tagIds, of: document, for: user.id, at: now()) })
        }
        // The Research rail's ×: one tag off the document.
        me.delete("volumes/:volumeId/documents/:documentId/tags/:tagId") { request, context -> DocumentTags in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let document = try self.document(context, resources: resources)
            let id = try context.parameters.require("tagId")
            return DocumentTags(document, try await stored { try store.removeTag(id, from: document, for: user.id) })
        }
    }

    /// The document a route names. Its volume must be in the catalogue; the document is named and
    /// not looked up, since the Mac's assignments can name a document this server does not hold.
    private static func document(_ context: APIRequestContext, resources: ServerResources) throws -> DocumentKey {
        let volumeId = try context.parameters.require("volumeId")
        let documentId = try context.parameters.require("documentId")
        guard resources.volume(volumeId) != nil else { throw APIProblem.volumeNotFound(volumeId) }
        guard documentId.utf8.count <= 256, FRUSURLScheme.isSafeComponent(documentId) else {
            throw APIProblem.invalidParameter("documentId", "\(documentId) is not a document's id.")
        }
        return DocumentKey(volumeId: volumeId, documentId: documentId)
    }

    /// Runs a store call off the cooperative pool, its refusals as problems.
    private static func stored<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        do {
            return try await Blocking.run(work)
        } catch let error as TagStoreError {
            throw problem(error)
        }
    }

    static func problem(_ error: TagStoreError) -> APIProblem {
        switch error {
        case .emptyName:
            APIProblem(.badRequest, code: "INVALID_FIELD", detail: "name: a tag's name, trimmed of spaces and new lines, cannot be empty.")
        case .tagNotFound(let id):
            APIProblem(.notFound, code: "TAG_NOT_FOUND", detail: "You have no tag with the id \(id).")
        case .mergeIntoItself:
            APIProblem(.badRequest, code: "INVALID_FIELD", detail: "into: a tag cannot be merged into itself.")
        }
    }
}

extension DocumentTags {
    init(_ document: DocumentKey, _ tags: [UserTagRecord]) {
        self.init(volumeId: document.volumeId, documentId: document.documentId, items: tags.map(UserTag.init))
    }
}
