// Tags in the user store (S14c), held to the app's rules: names trimmed and never empty, as its
// picker and editor make them; a deleted tag gone from every note, project and document, as
// `UserTagAdmin.deleteCascading` leaves them; a merged tag's references moved to the tag it joins,
// as `UserTagAdmin.merge` moves them; and one assignment per document and tag, as the picker's Done
// and the Research rail's × write them.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct UserTagTests {
    static let created = Date(timeIntervalSince1970: 1_792_800_000)  // 2026-10-24T00:00:00Z
    static let later = Date(timeIntervalSince1970: 1_792_803_600.25)  // an hour and a quarter second on
    static let laterText = "2026-10-24T01:00:00.250Z"
    static let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
    static let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")

    /// A new store of `kind`, a second connection to it, and what holds them, which a test keeps until
    /// it ends: app.db, or the PostgreSQL store where the run has a database for it. The store tests
    /// that take a kind are the conformance suite (S14d), each run on every store `UserStoreKind.available`
    /// names.
    static func open(_ kind: UserStoreKind) async throws -> (RelationalUserStore, UserStoreRows, TestUserStore) {
        let test = try await TestUserStore.open(kind)
        return (test.store, test.rows, test)
    }

    /// A new app.db, a second connection to its file, and its folder, for what only SQLite shows.
    static func open() async throws -> (SQLiteUserStore, UserStoreRows, TemporaryDirectory) {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent("app.db")
        let store = try await SQLiteUserStore(url: url, backupsDirectory: directory.url.appendingPathComponent("backups"))
        return (store, try UserStoreRows(url), directory)
    }

    @Test(arguments: UserStoreKind.available) func aTagsNameIsTrimmedAndNeverEmpty(_ kind: UserStoreKind) async throws {
        let (store, _, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let tag = try store.createTag(named: "  Primary source\n", for: "owner", at: Self.created)
        #expect(tag.name == "Primary source")
        #expect(UUID(uuidString: tag.id)?.uuidString == tag.id, "an uppercase uuidString, as the Mac's ids are")
        #expect(tag.createdAt == Self.created && tag.lastModified == Self.created)
        #expect(try store.tags(of: "owner") == [tag], "as stored")
        for name in ["", "   ", "\n\t "] {
            #expect(throws: TagStoreError.emptyName) { try store.createTag(named: name, for: "owner", at: Self.created) }
            #expect(throws: TagStoreError.emptyName) { try store.renameTag(tag.id, to: name, for: "owner", at: Self.later) }
        }
        #expect(try store.tags(of: "owner") == [tag], "nothing made or renamed")
        // Two tags may share a name: the app makes no check.
        _ = try store.createTag(named: "Primary source", for: "owner", at: Self.created)
        #expect(try store.tags(of: "owner").count == 2)
    }

    @Test(arguments: UserStoreKind.available) func tagsAreListedByNameAsTheAppSortsThemAndEachUsersAlone(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        try rows.addUser("reader")
        for name in ["revisit", "Berlin", "berlin", "Africa", "Tag 10", "Tag 9", "Élysée"] {
            try store.createTag(named: name, for: "owner", at: Self.created)
        }
        try store.createTag(named: "Theirs", for: "reader", at: Self.created)
        // As the app's query sorts them, by Foundation's localized standard comparison: digits as
        // numbers, an accent after its letter, and a lowercase name before its capital.
        let names = try store.tags(of: "owner").map(\.name)
        #expect(names == ["Africa", "berlin", "Berlin", "Élysée", "revisit", "Tag 9", "Tag 10"], "\(names)")
        #expect(try store.tags(of: "reader").map(\.name) == ["Theirs"])
        let theirs = try #require(try store.tags(of: "reader").first)
        #expect(try store.tag(theirs.id, of: "owner") == nil, "another user's tag is not the owner's")
        #expect(throws: TagStoreError.tagNotFound(theirs.id)) { try store.deleteTag(theirs.id, for: "owner", at: Self.later) }
        #expect(try store.tags(of: "reader").count == 1)
    }

    @Test(arguments: UserStoreKind.available) func aRenameMovesLastModifiedOnlyWhenTheNameChanges(_ kind: UserStoreKind) async throws {
        let (store, _, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let tag = try store.createTag(named: "Revisit", for: "owner", at: Self.created)
        #expect(try store.renameTag(tag.id, to: " Revisit ", for: "owner", at: Self.later) == tag, "the editor's Save leaves it")
        let renamed = try store.renameTag(tag.id.lowercased(), to: "Read again", for: "owner", at: Self.later)
        #expect(renamed.name == "Read again" && renamed.createdAt == Self.created && renamed.lastModified == UserStoreDate.rounded(Self.later))
        #expect(try store.tag(tag.id, of: "owner") == renamed)
        #expect(throws: TagStoreError.tagNotFound("not-an-id")) { try store.renameTag("not-an-id", to: "x", for: "owner", at: Self.later) }
    }

    /// `UserTagAdmin.deleteCascading`: the id leaves every note and project, each changed one
    /// stamped as modified, and every assignment goes.
    @Test(arguments: UserStoreKind.available) func aDeletedTagLeavesNoReferenceBehind(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let doomed = try store.createTag(named: "Doomed", for: "owner", at: Self.created)
        let kept = try store.createTag(named: "Kept", for: "owner", at: Self.created)
        try rows.addNote("N1", tagIds: [kept.id, doomed.id])
        try rows.addNote("N2", tagIds: [kept.id])
        try rows.addNote("N3", tagIds: [doomed.id.lowercased()])
        try rows.addProject("P1", tagIds: [doomed.id, kept.id])
        try rows.addProject("P2", tagIds: [])
        try store.setTags([doomed.id, kept.id], of: Self.d1, for: "owner", at: Self.created)
        try store.setTags([doomed.id], of: Self.d2, for: "owner", at: Self.created.addingTimeInterval(1))

        let change = try store.deleteTag(doomed.id, for: "owner", at: Self.later)
        #expect(change == TagChange(documents: [Self.d1, Self.d2], notes: 2, projects: 1))
        #expect(try rows.note("N1") == [UserStoreRows.json([kept.id]), Self.laterText])
        #expect(try rows.note("N2") == [UserStoreRows.json([kept.id]), "2026-01-01T00:00:00.000Z"], "untouched")
        #expect(try rows.note("N3") == ["[]", Self.laterText], "an id written in lowercase is the same id")
        #expect(try rows.project("P1") == [UserStoreRows.json([kept.id]), Self.laterText])
        #expect(try rows.project("P2") == ["[]", "2026-01-01T00:00:00.000Z"])
        #expect(try store.tags(of: Self.d1, for: "owner") == [kept])
        #expect(try store.tags(of: Self.d2, for: "owner") == [])
        #expect(try rows.assignments().map(\.tagId) == [kept.id], "no assignment of it is left")
        #expect(try store.tags(of: "owner") == [kept])
        #expect(throws: TagStoreError.tagNotFound(doomed.id)) { try store.deleteTag(doomed.id, for: "owner", at: Self.later) }
    }

    /// `UserTagAdmin.merge`: every reference to the source names the target once, and the source
    /// goes. A document that carried both keeps one assignment of the target.
    @Test(arguments: UserStoreKind.available) func aMergedTagsReferencesMoveToTheTagItJoins(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let source = try store.createTag(named: "Cold War", for: "owner", at: Self.created)
        let target = try store.createTag(named: "Cold war", for: "owner", at: Self.created)
        let other = try store.createTag(named: "Berlin", for: "owner", at: Self.created)
        try rows.addNote("N1", tagIds: [source.id, other.id])
        try rows.addNote("N2", tagIds: [target.id, source.id])
        try rows.addNote("N3", tagIds: [other.id])
        try rows.addProject("P1", tagIds: [source.id])
        try store.setTags([source.id], of: Self.d1, for: "owner", at: Self.created)
        try store.setTags([target.id, source.id, other.id], of: Self.d2, for: "owner", at: Self.created.addingTimeInterval(1))
        let targetRowOnD2 = try #require(try rows.assignments().first { $0.documentId == "d2" && $0.tagId == target.id })

        let change = try store.mergeTag(source.id, into: target.id, for: "owner", at: Self.later)
        #expect(change == TagChange(documents: [Self.d1, Self.d2], notes: 2, projects: 1))
        #expect(try rows.note("N1") == [UserStoreRows.json([other.id, target.id]), Self.laterText], "the target after the rest")
        #expect(try rows.note("N2") == [UserStoreRows.json([target.id]), Self.laterText], "once")
        #expect(try rows.note("N3").last == "2026-01-01T00:00:00.000Z")
        #expect(try rows.project("P1") == [UserStoreRows.json([target.id]), Self.laterText])
        #expect(try store.tags(of: Self.d1, for: "owner") == [target])
        #expect(try store.tags(of: Self.d2, for: "owner") == [other, target])
        let d2 = try rows.assignments().filter { $0.documentId == "d2" }
        #expect(d2.filter { $0.tagId == target.id }.map(\.id) == [targetRowOnD2.id], "one per document and tag, the target's own")
        #expect(try store.tags(of: "owner") == [other, target], "the source is gone; the target is as it was")

        #expect(throws: TagStoreError.mergeIntoItself) { try store.mergeTag(target.id, into: target.id, for: "owner", at: Self.later) }
        #expect(throws: TagStoreError.tagNotFound(source.id)) { try store.mergeTag(other.id, into: source.id, for: "owner", at: Self.later) }
    }

    /// The picker's Done: the document carries exactly the tags asked for, one assignment each, and
    /// a tag it kept keeps its assignment.
    @Test(arguments: UserStoreKind.available) func aDocumentsTagsAreSetOneAssignmentEach(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let a = try store.createTag(named: "A", for: "owner", at: Self.created)
        let b = try store.createTag(named: "B", for: "owner", at: Self.created)
        let c = try store.createTag(named: "C", for: "owner", at: Self.created)
        #expect(try store.setTags([b.id, a.id, b.id.lowercased()], of: Self.d1, for: "owner", at: Self.created) == [a, b])
        let first = try rows.assignments()
        #expect(first.count == 2)
        // A duplicate an import left, and an assignment of a tag the user no longer has.
        try rows.addAssignment("DUPLICATE", documentId: "d1", tagId: a.id, createdAt: "2026-10-24T00:30:00.000Z")
        try rows.addAssignment("DANGLING", documentId: "d1", tagId: UUID().uuidString)
        #expect(try store.tags(of: Self.d1, for: "owner") == [a, b], "a dangling assignment names nothing")

        #expect(try store.setTags([a.id, c.id], of: Self.d1, for: "owner", at: Self.later) == [a, c])
        let now = try rows.assignments()
        #expect(now.count == 2)
        #expect(now.first { $0.tagId == a.id }?.id == first.first { $0.tagId == a.id }?.id, "A keeps its oldest assignment")
        #expect(!now.contains { $0.id == "DUPLICATE" || $0.id == "DANGLING" })

        // A tag the user has not: refused, and nothing changed.
        let unknown = UUID().uuidString
        #expect(throws: TagStoreError.tagNotFound(unknown)) { try store.setTags([b.id, unknown], of: Self.d1, for: "owner", at: Self.later) }
        #expect(try store.tags(of: Self.d1, for: "owner") == [a, c])
        #expect(try store.setTags([], of: Self.d1, for: "owner", at: Self.later) == [])
        #expect(try rows.assignments().isEmpty)
    }

    /// The Research rail's ×: one tag off one document, every assignment of it there.
    @Test(arguments: UserStoreKind.available) func aTagIsTakenOffOneDocument(_ kind: UserStoreKind) async throws {
        let (store, rows, directory) = try await Self.open(kind)
        defer { withExtendedLifetime(directory) {} }
        let a = try store.createTag(named: "A", for: "owner", at: Self.created)
        let b = try store.createTag(named: "B", for: "owner", at: Self.created)
        try store.setTags([a.id, b.id], of: Self.d1, for: "owner", at: Self.created)
        try store.setTags([a.id], of: Self.d2, for: "owner", at: Self.created)
        try rows.addAssignment("DUPLICATE", documentId: "d1", tagId: a.id)
        #expect(try store.removeTag(a.id, from: Self.d1, for: "owner") == [b])
        #expect(try store.tags(of: Self.d2, for: "owner") == [a], "the other document keeps it")
        #expect(try store.removeTag(a.id, from: Self.d1, for: "owner") == [b], "again changes nothing")
        #expect(throws: TagStoreError.tagNotFound("x")) { try store.removeTag("x", from: Self.d1, for: "owner") }
    }

    @Test func theAppsRewritesOfAListOfIds() {
        #expect(TagReferences.removing("A", from: ["B", "C"]) == nil)
        #expect(TagReferences.removing("A", from: ["A", "B", "A"]) == ["B"])
        #expect(TagReferences.repointing("A", to: "T", in: ["A", "B"]) == ["B", "T"])
        #expect(TagReferences.repointing("A", to: "T", in: ["T", "A"]) == ["T"])
        #expect(TagReferences.repointing("A", to: "T", in: ["B"]) == nil)
        #expect(TagReferences.decode("not json") == nil && TagReferences.encode(["A", "B"]) == #"["A","B"]"#)
    }
}
