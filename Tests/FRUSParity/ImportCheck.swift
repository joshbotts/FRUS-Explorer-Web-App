// The import of a Mac JSON export, checked (PLAN's S16c): an export imported into a store of its own
// through the server's own mapping, as the import route's job imports one, then read back from the
// store's tables as the kit's records and held to the file, type by type, by id. For the tests, the
// kit's fixtures and the browser suite's export; and `frus-parity import-check`, which a session runs
// on the owner's export, printing counts and ids, never what the records say.

import FRUSCoreKit
import FRUSLightAPI
import FRUSLightCore
import Foundation
import ParityFormat

public enum ImportCheck {
    /// What an import made of an export, and how far the store holds it.
    public struct Outcome: Sendable {
        public let report: ResearchImportReport
        public let comparison: ResearchComparison
        /// The store the export was imported into.
        public let store: URL
    }

    /// Imports `data` for `user` into a new store in `directory`, as the route's job does, and reads
    /// it back at the file's format version.
    public static func run(_ data: Data, in directory: URL, user: String = "owner") async throws -> Outcome {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("app.db")
        let store = try await SQLiteUserStore(url: url, backupsDirectory: directory.appendingPathComponent("backups"))
        let envelope = try MacImport.envelope(of: data)
        let report = try MacImport.run(envelope, into: store, for: user, includingInstanceWide: true)
        let stored = try StoredResearch.envelope(at: url, user: user, formatVersion: envelope.formatVersion, header: envelope)
        return Outcome(report: report, comparison: .compare(file: envelope, stored: stored), store: url)
    }

    /// What `frus-parity import-check` prints: the file's version, and for each type its count in the
    /// file, what became of it, and whether the store holds every record as the file has it, by the
    /// ids and field names of any it does not.
    public static func describe(_ outcome: Outcome) -> [String] {
        var lines = ["format version \(outcome.report.formatVersion), exported \(outcome.report.exportedAt)"]
        for (count, compared) in zip(outcome.report.types, outcome.comparison.types) {
            let carried = count.carried ? "" : " (not carried at this version)"
            var line = "\(count.type): \(count.inFile) in the file\(carried); \(count.added) came in, \(count.replaced) replaced, "
                + "\(count.kept) kept, \(count.setAside) set aside, \(count.repeated) repeated in the file"
            line += compared.isWhole ? "; all held as the file has them" : "; NOT WHOLE"
            lines.append(line)
            for id in compared.missing { lines.append("  missing: \(id)") }
            for difference in compared.different { lines.append("  differs: \(difference.id) in \(difference.fields.joined(separator: ", "))") }
        }
        let report = outcome.report
        lines.append("notes with formatting \(report.formattedNotes), of which kept as they came \(report.formattingKept); "
                     + "headnote drafts \(report.headnoteDrafts); summaries without authorship \(report.summariesWithoutAuthorship); "
                     + "inert entries \(report.inertEntries); smart collections whose saved search is not held "
                     + "\(report.unlinkedCollections.count); documents findable through user_search \(report.searchableDocuments)")
        return lines
    }
}

extension ImportFixtures {
    /// The browser suite's export as `frus-parity import-fixture` writes it: d3's text and version
    /// along the server's path, from one full parse of frus1961-63v06 in the fixture TEI.
    public static func browserSuiteFile(layout: RepositoryLayout) async throws -> Data {
        let rows = try await ReaderRenderer(layout: layout).fullParseModels(["frus1961-63v06"]) { model in
            (flat: buildFlatText(from: model), blocks: buildFlatTextBlocks(from: model),
             version: ASTToRenderNodeConverter.renderingVersion(for: model))
        }
        guard let d3 = rows.first(where: { $0.document == "d3" })?.value else {
            throw GoldenError.malformed(browserSuitePath, "frus1961-63v06 has no d3 in a full parse")
        }
        return try browserSuite(d3: d3.flat, blocks: d3.blocks, renderingVersion: d3.version).jsonData()
    }
}
