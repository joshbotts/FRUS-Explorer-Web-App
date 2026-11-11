// /api/v1/admin/users (PLAN's S20d): the users the store holds, with their roles and last sign-in, and
// under `FRUS_AUTH=local` an admin's changes to the accounts, as `frus-light user` makes them: add one,
// set a role, disable or enable one, and set a new password. A new password and a disabled account end
// every session of the user's at once. No change leaves the instance without an admin who can sign in.
// Behind a proxy that signs people in the list alone, its admins `FRUS_ADMIN_USERS`'s. And the recovery
// action SPEC names, in every mode: erase one user's research, after a confirmation that names what
// they hold, which the erasure is refused unless they still hold. An admin's, behind `AdminRoutes`' guard.
//   GET   /api/v1/admin/users                          every user
//   POST  /api/v1/admin/users                          {"name", "displayName"?, "role"?, "password"}
//   PATCH /api/v1/admin/users/{name}                   {"role"?, "disabled"?}
//   PUT   /api/v1/admin/users/{name}/password          {"password"}
//   GET   /api/v1/admin/users/{name}/research          what an erasure would remove, table by table
//   POST  /api/v1/admin/users/{name}/research/erase    {"expected": {table: count}}

import FRUSLightCore
import Foundation
import Hummingbird

/// A user, as the admin's Users list shows them.
public struct AdminUser: Codable, Equatable, Sendable, ResponseEncodable {
    /// Their name, the id their research is kept under.
    public var id: String
    public var displayName: String
    /// `reader`, `curator` or `admin`, as the server takes them: behind a proxy, an admin if
    /// `FRUS_ADMIN_USERS` names them and a reader otherwise.
    public var role: String
    /// Whether they have a password, without which no one signs in as them.
    public var hasPassword: Bool
    /// When they were disabled; absent while they are not.
    public var disabledAt: String?
    public var lastSignInAt: String?
    public var createdAt: String?
}

/// `GET /api/v1/admin/users`.
public struct AdminUserList: Codable, Equatable, Sendable, ResponseEncodable {
    /// `FRUS_AUTH`: the accounts are this server's to change only under `local`.
    public var auth: String
    public var users: [AdminUser]
}

/// One table's rows of a user's that an erasure removes.
public struct ResearchHolding: Codable, Equatable, Sendable {
    /// The app's model type, such as `ResearchNote`, or `StoredKey` for the keys the server keeps.
    public var type: String
    /// Its table, the key a confirmation names it by.
    public var table: String
    public var count: Int
}

/// `GET /api/v1/admin/users/{name}/research`, and what an erasure removed.
public struct ResearchHoldings: Codable, Equatable, Sendable, ResponseEncodable {
    public var userId: String
    /// Each of the user's tables, in the user store's order, the stored keys last.
    public var holdings: [ResearchHolding]
    public var total: Int
}

enum AdminUserRoutes {
    struct NewAccount: Decodable {
        let name: String
        let displayName: String?
        let role: String?
        let password: String
    }

    struct Change: Decodable {
        let role: String?
        let disabled: Bool?
    }

    struct NewPassword: Decodable {
        let password: String
    }

    struct Erasure: Decodable {
        let expected: [String: Int]
    }

    /// The model type a stored key's holding is named by.
    static let storedKeyType = "StoredKey"

    static func add(to admin: RouterGroup<APIRequestContext>, services: UserDataServices) {
        let store = services.store
        let now = services.now

        admin.get("users") { request, _ -> EditedResponse<AdminUserList> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let accounts = try await Blocking.run { try store.accounts() }
            let list = AdminUserList(auth: services.auth.rawValue, users: accounts.map { user($0, services) })
            return EditedResponse(headers: [.cacheControl: "no-store"], response: list)
        }

        admin.post("users") { request, context -> EditedResponse<AdminUser> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let accounts = try local(services)
            let body = try await JSONBody.decode(NewAccount.self, from: request, fields: ["name", "displayName", "role", "password"])
            let id = try checkedName(body.name, field: "name")
            let shown = try checkedName(body.displayName ?? id, field: "displayName")
            let role = try body.role.map { try checkedRole($0) } ?? .reader
            try checkPassword(body.password)
            guard try await Blocking.run({ try store.account(id) }) == nil else { throw exists(id) }
            let hash = try await hash(body.password, with: accounts)
            let time = now()
            let account: Account
            do {
                account = try await Blocking.run { try store.addAccount(id, displayName: shown, role: role, passwordHash: hash, at: time) }
            } catch AccountStoreError.exists {
                throw exists(id)
            }
            let by = try context.requireUser().id
            context.logger.info("\(by) made the account \(id), \(role.rawValue)")
            let location = context.basePath.prefixing("/api/v1/admin/users/\(pathComponent(id))")
            return EditedResponse(status: .created, headers: [.location: location, .cacheControl: "no-store"],
                                  response: user(account, services))
        }

        admin.patch("users/:userName") { request, context -> EditedResponse<AdminUser> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let accounts = try local(services)
            let id = try userName(context)
            let body = try await JSONBody.decode(Change.self, from: request, fields: ["role", "disabled"])
            let role = try body.role.map { try checkedRole($0) }
            let time = now()
            let account: Account
            do {
                account = try await Blocking.run { try store.changeAccount(id, role: role, disabled: body.disabled, at: time) }
            } catch let error as AccountStoreError {
                throw problem(error)
            }
            // Its sessions read the account again at their next request: a role at once, and a disabled
            // account's, which the store has ended, end here too.
            accounts.forgetSessions(of: id)
            let by = try context.requireUser().id
            if let role { context.logger.info("\(by) made \(id) \(role.rawValue == "admin" ? "an" : "a") \(role.rawValue)") }
            if let disabled = body.disabled { context.logger.info("\(by) \(disabled ? "disabled" : "enabled") \(id)") }
            return EditedResponse(headers: [.cacheControl: "no-store"], response: user(account, services))
        }

        admin.put("users/:userName/password") { request, context -> Response in
            try FormQuery(request.uri.query).refuseUnknown([])
            let accounts = try local(services)
            let id = try userName(context)
            let body = try await JSONBody.decode(NewPassword.self, from: request, fields: ["password"])
            try checkPassword(body.password)
            guard try await Blocking.run({ try store.account(id) }) != nil else { throw notFound(id) }
            let hash = try await hash(body.password, with: accounts)
            do {
                try await Blocking.run { try store.setPasswordHash(hash, of: id) }
            } catch let error as AccountStoreError {
                throw problem(error)
            }
            accounts.forgetSessions(of: id)
            let by = try context.requireUser().id
            context.logger.info("\(by) set a new password for \(id), ending their sessions")
            return Response(status: .noContent, headers: [.cacheControl: "no-store"])
        }

        admin.get("users/:userName/research") { request, context -> EditedResponse<ResearchHoldings> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let id = try userName(context)
            do {
                let held = try await Blocking.run { try store.researchHoldings(of: id) }
                return EditedResponse(headers: [.cacheControl: "no-store"], response: holdings(held, of: id))
            } catch let error as AccountStoreError {
                throw problem(error)
            }
        }

        admin.post("users/:userName/research/erase") { request, context -> EditedResponse<ResearchHoldings> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let id = try userName(context)
            let body = try await JSONBody.decode(Erasure.self, from: request, fields: ["expected"])
            // An import of theirs under way would write after the erasure: the erasure waits for none, and
            // is refused while one is queued or running, the JSON import's or, for the store's single
            // user, an index import's, which may bring the owner's writing; and no JSON import begins
            // while it erases.
            let single = try await Blocking.run { try store.singleUserID() }
            let indexImporting = await services.jobs.jobs().contains { $0.kind == .indexImport && !$0.state.isFinished }
            guard !(id == single && indexImporting), await services.imports.beginErasure(of: id) else {
                throw APIProblem(.conflict, code: "IMPORT_IN_PROGRESS",
                                 detail: "An import of \(id)'s is queued or running: erase their research once it has ended, or cancel its job first.")
            }
            let outcome: Result<[String: Int], any Error>
            do {
                outcome = .success(try await Blocking.run { try store.eraseResearch(of: id, expected: body.expected) })
            } catch {
                outcome = .failure(error)
            }
            await services.imports.endErasure(of: id)
            let erased: [String: Int]
            do {
                erased = try outcome.get()
            } catch let error as AccountStoreError {
                throw problem(error)
            } catch ResearchErasureError.changed {
                throw APIProblem(.conflict, code: "RESEARCH_CHANGED",
                                 detail: "\(id)'s research changed since it was counted, so nothing was erased: count it again, then confirm what it holds now.")
            }
            let removed = holdings(erased, of: id)
            let by = try context.requireUser().id
            context.logger.info("\(by) erased \(id)'s research: \(removed.total) rows")
            return EditedResponse(headers: [.cacheControl: "no-store"], response: removed)
        }
    }

    // MARK: Parts

    /// The accounts' sign-in, under `FRUS_AUTH=local`, whose accounts are this server's to change.
    private static func local(_ services: UserDataServices) throws -> LocalAccounts {
        guard let accounts = services.accounts else {
            let keeper = services.auth == .header ? "the proxy that signs people in keeps them" : "this server has one user, owner"
            throw APIProblem(.conflict, code: "ACCOUNTS_NOT_LOCAL",
                             detail: "Accounts are made and changed here only with FRUS_AUTH=local: \(keeper).")
        }
        return accounts
    }

    static func user(_ account: Account, _ services: UserDataServices) -> AdminUser {
        let role: String = switch services.auth {
        case .header: services.adminUsers.contains(account.id) ? AccountRole.admin.rawValue : AccountRole.reader.rawValue
        case .none, .local: account.role.rawValue
        }
        return AdminUser(id: account.id, displayName: account.displayName, role: role, hasPassword: account.passwordHash != nil,
                         disabledAt: account.disabledAt.map(UserStoreDate.text), lastSignInAt: account.lastSignInAt.map(UserStoreDate.text),
                         createdAt: account.createdAt.map(UserStoreDate.text))
    }

    /// The user a route names, by their name, which the path gives percent-encoded.
    private static func userName(_ context: APIRequestContext) throws -> String {
        let given = try context.parameters.require("userName")
        return given.removingPercentEncoding ?? given
    }

    /// A name for a path's segment: everything but what RFC 3986 leaves unreserved, percent-encoded.
    static func pathComponent(_ name: String) -> String {
        name.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? name
    }

    private static func checkedName(_ name: String, field: String) throws -> String {
        switch AccountNames.checked(name) {
        case .success(let checked): return checked
        case .failure(let problem): throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "\(field): \(problem)")
        }
    }

    private static func checkedRole(_ role: String) throws -> AccountRole {
        guard let parsed = AccountRole(rawValue: role) else {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "role: reader, curator or admin.")
        }
        return parsed
    }

    /// The rules for a new password, `PasswordRules`', in words that never repeat it.
    private static func checkPassword(_ password: String) throws {
        if let problem = PasswordRules.problem(with: password) {
            throw APIProblem(.badRequest, code: "INVALID_FIELD", detail: "password: \(problem)")
        }
    }

    private static func hash(_ password: String, with accounts: LocalAccounts) async throws -> String {
        guard let hash = try await accounts.hash(password) else {
            throw APIProblem(.serviceUnavailable, code: "SIGN_IN_BUSY", detail: "Too many passwords are being checked at once: try again in a moment.")
        }
        return hash
    }

    private static func holdings(_ held: [String: Int], of user: String) -> ResearchHoldings {
        let types = Dictionary(MacImport.types.map { ($0.table, $0.model) }, uniquingKeysWith: { first, _ in first })
        let tables = UserStoreSchema.erased.map(\.name) + [RelationalUserStore.secretsTable]
        let rows = tables.map { table in
            ResearchHolding(type: table == RelationalUserStore.secretsTable ? storedKeyType : types[table] ?? table, table: table,
                            count: held[table] ?? 0)
        }
        return ResearchHoldings(userId: user, holdings: rows, total: rows.reduce(0) { $0 + $1.count })
    }

    private static func exists(_ id: String) -> APIProblem {
        APIProblem(.conflict, code: "USER_EXISTS", detail: "There is already a user named \(id).")
    }

    private static func notFound(_ id: String) -> APIProblem {
        APIProblem(.notFound, code: "USER_NOT_FOUND", detail: "There is no user named \(id).")
    }

    private static func problem(_ error: AccountStoreError) -> APIProblem {
        switch error {
        case .exists(let id): exists(id)
        case .notFound(let id): notFound(id)
        case .lastAdmin: APIProblem(.conflict, code: "LAST_ADMIN", detail: error.description)
        case .changed: APIProblem(.conflict, code: "USER_CHANGED", detail: error.description)
        }
    }
}
