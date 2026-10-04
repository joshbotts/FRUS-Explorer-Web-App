// results: check 3's counts and first 50 results, from the app's SearchService over a copy of the
// owner's three-volume export.

import Foundation
import ParityFormat
import SQLite3
@testable import FRUSExplorer

func resultsGolden(repo: Repository, export: URL, queries queriesURL: URL, out: URL) async throws {
    let queries = try loadQueries(queriesURL)
    let scratch = try Scratch()
    defer { scratch.remove() }
    let copy = try scratch.copy(database: export)
    try checkExport(copy)
    let service = try scratch.searchService(database: copy)

    var records: [ResultRecord] = []
    for query in queries {
        let parameters = try searchParameters(query)
        do {
            let count = try await service.searchCount(parameters: parameters)
            let top = try await service.search(parameters: parameters, limit: 50, offset: 0)
            // The results after the 50th that tie with it, page by page until the score changes.
            var tail: [SearchResult] = []
            if top.count == 50, let last = top.last?.bm25Score.bitPattern {
                var offset = 50
                paging: while true {
                    let page = try await service.search(parameters: parameters, limit: 50, offset: offset)
                    for result in page {
                        guard result.bm25Score.bitPattern == last else { break paging }
                        tail.append(result)
                    }
                    if page.count < 50 { break }
                    offset += 50
                }
            }
            records.append(ResultRecord(id: query.id, count: count, top: top.map(key), scoreBits: top.map(scoreBits),
                                        tieTail: tail.map(key), tieTailScoreBits: tail.map(scoreBits)))
        } catch {
            records.append(ResultRecord(id: query.id, count: nil, top: [], scoreBits: [],
                                        error: String(describing: error)))
        }
    }
    let golden = ResultsGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden results", inputs: [queriesURL]),
        queries: records
    )
    try GoldenJSON.write(golden, to: out)
    let errors = records.filter { $0.error != nil }.count
    let tails = records.filter { !$0.tieTail.isEmpty }.count
    note("results: \(records.count) queries, \(errors) refused, \(tails) with ties past the 50th, in \(repo.relativePath(out))")
}

private func key(_ result: SearchResult) -> String { "\(result.volumeId)/\(result.documentId)" }

/// A score's IEEE-754 bit pattern, in lowercase hex without leading zeros.
private func scoreBits(_ result: SearchResult) -> String { String(result.bm25Score.bitPattern, radix: 16) }

/// Opens the copy read-only and refuses anything but an export of exactly the fixture volumes,
/// without the owner's writing, from a build at this pin's index version.
func checkExport(_ url: URL) throws {
    var handle: OpaquePointer?
    guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db = handle else {
        sqlite3_close(handle)
        throw ToolError("cannot open the export's copy")
    }
    defer { sqlite3_close(db) }
    func column(_ sql: String) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ToolError("the export is not a FRUS Explorer research export: \(String(cString: sqlite3_errmsg(db)))")
        }
        defer { sqlite3_finalize(statement) }
        var values: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            values.append(sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "")
        }
        return values
    }
    let version = try column("PRAGMA user_version")
    guard version == ["4"] else { throw ToolError("the export's user_version is \(version.first ?? "none"), not 4") }
    let volumes = try column("SELECT DISTINCT volume_id FROM document_cache ORDER BY volume_id")
    guard volumes == ParityFixtures.volumes.sorted() else {
        throw ToolError("the export holds \(volumes.count) volumes; it must hold exactly \(ParityFixtures.volumes.sorted())")
    }
    func stamp(_ key: String) throws -> String? {
        try column("SELECT value FROM research_provenance WHERE key = '\(key)'").first
    }
    guard try stamp("my_writing_included") == "0" else {
        throw ToolError("the export includes the owner's writing, or has no stamp: export with notes off")
    }
    let current = String(IndexingPipeline.currentDateIndexVersion)
    for key in ["installed_index_version", "current_index_version"] {
        let value = try stamp(key)
        guard value == current else {
            throw ToolError("the export's \(key) is \(value ?? "missing"); this pin's is \(current): export from the pinned build")
        }
    }
}
