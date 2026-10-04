// mac-golden: writes the parity harness's golden files (docs/SPEC.md, checks 3 and 4) by running
// the Mac app's own code, compiled from the submodule unmodified. scripts/make-golden drives it.
//
// Messages go to standard error. Standard output carries the app's own debug logging.

import Foundation

let usage = """
    usage: mac-golden render      [--repo <root>] [--out <dir>]
           mac-golden expressions [--repo <root>] [--queries <jsonl>] [--rules <tsv>] [--out <json>] [--db <file>]
           mac-golden results     --db <export> [--repo <root>] [--queries <jsonl>] [--out <json>]

      render       the reader's HTML of every fixture document    (default out: fixtures/golden/render)
      expressions  the parse and MATCH expressions of each query  (default out: fixtures/golden/queries.expressions.json)
                   --db compiles against a copy of that database instead of an empty one
      results      each query's count and first 50 results, over a copy of a three-volume export
                   (default out: fixtures/golden/queries.results.json)

    --repo defaults to the current directory. Paths are relative to the current directory.
    """

do {
    var arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    let repo = try Repository(root: arguments.take("--repo") ?? FileManager.default.currentDirectoryPath)
    switch arguments.command {
    case "render":
        let out = arguments.path("--out") ?? repo.url("fixtures/golden/render")
        try arguments.finish()
        try await renderGolden(repo: repo, out: out)
    case "expressions":
        let queries = arguments.path("--queries") ?? repo.url("fixtures/parity/queries.jsonl")
        let rules = arguments.path("--rules") ?? repo.url("fixtures/parity/rules.tsv")
        let out = arguments.path("--out") ?? repo.url("fixtures/golden/queries.expressions.json")
        let database = arguments.path("--db")
        try arguments.finish()
        try await expressionsGolden(repo: repo, queries: queries, rules: rules, out: out, database: database)
    case "results":
        guard let export = arguments.path("--db") else { throw ToolError("results needs --db <export>") }
        let queries = arguments.path("--queries") ?? repo.url("fixtures/parity/queries.jsonl")
        let out = arguments.path("--out") ?? repo.url("fixtures/golden/queries.results.json")
        try arguments.finish()
        try await resultsGolden(repo: repo, export: export, queries: queries, out: out)
    default:
        throw ToolError("unknown command \(arguments.command)")
    }
} catch let error as Arguments.UsageError {
    note("mac-golden: \(error.message)\n\(usage)")
    exit(2)
} catch {
    note("mac-golden: \(error)")
    exit(1)
}
