// Projects, read only (PLAN's S15d): their ids and names, for a note's Projects and All Notes'
// Project filter. Only an import writes them (S16c), and S17f brings the rest of a project.

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

/// Where a user's projects are kept.
public protocol ProjectStore: Sendable {
    /// The user's projects by name, as the app's `NotesPaneSnapshot` sorts them, with the tag list's
    /// comparison, Foundation's localized standard one; then by id in uppercase.
    func projects(for user: String) throws -> [ProjectRecord]
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
}
