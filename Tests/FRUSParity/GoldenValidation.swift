// Whether the committed golden files can be trusted: present or pending, current, and whole.

import FRUSLightCore
import Foundation
import ParityFormat

/// What `GoldenValidation.validate` found in `fixtures/golden`.
public struct GoldenReport: Sendable {
    public var present: [GoldenFile] = []
    /// Each file still to be made, with what it waits for.
    public var pending: [GoldenFile: String] = [:]
    /// Each way a present file is stale, damaged or inconsistent, as a sentence.
    public var problems: [String] = []

    public init() {}
}

public enum GoldenValidation {
    /// Validates every golden file under `layout.golden`: each is present or pending; each present
    /// one was made from the pinned app's sources, at its index version, from the current inputs,
    /// which it records in full; each is whole; and the two made from an export come from the
    /// same one. `sourceDigest` defaults to the submodule's. With `sourceFilesRequired`, a file made
    /// from the app's source alone may not be pending, as in the committed repository.
    public static func validate(_ layout: RepositoryLayout, sourceDigest: String? = nil,
                                sourceFilesRequired: Bool = false) -> GoldenReport {
        var report = GoldenReport()
        let status: GoldenStatus
        do {
            status = try GoldenStatus(directory: layout.golden)
        } catch {
            report.problems.append("\(error)")
            return report
        }
        var digest = sourceDigest
        var queries: [ParityQuery]?
        var exports: [GoldenFile: Provenance] = [:]
        for file in GoldenFile.allCases {
            guard case .present = status.states[file] else {
                if case .pending(let reason)? = status.states[file] {
                    report.pending[file] = reason
                    if sourceFilesRequired, !file.needsExport {
                        report.problems.append("\(file.rawValue) is made from the app's source alone and must be committed, not pending: run scripts/make-golden")
                    }
                }
                continue
            }
            report.present.append(file)
            do {
                if digest == nil { digest = try Upstream.sourceDigest(layout.upstream) }
                if queries == nil, file == .expressions || file == .results { queries = try QueryList.load(layout.queries) }
                let url = status.url(file)
                let provenance: Provenance
                var problems: [String]
                switch file {
                case .render:
                    let golden = try GoldenJSON.read(RenderGolden.self, from: url)
                    provenance = golden.provenance
                    problems = format(golden.format, RenderGolden.currentFormat, file)
                        + renderProblems(golden, directory: url.deletingLastPathComponent())
                case .expressions:
                    let golden = try GoldenJSON.read(ExpressionsGolden.self, from: url)
                    provenance = golden.provenance
                    problems = format(golden.format, ExpressionsGolden.currentFormat, file)
                        + recordProblems(golden.queries.map(\.id), queries: queries ?? [], file: file)
                case .results:
                    let golden = try GoldenJSON.read(ResultsGolden.self, from: url)
                    provenance = golden.provenance
                    problems = format(golden.format, ResultsGolden.currentFormat, file)
                        + resultsProblems(golden, queries: queries ?? [])
                case .indexSummary:
                    let golden = try GoldenJSON.read(IndexSummaryGolden.self, from: url)
                    provenance = golden.provenance
                    problems = format(golden.format, IndexSummaryGolden.currentFormat, file) + indexSummaryProblems(golden)
                }
                report.problems += staleness(of: provenance, file: file.rawValue, layout: layout, sourceDigest: digest ?? "")
                report.problems += inputProblems(of: provenance, file: file)
                report.problems += problems
                if file.needsExport { exports[file] = provenance }
            } catch {
                report.problems.append("\(file.rawValue): \(error)")
            }
        }
        if let results = exports[.results], let summary = exports[.indexSummary] {
            report.problems += sameExportProblems(results: results, indexSummary: summary)
        }
        return report
    }

    /// Why a golden file is stale: made from other app sources, at another index version, or from
    /// inputs that have changed. Its inputs are keyed as `Provenance.inputs` says: a file must
    /// still hash the same, and a query list's records must still digest the same; a key without
    /// a `/` is information, such as an export's `research_provenance` values.
    public static func staleness(of provenance: Provenance, file: String, layout: RepositoryLayout, sourceDigest: String) -> [String] {
        var problems: [String] = []
        if provenance.sourceDigest != sourceDigest {
            problems.append(GoldenError.stale(file, "it was made from other app sources (source digest \(provenance.sourceDigest.prefix(12)); the submodule's is \(sourceDigest.prefix(12)))").description)
        }
        if provenance.indexVersion != IndexCompatibility.supportedIndexVersion {
            problems.append(GoldenError.stale(file, "it was made at index version \(provenance.indexVersion); the pin's is \(IndexCompatibility.supportedIndexVersion)").description)
        }
        for key in provenance.inputs.keys.sorted() where key.contains("/") {
            if key.hasSuffix(Provenance.recordsSuffix) {
                let path = String(key.dropLast(Provenance.recordsSuffix.count))
                let url = layout.root.appendingPathComponent(path)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    problems.append(GoldenError.stale(file, "its input \(path) no longer exists").description)
                    continue
                }
                do {
                    if QueryList.recordDigest(try QueryList.load(url)) != provenance.inputs[key] {
                        problems.append(GoldenError.stale(file, "the queries of its input \(path) have changed").description)
                    }
                } catch {
                    problems.append("\(file): its input \(path) cannot be read: \(error)")
                }
                continue
            }
            let url = layout.root.appendingPathComponent(key)
            guard let current = try? ParityFormat.Digest.sha256(contentsOf: url) else {
                problems.append(GoldenError.stale(file, "its input \(key) no longer exists").description)
                continue
            }
            if current != provenance.inputs[key] {
                problems.append(GoldenError.stale(file, "its input \(key) has changed").description)
            }
        }
        return problems
    }

    /// The `research_provenance` values a golden file made from an export must record: those that
    /// say which export it was and which build made it.
    public static let requiredStampKeys = [
        "app_build", "current_index_version", "exported_at", "installed_index_version", "my_writing_included",
    ].map { "research_provenance.\($0)" }

    /// The input keys each golden file must record, so that a change to any of its inputs makes
    /// it stale: the fixtures for whatever an index or a render was made from, the query list's
    /// records for whatever was made from queries, and the export's stamp.
    public static func requiredInputs(_ file: GoldenFile) -> [String] {
        let records = Provenance.recordsKey(RepositoryLayout.queriesPath)
        switch file {
        case .render: return ParityFixtures.teiInputKeys
        case .expressions: return [records]
        case .results: return [records] + ParityFixtures.teiInputKeys + requiredStampKeys
        case .indexSummary: return ParityFixtures.teiInputKeys + requiredStampKeys
        }
    }

    /// Each required input a golden file does not record and, for one made from an export, each
    /// stamp value that contradicts the provenance: an export from another build, or at another
    /// index version.
    public static func inputProblems(of provenance: Provenance, file: GoldenFile) -> [String] {
        var problems: [String] = []
        let missing = requiredInputs(file).filter { provenance.inputs[$0] == nil }
        if !missing.isEmpty {
            problems.append("\(file.rawValue): it was made without recording \(missing.joined(separator: ", ")). Run scripts/make-golden")
        }
        guard file.needsExport else { return problems }
        let build = provenance.appBuild.map(String.init) ?? "none"
        if let stamped = provenance.inputs["research_provenance.app_build"], stamped != build {
            problems.append("\(file.rawValue): its export was made by app build \(stamped), but it records the pin's build as \(build): export from the pinned build")
        }
        for key in ["research_provenance.installed_index_version", "research_provenance.current_index_version"] {
            if let stamped = provenance.inputs[key], stamped != String(provenance.indexVersion) {
                problems.append("\(file.rawValue): its export's \(key) is \(stamped), but it was made at index version \(provenance.indexVersion)")
            }
        }
        return problems
    }

    /// The results and the index summary must come from one export: every `research_provenance`
    /// value both record must be the same.
    public static func sameExportProblems(results: Provenance, indexSummary: Provenance) -> [String] {
        let keys = Set(results.inputs.keys).intersection(indexSummary.inputs.keys).filter { $0.hasPrefix("research_provenance.") }
        let differing = keys.sorted().filter { results.inputs[$0] != indexSummary.inputs[$0] }
        guard !differing.isEmpty else { return [] }
        let detail = differing.map { "\($0) is \(results.inputs[$0]!) in one and \(indexSummary.inputs[$0]!) in the other" }
        return ["\(GoldenFile.results.rawValue) and \(GoldenFile.indexSummary.rawValue) come from different exports: \(detail.joined(separator: "; ")). Make both from one export with scripts/make-golden --export"]
    }

    /// Check 4's golden HTML: each row's file is there with the manifest's size and SHA-256, no
    /// row is listed twice, no file is unlisted, and the rows cover exactly the fixture volumes,
    /// grouped by volume in sorted order.
    public static func renderProblems(_ golden: RenderGolden, directory: URL) -> [String] {
        let file = GoldenFile.render.rawValue
        var problems: [String] = []
        var listed: Set<String> = []
        for row in golden.rows {
            let path = RenderGolden.htmlPath(volume: row.volume, document: row.document)
            guard listed.insert(path).inserted else {
                problems.append("\(file): \(row.volume) \(row.document) is listed twice")
                continue
            }
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(path)) else {
                problems.append("\(file): \(path) is missing")
                continue
            }
            let sha = ParityFormat.Digest.sha256(data)
            if data.count != row.bytes || sha != row.sha256 {
                problems.append("\(file): \(path) is \(data.count) bytes with SHA-256 \(sha.prefix(12)); the manifest says \(row.bytes) bytes, \(row.sha256.prefix(12))")
            }
        }
        let html = directory.appendingPathComponent("html")
        if let enumerator = FileManager.default.enumerator(atPath: html.path) {
            while let path = enumerator.nextObject() as? String {
                if path.hasSuffix(".html"), !listed.contains("html/\(path)") {
                    problems.append("\(file): html/\(path) is not in the manifest")
                }
            }
        }
        let volumes = golden.rows.map(\.volume)
        if Set(volumes) != Set(ParityFixtures.volumes) {
            problems.append("\(file): the rows cover \(Set(volumes).sorted().joined(separator: ", ")), not exactly the fixtures \(ParityFixtures.volumes.joined(separator: ", "))")
        }
        var runs: [String] = []
        for volume in volumes where runs.last != volume { runs.append(volume) }
        if runs != runs.sorted() || Set(runs).count != runs.count {
            problems.append("\(file): the rows are not grouped by volume in sorted order")
        }
        return problems
    }

    /// Check 3's results: one record per query, each with a score for every result.
    public static func resultsProblems(_ golden: ResultsGolden, queries: [ParityQuery]) -> [String] {
        let file = GoldenFile.results.rawValue
        var problems = recordProblems(golden.queries.map(\.id), queries: queries, file: .results)
        for record in golden.queries {
            if record.scoreBits.count != record.top.count {
                problems.append("\(file): \(record.id) has \(record.scoreBits.count) scores for \(record.top.count) results")
            }
            if record.tieTailScoreBits.count != record.tieTail.count {
                problems.append("\(file): \(record.id) has \(record.tieTailScoreBits.count) scores for \(record.tieTail.count) tied results after the 50th")
            }
            if record.top.count > 50 {
                problems.append("\(file): \(record.id) lists \(record.top.count) results; the golden file keeps 50")
            }
        }
        return problems
    }

    /// Check 2's golden summary: exactly the fixture volumes, every check at its right value, and
    /// integrity checked.
    public static func indexSummaryProblems(_ golden: IndexSummaryGolden) -> [String] {
        let file = GoldenFile.indexSummary.rawValue
        var problems: [String] = []
        if golden.gating.volumes != ParityFixtures.volumes.sorted() {
            problems.append("\(file): it summarizes \(golden.gating.volumes.joined(separator: ", ")), not exactly the fixtures")
        }
        for failure in IndexSummaryComparison.failedChecks(golden) { problems.append("\(file): \(failure)") }
        if golden.gating.checks["integrity"] == nil {
            problems.append("\(file): it was made without the integrity checks")
        }
        return problems
    }

    /// One record per listed query: none missing, none extra, none twice.
    static func recordProblems(_ ids: [String], queries: [ParityQuery], file: GoldenFile) -> [String] {
        var problems: [String] = []
        var seen: Set<String> = []
        for id in ids where !seen.insert(id).inserted { problems.append("\(file.rawValue): \(id) has two records") }
        let listed = Set(queries.map(\.id))
        let missing = queries.map(\.id).filter { !seen.contains($0) }
        let extra = seen.subtracting(listed).sorted()
        if !missing.isEmpty { problems.append("\(file.rawValue): no record for \(missing.joined(separator: ", "))") }
        if !extra.isEmpty { problems.append("\(file.rawValue): records for queries not in the list: \(extra.joined(separator: ", "))") }
        return problems
    }

    static func format(_ found: Int, _ current: Int, _ file: GoldenFile) -> [String] {
        found == current ? [] : ["\(file.rawValue): format \(found); this harness reads format \(current)"]
    }
}

public enum QueryListValidation {
    /// Every way the query list and the rules file are inconsistent. `text` is the query list's
    /// raw JSONL, read for keys the decoder would silently drop.
    public static func problems(queries: [ParityQuery], rules: [ParityRule], text: String? = nil) -> [String] {
        var problems: [String] = []
        var ids: Set<String> = []
        for query in queries {
            if !ids.insert(query.id).inserted { problems.append("\(query.id) is used twice") }
            if !isQueryId(query.id) { problems.append("\(query.id) is not of the form q001") }
        }
        var ruleIds: Set<String> = []
        for rule in rules where !ruleIds.insert(rule.id).inserted { problems.append("rule \(rule.id) is listed twice") }
        for query in queries where !ruleIds.contains(query.rule) {
            problems.append("\(query.id) exercises \(query.rule), which rules.tsv does not list")
        }
        let exercised = Set(queries.map(\.rule))
        var reported: Set<String> = []
        for rule in rules where !exercised.contains(rule.id) && reported.insert(rule.id).inserted {
            problems.append("rule \(rule.id) has no query")
        }
        let fixtures = Set(ParityFixtures.volumes)
        for query in queries {
            for volume in query.filters.volumeIds ?? [] where !fixtures.contains(volume) {
                problems.append("\(query.id) filters on \(volume), which is not a fixture volume")
            }
            for bound in [query.filters.dateRange?.earliest, query.filters.dateRange?.latest].compactMap({ $0 }) where !isDate(bound) {
                problems.append("\(query.id) has the date \(bound), which is neither yyyy-MM-dd nor yyyy")
            }
            let encoded = try? JSONEncoder().encode(query)
            if encoded.flatMap({ try? JSONDecoder().decode(ParityQuery.self, from: $0) }) != query {
                problems.append("\(query.id) does not survive a JSON round trip")
            }
        }
        if let text { problems += unknownKeys(text) }
        return problems
    }

    /// Keys in the JSONL that `ParityQuery` does not decode, such as a misspelt filter.
    static func unknownKeys(_ text: String) -> [String] {
        var filters = QueryFilters()
        filters.phrase = ""
        filters.prefixWildcard = ""
        filters.excludedTerms = []
        filters.volumeIds = []
        filters.yearKeys = []
        filters.dateRange = DateRangeFilter(earliest: "", latest: "")
        filters.documentType = ""
        filters.includeFrontMatter = true
        filters.includeDocumentText = true
        filters.includeSummaries = true
        filters.includeNotes = true
        let full = ParityQuery(id: "", rule: "", query: "", filters: filters, notes: "")
        guard let data = try? JSONEncoder().encode(full),
              let known = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ["the query format cannot be encoded"] }
        let filterObject = known["filters"] as? [String: Any] ?? [:]
        let knownFilters = Set(filterObject.keys)
        let knownRange = Set((filterObject["dateRange"] as? [String: Any] ?? [:]).keys)

        var problems: [String] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
        where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                problems.append("line \(index + 1) is not a JSON object")
                continue
            }
            var unknown = object.keys.filter { known[$0] == nil }
            if let filters = object["filters"] as? [String: Any] {
                unknown += filters.keys.filter { !knownFilters.contains($0) }.map { "filters.\($0)" }
                if let range = filters["dateRange"] as? [String: Any] {
                    unknown += range.keys.filter { !knownRange.contains($0) }.map { "filters.dateRange.\($0)" }
                }
            }
            if !unknown.isEmpty { problems.append("line \(index + 1) has keys the query format does not read: \(unknown.sorted().joined(separator: ", "))") }
        }
        return problems
    }

    /// `q` and at least three digits.
    static func isQueryId(_ id: String) -> Bool {
        id.first == "q" && id.count >= 4 && id.dropFirst().allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// `yyyy-MM-dd`, a real day, or `yyyy`.
    static func isDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 1 || parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts[0].count == 4, let year = Int(parts[0]) else { return false }
        guard parts.count == 3 else { return true }
        guard parts[1].count == 2, parts[2].count == 2, let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month) else { return false }
        let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return (1...days[month - 1]).contains(day)
    }
}

// MARK: - Reading one golden file for a check

/// A golden file that records how it was made.
public protocol GoldenDocument: Decodable, Sendable {
    var provenance: Provenance { get }
}

extension RenderGolden: GoldenDocument {}
extension ExpressionsGolden: GoldenDocument {}
extension ResultsGolden: GoldenDocument {}
extension IndexSummaryGolden: GoldenDocument {}

/// A golden file as a check reads it: present, with each way it is stale at this pin, or pending,
/// with what it waits for.
public enum LoadedGolden<Golden: GoldenDocument>: Sendable {
    case present(Golden, stale: [String])
    case pending(String)
}

extension GoldenValidation {
    /// Reads `file` from `layout.golden`, as `RenderParity.golden` reads the render manifest: its
    /// state in `PENDING`, then, when present, the file and each way it is stale against the
    /// submodule. A check compares with it only when nothing is stale, since a golden file made from
    /// other app sources tests other code than the pin's.
    public static func load<Golden: GoldenDocument>(_ file: GoldenFile, as type: Golden.Type,
                                                    layout: RepositoryLayout) throws -> LoadedGolden<Golden> {
        let status = try GoldenStatus(directory: layout.golden)
        switch status.states[file] {
        case .present?:
            let golden = try GoldenJSON.read(type, from: status.url(file))
            let stale = staleness(of: golden.provenance, file: file.rawValue, layout: layout,
                                  sourceDigest: try Upstream.sourceDigest(layout.upstream))
            return .present(golden, stale: stale)
        case .pending(let reason)?:
            return .pending(reason)
        case nil:
            throw GoldenError.malformed(GoldenStatus.pendingFile, "no state for \(file.rawValue)")
        }
    }
}
