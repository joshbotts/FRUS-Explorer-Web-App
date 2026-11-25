// The semantic map's tools through the API (PLAN's S28e), held to the kit's own rules over the same files, computed
// here apart from the server: the bundled map and vectors through SemanticVectorsKit's loaders and the catalogue through
// FRUSCoreKit's, and the three fixture volumes as the server's, whose index it imports and serves. A lasso's rows and its
// capture under each scope, on the map and on a slice, and the corpus it saves; a region's save; two poles' slice and its
// refusals, and a pick on it; a point's nearest ten, by the semantic source over the fixture index and shards; and the
// regions' CSV and the figure's caption band, with the kit's method block: each is the kit's, field for field and byte for
// byte.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import ParityFormat
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticMapToolsParityTests {
    typealias Kit = SemanticMapReadingParityTests.Kit
    typealias Scope = SemanticMapReadingParityTests.Scope

    static let served = SemanticMapReadingParityTests.served
    static let locale = Locale(identifier: "en_US")

    // MARK: The lasso

    /// Lassos in the map's own coordinates: a ring around frus1961-63v06's d1, a wide band that holds more than a corpus
    /// keeps, a crossed one whose overlap is outside (even-odd), one over bare ground, and two points, which close none.
    static func polygons(_ kit: Kit) throws -> [[[Double]]] {
        let d1 = try #require(kit.index.row(documentID: "d1", volumeID: "frus1961-63v06").map { kit.positions[$0] })
        let (x, y) = (Double(d1.x), Double(d1.y))
        return [
            [[x - 900.5, y - 700.25], [x + 1_100, y - 650], [x + 800, y + 950.75], [x - 1_000, y + 600]],
            [[-30_000, -6_000], [30_000, -6_000], [30_000, 6_000], [-30_000, 6_000]],
            [[x - 3_000, y - 3_000], [x + 3_000, y + 3_000], [x + 3_000, y - 3_000], [x - 3_000, y + 3_000]],
            [[32_000, 32_000], [32_700, 32_000], [32_700, 32_700]],
            [[x - 100, y - 100], [x + 100, y + 100]],
        ]
    }

    /// The kit's capture of a polygon as the server receives it, among `positions`, under a scope's mask.
    static func capture(_ polygon: [[Double]], kit: Kit, positions: [SIMD2<Int16>], mask: SemanticMapColouring.ScopeMask?)
        -> SemanticMapPicking.LassoResult? {
        let grid = polygon.map { SIMD2<Float>(Float($0[0]), Float($0[1])) }
        guard grid.count >= 3 else { return nil }
        let found = SemanticMapPicking.rows(insideGrid: grid, positions: positions, limit: SemanticMapPicking.corpusCaptureLimit,
                                            scopeMask: mask?.flags)
        return SemanticMapCapture.lasso(rows: found.rows, total: found.total, isScoped: mask != nil, map: kit.map.vectors,
                                        index: kit.index, clusters: kit.clusters)
    }

    static func post(_ client: any TestClientProtocol, _ path: String, _ body: [String: Any]) async throws -> TestResponse {
        let response = try await client.execute(
            uri: path, method: .post, headers: [.contentType: "application/json"],
            body: ByteBuffer(bytes: try JSONSerialization.data(withJSONObject: body)))
        guard response.status == .ok else {
            throw APIParityError("POST \(path) answered \(response.status.code): \(String(buffer: response.body))")
        }
        return response
    }

    /// The path with a scope's and a slice's parameters.
    static func path(_ path: String, _ parts: String...) -> String {
        let query = parts.filter { !$0.isEmpty }.joined(separator: "&")
        return query.isEmpty ? path : "\(path)?\(query)"
    }

    @Test func aLassosRowsAndItsCaptureAreTheKits() async throws {
        let kit = try Kit.open()
        let polygons = try Self.polygons(kit)
        let scopes = try SemanticMapReadingParityTests.scopes(kit)
        let slice = try Self.slice(kit, from: "frus1961-63v06", to: "frus1969-76ve09p1")
        try await ServedFixture.run { client, _ in
            for scope in scopes {
                let mask = SemanticMapColouring.scopeMask(volumeIDs: scope.volumes, map: kit.map.vectors, index: kit.index)
                for (layout, positions, poles) in [("map", kit.positions, ""), ("slice", slice.positions, "from=frus1961-63v06&to=frus1969-76ve09p1")] {
                    for (at, polygon) in polygons.enumerated() {
                        let answer = try ServedFixture.decode(SemanticMapLassoAnswer.self, try await Self.post(
                            client, Self.path("/api/v1/semantic/map/lasso", scope.query, poles), ["polygon": polygon]))
                        let expected = Self.capture(polygon, kit: kit, positions: positions, mask: mask)
                        let context = "\(layout) lasso \(at) under '\(scope.query)'"
                        #expect(answer.scoped == (scope.volumes != nil), "\(context)")
                        #expect(answer.capture?.total == expected?.total && answer.capture?.kept == expected?.documentKeys.count, "\(context)")
                        #expect(answer.capture?.regionNames == expected?.regionNames, "\(context)")
                        let coverage = expected.map { CorpusCoverage(WorkingCorpusResolver(indexedVolumeIds: Self.served).resolve(documentKeys: $0.documentKeys)) }
                        #expect(answer.capture?.coverage == coverage, "\(context)")
                    }
                }
            }
            // What the five came to on the map, unscoped: d1's ring holds documents, the band is capped at the corpus's
            // 7,500 with every one counted, the bare ground and two points make no card.
            let whole = polygons.map { Self.capture($0, kit: kit, positions: kit.positions, mask: nil) }
            #expect((whole[0]?.total ?? 0) > 0 && whole[0]?.isTruncated == false)
            #expect(whole[1]?.documentKeys.count == 7_500 && (whole[1]?.total ?? 0) > 7_500)
            #expect(whole[3] == nil && whole[4] == nil)
            // Scoped to one volume, a lasso over bare ground is a capture of nothing, which the card says.
            let volume = SemanticMapColouring.scopeMask(volumeIDs: ["frus1961-63v06"], map: kit.map.vectors, index: kit.index)
            #expect(Self.capture(polygons[3], kit: kit, positions: kit.positions, mask: volume) == .init(documentKeys: [], total: 0, regionNames: []))
        }
    }

    @Test func aLassoAndARegionAreSavedAsTheAppSavesThem() async throws {
        let kit = try Kit.open()
        let polygons = try Self.polygons(kit)
        let york = try #require(TimeZone(identifier: "America/New_York"))
        let slice = try Self.slice(kit, from: "frus1961-63v06", to: "frus1969-76ve09p1")
        try await ServedFixture.run { client, _ in
            let session = try await CollectionExportParityTests.Session.open(client)
            let volume = SemanticMapColouring.scopeMask(volumeIDs: ["frus1961-63v06"], map: kit.map.vectors, index: kit.index)
            let label = try ServedFixture.decode(SemanticMapScopeAnswer.self, try await client.execute(
                uri: "/api/v1/semantic/map/scope?volume=frus1961-63v06", method: .get)).label
            let title = try #require(label)
            var saved: [(corpus: WorkingCorpus, capture: SemanticMapPicking.LassoResult, scoped: Bool)] = []
            // A lasso unscoped and capped, one scoped to the volume, and one drawn on a slice.
            for (polygon, scope, mask, positions, poles) in [
                (polygons[1], "", nil as SemanticMapColouring.ScopeMask?, kit.positions, ""),
                (polygons[0], "volume=frus1961-63v06", volume, kit.positions, ""),
                ([[-5_000, -5_000], [5_000, -5_000], [5_000, 5_000], [-5_000, 5_000]], "", nil, slice.positions, "from=frus1961-63v06&to=frus1969-76ve09p1"),
            ] {
                let capture = try #require(Self.capture(polygon, kit: kit, positions: positions, mask: mask))
                let corpus = try await session.json(WorkingCorpus.self, .post, Self.path("/api/v1/me/working-corpora/lasso", scope, poles),
                                                    ["polygon": polygon, "timeZone": "America/New_York"])
                saved.append((corpus, capture, mask != nil))
            }
            // A region's card, unscoped and capped, and scoped to the volume: "edc nato nuclear", 79 of its documents.
            for (region, scope, mask) in [(3, "", nil as SemanticMapColouring.ScopeMask?), (115, "volume=frus1961-63v06", volume)] {
                let cluster = try #require(kit.clusters.first { $0.id == region })
                let capture = SemanticMapCapture.region(cluster, map: kit.map.vectors, index: kit.index, scopeMask: mask?.flags)
                let corpus = try await session.json(
                    WorkingCorpus.self, .post, Self.path("/api/v1/me/working-corpora/region", scope),
                    ["region": region, "layout": kit.map.index.layoutIdentity, "timeZone": "America/New_York"])
                saved.append((corpus, capture, mask != nil))
            }
            #expect(saved[1].capture.documentKeys.allSatisfy { $0.hasPrefix("frus1961-63v06/") })
            #expect(saved[3].capture.isTruncated && saved[4].capture.total == 79 && saved[4].capture.regionNames == ["edc nato nuclear"])
            let export = try ResearchDataEnvelope.makeDecoder().decode(
                ResearchDataEnvelope.self, from: Data(buffer: try await session.get("/api/v1/me/export").body))
            for (at, (corpus, capture, scoped)) in saved.enumerated() {
                let time = try #require(corpus.capturedAt.flatMap(UserStoreDate.date))
                #expect(corpus.name == SemanticMapCapture.corpusName(
                    regionNames: capture.regionNames, stamp: SemanticMapCapture.stamp(for: time, locale: Self.locale, timeZone: york)), "\(at)")
                #expect(corpus.sourceDescription == SemanticMapCapture.sourceDescription(scopeLabel: scoped ? title : nil), "\(at)")
                #expect(corpus.sourceQuery == nil && corpus.indexedVolumeCountAtCapture == Self.served.count, "\(at)")
                #expect(corpus.documentCount == capture.documentKeys.count && corpus.totalMatchCountAtCapture == capture.total, "\(at)")
                #expect(corpus.wasTruncatedAtCapture == capture.isTruncated, "\(at)")
                let kept = try #require(export.workingCorpora.first { $0.id.uuidString == corpus.id })
                #expect(kept.documentKeys == capture.documentKeys, "corpus \(at) holds the kit's capture, in order")
            }
            #expect(saved[1].corpus.sourceDescription == "Semantic map selection, scoped to \(title)")
            #expect(saved[0].corpus.sourceDescription == "Semantic map selection")
        }
    }

    // MARK: The slice

    /// The kit's slice for two poles over the bundled tier, each volume's year from the catalogue, or its refusal.
    static func poles(_ kit: Kit, from: String, to: String) -> SemanticMapPoles.Resolution {
        SemanticMapPoles.resolve(negative: from, positive: to, isReady: true) {
            SemanticAxis.centroid(forVolume: $0, index: kit.index, corpus: kit.tiers.corpus)
        }
    }

    static func slice(_ kit: Kit, from: String, to: String) throws -> SemanticMapSlice.Layout {
        guard case .axis(let axis) = poles(kit, from: from, to: to) else { throw APIParityError("\(from) and \(to) draw no slice") }
        return SemanticMapSlice.layout(along: axis, map: kit.map.vectors, index: kit.index, corpus: kit.tiers.corpus,
                                       yearForVolume: { SemanticMapVolumes.coverageYear(of: kit.catalogue[$0]) })
    }

    @Test func aSliceAndItsRefusalsAreTheKits() async throws {
        let kit = try Kit.open()
        // Two volumes whose summaries are one, between which no direction runs: the kit's third refusal. A difference of
        // int8 codes is a multiple of a scale, never under the kit's 1e-6, so only identical summaries cancel; the bundle
        // has none at the pin, where the refusal is answered by the same branch as the other two, and a pair is asked
        // here once one is bundled.
        var seen: [[Float]: String] = [:]
        var twins: [(String, String)] = []
        for volume in kit.index.volumes.map(\.volumeID) {
            guard let centroid = SemanticAxis.centroid(forVolume: volume, index: kit.index, corpus: kit.tiers.corpus) else { continue }
            if let first = seen[centroid] { twins.append((first, volume)) } else { seen[centroid] = volume }
        }
        let alike = twins
        try await ServedFixture.run { client, _ in
            for (from, to) in [("frus1961-63v06", "frus1969-76ve09p1"), ("frus1894Nicaragua", "frus1961-63v06")] {
                let layout = try Self.slice(kit, from: from, to: to)
                let answer = try await SemanticMapReadingParityTests.json(SemanticMapSliceAnswer.self, client, "/api/v1/semantic/map/slice", "from=\(from)&to=\(to)")
                let extent = Float(SemanticAxis.sliceExtent)
                #expect(answer.refusal == nil && answer.from == from && answer.to == to && answer.gridExtent == SemanticAxis.sliceExtent)
                #expect(answer.scale == .init(minYear: layout.scale.minYear, maxYear: layout.scale.maxYear, undatedCount: layout.scale.undatedCount))
                #expect(answer.ticks == SemanticMapSlice.tickYears(min: layout.scale.minYear, max: layout.scale.maxYear).map {
                    .init(year: $0, y: SemanticMapSlice.y(forYear: $0, scale: layout.scale) * extent)
                })
                #expect(answer.gutterY == (layout.scale.undatedCount > 0 ? SemanticMapSlice.gutterY * extent : nil))
                #expect(answer.caveat == SemanticMapSlice.caveat(from: from, to: to, shippingDims: kit.index.provenance.shippingDims))
                // Every point at the kit's place, with its region from the map, six bytes a point.
                let points = try await SemanticMapReadingParityTests.get(client, "/api/v1/semantic/map/slice/points", "from=\(from)&to=\(to)")
                var expected = [UInt8]()
                expected.reserveCapacity(layout.positions.count * 6)
                for (row, position) in layout.positions.enumerated() {
                    let cluster = kit.map.vectors.placement(at: row)?.cluster ?? SemanticMapArtifacts.unclustered
                    for value in [UInt16(bitPattern: position.x), UInt16(bitPattern: position.y), cluster] {
                        expected.append(UInt8(value & 0xFF))
                        expected.append(UInt8(value >> 8))
                    }
                }
                #expect(Array(points.body.readableBytesView) == expected, "\(from) → \(to)'s points are the kit's")
                // A pick on the slice scans the slice's places, under a scope as the map's does.
                for scope in try SemanticMapReadingParityTests.scopes(kit).prefix(3) {
                    let mask = SemanticMapColouring.scopeMask(volumeIDs: scope.volumes, map: kit.map.vectors, index: kit.index)
                    for (x, y, tolerance) in [(0, 0, 800), (-20_000, 15_000, 1_500), (25_000, -25_000, 3_000), (5_000, 26_000, 500)] {
                        let picked = try await SemanticMapReadingParityTests.json(
                            SemanticMapPickAnswer.self, client, "/api/v1/semantic/map/slice/pick",
                            SemanticMapReadingParityTests.joined(scope, "from=\(from)&to=\(to)&x=\(x)&y=\(y)&tolerance=\(tolerance)"))
                        let hit = SemanticMapPicking.hit(nearGrid: SIMD2<Float>(Float(x), Float(y)), tolerance: Float(tolerance),
                                                         positions: layout.positions, scopeMask: mask?.flags)
                        #expect(picked.point?.row == hit?.row, "a pick at \(x), \(y) on the slice under '\(scope.query)'")
                        if let point = picked.point, let hit {
                            #expect(point.x == Int(hit.position.x) && point.y == Int(hit.position.y))
                            let document = try #require(kit.index.document(at: hit.row))
                            #expect(point.volumeId == document.volumeID && point.documentId == document.documentID)
                            #expect(point.regionName == SemanticMapPicking.regionName(ofRow: hit.row, map: kit.map.vectors, clusters: kit.clusters))
                        }
                    }
                }
            }
            // The app's refusals, in its words: both ends in one volume, a volume the bundle has no summary of, and two
            // volumes whose summaries cancel.
            var refusals: [(String, String, SemanticMapPoles.Refusal)] = [
                ("frus1961-63v06", "frus1961-63v06", .sameVolume), ("frus1961-63v06", "frus1800x", .noSummary),
                ("frus1800x", "frus1961-63v06", .noSummary),
            ]
            refusals += alike.prefix(1).map { ($0.0, $0.1, .tooAlike) }
            for (from, to, refusal) in refusals {
                guard case .refused(let expected) = Self.poles(kit, from: from, to: to) else {
                    Issue.record("the kit draws a slice from \(from) to \(to)")
                    continue
                }
                #expect(expected == refusal)
                let answer = try await SemanticMapReadingParityTests.json(SemanticMapSliceAnswer.self, client, "/api/v1/semantic/map/slice", "from=\(from)&to=\(to)")
                #expect(answer.refusal == .init(reason: refusal.rawValue, notice: refusal.notice) && answer.scale == nil && answer.caveat == nil,
                        "\(from) → \(to)")
            }
        }
    }

    // MARK: Nearest in language

    @Test func aPointsNearestTenAreTheSemanticSourcesForTheSameAnchor() async throws {
        let kit = try Kit.open()
        let host = try await RelatedDocumentsParityTests.Host.open()
        // Every eighth document of the three volumes the map places, and a document of a volume the server holds no
        // shard of, whose own vectors the generation needs.
        var anchors: [DocumentKey] = []
        for volume in ParityFixtures.volumes.sorted() {
            guard let rows = kit.index.rows(forVolume: volume) else { continue }
            for row in rows where (row - rows.lowerBound) % 8 == 0 {
                if let document = kit.index.document(at: row) {
                    anchors.append(DocumentKey(volumeId: document.volumeID, documentId: document.documentID))
                }
            }
        }
        #expect(anchors.count > 30)
        let unshardedVolume = "frus1969-76v12"
        let unsharded = try #require(kit.index.rows(forVolume: unshardedVolume).flatMap { kit.index.document(at: $0.lowerBound) })
        anchors.append(DocumentKey(volumeId: unsharded.volumeID, documentId: unsharded.documentID))
        var lists: [DocumentKey: [GeneratedCandidate]] = [:]
        for anchor in anchors {
            lists[anchor] = try await MainActor.run { host.semantic() }
                .candidates(for: anchor, anchorYear: nil, limit: 10, scopeVolumeIds: nil).candidates
        }
        let (asked, expected) = (anchors, lists)
        try await ServedFixture.run { client, _ in
            var listed = 0
            for anchor in asked {
                let key = "\(anchor.volumeId)/\(anchor.documentId)"
                let answer = try await SemanticMapReadingParityTests.json(
                    SemanticMapNearestAnswer.self, client, "/api/v1/semantic/map/nearest",
                    "document=\(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)")
                let candidates = try #require(expected[anchor])
                #expect(answer.document == key)
                #expect(answer.neighbours.map { DocumentKey(volumeId: $0.volumeId, documentId: $0.documentId) } == candidates.map(\.key), "\(key)")
                #expect(answer.neighbours.map(\.score) == candidates.map(\.strength), "\(key)")
                #expect(answer.neighbours.map(\.percent) == candidates.map { Int(($0.strength * 100).rounded()) }, "\(key)")
                #expect(answer.neighbours.map(\.title) == candidates.map(\.record.header), "\(key)")
                #expect(answer.neighbours.count <= 10 && answer.neighbours.allSatisfy { Self.served.contains($0.volumeId) })
                if !candidates.isEmpty { listed += 1 }
                if anchor.volumeId == unshardedVolume {
                    #expect(candidates.isEmpty && answer.empty == "noShard", "\(key) has no shard to ask with")
                } else {
                    #expect(answer.empty == (candidates.isEmpty ? "none" : nil), "\(key)")
                }
            }
            #expect(listed > 30, "the fixture documents have their neighbours")
        }
    }

    // MARK: The export

    static func host(_ timeZone: TimeZone) -> AnalyticsProvenance.Host {
        AnalyticsProvenance.Host(appVersion: "Light \(FRUSLightVersion.string)", locale: Self.locale,
                                 calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
    }

    @Test func theRegionsCSVIsTheKits() async throws {
        let kit = try Kit.open()
        let scopes = try SemanticMapReadingParityTests.scopes(kit)
        let zone = "America/New_York"
        let timeZone = try #require(TimeZone(identifier: zone))
        try await ServedFixture.run { client, _ in
            for (scope, lens) in zip(scopes, [SemanticMapLens.cluster, .era, .availability, .provenance, .cluster]) {
                let mask = SemanticMapColouring.scopeMask(volumeIDs: scope.volumes, map: kit.map.vectors, index: kit.index)
                let label = try ServedFixture.decode(SemanticMapScopeAnswer.self, try await client.execute(
                    uri: Self.path("/api/v1/semantic/map/scope", scope.query), method: .get)).label
                let before = Date()
                let response = try await SemanticMapReadingParityTests.get(
                    client, "/api/v1/semantic/map/export", SemanticMapReadingParityTests.joined(scope, "lens=\(lens.rawValue)&timeZone=\(zone)"))
                let after = Date()
                #expect(response.headers[.contentType] == "text/csv; charset=utf-8")
                let table = SemanticMapExport.regionsTable(clusters: SemanticMapLabelLayout.labelledClusters(kit.clusters, scope: mask))
                func csv(_ moment: Date) -> String {
                    var provenance = SemanticMapExport.provenance(
                        index: kit.map.index, scopeLabel: mask == nil ? nil : label, scopedDocumentCount: mask?.documentCount,
                        lens: lens, indexedVolumeCount: Self.served.count)
                    provenance.exportDate = moment
                    return table.provenancedCSV(provenance, for: Self.host(timeZone))
                }
                let written = String(buffer: response.body)
                #expect(written == csv(before) || written == csv(after), "the regions' CSV under '\(scope.query)' with \(lens.rawValue)")
                #expect(written.contains("Semantic map regions") && written.contains("Region,Terms,Documents,Center X,Center Y"))
                let disposition = response.headers[.contentDisposition] ?? ""
                #expect(disposition.hasPrefix("attachment; filename=\"FRUS-Analytics-Semantic-map-regions-") && disposition.contains(".csv"), "\(disposition)")
            }
        }
    }

    @Test func theFiguresCaptionBandAndNamesAreTheKits() async throws {
        let kit = try Kit.open()
        let zone = "UTC"
        let timeZone = try #require(TimeZone(identifier: zone))
        let size = CGSize(width: 1_144, height: 900)
        let gridExtent = Float(kit.map.index.gridExtent)
        try await ServedFixture.run { client, _ in
            for (scope, camera, poles) in [
                ("", SemanticMapCamera(centre: .zero, halfExtent: gridExtent), nil as (String, String)?),
                ("volume=frus1961-63v06", SemanticMapCamera(centre: SIMD2<Float>(-19_710, -219), halfExtent: 3_600), nil),
                ("", SemanticMapCamera(centre: .zero, halfExtent: Float(SemanticAxis.sliceExtent)), ("frus1961-63v06", "frus1969-76ve09p1")),
            ] {
                let volumes: Set<String>? = scope.isEmpty ? nil : ["frus1961-63v06"]
                let mask = SemanticMapColouring.scopeMask(volumeIDs: volumes, map: kit.map.vectors, index: kit.index)
                let label = try ServedFixture.decode(SemanticMapScopeAnswer.self, try await client.execute(
                    uri: Self.path("/api/v1/semantic/map/scope", scope), method: .get)).label
                let before = Date()
                let figure = try await SemanticMapReadingParityTests.json(
                    SemanticMapFigure.self, client, "/api/v1/semantic/map/plate",
                    [scope, poles.map { "from=\($0.0)&to=\($0.1)" } ?? "",
                     "lens=era&x=\(camera.centre.x)&y=\(camera.centre.y)&halfExtent=\(camera.halfExtent)&timeZone=\(zone)"]
                        .filter { !$0.isEmpty }.joined(separator: "&"))
                let after = Date()
                let labels = poles == nil
                    ? SemanticMapLabelLayout.labels(for: SemanticMapLabelLayout.labelledClusters(kit.clusters, scope: mask), camera: camera, size: size)
                    : []
                #expect(figure.width == 1_144 && figure.height == 900)
                #expect(figure.labels.map(\.id) == labels.map(\.id) && figure.labels.map(\.text) == labels.map(\.text))
                #expect(figure.labels.map(\.x) == labels.map { Double($0.position.x) } && figure.labels.map(\.y) == labels.map { Double($0.position.y) })
                func lines(_ moment: Date) -> [AnalyticsPlate.Line] {
                    var provenance = SemanticMapExport.provenance(
                        index: kit.map.index, scopeLabel: mask == nil ? nil : label, scopedDocumentCount: mask?.documentCount,
                        lens: .era, indexedVolumeCount: Self.served.count, figureTitle: "Semantic map",
                        sliceDescription: poles.map {
                            "This figure shows a SLICE (\($0.0) → \($0.1)), not a map: the horizontal axis is the slice projection and the vertical axis is time. The map’s region labels are omitted because a slice offers a totally different illustration of the series’s semantic space."
                        },
                        frame: SemanticMapExport.FigureFrame(camera: camera, size: size, labelledRegionCount: labels.count))
                    provenance.exportDate = moment
                    return AnalyticsPlate(provenance, host: Self.host(timeZone), date: moment).lines
                }
                #expect(figure.plate.lines == lines(before) || figure.plate.lines == lines(after), "the figure's band under '\(scope)'")
                #expect(figure.plate.lines.first?.text == "Semantic map")
                #expect(figure.plate.fileName.hasPrefix("FRUS-Analytics-Semantic-map-"))
                #expect((poles == nil) == !figure.labels.isEmpty, "a slice's figure names no region")
            }
        }
    }
}
