// frus-parity: the parity harness's command line (docs/SPEC.md, Verification, checks 2-4).
//
//   frus-parity summarize <db> [--any-volumes] [--golden <out.json>] [--upstream-commit <sha>] [--repo <root>]
//   frus-parity compare-summary <golden.json> <candidate.json>
//   frus-parity parse <queries.jsonl>
//   frus-parity render [<volume> <document> [--full-parse] [--out <file>]] [--repo <root>]
//   frus-parity check-golden [--repo <root>]
//
// The repository is found from the current directory unless --repo names it. Exit status: 0 when
// the check passes, 1 on a refusal, a difference or a problem, 2 on a usage error.

import FRUSParity
import Foundation
import ParityFormat

let usage = """
    usage: frus-parity summarize <db> [--any-volumes] [--golden <out.json>] [--upstream-commit <sha>] [--repo <root>]
           frus-parity compare-summary <golden.json> <candidate.json>
           frus-parity parse <queries.jsonl>
           frus-parity render [<volume> <document> [--full-parse] [--out <file>]] [--repo <root>]
           frus-parity check-golden [--repo <root>]
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
/// reader's path and again from one full parse per volume, and reports each difference. With a
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
        let full = try await renderer.fullParsePass(ParityFixtures.volumes.sorted())
        let fullTime = clock.now - start
        for (pass, rendered, time) in [("the reader's path", reader, readerTime), ("one full parse per volume", full, fullTime)] {
            let mismatches = RenderParity.mismatches(rendered, golden: golden, directory: directory)
            print("\(pass): \(rendered.count - mismatches.count) of \(golden.rows.count) rows identical, in \(milliseconds(time)) ms")
            problems += mismatches.map { "\(pass): \($0)" }
        }
        if full.map({ "\($0.volume)/\($0.document)" }) != golden.rows.map({ "\($0.volume)/\($0.document)" }) {
            problems.append("one full parse per volume yields \(full.count) rows, not the golden manifest's \(golden.rows.count) in its order")
        }
    case 2:
        let (volume, document) = (arguments.positional[0], arguments.positional[1])
        let rendered: RenderedDocument
        if arguments.flags.contains("--full-parse") {
            rendered = try await renderer.fullParsePass([volume]).first { $0.document == document }
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

let arguments = CommandLine.arguments.dropFirst()
do {
    switch arguments.first {
    case "summarize":
        try summarize(Arguments(arguments.dropFirst(), flags: ["--any-volumes"], options: ["--golden", "--upstream-commit", "--repo"]))
    case "compare-summary":
        try compareSummary(Arguments(arguments.dropFirst()))
    case "parse":
        try parse(Arguments(arguments.dropFirst()))
    case "render":
        try await render(Arguments(arguments.dropFirst(), flags: ["--full-parse"], options: ["--out", "--repo"]))
    case "check-golden":
        try checkGolden(Arguments(arguments.dropFirst(), options: ["--repo"]))
    default:
        throw UsageError(arguments.first.map { "unknown command \($0)" } ?? "no command")
    }
} catch let error as UsageError {
    FileHandle.standardError.write(Data("frus-parity: \(error)\n\(usage)\n".utf8))
    exit(2)
} catch {
    fail("\(error)")
}
