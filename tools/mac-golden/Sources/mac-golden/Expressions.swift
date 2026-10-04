// expressions: check 3's compiled queries, from the app's SearchService. They depend on the app's
// source alone, so an empty database serves; --db shows that another gives the same records.

import Foundation
import ParityFormat
@testable import FRUSExplorer

func expressionsGolden(repo: Repository, queries queriesURL: URL, rules: URL, out: URL, database: URL?) async throws {
    let queries = try loadQueries(queriesURL, rules: rules)
    let scratch = try Scratch()
    defer { scratch.remove() }
    let url = try database.map { try scratch.copy(database: $0) } ?? scratch.directory.appendingPathComponent("frus.db")
    let service = try scratch.searchService(database: url)

    var records: [ExpressionRecord] = []
    for query in queries {
        let parameters = try searchParameters(query)
        var search = SearchExpressionRecord(corpus: nil, userContent: nil,
                                            exactTerms: SearchService.exactTerms(from: parameters), error: nil)
        do {
            let expressions = try await service.matchExpressions(for: parameters)
            search.corpus = expressions.corpus
            search.userContent = expressions.userContent
        } catch {
            search.error = String(describing: error)
        }
        records.append(ExpressionRecord(id: query.id, parse: ParseRecord(SearchService.parsedQuery(for: parameters)),
                                        search: search))
    }
    let golden = ExpressionsGolden(
        provenance: try repo.provenance(tool: "tools/mac-golden expressions", inputs: [queriesURL, rules]),
        queries: records
    )
    try GoldenJSON.write(golden, to: out)
    let errors = records.filter { $0.search.error != nil }.count
    note("expressions: \(records.count) queries, \(errors) refused, in \(repo.relativePath(out))")
}

extension ParseRecord {
    init(_ parsed: ParsedQuery) {
        self.init(expression: parsed.expression, exactTerms: parsed.exactTerms, isApproximate: parsed.isApproximate,
                  malformedProximity: parsed.malformedProximity.map(MalformedProximityRecord.init),
                  operands: parsed.operands.map(OperandRecord.init),
                  droppedOperands: parsed.droppedOperands.map(OperandRecord.init))
    }
}

extension MalformedProximityRecord {
    init(_ malformed: MalformedProximity) {
        switch malformed {
        case .operatorInside(let text): self.init(kind: "operatorInside", text: text)
        case .invalidDistance(let text): self.init(kind: "invalidDistance", text: text)
        }
    }
}

extension OperandRecord {
    init(_ operand: ParsedOperand) {
        self.init(text: operand.text, rendered: operand.rendered, kind: "\(operand.kind)", isNegated: operand.isNegated,
                  isExact: operand.isExact, isExactApplied: operand.isExactApplied, source: "\(operand.source)")
    }
}
