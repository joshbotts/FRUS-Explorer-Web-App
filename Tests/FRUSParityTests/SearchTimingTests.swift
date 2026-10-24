// frus-parity time-search over the fixture index (S13b): the queries it times by default are the
// parity queries the golden expressions give exact terms, and it times the server's search, so each
// count it finds is the golden file's. While the golden results wait for the owner's export, the
// test still times every query and checks that none is refused.

import FRUSLightTestSupport
import FRUSParity
import Foundation
import ParityFormat
import Testing

@Suite struct SearchTimingTests {
    @Test func theExactWordQueriesAreTimedOverTheServersSearch() async throws {
        let built = try await FixtureIndex.value()
        let directory = try TemporaryDirectory()
        let database = directory.url.appendingPathComponent("frus.db")
        try FileManager.default.copyItem(at: built.copy, to: database)
        let layout = Repository.layout
        let golden = layout.golden

        let exact = try SearchTiming.exactWordQueries(try QueryList.load(layout.queries))
        let expressions = try GoldenJSON.read(ExpressionsGolden.self, from: golden.appendingPathComponent(GoldenFile.expressions.rawValue))
        #expect(exact.map(\.id) == expressions.queries.filter { !$0.search.exactTerms.isEmpty }.map(\.id))
        #expect(exact.count == 45)

        let service = try SearchTiming.service(database: database,
                                               resources: layout.upstream.appendingPathComponent(ParityIndex.resourcesPath))
        let records = try await SearchTiming.run(exact, service: service, retained: true)
        #expect(records.map(\.id) == exact.map(\.id))
        for record in records {
            #expect(record.page >= 0 && record.counting >= 0 && record.retained != nil, "\(record.id)")
        }
        switch try GoldenValidation.load(.results, as: ResultsGolden.self, layout: layout) {
        case .present(let results, _):
            let counts = Dictionary(uniqueKeysWithValues: results.queries.map { ($0.id, $0.count) })
            for record in records {
                #expect(record.error == nil && record.count == counts[record.id] ?? nil, "\(record.id)")
            }
        case .pending(let reason):
            print("\(GoldenFile.results.rawValue) is pending: it waits for \(reason)")
            for record in records { #expect(record.error == nil, "\(record.id)") }
        }
        print(SearchTiming.summary(records))
    }
}
