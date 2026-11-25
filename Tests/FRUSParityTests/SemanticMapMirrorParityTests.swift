// What the server and the browser app mirror of the app's semantic map (PLAN's S28b), held to the app's source at the
// pin, line beside line, the lens, the labels and the export in the kit's `FRUSCoreKit/Semantic` since S27c's pin move
// (S28a, FRUS-Explorer#1985), until S28c's rows call them: the Regions lens's sixteen-slot palette and a
// region's slot in it (`SemanticMapColouring`), and the ground, the sprite, the projection and the blending the Metal
// renderer draws them with (`SemanticMapRenderer`), which the web's WebGL2 renderer draws as; the camera's scale, its fit
// and its pan (`SemanticMapCamera`, `SemanticMapRenderer`) and the Mac's zoom steps (`SemanticMapSpikeView`); the regions'
// table's order and columns (`SemanticMapExport.regionsTable`); and every word the server writes and copy.ts holds,
// under the app's key, with the Analytics menu's order. A pin move that changes one fails here until the web follows it.

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

    @Test func thePaletteIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.lens, #"static let paletteSize = 16"#, Self.rules, #"export const paletteSize = 16;"#),
            (Self.lens, #"""
             return [SIMD4(0.35, 0.37, 0.42, 0.30)] + (1..<paletteSize).map { index in
                 let hue = Float(index - 1) / Float(paletteSize - 1)
                 return hsb(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 0.72)
             }
             """#,
             Self.rules, #"""
             [0.35, 0.37, 0.42, 0.3],
             ...Array.from({ length: paletteSize - 1 }, (_, slot) => {
               const index = slot + 1;
               const hue = (index - 1) / (paletteSize - 1);
               return hsb(hue, 0.55, 0.95, 0.72);
             }),
             """#),
            (Self.lens, #"""
             let sector = (hue - hue.rounded(.down)) * 6
             let fraction = sector - sector.rounded(.down)
             let p = brightness * (1 - saturation)
             let q = brightness * (1 - saturation * fraction)
             let t = brightness * (1 - saturation * (1 - fraction))
             switch Int(sector) % 6 {
             case 0: return SIMD4(brightness, t, p, alpha)
             case 1: return SIMD4(q, brightness, p, alpha)
             case 2: return SIMD4(p, brightness, t, alpha)
             case 3: return SIMD4(p, q, brightness, alpha)
             case 4: return SIMD4(t, p, brightness, alpha)
             default: return SIMD4(brightness, p, q, alpha)
             """#,
             Self.rules, #"""
             const sector = (hue - Math.floor(hue)) * 6;
             const fraction = sector - Math.floor(sector);
             const p = brightness * (1 - saturation);
             const q = brightness * (1 - saturation * fraction);
             const t = brightness * (1 - saturation * (1 - fraction));
             switch (Math.trunc(sector) % 6) {
               case 0: return [brightness, t, p, alpha];
               case 1: return [q, brightness, p, alpha];
               case 2: return [p, brightness, t, alpha];
               case 3: return [p, q, brightness, alpha];
               case 4: return [t, p, brightness, alpha];
               default: return [brightness, p, q, alpha];
             """#),
            // A region's slot: the points between regions in slot 0, the regions cycled through the other fifteen.
            (Self.lens, #"""
             colours[row] = cluster == SemanticMapArtifacts.unclustered
                 ? 0
                 : UInt8(1 + Int(cluster) % (paletteSize - 1))
             """#,
             Self.rules, #"return region === betweenRegions ? 0 : 1 + (region % (paletteSize - 1));"#),
            (Self.lens, #": UInt8(1 + Int(cluster) % (paletteSize - 1))"#,
             Self.webRenderer, #"uint slot = region == ${betweenRegions}u ? 0u : 1u + region % ${paletteSize - 1}u;"#),
            (Self.artifacts, #"public static let unclustered: UInt16 = 0xFFFF"#, Self.rules, #"export const betweenRegions = 0xffff;"#),
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
             Self.webRenderer, #"if (this.count > 0) gl.drawArrays(gl.POINTS, 0, this.count);"#),
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
        let lens = try sources.app("FRUSCoreKit/Semantic/SemanticMapLens.swift")
        let export = try sources.app("FRUSCoreKit/Semantic/SemanticMapExport.swift")
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
            (lens, "semanticMap.legend.unclustered", "Between regions", "betweenRegions: 'Between regions',"),
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

        // The Regions lens's caption, which names the table where the app's names the map, until the web draws the names.
        let caption = "Color separates neighboring regions rather than naming them; the names are on the map."
        #expect(NoteViewParityTests.writes(lens, "semanticMap.lens.cluster.caption", caption))
        #expect(block.contains("caption: '\(caption.replacingOccurrences(of: "on the map", with: "in the table"))',"))

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
