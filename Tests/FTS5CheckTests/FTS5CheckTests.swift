// The corpus index's full-text table works on this platform's SQLite, built with the app's own DDL.

import CSQLite
import FTS5Store
import Testing

/// An in-memory database holding `frus_documents` exactly as `FTS5Schema.frusDocuments` builds it.
/// It is an external-content table, so its content table, `document_cache`, exists too, with the
/// columns the FTS table reads from it.
private final class CorpusIndex {
    private(set) var db: OpaquePointer?

    init() throws {
        try check(sqlite3_open(":memory:", &db))
        try exec("""
            CREATE TABLE document_cache (
                rowid INTEGER PRIMARY KEY,
                document_id TEXT, volume_id TEXT, document_number TEXT,
                header TEXT, dateline TEXT, source_note TEXT, body_text TEXT,
                subject_tag_ids TEXT, user_tag_ids TEXT, is_editorial_note INTEGER
            )
            """)
        try exec(FTS5Schema.frusDocuments.createTableSQL(ifNotExists: false))
    }

    deinit { sqlite3_close(db) }

    /// Inserts a document into the content table and the index, as the external-content triggers would.
    func insert(rowid: Int, documentId: String, body: String) throws {
        for table in ["document_cache", "frus_documents"] {
            var stmt: OpaquePointer?
            try check(sqlite3_prepare_v2(
                db, "INSERT INTO \(table) (rowid, document_id, volume_id, body_text) VALUES (?, ?, 'frus1961-63v06', ?)",
                -1, &stmt, nil))
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(rowid))
            sqlite3_bind_text(stmt, 2, documentId, -1, transient)
            sqlite3_bind_text(stmt, 3, body, -1, transient)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw SQLiteError(message: lastError) }
        }
    }

    /// The document ids that match an FTS5 query, best first.
    func match(_ query: String) throws -> [String] {
        var stmt: OpaquePointer?
        try check(sqlite3_prepare_v2(
            db, "SELECT document_id FROM frus_documents WHERE frus_documents MATCH ? ORDER BY rank",
            -1, &stmt, nil))
        defer { sqlite3_finalize(stmt) }
        try check(sqlite3_bind_text(stmt, 1, query, -1, transient))
        var ids: [String] = []
        // A malformed query fails at step time, not at prepare, so check how stepping ends.
        var code = sqlite3_step(stmt)
        while code == SQLITE_ROW {
            ids.append(sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "")
            code = sqlite3_step(stmt)
        }
        guard code == SQLITE_DONE else { throw SQLiteError(message: lastError) }
        return ids
    }

    private func exec(_ sql: String) throws {
        try check(sqlite3_exec(db, sql, nil, nil, nil))
    }

    private func check(_ code: Int32) throws {
        guard code == SQLITE_OK else { throw SQLiteError(message: lastError) }
    }

    private var lastError: String { db.map { String(cString: sqlite3_errmsg($0)) } ?? "no database" }
}

private struct SQLiteError: Error { let message: String }

/// SQLITE_TRANSIENT: SQLite copies the bound string before the call returns.
private var transient: sqlite3_destructor_type { unsafeBitCast(-1, to: sqlite3_destructor_type.self) }

@Test func frusDocumentsUsesPorterUnicode61() {
    #expect(FTS5Schema.frusDocuments.createTableSQL(ifNotExists: false).contains("tokenize = 'porter unicode61'"))
}

@Test func stemmedPrefixMatchesInsideNearGroup() throws {
    let index = try CorpusIndex()
    try index.insert(rowid: 1, documentId: "frus1961-63v06d1",
                     body: "The ambassador was negotiating treaties with the minister.")
    try index.insert(rowid: 2, documentId: "frus1961-63v06d2",
                     body: "Negotiating began in May, and after many long weeks of talks the treaties came.")

    // The porter tokenizer stores "negotiating" as "negoti" and "treaties" as "treati". It stems a
    // prefix term as if it were a whole word: "negotiating*" becomes "negoti*", while "negotiat*"
    // stays "negotiat*", which no stored term begins with.
    #expect(try index.match("NEAR(negoti* treaty, 2)") == ["frus1961-63v06d1"])
    #expect(try index.match("NEAR(negotiating* treaty, 2)") == ["frus1961-63v06d1"])
    #expect(try index.match("NEAR(negotiat* treaty, 2)").isEmpty)
    // Both documents hold both words; only the first has them within the NEAR distance.
    #expect(try index.match("negoti* treaty").count == 2)
}

@Test func malformedQueryThrows() throws {
    let index = try CorpusIndex()
    #expect(throws: SQLiteError.self) { try index.match("NEAR(treaty") }
}
