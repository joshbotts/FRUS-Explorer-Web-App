// The golden files: which are present and which wait, whether the present ones are current and
// whole, and the checks that read them once they land.

import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct GoldenTests {
    // MARK: - The committed golden files

    /// Only a file made from the owner's export may wait. One made from the app's source alone is
    /// made in the session that changes what it depends on.
    @Test func committedGoldenFilesAreCurrentAndWhole() throws {
        let report = GoldenValidation.validate(Repository.layout)
        #expect(report.problems.isEmpty, "\(report.problems.joined(separator: "\n"))")
        #expect(report.present.count + report.pending.count == GoldenFile.allCases.count)
        for file in GoldenFile.allCases {
            guard let reason = report.pending[file] else { continue }
            if file.needsExport {
                print("\(file.rawValue) is pending: it waits for \(reason)")
            } else {
                Issue.record(Self.mustNotWait(file))
            }
        }
    }

    static func mustNotWait(_ file: GoldenFile) -> Comment {
        "\(file.rawValue) is made from the app's source alone and must be committed, not pending: run scripts/make-golden"
    }

    @Test func eachPendingFileSaysWhatItWaitsFor() throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        for file in GoldenFile.allCases {
            if case .pending(let reason) = status.states[file] {
                #expect(reason.contains("scripts/make-golden"), "\(file.rawValue): \(reason)")
            }
        }
    }

    /// Check 4's golden HTML is whole. It comes from the app's source alone, so it is never
    /// pending. RenderParityTests compares it with FRUSCoreKit's rendering.
    @Test func renderGoldenIsWhole() throws {
        let status = try GoldenStatus(directory: Repository.layout.golden)
        switch status.states[.render] {
        case .present:
            let golden = try GoldenJSON.read(RenderGolden.self, from: status.url(.render))
            let problems = GoldenValidation.renderProblems(golden, directory: status.url(.render).deletingLastPathComponent())
            #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
            print("\(GoldenFile.render.rawValue): \(golden.rows.count) documents, each present and matching its manifest row")
        case .pending:
            Issue.record(Self.mustNotWait(.render))
        case nil:
            Issue.record("GoldenStatus has no state for \(GoldenFile.render.rawValue)")
        }
    }

    // MARK: - GoldenStatus

    @Test func statusReadsPresentAndPendingFiles() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let golden = directory.url
            try writePending(in: golden, except: .expressions, .indexSummary)
            for file in [GoldenFile.expressions, .indexSummary] {
                try Data("{}".utf8).write(to: golden.appendingPathComponent(file.rawValue))
            }
            let status = try GoldenStatus(directory: golden)
            #expect(status.states[.expressions] == .present)
            #expect(status.states[.indexSummary] == .present)
            #expect(status.states[.render] == .pending("the tests"))
            #expect(status.states[.results] == .pending("the tests"))
        }
    }

    @Test func statusRefusesAFileBothPresentAndPending() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            try writePending(in: directory.url)
            try Data("{}".utf8).write(to: directory.url.appendingPathComponent(GoldenFile.results.rawValue))
            #expect(throws: GoldenError.malformed("PENDING", "queries.results.json exists but is still listed as pending")) {
                try GoldenStatus(directory: directory.url)
            }
        }
    }

    @Test func statusRefusesAFileNeitherPresentNorPending() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            try writePending(in: directory.url, except: .render)
            #expect(throws: GoldenError.malformed("PENDING", "render/manifest.json is missing and not listed as pending")) {
                try GoldenStatus(directory: directory.url)
            }
        }
    }

    @Test func statusRefusesAMalformedLine() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            try Data("render/manifest.json waits\n".utf8).write(to: directory.url.appendingPathComponent(GoldenStatus.pendingFile))
            #expect(throws: GoldenError.self) { try GoldenStatus(directory: directory.url) }
        }
    }

    // MARK: - Integrity of each kind of golden file

    @Test func renderIntegrityFindsEachProblem() throws {
        let directory = try TemporaryDirectory()
        try withExtendedLifetime(directory) {
            let folder = directory.url
            var rows: [RenderRow] = []
            for volume in ParityFixtures.volumes {
                for document in ["d1", "d2"] {
                    let html = "<p class=\"doc\">\(volume) \(document)</p>"
                    let path = folder.appendingPathComponent(RenderGolden.htmlPath(volume: volume, document: document))
                    try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Data(html.utf8).write(to: path)
                    rows.append(RenderRow(volume: volume, document: document, html: html))
                }
            }
            let golden = RenderGolden(provenance: Self.provenance, configuration: "tests", rows: rows)
            #expect(GoldenValidation.renderProblems(golden, directory: folder) == [])

            var damaged = golden
            damaged.rows[0].bytes += 1
            damaged.rows.append(damaged.rows[1])
            damaged.rows.removeAll { $0.volume == "frus1969-76ve09p1" && $0.document == "d2" }
            damaged.rows.append(RenderRow(volume: "frus1969-76ve09p1", document: "d9", sha256: "", bytes: 0))
            let problems = GoldenValidation.renderProblems(damaged, directory: folder)
            #expect(problems == [
                "render/manifest.json: html/frus1894Nicaragua/d1.html is \(rows[0].bytes) bytes with SHA-256 \(rows[0].sha256.prefix(12)); the manifest says \(rows[0].bytes + 1) bytes, \(rows[0].sha256.prefix(12))",
                "render/manifest.json: frus1894Nicaragua d2 is listed twice",
                "render/manifest.json: html/frus1969-76ve09p1/d9.html is missing",
                "render/manifest.json: html/frus1969-76ve09p1/d2.html is not in the manifest",
                "render/manifest.json: the rows are not grouped by volume in sorted order",
            ])

            var partial = golden
            partial.rows.removeAll { $0.volume == "frus1894Nicaragua" }
            partial.rows.swapAt(0, 2)
            let coverage = GoldenValidation.renderProblems(partial, directory: folder)
            #expect(coverage.contains("render/manifest.json: the rows cover frus1961-63v06, frus1969-76ve09p1, not exactly the fixtures frus1894Nicaragua, frus1961-63v06, frus1969-76ve09p1"))
            #expect(coverage.contains("render/manifest.json: the rows are not grouped by volume in sorted order"))
        }
    }

    @Test func resultsSanityFindsEachProblem() {
        let queries = [ParityQuery(id: "q001", rule: "R01", query: "treaty"), ParityQuery(id: "q002", rule: "R01", query: "canal")]
        let good = ResultRecord(id: "q001", count: 2, top: ["v/d1", "v/d2"], scoreBits: ["bfe0000000000000", "bfd0000000000000"])
        let golden = ResultsGolden(provenance: Self.provenance, queries: [
            good,
            ResultRecord(id: "q001", count: 1, top: ["v/d1"], scoreBits: [], tieTail: ["v/d3"]),
            ResultRecord(id: "q003", count: 0, top: [], scoreBits: []),
        ])
        #expect(GoldenValidation.resultsProblems(golden, queries: queries) == [
            "queries.results.json: q001 has two records",
            "queries.results.json: no record for q002",
            "queries.results.json: records for queries not in the list: q003",
            "queries.results.json: q001 has 0 scores for 1 results",
            "queries.results.json: q001 has 0 scores for 1 tied results after the 50th",
        ])
        #expect(GoldenValidation.resultsProblems(ResultsGolden(provenance: Self.provenance, queries: [good, ResultRecord(id: "q002", count: nil, top: [], scoreBits: [], error: "emptyQuery")]),
                                                 queries: queries).isEmpty)
    }

    @Test func indexSummarySanityNeedsTheFixturesAndPassingChecks() throws {
        let summary = try summarize(ParityExport())
        #expect(GoldenValidation.indexSummaryProblems(summary).isEmpty)

        var export = ParityExport()
        export.volumes = ["frus1961-63v06", "frus1969-76ve09p1"]
        let other = try summarize(export, anyVolumes: true, fullCheckLimit: 0)
        #expect(GoldenValidation.indexSummaryProblems(other) == [
            "index-summary.json: it summarizes frus1961-63v06, frus1969-76ve09p1, not exactly the fixtures",
            "index-summary.json: it was made without the integrity checks",
        ])

        var failing = summary
        failing.gating.checks["frus_documents.docsize_orphans"] = "2"
        #expect(GoldenValidation.indexSummaryProblems(failing) == ["index-summary.json: frus_documents.docsize_orphans: is 2, expected 0"])
    }

    // MARK: - Required inputs

    /// Each golden file records every input it depends on; without one it could not go stale.
    @Test(arguments: GoldenFile.allCases)
    func eachRequiredInputMustBeRecorded(_ file: GoldenFile) throws {
        let repository = try GoldenRepository()
        try writePending(in: repository.layout.golden, except: .render, .expressions, .results, .indexSummary)
        for each in GoldenFile.allCases { try repository.write(each) }
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems == [])

        let required = GoldenValidation.requiredInputs(file)
        #expect(Set(required).isSubset(of: try repository.inputs(file).keys))
        for key in required {
            try repository.write(file) { $0.inputs[key] = nil }
            #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems
                == ["\(file.rawValue): it was made without recording \(key). Run scripts/make-golden"])
        }
    }

    @Test func requiredInputsNameTheFixturesTheQueriesAndTheStamp() {
        let tei = ["fixtures/tei/frus1894Nicaragua.xml", "fixtures/tei/frus1961-63v06.xml",
                   "fixtures/tei/frus1969-76ve09p1.xml", "fixtures/tei/SHA256SUMS"]
        let stamp = ["app_build", "current_index_version", "exported_at", "installed_index_version", "my_writing_included"]
            .map { "research_provenance.\($0)" }
        #expect(GoldenValidation.requiredInputs(.render) == tei)
        #expect(GoldenValidation.requiredInputs(.expressions) == ["fixtures/parity/queries.jsonl#records"])
        #expect(GoldenValidation.requiredInputs(.results) == ["fixtures/parity/queries.jsonl#records"] + tei + stamp)
        #expect(GoldenValidation.requiredInputs(.indexSummary) == tei + stamp)
    }

    /// A file made from an export must come from the pinned build, at the pin's index version.
    @Test(arguments: [GoldenFile.results, .indexSummary])
    func anExportFromAnotherBuildIsReported(_ file: GoldenFile) throws {
        let repository = try GoldenRepository()
        try writePending(in: repository.layout.golden, except: file)
        try repository.write(file)
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems == [])

        try repository.write(file) { $0.inputs["research_provenance.app_build"] = "48" }
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems
            == ["\(file.rawValue): its export was made by app build 48, but it records the pin's build as 49: export from the pinned build"])

        try repository.write(file) { $0.appBuild = nil }
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems
            == ["\(file.rawValue): its export was made by app build 49, but it records the pin's build as none: export from the pinned build"])

        try repository.write(file) {
            $0.inputs["research_provenance.installed_index_version"] = "64"
            $0.inputs["research_provenance.current_index_version"] = "66"
        }
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems == [
            "\(file.rawValue): its export's research_provenance.installed_index_version is 64, but it was made at index version 65",
            "\(file.rawValue): its export's research_provenance.current_index_version is 66, but it was made at index version 65",
        ])
    }

    /// The results and the index summary must come from one export.
    @Test func theTwoExportFilesMustComeFromOneExport() throws {
        let repository = try GoldenRepository()
        try writePending(in: repository.layout.golden, except: .results, .indexSummary)
        try repository.write(.results)
        try repository.write(.indexSummary)
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems == [])

        try repository.write(.indexSummary) {
            $0.inputs["research_provenance.exported_at"] = "2026-11-01T09:00:00Z"
            $0.inputs["research_provenance.semantic_provenance_digest"] = "only in one"
        }
        #expect(GoldenValidation.validate(repository.layout, sourceDigest: "current").problems == [
            "queries.results.json and index-summary.json come from different exports: research_provenance.exported_at is 2026-10-03T15:14:19Z in one and 2026-11-01T09:00:00Z in the other. Make both from one export with scripts/make-golden --export",
        ])
    }

    static let provenance = Provenance(tool: "frus-parity tests", upstreamCommit: nil, appBuild: 49,
                                       indexVersion: IndexCompatibility.supportedIndexVersion, sourceDigest: "",
                                       inputs: [:], platform: .current())
}

/// A repository of its own in a temporary directory: stand-in fixtures, a query list, and the
/// golden files a test writes, each made from them with every input recorded.
struct GoldenRepository {
    let directory: TemporaryDirectory
    let layout: RepositoryLayout

    static let queries = [ParityQuery(id: "q001", rule: "R01", query: "treaty"), ParityQuery(id: "q002", rule: "R01", query: "canal")]
    static let stamp = [
        "app_build": "49", "app_version": "0.2", "current_index_version": "65", "exported_at": "2026-10-03T15:14:19Z",
        "installed_index_version": "65", "my_writing_included": "0",
    ]

    init() throws {
        directory = try TemporaryDirectory()
        layout = RepositoryLayout(root: directory.url)
        try writeTEIFixtures(to: layout.tei)
        try writeQueries(try Self.queries.map(ParseParityTests.line), to: layout.queries)
    }

    /// What the tools record for `file`: the fixtures, the query list's records and the stamp, as
    /// it depends on them.
    func inputs(_ file: GoldenFile) throws -> [String: String] {
        let tei = try ParityFixtures.verifiedInputs(tei: layout.tei)
        let records = [Provenance.recordsKey(RepositoryLayout.queriesPath): QueryList.recordDigest(Self.queries)]
        var inputs: [String: String]
        switch file {
        case .render, .indexSummary: inputs = tei
        case .expressions: inputs = records
        case .results: inputs = tei.merging(records) { a, _ in a }
        }
        if file.needsExport {
            for (key, value) in Self.stamp { inputs["research_provenance.\(key)"] = value }
        }
        return inputs
    }

    /// Writes `file`, whole, made from this repository's inputs, with `edit` applied to its provenance.
    func write(_ file: GoldenFile, _ edit: (inout Provenance) -> Void = { _ in }) throws {
        var provenance = Provenance(tool: "frus-parity tests", upstreamCommit: nil, appBuild: 49,
                                    indexVersion: IndexCompatibility.supportedIndexVersion, sourceDigest: "current",
                                    inputs: try inputs(file), platform: .current())
        edit(&provenance)
        let url = layout.golden.appendingPathComponent(file.rawValue)
        switch file {
        case .render:
            var rows: [RenderRow] = []
            for volume in ParityFixtures.volumes {
                let html = "<p class=\"doc\">\(volume) d1</p>"
                let path = url.deletingLastPathComponent().appendingPathComponent(RenderGolden.htmlPath(volume: volume, document: "d1"))
                try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(html.utf8).write(to: path)
                rows.append(RenderRow(volume: volume, document: "d1", html: html))
            }
            try GoldenJSON.write(RenderGolden(provenance: provenance, configuration: "tests", rows: rows), to: url)
        case .expressions:
            var golden = ParseParityTests.golden(for: Self.queries, sourceDigest: "current")
            golden.provenance = provenance
            try GoldenJSON.write(golden, to: url)
        case .results:
            let records = Self.queries.map { ResultRecord(id: $0.id, count: 0, top: [], scoreBits: []) }
            try GoldenJSON.write(ResultsGolden(provenance: provenance, queries: records), to: url)
        case .indexSummary:
            var summary = try summarize(ParityExport())
            summary.provenance = provenance
            try GoldenJSON.write(summary, to: url)
        }
    }
}
