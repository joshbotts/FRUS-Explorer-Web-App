// /api/v1/me/secrets and /api/v1/admin/secrets (PLAN's S20c): the keys the server keeps for the
// outside services it calls, as the Mac keeps them in the Keychain. A user keeps a NARA Catalog key and
// a Zotero key of their own, and an admin the instance's NARA key, which serves everyone who has none.
// A key is taken, sealed and kept (`SecretVault`), and never given back: every answer here says only
// which keys are set, and when each was. Both groups pass /api/v1/me's guard, so a change is sent to
// the server's own address, from a page of it, with the user's token, as JSON of the guard's size; the
// instance's key also needs the admin role, checked before the route reads the request's body.

import FRUSLightCore
import Foundation
import Hummingbird

/// One key an owner may keep: whether it is set, and since when. Never the key.
public struct SecretStatus: Codable, Equatable, Sendable, ResponseEncodable {
    /// `nara` or `zotero`.
    public var name: String
    public var set: Bool
    /// When it was last set, as the store writes dates; absent while it is not.
    public var updatedAt: String?
}

/// `GET /api/v1/me/secrets` and `GET /api/v1/admin/secrets`: every key the owner may keep, in the order
/// the app's Connections lists the services.
public struct SecretList: Codable, Equatable, Sendable, ResponseEncodable {
    public var secrets: [SecretStatus]
    /// For a user: the instance's keys that are set, by name, which serve them while they have none of
    /// their own. Absent from an admin's list of the instance's own.
    public var instance: [String]?
}

enum SecretRoutes {
    struct Change: Decodable {
        let value: String
    }

    /// The user's own keys, under /api/v1/me.
    static func add(to me: RouterGroup<APIRequestContext>, services: UserDataServices) {
        add(to: me, services: services, instance: true) { .user($0.id) }
    }

    /// The instance's, under /api/v1/admin, for an admin alone.
    static func addInstance(to admin: RouterGroup<APIRequestContext>, services: UserDataServices) {
        add(to: admin, services: services, instance: false) { user in
            try user.require(.admin)
            return .instance
        }
    }

    /// The three routes over the keys of the owner a request's user gives: `owner` refuses a user who
    /// may not act for it. With `instance`, the list also names the instance's keys that are set.
    private static func add(to group: RouterGroup<APIRequestContext>, services: UserDataServices, instance: Bool,
                            owner: @escaping @Sendable (RequestUser) throws -> SecretOwner) {
        let vault = services.secrets
        let now = services.now

        group.get("secrets") { request, context -> EditedResponse<SecretList> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let owner = try owner(try context.requireUser())
            let list = try await Blocking.run {
                let held = try vault.entries(for: owner)
                let secrets = SecretName.names(for: owner).map { status($0, held[$0]) }
                guard instance else { return SecretList(secrets: secrets, instance: nil) }
                let shared = try vault.entries(for: .instance)
                return SecretList(secrets: secrets, instance: SecretName.names(for: .instance).filter { shared[$0] != nil }.map(\.rawValue))
            }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: list)
        }
        // Sets the key, in place of any the owner had. The answer names it as set, and nothing more.
        group.put("secrets/:name") { request, context -> EditedResponse<SecretStatus> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let owner = try owner(try context.requireUser())
            let name = try name(context, for: owner)
            let value = try await value(from: request)
            let time = now()
            do {
                let entry = try await Blocking.run { try vault.set(value, named: name, for: owner, at: time) }
                return EditedResponse(headers: [.cacheControl: "no-store"], response: status(name, entry.updatedAt))
            } catch let problem as SecretValueProblem {
                throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "value: \(problem.reason)")
            }
        }
        // Clears it. 204 whether or not one was set: either way the owner now has none.
        group.delete("secrets/:name") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let owner = try owner(try context.requireUser())
            let name = try name(context, for: owner)
            _ = try await Blocking.run { try vault.remove(named: name, for: owner) }
            return Response(status: .noContent, headers: [.cacheControl: "no-store"])
        }
    }

    private static func status(_ name: SecretName, _ updatedAt: Date?) -> SecretStatus {
        SecretStatus(name: name.rawValue, set: updatedAt != nil, updatedAt: updatedAt.map(UserStoreDate.text))
    }

    /// The key a route names, one `owner` may keep.
    private static func name(_ context: APIRequestContext, for owner: SecretOwner) throws -> SecretName {
        let given = try context.parameters.require("name")
        let names = SecretName.names(for: owner)
        guard let name = SecretName(rawValue: given), names.contains(name) else {
            let kept = names.map(\.rawValue).joined(separator: " and ")
            throw APIProblem(.notFound, code: "SECRET_NOT_FOUND",
                             detail: "There is no \(given) key here: the \(names.count == 1 ? "key kept is" : "keys kept are") \(kept).")
        }
        return name
    }

    /// The key a change carries, `{"value"}`. A body that gives none is refused in this route's own
    /// words, so that nothing a decoder says of what it read is repeated.
    private static func value(from request: Request) async throws -> String {
        do {
            return try await JSONBody.decode(Change.self, from: request, fields: ["value"]).value
        } catch let problem as APIProblem where problem.code == "INVALID_FIELD" {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "value: the key, as text.")
        }
    }
}
