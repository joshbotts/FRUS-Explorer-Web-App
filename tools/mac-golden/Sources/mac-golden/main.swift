// mac-golden: writes the parity harness's golden files (docs/SPEC.md, checks 3 and 4) by running
// the Mac app's own code, compiled from the submodule unmodified. scripts/make-golden drives it.
//
// Messages go to standard error. Standard output carries the app's own debug logging.

import Foundation

let usage = """
    usage: mac-golden render      [--repo <root>] [--out <dir>]
           mac-golden render      --tei <dir> --rows <tsv> --out <dir> [--repo <root>]
           mac-golden expressions [--repo <root>] [--queries <jsonl>] [--rules <tsv>] [--out <json>] [--db <file>]
           mac-golden results     --db <export> [--any-volumes] [--repo <root>] [--queries <jsonl>] [--out <json>]
           mac-golden rich-text   [--repo <root>] [--out <json>]

      render       the reader's HTML of every fixture document    (default out: fixtures/golden/render)
                   it replaces <dir>/html and <dir>/manifest.json, and refuses a <dir> holding either without a render manifest
                   with --tei and --rows, the rows a TSV file names (volume<TAB>document), from that folder's
                   volumes, to an --out outside fixtures/golden, with the bundled broken-refs index applied
      expressions  the parse and MATCH expressions of each query  (default out: fixtures/golden/queries.expressions.json)
                   --db compiles against a copy of that database instead of an empty one
      results      each query's count and first 50 results, over a copy of a three-volume export
                   (default out: fixtures/golden/queries.results.json); --any-volumes takes any export
                   from the pinned build, such as the full corpus
      rich-text    the golden spans: the RTF the note editor writes for each formatting it offers, and the
                   app's reading of it, of fixtures/rich-text/read and of the web codec's fixtures/rich-text/web
                   (default out: fixtures/golden/rich-text/spans.json)

    --repo defaults to the current directory. Paths are relative to the current directory.
    """

do {
    var arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    let repo = try Repository(root: arguments.take("--repo") ?? FileManager.default.currentDirectoryPath)
    switch arguments.command {
    case "render":
        let out = arguments.path("--out")
        let tei = arguments.path("--tei"), rows = arguments.path("--rows")
        try arguments.finish()
        switch (tei, rows, out) {
        case (nil, nil, _):
            try await renderGolden(repo: repo, out: out ?? repo.url("fixtures/golden/render"))
        case let (tei?, rows?, out?):
            try await renderSample(repo: repo, tei: tei, rowsFile: rows, out: out)
        default:
            throw Arguments.UsageError(message: "render takes --tei, --rows and --out together")
        }
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
        let anyVolumes = arguments.flag("--any-volumes")
        try arguments.finish()
        try await resultsGolden(repo: repo, export: export, queries: queries, out: out, anyVolumes: anyVolumes)
    case "rich-text":
        let out = arguments.path("--out") ?? repo.url(RichTextPaths.golden)
        try arguments.finish()
        try await MainActor.run { try richTextGolden(repo: repo, out: out) }
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
