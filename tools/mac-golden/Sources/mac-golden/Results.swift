// results: check 3's counts and first 50 results, from the app's SearchService over a copy of the
// owner's three-volume export.

import Foundation
import ParityFormat
import SQLite3
@testable import FRUSExplorer

func resultsGolden(repo: Repository, export: URL, queries queriesURL: URL, out: URL) async throws {
    let queries = try loadQueries(queriesURL)
    // The export was indexed from the fixtures, so the file records them, as the index summary does.
    let fixtures = try verifyFixtures(repo)
    let scratch = try Scratch()
    defer { scratch.remove() }
    let copy = try scratch.copy(database: export)
    let stamp = try checkExport(copy, appBuild: repo.appBuild())
    let service = try scratch.searchService(database: copy)

    // ParityFormat's loop, which the harness runs over FRUSCoreKit's SearchService on Linux too.
    var records: [ResultRecord] = []
    for query in queries {
        let parameters = try searchParameters(query)
        records.append(await ResultsLoop.record(
            id: query.id,
            count: { try await service.searchCount(parameters: parameters) },
            page: { limit, offset in
                try await service.search(parameters: parameters, limit: limit, offset: offset)
                    .map { SearchHit(volume: $0.volumeId, document: $0.documentId, score: $0.bm25Score) }
            }))
    }
    // The query list's records, the fixtures, and the export's stamp, which names the export and
    // must match the index summary's (GoldenValidation.requiredInputs).
    var inputs = repo.records(queriesURL, queries).merging(fixtures) { $1 }
    for (key, value) in stamp { inputs["research_provenance.\(key)"] = value }
    let golden = ResultsGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden results", inputs: inputs),
        queries: records
    )
    try GoldenJSON.write(golden, to: out)
    let errors = records.filter { $0.error != nil }.count
    let tails = records.filter { !$0.tieTail.isEmpty }.count
    note("results: \(records.count) queries, \(errors) refused, \(tails) with ties past the 50th, in \(repo.relativePath(out))")
}

/// Opens the copy read-only and refuses anything but an export of exactly the fixture volumes,
/// without the owner's writing, from the pin's build at its index version. Returns the export's
/// `research_provenance`.
func checkExport(_ url: URL, appBuild: Int?) throws -> [String: String] {
    var handle: OpaquePointer?
    guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = handle else {
        sqlite3_close(handle)
        throw ToolError("cannot open the export's copy")
    }
    defer { sqlite3_close(db) }
    func rows(_ sql: String) throws -> [[String?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw ToolError("the export is not a FRUS Explorer research export: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(statement) }
        var rows: [[String?]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append((0..<sqlite3_column_count(statement)).map { text(statement, $0) })
        }
        return rows
    }
    func column(_ sql: String) throws -> [String] { try rows(sql).map { $0.first.flatMap { $0 } ?? "" } }

    let version = try column("PRAGMA user_version")
    guard version == ["4"] else { throw ToolError("the export's user_version is \(version.first ?? "none"), not 4") }
    let volumes = try column("SELECT DISTINCT volume_id FROM document_cache ORDER BY volume_id")
    guard volumes == ParityFixtures.volumes.sorted() else {
        throw ToolError("the export holds \(volumes.count) volumes; it must hold exactly \(ParityFixtures.volumes.sorted())")
    }
    // As frus-parity's summary reads it, so that the two golden files record the same stamp: a
    // NULL value is empty, and a row without a key is left out.
    var stamp: [String: String] = [:]
    for row in try rows("SELECT key, value FROM research_provenance") {
        if let key = row[0] { stamp[key] = row[1] ?? "" }
    }
    guard stamp["my_writing_included"] == "0" else {
        throw ToolError("the export includes the owner's writing, or has no stamp: export with notes off")
    }
    let current = String(IndexingPipeline.currentDateIndexVersion)
    for key in ["installed_index_version", "current_index_version"] {
        let value = stamp[key]
        guard value == current else {
            throw ToolError("the export's \(key) is \(value ?? "missing"); this pin's is \(current): export from the pinned build")
        }
    }
    let build = appBuild.map(String.init) ?? "none"
    guard stamp["app_build"] == build else {
        throw ToolError("the export's app_build is \(stamp["app_build"] ?? "missing"); this pin's is \(build): export from the pinned build")
    }
    return stamp
}

/// A column's value as text, as frus-parity's summary reads it: text as its bytes, a number as
/// Swift prints it, and NULL or a blob as nil.
private func text(_ statement: OpaquePointer, _ index: Int32) -> String? {
    switch sqlite3_column_type(statement, index) {
    case SQLITE_INTEGER: return String(sqlite3_column_int64(statement, index))
    case SQLITE_FLOAT: return String(sqlite3_column_double(statement, index))
    case SQLITE_TEXT:
        guard let bytes = sqlite3_column_text(statement, index) else { return "" }
        let count = Int(sqlite3_column_bytes(statement, index))
        return String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
    default: return nil
    }
}
