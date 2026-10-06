// The server's index format must match the pinned FRUS-Explorer commit and a real export.

import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

@Suite struct CompatibilityTests {
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func upstreamNumber(in path: String, after prefix: String) throws -> Int? {
        let source = try String(contentsOf: repository.appendingPathComponent("upstream/FRUS-Explorer/\(path)"), encoding: .utf8)
        guard let range = source.range(of: prefix) else { return nil }
        return Int(source[range.upperBound...].prefix { $0.isNumber })
    }

    /// Where the pinned app keeps IndexingPipeline.swift: in the kit's folder since FRUSCoreKit,
    /// part 2 (session 6's pin), and in the app's before. Exactly one of the two must hold it.
    static let indexingPipelinePaths = ["FRUSExplorer/Search/IndexingPipeline.swift", "FRUSCoreKit/Search/IndexingPipeline.swift"]

    static func indexingPipelinePath() throws -> String {
        let found = indexingPipelinePaths.filter {
            FileManager.default.fileExists(atPath: repository.appendingPathComponent("upstream/FRUS-Explorer/\($0)").path)
        }
        try #require(found.count == 1, """
            the submodule must hold IndexingPipeline.swift at exactly one of \(indexingPipelinePaths.joined(separator: " and ")), \
            but holds it at \(found.isEmpty ? "neither" : "both")
            """)
        return found[0]
    }

    @Test func supportedIndexVersionMatchesThePin() throws {
        let pinned = try Self.upstreamNumber(in: Self.indexingPipelinePath(),
                                             after: "static let currentDateIndexVersion: Int = ")
        #expect(pinned == IndexCompatibility.supportedIndexVersion,
                "the pin moved: update IndexCompatibility.supportedIndexVersion")
    }

    @Test func ftsSchemaVersionMatchesThePin() throws {
        let pinned = try Self.upstreamNumber(in: "FTS5Store/FTS5Connection.swift", after: "static let currentSchemaGeneration = ")
        #expect(pinned == IndexCompatibility.ftsSchemaVersion)
    }

    /// The real export's full-text tables are exactly what the app's FTS5Types.swift builds.
    @Test(arguments: [("frus_documents", FTS5Schema.frusDocuments), ("user_content", FTS5Schema.userContent)])
    func exportFullTextTablesMatchTheAppsDDL(_ table: String, _ schema: FTS5Schema) throws {
        let exportSchema = try SyntheticExport.schema()
        let start = try #require(exportSchema.range(of: "CREATE VIRTUAL TABLE \(table) USING fts5("))
        let end = try #require(exportSchema[start.lowerBound...].range(of: ");"))
        let fromExport = String(exportSchema[start.lowerBound..<end.lowerBound]) + ")"
        let squeeze = { (sql: String) in sql.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        #expect(squeeze(fromExport) == squeeze(schema.createTableSQL(ifNotExists: false)))
    }
}
