// What the server and the browser app mirror of the app's Archives Visits (PLAN's S30c), held to the app's source at the
// pin, line beside line. The derivation, its overlay and every write are the kit's (`ArchiveVisitDerivation`,
// `ArchiveVisitPlanWrites`), computed on the server and held to the kit by `ArchiveVisitParityTests`; what is mirrored is the
// app's view and its appliers: the Targets list's sections, their order and links, a row's lines, the stored targets and
// their captions, the seeds' facts and switches, the four filters and their reset, the empty states, the menus, the list's
// order and line, the writes' one field each, and every word, the server's and copy.ts's, under the app's key. Where the app
// speaks of a device, its sync or its index, the web speaks of this server, and both texts are held. A pin move that changes
// one fails here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct ArchiveVisitMirrorParityTests {
    static let editor = "TripPacket/ArchiveVisitEditorView.swift"
    static let list = "TripPacket/ArchiveVisitListView.swift"
    static let appliers = "TripPacket/ArchiveVisitDerivation+App.swift"
    static let model = "Models/ArchiveVisitPlan.swift"
    static let sidebar = "Research/ResearchView.swift"
    static let exporter = "kit:FRUSCoreKit/TripPacket/TripPacketExporter.swift"
    static let server = "Sources/FRUSLightAPI/ArchiveVisits.swift"
    static let rules = "web:visits/visitRules.ts"
    static let screen = "web:visits/VisitEditorScreen.tsx"
    static let listScreen = "web:visits/VisitsScreen.tsx"

    @Test func theSectionsAndTheirRowsAreTheViews() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // The sections, each repository then "Confirm before you travel", by the kit's rule the summary counts by.
            (Self.editor, #"ArchiveVisitCounts.sectionHeadings(of: derived.model.targets)"#,
             Self.server, #"sections = ArchiveVisitCounts.sectionHeadings(of: model.targets).map { heading in"#),
            (Self.editor, #"let members = visible.filter { sectionKey(for: $0) == heading }"#,
             Self.server, #"let members = model.targets.filter { ArchiveVisitCounts.sectionHeading(for: $0) == heading }"#),
            // Within a repository: tier groups in order, Unprioritized last, label-sorted within a group.
            (Self.editor, #"let l = derived.overlay.tierOrderIndex(for: $0.key) let r = derived.overlay.tierOrderIndex(for: $1.key) if l != r { return l < r } return $0.label < $1.label"#,
             Self.server, #"let l = overlay.tierOrderIndex(for: $0.key) let r = overlay.tierOrderIndex(for: $1.key) if l != r { return l < r } return $0.label < $1.label"#),
            // A section's header: its verified links, found by its exact name.
            (Self.editor, #"let row = RepositoryFactTable.current.row(forHeading: heading)"#,
             Self.server, #"let links = RepositoryFactTable.current.row(forHeading: heading)?.links.filter(\.isPrintable) ?? []"#),
            (Self.editor, #"ForEach(row.links.filter(\.isPrintable), id: \.url) { link in"#,
             Self.screen, #"{section.links.map((link) => ("#),
            // A target's row: its records line, its claims, its substitute, its access lines, its lots, its note, its exclusion.
            (Self.editor, #"if let line = target.recordsLine {"#, Self.server, #"recordsLine: target.recordsLine"#),
            (Self.editor, #"target.drawnFrom.contains { derived.model.substitutes.matchesByDocument[$0.id] != nil }"#,
             Self.server, #"substitute: target.drawnFrom.contains { model.substitutes.matchesByDocument[$0.id] != nil }"#),
            (Self.editor, #"ForEach(TripPacketExporter.restrictionLines(target.restriction), id: \.self) {"#,
             Self.server, #"accessLines: TripPacketExporter.restrictionLines(target.restriction)"#),
            (Self.editor, #"Text(String(format: String(localized: "archiveVisit.target.lot %@ %@", defaultValue: "Lot %1$@ — %2$@"), lot.lotAsPrinted, CountCopy.documents(lot.documentCount)))"#,
             Self.server, #"title: String(format: "Lot %1$@ — %2$@", lot.lotAsPrinted, CountCopy.documents(lot.documentCount, locale: locale))"#),
            (Self.editor, #"ForEach(TripPacketExporter.restrictionLines(lot.restriction), id: \.self) {"#,
             Self.server, #"accessLines: TripPacketExporter.restrictionLines(lot.restriction)"#),
            (Self.editor, #"if let note = derived.overlay.notes[target.key] {"#, Self.server, #"note: overlay.notes[target.key])"#),
            (Self.editor, #"let excluded = derived.overlay.excludedKeys.contains(target.key)"#,
             Self.server, #"excluded: overlay.excludedKeys.contains(target.key)"#),
            (Self.editor, #".strikethrough(excluded)"#, "web:styles/app.css", #".visit-target.excluded .visit-target-label { color: var(--text-secondary); text-decoration: line-through; }"#),
            (Self.editor, #"Text(derived.overlay.tier(for: key) .map { derived.overlay.displayName(for: $0) } ?? String(localized: "archiveVisit.target.setTier", defaultValue: "Set tier"))"#,
             Self.screen, #"label={tier ?? copy.visits.setTier}"#),
            (Self.editor, #"Text(derived.overlay.tier(for: key) .map { derived.overlay.displayName(for: $0) }"#,
             Self.server, #"tierId: overlay.tier(for: target.key)?.id.uuidString, excluded:"#),
            // The seedings, each claim's list capped at the packet's eight, the footnote's line the packet's.
            (Self.editor, #"ForEach(target.drawnFrom.prefix(TripPacketExporter.seedingRowLimit), id: \.id) { doc in"#,
             Self.server, #"let limit = TripPacketExporter.seedingRowLimit"#),
            (Self.exporter, #"public static let seedingRowLimit = 8"#, Self.screen, #"const seedingRowLimit = 8;"#),
            (Self.editor, #"if target.drawnFrom.count > TripPacketExporter.seedingRowLimit {"#,
             Self.screen, #"{target.drawnFromCount > seedingRowLimit && <p className="meta small">{copy.visits.seedingsMore(target.drawnFromCount - seedingRowLimit)}</p>}"#),
            (Self.editor, #"Text(AttributedString(markdownBody: doc.citation)).font(.caption)"#, Self.screen, #"<Citation text={document.citation} />"#),
            (Self.editor, #"Text(quotedExcerpt(doc.sourceNote))"#, Self.screen, #"{copy.visits.quoted(document.sourceNote)}"#),
            (Self.editor, #"Text(AttributedString(markdownBody: TripPacketExporter.footnoteLine(for: seeding)))"#,
             Self.server, #"line: TripPacketExporter.footnoteLine(for: $0)"#),
            (Self.editor, #"if seeding.inherited {"#, Self.screen, #"{seeding.inherited && <p className="meta small">{copy.visits.inherited}</p>}"#),
            // The stored targets: the orphans, then the rows another is shown over, by their keys, each with its caption.
            (Self.editor, #"let superseded = derived.overlay.superseded.keys.sorted()"#, Self.server, #"for key in overlay.superseded.keys.sorted() {"#),
            (Self.editor, #"ForEach(derived.overlay.orphanKeys, id: \.self) { key in"#, Self.server, #"stored = overlay.orphanKeys.map { key in"#),
            (Self.editor, #"derived.model.targets.first { $0.key == entry.targetKey }?.label ?? orphanLabel(forKey: entry.targetKey)))"#,
             Self.server, #"partOf: model.targets.first { $0.key == entry.targetKey }?.label ?? storedLabel(entry.targetKey),"#),
            (Self.editor, #"if entry.excluded {"#, Self.server, #"excludedWhenOwn: entry.excluded))"#),
            (Self.editor, #"guard let bar = key.firstIndex(of: "|") else { return key } return String(key[key.index(after: bar)...])"#,
             Self.server, #"guard let bar = key.firstIndex(of: "|") else { return key } return String(key[key.index(after: bar)...])"#),
            (Self.editor, #"if let note = derived.overlay.notes[key] {"#, Self.server, #"note: overlay.notes[key], partOf: nil, excludedWhenOwn: false)"#),
            // The summary and the coverage, amber when this server lacks some of the documents.
            (Self.editor, #"if let derived, !(plan.documents ?? []).isEmpty {"#,
             Self.server, #"if !plan.documents.isEmpty { summary = ArchiveVisitCounts.editorSummary(of: model) }"#),
            (Self.editor, #"Text(ArchiveVisitCounts.editorSummary(of: derived.model))"#, Self.screen, #"{plan.summary && <p className="meta">{plan.summary}</p>}"#),
            (Self.editor, #"if derived.indexedDocumentCount < derived.seededDocumentCount {"#,
             Self.screen, #"{plan.indexedDocumentCount < plan.documentCount && ("#),
            (Self.editor, #".foregroundStyle(Color.orange)"#, Self.screen, #"<p className="count warning">{copy.visits.editorCoverage(plan.indexedDocumentCount, copy.visits.seeding(plan.documentCount))}</p>"#),
        ])
    }

    @Test func theFiltersAndTheEmptyStatesAreTheViews() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.editor, #"if let repositoryFilter, sectionKey(for: target) != repositoryFilter { return false }"#,
             Self.rules, #"if (filters.repository !== null && heading !== filters.repository) return false;"#),
            (Self.editor, #"if derived.overlay.tier(for: target.key) != nil { return false }"#, Self.rules, #"if (target.tierId != null) return false;"#),
            (Self.editor, #"if derived.overlay.tierAssignments[target.key] != id { return false }"#,
             Self.rules, #"if (target.tierId !== filters.tier.id) return false;"#),
            (Self.editor, #"case .drawnFrom: if target.drawnFrom.isEmpty { return false }"#, Self.rules, #"if (target.drawnFromCount === 0) return false;"#),
            (Self.editor, #"case .pointedAt: if target.pointedAt.isEmpty { return false }"#, Self.rules, #"if (target.pointedAtCount === 0) return false;"#),
            (Self.editor, #"if includedOnly, derived.overlay.excludedKeys.contains(target.key) { return false }"#,
             Self.rules, #"if (filters.includedOnly && target.excluded) return false;"#),
            (Self.editor, #"let sections = facilityHeadings(derived).filter { heading in visible.contains { sectionKey(for: $0) == heading } }"#,
             Self.rules, #".filter((section) => section.targets.length > 0);"#),
            (Self.editor, #"repositoryFilter != nil || tierFilter != .all || claimFilter != .all || includedOnly"#,
             Self.rules, #"filters.repository !== null || filters.tier.kind !== 'all' || filters.claim !== 'all' || filters.includedOnly"#),
            (Self.editor, #"repositoryFilter = nil tierFilter = .all claimFilter = .all includedOnly = false"#,
             Self.rules, #"export const noFilters: TargetFilters = { repository: null, tier: { kind: 'all' }, claim: 'all', includedOnly: false };"#),
            // The stale filters' reset after each answer.
            (Self.editor, #"!derived.overlay.tiers.contains(where: { $0.id == id }) {"#,
             Self.rules, #"if (!plan.tiers.some((tier) => tier.id === id)) fresh = { ...fresh, tier: { kind: 'all' } };"#),
            (Self.editor, #"if let repositoryFilter, !facilityHeadings(derived).contains(repositoryFilter) {"#,
             Self.rules, #"if (fresh.repository !== null && !plan.sections.some((section) => section.heading === fresh.repository)) {"#),
            // The tier filter's choices: All, each tier, Unprioritized last.
            (Self.editor, #"ForEach(derived.overlay.tiers) { tier in Text(derived.overlay.displayName(for: tier)) .tag(TierFilter.tier(tier.id)) }"#,
             Self.screen, #"{plan.tiers.map((tier) => ( <option key={tier.id} value={`tier:${tier.id}`}>"#),
            // The empty states, in the view's order.
            (Self.editor, #"if (plan.documents ?? []).isEmpty { Section { noSeedsView }"#, Self.screen, #"if (plan.documents.length === 0) return <NoSeeds />;"#),
            (Self.editor, #"} else if derived.model.targets.isEmpty {"#, Self.screen, #"{plan.sections.length === 0 ? ("#),
            (Self.editor, #"} else if visibleTargets(derived).isEmpty {"#, Self.screen, #") : sections.length === 0 ? ("#),
            (Self.editor, #"let anyOn = seeds.contains { $0.includeSource || $0.includeExternalRefs }"#,
             Self.rules, #"const anyOn = plan.documents.some((seed) => seed.includeSource || seed.includeExternalRefs);"#),
            (Self.editor, #"return parts.joined(separator: " · ")"#, Self.rules, #"return parts.join(' · ');"#),
        ])
    }

    @Test func theMenusTheSeedsAndTheListAreTheViews() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            // A target's menu: Edit Note…, and Include or Exclude; a stored row's Remove Stored State in its place.
            (Self.editor, #"setIncluded(excluded, forKey: key)"#, Self.screen, #"onSelect: () => onIncluded(target.excluded),"#),
            (Self.editor, #"Button(String(localized: "archiveVisit.tier.unprioritized", defaultValue: "Unprioritized")) { setTier(nil, forKey: key) }"#,
             Self.screen, #"{ kind: 'item', label: copy.visits.unprioritized, onSelect: () => onTier(null) },"#),
            (Self.editor, #"if let project = plan.owningProject(among: projects) {"#, Self.screen, #"...(plan.project ? ["#),
            (Self.model, #"guard let id = projectIds.first else { return nil } return projects.first { $0.id == id }"#,
             Self.server, #"let project = plan.projectIds.first.flatMap { id in projects.first { $0.id == id } }"#),
            (Self.editor, #"toast = String(localized: "archiveVisit.duplicate.toast", defaultValue: "Duplicated as “\(copy.displayName)”")"#,
             Self.screen, #"setStatus(copy.visits.duplicated(copied.displayName));"#),
            (Self.editor, #"plan.replaceInquiryTopic(with: pending.question)"#,
             Self.screen, #"onReplace={() => editVisit(client, plan.id, { inquiryText: dialog.question })}"#),
            (Self.editor, #"let name = ArchiveVisitPlanWrites.name(fromDraft: nameDraft) if name == nil { nameDraft = plan.name }"#,
             Self.screen, #"if (trimmed === '') { setDraft(plan.name);"#),
            // The tiers' sheet: each tier's members, the stored targets it holds.
            (Self.editor, #"let members = (plan.targets ?? []).filter { $0.tierId == tier.id }.count"#,
             Self.server, #"members: plan.targets.filter { $0.tierId == tier.id }.count)"#),
            // The seeds: their facts through the builder's two queries, and each row's two halves or its captions.
            (Self.editor, #"let relevant = (citations[key] ?? []).filter { $0.anchor != "centralFileClass" }"#,
             Self.server, #"let relevant = (citations[key] ?? []).filter { $0.anchor != "centralFileClass" }"#),
            (Self.editor, #"hasSourceNote: noteKeys.contains(key), referenceCount: relevant.count)"#,
             Self.server, #"hasSourceNote: noteKeys.contains(key), referenceCount: relevant.count)"#),
            (Self.editor, #"(plan.documents ?? []).sorted { $0.documentKey < $1.documentKey }"#,
             Self.server, #"documents: try ResearchExport.ordered(rows.documents, in: "visit_documents") { try $0.text("document_key") },"#),
            (Self.editor, #"Text(facts?.header ?? seed.documentKey)"#, Self.screen, #"const title = seed.header ?? seed.key;"#),
            (Self.editor, #"if seed.includeSource == false && seed.includeExternalRefs == false {"#,
             Self.screen, #"{!seed.includeSource && !seed.includeExternalRefs && <p className="count warning">{copy.visits.nothing}</p>}"#),
            (Self.editor, #"if facts?.hasSourceNote != false {"#, Self.screen, #"{seed.hasSourceNote !== false ? ("#),
            (Self.editor, #"if let count = facts?.referenceCount, count == 0 {"#, Self.screen, #"{seed.referenceCount === 0 ? ("#),
            // The list: most recently changed first, a row's line the kit's count or its documents', and its coverage.
            (Self.list, #"@Query(sort: \ArchiveVisitPlan.lastModified, order: .reverse)"#, Self.server, #"return x != y ? x > y : a.offset < b.offset"#),
            (Self.list, #"guard summaries[key] == nil, !(plan.documents ?? []).isEmpty,"#, Self.server, #"if let served, !plan.documents.isEmpty {"#),
            (Self.list, #"summaries[key] = ArchiveVisitCounts.listSummary(of: derived.model)"#,
             Self.server, #"summary = ArchiveVisitCounts.listSummary(of: try await derivation(of: plan, served: served, resources: resources).derived.model)"#),
            (Self.list, #"parts.append(CountCopy.documents((plan.documents ?? []).count))"#,
             Self.listScreen, #"const parts = [plan.summary ?? copy.visits.documents(plan.documentCount)];"#),
            (Self.list, #"return parts.joined(separator: " · ")"#, Self.listScreen, #"return parts.join(' · ');"#),
            (Self.list, #"if indexed < seeds.count {"#, Self.listScreen, #"{plan.indexedDocumentCount < plan.documentCount && ("#),
            (Self.list, #"opened = copy"#, Self.listScreen, #"void navigate({ to: '/visits/$planId', params: { planId: copied.id } });"#),
            (Self.list, #"let plan = ArchiveVisitPlan.make(name: "", activeProjectId: appState.activeProjectId, in: modelContext)"#,
             Self.server, #"let plan = ArchiveVisitPlanWrites.newPlan(name: body.name ?? "", projectId: project?.id, researchQuestion: project?.researchQuestion, id: UUID(), now: time)"#),
            (Self.model, #"let record = ArchiveVisitPlanWrites.newPlan(name: name, projectId: activeProject?.id, researchQuestion: activeProject?.researchQuestion)"#,
             Self.server, #"researchQuestion: project?.researchQuestion, id: UUID(), now: time)"#),
        ])
    }

    /// The app's appliers write the one field each rule changes, and the server's write the same fields.
    @Test func theWritesSetTheFieldsTheAppsAppliersSet() throws {
        try ArchivalAndSeriesMirrorParityTests.expect([
            (Self.appliers, #"if addition.turnsOnSource { seed.includeSource = update.record.includeSource }"#,
             Self.server, #"if addition.turnsOnSource { plan.documents[update.index].includeSource = update.record.includeSource }"#),
            (Self.appliers, #"if addition.turnsOnExternalRefs { seed.includeExternalRefs = update.record.includeExternalRefs }"#,
             Self.server, #"if addition.turnsOnExternalRefs { plan.documents[update.index].includeExternalRefs = update.record.includeExternalRefs }"#),
            (Self.appliers, #"row(written, among: rows, in: context).tierId = written.record.tierId"#,
             Self.server, #"case .stored(let row): plan.targets[row.index].tierId = row.record.tierId"#),
            (Self.appliers, #"row(written, among: rows, in: context).included = written.record.included"#,
             Self.server, #"case .stored(let row): plan.targets[row.index].included = row.record.included"#),
            (Self.appliers, #"row(written, among: rows, in: context).userNote = written.record.userNote"#,
             Self.server, #"case .stored(let row): plan.targets[row.index].userNote = row.record.userNote"#),
            (Self.appliers, #"rows[cleared.index].tierId = cleared.record.tierId"#,
             Self.server, #"for cleared in removal.clearedTargets { plan.targets[cleared.index].tierId = cleared.record.tierId }"#),
            (Self.appliers, #"if case .filled(let question) = reseed.topic { inquiryText = question }"#,
             Self.server, #"if case .filled(let question) = reseed.topic { plan.inquiryText = question }"#),
            (Self.appliers, #"func replaceInquiryTopic(with question: String) { inquiryText = question }"#,
             Self.server, #"if let topic = body.inquiryText { plan.inquiryText = TripPacketTopicSentence.written(topic) }"#),
            (Self.editor, #"plan.setNote(fromDraft: noteDraft, forKey: key, resolvedBy: derived?.overlay, in: modelContext)"#,
             Self.server, #"ArchiveVisitPlanWrites.settingNote(fromDraft: draft, forKey: body.key, resolvedBy: overlay,"#),
        ])
    }

    @Test func theWordsAndThePlaceAreTheApps() throws {
        let sources = NoteViewParityTests.Sources()
        let editor = try sources.app(Self.editor)
        let list = try sources.app(Self.list)
        let sidebar = try sources.app(Self.sidebar)
        let writes = try SearchSetParityTests.kit("FRUSCoreKit/TripPacket/ArchiveVisitPlanWrites.swift")
        let counts = try SearchSetParityTests.kit("FRUSCoreKit/Models/CountCopy.swift")
        let copy = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let block = try NoteViewParityTests.block("visits", of: copy)

        // Archives Visits in the iPhone's Research sidebar after Project Home and before the guide, its caption under it;
        // in the web's Research rows, pinned above the categories, and in Research's screens after History.
        let order = ["research.sidebar.projectHome", "research.sidebar.archiveVisits\"", "research.sidebar.guide.caption"]
            .compactMap { sidebar.range(of: $0)?.lowerBound }
        #expect(order.count == 3 && order == order.sorted())
        #expect(NoteViewParityTests.writes(sidebar, "research.sidebar.archiveVisits", "Archives Visits"))
        #expect(NoteViewParityTests.writes(sidebar, "research.sidebar.archiveVisits.caption", "Plans for consulting the records behind your documents"))
        #expect(block.contains("caption: 'Plans for consulting the records behind your documents',"))
        let page = try SearchSetParityTests.web("research/ResearchScreen.tsx")
        let pinned = ["<Link to=\"/visits\" className=\"research-category\">", "{category('allAnnotated',"].compactMap { page.range(of: $0)?.lowerBound }
        #expect(pinned.count == 2 && pinned == pinned.sorted())
        let nav = try SearchSetParityTests.web("research/ResearchNav.tsx")
        let screens = ["to=\"/research/history\"", "to=\"/visits\""].compactMap { nav.range(of: $0)?.lowerBound }
        #expect(screens.count == 2 && screens == screens.sorted())

        for (source, key, words, line) in [
            (list, "archiveVisit.list.title", "Archives Visits", "title: 'Archives Visits',"),
            (list, "archiveVisit.empty.title", "No Archives Visits", "emptyTitle: 'No Archives Visits',"),
            (list, "archiveVisit.new", "New Archives Visit", "new: 'New Archives Visit',"),
            (writes, "archiveVisit.untitled.name", "Untitled Archives Visit", "untitled: 'Untitled Archives Visit',"),
            (list, "archiveVisit.rename.title", "Rename Archives Visit", "renameTitle: 'Rename Archives Visit',"),
            (list, "archiveVisit.rename.placeholder", "Name", "renamePlaceholder: 'Name',"),
            (list, "common.rename", "Rename", "rename: 'Rename',"),
            (list, "common.duplicate", "Duplicate", "duplicate: 'Duplicate',"),
            (list, "common.delete", "Delete", "delete: 'Delete',"),
            (list, "common.cancel", "Cancel", "cancel: 'Cancel',"),
            (list, "common.save", "Save", "save: 'Save',"),
            (list, "archiveVisit.delete.title", "Delete this Archives Visit?", "deleteTitle: 'Delete this Archives Visit?',"),
            (list, "archiveVisit.list.modified %@", "Modified %@", "modified: (date: string) => `Modified ${date}`,"),
            (editor, "archiveVisit.editor.title", "Archives Visit", "editorTitle: 'Archives Visit',"),
            (editor, "archiveVisit.editor.name.a11y", "Archive visit name", "nameA11y: 'Archive visit name',"),
            (editor, "archiveVisit.editor.tab", "View", "tab: 'View',"),
            (editor, "archiveVisit.editor.tab.targets", "Targets", "tabTargets: 'Targets',"),
            (editor, "archiveVisit.editor.tab.documents", "Documents", "tabDocuments: 'Documents',"),
            (editor, "archiveVisit.editor.deriving", "Deriving research targets from the plan’s documents…",
             "deriving: 'Deriving research targets from the plan’s documents…',"),
            (editor, "archiveVisit.editor.about", "About research targets", "about: 'About research targets',"),
            (editor, "archiveVisit.editor.about.help", "What a research target is, what Drawn from and Pointed at mean, and why their counts are never added",
             "aboutHelp: 'What a research target is, what Drawn from and Pointed at mean, and why their counts are never added',"),
            (editor, "archiveVisit.info.sparsity",
             "Footnote references to unprinted material exist on only about 4% of documents corpus-wide (measured over the full index: 13,750 of 316,839), so a thin pointed-at list is expected — sparse data, not a failed scan.",
             "infoSparsity: 'Footnote references to unprinted material exist on only about 4% of documents corpus-wide (measured over the full index: 13,750 of 316,839), so a thin pointed-at list is expected — sparse data, not a failed scan.',"),
            (editor, "archiveVisit.editor.more", "More", "more: 'More',"),
            (editor, "archiveVisit.editor.tiers", "Priority Tiers…", "tiers: 'Priority Tiers…',"),
            (editor, "archiveVisit.editor.reseed", "Re-seed from Project", "reseed: 'Re-seed from Project',"),
            (editor, "archiveVisit.editor.noSeeds.title", "No documents seeded", "noSeedsTitle: 'No documents seeded',"),
            (editor, "archiveVisit.editor.allOff",
             "Every document’s contributions are switched off — turn a document’s archival source or unprinted references back on under Documents.",
             "allOff: 'Every document’s contributions are switched off — turn a document’s archival source or unprinted references back on under Documents.',"),
            (editor, "archiveVisit.editor.noMatches", "No targets match the current filters.", "noMatches: 'No targets match the current filters.',"),
            (editor, "archiveVisit.filter.clear", "Clear Filters", "clearFilters: 'Clear Filters',"),
            (editor, "archiveVisit.filter.repository", "Repository", "repository: 'Repository',"),
            (editor, "archiveVisit.filter.tier", "Tier", "tier: 'Tier',"),
            (editor, "archiveVisit.filter.claim", "Claim", "claim: 'Claim',"),
            (editor, "archiveVisit.filter.all", "All", "all: 'All',"),
            (editor, "archiveVisit.filter.includedOnly", "Included only", "includedOnly: 'Included only',"),
            (editor, "archiveVisit.claim.drawnFrom", "Drawn from", "drawnFrom: 'Drawn from',"),
            (editor, "archiveVisit.claim.pointedAt", "Pointed at", "pointedAt: 'Pointed at',"),
            (editor, "archiveVisit.tier.unprioritized", "Unprioritized", "unprioritized: 'Unprioritized',"),
            (editor, "archiveVisit.target.setTier", "Set tier", "setTier: 'Set tier',"),
            (editor, "archiveVisit.target.substitute", "⇄ Part of this record is digitized or filmed — read it that way instead of pulling.",
             "substitute: '⇄ Part of this record is digitized or filmed — read it that way instead of pulling.',"),
            (editor, "archiveVisit.target.excluded", "Excluded from the exported packet", "excluded: 'Excluded from the exported packet',"),
            (editor, "archiveVisit.target.editNote", "Edit Note…", "editNote: 'Edit Note…',"),
            (editor, "archiveVisit.target.include", "Include in Packet", "include: 'Include in Packet',"),
            (editor, "archiveVisit.target.exclude", "Exclude from Packet", "exclude: 'Exclude from Packet',"),
            (editor, "archiveVisit.target.removeStored", "Remove Stored State", "removeStored: 'Remove Stored State',"),
            (editor, "archiveVisit.row.drawnFrom.one", "drawn from 1 document",
             "drawnFromCount: (count: number) => (count === 1 ? 'drawn from 1 document' : `drawn from ${count.toLocaleString('en-US')} documents`),"),
            (editor, "archiveVisit.row.drawnFrom.other", #"drawn from \(n.formatted()) documents"#,
             "drawnFromCount: (count: number) => (count === 1 ? 'drawn from 1 document' : `drawn from ${count.toLocaleString('en-US')} documents`),"),
            (editor, "archiveVisit.row.pointedAt.one", "pointed at by 1 footnote",
             "count === 1 ? 'pointed at by 1 footnote' : `pointed at by ${count.toLocaleString('en-US')} footnotes`,"),
            (editor, "archiveVisit.row.pointedAt.other", #"pointed at by \(n.formatted()) footnotes"#,
             "count === 1 ? 'pointed at by 1 footnote' : `pointed at by ${count.toLocaleString('en-US')} footnotes`,"),
            (editor, "archiveVisit.claim.drawnFrom.header %lld", "Drawn from — %lld documents",
             "drawnFromHeader: (count: number) => `Drawn from — ${count} documents`,"),
            (editor, "archiveVisit.claim.pointedAt.header %lld", "Pointed at — %lld footnotes",
             "pointedAtHeader: (count: number) => `Pointed at — ${count} footnotes`,"),
            (editor, "archiveVisit.seedings.more %lld", "…and %lld more — the export carries the same capped list.",
             "seedingsMore: (count: number) => `…and ${count} more — the export carries the same capped list.`,"),
            (editor, "archiveVisit.seeding.quoted %@", "“%@”", "quoted: (text: string) => `“${text}”`,"),
            (editor, "archiveVisit.seeding.inherited", "Cited as “Ibid.” — inherited from the preceding footnote’s citation.",
             "inherited: 'Cited as “Ibid.” — inherited from the preceding footnote’s citation.',"),
            (editor, "archiveVisit.orphans.header", "Stored targets", "storedHeader: 'Stored targets',"),
            (editor, "archiveVisit.orphan.caption",
             "Stored target — no longer derives from this plan’s current seeds. Kept with your tier and notes; it never deletes itself.",
             "orphanCaption: 'Stored target — no longer derives from this plan’s current seeds. Kept with your tier and notes; it never deletes itself.',"),
            (editor, "archiveVisit.superseded.caption %@",
             "Stored target — now part of “%@”, which shows another stored row’s tier, note and exclusion. Kept with your tier and notes; it never deletes itself.",
             "`Stored target — now part of “${target}”, which shows another stored row’s tier, note and exclusion. Kept with your tier and notes; it never deletes itself.`,"),
            (editor, "archiveVisit.superseded.excluded", "Excluded from the packet when it was a target of its own.",
             "supersededExcluded: 'Excluded from the packet when it was a target of its own.',"),
            (editor, "archiveVisit.orphan.remove.title", "Remove this stored target?", "removeStoredTitle: 'Remove this stored target?',"),
            (editor, "archiveVisit.note.title", "Target Note", "noteTitle: 'Target Note',"),
            (editor, "archiveVisit.note.placeholder", "Note", "notePlaceholder: 'Note',"),
            (editor, "archiveVisit.reseed.topic.title", "Replace the inquiry topic?", "topicTitle: 'Replace the inquiry topic?',"),
            (editor, "archiveVisit.reseed.topic.replace", "Replace Topic", "topicReplace: 'Replace Topic',"),
            (editor, "archiveVisit.reseed.topic.keep", "Keep Current Topic", "topicKeep: 'Keep Current Topic',"),
            (editor, "archiveVisit.reseed.topic.filled", "The inquiry topic now reads the project’s research question.",
             "topicFilled: 'The inquiry topic now reads the project’s research question.',"),
            (editor, "archiveVisit.reseed.topic.message",
             #"The project’s research question now reads:\n\n“\(pending.question)”\n\nThis plan’s inquiry drafts include:\n\n“\(pending.current)”\n\nReplace the topic with the question?"#,
             "topicNow: 'The project’s research question now reads:', topicDrafts: 'This plan’s inquiry drafts include:', topicAsk: 'Replace the topic with the question?',"),
            (editor, "archiveVisit.document.nothing", "Contributes nothing to this plan", "nothing: 'Contributes nothing to this plan',"),
            (editor, "archiveVisit.document.source", "Archival source", "source: 'Archival source',"),
            (editor, "archiveVisit.document.noSource", "This document carries no source note", "noSource: 'This document carries no source note',"),
            (editor, "archiveVisit.document.noRefs", "No unprinted references in this document’s footnotes",
             "noRefs: 'No unprinted references in this document’s footnotes',"),
            (editor, "archiveVisit.document.refs.counted %lld", "Unprinted references · %lld", "refsCounted: (count: number) => `Unprinted references · ${count}`,"),
            (editor, "archiveVisit.document.refs", "Unprinted references", "refs: 'Unprinted references',"),
            (editor, "archiveVisit.document.open", "Open Document", "open: 'Open Document',"),
            (editor, "archiveVisit.document.remove", "Remove", "remove: 'Remove',"),
            (editor, "archiveVisit.documents.footer",
             "Each document contributes through two switches: its own source note (drawn from) and its footnotes’ citations to unprinted material (pointed at). References beyond FRUS exist on only about 4% of documents — where a half is absent, the control acts as a caption instead of a dead switch.",
             "documentsFooter: 'Each document contributes through two switches: its own source note (drawn from) and its footnotes’ citations to unprinted material (pointed at). References beyond FRUS exist on only about 4% of documents — where a half is absent, the control acts as a caption instead of a dead switch.',"),
            (editor, "archiveVisit.tiers.title", "Priority Tiers", "tiersTitle: 'Priority Tiers',"),
            (editor, "archiveVisit.tiers.add", "Add a priority tier", "addTier: 'Add a priority tier',"),
            (editor, "archiveVisit.tiers.footer", "Targets without a tier stay in Unprioritized, always listed last. An unlabeled tier reads “Priority 1”.",
             "tiersFooter: 'Targets without a tier stay in Unprioritized, always listed last. An unlabeled tier reads “Priority 1”.',"),
            (editor, "archiveVisit.tiers.members %lld", "%lld targets", "members: (count: number) => `${count} targets`,"),
            (editor, "archiveVisit.tiers.rename.title", "Rename Tier", "renameTier: 'Rename Tier',"),
            (editor, "archiveVisit.tiers.rename.placeholder", "Label", "tierLabel: 'Label',"),
            (editor, "archiveVisit.tiers.delete.confirm", "Delete Tier", "deleteTier: 'Delete Tier',"),
            (editor, "archiveVisit.tiers.delete.title %@", "Delete “%@”?", "deleteTierTitle: (tier: string) => `Delete “${tier}”?`,"),
            (editor, "archiveVisit.tiers.delete.message %lld", "Its %lld targets move to Unprioritized. Nothing is removed from the plan.",
             "deleteTierMessage: (count: number) => `Its ${count} targets move to Unprioritized. Nothing is removed from the plan.`,"),
            (editor, "common.done", "Done", "done: 'Done',"),
            (editor, "archiveVisit.editor.coverage.seeding.one", "%@ seeding document",
             "seeding: (count: number) => (count === 1 ? '1 seeding document' : `${count.toLocaleString('en-US')} seeding documents`),"),
            (editor, "archiveVisit.editor.coverage.seeding.many", "%@ seeding documents",
             "seeding: (count: number) => (count === 1 ? '1 seeding document' : `${count.toLocaleString('en-US')} seeding documents`),"),
            (counts, "count.documents.one", "%@ document",
             "documents: (count: number) => (count === 1 ? '1 document' : `${count.toLocaleString('en-US')} documents`),"),
            (counts, "count.documents.many", "%@ documents",
             "documents: (count: number) => (count === 1 ? '1 document' : `${count.toLocaleString('en-US')} documents`),"),
        ] {
            #expect(NoteViewParityTests.writes(source, key, words), "the app writes \(key)")
            #expect(block.contains(NoteViewParityTests.flattened(line)), "copy.ts holds \(line)")
        }

        // The app's words of a device, its sync and its index, which the web says of this server: both held.
        for (source, key, words, line) in [
            (list, "archiveVisit.empty.detail",
             "An Archives Visit uses information drawn from documents’ source notes to generate a draft research-trip plan. Seed one from Source Explorer, Archival Neighbors, a collection, or a project — or start empty below.",
             "emptyDetail: 'An Archives Visit uses information drawn from documents’ source notes to generate a draft research-trip plan. Seed one from a project — or start empty below.',"),
            (list, "archiveVisit.list.footer",
             "An Archives Visit is an initial draft of a plan for consulting the records behind these documents — what to see, in what order, at which repository. The whole plan syncs to your other devices.",
             "footer: 'An Archives Visit is an initial draft of a plan for consulting the records behind these documents — what to see, in what order, at which repository. The whole plan is kept on this server.',"),
            (list, "archiveVisit.delete.message",
             "This deletes the plan, its priority tiers, and its per-target notes — from your other devices too, after sync. Documents and volumes are untouched.",
             "deleteMessage: 'This deletes the plan, its priority tiers, and its per-target notes. Documents and volumes are untouched.',"),
            (list, "archiveVisit.coverage.v3", #"\(indexed.formatted()) of \(CountCopy.documents(seeds.count)) indexed on this device"#,
             "coverage: (indexed: number, documents: string) => `${indexed.toLocaleString('en-US')} of ${documents} indexed on this server`,"),
            (editor, "archiveVisit.editor.coverage.v3",
             #"\(derived.indexedDocumentCount.formatted()) of \(seeding) indexed on this device — targets from unindexed documents may be missing below."#,
             "`${indexed.toLocaleString('en-US')} of ${seeding} indexed on this server — targets from unindexed documents may be missing below.`,"),
            (editor, "archiveVisit.info.body",
             "A target is one archival unit under one claim. Drawn from: the document was published from this file — its own source note. Pointed at: the document’s footnotes cite this, unprinted. One document can seed several targets, each prioritized on its own; the two counts are never added because they answer different questions. A row is stored only once you give it a tier, a note, or an exclusion — the rest derives from the document seeds each time, so it always reflects the current app index.",
             "infoBody: 'A target is one archival unit under one claim. Drawn from: the document was published from this file — its own source note. Pointed at: the document’s footnotes cite this, unprinted. One document can seed several targets, each prioritized on its own; the two counts are never added because they answer different questions. A row is stored only once you give it a tier, a note, or an exclusion — the rest derives from the document seeds each time, so it always reflects the index this server serves.',"),
            (editor, "archiveVisit.info.sparsity.measured.v2",
             #"On this device: \(sparsity.withReferences.formatted()) of \(sparsity.indexed.formatted()) indexed documents carry such references."#,
             "`On this server: ${withReferences.toLocaleString('en-US')} of ${indexed.toLocaleString('en-US')} indexed documents carry such references.`,"),
            (editor, "archiveVisit.editor.noSeeds.detail",
             "Seed this plan from Source Explorer, Archival Neighbors, a collection, or a project — each surface offers Add to Archives Visit.",
             "noSeedsDetail: 'A plan made while a project is active can be seeded from it with Re-seed from Project.',"),
            (editor, "archiveVisit.editor.noTargets",
             "No targets derive from these documents on this device — their volumes may not be indexed yet, or their source notes name nothing the app can place.",
             "noTargets: 'No targets derive from these documents on this server — their volumes may not be indexed yet, or their source notes name nothing the server can place.',"),
            (editor, "archiveVisit.orphan.remove.message",
             "Its tier and note are deleted — from your other devices too, after sync. Nothing else in the plan changes.",
             "removeStoredMessage: 'Its tier and note are deleted. Nothing else in the plan changes.',"),
        ] {
            #expect(NoteViewParityTests.writes(source, key, words), "the app writes \(key)")
            #expect(block.contains(NoteViewParityTests.flattened(line)), "copy.ts holds \(line)")
        }
    }
}
