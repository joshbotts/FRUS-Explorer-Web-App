// /api/v1/me/volume-scopes (PLAN's S17e): the user's volume scopes, My Scopes, each a named set of
// volumes the reader assembles, as the Mac's `CustomVolumeScope` keeps one: listed most recently
// edited first, as Browse's My Scopes lists them (`ScopeIndexView`); made, as its New Scope makes one;
// renamed and given its volumes, as the scope editor writes them (`ScopeEditorView`, `ScopeAxis`); and
// deleted. Each is resolved as the kit resolves a scope (`CustomScopeResolver`): at the index's grain,
// the members the served index holds, which a search's volume filter takes, or the explicit outcome
// that none are, which never searches unscoped; and at the catalogue's, the members it can show. A row
// is written as the import writes a Mac's (`MacImport.scope`) and read as the export reads one
// (`ResearchExport.scope`).

import FRUSCoreKit
import FRUSLightCore
import Foundation
import Hummingbird

/// One of the user's volume scopes.
public struct VolumeScope: Codable, Equatable, Sendable, ResponseEncodable {
    public var id: String
    /// May be empty, as New Scope makes one: a list names it Untitled Scope.
    public var name: String
    /// Its members, the catalogue's volume ids, each once, sorted, as the editor writes them; they may
    /// name a volume the catalogue no longer lists, which the scope keeps.
    public var volumeIds: [String]
    public var createdAt: String?
    public var lastModified: String?
    /// The kit's index grain, `CustomScopeResolver.indexedResolution(memberVolumeIds:indexed:)`: the
    /// members the served index holds, sorted, never empty, which a search's volume filter takes; absent
    /// for `noIndexedMembers`, and while no index is served.
    public var indexedVolumeIds: [String]?
    /// `resolved`, or `noIndexedMembers`: the scope has members, or none, and the index holds none of
    /// them, which a search must say rather than search every volume. Absent while no index is served.
    public var indexedResolution: String?
    /// The kit's catalogue grain, `CustomScopeResolver.manifestVolumeIds(memberVolumeIds:manifestIds:)`:
    /// how many of its members the catalogue lists, which the scope's list shows.
    public var cataloguedCount: Int

    init(_ scope: CustomVolumeScopeExport, served: ServedIndex?, resources: ServerResources) {
        id = scope.id.uuidString
        name = scope.name
        volumeIds = scope.volumeIds
        createdAt = scope.createdAt.map(UserStoreDate.text)
        lastModified = scope.lastModified.map(UserStoreDate.text)
        if let served {
            switch CustomScopeResolver.indexedResolution(memberVolumeIds: scope.volumeIds, indexed: served.indexedVolumeIds) {
            case .resolved(let ids):
                indexedVolumeIds = ids.sorted()
                indexedResolution = "resolved"
            case .noIndexedMembers, .scopeUnavailable:
                indexedResolution = "noIndexedMembers"
            }
        }
        cataloguedCount = CustomScopeResolver.manifestVolumeIds(
            memberVolumeIds: scope.volumeIds, manifestIds: Set(resources.manifest.map(\.volumeId))).count
    }
}

/// The user's volume scopes, the most recently edited first.
public struct VolumeScopeList: Codable, Equatable, Sendable, ResponseEncodable {
    public var total: Int
    public var items: [VolumeScope]
}

enum VolumeScopeRoutes {
    struct Create: Decodable {
        let name: String?
        let volumeIds: [String]?
    }

    struct Edit: Decodable {
        let name: String?
        let volumeIds: [String]?
    }

    /// The most volumes a scope may name, the web's own bound: several times the catalogue's.
    static let volumeLimit = 5_000

    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices, provider: ServedIndexProvider,
                    resources: ServerResources) {
        let store = services.store
        let now = services.now

        me.get("volume-scopes") { request, context -> VolumeScopeList in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let served = try await provider.servedIfReady()
            let scopes = try await scopes(of: user.id, in: store)
            return VolumeScopeList(total: scopes.count, items: scopes.map { VolumeScope($0, served: served, resources: resources) })
        }
        // New Scope: `ScopeAxis.create(named:volumeIds:in:)`, unnamed and empty unless the body names
        // some, as the Save as Scope of a volume list would.
        me.post("volume-scopes") { request, context -> EditedResponse<VolumeScope> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let body = try await JSONBody.decode(Create.self, from: request, fields: ["name", "volumeIds"])
            let time = UserStoreDate.rounded(now())
            let scope = CustomVolumeScopeExport(id: UUID(), name: body.name ?? "", volumeIds: try members(body.volumeIds ?? []),
                                                createdAt: time, lastModified: time)
            try await Blocking.run { try store.addSearchSet(.volumeScopes, MacImport.scope(scope).values, for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/volume-scopes/\(scope.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: VolumeScope(scope, served: try await provider.servedIfReady(), resources: resources))
        }
        me.get("volume-scopes/:scopeId") { request, context -> VolumeScope in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let scope = try await scope(try context.parameters.require("scopeId"), of: user.id, in: store)
            return VolumeScope(scope, served: try await provider.servedIfReady(), resources: resources)
        }
        // The editor: its name as typed, and its members as one sorted reassignment, each stamping the
        // time it changed, as the editor's bindings and its picker's Done do.
        me.patch("volume-scopes/:scopeId") { request, context -> VolumeScope in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("scopeId")
            let body = try await JSONBody.decode(Edit.self, from: request, fields: ["name", "volumeIds"])
            var scope = try await scope(id, of: user.id, in: store)
            if let name = body.name { scope.name = name }
            if let volumeIds = body.volumeIds { scope.volumeIds = try members(volumeIds) }
            scope.lastModified = UserStoreDate.rounded(now())
            let values = MacImport.scope(scope).values.filter { ["name", "volume_ids", "last_modified"].contains($0.key) }
            guard let row = try await Blocking.run({ try store.updateSearchSet(.volumeScopes, id: id, values, for: user.id) }) else {
                throw notFound(id)
            }
            return VolumeScope(try read(row), served: try await provider.servedIfReady(), resources: resources)
        }
        me.delete("volume-scopes/:scopeId") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let id = try context.parameters.require("scopeId")
            guard try await Blocking.run({ try store.deleteSearchSet(.volumeScopes, id: id, for: user.id) }) else { throw notFound(id) }
            return Response(status: .noContent)
        }
    }

    /// A scope's members as `CustomVolumeScope.init` keeps them, each once and sorted: volume ids, which
    /// may name volumes the catalogue does not list, as an imported scope can.
    static func members(_ volumeIds: [String]) throws -> [String] {
        guard volumeIds.count <= volumeLimit else {
            throw APIProblem.invalidParameter("volumeIds", "a scope names at most \(volumeLimit) volumes, not \(volumeIds.count)")
        }
        if let bad = volumeIds.first(where: { $0.isEmpty || $0.utf8.count > 256 || !FRUSURLScheme.isSafeComponent($0) }) {
            throw APIProblem.invalidParameter("volumeIds", "\(bad) is not a volume's id")
        }
        return Array(Set(volumeIds)).sorted()
    }

    /// The user's scopes, the most recently edited first, as `@Query(sort: \CustomVolumeScope.lastModified,
    /// order: .reverse)` lists them, one never edited last; a tie in the store's order.
    static func scopes(of user: String, in store: any UserDataStore) async throws -> [CustomVolumeScopeExport] {
        let rows = try await Blocking.run { try store.searchSets(.volumeScopes, of: user) }
        let scopes = try rows.map(read)
        return scopes.enumerated().sorted { a, b in
            let (x, y) = (a.element.lastModified ?? .distantPast, b.element.lastModified ?? .distantPast)
            return x != y ? x > y : a.offset < b.offset
        }.map(\.element)
    }

    static func scope(_ id: String, of user: String, in store: any UserDataStore) async throws -> CustomVolumeScopeExport {
        guard let row = try await Blocking.run({ try store.searchSet(.volumeScopes, id: id, of: user) }) else { throw notFound(id) }
        return try read(row)
    }

    static func read(_ row: ExportRow) throws -> CustomVolumeScopeExport {
        do {
            return try ResearchExport.scope(ResearchExport.Fields("volume_scopes", row))
        } catch let error as ResearchExportError {
            throw APIProblem(.internalServerError, code: "STORE_DAMAGED", detail: "The volume scope could not be read: \(error.description)")
        }
    }

    static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "SCOPE_NOT_FOUND", detail: "You have no volume scope with the id \(id).")
    }
}
