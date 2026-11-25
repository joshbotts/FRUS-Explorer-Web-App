// The semantic map's reading through the API (PLAN's S28c), held to the kit's own rules over the same files, computed
// here apart from the server: the bundled map and vectors through SemanticVectorsKit's loaders, the catalogue, the
// bundled source-provenance aggregate and the administrations through FRUSCoreKit's, and the three fixture volumes as
// the server's, whose index the server imports and serves. Each lens's slots, under each scope its mask, its sentence
// and its regions, the names for several views, the picks at many points of the grid, a link's request, revealing or
// focusing, and a region's card with its documents are the kit's, byte for byte and field for field.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import Foundation
import Hummingbird
import HummingbirdTesting
import ParityFormat
import SemanticVectorsKit
import Testing

@testable import FRUSLightAPI

@Suite struct SemanticMapReadingParityTests {
    /// The bundled files as a host decodes them with the kits' loaders, apart from the server's.
    struct Kit: Sendable {
        let tiers: SemanticBundledTiers
        let map: SemanticBundledMap
        let catalogue: [String: VolumeManifestEntry]
        let byVolume: [VolumeProvenance]?
        let administrations: [AdministrationProfile]
        let positions: [SIMD2<Int16>]

        var index: SemanticVectorIndex { tiers.index }
        var clusters: [SemanticMapArtifacts.Cluster] { map.index.clusters }
        var mapped: Set<String> { Set(index.volumes.map(\.volumeID)) }

        static func open() throws -> Kit {
            let directory = ServedFixture.resources
            func at(_ name: String) -> URL { directory.appendingPathComponent(name) }
            let tiers = try SemanticBundledTiers(indexAt: at("semantic-vectors-index.json"), binaryAt: at("semantic-vectors-binary.bin"))
            let map = try SemanticBundledMap(indexAt: at("semantic-map-index.json"), binaryAt: at("semantic-map.bin"), vectorIndex: tiers.index)
            let catalogue = try FixedVolumeCatalogue(contentsOf: at("manifest.json")).citableEntries
            return Kit(
                tiers: tiers, map: map,
                catalogue: Dictionary(uniqueKeysWithValues: catalogue.map { ($0.volumeId, $0) }),
                byVolume: try SourceProvenanceIndex(contentsOf: at("source-provenance-index.json")).byVolume,
                administrations: try AdministrationProfilesIndex(contentsOf: at("administration-profiles-index.json")).administrations,
                positions: SemanticMapPicking.positions(of: map.vectors))
        }

        /// The app's headline for a point: the volume's title and the document's id, the ids where the catalogue has none.
        func headline(_ volume: String, _ document: String) -> String {
            guard let title = catalogue[volume]?.title, !title.isEmpty else { return "\(volume) · \(document)" }
            return "\(title) · \(document)"
        }
    }

    /// The volumes the server serves: the three fixture volumes, whose index it imports.
    static let served = Set(ParityFixtures.volumes)

    /// A scope as an address names it, and its volumes as the scope bar resolves them over the series.
    struct Scope: Sendable {
        let query: String
        let volumes: Set<String>?
    }

    static func scopes(_ kit: Kit) throws -> [Scope] {
        let nixon = try #require(kit.administrations.first { $0.id == "nixon" } ?? kit.administrations.first { !$0.volumes.isEmpty })
        let subseries = "1961-63"
        return [
            Scope(query: "", volumes: nil),
            Scope(query: "subseries=\(subseries)",
                  volumes: kit.mapped.filter { CorpusAnalyticsService.subseries(fromVolumeId: $0) == subseries }),
            Scope(query: "volume=frus1961-63v06", volumes: ["frus1961-63v06"]),
            Scope(query: "administration=\(nixon.id)", volumes: Set(nixon.volumes.map(\.volumeId)).intersection(kit.mapped)),
            Scope(query: "volumes=frus1894Nicaragua&volumes=frus1969-76ve09p1&scopeLabel=Mine",
                  volumes: ["frus1894Nicaragua", "frus1969-76ve09p1"]),
        ]
    }

    static func get(_ client: any TestClientProtocol, _ path: String, _ query: String = "") async throws -> TestResponse {
        let response = try await client.execute(uri: query.isEmpty ? path : "\(path)?\(query)", method: .get)
        guard response.status == .ok else {
            throw APIParityError("\(path)?\(query) answered \(response.status.code): \(String(buffer: response.body))")
        }
        return response
    }

    static func json<T: Decodable>(_ type: T.Type, _ client: any TestClientProtocol, _ path: String, _ query: String = "") async throws -> T {
        try ServedFixture.decode(type, try await get(client, path, query))
    }

    static func joined(_ scope: Scope, _ more: String) -> String {
        [scope.query, more].filter { !$0.isEmpty }.joined(separator: "&")
    }

    @Test func theReadingIsTheKits() async throws {
        let kit = try Kit.open()
        let scopes = try Self.scopes(kit)
        #expect(kit.mapped == Set(kit.catalogue.keys), "the series the scope bar offers is the series the map places")
        #expect(kit.mapped.isSuperset(of: Self.served))
        try await ServedFixture.run { client, _ in
            try await Self.lenses(kit, client)
            for scope in scopes {
                let mask = SemanticMapColouring.scopeMask(volumeIDs: scope.volumes, map: kit.map.vectors, index: kit.index)
                try await Self.scope(kit, scope, mask: mask, client)
                try await Self.labels(kit, scope, mask: mask, client)
                try await Self.picks(kit, scope, mask: mask, client)
                try await Self.regionCards(kit, scope, mask: mask, client)
            }
            try await Self.requests(kit, client)
        }
    }

    /// The lenses the picker offers and their slots: the kit's colouring, each volume's era from the catalogue, the served
    /// volumes for On This Server and each volume's plurality provenance from the bundled aggregate.
    static func lenses(_ kit: Kit, _ client: any TestClientProtocol) async throws {
        let reading = try await json(SemanticMapReadingContext.self, client, "/api/v1/semantic/map/reading")
        let available = SemanticMapLens.allCases.filter { $0.isAvailable(volumeProvenance: kit.byVolume) }
        #expect(available == SemanticMapLens.allCases, "the bundled aggregate has its table by volume")
        #expect(reading.lenses.map(\.id) == available.map(\.rawValue))
        #expect(reading.layoutIdentity == kit.map.index.layoutIdentity && reading.mappedVolumes == 553)
        for (answer, lens) in zip(reading.lenses, available) {
            #expect(answer.name == (lens == .availability ? "On This Server" : lens.displayName))
            #expect(answer.legend == (lens == .availability ? ["Not on this server", "On this server"] : lens.legend))
            #expect(answer.caption == lens.caption && answer.namesEveryColour == lens.namesEveryColour)
            #expect(answer.palette == SemanticMapColouring.palette(for: lens).map { [$0.x, $0.y, $0.z, $0.w] }, "\(lens)'s palette")
        }
        #expect(reading.lenses.map(\.name) == ["Regions", "Era", "On This Server", "Provenance"])
        // The administration menu: each presidency with its volumes the map places; some none, which disables them.
        #expect(reading.administrations.map(\.id) == kit.administrations.map(\.id))
        for (answer, profile) in zip(reading.administrations, kit.administrations) {
            #expect(answer.mappedVolumes == Set(profile.volumes.map(\.volumeId)).intersection(kit.mapped).count, "\(profile.president)")
        }
        #expect(reading.administrations.contains { $0.mappedVolumes == 0 } && reading.administrations.contains { $0.mappedVolumes > 0 })

        let dominant = SemanticMapVolumes.dominantProvenance(byVolume: kit.byVolume ?? [])
        for lens in available {
            let expected = SemanticMapColouring.indices(
                for: lens, map: kit.map.vectors, index: kit.index,
                eraForVolume: { SemanticMapVolumes.era(of: kit.catalogue[$0]) },
                isDownloaded: { served.contains($0) },
                provenanceForVolume: { dominant[$0] })
            let response = try await get(client, "/api/v1/semantic/map/lens", "lens=\(lens.rawValue)")
            #expect(response.headers[.contentType] == "application/octet-stream")
            let slots = Array(response.body.readableBytesView)
            #expect(slots.count == 314_616 && slots == expected, "\(lens)'s slots are the kit's")
            // Each lens draws more than one colour: the regions' sixteen, the eras the catalogue's volumes fall in, both
            // of On This Server's, and the categories.
            let drawn = Set(slots)
            #expect(drawn.count >= (lens == .availability ? 2 : 3), "\(lens) draws \(drawn.sorted())")
            if lens.namesEveryColour { #expect(drawn.allSatisfy { Int($0) < (lens == .availability ? 2 : lens.legend.count) }, "\(lens)'s key names each") }
        }
        // On This Server colours the fixture volumes' documents alone.
        let onServer = Array(try await get(client, "/api/v1/semantic/map/lens", "lens=availability").body.readableBytesView)
        let servedRows = Self.served.compactMap { kit.index.rows(forVolume: $0) }.reduce(0) { $0 + $1.count }
        #expect(onServer.filter { $0 == 1 }.count == servedRows && servedRows > 0)
    }

    /// A scope's facts, its regions for the keyboard's list and its mask: the kit's.
    static func scope(_ kit: Kit, _ scope: Scope, mask: SemanticMapColouring.ScopeMask?, _ client: any TestClientProtocol) async throws {
        let answer = try await json(SemanticMapScopeAnswer.self, client, "/api/v1/semantic/map/scope", scope.query)
        let labelled = SemanticMapLabelLayout.labelledClusters(kit.clusters, scope: mask).sorted {
            $0.documentCount == $1.documentCount ? $0.id < $1.id : $0.documentCount > $1.documentCount
        }
        #expect(answer.regions.map(\.id) == labelled.map(\.id), "the regions under \(scope.query)")
        #expect(answer.regions.map(\.documentCount) == labelled.map(\.documentCount))
        #expect(answer.regions.map(\.name) == labelled.map { $0.terms.prefix(3).joined(separator: " ") })
        #expect(answer.regions.allSatisfy { $0.accessibilityLabel == "\($0.name), region" && $0.accessibilityValue.contains(" documents") })
        guard let mask else {
            #expect(answer.summary == nil && answer.regionCounts == nil && answer.label == nil && answer.volumeIds == nil)
            #expect(answer.documentCount == 314_616 && answer.volumeCount == 553 && answer.regions.count == 140)
            let refused = try await client.execute(uri: "/api/v1/semantic/map/scope/flags", method: .get)
            #expect(refused.status == .badRequest, "the whole series ghosts nothing")
            return
        }
        #expect(answer.documentCount == mask.documentCount && answer.volumeCount == mask.volumeCount && mask.documentCount > 0)
        #expect(answer.summary == SemanticMapColouring.scopeSummary(documents: mask.documentCount, volumes: mask.volumeCount, ofVolumes: 553))
        #expect(answer.regionCounts == Dictionary(uniqueKeysWithValues: mask.regionCounts.map { (String($0.key), $0.value) }))
        #expect(answer.volumeIds.map(Set.init) == scope.volumes)
        let flags = try await get(client, "/api/v1/semantic/map/scope/flags", scope.query)
        #expect(Array(flags.body.readableBytesView) == mask.flags, "the mask under \(scope.query) is the kit's")
    }

    /// The views the names are laid out for: the whole map in three sizes, and two closer views, each about a region.
    static func views(_ kit: Kit) -> [(camera: SemanticMapCamera, size: CGSize)] {
        let largest = kit.clusters.max { $0.documentCount < $1.documentCount }!
        let other = kit.clusters.first { $0.id == 17 } ?? kit.clusters[0]
        return [
            (SemanticMapCamera(centre: SIMD2(0, 0), halfExtent: 30_000), CGSize(width: 900, height: 600)),
            (SemanticMapCamera(centre: SIMD2(0, 0), halfExtent: 30_000), CGSize(width: 1_280, height: 853.5)),
            (SemanticMapCamera(centre: SIMD2(0, 0), halfExtent: 30_000), CGSize(width: 343, height: 300)),
            (SemanticMapCamera(centre: SIMD2(Float(largest.centreX), Float(largest.centreY)), halfExtent: 3_600), CGSize(width: 900, height: 600)),
            (SemanticMapCamera(centre: SIMD2(Float(other.centreX) + 777.5, Float(other.centreY) - 1_234.25), halfExtent: 9_876.5),
             CGSize(width: 700, height: 900)),
        ]
    }

    /// The names for each view: the kit's layout of the regions the scope labels.
    static func labels(_ kit: Kit, _ scope: Scope, mask: SemanticMapColouring.ScopeMask?, _ client: any TestClientProtocol) async throws {
        for view in views(kit) {
            let query = joined(scope, "x=\(view.camera.centre.x)&y=\(view.camera.centre.y)&halfExtent=\(view.camera.halfExtent)"
                + "&width=\(view.size.width)&height=\(view.size.height)")
            let answer = try await json(SemanticMapLabelsAnswer.self, client, "/api/v1/semantic/map/labels", query)
            let expected = SemanticMapLabelLayout.labels(
                for: SemanticMapLabelLayout.labelledClusters(kit.clusters, scope: mask), camera: view.camera, size: view.size)
            #expect(answer.labels == expected.map {
                .init(id: $0.id, text: $0.text, x: Double($0.position.x), y: Double($0.position.y), documentCount: $0.documentCount)
            }, "the names for \(query)")
            #expect(answer.labels.count <= SemanticMapLabelLayout.defaultLimit)
        }
        let whole = try await json(SemanticMapLabelsAnswer.self, client, "/api/v1/semantic/map/labels",
                                   joined(scope, "x=0&y=0&halfExtent=30000&width=900&height=600"))
        #expect(scope.volumes != nil || whole.labels.count > 10, "the whole map names many of its regions")
    }

    /// The picks at the places of documents, between them and far from any, at several tolerances: the kit's hit test.
    static func picks(_ kit: Kit, _ scope: Scope, mask: SemanticMapColouring.ScopeMask?, _ client: any TestClientProtocol) async throws {
        var targets: [(x: Float, y: Float, tolerance: Float)] = []
        // At the fixture volumes' documents and a stride through the corpus, and beside them.
        let rows = Self.served.flatMap { volume in kit.index.rows(forVolume: volume).map { [$0.lowerBound, $0.lowerBound + 7] } ?? [] }
            + Array(stride(from: 13, to: 314_616, by: 52_437))
        for row in rows {
            let place = kit.positions[row]
            targets.append((Float(place.x), Float(place.y), 1))
            targets.append((Float(place.x) + 37.5, Float(place.y) - 21.25, 220))
        }
        // At regions' centres, at a whole map's reach and a closer one's, and far from everything.
        for cluster in kit.clusters.prefix(6) {
            targets.append((Float(cluster.centreX), Float(cluster.centreY), 2_200))
            targets.append((Float(cluster.centreX) - 300, Float(cluster.centreY) + 300, 55))
        }
        targets.append((40_000, -40_000, 100))
        var found = 0
        for target in targets {
            let answer = try await json(SemanticMapPickAnswer.self, client, "/api/v1/semantic/map/pick",
                                        joined(scope, "x=\(target.x)&y=\(target.y)&tolerance=\(target.tolerance)"))
            let hit = SemanticMapPicking.hit(nearGrid: SIMD2(target.x, target.y), tolerance: target.tolerance,
                                            positions: kit.positions, scopeMask: mask?.flags)
            #expect(answer.point?.row == hit?.row, "the pick at \(target) under \(scope.query)")
            guard let hit, let point = answer.point else { continue }
            found += 1
            let document = try #require(kit.index.document(at: hit.row))
            let cluster = kit.map.vectors.placement(at: hit.row)?.cluster ?? SemanticMapArtifacts.unclustered
            #expect(point.volumeId == document.volumeID && point.documentId == document.documentID)
            #expect(point.x == Int(hit.position.x) && point.y == Int(hit.position.y))
            #expect(point.regionName == SemanticMapPicking.regionName(ofRow: hit.row, map: kit.map.vectors, clusters: kit.clusters))
            #expect(point.regionId == (cluster == SemanticMapArtifacts.unclustered ? nil : Int(cluster)))
            #expect(point.headline == kit.headline(document.volumeID, document.documentID))
            #expect(point.ids == "\(document.volumeID) · \(document.documentID)")
            #expect(point.served == served.contains(document.volumeID))
            #expect(point.served == (point.title != nil), "a served document is titled from the index, another is not")
            if let scoped = scope.volumes { #expect(scoped.contains(document.volumeID), "a pick never lands outside the scope") }
        }
        if scope.volumes == nil { #expect(found > targets.count / 3, "most picks find a point") }
        if scope.volumes?.isDisjoint(with: served) == false { #expect(found > 0, "a pick finds a point of the scope") }
    }

    /// A region's card under the scope: the kit's headline and era rows, and its documents, the kit's capture, a page at a time.
    static func regionCards(_ kit: Kit, _ scope: Scope, mask: SemanticMapColouring.ScopeMask?, _ client: any TestClientProtocol) async throws {
        let inScope = mask.map { mask in kit.clusters.filter { mask.regionCounts[UInt16($0.id)] != nil } } ?? kit.clusters
        let largest = inScope.max { $0.documentCount < $1.documentCount }
        for cluster in [largest, inScope.first, kit.clusters.last].compactMap({ $0 }) {
            let capture = SemanticMapCapture.region(cluster, map: kit.map.vectors, index: kit.index, scopeMask: mask?.flags)
            for (offset, limit) in [(0, 25), (25, 10), (capture.documentKeys.count, 5)] {
                let card = try await json(SemanticMapRegionCard.self, client, "/api/v1/semantic/map/regions/\(cluster.id)",
                                          joined(scope, "offset=\(offset)&limit=\(limit)&layout=\(kit.map.index.layoutIdentity)"))
                #expect(card.id == cluster.id && card.name == cluster.terms.prefix(3).joined(separator: " "))
                #expect(card.countSummary == SemanticMapRegionRows.countSummary(
                    documentCount: cluster.documentCount, inScope: mask?.regionCounts[UInt16(cluster.id)]))
                #expect(card.eraRows.map(\.label) == SemanticMapRegionRows.eraRows(cluster, locale: Locale(identifier: "en_US")).map(\.label))
                #expect(card.eraRows.map(\.count) == SemanticMapRegionRows.eraRows(cluster, locale: Locale(identifier: "en_US")).map(\.count))
                #expect(card.total == capture.total && card.kept == capture.documentKeys.count && card.offset == offset)
                let page = Array(capture.documentKeys.dropFirst(offset).prefix(limit))
                #expect(card.documents.map { "\($0.volumeId)/\($0.documentId)" } == page, "region \(cluster.id) from \(offset)")
                for document in card.documents {
                    #expect(document.headline == kit.headline(document.volumeId, document.documentId))
                    #expect(document.served == served.contains(document.volumeId))
                    #expect(document.served || document.title == nil)
                }
            }
        }
    }

    /// A link's request: its lens, where the server draws it; the document it reveals, or that it has no place; and the
    /// region it focuses, against the layout it was named in: the kit's `SemanticMapReveal`.
    static func requests(_ kit: Kit, _ client: any TestClientProtocol) async throws {
        let path = "/api/v1/semantic/map/request"
        #expect(try await json(SemanticMapRequestAnswer.self, client, path) == SemanticMapRequestAnswer(lens: "cluster"))
        #expect(try await json(SemanticMapRequestAnswer.self, client, path, "lens=era").lens == "era")
        #expect(try await json(SemanticMapRequestAnswer.self, client, path, "lens=availability").lens == "availability")
        #expect(try await json(SemanticMapRequestAnswer.self, client, path, "lens=administration").lens == "cluster",
                "a lens this build does not have is ignored")
        let presidency = try #require(kit.administrations.first { $0.id == "nixon" })
        #expect(try await json(SemanticMapRequestAnswer.self, client, path, "administration=nixon").scopeLabel == presidency.president)

        // A served document with a point, and one of a volume the server does not serve: each revealed where the kit puts it.
        for key in ["frus1961-63v06/d1", "frus1969-76ve09p1/d12", "frus1969-76v12/d45"] {
            let answer = try await json(SemanticMapRequestAnswer.self, client, path, "document=\(key)&lens=era")
            let parts = try #require(SemanticMapReveal.documentKey(key))
            let revealed = try #require(SemanticMapReveal.reveal(
                volumeID: parts.volumeID, documentID: parts.documentID, index: kit.index, map: kit.map.vectors,
                clusters: kit.clusters, isReadable: { served.contains($0) }))
            let reveal = try #require(answer.reveal)
            #expect(answer.lens == "era" && answer.focus == nil && reveal.key == key && reveal.revealed)
            #expect(reveal.point?.row == revealed.selection.row && reveal.point?.regionName == revealed.selection.regionName)
            #expect(reveal.point?.served == revealed.selection.isDownloaded && revealed.selection.isDownloaded == served.contains(parts.volumeID))
            #expect(reveal.camera == .init(x: revealed.camera.centre.x, y: revealed.camera.centre.y, halfExtent: revealed.camera.halfExtent))
            #expect(reveal.camera?.halfExtent == SemanticMapReveal.documentHalfExtent)
            #expect(reveal.volumeTitle == kit.catalogue[parts.volumeID]?.title)
        }
        // A document the map has no point for, a chapter's opening, and a key with no document: no place on the map.
        for (key, volume) in [("frus1961-63v06/ch1", "frus1961-63v06"), ("frus1961-63v06/d999999", "frus1961-63v06"), ("nothing", "nothing")] {
            let answer = try await json(SemanticMapRequestAnswer.self, client, path, "document=\(key)")
            #expect(answer.reveal == .init(key: key, revealed: false, volumeTitle: kit.catalogue[volume]?.title ?? volume), "\(key)")
        }
        // A region focused in its layout; in another, or one the layout has not, the map opens unfocused.
        let region = kit.clusters[42]
        let focused = try await json(SemanticMapRequestAnswer.self, client, path, "region=42&layout=\(kit.map.index.layoutIdentity)")
        let expected = try #require(SemanticMapReveal.focus(regionID: 42, digest: kit.map.index.layoutIdentity,
                                                            artifactDigest: kit.map.index.layoutIdentity, clusters: kit.clusters))
        #expect(expected.region.id == region.id)
        #expect(focused.focus == .init(region: 42, focused: true,
                                       camera: .init(x: expected.camera.centre.x, y: expected.camera.centre.y, halfExtent: SemanticMapReveal.regionHalfExtent)))
        for query in ["region=42&layout=00000000:2026-01-01:1", "region=42", "region=999&layout=\(kit.map.index.layoutIdentity)"] {
            let answer = try await json(SemanticMapRequestAnswer.self, client, path, query)
            #expect(answer.focus?.focused == false && answer.focus?.camera == nil, "\(query) opens the map unfocused")
        }
        // A document and a region both named: the document's reveal is the finer ask, as the app takes it.
        let both = try await json(SemanticMapRequestAnswer.self, client, path, "document=frus1961-63v06/d1&region=42&layout=\(kit.map.index.layoutIdentity)")
        #expect(both.reveal?.revealed == true && both.focus == nil)
    }
}
