// The user half of a search (PLAN's S17d): the notes and summaries its words match, and the tags its
// filter, its rows and its counts read, are those of the user the request acts for, from the user
// store's search database, which the served index attaches (FRUSCoreKit's
// `SearchUserSource.attachedStore(userId:)`, upstream #1806). A request that acts for no one searches
// the corpus alone. And GET /api/v1/me/search/tags: the user's tags, each counted over a search's
// results, as the Mac's My Tags toggles count them.

import FRUSCoreKit
import FRUSLightCore
import FTS5Store
import Foundation
import Hummingbird

/// The user a search reads beside the corpus, and how far their store had moved when it was asked.
struct SearchUser: Sendable, Equatable {
    let id: String
    /// The store's `searchMark()` as the search began.
    let mark: Int

    /// What begins the key each answer of the search is kept by: the mark and the id, ended by a line
    /// break, which no user's id holds, so the rest of the key cannot run into it.
    var key: String { "\(mark) \(id)\n" }
}

/// Whose notes, summaries and tags a search reads beside the corpus: the user a request under
/// /api/v1/me would act for, on the same terms. The server keeps user data, and the request is sent to
/// the address `FRUS_PUBLIC_URL` names, as a read under /me must be, since a page under another name
/// pointed at this server could otherwise read a user's writing through their searches. Behind a proxy
/// that signs people in, a request that names no one, as a script may send, searches as no one. A search
/// that acts for no one is the corpus's alone, as before S17d: its user half is the index's own, which
/// an import leaves empty (`IndexImporter.checkWriting`, and S16e's strip).
struct SearchUsers: Sendable {
    /// Nil for a server built with no user store, as some tests build it.
    let services: UserDataServices?

    /// The user `request` searches as, or nil for no one, once each tag `parameters` filter by is
    /// found among the user's own tags: one they have not, or any for no one, is refused as
    /// `TAG_NOT_FOUND`, so one user's search can never name another's tag.
    func user(searching parameters: SearchParameters, for request: Request, context: APIRequestContext) async throws -> SearchUser? {
        guard let services, let user = try await requestUser(request, context: context, services: services) else {
            if let tag = parameters.userTagIds.first {
                throw APIProblem(.notFound, code: "TAG_NOT_FOUND",
                                 detail: "No tag with the id \(tag) is yours to search by: this request acts for no one, and a search filters by the tags of the user a request under /api/v1/me acts for.")
            }
            return nil
        }
        return try await Self.user(user.id, searching: parameters, in: services.store)
    }

    /// `id` as a search's user, its tags checked against `parameters` and its store's mark taken.
    static func user(_ id: String, searching parameters: SearchParameters, in store: any UserDataStore) async throws -> SearchUser {
        let asked = parameters.userTagIds
        let (mark, held) = try await Blocking.run {
            (try store.searchMark(), asked.isEmpty ? [] : try store.tags(of: id).map(\.id))
        }
        let known = Set(held.map(caseFolded))
        if let missing = asked.first(where: { !known.contains(caseFolded($0)) }) {
            throw APIProblem(.notFound, code: "TAG_NOT_FOUND", detail: "You have no tag with the id \(missing).")
        }
        return SearchUser(id: id, mark: mark)
    }

    /// The user `request` acts for under /me's guard's first two steps, or nil: none while the server
    /// keeps no user data, for a request sent to another address, or for one that, behind a proxy, names
    /// no one signed in.
    private func requestUser(_ request: Request, context: APIRequestContext, services: UserDataServices) async throws -> RequestUser? {
        guard services.enabled, let host = request.head.authority, services.address.allows(host: host) else { return nil }
        do {
            return try await services.resolver.user(for: request, context: context)
        } catch let problem as APIProblem where problem.code == "NOT_SIGNED_IN" {
            return nil
        }
    }

    /// A tag's id with its ASCII letters in upper case: the kit matches a tag's id as SQLite's
    /// `COLLATE NOCASE` does, so a filter by an id in any case finds the user's tag.
    static func caseFolded(_ id: String) -> String {
        String(decoding: id.utf8.map { (0x61...0x7A).contains($0) ? $0 - 0x20 : $0 }, as: UTF8.self)
    }
}

/// `GET /api/v1/me/search/tags`: the user's tags, in the order `GET /me/tags` lists them, each with how
/// many documents of a search's results carry it, as the Mac's My Tags toggles count them, over the
/// search that ran, its tag filter included (`SearchService.userTagCounts(parameters:tagIds:documentKeys:)`,
/// the keyword route). A tag none of them carries counts 0, which is an answer worth showing, as the
/// Mac's says.
public struct SearchTagCounts: Codable, Equatable, Sendable {
    public struct Tag: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var count: Int
    }

    public var items: [Tag]
    public var coverage: Coverage
}

extension SearchTagCounts: ResponseEncodable {}

enum SearchTagRoutes {
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, provider: ServedIndexProvider,
                    resources: ServerResources) {
        // A search's fields, and its page and order, which change nothing it counts, so a search's
        // address can be read as it stands, as /search/inspect reads it.
        me.get("/search/tags") { request, context -> SearchTagCounts in
            let parameters = try SearchRequest(formEncoded: request.uri.query).parameters
            let user = try context.requireUser()
            let search = try await SearchUsers.user(user.id, searching: parameters, in: services.store)
            let store = services.store
            let tags = try await Blocking.run { try store.tags(of: user.id) }
            let served = try await provider.served()
            let counts: [String: Int]
            do {
                counts = try await served.search(for: search).service.userTagCounts(parameters: parameters, tagIds: tags.map(\.id))
            } catch let error as FTS5Error {
                throw SearchRoutes.refusal(error)
            }
            return SearchTagCounts(items: tags.map { .init(id: $0.id, name: $0.name, count: counts[$0.id] ?? 0) },
                                   coverage: Coverage(index: served.corpus, resources: resources))
        }
    }
}
