// GET /api/v1/admin/backup (S14b): the newest daily backup with a manifest of versions, as one tar
// archive, for an admin alone, by the role check the server makes for an instance's data; refused
// while user data is off, and to another host, as the user's own data is.

import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

/// A request's user who holds `roles` alone, as S14e's sign-in may resolve one.
struct RolesResolver: UserResolver {
    let roles: [RequestUser.Role]

    func user(for request: Request, context: APIRequestContext) async throws -> RequestUser {
        RequestUser(id: "owner", displayName: "Owner", roles: roles)
    }
}

@Suite struct AdminBackupTests {
    static let hour = Date(timeIntervalSince1970: 1_793_070_000)  // 2026-10-27T03:00:00Z
    static let path = "/api/v1/admin/backup"

    static func backups(_ fixture: UserDataFixture) -> UserStoreBackups {
        UserStoreBackups(files: fixture.server.files, copyDirectory: nil,
                         schedule: BackupSchedule(hour: 3, timeZone: TimeZone(identifier: "UTC")!))
    }

    /// A backup of the fixture's store, which then holds a note.
    static func backedUp(_ fixture: UserDataFixture) async throws {
        try fixture.rows.addNote("N1")
        guard case .taken = try await backups(fixture).backUp(at: hour) else { throw CocoaError(.fileNoSuchFile) }
    }

    @Test func theNewestBackupComesWithAManifestOfVersions() async throws {
        let fixture = try await UserDataFixture()
        defer { withExtendedLifetime(fixture) {} }
        let backups = Self.backups(fixture)
        try await fixture.app.test(.router) { client in
            let none = try await client.execute(uri: Self.path, method: .get)
            #expect(none.status == .notFound && problemCode(none) == "BACKUP_NOT_FOUND")

            let browser = Browser(client: client)
            _ = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Backed up"}"#)
            guard case .taken(let first, .none) = try await backups.backUp(at: Self.hour) else {
                Issue.record("the first backup")
                return
            }
            _ = try await browser.send(.post, "/api/v1/me/tags", #"{"name": "Backed up the next day"}"#)
            guard case .taken(let newest, .none) = try await backups.backUp(at: Self.hour.addingTimeInterval(24 * 3_600)) else {
                Issue.record("the second backup")
                return
            }

            let response = try await client.execute(uri: Self.path, method: .get)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/x-tar")
            #expect(response.headers[.contentDisposition] == "attachment; filename=\"frus-light-backup-20261028T030000Z.tar\"")
            #expect(response.headers[.cacheControl] == "no-store")
            let directory = try TemporaryDirectory()
            let archive = directory.url.appendingPathComponent("backup.tar")
            try Data(buffer: response.body).write(to: archive)
            let extracted = directory.url.appendingPathComponent("app.db")
            let manifest = try BackupArchive.extract(archive, to: extracted)
            #expect(manifest.backup.name == newest.name && manifest.backup.kind == .daily)
            #expect(manifest.backup.sha256 == (try UserStoreBackup.sha256(of: newest.url)))
            #expect(manifest.versions.map(\.name) == [newest.name, first.name], "every version, newest first")
            #expect(manifest.versions.allSatisfy { $0.migration == UserStoreMigrations.all.count && $0.copied == nil })
            #expect(manifest.server == .current)
            #expect(try UserStoreBackup.fingerprint(of: extracted, immutable: true) == UserStoreBackup.fingerprint(of: fixture.server.files.userStore),
                    "the store as it stands, backed up and through the API")

            let unknown = try await client.execute(uri: Self.path + "?name=x", method: .get)
            #expect(unknown.status == .badRequest && problemCode(unknown) == "UNKNOWN_PARAMETER")
        }
    }

    @Test func anAdminAloneMayHaveIt() async throws {
        let fixture = try await UserDataFixture(resolver: RolesResolver(roles: [.reader, .curator]))
        defer { withExtendedLifetime(fixture) {} }
        try await Self.backedUp(fixture)
        try await fixture.app.test(.router) { client in
            let refused = try await client.execute(uri: Self.path, method: .get)
            #expect(refused.status == .forbidden && problemCode(refused) == "ROLE_REQUIRED")
            let tags = try await client.execute(uri: "/api/v1/me/tags", method: .get)
            #expect(tags.status == .ok, "a reader keeps their own data")
        }
    }

    /// It holds every user's data, so it is refused as the user's own is.
    @Test func itIsRefusedWhileUserDataIsOffAndToAnotherHost() async throws {
        let off = try await UserDataFixture(userData: false)
        defer { withExtendedLifetime(off) {} }
        try await Self.backedUp(off)
        try await off.app.test(.router) { client in
            let refused = try await client.execute(uri: Self.path, method: .get)
            #expect(refused.status == .forbidden && problemCode(refused) == "USER_DATA_OFF")
        }
        let elsewhere = try await UserDataFixture(publicURL: "https://frus.example.org")
        defer { withExtendedLifetime(elsewhere) {} }
        try await Self.backedUp(elsewhere)
        try await elsewhere.app.test(.router) { client in
            let refused = try await client.execute(uri: Self.path, method: .get)
            #expect(refused.status == .forbidden && problemCode(refused) == "HOST_NOT_ALLOWED")
        }
    }
}
