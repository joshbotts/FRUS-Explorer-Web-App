// Suggested Next's leads (PLAN's S23d): what the server computes for a project with the kit's engine and
// aggregator (Sources/FRUSLightAPI/ProjectLeads.swift), kept as the app's `ProjectLeadsService` keeps its
// `ProjectLeadEntry` records. `applyLeads`: the leads still ranked keep their rows, each one not dismissed
// taking its new score, seeds and record; a lead ranked for the first time is added with the time it
// surfaced, which Project Home's NEW reads; and a lead no longer ranked is removed. A dismissed lead is
// kept even then, the web's own, where the app removes it: the server ranks with fewer axes than a Mac
// whose export brought the dismissals, and a dismissal removed would come back as a new lead once the
// ranking reached it again. And `clearVisibleLeads`: a project with nothing to rank from loses its leads
// but its dismissed ones, which would otherwise come back as new once it has. Each is one transaction, written once for both stores,
// and reads the project's leads as they stand when it writes, so that a lead dismissed while the ranking
// ran stays dismissed.

import Foundation

/// One lead the aggregator ranked (`ProjectLeadCandidate`), with what its row shows, when a seed's
/// ranking carried it.
public struct ProjectLeadWrite: Sendable, Equatable {
    public var volumeId: String
    public var documentId: String
    /// Its relatedness summed across the seeds that surfaced it.
    public var aggregateScore: Double
    /// The seeds that surfaced it, `volumeId/documentId`, sorted.
    public var contributingSeedKeys: [String]
    /// What its row shows, from the ranking that carried it; nil for a lead no seed's ranking carried
    /// this time, which keeps what it showed.
    public var record: Record?

    /// A lead's display fields (`CandidateRecord`).
    public struct Record: Sendable, Equatable {
        public var header: String
        public var documentNumber: String?
        public var isEditorialNote: Bool

        public init(header: String, documentNumber: String?, isEditorialNote: Bool) {
            self.header = header
            self.documentNumber = documentNumber
            self.isEditorialNote = isEditorialNote
        }
    }

    public init(volumeId: String, documentId: String, aggregateScore: Double, contributingSeedKeys: [String], record: Record?) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.aggregateScore = aggregateScore
        self.contributingSeedKeys = contributingSeedKeys
        self.record = record
    }

    /// `volumeId/documentId`, the key a lead is matched by.
    public var documentKey: String { "\(volumeId)/\(documentId)" }
}

public protocol ProjectLeadStore: Sendable {
    /// Keeps `leads`, the aggregator's ranking, as the project's (`ProjectLeadsService.applyLeads`): a
    /// lead the project holds keeps its row, and, unless it was dismissed, takes the new score, seeds and,
    /// where given, record; a new one is added, first surfaced and computed `now`; and every lead not in
    /// `leads` is removed but a dismissed one, which stays dismissed, the web's own. False, writing nothing,
    /// when the user has no such project.
    @discardableResult
    func applyProjectLeads(_ leads: [ProjectLeadWrite], toProject project: String, for user: String, at now: Date) throws -> Bool
    /// Removes the project's leads but its dismissed ones (`ProjectLeadsService.clearVisibleLeads`), as the
    /// app does for a project with nothing to rank from. False, writing nothing, when the user has no such
    /// project.
    @discardableResult
    func clearVisibleProjectLeads(ofProject project: String, for user: String) throws -> Bool
}

extension RelationalUserStore: ProjectLeadStore {
    @discardableResult
    public func applyProjectLeads(_ leads: [ProjectLeadWrite], toProject project: String, for user: String,
                                  at now: Date) throws -> Bool {
        let time = SQLiteValue.text(UserStoreDate.text(UserStoreDate.rounded(now)))
        return try writing(outsideSearch: true) { db in
            guard let projectId = try Self.leadsProject(project, of: user, in: db) else { return false }
            // The project's leads in the order the store took them: of two for one document, the first is
            // the one kept up to date, as the app's `uniquingKeysWith: { first, _ in first }` keeps it.
            let existing = try db.query("""
                SELECT id, volume_id, document_id, dismissed FROM project_leads
                    WHERE user_id = ? AND upper(project_id) = ? ORDER BY rowid
                """, [.text(user), .text(UserSearchText.uuidString(projectId))])
                .map { (id: $0[0].text ?? "", key: "\($0[1].text ?? "")/\($0[2].text ?? "")", dismissed: ($0[3].integer ?? 0) != 0) }
            var held: [String: (id: String, dismissed: Bool)] = [:]
            for lead in existing where held[lead.key] == nil { held[lead.key] = (lead.id, lead.dismissed) }
            for lead in leads {
                if let entry = held[lead.documentKey] {
                    if entry.dismissed {
                        // A dismissed lead keeps what it showed, and stays hidden.
                        _ = try db.query("UPDATE project_leads SET last_computed_at = ? WHERE user_id = ? AND id = ?",
                                         [time, .text(user), .text(entry.id)])
                    } else if let record = lead.record {
                        _ = try db.query("""
                            UPDATE project_leads SET aggregate_score = ?, contributing_seed_keys = ?, header = ?,
                                document_number = ?, is_editorial_note = ?, last_computed_at = ?
                                WHERE user_id = ? AND id = ?
                            """, [.real(lead.aggregateScore), .text(TagReferences.encode(lead.contributingSeedKeys)),
                                  .text(record.header), record.documentNumber.map(SQLiteValue.text) ?? .null,
                                  .integer(record.isEditorialNote ? 1 : 0), time, .text(user), .text(entry.id)])
                    } else {
                        _ = try db.query("""
                            UPDATE project_leads SET aggregate_score = ?, contributing_seed_keys = ?, last_computed_at = ?
                                WHERE user_id = ? AND id = ?
                            """, [.real(lead.aggregateScore), .text(TagReferences.encode(lead.contributingSeedKeys)), time,
                                  .text(user), .text(entry.id)])
                    }
                } else {
                    _ = try db.query("""
                        INSERT INTO project_leads (user_id, id, project_id, volume_id, document_id, aggregate_score,
                            contributing_seed_keys, header, document_number, is_editorial_note, first_surfaced_at,
                            last_computed_at, dismissed)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                        """, [.text(user), .text(UUID().uuidString), .text(projectId), .text(lead.volumeId),
                              .text(lead.documentId), .real(lead.aggregateScore),
                              .text(TagReferences.encode(lead.contributingSeedKeys)), .text(lead.record?.header ?? ""),
                              lead.record?.documentNumber.map(SQLiteValue.text) ?? .null,
                              .integer(lead.record?.isEditorialNote == true ? 1 : 0), time, time])
                    // A second lead for one document in a ranking, which the aggregator never gives, is kept once.
                    held[lead.documentKey] = ("", false)
                }
            }
            let ranked = Set(leads.map(\.documentKey))
            for lead in existing where !ranked.contains(lead.key) && !lead.dismissed {
                _ = try db.query("DELETE FROM project_leads WHERE user_id = ? AND id = ?", [.text(user), .text(lead.id)])
            }
            return true
        }
    }

    @discardableResult
    public func clearVisibleProjectLeads(ofProject project: String, for user: String) throws -> Bool {
        try writing(outsideSearch: true) { db in
            guard let projectId = try Self.leadsProject(project, of: user, in: db) else { return false }
            _ = try db.query("DELETE FROM project_leads WHERE user_id = ? AND upper(project_id) = ? AND dismissed = 0",
                             [.text(user), .text(UserSearchText.uuidString(projectId))])
            return true
        }
    }

    /// The project's id as the store holds it, or nil for a project the user does not have.
    private static func leadsProject(_ id: String, of user: String, in db: UserStoreTransaction) throws -> String? {
        try db.query("SELECT id FROM projects WHERE user_id = ? AND upper(id) = ? ORDER BY id LIMIT 1",
                     [.text(user), .text(UserSearchText.uuidString(id))]).first?[0].text
    }
}
