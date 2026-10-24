// frus-parity: the parity harness's command line (docs/SPEC.md, Verification, checks 2-4).
//
//   frus-parity summarize <db> [--any-volumes] [--golden <out.json>] [--upstream-commit <sha>] [--repo <root>]
//   frus-parity compare-summary <golden.json> <candidate.json>
//   frus-parity compare-results <golden.json> <candidate.json>
//   frus-parity results --api <url> --out <candidate.json> [--queries <jsonl>] [--repo <root>]
//   frus-parity render-api --api <url> <render folder>
//   frus-parity parse <queries.jsonl>
//   frus-parity render [<volume> <document> [--full-parse] [--out <file>]] [--repo <root>]
//   frus-parity index [<volume>...] [--tei <dir>] [--resources <dir>] [--out <db>] [--metrics] [--repo <root>]
//   frus-parity check-golden [--repo <root>]
//   frus-parity own-text --api <url> <export> [--volumes <id,id>]
//   frus-parity time-search <db> [--all] [--ids <id,...>] [--retained] [--out <results.json>] [--queries <jsonl>] [--resources <dir>] [--repo <root>]
//   frus-parity highlight-samples --out <samples.json> [--repo <root>]
//   frus-parity rich-text-fixtures [--repo <root>]
//
// The repository is found from the current directory unless --repo names it. Exit status: 0 when
// the check passes, 1 on a refusal, a difference or a problem, 2 on a usage error.

import FRUSParity
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ParityFormat

let usage = """
    usage: frus-parity summarize <db> [--any-volumes] [--golden <out.json>] [--upstream-commit <sha>] [--repo <root>]
           frus-parity compare-summary <golden.json> <candidate.json>
           frus-parity compare-results <golden.json> <candidate.json>
           frus-parity results --api <url> --out <candidate.json> [--queries <jsonl>] [--repo <root>]
           frus-parity render-api --api <url> <render folder>
           frus-parity parse <queries.jsonl>
           frus-parity render [<volume> <document> [--full-parse] [--out <file>]] [--repo <root>]
           frus-parity index [<volume>...] [--tei <dir>] [--resources <dir>] [--out <db>] [--metrics] [--repo <root>]
           frus-parity check-golden [--repo <root>]
           frus-parity own-text --api <url> <export> [--volumes <id,id>]
           frus-parity time-search <db> [--all] [--ids <id,...>] [--retained] [--out <results.json>] [--queries <jsonl>] [--resources <dir>] [--repo <root>]
           frus-parity highlight-samples --out <samples.json> [--repo <root>]
           frus-parity rich-text-fixtures [--repo <root>]
    """

/// A command's positional arguments, flags and options.
struct Arguments {
    var positional: [String] = []
    var flags: Set<String> = []
    var options: [String: String] = [:]

    init(_ arguments: ArraySlice<String>, flags known: Set<String> = [], options valued: Set<String> = []) throws {
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            if known.contains(argument) {
                flags.insert(argument)
            } else if valued.contains(argument) {
                guard let value = rest.popFirst() else { throw UsageError("\(argument) needs a value") }
                options[argument] = value
            } else if argument.hasPrefix("--") {
                throw UsageError("unknown option \(argument)")
            } else {
                positional.append(argument)
            }
        }
    }
}

struct UsageError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("frus-parity: \(message)\n".utf8))
    exit(1)
}

func repository(_ arguments: Arguments) throws -> RepositoryLayout {
    if let root = arguments.options["--repo"] { return RepositoryLayout(root: URL(fileURLWithPath: root, isDirectory: true)) }
    return try RepositoryLayout.locate(from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true))
}

func summarize(_ arguments: Arguments) throws {
    guard arguments.positional.count == 1 else { throw UsageError("summarize takes one database") }
    let layout = try repository(arguments)
    let url = URL(fileURLWithPath: arguments.positional[0])
    // A golden summary names the submodule's commit, as tools/mac-golden's files do.
    var commit = arguments.options["--upstream-commit"]
    if commit == nil, arguments.options["--golden"] != nil { commit = layout.upstreamCommit() }
    let summarizer = IndexSummarizer(layout: layout, anyVolumes: arguments.flags.contains("--any-volumes"),
                                     upstreamCommit: commit)
    let summary: IndexSummaryGolden
    do {
        summary = try summarizer.summarize(url)
    } catch let refusal as SummaryRefusal {
        fail("refused \(url.lastPathComponent): \(refusal.reason)")
    }
    print(url.path)
    print(summary.report())
    if let output = arguments.options["--golden"] {
        try GoldenJSON.write(summary, to: URL(fileURLWithPath: output))
        print("wrote \(output)")
    }
    let failed = IndexSummaryComparison.failedChecks(summary)
    if !failed.isEmpty { fail("checks failed: \(failed.map(\.description).joined(separator: "; "))") }
}

func compareSummary(_ arguments: Arguments) throws {
    guard arguments.positional.count == 2 else { throw UsageError("compare-summary takes a golden summary and a candidate") }
    let golden = try GoldenJSON.read(IndexSummaryGolden.self, from: URL(fileURLWithPath: arguments.positional[0]))
    let candidate = try GoldenJSON.read(IndexSummaryGolden.self, from: URL(fileURLWithPath: arguments.positional[1]))
    let (a, b) = (golden.information, candidate.information)
    print("information, not compared: SQLite \(a.sqliteVersion) and \(b.sqliteVersion); volume order \(a.volumeOrder.joined(separator: ",")) and \(b.volumeOrder.joined(separator: ","))")
    let differences = IndexSummaryComparison.differences(golden: golden, candidate: candidate)
    guard differences.isEmpty else {
        for difference in differences { print(difference) }
        fail("check 2 fails: \(differences.count) gating difference(s)")
    }
    print("check 2 passes: \(golden.gating.digests.count) digests and \(golden.gating.checks.count) checks are identical")
}

/// Check 3's results: each query's count and first 50 results in a candidate, such as a file
/// `mac-golden results` writes or one from the Linux index, against the golden file's. Each tie
/// group the candidate reorders is listed, and passes.
func compareResults(_ arguments: Arguments) throws {
    guard arguments.positional.count == 2 else { throw UsageError("compare-results takes golden results and a candidate") }
    let golden = try GoldenJSON.read(ResultsGolden.self, from: URL(fileURLWithPath: arguments.positional[0]))
    let candidate = try GoldenJSON.read(ResultsGolden.self, from: URL(fileURLWithPath: arguments.positional[1]))
    func made(_ provenance: Provenance) -> String {
        "\(provenance.tool) on \(provenance.platform.os), SQLite \(provenance.platform.sqlite ?? "unknown")"
    }
    print("information, not compared: golden by \(made(golden.provenance)); candidate by \(made(candidate.provenance))")
    let report = SearchParity.compare(golden: golden, candidate: candidate)
    for permutation in report.permutations { print("tie      \(permutation)") }
    if !report.otherScores.isEmpty {
        let queries = report.otherScores.count == 1 ? "1 passing query has" : "\(report.otherScores.count) passing queries have"
        print("information, not compared: \(queries) other score bits than the golden file's: \(report.otherScores.joined(separator: ", "))")
    }
    let groups = switch report.permutations.count {
    case 0: ""
    case 1: " (1 group, listed)"
    default: " (\(report.permutations.count) groups, each listed)"
    }
    let counts = "\(report.identical.count) identical and \(report.permuted.count) reordered only within Mac tie groups\(groups)"
    guard report.passes else {
        for difference in report.differences { print("differs  \(difference)") }
        let format = report.differences.count > report.differing.count ? "the format and " : ""
        fail("check 3's results fail: \(format)\(report.differing.count) of \(report.queryCount) queries differ; \(counts)")
    }
    print("check 3's results pass: \(report.queryCount) queries, \(counts)")
}

func parse(_ arguments: Arguments) throws {
    guard arguments.positional.count == 1 else { throw UsageError("parse takes one query list") }
    struct Line: Encodable {
        let id: String
        let parse: ParseRecord
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    for query in try QueryList.load(URL(fileURLWithPath: arguments.positional[0])) {
        print(String(decoding: try encoder.encode(Line(id: query.id, parse: ParseParity.parse(query))), as: UTF8.self))
    }
}

/// Check 4 on this machine. With no document, renders every row of the golden manifest along the
/// reader's path and again from one full parse per volume, compares that parse's persons and terms
/// with the reader's, and reports each difference. With a
/// volume and a document, renders that document along the reader's path, or from a full parse with
/// --full-parse, says whether it is the golden file's HTML, and writes it to --out's file. The HTML
/// never goes to standard output, where a debug build of the kit prints its parser's log.
func render(_ arguments: Arguments) async throws {
    let layout = try repository(arguments)
    let renderer = try ReaderRenderer(layout: layout)
    let (golden, stale) = try RenderParity.golden(layout)
    let directory = layout.golden.appendingPathComponent(GoldenFile.render.rawValue).deletingLastPathComponent()
    var problems = stale
    switch arguments.positional.count {
    case 0:
        guard !arguments.flags.contains("--full-parse"), arguments.options["--out"] == nil else {
            throw UsageError("--full-parse and --out need a volume and a document")
        }
        let clock = ContinuousClock()
        var start = clock.now
        let reader = try await renderer.readerPass(golden.rows.map { ($0.volume, $0.document) })
        let readerTime = clock.now - start
        start = clock.now
        let volumes = ParityFixtures.volumes.sorted()
        let (full, fullLists) = try await renderer.fullParsePass(volumes)
        let fullTime = clock.now - start
        for (pass, rendered, time) in [("the reader's path", reader, readerTime), ("one full parse per volume", full, fullTime)] {
            let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
            print("\(pass): \(rendered.count - mismatches.count) of \(golden.rows.count) rows identical, in \(milliseconds(time)) ms")
            problems += mismatches.map { "\(pass): \($0)" }
        }
        if full.map({ "\($0.volume)/\($0.document)" }) != golden.rows.map({ "\($0.volume)/\($0.document)" }) {
            problems.append("one full parse per volume yields \(full.count) rows, not the golden manifest's \(golden.rows.count) in its order")
        }
        // The HTML would be the same with other persons and terms, so the full parse's are compared
        // with the reader's.
        let readerLists = try await renderer.readerLists(volumes)
        for volume in volumes where fullLists[volume] != readerLists[volume] {
            problems.append("one full parse of \(volume) gives other persons or terms than parsePersons and parseTerms")
        }
    case 2:
        let (volume, document) = (arguments.positional[0], arguments.positional[1])
        let rendered: RenderedDocument
        if arguments.flags.contains("--full-parse") {
            rendered = try await renderer.fullParsePass([volume]).documents.first { $0.document == document }
                ?? RenderedDocument(volume: volume, document: document, html: nil)
        } else {
            rendered = try await renderer.readerPass([(volume, document)])[0]
        }
        if let html = rendered.html, let out = arguments.options["--out"] {
            try Data(html.utf8).write(to: URL(fileURLWithPath: out))
            print("wrote \(out)")
        }
        let mismatches = RenderParity.mismatches([rendered], golden: golden, directory: directory)
        if mismatches.isEmpty { print("\(volume)/\(document) is the golden file's HTML, byte for byte") }
        problems += mismatches.map(\.description)
    default:
        throw UsageError("render takes no arguments, or a volume and a document")
    }
    guard problems.isEmpty else {
        for problem in problems { print("problem  \(problem)") }
        fail("check 4 fails: \(problems.count) problem(s)")
    }
    print("check 4 passes")
}

/// Indexes TEI volumes with FRUSCoreKit, as checks 2 and 3 do, and says how it went: the fixtures
/// by default, or the volumes named, from --tei's folder, every .xml in it when none is named. The
/// data files come from the submodule's FRUSExplorer/Resources unless --resources names a folder.
/// It builds in a new temporary folder, which it removes, and prints each volume's documents; with
/// --metrics, each step's time, its documents per second and the peak memory, which session 6
/// records (build with -c release to measure); with --out, it keeps a copy of the index out of
/// write-ahead-log mode, which `summarize --any-volumes` reads.
func index(_ arguments: Arguments) async throws {
    let layout = try repository(arguments)
    let tei = arguments.options["--tei"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? layout.tei
    var volumes = arguments.positional
    if volumes.isEmpty {
        if arguments.options["--tei"] == nil {
            volumes = ParityFixtures.volumes
        } else {
            volumes = try FileManager.default.contentsOfDirectory(atPath: tei.path)
                .filter { $0.hasSuffix(".xml") }.map { String($0.dropLast(".xml".count)) }.sorted()
        }
    }
    guard !volumes.isEmpty else { throw UsageError("\(tei.path) holds no .xml file") }
    guard Set(volumes).count == volumes.count else { throw UsageError("a volume is named twice") }
    for volume in volumes {
        guard volume.range(of: "^[A-Za-z0-9._-]+$", options: .regularExpression) != nil else {
            throw UsageError("\(volume) is not a volume id")
        }
        guard FileManager.default.fileExists(atPath: tei.appendingPathComponent("\(volume).xml").path) else {
            fail("\(tei.path) has no \(volume).xml")
        }
    }
    let resources = arguments.options["--resources"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? layout.upstream.appendingPathComponent(ParityIndex.resourcesPath)
    let out = arguments.options["--out"].map { URL(fileURLWithPath: $0) }
    if let out, FileManager.default.fileExists(atPath: out.path) { fail("\(out.path) exists") }
    let scratch = FileManager.default.temporaryDirectory
        .appendingPathComponent("frus-parity-index-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratch) }

    let index = try await ParityIndex.build(volumes: volumes, tei: tei, resources: resources,
                                            database: scratch.appendingPathComponent("frus.db"))
    for volume in volumes { print("\(volume): \(index.documents[volume] ?? 0) documents") }
    print("\(volumes.count) volumes, \(index.documents.values.reduce(0, +)) documents, "
          + "\(ProcessInfo.processInfo.activeProcessorCount) processors; person rollup rebuilt: \(index.rollupRebuilt)")
    #if DEBUG
    print("a debug build: its timings are not measurements; build with -c release")
    #endif
    if arguments.flags.contains("--metrics") { print(index.metrics.report()) }
    if let out {
        try IndexCopy.rollbackJournal(of: index.database, to: out)
        let bytes = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int64) ?? nil
        print("wrote \(out.path)\(bytes.map { ", \($0) bytes" } ?? "")")
    }
}

func milliseconds(_ duration: Duration) -> Int64 {
    duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000
}

func checkGolden(_ arguments: Arguments) throws {
    guard arguments.positional.isEmpty else { throw UsageError("check-golden takes no arguments") }
    let layout = try repository(arguments)
    let report = GoldenValidation.validate(layout, sourceFilesRequired: true)
    var problems = report.problems
    for file in GoldenFile.allCases {
        if report.present.contains(file) { print("present  \(file.rawValue)") }
        if let reason = report.pending[file] { print("pending  \(file.rawValue): waits for \(reason)") }
    }
    if FileManager.default.fileExists(atPath: layout.queries.path) {
        let queries = try QueryList.load(layout.queries)
        let rules = try QueryList.loadRules(layout.rules)
        let text = try String(contentsOf: layout.queries, encoding: .utf8)
        problems += QueryListValidation.problems(queries: queries, rules: rules, text: text).map { "\(RepositoryLayout.queriesPath): \($0)" }
        print("query list: \(queries.count) queries over \(rules.count) rules")
        if report.present.contains(.expressions) {
            let golden = try GoldenJSON.read(ExpressionsGolden.self, from: layout.golden.appendingPathComponent(GoldenFile.expressions.rawValue))
            let mismatches = ParseParity.mismatches(queries: queries, golden: golden)
            problems += mismatches.map { "parse parity: \($0)" }
            print("parse parity: \(queries.count - Set(mismatches.map(\.id)).count) of \(queries.count) queries parse as the golden file says")
        }
    } else {
        problems.append("\(RepositoryLayout.queriesPath) is missing")
    }
    guard problems.isEmpty else {
        for problem in problems { print("problem  \(problem)") }
        fail("\(problems.count) problem(s) in \(layout.golden.path)")
    }
    print("golden files: \(report.present.count) present and valid, \(report.pending.count) pending")
}

/// Check 12's search times (S13b): each query's first page of 20 and its count through FRUSCoreKit's
/// SearchService over an export opened read-only and immutable, as the server opens it, one after the
/// other as `/api/v1/search` asks them; with --retained, the 7,500 results the app keeps too. By
/// default the parity queries that apply an exact term; --all times every query, and --ids those
/// named. With --out, it then writes their records as check 3 makes them, which compare-results
/// holds to another run's. Build with -c release to measure.
func timeSearch(_ arguments: Arguments) async throws {
    guard arguments.positional.count == 1 else { throw UsageError("time-search takes one index") }
    let layout = try repository(arguments)
    let database = URL(fileURLWithPath: arguments.positional[0])
    guard FileManager.default.fileExists(atPath: database.path) else { fail("\(database.path) does not exist") }
    let queriesPath = arguments.options["--queries"] ?? layout.queries.path
    var queries = try QueryList.load(URL(fileURLWithPath: queriesPath))
    if !arguments.flags.contains("--all") { queries = try SearchTiming.exactWordQueries(queries) }
    if let ids = arguments.options["--ids"] {
        let wanted = Set(ids.split(separator: ",").map(String.init))
        queries = queries.filter { wanted.contains($0.id) }
        guard queries.count == wanted.count else { throw UsageError("--ids names a query the list lacks") }
    }
    let resources = arguments.options["--resources"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        ?? layout.upstream.appendingPathComponent(ParityIndex.resourcesPath)
    let service = try SearchTiming.service(database: database, resources: resources)
    #if DEBUG
    print("a debug build: its timings are not measurements; build with -c release")
    #endif
    print("\(queries.count) queries over \(database.lastPathComponent), upstream \(layout.upstreamCommit()?.prefix(8) ?? "unknown"), on \(Platform.current().os), SQLite \(SearchTiming.sqliteVersion)")
    let records = try await SearchTiming.run(queries, service: service, retained: arguments.flags.contains("--retained")) { record in
        print(record.line)
        if let error = record.error { print("        refused: \(error)") }
    }
    print(SearchTiming.summary(records))
    if let out = arguments.options["--out"] {
        let written = try await SearchTiming.writeRecords(queries, service: service, queriesPath: queriesPath, layout: layout,
                                                          database: database, to: URL(fileURLWithPath: out))
        print("wrote \(out): \(written.count) queries' counts, first 50 results and tie tails, score bits included")
    }
}

/// GET against a server's base URL, for LiveAPI: a path with its query string, answered with the
/// status and the body. A request may take 15 minutes: over the full corpus an exact-word search
/// (`=Soviet`) took more than URLSession's default minute on a server that was busy (S10).
func httpGet(_ base: URL) -> (String) async throws -> LiveAPI.Response {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 900
    configuration.timeoutIntervalForResource = 3_600
    let session = URLSession(configuration: configuration)
    return { path in
        guard let url = URL(string: path, relativeTo: base) else { throw LiveAPI.Failure("\(path) is not a path") }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw LiveAPI.Failure("\(url.absoluteString) gave no HTTP response") }
        return (http.statusCode, data)
    }
}

/// What a server's status says of the index it serves, which a file made through its API records.
struct ServedStatus: Decodable {
    struct Index: Decodable {
        let documents: Int
        let volumes: Int
        let indexVersion: Int
        let appBuild: String?
        let exportedAt: String?
    }

    let version: String
    let index: Index?
}

/// Check 3 against a running server (S10): each query's record, read through its API with the
/// golden tool's loop, as a results file for compare-results. The file records what the server
/// says it serves, and the query list's records.
func results(_ arguments: Arguments) async throws {
    guard arguments.positional.isEmpty, let api = arguments.options["--api"], let base = URL(string: api),
          let out = arguments.options["--out"] else { throw UsageError("results takes --api <url> and --out <file>") }
    let layout = try repository(arguments)
    let queriesPath = arguments.options["--queries"] ?? layout.queries.path
    let queries = try QueryList.load(URL(fileURLWithPath: queriesPath))
    let fetch = httpGet(base)
    // Each request's time, for the slowest few, which check 3 does not compare.
    var times: [(path: String, seconds: Double)] = []
    let get: (String) async throws -> LiveAPI.Response = { path in
        let start = Date()
        defer { times.append((path, Date().timeIntervalSince(start))) }
        return try await fetch(path)
    }
    let response = try await get("/api/v1/status")
    guard response.status == 200, let index = try JSONDecoder().decode(ServedStatus.self, from: response.body).index else {
        fail("\(api) serves no index: import an export first")
    }
    let (records, anomalies) = await LiveAPI.results(queries, get: get)
    var inputs = [Provenance.recordsKey(RepositoryLayout.queriesPath): QueryList.recordDigest(queries), "served.api": api,
                  "served.documents": String(index.documents), "served.volumes": String(index.volumes)]
    inputs["served.appBuild"] = index.appBuild
    inputs["served.exportedAt"] = index.exportedAt
    let candidate = ResultsGolden(
        provenance: Provenance(tool: "frus-parity results --api", upstreamCommit: layout.upstreamCommit(),
                               appBuild: index.appBuild.flatMap { Int($0) }, indexVersion: index.indexVersion,
                               sourceDigest: try UpstreamDigest.compute(upstream: layout.upstream), inputs: inputs,
                               platform: .current()),
        queries: records)
    try GoldenJSON.write(candidate, to: URL(fileURLWithPath: out))
    let refused = records.filter { $0.error != nil }.count
    let tails = records.filter { !$0.tieTail.isEmpty }.count
    print("results: \(records.count) queries through \(api), \(refused) refused, \(tails) with ties past the 50th, over \(index.documents) documents in \(index.volumes) volumes; wrote \(out)")
    let total = times.reduce(0) { $0 + $1.seconds }
    print("information, not compared: \(times.count) requests in \(String(format: "%.0f", total)) s; the slowest:")
    for time in times.sorted(by: { $0.seconds > $1.seconds }).prefix(5) {
        print(String(format: "  %7.1f s  ", time.seconds) + (time.path.removingPercentEncoding ?? time.path))
    }
    guard anomalies.isEmpty else {
        for anomaly in anomalies { print("anomaly  \(anomaly)") }
        fail("\(anomalies.count) page(s) are not what check 3 asked for")
    }
}

/// Check 4 against a running server (S10): every row of a render folder, such as `mac-golden
/// render --tei --rows` writes, fetched as the reader's body and compared byte for byte with the
/// row's file, figure addresses mapped back.
func renderAPI(_ arguments: Arguments) async throws {
    guard arguments.positional.count == 1, let api = arguments.options["--api"], let base = URL(string: api) else {
        throw UsageError("render-api takes --api <url> and a render folder")
    }
    let directory = URL(fileURLWithPath: arguments.positional[0], isDirectory: true)
    let golden = try GoldenJSON.read(RenderGolden.self, from: directory.appendingPathComponent("manifest.json"))
    let rows = golden.rows.map { (volume: $0.volume, document: $0.document) }
    let volumes = Set(rows.map(\.volume)).sorted()
    print("information, not compared: \(golden.provenance.tool) at \(golden.provenance.upstreamCommit?.prefix(8) ?? "an unknown commit"), \(rows.count) rows in \(volumes.count) volumes, \(volumes.first ?? "") to \(volumes.last ?? "")")
    let (documents, figures) = try await LiveAPI.bodies(rows, get: httpGet(base))
    let mismatches = RenderParity.mismatches(documents, golden: golden, directory: directory)
    for mismatch in mismatches.prefix(50) { print("differs  \(mismatch)") }
    guard mismatches.isEmpty else { fail("check 4 fails: \(mismatches.count) of \(rows.count) rows differ") }
    print("check 4 through the API: \(rows.count) of \(rows.count) rows identical, \(figures.values.reduce(0, +)) figure images in \(figures.count) rows named by the server")
}

/// A section's own text against a running server: every section of every volume an export holds,
/// or of the volumes --volumes names, through the server's API, held to the kit's rule over the
/// export's rows, read through the kit's read-only open (`OwnTextCheck`). The export must be the one
/// the server serves. Each section's page is read, and each row's neighbours in the reader.
func ownText(_ arguments: Arguments) async throws {
    guard arguments.positional.count == 1, let api = arguments.options["--api"], let base = URL(string: api) else {
        throw UsageError("own-text takes --api <url> and the export the server serves")
    }
    let database = URL(fileURLWithPath: arguments.positional[0])
    guard FileManager.default.fileExists(atPath: database.path) else { fail("\(database.path) does not exist") }
    let volumes = try arguments.options["--volumes"].map { $0.split(separator: ",").map(String.init) }
        ?? OwnTextCheck.volumes(in: database)
    let pipeline = try OwnTextCheck.readOnlyPipeline(database)
    let get = httpGet(base)
    var report = OwnTextCheck.Report()
    let clock = ContinuousClock()
    let start = clock.now
    for (number, volume) in volumes.enumerated() {
        try await OwnTextCheck.check(try await OwnTextVolume(volume, pipeline: pipeline), get: get, into: &report)
        if (number + 1) % 50 == 0 { print("\(number + 1) of \(volumes.count) volumes: \(report.rows) rows, \(report.mismatches.count) differences") }
    }
    let seconds = (clock.now - start).components.seconds
    print(report.summary)
    for mismatch in report.mismatches.prefix(50) { print("differs  \(mismatch)") }
    guard report.mismatches.isEmpty else { fail("own text differs from the kit's rule in \(report.mismatches.count) places") }
    print("own text through the API is the kit's for every section, in \(seconds) s")
}

/// Check 6's samples (PLAN's S15c): highlights placed by offset over each golden row's flat text,
/// for the browser suite. Written to `--out`, never standard output, where a debug build of the kit
/// prints its parser's log.
func highlightSamples(_ arguments: Arguments) async throws {
    guard arguments.positional.isEmpty, let out = arguments.options["--out"] else {
        throw UsageError("highlight-samples takes --out <file>, such as \(HighlightSamples.path)")
    }
    let layout = try repository(arguments)
    let (golden, stale) = try RenderParity.golden(layout)
    guard stale.isEmpty else { fail(stale.joined(separator: "\n")) }
    let file = try await HighlightSamples.make(layout: layout, rows: golden.rows.map { ($0.volume, $0.document) })
    try GoldenJSON.write(file, to: URL(fileURLWithPath: out))
    print("check 6's samples: \(file.rows.count) rows, \(file.rows.map(\.samples.count).reduce(0, +)) highlights, in \(out)")
}

/// The golden spans' web cases (S15d): the RTF the codec writes for each case of
/// fixtures/rich-text/web/cases.json, beside it, for tools/mac-golden to read with the app's code.
func richTextFixtures(_ arguments: Arguments) throws {
    guard arguments.positional.isEmpty else { throw UsageError("rich-text-fixtures takes only --repo") }
    let layout = try repository(arguments)
    let count = try RichTextParity.writeWebFixtures(root: layout.root)
    print("the codec's RTF for \(count) web cases, in \(RichTextWebCases.path)'s folder")
}

let arguments = CommandLine.arguments.dropFirst()
do {
    switch arguments.first {
    case "summarize":
        try summarize(Arguments(arguments.dropFirst(), flags: ["--any-volumes"], options: ["--golden", "--upstream-commit", "--repo"]))
    case "compare-summary":
        try compareSummary(Arguments(arguments.dropFirst()))
    case "compare-results":
        try compareResults(Arguments(arguments.dropFirst()))
    case "results":
        try await results(Arguments(arguments.dropFirst(), options: ["--api", "--out", "--queries", "--repo"]))
    case "render-api":
        try await renderAPI(Arguments(arguments.dropFirst(), options: ["--api"]))
    case "parse":
        try parse(Arguments(arguments.dropFirst()))
    case "render":
        try await render(Arguments(arguments.dropFirst(), flags: ["--full-parse"], options: ["--out", "--repo"]))
    case "index":
        try await index(Arguments(arguments.dropFirst(), flags: ["--metrics"], options: ["--tei", "--resources", "--out", "--repo"]))
    case "check-golden":
        try checkGolden(Arguments(arguments.dropFirst(), options: ["--repo"]))
    case "own-text":
        try await ownText(Arguments(arguments.dropFirst(), options: ["--api", "--volumes"]))
    case "highlight-samples":
        try await highlightSamples(Arguments(arguments.dropFirst(), options: ["--out", "--repo"]))
    case "rich-text-fixtures":
        try richTextFixtures(Arguments(arguments.dropFirst(), options: ["--repo"]))
    case "time-search":
        try await timeSearch(Arguments(arguments.dropFirst(), flags: ["--all", "--retained"],
                                       options: ["--ids", "--out", "--queries", "--resources", "--repo"]))
    default:
        throw UsageError(arguments.first.map { "unknown command \($0)" } ?? "no command")
    }
} catch let error as UsageError {
    FileHandle.standardError.write(Data("frus-parity: \(error)\n\(usage)\n".utf8))
    exit(2)
} catch {
    fail("\(error)")
}
