// What the server and the browser app mirror of the app's semantic map's tools (PLAN's S28e), held to the app's source
// at the pin, line beside line. The rules are the kit's (`FRUSCoreKit/Semantic`, S28a), computed on the server; what is
// mirrored is the app's view and model around them (`SemanticMapSpikeView`): the lasso's stroke, its close and its scan,
// a scope's and the toggle's dropping of it, and its card; the save of a lasso and of a region, and the region card's
// line; the poles' setting, their refusal and Reset, the point card's controls and order, the axis's card and the
// slice's scale; Nearest in language's call and its row; and the export's table, statement, plate and figure. With them
// every word the server writes and copy.ts holds, under the app's key, those that speak of a device in a server's words
// beside the app's. A pin move that changes one fails here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SemanticMapToolsMirrorParityTests {
    static let view = "Semantic/Map/SemanticMapSpikeView.swift"
    static let figureExport = "Analytics/Export/AnalyticsFigureExport.swift"
    static let delivery = "Analytics/Export/AnalyticsExportDelivery.swift"
    static let chip = "Provenance/ProvenanceChip.swift"
    static let source = "kit:FRUSCoreKit/Provenance/ProvenanceSource.swift"
    static let count = "kit:FRUSCoreKit/Models/CountCopy.swift"
    static let rules = "web:analytics/semanticMapRules.ts"
    static let map = "web:analytics/SemanticMap.tsx"
    static let cards = "web:analytics/SemanticMapCards.tsx"
    static let screen = "web:analytics/SemanticAnalyticsScreen.tsx"
    static let figure = "web:analytics/semanticMapFigure.ts"
    static let tools = "Sources/FRUSLightAPI/SemanticMapTools.swift"

    @Test func theLassoIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // The stroke thinned as it is drawn, at four points on both axes.
            (Self.view, #"""
             if let last = lassoPath.last,
                abs(last.x - point.x) < 4, abs(last.y - point.y) < 4 { return }
             lassoPath.append(point)
             """#,
             Self.rules, #"""
             if (last && Math.abs(last[0] - point[0]) < lassoStep && Math.abs(last[1] - point[1]) < lassoStep) return [...path];
             return [...path, point];
             """#),
            (Self.view, #"abs(last.x - point.x) < 4"#, Self.rules, #"export const lassoStep = 4;"#),
            // Drawn closed, since what it holds is decided against the closed shape.
            (Self.view, #"path.addLines(model.lassoPath) path.closeSubpath()"#, Self.map, #"<polygon points={lassoPath.map(([x, y]) => `${x},${y}`).join(' ')} />"#),
            // A path of fewer than three points closes no lasso.
            (Self.view, #"guard let map = BundledSemanticMap.vectors, let index, lassoPath.count >= 3 else {"#,
             Self.map, #"if (event.type !== 'pointerup' || press.current?.moved !== true || stroke.length < 3) return;"#),
            (Self.view, #"guard let map = BundledSemanticMap.vectors, let index, lassoPath.count >= 3 else {"#,
             Self.tools, #"guard polygon.count >= 3 else { return (nil, mask.scope) }"#),
            // The scan of the positions drawn, under the scope, at the capture's cap, and the kit's capture of it.
            (Self.view, #"""
             let found = SemanticMapPicking.rows(
                 inside: lassoPath, positions: positions, camera: camera, size: size,
                 limit: SemanticMapPicking.corpusCaptureLimit,
                 scopeMask: scope?.flags)
             """#,
             Self.tools, #"""
             let found = SemanticMapPicking.rows(insideGrid: polygon, positions: positions,
                                                 limit: SemanticMapPicking.corpusCaptureLimit, scopeMask: mask.mask?.flags)
             """#),
            (Self.view, #"""
             lassoResult = SemanticMapCapture.lasso(
                 rows: found.rows, total: found.total, isScoped: scope != nil,
                 map: map, index: index, clusters: clusters)
             """#,
             Self.tools, #"""
             return SemanticMapCapture.lasso(rows: found.rows, total: found.total, isScoped: mask.mask != nil,
                                             map: plane.map.vectors, index: plane.index, clusters: plane.clusters)
             """#),
            // The view's point turned into the grid's (`unproject`), as the browser's lasso is sent in it.
            (Self.view, #"inside: lassoPath, positions: positions, camera: camera, size: size,"#,
             Self.map, #"onLasso?.(stroke.map(([x, y]) => gridPoint(latest.current, view, x, y)));"#),
            // A scope drops the lasso, as it drops the selection; the toggle drops it too.
            (Self.view, #"selection = nil lassoResult = nil renderer?.setScopeFlags(scope?.flags ?? [])"#,
             Self.screen, #"setCards((current) => ({ region: current.region })); setLasso(undefined);"#),
            (Self.view, #".onChange(of: isLassoing) { _, _ in model.clearLasso()"#,
             Self.screen, #"setLassoing((on) => !on); setLasso(undefined);"#),
            // Its card: the count or that nothing in scope is there, the regions, the model's chip, the cap, the coverage
            // and the save, offered for a capture that holds something.
            (Self.view, #"""
             Text(verbatim: result.total == 0
                  ? String(localized: "semanticMap.lasso.emptyInScope",
                           defaultValue: "Nothing in scope here")
                  : Self.documentCount(result.total))
             """#,
             Self.cards, #"<h2 id={heading}>{empty ? words.lasso.emptyInScope : words.lasso.documents(capture.total)}</h2>"#),
            (Self.view, #"Text(verbatim: result.regionNames.joined(separator: " · "))"#,
             Self.cards, #"{capture.regionNames.length > 0 && <p className="semantic-card-region">{capture.regionNames.join(' · ')}</p>}"#),
            (Self.view, #"if result.total > 0 { ProvenanceChip(source: .appModel) }"#, Self.cards, #"{!empty && <ProvenanceChip source="appModel" />}"#),
            (Self.view, #"if result.isTruncated {"#, Self.cards, #"{capture.total > capture.kept && <p className="semantic-card-absent">"#),
            (Self.view, #"""
             .foregroundStyle(coverage(for: result).isComplete
                              ? Color.secondary : Color.orange)
             """#,
             Self.cards, #"<p className={capture.coverage.isComplete ? 'semantic-card-note' : 'semantic-card-absent'}>"#),
            (Self.view, #"if result.total == 0 { EmptyView() } else if let saved = savedCorpusName {"#,
             Self.cards, #"{!empty && canSave && ( saved ? ("#),
            // The coverage the card says is the resolver's, over the volumes served.
            (Self.view, #"WorkingCorpusResolver(indexedVolumeIds: appState.indexedVolumeIds)"#,
             Self.tools, #"CorpusCoverage(WorkingCorpusResolver(indexedVolumeIds: $0.indexedVolumeIds).resolve(documentKeys: capture.documentKeys))"#),
        ])
    }

    @Test func theSavesAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.view, #"""
             let name = SemanticMapCapture.corpusName(regionNames: result.regionNames,
                                                      stamp: SemanticMapCapture.stamp(for: Date()))
             """#,
             Self.tools, #"""
             let name = SemanticMapCapture.corpusName(
                 regionNames: capture.regionNames,
                 stamp: SemanticMapCapture.stamp(for: time, locale: SearchItem.locale, timeZone: timeZone))
             """#),
            (Self.view, #"""
             sourceQuery: nil,
             """#, Self.tools, #"sourceQuery: nil,"#),
            (Self.view, #"sourceDescription: SemanticMapCapture.sourceDescription(scopeLabel: scopeLabel),"#,
             Self.tools, #"sourceDescription: SemanticMapCapture.sourceDescription(scopeLabel: scope.volumeIds == nil ? nil : scope.label),"#),
            (Self.view, #"""
             indexedVolumeCountAtCapture: appState.indexedVolumeIds.count,
             wasTruncatedAtCapture: result.isTruncated,
             totalMatchCountAtCapture: result.total)
             """#,
             Self.tools, #"""
             indexedVolumeCountAtCapture: served?.indexedVolumeIds.count ?? 0,
             wasTruncatedAtCapture: capture.isTruncated, totalMatchCountAtCapture: capture.total,
             """#),
            // A region's capture, the kit's under the scope, saved by the same path.
            (Self.view, #"return SemanticMapCapture.region(region, map: map, index: index, scopeMask: scope?.flags)"#,
             Self.tools, #"SemanticMapCapture.region(cluster, map: plane.map.vectors, index: plane.index, scopeMask: mask.mask?.flags)"#),
            (Self.view, #"if let capture = model.regionCapture() { savedRegionCorpusName = saveWorkingCorpus(capture)"#,
             Self.cards, #"setSaved(await saveRegionCorpus(client, region, layout, scope));"#),
            // The card's line once saved, in place of its button, and the cap's beside it.
            (Self.view, #"if let saved = savedRegionCorpusName {"#, Self.cards, #"{saved ? ( <p ref={savedLine} tabIndex={-1} className="semantic-card-note"> {words.regionSave.saved(saved.name)}"#),
            (Self.view, #"Int64(truncated.documentKeys.count), Int64(truncated.total)))"#,
             Self.cards, #"{words.regionSave.truncated(saved.documentCount, saved.totalMatchCountAtCapture)}"#),
            // A new region is a new capture: the card is made again, its line with it.
            (Self.view, #".onChange(of: region.id) { _, _ in savedRegionCorpusName = nil regionCaptureTruncation = nil }"#,
             Self.screen, #"key={`${cards.region}|${chosen}`}"#),
        ])
    }

    @Test func theAxisIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // A pole set clears the last notice; a refusal lets the end just set go and says why; Reset clears both.
            (Self.view, #"if isPositive { poles.positive = volumeID } else { poles.negative = volumeID } axisNotice = nil"#,
             Self.screen, #"const next: Poles = positive ? { ...poles, positive: volume } : { ...poles, negative: volume }; const serial = ++poleSerial.current; setNotice(undefined);"#),
            (Self.view, #"""
             case .refused(let refusal):
                 if isPositive { poles.positive = nil } else { poles.negative = nil }
                 axisNotice = refusal.notice
             """#,
             Self.screen, #"""
             if (answer.refusal) {
               setPoles(positive ? { negative: next.negative } : { positive: next.positive });
               setNotice(answer.refusal.notice);
             """#),
            (Self.view, #"switch SemanticMapPoles.resolve(negative: poles.negative, positive: poles.positive,"#,
             Self.tools, #"let resolution = SemanticMapPoles.resolve(negative: from, positive: to, isReady: true) { volume in"#),
            (Self.view, #"return SemanticAxis.centroid(forVolume: volumeID, index: index, corpus: vectors)"#,
             Self.tools, #"SemanticAxis.centroid(forVolume: volume, index: index, corpus: corpus)"#),
            (Self.view, #"poles = (nil, nil) requestedPoles = (nil, nil) axisNotice = nil"#, Self.screen, #"setPoles({}); setNotice(undefined);"#),
            // The layout, each volume's year its coverage midpoint in the catalogue.
            (Self.view, #"""
             let layout = SemanticMapSlice.layout(along: axis, map: map, index: index, corpus: vectors,
                                                  yearForVolume: yearForVolume)
             """#,
             Self.tools, #"""
             let layout = SemanticMapSlice.layout(along: axis, map: plane.map.vectors, index: index, corpus: corpus,
                                                  yearForVolume: yearForVolume)
             """#),
            (Self.view, #"SemanticMapVolumes.coverageYear(of: appState.manifestStore.entry(forVolumeId: volumeID))"#,
             Self.tools, #"yearForVolume: { SemanticMapVolumes.coverageYear(of: resources.volume($0)) })"#),
            // Only a complete axis travels in the request, as the address carries both poles or neither.
            (Self.view, #"axisNegativeVolumeID: model.slice != nil ? model.poles.negative : nil,"#,
             Self.rules, #"if (from !== undefined && to !== undefined) { search.from = from; search.to = to; }"#),
            // The point card: what a slice adds, until one is drawn; the two poles, the high end once the low is set;
            // then the nearest, then Open Document.
            (Self.view, #"if model.slice == nil { Text(String( localized: "semanticMap.axis.whatItAdds","#,
             Self.cards, #"{!poles.sliced && <p className="semantic-card-note">{words.axis.whatItAdds}</p>}"#),
            (Self.view, #".disabled(model.poles.negative == nil)"#, Self.cards, #"<button type="button" disabled={!poles.canSetTo} onClick={poles.onTo}>"#),
            (Self.view, #".disabled(model.poles.negative == nil)"#, Self.screen, #"canSetTo: poles.negative !== undefined,"#),
            (Self.view, #"model.setPole(volumeID: selection.volumeID, isPositive: false,"#, Self.screen, #"onFrom: () => void setPole(point.volumeId, false),"#),
            (Self.view, #"model.setPole(volumeID: selection.volumeID, isPositive: true,"#, Self.screen, #"onTo: () => void setPole(point.volumeId, true),"#),
            (Self.view, #"nearestSection(for: selection) if selection.isDownloaded { openButton(for: selection)"#,
             Self.cards, #"{onShow && <Nearest key={`${point.volumeId}/${point.documentId}`} point={point} onShow={onShow} />} {point.served ? ("#),
            // The axis's card: the slice's two ends with the way back, or the one pole set, and the notice.
            (Self.view, #"Text(verbatim: "\(slice.negativeLabel) → \(slice.positiveLabel)")"#, Self.cards, #"<p className="semantic-card-ids">{words.axis.poles(slice.from, slice.to)}</p>"#),
            (Self.view, #"} else if let pole = model.poles.negative ?? model.poles.positive {"#, Self.screen, #"pole={sliced || laying ? undefined : (poles.negative ?? poles.positive)}"#),
            // The slice's scale: each tick's year at its row on the left edge while in view, the poles at the ends, the gutter.
            (Self.view, #"SemanticMapLabelLayout.project( SIMD2<Float>(-extent, y), camera: model.camera, size: proxy.size)"#,
             Self.map, #"const y = viewPoint(camera, size, [-gridExtent, tick.y])[1];"#),
            (Self.view, #"if at.y > 8, at.y < proxy.size.height - 8 {"#, Self.map, #"const inView = (y: number) => y > 8 && y < size.height - 8;"#),
            (Self.view, #".position(x: 24, y: at.y)"#, Self.map, #"style={{ left: '24px', top: `${y}px` }}"#),
            (Self.view, #"Text(verbatim: "← \(slice.negativeLabel)")"#, Self.map, #"{words.axis.low(slice.from)}"#),
            (Self.view, #".position(x: 16 + 40, y: proxy.size.height - 14)"#, Self.map, #"style={{ left: '56px', top: `${size.height - 14}px` }}"#),
            (Self.view, #"Text(verbatim: "\(slice.positiveLabel) →")"#, Self.map, #"{words.axis.high(slice.to)}"#),
            (Self.view, #".position(x: proxy.size.width - 16 - 40, y: proxy.size.height - 14)"#, Self.map, #"style={{ left: `${size.width - 56}px`, top: `${size.height - 14}px` }}"#),
            (Self.view, #"if scale.undatedCount > 0 {"#, Self.map, #"const gutter = slice.undatedCount > 0 && slice.gutterY !== undefined"#),
            (Self.view, #".position(x: 44, y: gutterAt.y)"#, Self.map, #"style={{ left: '44px', top: `${gutter}px` }}"#),
            // The names are drawn on the map alone; a tap on one is a slice's no more.
            (Self.view, #"let labels = model.slice == nil ? SemanticMapLabelLayout.labels("#, Self.screen, #"names={!sliced}"#),
            (Self.view, #"guard slice == nil else { return nil }"#, Self.map, #"enabled: names && settled !== undefined,"#),
            // A slice's frame is fitted to its own grid (`frameAll(extent:)`).
            (Self.view, #"renderer.frameAll(extent: Float(SemanticAxis.sliceExtent))"#, Self.map, #"setCamera(fitCamera(gridExtent));"#),
            // The caveat under the map is the slice's on a slice.
            (Self.view, #"if let slice = model.slice { Text(verbatim: Self.sliceCaveat(from: slice.negativeLabel, to: slice.positiveLabel))"#,
             Self.screen, #"<p className="semantic-map-caveat">{sliced?.answer.caveat ?? words.caveat}</p>"#),
            (Self.view, #"SemanticMapSlice.caveat(from: negative, to: positive, shippingDims: BundledSemanticVectors.index?.provenance.shippingDims)"#,
             Self.tools, #"caveat: SemanticMapSlice.caveat(from: from, to: to, shippingDims: slice.shippingDims))"#),
        ])
    }

    @Test func nearestInLanguageIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.view, #"""
             let pool = try? await SemanticSimilarityGenerator().candidates(
                 for: DocumentKey(volumeId: selection.volumeID, documentId: selection.documentID),
                 anchorYear: nil,
                 limit: Self.nearestCount,
             """#,
             Self.tools, #"let pool = try await semantic.source.candidates(for: anchor, anchorYear: nil, limit: nearestCount, scopeVolumeIds: nil)"#),
            (Self.view, #"scopeVolumeIds: nil, appState: appState)"#, Self.tools, #"scopeVolumeIds: nil)"#),
            (Self.view, #"static let nearestCount = 10"#, Self.tools, #"static let nearestCount = 10"#),
            (Self.view, #"Text(verbatim: candidate.record.header)"#, Self.tools, #": candidate.record.header,"#),
            (Self.view, #"Int64((candidate.strength * 100).rounded())))"#, Self.tools, #"score: candidate.strength, percent: Int((candidate.strength * 100).rounded()))"#),
            (Self.view, #"model.reveal(documentKey: "\(candidate.key.volumeId)/\(candidate.key.documentId)","#,
             Self.cards, #"<button type="button" className="link-button" data-key={key} onClick={() => onShow(key)}>"#),
            (Self.view, #"} else if neighboursAnchor == selection.row {"#, Self.cards, #"{answer?.empty === 'noShard' ? words.nearest.noShard"#),
        ])
    }

    @Test func theExportIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.view, #"let clusters = model.labelledClusters let table = SemanticMapExport.regionsTable(clusters: clusters)"#,
             Self.tools, #"let table = SemanticMapExport.regionsTable(clusters: SemanticMapLabelLayout.labelledClusters(plane.clusters, scope: mask.mask))"#),
            (Self.view, #"""
             scopedDocumentCount: model.scope?.documentCount,
             lens: lens,
             indexedVolumeCount: appState.indexedVolumeIds.count)
             """#,
             Self.tools, #"scopedDocumentCount: mask.mask?.documentCount, lens: lens, indexedVolumeCount: served.count)"#),
            (Self.view, #"let mapPoints = CGSize(width: AnalyticsFigureExporter.defaultWidth - 56, height: 900)"#,
             Self.tools, #"static let plateWidth: CGFloat = 1_200 - 56 static let plateHeight: CGFloat = 900"#),
            (Self.figureExport, #"static let defaultWidth: CGFloat = 1200"#, Self.tools, #"static let plateWidth: CGFloat = 1_200 - 56"#),
            (Self.figureExport, #"static let scale: CGFloat = 2"#, Self.figure, #"export const figureScale = 2;"#),
            (Self.view, #"""
             let labels = model.slice == nil
                 ? SemanticMapLabelLayout.labels(
                     for: model.labelledClusters, camera: model.camera, size: mapPoints)
                 : []
             """#,
             Self.tools, #"""
             let labels = slice == nil
                 ? SemanticMapLabelLayout.labels(for: SemanticMapLabelLayout.labelledClusters(plane.clusters, scope: mask.mask),
                                                 camera: camera, size: size)
                 : []
             """#),
            (Self.view, #"""
             frame: SemanticMapExport.FigureFrame(camera: model.camera,
                                                  size: mapPoints,
                                                  labelledRegionCount: labels.count))
             """#,
             Self.tools, #"frame: SemanticMapExport.FigureFrame(camera: camera, size: size, labelledRegionCount: labels.count))"#),
            // The plate, the points drawn again at the raster's size, its names over it in the app's white.
            (Self.view, #"pixelSize: CGSize(width: mapPoints.width * scale, height: mapPoints.height * scale),"#,
             Self.figure, #"canvas.width = figure.width * figureScale; canvas.height = figure.height * figureScale;"#),
            (Self.view, #"Text(label.text) .font(.caption2.weight(.medium)) .foregroundStyle(.white)"#,
             Self.figure, #"mark: { type: 'text', fontSize: 11, fontWeight: 500, color: '#ffffff' },"#),
        ])
    }

    @Test func theWordsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let view = try sources.app(Self.view)
        let delivery = try sources.app(Self.delivery)
        let chip = try sources.app(Self.chip)
        let source = try sources.app(String(Self.source.dropFirst("kit:".count)))
        let count = try sources.app(String(Self.count.dropFirst("kit:".count)))
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let block = try NoteViewParityTests.block("semanticAnalytics", of: copy)
        let sourcesBlock = try NoteViewParityTests.block("sources", of: copy)
        let tools = try SearchSetParityTests.server(Self.tools)

        for (from, key, words, line) in [
            (view, "semanticMap.lasso", "Lasso", "toggle: 'Lasso',"),
            (view, "semanticMap.lasso.emptyInScope", "Nothing in scope here", "emptyInScope: 'Nothing in scope here',"),
            (view, "semanticMap.lasso.dismiss", "Dismiss", "dismiss: 'Dismiss',"),
            (view, "semanticMap.lasso.save", "Save as Working Corpus", "save: 'Save as Working Corpus',"),
            (view, "semanticMap.lasso.truncated %lld %lld", "Saving the first %lld of %lld.",
             "truncated: (kept: number, total: number) => `Saving the first ${kept.toLocaleString('en-US')} of ${total.toLocaleString('en-US')}.`,"),
            (count, "count.documents.one", "%@ document", "documents: (count: number) => (count === 1 ? '1 document' : `${count.toLocaleString('en-US')} documents`),"),
            (count, "count.documents.many", "%@ documents", "documents: (count: number) => (count === 1 ? '1 document' : `${count.toLocaleString('en-US')} documents`),"),
            (view, "semanticMap.region.save", "Save as Working Corpus", "save: 'Save as Working Corpus',"),
            (view, "semanticMap.region.saved %@", "Saved as “%@”. Find it under Working Corpora, where it can scope a search.",
             "saved: (name: string) => `Saved as “${name}”. Find it under Working Corpora, where it can scope a search.`,"),
            (view, "semanticMap.region.saved.truncated %lld %lld", "Saved the first %1$lld of %2$lld.",
             "truncated: (kept: number, total: number) => `Saved the first ${kept.toLocaleString('en-US')} of ${total.toLocaleString('en-US')}.`,"),
            (view, "semanticMap.axis.title", "Axis", "title: 'Axis',"),
            (view, "semanticMap.axis.clear", "Clear axis and return to the map", "clear: 'Clear axis and return to the map',"),
            (view, "semanticMap.axis.back", "Back to the map", "back: 'Back to the map',"),
            (view, "semanticMap.axis.poleFrom", "Axis: from here", "from: 'Axis: from here',"),
            (view, "semanticMap.axis.poleTo", "…to here", "to: '…to here',"),
            (view, "semanticMap.slice.gutter %lld", "undated (%lld)", "gutter: (count: number) => `undated (${count.toLocaleString('en-US')})`,"),
            (view, "semanticMap.nearest.loading", "Finding nearest documents…", "loading: 'Finding nearest documents…',"),
            (view, "semanticMap.nearest.header", "Nearest in language", "header: 'Nearest in language',"),
            (view, "semanticMap.nearest.score %lld", "%lld%%", "score: (percent: number) => `${percent}%`,"),
            (view, "semanticMap.export.a11y", "Export map data", "accessibleLabel: 'Export map data',"),
            (delivery, "analytics.export.section.button", "Export", "label: 'Export',"),
            (delivery, "analytics.export.csv", "Chart data (CSV)…", "csv: 'Chart data (CSV)…',"),
            (delivery, "analytics.export.png", "Figure (PNG)…", "png: 'Figure (PNG)…',"),
        ] {
            #expect(NoteViewParityTests.writes(from, key, words), "the app writes \(key)")
            #expect(block.contains(NoteViewParityTests.flattened(line)), "copy.ts holds \(line)")
        }
        // The two sentences the app's source writes in one literal over several lines or with its escapes.
        #expect(view.contains(NoteViewParityTests.flattened(#"""
            Text(String(localized: "semanticMap.lasso.emptyInScope.detail",
                                defaultValue: """
                                    Everything you enclosed is outside the current scope. Widen the \
                                    scope, or draw around the coloured documents.
                                    """))
            """#)))
        #expect(block.contains("emptyInScopeDetail: 'Everything you enclosed is outside the current scope. Widen the scope, or draw around the coloured documents.',"))
        #expect(NoteViewParityTests.writes(view, "semanticMap.axis.needsSecondPole.v2",
            #"Select a document in a different volume and choose \u{201C}…to here\u{201D}. The map will then display every document in the series by where it falls between your chosen documents’ enclosing volumes."#))
        #expect(block.contains("needsSecondPole: 'Select a document in a different volume and choose “…to here”. The map will then display every document in the series by where it falls between your chosen documents’ enclosing volumes.',"))
        let whatItAdds = "On the map no direction has a meaning. A slice gives one that does: left to right becomes how far each document “leans” between two volumes you pick, with time running up the side. Any two volumes should produce a spread, so read it as a contrast you are interested in investigating — not one the corpus found."
        #expect(NoteViewParityTests.writes(view, "semanticMap.axis.whatItAdds", whatItAdds))
        #expect(block.contains("whatItAdds: '\(whatItAdds)',"))

        // Nearest's three sentences that speak of a device's downloads, in a server's words beside the app's.
        #expect(NoteViewParityTests.writes(view, "semanticMap.nearest.fence",
            "Drawn only from volumes downloaded on this device — the map shows the whole series, so there may be nearer documents it cannot score yet."))
        #expect(block.contains("fence: 'Drawn only from volumes on this server — the map shows the whole series, so there may be nearer documents in volumes it does not serve.',"))
        #expect(NoteViewParityTests.writes(view, "semanticMap.nearest.needsVolume",
            "Finding nearest documents needs this volume on the device. Download it to compare this document with others."))
        #expect(block.contains("noShard: 'Finding nearest documents needs this volume’s vectors, which are not on this server.',"))
        #expect(NoteViewParityTests.writes(view, "semanticMap.nearest.none",
            "No nearest documents yet. The vectors for this volume may still be downloading — try again in a moment."))
        #expect(block.contains("none: 'No nearest documents were found among the volumes on this server.',"))

        // The figure's title and a slice's sentence, which the server writes into the kit's statement.
        #expect(NoteViewParityTests.writes(view, "semanticMap.export.figureTitle", "Semantic map"))
        #expect(tools.contains(#"static let figureTitle = "Semantic map""#))
        let sliceWords = "This figure shows a SLICE (%1$@ → %2$@), not a map: the horizontal axis is the slice projection and the vertical axis is time. The map’s region labels are omitted because a slice offers a totally different illustration of the series’s semantic space."
        #expect(NoteViewParityTests.writes(view, "semanticMap.export.caveat.slice %@ %@", sliceWords))
        #expect(tools.contains("static let sliceDescription = \"\(sliceWords)\""))

        // The lasso's chip: the kit's label for the app's model, its tier computed, and the app's spoken words.
        #expect(NoteViewParityTests.writes(source, "provenance.source.model", "This app's model"))
        #expect(source.contains("case .appWordLists, .appModel: return .computed"))
        #expect(NoteViewParityTests.writes(chip, "provenance.chip.a11y.computed", "Source: computed by this app."))
        #expect(sourcesBlock.contains(#"appModel: { label: "This app's model", tier: 'computed', spoken: 'Source: computed by this app.' },"#))
    }
}
