// An admin's two writes to the accounts and the research (PLAN's S20d), on every store
// `UserStoreKind.available` names: a user's research erased, theirs alone, once what they hold is
// still what the confirmation named; and an account's role or its disabling, refused when it would
// leave no admin who can sign in.

@testable import FRUSLightCore
import FRUSCoreKit
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserErasureTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")

    /// Research of several kinds for `user`: a tag on a document, a note that makes the document
    /// findable, a project they work in, their preferences and a stored key.
    static func research(_ store: RelationalUserStore, _ rows: UserStoreRows, for user: String) throws {
        let tag = try store.createTag(named: "Kept", for: user, at: Self.created)
        try store.setTags([tag.id], of: Self.d1, for: user, at: Self.created)
        _ = try UserNoteTests.make(store, "Wheat for Egypt.", user: user)
        let project = UUID().uuidString
        try rows.addProject(project, user: user)
        try store.setActiveProject(project, for: user)
        try store.setPreferences(["citation_style_raw": .text("chicago")], initial: UserTrailTests.initialPreferences, for: user,
                                 at: Self.created)
        try store.setSecret([1, 2, 3], keyID: "k", named: "zotero", of: .user(user), at: Self.created)
    }

    /// What `user` holds, table by table, but the tables they hold nothing in.
    static func held(_ store: RelationalUserStore, _ user: String) throws -> [String: Int] {
        try store.researchHoldings(of: user).filter { $0.value > 0 }
    }

    /// The erasure removes every row of the user's, their search rows and their active project, and
    /// gives what it removed; another user's research, the account and its sessions are as they were.
    @Test(arguments: UserStoreKind.available)
    func anErasureRemovesOneUsersResearchAlone(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addAccount("erin", displayName: "Erin", role: .reader, passwordHash: "h", at: Self.created)
        try store.addAccount("frank", displayName: "Frank", role: .reader, passwordHash: "h", at: Self.created)
        try Self.research(store, rows, for: "erin")
        try Self.research(store, rows, for: "frank")
        let session = Session(id: SessionToken.id(of: SessionToken.make()), userID: "erin", createdAt: Self.created,
                              lastUsedAt: Self.created, expiresAt: Self.created.addingTimeInterval(3_600))
        try store.startSession(session)
        let holdings = try store.researchHoldings(of: "erin")
        #expect(Set(holdings.keys) == Set(UserStoreSchema.erased.map(\.name) + ["secrets"]))
        let expected = ["tags": 1, "tag_assignments": 1, "notes": 1, "projects": 1, "preferences": 1, "secrets": 1]
        #expect(try Self.held(store, "erin") == expected)
        let frankBefore = try store.researchHoldings(of: "frank")
        let mark = try store.searchMark()

        #expect(try store.eraseResearch(of: "erin", expected: holdings) == holdings)
        #expect(try Self.held(store, "erin").isEmpty)
        #expect(try store.researchCounts(for: "erin", tables: Set(UserStoreSchema.erased.map(\.name))).values.allSatisfy { $0 == 0 },
                "their export carries none of it")
        #expect(try store.researchHoldings(of: "frank") == frankBefore, "another's research is as it was")
        #expect(try rows.searched("SELECT count(*) FROM user_search WHERE user_id = 'erin'") == [[.integer(0)]])
        #expect(try rows.searched("SELECT count(*) FROM user_search WHERE user_id = 'frank'") == [[.integer(1)]])
        #expect(try rows.searched("SELECT count(*) FROM tag_assignments WHERE user_id = 'erin'") == [[.integer(0)]],
                "and what the kit's search reads of it")
        #expect(try rows.searched("SELECT count(*) FROM tag_assignments WHERE user_id = 'frank'") == [[.integer(1)]])
        #expect(try rows.stored("SELECT active_project_id FROM users WHERE user_id = 'erin'") == [[.null]])
        #expect(try store.account("erin")?.passwordHash == "h", "the account is as it was")
        #expect(try store.session(session.id, at: Self.created)?.account.id == "erin", "and its sessions")
        #expect(try store.searchMark() > mark, "no search kept from before it is given again")
    }

    /// An erasure whose confirmation named other holdings than the user's now is refused, with what
    /// they hold now, and removes nothing; one of a user the store does not hold is refused too.
    @Test(arguments: UserStoreKind.available)
    func anErasureIsRefusedOnceTheResearchChanged(_ kind: UserStoreKind) async throws {
        let (store, rows, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addAccount("erin", displayName: "Erin", role: .reader, passwordHash: "h", at: Self.created)
        try Self.research(store, rows, for: "erin")
        let counted = try store.researchHoldings(of: "erin")
        _ = try UserNoteTests.make(store, "Another.", user: "erin")
        let now = try store.researchHoldings(of: "erin")
        #expect(throws: ResearchErasureError.changed(now)) { try store.eraseResearch(of: "erin", expected: counted) }
        #expect(try store.researchHoldings(of: "erin") == now, "nothing removed")
        #expect(throws: AccountStoreError.notFound("nobody")) { try store.researchHoldings(of: "nobody") }
        #expect(throws: AccountStoreError.notFound("nobody")) { try store.eraseResearch(of: "nobody", expected: [:]) }
    }

    /// An admin's change sets a role or disables an account, ending its sessions; one that would leave
    /// no admin who can sign in is refused and changes nothing, whether it demotes or disables the last,
    /// and allowed once another can.
    @Test(arguments: UserStoreKind.available)
    func noChangeLeavesTheInstanceWithoutAnAdminWhoCanSignIn(_ kind: UserStoreKind) async throws {
        let (store, _, test) = try await UserTagTests.open(kind)
        defer { withExtendedLifetime(test) {} }
        try store.addAccount("alice", displayName: "Alice", role: .admin, passwordHash: "h", at: Self.created)
        try store.addAccount("bob", displayName: "Bob", role: .reader, passwordHash: "h", at: Self.created)
        // owner holds the role with no password: no one signs in as owner.
        #expect(throws: AccountStoreError.lastAdmin("alice")) { try store.changeAccount("alice", role: .curator, disabled: nil, at: Self.created) }
        #expect(throws: AccountStoreError.lastAdmin("alice")) { try store.changeAccount("alice", role: nil, disabled: true, at: Self.created) }
        #expect(try store.account("alice")?.role == .admin && store.account("alice")?.disabledAt == nil, "nothing changed")

        let session = Session(id: SessionToken.id(of: SessionToken.make()), userID: "bob", createdAt: Self.created,
                              lastUsedAt: Self.created, expiresAt: Self.created.addingTimeInterval(3_600))
        try store.startSession(session)
        let bob = try store.changeAccount("bob", role: .admin, disabled: nil, at: Self.created)
        #expect(bob.role == .admin && bob.disabledAt == nil)
        #expect(try store.session(session.id, at: Self.created) != nil, "a new role ends no session")
        let demoted = try store.changeAccount("alice", role: .reader, disabled: nil, at: Self.created)
        #expect(demoted.role == .reader, "bob can sign in as an admin now")
        #expect(throws: AccountStoreError.lastAdmin("bob")) { try store.changeAccount("bob", role: nil, disabled: true, at: Self.created) }
        try store.changeAccount("alice", role: .admin, disabled: nil, at: Self.created)
        let disabled = try store.changeAccount("bob", role: nil, disabled: true, at: Self.created)
        #expect(disabled.disabledAt == Self.created)
        #expect(try store.session(session.id, at: Self.created) == nil, "a disabled account's sessions end")
        let enabled = try store.changeAccount("bob", role: .curator, disabled: false, at: Self.created)
        #expect(enabled.disabledAt == nil && enabled.role == .curator)
        #expect(throws: AccountStoreError.notFound("nobody")) { try store.changeAccount("nobody", role: .reader, disabled: nil, at: Self.created) }
    }
}
