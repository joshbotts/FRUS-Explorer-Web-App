// The Query Inspector through the API, over the kit's fixture index imported as an export, beside the
// kit's own `QueryInspector` over the same index: every parity query's inspection, its scoped counts
// and the terms that match nothing are the kit's.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import Testing

@testable import FRUSLightAPI
@testable import FTS5Store

@Suite struct QueryInspectorAPIParityTests {
    /// An operand as the kit reports it, by its own fields, so the comparison reads the kit's value
    /// rather than the API's way of writing it.
    static func described(_ operand: ParsedOperand) -> String {
        "\(operand.text)|\(operand.rendered)|\(operand.kind)|\(operand.isNegated)|\(operand.isExact)|\(operand.isExactApplied)|\(operand.source)"
    }

    static func described(_ operand: SearchInspection.Operand) -> String {
        "\(operand.text)|\(operand.rendered)|\(operand.kind)|\(operand.isNegated)|\(operand.isExact)|\(operand.isExactApplied)|\(operand.source)"
    }

    static func described(_ term: InspectedOperand) -> String {
        "\(described(term.operand))|\(term.stem ?? "-")|\(term.scopedCount.map(String.init) ?? "-")|\(term.corpusDocumentFrequency.map(String.init) ?? "-")|\(term.corpusOccurrences.map(String.init) ?? "-")|\(term.corpusOccurrencesPerDocument.map { String($0.bitPattern) } ?? "-")|\(term.isStemBroadening)|\(term.showsStructuredTag)"
    }

    static func described(_ term: SearchInspection.Inspection.Term) -> String {
        "\(described(term.operand))|\(term.stem ?? "-")|\(term.scopedCount.map(String.init) ?? "-")|\(term.corpusDocumentFrequency.map(String.init) ?? "-")|\(term.corpusOccurrences.map(String.init) ?? "-")|\(term.corpusOccurrencesPerDocument.map { String($0.bitPattern) } ?? "-")|\(term.isStemBroadening)|\(term.showsStructuredTag)"
    }

    /// Every parity query's inspection through the API is the kit's over the same index, with both
    /// expensive passes: `inspect(parameters:indexedVolumeCount:)` out of the three volumes served,
    /// then `scopedCounts(for:parameters:)`, and `emptyConjuncts(parameters:)`. The queries reach every
    /// state the inspector reports, which the test counts.
    @Test func everyQueryIsInspectedAsTheKitInspectsIt() async throws {
        let queries = try QueryList.load(Repository.layout.queries)
        let inspector = QueryInspector(searchService: try await FixtureIndex.value().index.service)
        let answers = try await ServedFixture.run { client, _ in
            var answers: [SearchInspection] = []
            for query in queries {
                let uri = "/api/v1/search/inspect?\(APIParity.formEncode(query))&scopedCounts=true&emptyConjuncts=true"
                let response = try await client.execute(uri: uri, method: .get)
                guard response.status == .ok else { throw APIParityError("\(query.id): inspect answered \(response.status.code)") }
                answers.append(try ServedFixture.decode(SearchInspection.self, response))
            }
            return answers
        }

        var reached: [String: Int] = [:]
        for (query, answer) in zip(queries, answers) {
            let parameters = try LinuxSearch.parameters(query)
            let inspected = await inspector.inspect(parameters: parameters, indexedVolumeCount: 3)
            let kit = inspected.replacingOperands(await inspector.scopedCounts(for: inspected, parameters: parameters))
            let empty = await inspector.emptyConjuncts(parameters: parameters)
            guard let api = answer.inspection else {
                Issue.record("\(query.id): no inspection")
                continue
            }
            let context = "\(query.id) \(query.query)"
            #expect(api.indexedVolumeCount == 3, "\(context)")
            #expect(api.expression?.corpus == kit.expression?.corpus && api.expression?.userContent == kit.expression?.userContent, "\(context)")
            #expect(api.expression?.displayed == kit.expression?.displayed, "\(context)")
            #expect(api.expression?.expressionsDiffer == kit.expression?.expressionsDiffer, "\(context)")
            #expect(api.operands.map(Self.described) == kit.operands.map(Self.described), "\(context)")
            #expect(api.notApplied.map(Self.described) == kit.notApplied.map(Self.described), "\(context)")
            #expect(api.isFilterOnly == kit.isFilterOnly && api.isApproximate == kit.isApproximate && api.isRefused == kit.isRefused, "\(context)")
            #expect(api.malformedProximity == kit.malformedProximity, "\(context)")
            #expect(api.showsStrip == kit.showsStrip && api.showsApproximateCaption == kit.showsApproximateCaption, "\(context)")
            #expect(api.showsTermRows == kit.showsTermRows && api.hasOperands == kit.hasOperands, "\(context)")
            #expect(api.hasUncountedOperands == kit.hasUncountedOperands, "\(context)")
            #expect(answer.emptyConjuncts?.map(Self.described) == empty.map(Self.described), "\(context)")

            func reach(_ state: String, _ condition: Bool) { if condition { reached[state, default: 0] += 1 } }
            reach("expression", kit.expression != nil)
            reach("expressionsDiffer", kit.expression?.expressionsDiffer == true)
            reach("notApplied", !kit.notApplied.isEmpty)
            reach("approximate", kit.isApproximate)
            reach("refused", kit.isRefused)
            reach("malformedProximity", kit.malformedProximity != nil)
            reach("stemBroadening", kit.operands.contains(where: \.isStemBroadening))
            reach("structured", kit.operands.contains(where: \.showsStructuredTag))
            reach("exactApplied", kit.operands.contains { $0.operand.isExactApplied })
            reach("negated", kit.operands.contains { $0.operand.isNegated })
            reach("noStem", kit.operands.contains { $0.stem == nil && !$0.operand.isNegated })
            reach("scopedCount", kit.operands.contains { $0.scopedCount != nil })
            reach("emptyConjunct", !empty.isEmpty)
        }
        let states = ["expression", "expressionsDiffer", "notApplied", "approximate", "refused", "malformedProximity",
                      "stemBroadening", "structured", "exactApplied", "negated", "noStem", "scopedCount", "emptyConjunct"]
        #expect(states.filter { reached[$0, default: 0] == 0 }.isEmpty, "states no query reached: \(reached)")
        print("the Query Inspector through the API: \(queries.count) queries inspected as the kit inspects them, with their scoped counts and empty terms; \(states.map { "\($0) \(reached[$0, default: 0])" }.joined(separator: ", "))")
    }

    /// The browser app's line for a refused query names the parser's limit on nesting, which the
    /// Mac's strip reads from the parser and the web's copy writes out.
    @Test func theRefusedLineNamesTheParsersLimitOnNesting() throws {
        let copy = try String(contentsOf: RepositoryFiles.root.appendingPathComponent("web/src/copy.ts"), encoding: .utf8)
        #expect(copy.contains("or its parentheses nest more than \(FTS5InlineQueryParser.maximumGroupDepth) deep."))
    }
}
