// What the server and the browser app mirror of the app's semantic map (PLAN's S28b, S28c), held to the app's source at
// the pin, line beside line. Since S28c each lens's palette, each point's slot, the names, the picks and the cards'
// rows are the kit's (`FRUSCoreKit/Semantic`, S28a), computed on the server, and no longer mirrored; what is mirrored is
// the app's view and renderer: the ground, the sprite, the projection, the blending and the scope's ghost the Metal
// renderer draws with (`SemanticMapRenderer`), which the web's WebGL2 renderer draws as; the camera's scale, its fit and
// its pan (`SemanticMapCamera`, `SemanticMapRenderer`) and the Mac's zoom steps (`SemanticMapSpikeView`); a pick's
// tolerance from a view (`SemanticMapPicking.hit(at:)`, whose grid form the server runs), a click on a drawn name
// (`regionLabel(at:size:)`) and a key's swatch (`swatch(lens:slot:)`); the regions' table's order and columns
// (`SemanticMapExport.regionsTable`); the keyboard's list's order and words (`mapAccessibilityList`); the rail's tile and
// its place (`ResearchRailView`); and every word the server writes and copy.ts holds, under the app's key, with the
// Analytics menu's order. A pin move that changes one fails here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SemanticMapMirrorParityTests {
    static let lens = "kit:FRUSCoreKit/Semantic/SemanticMapLens.swift"
    static let renderer = "Semantic/Map/SemanticMapRenderer.swift"
    static let labels = "kit:FRUSCoreKit/Semantic/SemanticMapLabels.swift"
    static let view = "Semantic/Map/SemanticMapSpikeView.swift"
    static let export = "kit:FRUSCoreKit/Semantic/SemanticMapExport.swift"
    static let menu = "App/FRUSExplorerApp.swift"
    static let artifacts = "kit:SemanticVectorsKit/SemanticMapArtifacts.swift"
    static let rules = "web:analytics/semanticMapRules.ts"
    static let webRenderer = "web:analytics/semanticMapRenderer.ts"
    static let map = "web:analytics/SemanticMap.tsx"
    static let screen = "web:analytics/SemanticAnalyticsScreen.tsx"
    static let shell = "web:shell/AppShell.tsx"
    static let server = "Sources/FRUSLightAPI/SemanticMap.swift"
    static let reading = "Sources/FRUSLightAPI/SemanticMapReading.swift"
    static let picking = "kit:FRUSCoreKit/Semantic/SemanticMapPicking.swift"
    static let rail = "DocumentView/ResearchRailView.swift"

    @Test func thePaletteAndTheGhostAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.lens, #"static let paletteSize = 16"#, Self.rules, #"export const paletteSize = 16;"#),
            // A point's slot is the server's, the kit's colouring, and the shader reads it whole, as the app's reads its byte.
            (Self.renderer, #"float4 colour = palette[p.colourIndex];"#, Self.webRenderer, #"colour = palette[min(slot, ${paletteSize - 1}u)];"#),
            // A point outside the scope is grey at a fixed alpha, and one inside it is raised to a floor while a scope is on.
            (Self.renderer, #"""
             if ((p.flags & 1u) != 0u) {
                 float grey = dot(colour.rgb, float3(0.2126, 0.7152, 0.0722)) * 0.55;
                 colour = float4(grey, grey, grey, 0.16);
             } else if (uniforms.scopeActive > 0.5) {
                 colour.a = max(colour.a, 0.45);
             }
             """#,
             Self.webRenderer, #"""
             if ((flags & 1u) != 0u) {
               float grey = dot(colour.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.55;
               colour = vec4(grey, grey, grey, 0.16);
             } else if (scopeActive > 0.5) {
               colour.a = max(colour.a, 0.45);
             }
             """#),
            // A mask of another length is stale, and draws the map unscoped.
            (Self.renderer, #"isScoped = !flags.isEmpty && flags.count == pointCount"#,
             Self.webRenderer, #"const scoped = flags !== undefined && flags.length === this.count;"#),
            // A key's swatch: the slot's colour, opaque.
            (Self.view, #"""
             return Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z),
                          opacity: 1.0)
             """#,
             Self.rules, #"return `rgb(${channel(colour[0])}, ${channel(colour[1])}, ${channel(colour[2])})`;"#),
            // The key names every colour, or the regions' one, Between regions.
            (Self.view, #"let entries = Array(lens.legend.enumerated())"#,
             Self.screen, #"const keyEntries = drawnLens ? (drawnLens.namesEveryColour ? drawnLens.legend : drawnLens.legend.slice(0, 1)) : [];"#),
        ])
    }

    @Test func theMapIsDrawnAsTheAppsRendererDrawsIt() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.renderer, #"static let backgroundClearColor = MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)"#,
             Self.rules, #"export const background: Rgba = [0.06, 0.07, 0.09, 1];"#),
            (Self.renderer, #"var pointSize: Float = 2.0 { didSet { setNeedsRedraw() } }"#, Self.rules, #"export const pointSize = 2;"#),
            (Self.renderer, #"""
             float2 view = (grid - uniforms.centre) / uniforms.scale;
             RasterPoint out;
             out.position = float4(view, 0.0, 1.0);
             out.pointSize = uniforms.pointSize;
             """#,
             Self.webRenderer, #"""
             gl_Position = vec4((position - centre) / scale, 0.0, 1.0);
             gl_PointSize = pointSize;
             """#),
            (Self.renderer, #"""
             float d = length(coordinate - float2(0.5));
             if (d > 0.5) { discard_fragment(); }
             half edge = half(smoothstep(0.5, 0.35, d));
             return half4(in.colour.rgb, in.colour.a * edge);
             """#,
             Self.webRenderer, #"""
             float d = length(gl_PointCoord - vec2(0.5));
             if (d > 0.5) discard;
             float edge = 1.0 - smoothstep(0.35, 0.5, d);
             fragment = vec4(colour.rgb, colour.a * edge);
             """#),
            (Self.renderer, #"""
             descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
             descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
             descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
             descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
             """#,
             Self.webRenderer, #"gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ONE_MINUS_SRC_ALPHA);"#),
            // One draw call for every point.
            (Self.renderer, #"encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pointCount)"#,
             Self.webRenderer, #"if (this.count > 0 && this.slotCount === this.count) gl.drawArrays(gl.POINTS, 0, this.count);"#),
        ])
    }

    @Test func theCameraAndItsZoomAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.labels, #"""
             return safeAspect >= 1
                 ? SIMD2<Float>(halfExtent * safeAspect, halfExtent)
                 : SIMD2<Float>(halfExtent, halfExtent / safeAspect)
             """#,
             Self.rules, #"return safeAspect >= 1 ? [camera.halfExtent * safeAspect, camera.halfExtent] : [camera.halfExtent, camera.halfExtent / safeAspect];"#),
            (Self.renderer, #"camera = SemanticMapCamera(centre: SIMD2<Float>(0, 0), halfExtent: extent)"#,
             Self.rules, #"return { centre: [0, 0], halfExtent: gridExtent };"#),
            (Self.view, #"? Float(BundledSemanticMap.vectors?.gridExtent ?? SemanticAxis.sliceExtent)"#,
             Self.map, #"next = () => fitCamera(gridExtent);"#),
            (Self.renderer, #"""
             camera.centre.x -= Float(translation.width) / halfWidth * scale.x
             camera.centre.y += Float(translation.height) / halfHeight * scale.y
             """#,
             Self.rules, #"{ centre: [camera.centre[0] - (dx / halfWidth) * scaleX, camera.centre[1] + (dy / halfHeight) * scaleY], halfExtent: camera.halfExtent },"#),
            (Self.renderer, #"camera.halfExtent /= factor"#, Self.rules, #"const next = clampCamera({ centre: camera.centre, halfExtent: camera.halfExtent / factor }, gridExtent);"#),
            (Self.view, #"model.zoom(by: 1.4)"#, Self.rules, #"export const zoomStep = 1.4;"#),
            (Self.view, #"model.zoom(by: 1 / 1.4)"#, Self.map, #"<button type="button" onClick={() => zoomBy(1 / zoomStep)}>"#),
            (Self.view, #"model.frameAll()"#, Self.map, #"<button type="button" onClick={() => setCamera(fitCamera(gridExtent))}>"#),
            (Self.view, #"onZoom?(1.6)"#, Self.rules, #"export const doubleClickZoom = 1.6;"#),
        ])
    }

    @Test func thePicksAndTheNamesAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // A pick's tolerance from the view: the click's radius in grid units, by the larger of the two axes'.
            (Self.picking, #"public static let tapRadius: CGFloat = 22"#, Self.rules, #"export const tapRadius = 22;"#),
            (Self.picking, #"""
             let aspect = Float(size.width / size.height)
             let scale = camera.scale(aspect: aspect)
             let gridPerPointX = scale.x * 2 / Float(size.width)
             let gridPerPointY = scale.y * 2 / Float(size.height)
             let tolerance = Float(radius) * max(gridPerPointX, gridPerPointY)
             """#,
             Self.rules, #"""
             const [scaleX, scaleY] = cameraScale(camera, size.width / size.height);
             const gridPerPointX = (scaleX * 2) / size.width;
             const gridPerPointY = (scaleY * 2) / size.height;
             return radius * Math.max(gridPerPointX, gridPerPointY);
             """#),
            (Self.picking, #"let target = SemanticMapLabelLayout.unproject(point, camera: camera, size: size)"#,
             Self.map, #"onPick(gridPoint(latest.current, view, at.x, at.y), pickTolerance(latest.current, view));"#),
            // The server runs the grid form, over the scope's mask.
            (Self.picking, #"public static func hit( nearGrid target: SIMD2<Float>, tolerance: Float, positions: [SIMD2<Int16>], scopeMask: [UInt8]? = nil ) -> Hit? {"#,
             Self.reading, #"SemanticMapPicking.hit(nearGrid: target, tolerance: tolerance, positions: plane.positions, scopeMask: mask.mask?.flags)"#),
            // A click on a drawn name opens its region, the first within the picker's reach of its laid-out place.
            (Self.view, #"static let regionTapRadius: CGFloat = 22"#, Self.rules, #"export const regionTapRadius = 22;"#),
            (Self.view, #".first { hypot($0.position.x - point.x, $0.position.y - point.y) <= Self.regionTapRadius }"#,
             Self.rules, #"return labels.find((label) => Math.hypot(label.x - x, label.y - y) <= regionTapRadius);"#),
            (Self.view, #"if let label = regionLabel(at: point, size: size) {"#,
             Self.map, #"""
             const label = labelAt(drawnLabels, at.x, at.y);
             if (label) {
             """#),
            // The keyboard's list: the regions the names may name, largest first, ties by id, each "[name], region".
            (Self.view, #"""
             let clusters = model.labelledClusters.sorted {
                 $0.documentCount == $1.documentCount ? $0.id < $1.id
                                                      : $0.documentCount > $1.documentCount
             }
             """#,
             Self.reading, #"""
             let regions = labelled.sorted {
                 $0.documentCount == $1.documentCount ? $0.id < $1.id : $0.documentCount > $1.documentCount
             }
             """#),
            (Self.view, #"defaultValue: "%1$@, region"),"#, Self.reading, #"appWords("semanticMap.a11y.region.label %@", "%1$@, region")"#),
            (Self.view, #"defaultValue: "mostly %1$@"), era.label)"#, Self.reading, #"appWords("semanticMap.a11y.region.era %@", "mostly %1$@"), era.label)"#),
            (Self.view, #"let count = CountCopy.documents(cluster.documentCount)"#, Self.reading, #"let count = CountCopy.documents(cluster.documentCount)"#),
            // A point's headline: the volume's title and the document's id, the ids where the catalogue has none.
            (Self.view, #"""
             guard let title, !title.isEmpty else {
                 return "\(selection.volumeID) · \(selection.documentID)"
             }
             return "\(title) · \(selection.documentID)"
             """#,
             Self.reading, #"""
             guard let title = resources.volume(volumeId)?.title, !title.isEmpty else { return "\(volumeId) · \(documentId)" }
             return "\(title) · \(documentId)"
             """#),
            // A link's request lands in the app's order: the lens, the scope, then the document, else the region.
            (Self.view, #"if let key = continued.focusDocumentKey {"#, Self.reading, #"if let key = request.focusDocumentKey {"#),
            (Self.view, #"} else if let clusterID = continued.focusClusterID {"#, Self.reading, #"} else if let region = request.focusClusterID {"#),
        ])
    }

    @Test func theRegionsTableIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.export, #"""
             let ranked = clusters.sorted {
                 $0.documentCount == $1.documentCount ? $0.id < $1.id
                                                      : $0.documentCount > $1.documentCount
             }
             """#,
             Self.screen, #".sort((a, b) => b.documentCount - a.documentCount || a.id - b.id)"#),
            (Self.export, #"""
             String(cluster.id),
             cluster.terms.prefix(termCount).joined(separator: " "),
             String(cluster.documentCount),
             """#,
             Self.screen, #".map((region) => [String(region.id), region.terms.join(' '), region.documentCount.toLocaleString('en-US')]);"#),
            (Self.export, #"static func regionsTable(clusters: [SemanticMapArtifacts.Cluster], termCount: Int = 4) -> ChartInspectorData {"#,
             Self.screen, #"columns: [words.columns.region, words.columns.terms, words.columns.documents],"#),
        ])
    }

    @Test func theWordsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let view = try sources.app(Self.view)
        // The kit's files, by the paths the pairs name without their prefix (`Sources.app` reads `FRUSCoreKit/` from the root).
        let lens = try sources.app(String(Self.lens.dropFirst("kit:".count)))
        let export = try sources.app(String(Self.export.dropFirst("kit:".count)))
        let menu = try sources.app(Self.menu)
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let block = try NoteViewParityTests.block("semanticAnalytics", of: copy)
        let appBlock = try NoteViewParityTests.block("app", of: copy)
        let server = try SearchSetParityTests.server(Self.server)

        // The Mac's Analytics menu: Semantic Analytics after Archival Analytics, before the divider and Chronology.
        #expect(NoteViewParityTests.writes(menu, "menu.analytics.semantic", "Semantic Analytics"))
        let order = ["menu.analytics.archival", "menu.analytics.semantic", "menu.analytics.chronology"].compactMap { menu.range(of: $0)?.lowerBound }
        #expect(order.count == 3 && order == order.sorted())
        #expect(appBlock.contains("semanticAnalytics: 'Semantic Analytics',"))
        let shell = try SearchSetParityTests.web("shell/AppShell.tsx")
        #expect(shell.contains(NoteViewParityTests.flattened("""
            { kind: 'item', label: copy.app.archivalAnalytics, onSelect: () => openTool('/analytics/archives') },
            // From S28b, Semantic Analytics after Archival Analytics, as the Mac's menu has it.
            { kind: 'item', label: copy.app.semanticAnalytics, onSelect: () => openTool('/analytics/semantic') },
            { kind: 'separator' },
            """)))

        for (source, key, words, line) in [
            (view, "semanticAnalytics.title", "Semantic Analytics", "title: 'Semantic Analytics',"),
            (view, "semanticMap.pending", "Loading the map…", "loading: 'Loading the map…',"),
            (view, "semanticMap.unavailable", "Map unavailable", "unavailableTitle: 'Map unavailable',"),
            (view, "semanticMap.malformed", "The semantic map could not be read.", "unreadable: 'The semantic map could not be read.',"),
            (view, "semanticMap.zoomIn", "Zoom In", "zoomIn: 'Zoom In',"),
            (view, "semanticMap.zoomOut", "Zoom Out", "zoomOut: 'Zoom Out',"),
            (view, "semanticMap.zoomFit", "Fit the Map", "zoomFit: 'Fit the Map',"),
            (export, "semanticMap.export.table.title", "Semantic map regions", "table: 'Semantic map regions',"),
        ] {
            #expect(NoteViewParityTests.writes(source, key, words), "the app writes \(key)")
            #expect(block.contains(line), "copy.ts holds \(line)")
        }
        let columns = [("region", "Region"), ("terms", "Terms"), ("documents", "Documents")]
        for (key, words) in columns {
            #expect(NoteViewParityTests.writes(export, "semanticMap.export.column.\(key)", words))
        }
        #expect(block.contains("columns: { region: 'Region', terms: 'Terms', documents: 'Documents' },"))

        // The summary the app's list of the regions opens with, its counts the web's grouped numbers.
        #expect(NoteViewParityTests.writes(view, "semanticMap.a11y.summary %lld %lld %lld",
            "Semantic map: %1$lld regions covering %2$lld documents. %3$lld more sit between regions and are not listed. Position shows similarity, not time — distances between far-apart regions are not meaningful."))
        #expect(block.contains(NoteViewParityTests.flattened("""
            `Semantic map: ${regions.toLocaleString('en-US')} regions covering ${documents.toLocaleString('en-US')} documents. ${between.toLocaleString('en-US')} more sit between regions and are not listed. Position shows similarity, not time — distances between far-apart regions are not meaningful.`,
            """)))

        // The lenses' captions are the kit's, from the server, the Regions lens's naming the map, whose names are drawn.
        #expect(!block.contains("the names are in the table"))
        #expect(NoteViewParityTests.writes(lens, "semanticMap.lens.cluster.caption",
                                           "Color separates neighboring regions rather than naming them; the names are on the map."))

        // S28c: the picker, the administration menu, the cards, the notice and the caveat, in the app's words.
        for (source, key, words, line) in [
            (view, "semanticMap.lens", "Color by", "colorBy: 'Color by',"),
            (view, "semanticMap.region.title", "Region", "title: 'Region',"),
            (view, "semanticMap.region.clear", "Dismiss region", "dismiss: 'Dismiss region',"),
            (view, "semanticMap.region.clear.help", "Closes this region’s card", "dismissHelp: 'Closes this region’s card',"),
            (view, "semanticMap.region.eraCaveat", "Era is the volume’s coverage midpoint, not each document’s own date.",
             "eraCaveat: 'Era is the volume’s coverage midpoint, not each document’s own date.',"),
            (view, "semanticMap.selection.dismiss", "Dismiss", "dismiss: 'Dismiss',"),
            (view, "semanticMap.selection.betweenRegions", "Between regions", "betweenRegions: 'Between regions',"),
            (view, "semanticMap.selection.open", "Open Document", "open: 'Open Document',"),
            (view, "semanticMap.reveal.notOnMap", "This document has no place on the map", "title: 'This document has no place on the map',"),
            (view, "semanticMap.reveal.notOnMap.dismiss", "Dismiss", "dismiss: 'Dismiss',"),
        ] {
            #expect(NoteViewParityTests.writes(source, key, words), "the app writes \(key)")
            #expect(block.contains(line), "copy.ts holds \(line)")
        }
        let whatItIs = "A region is a group the corpus fell into on its own — documents whose meaning an AI model detected to be alike, found by mathematical clustering rather than chosen by a human editor. Its name reflects the most distinctive words in a sample of those documents. It is NOT a subject heading, so read it as a hint at what the group is about rather than a claim about every document in it."
        #expect(NoteViewParityTests.writes(view, "semanticMap.region.whatItIs", whatItIs))
        #expect(block.contains("whatItIs: '\(whatItIs)',"))
        #expect(NoteViewParityTests.writes(view, "semanticMap.reveal.notOnMap.detail %@",
            "Chapter openers, front matter and appendix material were not included when the map was built, so %@ has no point to show. The rest of the series is here."))
        #expect(block.contains("`Chapter openers, front matter and appendix material were not included when the map was built, so ${volume} has no point to show. The rest of the series is here.`,"))
        #expect(NoteViewParityTests.writes(view, "semanticMap.scope.administration.none %@", "%@ — no mapped volumes"))
        #expect(block.contains("administrationNone: (president: string) => `${president} — no mapped volumes`,"))
        #expect(view.contains(NoteViewParityTests.flattened(#"""
            localized: "semanticMap.caveat.map",
                            defaultValue: """
                                Layout preserves local similarity; distances between far regions are not \
                                meaningful.
                                """))
            """#)))
        #expect(block.contains("caveat: 'Layout preserves local similarity; distances between far regions are not meaningful.',"))
        // A volume the server does not serve, and the Downloaded lens, in a server's words.
        #expect(NoteViewParityTests.writes(view, "semanticMap.selection.notDownloaded", "This volume is not on this device."))
        #expect(block.contains("notServed: 'This volume is not on this server.',"))
        #expect(NoteViewParityTests.writes(lens, "semanticMap.lens.availability", "Downloaded"))
        #expect(NoteViewParityTests.writes(lens, "semanticMap.legend.notDownloaded", "Not downloaded"))
        #expect(NoteViewParityTests.writes(lens, "semanticMap.legend.downloaded", "Downloaded"))
        let reading = try SearchSetParityTests.server(Self.reading)
        #expect(reading.contains(#"static let onThisServer = "On This Server""#))
        #expect(reading.contains(#"static let onThisServerLegend = ["Not on this server", "On this server"]"#))

        // The rail's On the Map, after Related, as the app's grid has it.
        let rail = try sources.app(Self.rail)
        #expect(NoteViewParityTests.writes(rail, "researchRail.tile.semanticMap", "On the Map"))
        #expect(NoteViewParityTests.writes(rail, "researchRail.tile.semanticMap.help",
                                           "Show where this document sits on the semantic map, among the documents whose language is most like it"))
        #expect(block.contains("tile: 'On the Map',"))
        #expect(block.contains("tileHelp: 'Show where this document sits on the semantic map, among the documents whose language is most like it',"))
        let tiles = ["RailTileCopy.related", "RailTileCopy.semanticMap", "RailTileCopy.share"].compactMap { rail.range(of: $0)?.lowerBound }
        #expect(tiles.count == 3 && tiles == tiles.sorted())
        let reader = try SearchSetParityTests.web("reader/ReaderScreen.tsx")
        let webTiles = ["{copy.related.tile}", "{copy.semanticAnalytics.tile}"].compactMap { reader.range(of: $0)?.lowerBound }
        #expect(webTiles.count == 2 && webTiles == webTiles.sorted())
        #expect(rail.contains(NoteViewParityTests.flattened(#"""
            focusDocumentKey: "\(entry.volumeId)/\(entry.documentId)"),
            """#)))
        #expect(reader.contains(NoteViewParityTests.flattened(#"""
            <Link to="/analytics/semantic" search={{ document: `${volumeId}/${documentId}` }} title={copy.semanticAnalytics.tileHelp}>
            """#)))

        // The server's refusals, the app's, its build a server.
        #expect(NoteViewParityTests.writes(view, "semanticMap.noArtifact", "This build does not carry the semantic map."))
        #expect(server.contains(#"static let noArtifactWords = "This server does not carry the semantic map.""#))
        #expect(server.contains(#"static let malformedWords = "The semantic map could not be read.""#))
        #expect(view.contains(NoteViewParityTests.flattened(#"""
            String(localized: "semanticMap.mismatch",
                          defaultValue: """
                              The map and the vectors come from different releases, so the map is \
                              not being drawn.
                              """)
            """#)))
        #expect(server.contains(#"static let mismatchWords = "The map and the vectors come from different releases, so the map is not being drawn.""#))
    }
}
