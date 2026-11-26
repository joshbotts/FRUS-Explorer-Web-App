// What the server and the browser app mirror of the app's packet and its ways in (PLAN's S30d), held to the app's source
// at the pin, line beside line. The packet is the kit's exporter (`TripPacketExporter`), held to the kit by
// `ArchivePacketParityTests`; what is mirrored is the app's sheet (`TripPacketSheet`): its one render path, the repositories
// it offers and each one's Copy, its order of refusals, the topic's write and caption and the deliverables' write, and its
// PDF's page; the plan picker (`PlanPickerSheet`): its banner, its rows, its add and its New row; each way in: Source
// Explorer's menu of three, Archival Neighbors' add of those shown, a collection authority's record's add of its citing
// documents, a collection editor's add of its reading list, Project Home's Plan a Visit with its gate, and the review
// sheet's Open the plan; and every word, the server's and copy.ts's, under the app's key. Where the app's sheet shares, the
// web saves, and where the app speaks of a device's indexing, the web speaks of this server: both texts are held. A pin move
// that changes one fails here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct ArchivePacketMirrorParityTests {
    static let sheet = "TripPacket/TripPacketSheet.swift"
    static let picker = "TripPacket/PlanPickerSheet.swift"
    static let editor = "TripPacket/ArchiveVisitEditorView.swift"
    static let appliers = "TripPacket/ArchiveVisitDerivation+App.swift"
    static let tripPacketApp = "TripPacket/TripPacket+App.swift"
    static let explorer = "SourceExplorer/SourceExplorerView.swift"
    static let neighbors = "SourceExplorer/ArchivalNeighborsSheet.swift"
    static let record = "SourceExplorer/CollectionDetailView.swift"
    static let collectionEditor = "Collections/CollectionEditorView.swift"
    static let projectHome = "ProjectContext/ProjectHomeView.swift"
    static let review = "DocumentView/DocumentChangeReviewSheet.swift"
    static let derivation = "kit:FRUSCoreKit/TripPacket/ArchiveVisitDerivation.swift"
    static let topic = "kit:FRUSCoreKit/TripPacket/TripPacketModel.swift"
    static let packet = "Sources/FRUSLightAPI/ArchivePacket.swift"
    static let visits = "Sources/FRUSLightAPI/ArchiveVisits.swift"
    static let reviews = "Sources/FRUSLightAPI/Reviews.swift"
    static let packetSheet = "web:visits/PacketSheet.tsx"
    static let planPicker = "web:visits/PlanPicker.tsx"
    static let rules = "web:visits/visitRules.ts"
    static let editorScreen = "web:visits/VisitEditorScreen.tsx"
    static let sourcesScreen = "web:sources/SourcesScreen.tsx"
    static let neighboursScreen = "web:sources/NeighboursScreen.tsx"
    static let recordScreen = "web:sources/CollectionScreen.tsx"
    static let collectionScreen = "web:collections/CollectionEditorScreen.tsx"
    static let projectScreen = "web:research/ProjectHomeScreen.tsx"
    static let reviewScreen = "web:reader/ReviewSheet.tsx"

    @Test func theSheetIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // One render path for build, edit, scope and deliverables.
            (Self.sheet, #"var exporter = TripPacketExporter(model: model, projectName: title)"#,
             Self.packet, #"var exporter = TripPacketExporter(model: derived.model, projectName: title)"#),
            (Self.sheet, #"exporter.facilityScope = facilityScope"#, Self.packet, #"exporter.facilityScope = scope"#),
            (Self.sheet, #"exporter.deliverables = deliverables"#, Self.packet, #"exporter.deliverables = deliverables"#),
            (Self.sheet, #"exporter.overlay = overlay"#, Self.packet, #"exporter.overlay = derived.overlay"#),
            (Self.sheet, #"exporter.seededDocumentCount = seedCoverage.seeded"#, Self.packet, #"exporter.seededDocumentCount = derived.seededDocumentCount"#),
            (Self.sheet, #"exporter.resolvedDocumentCount = seedCoverage.indexed"#,
             Self.packet, #"exporter.resolvedDocumentCount = derived.indexedDocumentCount"#),
            (Self.sheet, #"exporter.generatedOn = Date()"#, Self.packet, #"exporter.generatedOn = day"#),
            (Self.sheet, #"seedCoverage = (seeded: derived.seededDocumentCount, indexed: derived.indexedDocumentCount)"#,
             Self.packet, #"let derived = try await ArchiveVisitRoutes.derivation(of: plan, served: served, resources: resources).derived"#),
            // The plan's own deliverables, its name as the title, its project's question for the caption.
            (Self.sheet, #"deliverables = plan.deliverables"#, Self.packet, #"answer.text = render(derived, title: title, scope: scope, deliverables: plan.deliverables, on: day.date)"#),
            (Self.editor, #"TripPacketSheet(plan: plan, title: plan.displayName,"#, Self.packet, #"let title = ArchiveVisitPlanWrites.displayName(of: plan.name)"#),
            (Self.editor, #"researchQuestion: plan.owningProject(in: modelContext)?.researchQuestion)"#,
             Self.packet, #"let question = plan.projectIds.first.flatMap { id in projects.first { $0.id == id } }?.researchQuestion"#),
            // The repositories offered, each one's Copy, and a scope the plan lost.
            (Self.sheet, #"return TripPacketExporter.offeredRepositories(model: model, overlay: overlay)"#,
             Self.packet, #"let facilities = TripPacketExporter.offeredRepositories(model: derived.model, overlay: derived.overlay)"#),
            (Self.sheet, #"let draft = TripPacketExporter.copiedInquiryDraft(model: model, projectName: title, overlay: overlay, repository: facility)"#,
             Self.packet, #"text: TripPacketExporter.copiedInquiryDraft(model: derived.model, projectName: title, overlay: derived.overlay, repository: facility))"#),
            (Self.sheet, #"if let scope = facilityScope, !facilities.contains(scope) { facilityScope = nil }"#,
             Self.packet, #"let scope = repository.flatMap { facilities.contains($0) ? $0 : nil }"#),
            (Self.sheet, #"Picker(String(localized: "packet.scope.picker", defaultValue: "Repository"), selection: $facilityScope) {"#,
             Self.packetSheet, #"<option value="">{words.packetScopeAll}</option>"#),
            (Self.sheet, #"ForEach(facilities, id: \.self) { facility in Button(facility) { copyDraft(for: facility) } }"#,
             Self.packetSheet, #"<button key={each} type="button" onClick={() => void copyDraft(each)}>"#),
            // Each unavailable state for its cause, the index first, then the plan's documents.
            (Self.sheet, #"guard let pipeline = appState.indexingPipeline else {"#,
             Self.packet, #"guard let served = try await provider.servedIfReady() else { answer.unavailable = "indexUnavailable""#),
            (Self.sheet, #"guard !(plan.documents ?? []).isEmpty else { packet = nil packetPDF = nil model = nil unavailableReason = .noDocuments"#,
             Self.packet, #"guard !plan.documents.isEmpty else { answer.unavailable = "noDocuments""#),
            (Self.sheet, #"case .indexUnavailable: ContentUnavailableView("#,
             Self.packetSheet, #"<h3>{data.unavailable === 'indexUnavailable' ? words.packetNoIndexTitle : words.packetEmptyTitle}</h3>"#),
            // The topic: saved half a second after typing stops, as typed, a blank one as none; Done saves an edit first;
            // the caption only while the field reads the project's question.
            (Self.sheet, #"try? await Task.sleep(nanoseconds: 500_000_000)"#, Self.packetSheet, #"export const topicPause = 500;"#),
            (Self.sheet, #"plan.inquiryText = trimmed.isEmpty ? nil : topicDraft"#,
             Self.visits, #"if let topic = body.inquiryText { plan.inquiryText = TripPacketTopicSentence.written(topic) }"#),
            (Self.sheet, #"TripPacketTopicSentence.isUncommitted(draft: topicDraft, edited: model.topicSentence.edited) { applyTopicEdit() }"#,
             Self.packetSheet, #"if (!topicIsUncommitted(draft, saved.current)) { close(); return; }"#),
            (Self.sheet, #"Text(TripPacketTopicSentence.showsSeededCaption(draft: topicDraft, researchQuestion: researchQuestion)"#,
             Self.packetSheet, #"{showsSeededCaption(draft, data.researchQuestion) ? words.packetTopicSeeded : words.packetTopicUnseeded}"#),
            (Self.sheet, #"prompt: Text(TripPacketTopicSentence.placeholder),"#, Self.packet, #"topicPlaceholder: TripPacketTopicSentence.placeholder,"#),
            (Self.sheet, #"let opened = planModel.topicSentence.openPlanDraft(draft: topicDraft, stored: plan.inquiryText)"#,
             Self.packetSheet, #"const [draft, setDraft] = useState(plan.inquiryText ?? '');"#),
            // The kit's topic rules the field reads, mirrored.
            (Self.topic, #"guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil } return text"#,
             Self.rules, #"return text != null && text.trim() !== '' ? text : null;"#),
            (Self.topic, #"guard let first = written(first), let second = written(second) else { return false }"#,
             Self.rules, #"return a !== null && b !== null && a.trim() === b.trim();"#),
            (Self.topic, #"written(draft) != written(edited)"#, Self.rules, #"return writtenTopic(draft) !== writtenTopic(edited);"#),
            // The derivation's topic, set over the model the server keeps for the plan's seeds.
            (Self.derivation, #"if let inquiryText = plan.inquiryText, !inquiryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { model.topicSentence.edited = inquiryText }"#,
             Self.visits, #"if let inquiryText = plan.inquiryText, !inquiryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { model.topicSentence.edited = inquiryText }"#),
            (Self.derivation, #"researchQuestion: nil,"#, Self.visits, #"model.topicSentence = .seeded(from: nil)"#),
            // The deliverables, written to the plan.
            (Self.sheet, #"plan.deliverables = deliverables"#,
             Self.visits, #"if let deliverables = body.deliverables { plan.deliverables = deliverables.applied(to: plan.deliverables) }"#),
            (Self.sheet, #"Toggle(String(localized: "packet.deliverables.links", defaultValue: "Repository visit-planning links"), isOn: $deliverables.includeLinks)"#,
             Self.packetSheet, #"{ key: 'includeLinks', label: words.packetLinks },"#),
            (Self.sheet, #"isOn: $deliverables.includeCitationCrib)"#, Self.packetSheet, #"{ key: 'includeCitationCrib', label: words.packetCrib },"#),
            // The text the sheet shows, and its share as text.
            (Self.sheet, #"Text(packet) .font(.system(.footnote, design: .monospaced)) .textSelection(.enabled)"#,
             Self.packetSheet, #"<pre className="packet-text" role="region" aria-label={words.packetText} tabIndex={0}>"#),
            (Self.sheet, #"ShareLink(item: packet) {"#, Self.packet, #"return download(Data(text.utf8), named: packet.textFileName, type: "text/plain; charset=utf-8")"#),
            // The PDF: the same string, never a second composition, on US Letter at 54 points' margin, at 9 points in Menlo,
            // black, named by the kit's rule.
            (Self.sheet, #"packetPDF = TripPacketPDFRenderer.render(packet: rendered, title: title)"#,
             Self.packet, #"let printed = try await pdf.pdf(fromHTML: page(packet: text, title: packet.title), fields: printFields)"#),
            (Self.sheet, #"var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)"#, Self.packet, #"("paperWidth", "8.5"), ("paperHeight", "11"),"#),
            (Self.sheet, #"let textRect = pageRect.insetBy(dx: 54, dy: 54)"#,
             Self.packet, #"("marginTop", "0.75"), ("marginBottom", "0.75"), ("marginLeft", "0.75"), ("marginRight", "0.75"),"#),
            (Self.sheet, #"let font = CTFontCreateWithName("Menlo" as CFString, 9, nil)"#,
             Self.packet, #"font-family: "DejaVu Sans Mono", monospace; font-size: 9pt; line-height: normal;"#),
            (Self.sheet, #"CGColor(gray: 0, alpha: 1),"#, Self.packet, #"pre { margin: 0; color: #000;"#),
            (Self.sheet, #"let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(title: title))"#,
             Self.packet, #"let fileName = TripPacketPDFRenderer.fileName(title: title)"#),
            // The editor's Export packet, disabled for a plan with no documents.
            (Self.editor, #"private var exportIsUnavailable: Bool { (plan.documents ?? []).isEmpty }"#,
             Self.editorScreen, #"disabled={plan.documents.length === 0} onClick={() => open({ kind: 'packet' })}>"#),
        ])
    }

    @Test func thePickerIsTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.picker, #"case (true, true): contribution = String(format: String(localized: "archiveVisit.picker.adding.both %@""#,
             Self.rules, #"includeSource && includeExternalRefs ? copy.visits.pickerAddingBoth(documents)"#),
            (Self.picker, #"case (true, false): contribution = String(format: String(localized: "archiveVisit.picker.adding.source %@""#,
             Self.rules, #": includeSource ? copy.visits.pickerAddingSource(documents) : copy.visits.pickerAddingRefs(documents);"#),
            (Self.picker, #"let count = CountCopy.documents(documents.count)"#, Self.rules, #"const documents = copy.visits.documents(count);"#),
            (Self.picker, #"return "\(contribution) — \(basis)""#, Self.rules, #"return `${contribution} — ${basis}`;"#),
            (Self.picker, #"return plans.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }"#,
             Self.rules, #"return search === '' || plan.displayName.toLocaleLowerCase('en-US').includes(search.toLocaleLowerCase('en-US'));"#),
            (Self.picker, #"@Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)"#, Self.planPicker, #"const plans = useQuery(visitsQuery);"#),
            (Self.picker, #"Text(CountCopy.documents((plan.documents ?? []).count))"#, Self.planPicker, #"<span className="meta">{words.documents(plan.documentCount)}</span>"#),
            (Self.picker, #"if addedPlanId == plan.id {"#, Self.planPicker, #"{added?.id === plan.id && <span className="added">{words.pickerAdded}</span>}"#),
            (Self.picker, #"ForEach(filtered) { plan in planRow(plan) } newPlanRow"#, Self.planPicker, #"<button type="button" className="picker-row picker-new" onClick={() => void choose(null)}>"#),
            // The add, the one every way in shares, and the New row, a plan made under the active project, named as the way
            // in suggests, then seeded like any other row.
            (Self.picker, #"plan.addSeeds(documents, includeSource: includeSource, includeExternalRefs: includeExternalRefs, in: modelContext)"#,
             Self.planPicker, #"await addSeeds(client, id, seeds);"#),
            (Self.appliers, #"let addition = ArchiveVisitPlanWrites.addingSeeds(documents, includeSource: includeSource, includeExternalRefs: includeExternalRefs,"#,
             Self.visits, #"apply(ArchiveVisitPlanWrites.addingSeeds(documents, includeSource: body.includeSource, includeExternalRefs: body.includeExternalRefs,"#),
            (Self.picker, #"let plan = ArchiveVisitPlan.make(name: suggestedName ?? "", activeProjectId: appState.activeProjectId, in: modelContext)"#,
             Self.planPicker, #"id === null ? await createVisitWith(client, seeds, request.suggestedName ?? '')"#),
            (Self.picker, #"let plan = ArchiveVisitPlan.make(name: suggestedName ?? "","#,
             Self.visits, #"var plan = ArchiveVisitPlanWrites.newPlan(name: body.name ?? "", projectId: project?.id,"#),
            (Self.picker, #"DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }"#,
             Self.planPicker, #"closing.current = setTimeout(() => closeAtOnce(onClose), addedPause);"#),
            (Self.picker, #"DispatchQueue.main.asyncAfter(deadline: .now() + 0.6)"#, "web:collections/CollectionPicker.tsx", #"export const addedPause = 600;"#),
        ])
    }

    @Test func theWaysInAreTheApps() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // Source Explorer: the Source Note's three-way add, an option with nothing behind it absent.
            (Self.explorer, #"if hasSourceNote { Button { presentPlanPicker(volumeId: volumeId, documentId: docId, includeSource: true, includeExternalRefs: false)"#,
             Self.sourcesScreen, #"if (sources.hasSourceNote) entries.push({ kind: 'item', label: words.addVisitSource, onSelect: () => present(true, false) });"#),
            (Self.explorer, #"if !unprintedPointers.isEmpty { Button { presentPlanPicker(volumeId: volumeId, documentId: docId, includeSource: false, includeExternalRefs: true)"#,
             Self.sourcesScreen, #"if (references > 0) entries.push({ kind: 'item', label: words.addVisitRefs(references), onSelect: () => present(false, true) });"#),
            (Self.explorer, #"if hasSourceNote && !unprintedPointers.isEmpty { Button { presentPlanPicker(volumeId: volumeId, documentId: docId, includeSource: true, includeExternalRefs: true)"#,
             Self.sourcesScreen, #"if (sources.hasSourceNote && references > 0) entries.push({ kind: 'item', label: words.addVisitBoth, onSelect: () => present(true, true) });"#),
            (Self.explorer, #"documents: [(volumeId: volumeId, documentId: documentId)],"#,
             Self.sourcesScreen, #"documents: [{ volumeId: sources.volumeId, documentId: sources.documentId }],"#),
            (Self.explorer, #"Text(String(localized: "source.explorer.rawNote.header", defaultValue: "Source Note")) Spacer()"#,
             Self.sourcesScreen, #"<Section title={words.rawNote} action={<AddToVisit sources={sources} />}>"#),
            (Self.explorer, #"if !hasSourceNote { addToVisitMenu }"#,
             Self.sourcesScreen, #"action={sources.hasSourceNote ? undefined : <AddToVisit sources={sources} />}"#),
            // Archival Neighbors: the documents shown, the source alone.
            (Self.neighbors, #"documents: docs.map { (volumeId: $0.volumeId, documentId: $0.documentId) }, includeSource: true, includeExternalRefs: false,"#,
             Self.neighboursScreen, #"documents: data.documents.map((document) => ({ volumeId: document.volumeId, documentId: document.documentId })), includeSource: true, includeExternalRefs: false,"#),
            (Self.neighbors, #"Int64(docs.count)))"#, Self.neighboursScreen, #"basis: copy.visits.basisNeighbors(data.documents.length),"#),
            // A record's citing documents: every one, to the app's ceiling, the source alone, the record's name for a plan.
            (Self.record, #"private static let planSeedFetchCeiling = 20_000"#, Self.packet, #"static let planSeedFetchCeiling = 20_000"#),
            (Self.record, #"names: [record.name] + record.aliases, limit: Self.planSeedFetchCeiling) else { return }"#,
             Self.packet, #"names: [record.name] + record.aliases, limit: planSeedFetchCeiling))"#),
            (Self.record, #"guard !result.documents.isEmpty else { return }"#, Self.recordScreen, #"if (seeds.documents.length === 0) return;"#),
            (Self.record, #"if result.totalCount > result.documents.count {"#, Self.recordScreen, #"seeds.totalCount > seeds.documents.length"#),
            (Self.record, #"includeSource: true, includeExternalRefs: false, basis: basis, suggestedName: record.name)"#,
             Self.recordScreen, #"suggestedName: seeds.name,"#),
            (Self.record, #"Int64(stats.documentCount)),"#, Self.recordScreen, #"{words.addToVisit(collection.documentCount)}"#),
            (Self.record, #".disabled(isFetchingPlanSeeds)"#, Self.recordScreen, #"aria-disabled={fetching || undefined}"#),
            // A collection's editor: its reading list, both halves, the collection's names.
            (Self.collectionEditor, #"documents: docs, includeSource: true, includeExternalRefs: true,"#,
             Self.collectionScreen, #"includeSource: true, includeExternalRefs: true,"#),
            (Self.collectionEditor, #"CollectionEditorNaming.listName(savedName: collection.name)),"#,
             Self.packet, #"listName: CollectionEditorNaming.listName(savedName: collection.name),"#),
            (Self.collectionEditor, #"suggestedName: collection.name.trimmingCharacters(in: .whitespacesAndNewlines))"#,
             Self.packet, #"suggestedName: collection.name.trimmingCharacters(in: .whitespacesAndNewlines))"#),
            (Self.collectionEditor, #".disabled(orderedDocumentKeys.isEmpty && !sortedEntries.contains { $0.entryKind == .excerpt && !$0.volumeId.isEmpty && !$0.documentId.isEmpty } && linkedSavedSearchId == nil)"#,
             Self.collectionScreen, #"documents.length > 0 || entries.some((entry) => entry.kind === 'excerpt' && entry.volumeId !== '' && entry.documentId !== '') || detail.savedSearchId != null;"#),
            (Self.collectionEditor, #"addToVisitError = error.localizedDescription"#, Self.collectionScreen, #"setAddToVisitError(errorMessage(error));"#),
            (Self.sheet, #"return refs.sorted { $0.sortOrder < $1.sortOrder } .map { (volumeId: $0.volumeId, documentId: $0.documentId) }"#,
             Self.packet, #"return refs.sorted { $0.sortOrder < $1.sortOrder } .map { (volumeId: $0.volumeId, documentId: $0.documentId) }"#),
            (Self.sheet, #"return staticSeedDocuments(from: collection.documentEntries ?? [])"#,
             Self.packet, #"return TripPacketSeed.staticSeedDocuments(from: collection.entries.map {"#),
            (Self.tripPacketApp, #"(kind: $0.entryKind, volumeId: $0.volumeId, documentId: $0.documentId, sortOrder: $0.sortOrder)"#,
             Self.packet, #"(kind: $0.entryKind, volumeId: $0.volumeId, documentId: $0.documentId, sortOrder: $0.sortOrder)"#),
            // Project Home's Plan a Visit: the project's plan opened, or made from its engaged documents, and its gate.
            (Self.projectHome, #"allArchiveVisits.first { $0.projectIds.contains(projectId) }"#, Self.packet, #"plans.first { $0.projectIds.contains(project.id) }"#),
            (Self.projectHome, #"guard !engagedPacketDocuments.isEmpty else { return }"#, Self.packet, #"guard !engaged.isEmpty else {"#),
            (Self.projectHome, #"let created = ArchiveVisitPlan.make(name: project.name, activeProject: project)"#,
             Self.packet, #"var plan = ArchiveVisitPlanWrites.newPlan(name: project.name, projectId: project.id, researchQuestion: project.researchQuestion,"#),
            (Self.projectHome, #"created.addSeeds(engagedPacketDocuments, includeSource: true, includeExternalRefs: true, in: modelContext)"#,
             Self.packet, #"ArchiveVisitRoutes.apply(ArchiveVisitPlanWrites.addingSeeds(engaged, includeSource: true, includeExternalRefs: true,"#),
            (Self.projectHome, #"return keys.compactMap { DocumentKey(compositeString: $0)?.tuple }"#,
             Self.packet, #"return keys.compactMap { DocumentKey(compositeString: $0)?.tuple }"#),
            (Self.projectHome, #".disabled(engagedPacketDocuments.isEmpty && projectPlan == nil)"#,
             Self.projectScreen, #"const offered = visit.data !== undefined && (visit.data.engagedDocuments > 0 || visit.data.planId != null);"#),
            // The review sheet: a row a plan the document seeds, by its display name, then its id.
            (Self.review, #"rows.append((id: id, name: plan.displayName, plan: plan))"#,
             Self.reviews, #"return ReviewOthers.Plan(id: id, name: ArchiveVisitPlanWrites.displayName(of: fields.optionalText("name") ?? ""))"#),
            (Self.review, #"let c = $0.name.localizedCaseInsensitiveCompare($1.name) return c != .orderedSame ? c == .orderedAscending : $0.id.uuidString < $1.id.uuidString"#,
             Self.reviews, #"let c = $0.name.localizedCaseInsensitiveCompare($1.name) return c != .orderedSame ? c == .orderedAscending : $0.id < $1.id"#),
            (Self.review, #"ForEach(planRows, id: \.id) { row in Button { openPlan(row.plan) }"#,
             Self.reviewScreen, #"<Link to="/visits/$planId" params={{ planId: plan.id }}> {words.openPlan(plan.name)} </Link>"#),
        ])
        // The review's rows follow Edit Tags…, as the app's do.
        let review = try SearchSetParityTests.app(Self.review)
        let order = ["document.review.other.editTags", "document.review.other.openPlan %@"].compactMap { review.range(of: $0)?.lowerBound }
        #expect(order.count == 2 && order == order.sorted())
        let sheet = try SearchSetParityTests.web("reader/ReviewSheet.tsx")
        let web = ["{words.editTags}", "{words.openPlan(plan.name)}"].compactMap { sheet.range(of: $0)?.lowerBound }
        #expect(web.count == 2 && web == web.sorted())
    }

    @Test func theWordsAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let sheet = try sources.app(Self.sheet)
        let picker = try sources.app(Self.picker)
        let editor = try sources.app(Self.editor)
        let explorer = try sources.app(Self.explorer)
        let neighbors = try sources.app(Self.neighbors)
        let record = try sources.app(Self.record)
        let collectionEditor = try sources.app(Self.collectionEditor)
        let projectHome = try sources.app(Self.projectHome)
        let review = try sources.app(Self.review)
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let visits = try NoteViewParityTests.block("visits", of: copy)

        for (source, key, words, block, line) in [
            (editor, "archiveVisit.editor.export", "Export packet", visits, "exportPacket: 'Export packet',"),
            (picker, "archiveVisit.picker.title", "Add to Archives Visit", visits, "pickerTitle: 'Add to Archives Visit',"),
            (picker, "archiveVisit.picker.adding.both %@", "Adding %@: archival sources + unprinted references", visits,
             "pickerAddingBoth: (documents: string) => `Adding ${documents}: archival sources + unprinted references`,"),
            (picker, "archiveVisit.picker.adding.source %@", "Adding %@: archival sources", visits,
             "pickerAddingSource: (documents: string) => `Adding ${documents}: archival sources`,"),
            (picker, "archiveVisit.picker.adding.refs %@", "Adding %@: unprinted references", visits,
             "pickerAddingRefs: (documents: string) => `Adding ${documents}: unprinted references`,"),
            (picker, "archiveVisit.picker.search.placeholder", "Search Archives Visits…", visits, "pickerSearch: 'Search Archives Visits…',"),
            (picker, "archiveVisit.picker.added.a11y", "Added", visits, "pickerAdded: 'Added',"),
            (picker, "archiveVisit.picker.new", "New Archives Visit", visits, "new: 'New Archives Visit',"),
            (picker, "common.cancel", "Cancel", visits, "cancel: 'Cancel',"),
            (explorer, "archiveVisit.basis.sourceExplorer", "from Source Explorer", visits, "basisSourceExplorer: 'from Source Explorer',"),
            (neighbors, "archiveVisit.basis.neighbors %lld", "the %lld neighbors shown", visits,
             "basisNeighbors: (count: number) => `the ${count} neighbors shown`,"),
            (record, "archiveVisit.basis.unit %@", "the documents citing “%@”", visits, "basisUnit: (name: string) => `the documents citing “${name}”`,"),
            (record, "archiveVisit.basis.unit.partial %lld %lld %@", "the first %lld of %lld documents citing “%@”", visits,
             "basisUnitPartial: (shown: number, total: number, name: string) => `the first ${shown} of ${total} documents citing “${name}”`,"),
            (collectionEditor, "archiveVisit.basis.collection %@", "from the collection “%@”", visits,
             "basisCollection: (name: string) => `from the collection “${name}”`,"),
            (collectionEditor, "archiveVisit.collection.error.title", "Couldn’t Add to Archives Visit", visits,
             "collectionErrorTitle: 'Couldn’t Add to Archives Visit',"),
            (collectionEditor, "common.ok", "OK", visits, "ok: 'OK',"),
            (sheet, "packet.title", "Archives Visit", visits, "packetTitle: 'Archives Visit',"),
            (sheet, "packet.building", "Reading your documents’ source notes…", visits, "packetBuilding: 'Reading your documents’ source notes…',"),
            (sheet, "packet.empty.noIndex.title", "The search index isn’t ready", visits, "packetNoIndexTitle: 'The search index isn’t ready',"),
            (sheet, "packet.empty.title", "Nothing to plan yet", visits, "packetEmptyTitle: 'Nothing to plan yet',"),
            (sheet, "packet.empty.noDocuments.message",
             "There are no documents here to plan over. Add documents to a collection, write a note on one, or apply a focus tag — the packet is built from the documents you have engaged with.",
             visits,
             "packetEmpty: 'There are no documents here to plan over. Add documents to a collection, write a note on one, or apply a focus tag — the packet is built from the documents you have engaged with.',"),
            (sheet, "packet.options", "Options", visits, "packetOptions: 'Options',"),
            (sheet, "packet.scope.picker", "Repository", visits, "packetScope: 'Repository',"),
            (sheet, "packet.scope.all", "All repositories", visits, "packetScopeAll: 'All repositories',"),
            (sheet, "packet.copyDraft.section", "Copy inquiry draft", visits, "packetCopyDraft: 'Copy inquiry draft',"),
            (sheet, "packet.deliverables.section", "What to Include", visits, "packetDeliverables: 'What to Include',"),
            (sheet, "packet.deliverables.links", "Repository visit-planning links", visits, "packetLinks: 'Repository visit-planning links',"),
            (sheet, "packet.deliverables.targets", "Target list", visits, "packetTargets: 'Target list',"),
            (sheet, "packet.deliverables.inquiry", "Inquiry email drafts", visits, "packetInquiry: 'Inquiry email drafts',"),
            (sheet, "packet.appendix.crib", "Include NARA citation guidance", visits, "packetCrib: 'Include NARA citation guidance',"),
            (sheet, "packet.topic.header", "Inquiry topic sentence", visits, "packetTopicHeader: 'Inquiry topic sentence',"),
            (sheet, "packet.topic.caption.seeded",
             "Seeded from your project’s research question — edit freely. The drafts include what you write here, never the stored note.", visits,
             "packetTopicSeeded: 'Seeded from your project’s research question — edit freely. The drafts include what you write here, never the stored note.',"),
            (sheet, "packet.topic.caption.unseeded", "The inquiry drafts include what you write here.", visits,
             "packetTopicUnseeded: 'The inquiry drafts include what you write here.',"),
            (sheet, "common.done", "Done", visits, "done: 'Done',"),
            (explorer, "source.explorer.addVisit", "Add to Archives Visit", try NoteViewParityTests.block("sources", of: copy),
             "addVisit: 'Add to Archives Visit',"),
            (explorer, "source.explorer.addVisit.source", "Add archival source", try NoteViewParityTests.block("sources", of: copy),
             "addVisitSource: 'Add archival source',"),
            (explorer, "source.explorer.addVisit.refs %lld", "Add unprinted references (%lld)", try NoteViewParityTests.block("sources", of: copy),
             "addVisitRefs: (count: number) => `Add unprinted references (${count})`,"),
            (explorer, "source.explorer.addVisit.both", "Add both", try NoteViewParityTests.block("sources", of: copy), "addVisitBoth: 'Add both',"),
            (neighbors, "archivalNeighbors.addToVisit %lld", "Add the %lld shown to an Archives Visit…",
             try NoteViewParityTests.block("archivalNeighbors", of: copy), "addToVisit: (count: number) => `Add the ${count} shown to an Archives Visit…`,"),
            (record, "collection.detail.addToVisit %lld", "Add the %lld citing documents to an Archives Visit…",
             try NoteViewParityTests.block("archivalCollection", of: copy),
             "addToVisit: (count: number) => `Add the ${count} citing documents to an Archives Visit…`,"),
            (collectionEditor, "collection.addToVisit", "Add to Archives Visit…", try NoteViewParityTests.block("collectionEditor", of: copy),
             "addToVisit: 'Add to Archives Visit…',"),
            (projectHome, "project.home.planVisit", "Plan a Visit", try NoteViewParityTests.block("projectHome", of: copy), "planVisit: 'Plan a Visit',"),
            (review, "document.review.other.openPlan %@", "Open the plan “%@”", try NoteViewParityTests.block("review", of: copy),
             "openPlan: (name: string) => `Open the plan “${name}”`,"),
        ] {
            #expect(NoteViewParityTests.writes(source, key, words), "the app writes \(key)")
            #expect(block.contains(NoteViewParityTests.flattened(line)), "copy.ts holds \(line)")
        }

        // Where the app's sheet shares, the web saves; where it speaks of a device's indexing, of this server: both held.
        for (source, key, words, line) in [
            (sheet, "packet.share", "Share", "packetSaveText: 'Save as Text',"),
            (sheet, "packet.share.pdf", "Share as PDF", "packetSavePDF: 'Save as PDF',"),
            (editor, "archiveVisit.editor.export.help",
             "Open this plan’s packet — its research targets, repository visit-planning links and inquiry email drafts — to share as plain text or as a PDF",
             "exportPacketHelp: 'Open this plan’s packet — its research targets, repository visit-planning links and inquiry email drafts — to save as plain text or as a PDF',"),
            (sheet, "packet.empty.noIndex.message",
             "The packet reads source notes from the search index, which isn’t available yet. Finish indexing and try again.",
             "packetNoIndex: 'The packet reads source notes from the search index, which this server isn’t serving yet. Try again once it is.',"),
        ] {
            #expect(NoteViewParityTests.writes(source, key, words), "the app writes \(key)")
            #expect(visits.contains(NoteViewParityTests.flattened(line)), "copy.ts holds \(line)")
        }
    }
}
