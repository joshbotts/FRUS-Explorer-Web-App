// Check 2: the summary of an index, its golden file, and how two summaries compare.

import Foundation
import ParityFormat

/// `fixtures/golden/index-summary.json`: check 2's summary of the owner's three-volume export, which
/// `frus-parity summarize` writes. The Linux indexer's database (session 6) is summarized the same
/// way and compared with it by `IndexSummaryComparison`: only `gating` is compared.
public struct IndexSummaryGolden: Codable, Equatable, Sendable {
    public var format: Int
    public var provenance: Provenance
    public var gating: IndexGating
    public var information: IndexInformation

    public static let currentFormat = 1

    public init(provenance: Provenance, gating: IndexGating, information: IndexInformation) {
        self.format = Self.currentFormat
        self.provenance = provenance
        self.gating = gating
        self.information = information
    }
}

/// What must be identical on both platforms.
public struct IndexGating: Codable, Equatable, Sendable {
    /// The distinct `document_cache.volume_id` values, sorted.
    public var volumes: [String]
    /// Conditions with one right value, each named, such as `integrity`. A condition the summary
    /// could not check, such as integrity above the size limit, is left out and named in the notes.
    public var checks: [String: String]
    /// One digest per hashed statement, by name: `document_cache` for a table's rows in natural-key
    /// order, `document_cache.sequence` for their order within each volume, and so on.
    public var digests: [String: StatementDigest]

    /// The right value of each check.
    public static let expectedChecks: [String: String] = [
        "application_id": "0",
        "document_revisions.history": "0",
        "encoding": "UTF-8",
        "frus_documents.docsize_orphans": "0",
        "integrity": "ok",
        "user_content.docsize_orphans": "0",
        "user_version": String(IndexSummarizer.ftsSchemaVersion),
    ]

    public init(volumes: [String], checks: [String: String], digests: [String: StatementDigest]) {
        self.volumes = volumes
        self.checks = checks
        self.digests = digests
    }
}

/// What may differ between platforms or runs, reported for people to read and never compared.
public struct IndexInformation: Codable, Equatable, Sendable {
    public var sqliteVersion: String
    public var fileBytes: Int64
    public var pageSize: Int
    public var pageCount: Int
    public var freelistCount: Int
    public var journalMode: String
    /// Volumes in the order they were indexed: by their first `document_cache` rowid.
    public var volumeOrder: [String]
    /// The export's `research_provenance`, or nil for an index the exporter did not stamp.
    public var exportStamp: [String: String]?
    /// `sqlite_sequence`: the last id each AUTOINCREMENT table handed out.
    public var sqliteSequence: [String: Int64]
    /// Statements run before hashing: the temporary `fts5vocab` tables.
    public var setup: [String]
    /// Digests that are reported but not compared: orders the app never reads, raw ids, raw JSON.
    public var digests: [String: StatementDigest]
    /// What the summary left out, and why.
    public var notes: [String]
    /// Seconds per statement, and `total`.
    public var timings: [String: Double]

    public init(sqliteVersion: String, fileBytes: Int64, pageSize: Int, pageCount: Int, freelistCount: Int,
                journalMode: String, volumeOrder: [String], exportStamp: [String: String]?,
                sqliteSequence: [String: Int64], setup: [String], digests: [String: StatementDigest],
                notes: [String], timings: [String: Double]) {
        self.sqliteVersion = sqliteVersion
        self.fileBytes = fileBytes
        self.pageSize = pageSize
        self.pageCount = pageCount
        self.freelistCount = freelistCount
        self.journalMode = journalMode
        self.volumeOrder = volumeOrder
        self.exportStamp = exportStamp
        self.sqliteSequence = sqliteSequence
        self.setup = setup
        self.digests = digests
        self.notes = notes
        self.timings = timings
    }
}

/// One hashed statement: its exact SQL, so anyone can re-derive the digest, its row count and
/// its SHA-256 in `sha3_query` framing (`ParityDatabase.digest`).
public struct StatementDigest: Codable, Equatable, Sendable {
    public var sql: String
    public var rows: Int
    public var sha256: String
    /// The rows of each volume, hashed under the same statement frame, when the statement has a
    /// volume column. A difference then names the volume.
    public var volumes: [String: VolumeDigest]?

    public init(sql: String, rows: Int, sha256: String, volumes: [String: VolumeDigest]? = nil) {
        self.sql = sql
        self.rows = rows
        self.sha256 = sha256
        self.volumes = volumes
    }
}

public struct VolumeDigest: Codable, Equatable, Sendable {
    public var rows: Int
    public var sha256: String

    public init(rows: Int, sha256: String) {
        self.rows = rows
        self.sha256 = sha256
    }
}

/// One gating difference between two summaries, or one check at the wrong value.
public struct SummaryDifference: Equatable, Sendable, CustomStringConvertible {
    /// A digest's or a check's name, or `format` or `volumes`.
    public var item: String
    public var volume: String?
    public var detail: String

    public init(item: String, volume: String? = nil, detail: String) {
        self.item = item
        self.volume = volume
        self.detail = detail
    }

    public var description: String {
        volume.map { "\(item) [\($0)]: \(detail)" } ?? "\(item): \(detail)"
    }
}

public enum IndexSummaryComparison {
    /// Every gating difference between a golden summary and a candidate, by item and volume, and
    /// every check either one holds at the wrong value. Empty when check 2 passes.
    public static func differences(golden: IndexSummaryGolden, candidate: IndexSummaryGolden) -> [SummaryDifference] {
        var differences: [SummaryDifference] = []
        if golden.format != candidate.format {
            differences.append(SummaryDifference(item: "format", detail: "golden \(golden.format), candidate \(candidate.format)"))
        }
        let (g, c) = (golden.gating, candidate.gating)
        if g.volumes != c.volumes {
            differences.append(SummaryDifference(
                item: "volumes", detail: "golden \(g.volumes.joined(separator: ", ")), candidate \(c.volumes.joined(separator: ", "))"))
        }
        for name in Set(g.checks.keys).union(c.checks.keys).sorted() where g.checks[name] != c.checks[name] {
            differences.append(SummaryDifference(
                item: name, detail: "golden \(g.checks[name] ?? "not checked"), candidate \(c.checks[name] ?? "not checked")"))
        }
        // A check both hold at the same wrong value is no difference, but still fails.
        for failure in failedChecks(golden) where g.checks[failure.item] == c.checks[failure.item] {
            differences.append(SummaryDifference(item: failure.item, detail: "both \(failure.detail)"))
        }
        for name in Set(g.digests.keys).union(c.digests.keys).sorted() {
            guard let a = g.digests[name], let b = c.digests[name] else {
                differences.append(SummaryDifference(
                    item: name, detail: g.digests[name] == nil ? "only the candidate has it" : "only the golden summary has it"))
                continue
            }
            differences += self.differences(name, golden: a, candidate: b)
        }
        return differences
    }

    /// The checks a summary holds at a value other than the right one.
    public static func failedChecks(_ summary: IndexSummaryGolden) -> [SummaryDifference] {
        summary.gating.checks.keys.sorted().compactMap { name in
            let value = summary.gating.checks[name]
            let expected = IndexGating.expectedChecks[name]
            guard value != expected else { return nil }
            return SummaryDifference(item: name, detail: "is \(value ?? "missing"), expected \(expected ?? "no such check")")
        }
    }

    static func differences(_ name: String, golden: StatementDigest, candidate: StatementDigest) -> [SummaryDifference] {
        guard golden.sql == candidate.sql else {
            return [SummaryDifference(item: name, detail: "the statements differ, so the summaries came from different harness versions: regenerate the golden file")]
        }
        guard golden.sha256 != candidate.sha256 || golden.rows != candidate.rows else { return [] }
        var differences = [SummaryDifference(item: name, detail: "\(rows(golden.rows, candidate.rows))content differs")]
        let (a, b) = (golden.volumes ?? [:], candidate.volumes ?? [:])
        for volume in Set(a.keys).union(b.keys).sorted() where a[volume] != b[volume] {
            let detail: String
            switch (a[volume], b[volume]) {
            case (let x?, let y?): detail = "\(rows(x.rows, y.rows))content differs"
            case (let x?, nil): detail = "golden has \(x.rows) rows, candidate none"
            case (nil, let y?): detail = "golden has none, candidate \(y.rows) rows"
            case (nil, nil): continue
            }
            differences.append(SummaryDifference(item: name, volume: volume, detail: detail))
        }
        return differences
    }

    private static func rows(_ golden: Int, _ candidate: Int) -> String {
        golden == candidate ? "\(golden) rows each, " : "golden \(golden) rows, candidate \(candidate), "
    }
}

extension IndexSummaryGolden {
    /// A readable report: checks, then each digest with its rows and the start of its hash, each
    /// volume's when there are at most `volumeLimit` volumes, then the information.
    public func report(volumeLimit: Int = 10) -> String {
        var lines: [String] = []
        func digestLines(_ digests: [String: StatementDigest]) {
            let width = (digests.keys.map(\.count).max() ?? 0) + 2
            for name in digests.keys.sorted() {
                let digest = digests[name]!
                lines.append("  \(name.padding(toLength: width, withPad: " ", startingAt: 0))\(String(digest.rows).leftPadded(9)) rows  \(digest.sha256.prefix(16))")
                guard let volumes = digest.volumes, gating.volumes.count <= volumeLimit else { continue }
                for volume in volumes.keys.sorted() {
                    let entry = volumes[volume]!
                    lines.append("    \(volume.padding(toLength: width - 2, withPad: " ", startingAt: 0))\(String(entry.rows).leftPadded(9)) rows  \(entry.sha256.prefix(16))")
                }
            }
        }
        lines.append("volumes (\(gating.volumes.count)): \(gating.volumes.prefix(volumeLimit).joined(separator: ", "))\(gating.volumes.count > volumeLimit ? ", …" : "")")
        lines.append("checks:")
        for name in gating.checks.keys.sorted() {
            let value = gating.checks[name]!
            let mark = value == IndexGating.expectedChecks[name] ? "" : "   <- expected \(IndexGating.expectedChecks[name] ?? "nothing")"
            lines.append("  \(name) = \(value)\(mark)")
        }
        lines.append("gating digests:")
        digestLines(gating.digests)
        lines.append("information digests:")
        digestLines(information.digests)
        let info = information
        lines.append("information:")
        lines.append("  SQLite \(info.sqliteVersion), \(info.fileBytes) bytes, page size \(info.pageSize), \(info.pageCount) pages, \(info.freelistCount) free, journal mode \(info.journalMode)")
        lines.append("  volume order: \(info.volumeOrder.prefix(volumeLimit).joined(separator: ", "))\(info.volumeOrder.count > volumeLimit ? ", …" : "")")
        if let stamp = info.exportStamp {
            for key in stamp.keys.sorted() { lines.append("  research_provenance \(key) = \(stamp[key]!)") }
        } else {
            lines.append("  no research_provenance: the exporter did not stamp this index")
        }
        for name in info.sqliteSequence.keys.sorted() { lines.append("  sqlite_sequence \(name) = \(info.sqliteSequence[name]!)") }
        for note in info.notes { lines.append("  note: \(note)") }
        lines.append(String(format: "  total %.2f s", info.timings["total"] ?? 0))
        return lines.joined(separator: "\n")
    }
}

extension String {
    fileprivate func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }
}
