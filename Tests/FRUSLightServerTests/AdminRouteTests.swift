// /api/v1/admin through the router (PLAN's S20d): every route refused to a reader, and its changes held
// to /api/v1/me's guard; the jobs an import and a reset leave, and a cancel of one waiting and one
// running; the users under local accounts, an admin's changes to them, which end a disabled account's
// or a new password's sessions at once and never leave the instance without an admin; a user's
// research erased, theirs alone, once its counts are confirmed; Status; the backups; and the index's
// reset in Import mode.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct AdminRouteTests {
    static let password = LocalAccountTests.password
    static let anyJob = "5E20D000-0000-4000-8000-000000000001"

    /// Every route under /api/v1/admin, with a body where it takes one.
    static let routes: [(HTTPRequest.Method, String, String?)] = [
        (.get, "/api/v1/admin/status", nil),
        (.get, "/api/v1/admin/jobs", nil),
        (.get, "/api/v1/admin/jobs/\(anyJob)", nil),
        (.post, "/api/v1/admin/jobs/\(anyJob)/cancel", nil),
        (.get, "/api/v1/admin/users", nil),
        (.post, "/api/v1/admin/users", #"{"name":"carol","password":"\#(password)"}"#),
        (.patch, "/api/v1/admin/users/bob", #"{"role":"admin"}"#),
        (.put, "/api/v1/admin/users/bob/password", #"{"password":"\#(password)"}"#),
        (.get, "/api/v1/admin/users/bob/research", nil),
        (.post, "/api/v1/admin/users/alice/research/erase", #"{"expected":{}}"#),
        (.get, "/api/v1/admin/backups", nil),
        (.get, "/api/v1/admin/backup", nil),
        (.post, "/api/v1/admin/index/reset", nil),
        (.get, "/api/v1/admin/index", nil),
        (.post, "/api/v1/admin/index/compact", nil),
        (.post, "/api/v1/admin/index/check", nil),
        (.get, "/api/v1/admin/secrets", nil),
        (.put, "/api/v1/admin/secrets/nara", #"{"value":"abc"}"#),
        (.delete, "/api/v1/admin/secrets/nara", nil),
        (.get, "/api/v1/admin/library", nil),
        (.post, "/api/v1/admin/library/downloads", #"{"all":true}"#),
        (.post, "/api/v1/admin/library/index", #"{"all":true}"#),
        (.post, "/api/v1/admin/library/sideload?file=frusX.xml", nil),
        (.delete, "/api/v1/admin/library/volumes/frus1894Nicaragua", nil),
    ]

    /// The routes the admin files register, as their source writes them: so a route added there and
    /// not to `routes` fails this suite.
    @Test func everyRouteTheAdminFilesRegisterIsTested() throws {
        let folder = RepositoryFiles.root.appendingPathComponent("Sources/FRUSLightAPI")
        var registered: Set<String> = []
        for file in try FileManager.default.contentsOfDirectory(atPath: folder.path) where file.hasPrefix("Admin") {
            let source = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
            // The admin group's, and the side-load's group of its own (PLAN's S21e).
            for match in source.matches(of: /(?:admin|sideloads)\.(get|post|put|patch|delete)\("([^"]*)"\)/) {
                registered.insert("\(match.1.uppercased()) \(match.2)")
            }
        }
        let tested = Set(Self.routes.map { method, path, _ in
            "\(method.rawValue) " + String(path.dropFirst("/api/v1/admin/".count))
                .replacingOccurrences(of: Self.anyJob, with: ":jobId")
                .replacing(#/users/(bob|alice)/#, with: "users/:userName")
                .replacingOccurrences(of: "library/volumes/frus1894Nicaragua", with: "library/volumes/:volumeId")
                .replacingOccurrences(of: "?file=frusX.xml", with: "")
        })
        #expect(registered.isSubset(of: tested), "untested: \(registered.subtracting(tested).sorted())")
        #expect(registered.count >= 12)
    }

    /// A reader is refused every route, before it reads a body or changes anything; an admin is not.
    @Test func aReaderIsRefusedEveryRoute() async throws {
        let fixture = try await LocalAccountTests.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", Self.password)
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            for (method, path, body) in Self.routes {
                let response = method == .get ? try await bob.get(path) : try await bob.send(method, path, body)
                #expect(response.status == .forbidden && problemCode(response) == "ROLE_REQUIRED", "\(method) \(path)")
                if method == .get {
                    #expect(problemCode(try await alice.get(path)) != "ROLE_REQUIRED", "\(path) answers an admin")
                }
            }
            #expect(try fixture.store.account("bob")?.role == .reader && fixture.store.account("carol") == nil, "nothing changed")
            let nobody = AccountBrowser(client: client)
            #expect(problemCode(try await nobody.get("/api/v1/admin/status")) == "NOT_SIGNED_IN")
        }
    }

    /// An admin's changes pass /api/v1/me's guard: the token, the origin and the body's size.
    @Test func anAdminsChangesPassTheGuard() async throws {
        let fixture = try await LocalAccountTests.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            let change = #"{"role":"curator"}"#
            #expect(problemCode(try await alice.send(.patch, "/api/v1/admin/users/bob", change, token: "0")) == "CSRF_TOKEN_INVALID")
            var elsewhere = alice
            elsewhere.origin = "https://evil.example"
            #expect(problemCode(try await elsewhere.send(.patch, "/api/v1/admin/users/bob", change)) == "ORIGIN_NOT_ALLOWED")
            let large = #"{"role":"curator","x":""# + String(repeating: "a", count: 70_000) + #""}"#
            #expect(problemCode(try await alice.send(.patch, "/api/v1/admin/users/bob", large)) == "CONTENT_TOO_LARGE")
            #expect(problemCode(try await alice.send(.patch, "/api/v1/admin/users/bob", #"{"role":"curator","x":1}"#)) == "UNKNOWN_FIELD")
            #expect(try fixture.store.account("bob")?.role == .reader, "nothing changed")
        }
    }

    /// An import's job is listed with the import's id, who asked and its line; a job waiting is
    /// cancelled at once, the import's status saying so and nothing kept, and one running stops at its
    /// next step; a finished one, or one unknown, is refused.
    @Test func theJobsListAndCancel() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let posted = try decode(ImportStatus.self, try await owner.send(.post, ImportRouteTests.path, try ImportRouteTests.export()))
            await fixture.jobs.waitUntilIdle()
            let list = try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs"))
            let job = try #require(list.jobs.first)
            #expect(list.jobs.count == 1 && job.id == posted.id && job.kind == "researchImport" && job.state == "succeeded")
            #expect(job.requestedBy == "owner" && job.subject == "A Mac JSON export, format 7" && job.error == nil && !job.cancellable)
            #expect(job.progress?.hasPrefix("Imported into owner's research: ") == true)
            #expect(try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id.lowercased())")) == job)
            let finished = try await owner.send(.post, "/api/v1/admin/jobs/\(job.id)/cancel")
            #expect(finished.status == .conflict && problemCode(finished) == "JOB_FINISHED")
            #expect(problemCode(try await owner.get("/api/v1/admin/jobs/\(Self.anyJob)")) == "JOB_NOT_FOUND")
            #expect(problemCode(try await owner.send(.post, "/api/v1/admin/jobs/\(Self.anyJob)/cancel")) == "JOB_NOT_FOUND")

            // A job of the server's runs; the next import waits behind it.
            let gate = JobGate()
            let held = try await fixture.jobs.submit(.indexImport, subject: "export.sqlite") { job in
                try await job.step("Copying export.sqlite")
                await gate.wait()
                try await job.step("Checking the file's format")
                return nil
            }
            await gate.untilReached()
            let second = try decode(ImportStatus.self, try await owner.send(.post, ImportRouteTests.path, try ImportRouteTests.export(noteText: "Two.")))
            let dequeued = try await owner.send(.post, "/api/v1/admin/jobs/\(second.id)/cancel")
            let cancelled = try decode(AdminJob.self, dequeued)
            #expect(dequeued.status == .ok && cancelled.state == "cancelled")
            let status = try decode(ImportStatus.self, try await owner.get("/api/v1/me/import/\(second.id)"))
            #expect(status.state == .failed && status.problem?.code == "IMPORT_CANCELLED" && status.problem?.detail == ImportRoutes.cancelledDetail)
            let asked = try await owner.send(.post, "/api/v1/admin/jobs/\(held.id)/cancel")
            let running = try decode(AdminJob.self, asked)
            #expect(asked.status == .accepted && running.state == "running" && running.cancelRequestedBy == "owner")
            gate.open()
            await fixture.jobs.waitUntilIdle()
            let stopped = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(held.id)"))
            #expect(stopped.state == "cancelled" && stopped.progress == "Copying export.sqlite" && stopped.requestedBy == nil)
            #expect(try decode(AdminJobList.self, try await owner.get("/api/v1/admin/jobs")).jobs.map(\.id) == [second.id, held.id, job.id])
            #expect(try fixture.store.note(ImportRouteTests.id(1).uuidString, of: "owner")?.bodyText == "An imported note.",
                    "the cancelled import kept nothing")
        }
    }

    /// Under local accounts an admin lists, adds and changes them: a disabled account's session, and a
    /// session of an account given a new password, end at once; and no change leaves no admin.
    @Test func anAdminManagesTheAccounts() async throws {
        let fixture = try await LocalAccountTests.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", Self.password)

            let list = try decode(AdminUserList.self, try await alice.get("/api/v1/admin/users"))
            #expect(list.auth == "local" && list.users.map(\.id) == ["alice", "bob", "owner"])
            let listedBob = try #require(list.users.first { $0.id == "bob" })
            #expect(listedBob.role == "reader" && listedBob.hasPassword && listedBob.disabledAt == nil && listedBob.lastSignInAt != nil)
            #expect(list.users.first { $0.id == "owner" }?.hasPassword == false)

            let made = try await alice.send(.post, "/api/v1/admin/users", #"{"name":" Zoë Ödegaard ","role":"curator","password":"\#(Self.password)"}"#)
            #expect(made.status == .created && made.headers[.location] == "/api/v1/admin/users/Zo%C3%AB%20%C3%96degaard")
            #expect(try decode(AdminUser.self, made).role == "curator")
            var zoe = AccountBrowser(client: client)
            #expect(try await zoe.signIn("Zoë Ödegaard", Self.password).status == .ok, "the new account signs in")
            #expect(problemCode(try await alice.send(.post, "/api/v1/admin/users", #"{"name":"bob","password":"\#(Self.password)"}"#)) == "USER_EXISTS")
            let short = try await alice.send(.post, "/api/v1/admin/users", #"{"name":"carol","password":"short"}"#)
            #expect(problemCode(short) == "INVALID_FIELD" && !String(buffer: short.body).contains("short\""), "a password is never repeated")
            #expect(problemCode(try await alice.send(.post, "/api/v1/admin/users", #"{"name":"carol","role":"owner","password":"\#(Self.password)"}"#)) == "INVALID_FIELD")

            let renamed = try decode(AdminUser.self, try await alice.send(.patch, "/api/v1/admin/users/Zo%C3%AB%20%C3%96degaard", #"{"role":"reader"}"#))
            #expect(renamed.id == "Zoë Ödegaard" && renamed.role == "reader")
            #expect(try await bob.me().roles == [.reader])
            _ = try await alice.send(.patch, "/api/v1/admin/users/bob", #"{"role":"curator"}"#)
            #expect(try await bob.me().roles == [.reader, .curator], "a new role reaches a held session at once")
            let disabled = try decode(AdminUser.self, try await alice.send(.patch, "/api/v1/admin/users/bob", #"{"disabled":true}"#))
            #expect(disabled.disabledAt != nil)
            #expect(problemCode(try await bob.get("/api/v1/me")) == "NOT_SIGNED_IN", "a disabled account's session ends at once")
            _ = try await alice.send(.patch, "/api/v1/admin/users/bob", #"{"disabled":false}"#)
            try await bob.signIn("bob", Self.password)
            let reset = try await alice.send(.put, "/api/v1/admin/users/bob/password", #"{"password":"a new password, quite long"}"#)
            #expect(reset.status == .noContent)
            #expect(problemCode(try await bob.get("/api/v1/me")) == "NOT_SIGNED_IN", "a new password ends the sessions at once")
            #expect(try await bob.signIn("bob", Self.password).status == .forbidden)
            #expect(try await bob.signIn("bob", "a new password, quite long").status == .ok)

            let last = try await alice.send(.patch, "/api/v1/admin/users/alice", #"{"role":"reader"}"#)
            #expect(last.status == .conflict && problemCode(last) == "LAST_ADMIN")
            #expect(problemCode(try await alice.send(.patch, "/api/v1/admin/users/alice", #"{"disabled":true}"#)) == "LAST_ADMIN")
            #expect(try await alice.me().roles.contains(.admin), "she is still an admin")
            #expect(problemCode(try await alice.send(.patch, "/api/v1/admin/users/nobody", #"{"role":"reader"}"#)) == "USER_NOT_FOUND")
        }
    }

    /// Under no sign-in the accounts are none of the server's to change, and the list is its one user.
    @Test func withoutLocalAccountsTheListAlone() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let list = try decode(AdminUserList.self, try await owner.get("/api/v1/admin/users"))
            #expect(list.auth == "none" && list.users.map(\.id) == ["owner"] && list.users[0].role == "admin")
            for (method, path, body) in Self.routes.filter({ $0.1.contains("/users") && !$0.1.contains("research") && $0.0 != .get }) {
                #expect(problemCode(try await owner.send(method, path, body)) == "ACCOUNTS_NOT_LOCAL", "\(method) \(path)")
            }
        }
    }

    /// An admin erases a user's research once its counts are confirmed: their export is then empty,
    /// another's is not; counts from before a change are refused, and an import of theirs under way
    /// holds the erasure off.
    @Test func anAdminErasesOneUsersResearch() async throws {
        let fixture = try await LocalAccountTests.fixture()
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            var alice = AccountBrowser(client: client)
            try await alice.signIn("alice", Self.password)
            var bob = AccountBrowser(client: client)
            try await bob.signIn("bob", Self.password)
            for browser in [alice, bob] {
                #expect(try await browser.send(.post, "/api/v1/me/tags", #"{"name":"Cuba"}"#).status == .created)
            }
            let counted = try decode(ResearchHoldings.self, try await alice.get("/api/v1/admin/users/bob/research"))
            #expect(counted.userId == "bob" && counted.total == 1 && counted.holdings.last?.type == "StoredKey")
            #expect(counted.holdings.first { $0.table == "tags" } == ResearchHolding(type: "UserTag", table: "tags", count: 1))
            func confirmation(_ holdings: ResearchHoldings) -> String {
                "{\"expected\":{" + holdings.holdings.map { "\"\($0.table)\":\($0.count)" }.joined(separator: ",") + "}}"
            }
            #expect(try await bob.send(.post, "/api/v1/me/tags", #"{"name":"Laos"}"#).status == .created)
            let stale = try await alice.send(.post, "/api/v1/admin/users/bob/research/erase", confirmation(counted))
            #expect(stale.status == .conflict && problemCode(stale) == "RESEARCH_CHANGED")
            let recounted = try decode(ResearchHoldings.self, try await alice.get("/api/v1/admin/users/bob/research"))
            let erased = try await alice.send(.post, "/api/v1/admin/users/bob/research/erase", confirmation(recounted))
            let removed = try decode(ResearchHoldings.self, erased)
            #expect(erased.status == .ok && removed == recounted)

            func exported(_ browser: AccountBrowser) async throws -> Int {
                try decode(ExportContents.self, try await browser.get("/api/v1/me/export/contents")).types.reduce(0) { $0 + $1.count }
            }
            #expect(try await exported(bob) == 0, "bob's export is empty")
            #expect(try await exported(alice) == 1, "alice's is not")
            #expect(try await bob.me().userId == "bob", "his account and his session are as they were")
            #expect(problemCode(try await alice.get("/api/v1/admin/users/nobody/research")) == "USER_NOT_FOUND")

            // An import of bob's waits behind a job: the erasure is refused until it ends.
            let gate = JobGate()
            _ = try await fixture.jobs.submit(.indexImport) { _ in
                await gate.wait()
                return nil
            }
            #expect(try await bob.send(.post, ImportRouteTests.path, try ImportRouteTests.export()).status == .accepted)
            let held = try decode(ResearchHoldings.self, try await alice.get("/api/v1/admin/users/bob/research"))
            #expect(problemCode(try await alice.send(.post, "/api/v1/admin/users/bob/research/erase", confirmation(held))) == "IMPORT_IN_PROGRESS")
            gate.open()
            await fixture.jobs.waitUntilIdle()
        }
    }

    /// Status names the mode, the index, the store and its migration, the backups, the key file and the
    /// jobs; the backups' list is the archive manifest's.
    @Test func statusAndTheBackups() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            let response = try await owner.get("/api/v1/admin/status")
            #expect(response.headers[.cacheControl] == "no-store")
            let status = try decode(AdminStatus.self, response)
            #expect(status.mode == "import" && status.auth == "none" && status.userData && status.version == FRUSLightVersion.string)
            let served = try decode(ServerStatus.self, try await owner.get("/api/v1/status"))
            #expect(status.readiness.ready && status.index != nil && status.index == served.index && status.catalogueVolumes == 553)
            #expect(status.store == .init(kind: "sqlite", migration: UserStoreMigrations.all.count, latestMigration: UserStoreMigrations.all.count))
            #expect(status.keys == .init(keyFileId: fixture.services.secrets.key.id, stored: 0))
            #expect(status.backups?.daily == 0 && status.backups?.newest == nil && status.backups?.hour == "03:00")
            #expect(status.jobs == .init(queued: 0, running: nil))
            let backups = try decode(AdminBackups.self, try await owner.get("/api/v1/admin/backups"))
            #expect(backups.backedUp && backups.backups.isEmpty && !backups.copiedToHost)
        }
    }

    /// In Import mode the reset is a job that removes the served index, after which the server waits for
    /// an export: search is refused, the readiness says so, and the files are gone.
    @Test func anIndexResetRemovesTheServedIndex() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let owner = Browser(client: client)
            #expect(try await owner.get("/api/v1/search?keywords=containment").status == .ok)
            let posted = try await owner.send(.post, "/api/v1/admin/index/reset")
            let job = try decode(AdminJob.self, posted)
            #expect(posted.status == .accepted && posted.headers[.location] == "/api/v1/admin/jobs/\(job.id)")
            #expect(job.kind == "indexReset" && job.requestedBy == "owner")
            await fixture.jobs.waitUntilIdle()
            let done = try decode(AdminJob.self, try await owner.get("/api/v1/admin/jobs/\(job.id)"))
            #expect(done.state == "succeeded" && done.progress?.hasPrefix("Removed the index of ") == true)
            let refused = try await owner.get("/api/v1/search?keywords=containment")
            #expect(refused.status == .serviceUnavailable && problemCode(refused) == "INDEX_NOT_READY")
            #expect(await fixture.server.state.readiness().step == .waitingForExport)
            #expect(!FileManager.default.fileExists(atPath: fixture.server.files.liveIndex.path))
            #expect(try decode(AdminStatus.self, try await owner.get("/api/v1/admin/status")).index == nil)
        }
    }
}
