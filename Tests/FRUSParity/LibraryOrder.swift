// Check 2 at full scale (PLAN's S25b): each volume's documents in the order the app lists them, by rowid
// (`documents(forVolume:)`), in a library against an index of the same files.
//
// The kit writes `document_cache` by upsert, which keeps a document's rowid when its volume is indexed again
// (`IndexSchema`'s `upserted`), so a library the app has kept over many index versions and corrections holds
// a volume's documents in the order of its indexing passes: those of its first pass in the order that pass
// stored them, then a document a later index version began to hold, or a corrected file added, after them.
// An index made in one pass holds each volume in its file's order, in one run of consecutive rowids.
// `compare(library:index:)` says which, volume by volume: the index's order; runs of consecutive rowids, one
// to a pass, each in the index's order; or out of the index's order within a run, as an earlier version of a
// file or of the indexer stored it, each with its first inversion. The two must hold the same documents,
// which check 2's digests gate; the order of a library is reported, not gated, since it is that library's
// history (the fixtures' order is gated against a library that indexed them in one pass, the golden one).

import Foundation

public enum LibraryOrder {
    /// What the comparison found.
    public struct Result: Sendable, Equatable {
        public var volumes = 0
        /// The volumes in the index's order.
        public var sameOrder = 0
        /// The volumes whose documents fall in runs of consecutive rowids, each in the index's order, by
        /// volume, with how many runs.
        public var passes: [String: Int] = [:]
        /// The rows after a volume's first run, in the volumes whose runs are each in the index's order.
        public var laterRows = 0
        /// The runs of a single row among those volumes' runs, which are in the index's order whatever their order
        /// between them: the more there are, the less the classification says.
        public var singleRowRuns = 0
        /// The volumes out of the index's order within a run, each with its first inversion.
        public var outOfOrder: [String: String] = [:]
        /// The volumes whose documents differ, which check 2's digests refuse.
        public var differentDocuments: [String: String] = [:]

        /// Whether both hold the same documents in every volume.
        public var holdsTheSameDocuments: Bool { differentDocuments.isEmpty && volumes > 0 }

        /// The report's lines.
        public func summary() -> String {
            var lines = ["\(volumes) volumes: \(sameOrder) in the index's order; \(passes.count) in runs of consecutive rowids, "
                         + "one to a pass, each run in the index's order (\(passes.values.reduce(0, +)) runs, \(singleRowRuns) of them a single row, \(laterRows) rows after a volume's first run); "
                         + "\(outOfOrder.count) out of the index's order within a run"]
            for volume in outOfOrder.keys.sorted() { lines.append("  out of order within a run: \(volume): \(outOfOrder[volume]!)") }
            for volume in differentDocuments.keys.sorted() { lines.append("  other documents: \(volume): \(differentDocuments[volume]!)") }
            return lines.joined(separator: "\n")
        }
    }

    /// Each volume's documents and their rowids, in rowid order, read with `immutable=1`.
    static func rows(_ url: URL) throws -> [String: [(document: String, rowid: Int64)]] {
        var rows: [String: [(document: String, rowid: Int64)]] = [:]
        for row in try ParityDatabase.immutable(url).rows("SELECT volume_id, document_id, rowid FROM document_cache ORDER BY volume_id, rowid") {
            guard let volume = row[0].text, let document = row[1].text, let rowid = row[2].integer else { continue }
            rows[volume, default: []].append((document, rowid))
        }
        return rows
    }

    /// Compares the order of each volume's documents in `library` with `index`'s.
    public static func compare(library: URL, index: URL) throws -> Result {
        // Read with `immutable=1`, which would miss a log's pages: refused, as the summary refuses them.
        try IndexSummarizerFile.refuseUnfinished(library)
        try IndexSummarizerFile.refuseUnfinished(index)
        let (theirs, ours) = (try rows(library), try rows(index))
        var result = Result()
        for volume in Set(theirs.keys).union(ours.keys).sorted() {
            result.volumes += 1
            let (held, made) = (theirs[volume] ?? [], ours[volume] ?? [])
            guard held.count == made.count, Set(held.map(\.document)) == Set(made.map(\.document)) else {
                result.differentDocuments[volume] = "\(held.count) documents in the library, \(made.count) in the index"
                continue
            }
            if held.map(\.document) == made.map(\.document) {
                result.sameOrder += 1
                continue
            }
            var place: [String: Int] = [:]
            for (offset, row) in made.enumerated() { place[row.document] = offset }
            var runs = 1
            var length = 1
            var singles = 0
            var later = 0
            var inversion: String?
            for (previous, row) in zip(held, held.dropFirst()) {
                if row.rowid != previous.rowid + 1 {
                    if length == 1 { singles += 1 }
                    runs += 1
                    length = 1
                } else {
                    length += 1
                    if inversion == nil, place[row.document]! < place[previous.document]! {
                        inversion = "\(previous.document) before \(row.document), where the index has them the other way round"
                    }
                }
                if runs > 1 { later += 1 }
            }
            if length == 1 { singles += 1 }
            if let inversion {
                result.outOfOrder[volume] = inversion
            } else {
                result.passes[volume] = runs
                result.singleRowRuns += singles
                result.laterRows += later
            }
        }
        return result
    }
}
