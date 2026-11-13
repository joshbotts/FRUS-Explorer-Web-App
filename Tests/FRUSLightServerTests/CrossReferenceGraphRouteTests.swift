// The cross-reference graph's route (PLAN's S23e), over the synthetic export: what a request may ask and
// what is refused, the canvas a timeline is laid out on, FRUS-Explorer#1893's narrowest width among it, and
// the answer while no index is served. The graph itself is held to the kit's over the fixture index in
// `CrossReferenceGraphParityTests`.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CrossReferenceGraphRouteTests {
    static let volume = UserHalfSearchTests.volume

    @Test func theGraphsRequestsAndRefusals() async throws {
        let fixture = try await UserDataFixture(indexed: true)
        defer { withExtendedLifetime(fixture) {} }
        try await fixture.app.test(.router) { client in
            let base = "/api/v1/volumes/\(Self.volume)/documents/d1/graph"
            let graph = try decode(DocumentGraph.self, try await client.execute(uri: base, method: .get))
            #expect(graph.centralKey == "\(Self.volume)/d1" && graph.chosenDegree == nil && graph.chosenLayout == nil)
            #expect(graph.nodes.first?.id == graph.centralKey && graph.nodes.first?.kind == "central" && graph.nodes.first?.degree == 0)
            #expect(graph.degree == (graph.widened ? 2 : 1))
            #expect(graph.layout == (graph.timelineEligible ? "timeline" : "network") && (graph.timeline != nil) == graph.timelineEligible)
            // The degree and layout chosen are kept, and answered as chosen.
            let deep = try decode(DocumentGraph.self, try await client.execute(uri: "\(base)?degree=3&layout=network", method: .get))
            #expect(deep.chosenDegree == 3 && deep.degree == 3 && !deep.widened && deep.chosenLayout == "network")
            #expect(deep.layout == "network" && deep.timeline == nil)
            for (query, code) in [
                ("degree=0", "INVALID_PARAMETER"), ("degree=4", "INVALID_PARAMETER"), ("degree=two", "INVALID_PARAMETER"),
                ("layout=circle", "INVALID_PARAMETER"), ("width=0", "INVALID_PARAMETER"), ("height=4097", "INVALID_PARAMETER"),
                ("expand=everything", "INVALID_PARAMETER"), ("expand=cluster/inbound/", "INVALID_PARAMETER"),
                ("expandDates=cluster/inbound/frus1961-63v06", "INVALID_PARAMETER"), ("from=1", "INVALID_PARAMETER"),
                ("from=5&to=5", "INVALID_PARAMETER"), ("from=a&to=b", "INVALID_PARAMETER"), ("from=nan&to=1", "INVALID_PARAMETER"),
                ("degree=1&degree=2", "INVALID_PARAMETER"), ("scope=all", "UNKNOWN_PARAMETER"),
            ] {
                #expect(problemCode(try await client.execute(uri: "\(base)?\(query)", method: .get)) == code, "\(query)")
            }
            let many = (0...CrossReferenceGraphRoutes.maximumExpanded).map { "expand=cluster/inbound/v\($0)" }.joined(separator: "&")
            #expect(problemCode(try await client.execute(uri: "\(base)?\(many)", method: .get)) == "INVALID_PARAMETER")
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/frus1800nowhere/documents/d1/graph", method: .get)) == "VOLUME_NOT_FOUND")
            let long = String(repeating: "d", count: 257)
            #expect(problemCode(try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/\(long)/graph", method: .get))
                    == "INVALID_PARAMETER")
            // A document the index does not hold is still drawn, with what the bundled index says cites it.
            let unheld = try decode(DocumentGraph.self, try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/d999/graph", method: .get))
            #expect(unheld.nodes.first?.kind == "central" && unheld.nodes.first?.opens == false)
        }
        let waiting = try await UserDataFixture()
        defer { withExtendedLifetime(waiting) {} }
        try await waiting.app.test(.router) { client in
            let response = try await client.execute(uri: "/api/v1/volumes/\(Self.volume)/documents/d1/graph", method: .get)
            #expect(response.status == .serviceUnavailable && problemCode(response) == "INDEX_NOT_READY")
        }
    }

    /// The request's state as the route reads it: the canvas, the clusters and the brushed window.
    @Test func aRequestsStateIsReadAsTheViewModelHoldsIt() throws {
        let plain = try CrossReferenceGraphRoutes.graphRequest(try FormQuery(nil))
        #expect(plain == GraphRequest())
        #expect(plain.width == 960 && plain.height == 560 && plain.chosenDegree == nil && plain.chosenLayout == nil && plain.domain == nil)
        let asked = try CrossReferenceGraphRoutes.graphRequest(try FormQuery(
            "degree=2&layout=timeline&width=50&height=300&expand=cluster/outbound/frus1952-54v02p1&expandDates=datecluster/frus1961-63v06/d4&from=-1.5&to=2e3"))
        #expect(asked.chosenDegree == 2 && asked.chosenLayout == .timeline && asked.width == 50 && asked.height == 300)
        #expect(asked.expandedClusters == ["cluster/outbound/frus1952-54v02p1"] && asked.expandedDateClusters == ["datecluster/frus1961-63v06/d4"])
        #expect(asked.domain == -1.5...2_000)
        // FRUS-Explorer#1893: the width asked is kept as asked; the timeline is laid out at 116 or more.
        #expect(CrossReferenceGraphRoutes.narrowestTimeline == 116)
    }

    /// A timeline asked narrower than 116 pt is laid out at 116 (FRUS-Explorer#1893), where the kit's layout
    /// would trap; at 116 or wider, at the width asked.
    @Test func aNarrowTimelineIsLaidOutAt116() throws {
        let nodes = [
            DisplayNode(id: "v/d1", kind: .central, metadata: nil, isDownloaded: true, degree: 0),
            DisplayNode(id: "v/d2", kind: .inbound, metadata: nil, isDownloaded: true),
            DisplayNode(id: "v/d3", kind: .outbound, metadata: nil, isDownloaded: true),
        ]
        let edges = [DisplayEdge(source: "v/d2", target: "v/d1", referenceType: .footnote, context: nil),
                     DisplayEdge(source: "v/d1", target: "v/d3", referenceType: .footnote, context: nil)]
        let dates: [String: TimeInterval] = ["v/d1": 0, "v/d2": 86_400, "v/d3": -86_400]
        for (asked, laid) in [(1.0, 116.0), (50, 116), (115, 116), (116, 116), (117, 117), (900, 900)] {
            var request = GraphRequest()
            request.width = asked
            let timeline = CrossReferenceGraphRoutes.laidOutTimeline(nodes: nodes, edges: edges, dateValues: dates, centralKey: "v/d1",
                                                                     request: request, counts: [:], metadata: [:])
            #expect(timeline.width == laid && timeline.positions.count == 3, "\(asked)")
            #expect(timeline.positions.values.allSatisfy { $0.x >= 0 && $0.x <= laid }, "\(asked): \(timeline.positions)")
        }
    }

    /// A node's first label line and whether it opens, as the app's view and view model decide them.
    @Test func aNodesLabelAndWhetherItOpens() {
        func node(_ kind: DisplayNode.Kind, _ meta: CrossReferenceNodeMetadata?) -> DisplayNode {
            DisplayNode(id: meta?.nodeKey ?? "x", kind: kind, metadata: meta, isDownloaded: true)
        }
        let numbered = CrossReferenceNodeMetadata(documentId: "d4", volumeId: "v", documentNumber: "4", header: "4. Telegram", dateline: nil)
        let headed = CrossReferenceNodeMetadata(documentId: "d5", volumeId: "v", documentNumber: nil,
                                                header: " Memorandum From the Secretary of State to the President ", dateline: nil)
        let page = CrossReferenceNodeMetadata(documentId: "pg_531", volumeId: "frus1943v03", documentNumber: nil,
                                              header: "1943, vol. III, p. 531", dateline: nil, citedPage: 531)
        let bare = CrossReferenceNodeMetadata(documentId: "d6", volumeId: "v", documentNumber: nil, header: nil, dateline: nil)
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.inbound, numbered)) == "Doc. 4")
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.outbound, headed)) == "Memorandum From the…")
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.extended, page)) == "p. 531")
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.inbound, bare)) == nil)
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.clusterInbound(volumeId: "v", count: 31), nil)) == "31 docs")
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.dateCluster(label: "Jun 1967", count: 5, memberKeys: []), nil)) == "5 docs · Jun 1967")
        #expect(CrossReferenceGraphRoutes.labelText(for: node(.unit(collectionId: "c1", name: "Lot 59 D 95"), nil)) == nil)
        #expect(CrossReferenceGraphRoutes.opensEntry(numbered) && CrossReferenceGraphRoutes.opensEntry(headed))
        #expect(!CrossReferenceGraphRoutes.opensEntry(page) && !CrossReferenceGraphRoutes.opensEntry(bare) && !CrossReferenceGraphRoutes.opensEntry(nil))
    }
}
