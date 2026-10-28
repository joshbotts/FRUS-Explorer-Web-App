// Projects (PLAN's S15d and S17f): their ids and names, for a note's Projects and All Notes' Project
// filter; the project each user works in, the web's own, which the Mac keeps on each device; and the
// two changes `ProjectAdminService` makes across the store, a delete and a merge. A project's own
// rows, its leads and its trail are rows of their tables (`ResearchRowStore`), which the API writes as
// the import writes a Mac's.

import Foundation

/// One of a user's projects, as far as a note names it.
public struct ProjectRecord: Sendable, Equatable {
    /// The Mac's id.
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Why the store refused a change to a project.
public enum ProjectStoreError: Error, Equatable, CustomStringConvertible {
    /// The user has no project with this id.
    case projectNotFound(String)
    /// A project was to be merged into itself.
    case mergeIntoItself

    public var description: String {
        switch self {
        case .projectNotFound(let id): "no project with the id \(id)"
        case .mergeIntoItself: "a project cannot be merged into itself"
        }
    }
}

/// Where a user's projects are kept.
public protocol ProjectStore: Sendable {
    /// The user's projects by name, as the app's `NotesPaneSnapshot` sorts them, with the tag list's
    /// comparison, Foundation's localized standard one; then by id in uppercase.
    func projects(for user: String) throws -> [ProjectRecord]
    /// The id of the project the user works in, as their projects hold it, or nil for the Mac's
    /// Global Context: none chosen, or one they no longer hold, as `ProjectAdminService` returns a Mac
    /// to Global Context when its active project is gone.
    func activeProjectId(of user: String) throws -> String?
    /// Makes the project with this id, in any letter case, the one the user works in, or none. Throws
    /// `ProjectStoreError.projectNotFound` for an id the user holds no project for, changing nothing.
    func setActiveProject(_ id: String?, for user: String) throws
    /// Deletes the project, as `ProjectAdminService.delete` does: the user's active project no longer
    /// if it was, and every note, collection, summary, plan, trail row and lead that names it keeping
    /// the id. Answers whether there was one.
    @discardableResult
    func deleteProject(_ id: String, for user: String) throws -> Bool
    /// Merges the project into `target`, as `ProjectAdminService.merge` does: the notes and collections
    /// filed under it are filed under `target` instead, after the rest, unless they are already; an
    /// Archives Visit's projects name `target` where they named it; the summaries and the three trails
    /// it is stamped on are `target`'s; the user works in `target` if they worked in it; and it is
    /// deleted. A lead keeps its project, as the app's merge leaves the leads. A note, collection,
    /// plan or summary it changes is stamped as changed at `now`, as the app's save stamps it.
    func mergeProject(_ id: String, into target: String, for user: String, at now: Date) throws
}

extension RelationalUserStore: ProjectStore {
    public func projects(for user: String) throws -> [ProjectRecord] {
        try reading { db in
            try db.query("SELECT id, name FROM projects WHERE user_id = ?", [.text(user)])
                .map { ProjectRecord(id: $0[0].text ?? "", name: $0[1].text ?? "") }
                .sorted { a, b in
                    switch a.name.localizedStandardCompare(b.name) {
                    case .orderedAscending: true
                    case .orderedDescending: false
                    case .orderedSame: UserSearchText.uuidString(a.id) < UserSearchText.uuidString(b.id)
                    }
                }
        }
    }

    public func activeProjectId(of user: String) throws -> String? {
        try reading { db in
            try db.query(
                """
                SELECT p.id FROM users u JOIN projects p ON p.user_id = u.user_id AND upper(p.id) = upper(u.active_project_id)
                    WHERE u.user_id = ? ORDER BY p.id LIMIT 1
                """, [.text(user)]).first?[0].text
        }
    }

    public func setActiveProject(_ id: String?, for user: String) throws {
        try writing(outsideSearch: true) { db in
            var held: SQLiteValue = .null
            if let id {
                guard let project = try Self.project(id, of: user, in: db) else { throw ProjectStoreError.projectNotFound(id) }
                held = .text(project)
            }
            _ = try db.query("UPDATE users SET active_project_id = ? WHERE user_id = ?", [held, .text(user)])
        }
    }

    @discardableResult
    public func deleteProject(_ id: String, for user: String) throws -> Bool {
        try writing(outsideSearch: true) { db in
            guard let project = try Self.project(id, of: user, in: db) else { return false }
            _ = try db.query("UPDATE users SET active_project_id = NULL WHERE user_id = ? AND upper(active_project_id) = ?",
                             [.text(user), .text(project.uppercased())])
            _ = try db.query("DELETE FROM projects WHERE user_id = ? AND id = ?", [.text(user), .text(project)])
            return true
        }
    }

    public func mergeProject(_ id: String, into target: String, for user: String, at now: Date) throws {
        let time = SQLiteValue.text(UserStoreDate.text(UserStoreDate.rounded(now)))
        try writing(outsideSearch: true) { db in
            guard let source = try Self.project(id, of: user, in: db) else { throw ProjectStoreError.projectNotFound(id) }
            guard let survivor = try Self.project(target, of: user, in: db) else { throw ProjectStoreError.projectNotFound(target) }
            // The ids as an id list names them, so that one written in another case is matched.
            let (from, to) = (TagReferences.normalized(source) ?? source, TagReferences.normalized(survivor) ?? survivor)
            guard from != to else { throw ProjectStoreError.mergeIntoItself }
            for table in ["notes", "collections"] {
                _ = try Self.rewriteReferences(in: table, column: "project_ids", naming: from, for: user, at: now, db) {
                    TagReferences.repointing(from, to: to, in: $0)
                }
            }
            // A plan's first project is its own, so its list is re-pointed where it stands.
            _ = try Self.rewriteReferences(in: "visit_plans", column: "project_ids", naming: from, for: user, at: now, db) {
                TagReferences.replacing(from, with: to, in: $0)
            }
            _ = try db.query("UPDATE summaries SET project_id = ?, last_modified = ? WHERE user_id = ? AND upper(project_id) = ?",
                             [.text(to), time, .text(user), .text(from)])
            for table in ["trail_reading", "trail_search", "trail_export"] {
                _ = try db.query("UPDATE \(table) SET project_id = ? WHERE user_id = ? AND upper(project_id) = ?",
                                 [.text(to), .text(user), .text(from)])
            }
            _ = try db.query("UPDATE users SET active_project_id = ? WHERE user_id = ? AND upper(active_project_id) = ?",
                             [.text(survivor), .text(user), .text(from)])
            _ = try db.query("DELETE FROM projects WHERE user_id = ? AND id = ?", [.text(user), .text(source)])
        }
    }

    /// The id of the user's project whose id is `id` in any letter case, as it is held, the first in
    /// the order of the ids where two differ only in case.
    private static func project(_ id: String, of user: String, in db: UserStoreTransaction) throws -> String? {
        try db.query("SELECT id FROM projects WHERE user_id = ? AND upper(id) = ? ORDER BY id LIMIT 1",
                     [.text(user), .text(UserSearchText.uuidString(id))]).first?[0].text
    }
}
