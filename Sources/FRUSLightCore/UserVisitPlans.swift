// A user's Archives Visit plans (PLAN's S30c): the rows of migration 2's `visit_plans`, `visit_documents` and
// `visit_targets`, a plan's seeds and stored targets held to it by the plan's id, as the Mac keeps their `planId`. The
// store keeps the rows, their identity and their consistency: a plan is read with its seeds and targets, made with them,
// changed with them in one write, which reads them, asks the API what they become and writes only what differs, so a
// rule that adds many seeds, clears a tier's members or mints a target's row changes all or none; and deleted with them,
// the kit's cascade (`ArchiveVisitPlanWrites.deletion(of:)`), every row that names the plan. What the columns hold is the
// API's, which writes a row as the import writes a Mac's record (`MacImport.plan`, `.seed`, `.target`) and reads one as
// the export does (`ResearchExport.plan`, `.visitDocument`, `.visitTarget`), and applies the kit's write rules
// (`ArchiveVisitPlanWrites`). No plan's write changes `user_search` or the tag assignments, so none moves the search
// mark.

import Foundation

/// A plan's rows: its own, and its seeds' and stored targets' in the order the store took them.
public struct VisitPlanRows: Sendable, Equatable {
    public var plan: ExportRow
    public var documents: [ExportRow]
    public var targets: [ExportRow]

    public init(plan: ExportRow, documents: [ExportRow], targets: [ExportRow]) {
        self.plan = plan
        self.documents = documents
        self.targets = targets
    }
}

/// What a write makes of a plan's rows, each given whole, by its values with `id` among them, as `ImportRow` gives one.
public struct VisitPlanChange: Sendable {
    /// The plan's columns. A change keeps the id it holds; a new plan takes this one.
    public var plan: [String: SQLiteValue]
    /// Its seeds. One the store holds keeps its row, and only its columns that differ are written; one whose id the user
    /// holds no seed under is added, naming the plan; one held and left out is deleted.
    public var documents: [[String: SQLiteValue]]
    /// Its stored targets, as its seeds are.
    public var targets: [[String: SQLiteValue]]

    public init(plan: [String: SQLiteValue], documents: [[String: SQLiteValue]], targets: [[String: SQLiteValue]]) {
        self.plan = plan
        self.documents = documents
        self.targets = targets
    }
}

/// Where a user's Archives Visit plans are kept, each the user's alone. A plan's id, a seed's and a target's, is the
/// Mac's, an uppercase `uuidString`, and is found in any letter case.
public protocol VisitPlanStore: Sendable {
    /// The user's plans and every seed and target of theirs, each table's rows in the order the store took them; a seed
    /// or target whose plan they hold none of among them, as an import may leave one.
    func visitPlanRows(of user: String) throws -> (plans: [ExportRow], documents: [ExportRow], targets: [ExportRow])
    /// One of the user's plans with its seeds and targets, or nil when they hold none with this id.
    func visitPlanRows(_ id: String, of user: String) throws -> VisitPlanRows?
    /// Adds a plan with its seeds and targets in one write, and answers its rows. Throws `ResearchRowStoreError`, writing
    /// nothing, for a column a table lacks or an id that is missing or the user's already.
    @discardableResult
    func addVisitPlan(_ change: VisitPlanChange, for user: String) throws -> VisitPlanRows
    /// Reads the user's plan with this id and its seeds and targets inside one write, asks `change` what they become,
    /// nil for nothing, writes what differs, and answers the rows as they then stand; nil when the user has no such plan,
    /// writing nothing. What `change` throws rolls the write back.
    @discardableResult
    func changeVisitPlan(_ id: String, for user: String,
                         _ change: @Sendable (VisitPlanRows) throws -> VisitPlanChange?) throws -> VisitPlanRows?
    /// Deletes the user's plan with this id with every seed and target that names it, the kit's cascade
    /// (`ArchiveVisitPlanWrites.deletion(of:)`); whether there was one.
    @discardableResult
    func deleteVisitPlan(_ id: String, for user: String) throws -> Bool
}

extension RelationalUserStore: VisitPlanStore {
    static let visitPlansTable = UserStoreSchema.tables.first { $0.name == "visit_plans" }!
    static let visitDocumentsTable = UserStoreSchema.tables.first { $0.name == "visit_documents" }!
    static let visitTargetsTable = UserStoreSchema.tables.first { $0.name == "visit_targets" }!

    public func visitPlanRows(of user: String) throws -> (plans: [ExportRow], documents: [ExportRow], targets: [ExportRow]) {
        try reading { db in
            (try Self.rows(of: Self.visitPlansTable, where: "user_id = ?", [.text(user)], in: db),
             try Self.rows(of: Self.visitDocumentsTable, where: "user_id = ?", [.text(user)], in: db),
             try Self.rows(of: Self.visitTargetsTable, where: "user_id = ?", [.text(user)], in: db))
        }
    }

    public func visitPlanRows(_ id: String, of user: String) throws -> VisitPlanRows? {
        try reading { db in try Self.visitPlanRows(id, of: user, in: db) }
    }

    @discardableResult
    public func addVisitPlan(_ change: VisitPlanChange, for user: String) throws -> VisitPlanRows {
        try Self.check(change)
        guard let id = change.plan["id"]?.text else { throw ResearchRowStoreError.invalidId(table: Self.visitPlansTable.name, id: nil) }
        return try writing(outsideSearch: true) { db in
            guard try Self.row(Self.visitPlansTable, id: id, of: user, in: db) == nil else {
                throw ResearchRowStoreError.invalidId(table: Self.visitPlansTable.name, id: id)
            }
            try Self.insert(change.plan, into: Self.visitPlansTable, for: user, in: db)
            let planId = SQLiteValue.text(id)
            try Self.insertChildren(change.documents, into: Self.visitDocumentsTable, of: planId, for: user, in: db)
            try Self.insertChildren(change.targets, into: Self.visitTargetsTable, of: planId, for: user, in: db)
            guard let rows = try Self.visitPlanRows(id, of: user, in: db) else {
                throw ResearchRowStoreError.invalidId(table: Self.visitPlansTable.name, id: id)
            }
            return rows
        }
    }

    @discardableResult
    public func changeVisitPlan(_ id: String, for user: String,
                                _ change: @Sendable (VisitPlanRows) throws -> VisitPlanChange?) throws -> VisitPlanRows? {
        try writing(outsideSearch: true) { db in
            guard let held = try Self.visitPlanRows(id, of: user, in: db) else { return nil }
            guard let made = try change(held) else { return held }
            try Self.check(made)
            let planId = held.plan.values["id"] ?? .null
            let changed = Self.differing(made.plan, from: held.plan.values)
            if !changed.isEmpty, let key = planId.text {
                _ = try Self.update(Self.visitPlansTable, id: key, changed, of: user, in: db)
            }
            try Self.reconcile(held.documents, with: made.documents, in: Self.visitDocumentsTable, of: planId, for: user, db: db)
            try Self.reconcile(held.targets, with: made.targets, in: Self.visitTargetsTable, of: planId, for: user, db: db)
            return try Self.visitPlanRows(id, of: user, in: db)
        }
    }

    @discardableResult
    public func deleteVisitPlan(_ id: String, for user: String) throws -> Bool {
        try writing(outsideSearch: true) { db in
            guard let held = try Self.visitPlanRows(id, of: user, in: db) else { return false }
            let planId = held.plan.values["id"] ?? .null
            // Every row that names the plan, in any letter case: the seeds and targets the kit's cascade lists.
            for table in [Self.visitDocumentsTable, Self.visitTargetsTable] {
                _ = try db.query("DELETE FROM \(table.name) WHERE user_id = ? AND upper(plan_id) = ?",
                                 [.text(user), .text(UserSearchText.uuidString(planId.text ?? id))])
            }
            _ = try db.query("DELETE FROM visit_plans WHERE user_id = ? AND id = ?", [.text(user), planId])
            return true
        }
    }

    // MARK: Within a transaction

    /// The user's plan with this id in any letter case, and the seeds and targets that name it, in any letter case, each
    /// in the store's order.
    static func visitPlanRows(_ id: String, of user: String, in db: UserStoreTransaction) throws -> VisitPlanRows? {
        guard let plan = try row(visitPlansTable, id: id, of: user, in: db) else { return nil }
        let key = UserSearchText.uuidString(plan.values["id"]?.text ?? id)
        let documents = try rows(of: visitDocumentsTable, where: "user_id = ? AND upper(plan_id) = ?", [.text(user), .text(key)], in: db)
        let targets = try rows(of: visitTargetsTable, where: "user_id = ? AND upper(plan_id) = ?", [.text(user), .text(key)], in: db)
        return VisitPlanRows(plan: plan, documents: documents, targets: targets)
    }

    /// Refuses a change whose rows name a column their table lacks.
    static func check(_ change: VisitPlanChange) throws {
        try check(change.plan, in: visitPlansTable)
        for document in change.documents { try check(document, in: visitDocumentsTable) }
        for target in change.targets { try check(target, in: visitTargetsTable) }
    }

    /// Adds children of the plan whose stored id is `planId`, each naming it, each refused, and the write with it, under
    /// an id one of the user's rows of `table` holds. The user's ids are read once, in uppercase.
    static func insertChildren(_ children: [[String: SQLiteValue]], into table: UserStoreSchema.Table, of planId: SQLiteValue,
                               for user: String, in db: UserStoreTransaction) throws {
        guard !children.isEmpty else { return }
        var held = try heldIds(of: table.name, for: user, in: db)
        for child in children {
            guard let id = child["id"]?.text else { throw ResearchRowStoreError.invalidId(table: table.name, id: nil) }
            guard held.insert(UserSearchText.uuidString(id)).inserted else {
                throw ResearchRowStoreError.invalidId(table: table.name, id: id)
            }
            var values = child
            values["plan_id"] = planId
            try insert(values, into: table, for: user, in: db)
        }
    }

    /// Writes `made`, what a change makes of the plan's children of `table`, over `held`, those it read: a held child,
    /// its id in any letter case, keeps its row and only its columns that differ are written, never the plan it names;
    /// one held and left out is deleted; and one the plan does not hold is added, naming it.
    static func reconcile(_ held: [ExportRow], with made: [[String: SQLiteValue]], in table: UserStoreSchema.Table,
                          of planId: SQLiteValue, for user: String, db: UserStoreTransaction) throws {
        var heldById: [String: ExportRow] = [:]
        for row in held {
            if let id = row.values["id"]?.text { heldById[UserSearchText.uuidString(id)] = row }
        }
        var kept = Set<String>()
        var added: [[String: SQLiteValue]] = []
        for child in made {
            guard let id = child["id"]?.text else { throw ResearchRowStoreError.invalidId(table: table.name, id: nil) }
            let key = UserSearchText.uuidString(id)
            guard let existing = heldById[key] else {
                added.append(child)
                continue
            }
            kept.insert(key)
            var differing = differing(child, from: existing.values)
            differing["plan_id"] = nil
            if !differing.isEmpty, let stored = existing.values["id"]?.text {
                _ = try update(table, id: stored, differing, of: user, in: db)
            }
        }
        for (key, row) in heldById where !kept.contains(key) {
            _ = try db.query("DELETE FROM \(table.name) WHERE user_id = ? AND id = ?", [.text(user), row.values["id"] ?? .text(key)])
        }
        try insertChildren(added, into: table, of: planId, for: user, in: db)
    }
}
