// The collection editor's rules (PLAN's S18d), over the research data export's values of a collection,
// `CollectionExport` and its `CollectionEntryExport`s, which the store's rows map to. The outline's
// core is FRUSCoreKit's (`CollectionOutline`: the depths, the section ranges and the move order, over
// `StructuralRef`), and so are the presets' recipes, the kinds, the block types and the naming; what
// the app keeps over its SwiftData models is mirrored here, each rule from the file and type the
// comment names, and `CollectionParityTests` holds each to the app's source at the pin:
// `CollectionOutline+App.swift`'s normalize, indent and outdent; `CollectionEntryData.swift`'s
// `CollectionEntryOrdering` and `sortedByDate`; the editor's appends, deletes, moves and presets
// (`CollectionEditorView.swift`); the document and excerpt appends (`CollectionDocumentDiscovery`,
// `CollectionExcerpts`); `Collection.duplicate(in:)`, the footnote flags, `documentCount` and
// `SmartCollectionRule` (`Models/Collection.swift`); `CollectionPreset.applyFields(to:)` and
// `matches(_:)` (`CollectionExporter+App.swift`); and the inspector's selections, resolved defaults
// and, from PLAN's S18f, its headnote card (`CollectionEntryInspector.swift`).

import FRUSCoreKit
import FRUSLightCore
import Foundation

enum CollectionEditing {

    // MARK: - Ordering (`CollectionEntryOrdering`)

    /// The entries in the order they sit, `CollectionEntryOrdering.modelOrder(of:)` with no outline: by
    /// position, and at a shared position by id.
    static func modelOrder(_ entries: [CollectionEntryExport]) -> [CollectionEntryExport] {
        entries.sorted { a, b in
            a.sortOrder != b.sortOrder ? a.sortOrder < b.sortOrder : a.id.uuidString < b.id.uuidString
        }
    }

    /// `CollectionEntryOrdering.nextSortOrder(in:outline:)`: one past the highest position any entry
    /// holds, or 0 when there is none. Never a count.
    static func nextSortOrder(_ entries: [CollectionEntryExport]) -> Int {
        (entries.map(\.sortOrder).max() ?? -1) + 1
    }

    /// The first of `count` positions after the last entry, `nextSortOrder`'s. The web's own where the
    /// highest position leaves no room for them, as an import of an edited file can: the entries are
    /// renumbered in their order first, where the app's arithmetic would trap, and with it a server
    /// every user shares.
    static func appendOrder(making count: Int, in collection: inout CollectionExport) -> Int {
        let highest = collection.entries.map(\.sortOrder).max() ?? -1
        if highest >= Int.max - count { renumber(&collection.entries) }
        return nextSortOrder(collection.entries)
    }

    /// `CollectionEntryOrdering.renumber(_:in:)` over the whole outline, which holds every entry the
    /// store does: `0..<n` in its order.
    static func renumber(_ outline: inout [CollectionEntryExport]) {
        for index in outline.indices { outline[index].sortOrder = index }
    }

    // MARK: - The outline (`CollectionOutline+App.swift`)

    /// `CollectionOutline.StructuralRef(_ entry:)`.
    static func ref(_ entry: CollectionEntryExport) -> CollectionOutline.StructuralRef {
        CollectionOutline.StructuralRef(isHeading: entry.entryKind == .heading, level: entry.level ?? 1,
                                        bodyDepthOverride: entry.bodyDepthOverride)
    }

    /// Each position's resolved depth, the kit's `resolvedDepths` over the outline.
    static func depths(_ outline: [CollectionEntryExport]) -> [Int] {
        CollectionOutline.resolvedDepths(outline.map(ref))
    }

    /// The section a heading owns, the kit's `sectionRange(of:refs:)`.
    static func sectionRange(of index: Int, in outline: [CollectionEntryExport]) -> Range<Int> {
        CollectionOutline.sectionRange(of: index, refs: outline.map(ref))
    }

    /// `CollectionOutline.normalize(_:)`: writes the resolved level onto each heading whose stored one
    /// differs, and onto no other.
    static func normalize(_ outline: inout [CollectionEntryExport]) {
        let resolved = depths(outline)
        for index in outline.indices where outline[index].entryKind == .heading {
            if outline[index].level != resolved[index] { outline[index].level = resolved[index] }
        }
    }

    /// `CollectionOutline.canIndent(_:in:)`: a heading below the cap whose nearest preceding heading
    /// sits at its level or deeper; the first heading never.
    static func canIndent(_ index: Int, in outline: [CollectionEntryExport]) -> Bool {
        guard outline.indices.contains(index), outline[index].entryKind == .heading else { return false }
        let resolved = depths(outline)
        let level = resolved[index]
        guard level < CollectionOutline.maxLevel else { return false }
        for i in stride(from: index - 1, through: 0, by: -1) where outline[i].entryKind == .heading {
            return resolved[i] >= level
        }
        return false
    }

    /// `CollectionOutline.canOutdent(_:in:)`: any heading deeper than level 1.
    static func canOutdent(_ index: Int, in outline: [CollectionEntryExport]) -> Bool {
        guard outline.indices.contains(index), outline[index].entryKind == .heading else { return false }
        return depths(outline)[index] > 1
    }

    /// `CollectionOutline.indentSection(at:in:)`: the heading and every heading of its section a level
    /// deeper, capped, then normalized. Nothing when it cannot indent.
    static func indentSection(at index: Int, in outline: inout [CollectionEntryExport]) {
        guard canIndent(index, in: outline) else { return }
        shiftSection(at: index, by: +1, in: &outline)
        normalize(&outline)
    }

    /// `CollectionOutline.outdentSection(at:in:)`: the heading and its section's headings a level up,
    /// then normalized. Nothing when it cannot outdent.
    static func outdentSection(at index: Int, in outline: inout [CollectionEntryExport]) {
        guard canOutdent(index, in: outline) else { return }
        shiftSection(at: index, by: -1, in: &outline)
        normalize(&outline)
    }

    /// `CollectionOutline.shiftSection(at:by:items:)`, from the resolved depths.
    private static func shiftSection(at index: Int, by delta: Int, in outline: inout [CollectionEntryExport]) {
        let resolved = depths(outline)
        for i in sectionRange(of: index, in: outline) where outline[i].entryKind == .heading {
            outline[i].level = min(max(resolved[i] + delta, 1), CollectionOutline.maxLevel)
        }
    }

    /// `CollectionOutline.applyingMove(_:fromIndex:toOffset:)`: the kit's move order, a heading taking
    /// its section; nil for a move into its own block or one that changes nothing.
    static func applyingMove(_ outline: [CollectionEntryExport], fromIndex: Int, toOffset: Int) -> [CollectionEntryExport]? {
        guard let order = CollectionOutline.movedOrder(outline.map(ref), fromIndex: fromIndex, toOffset: toOffset) else {
            return nil
        }
        return order.map { outline[$0] }
    }

    /// The editors' `finishOutlineMutation()`: renumbered, then normalized, the order the Mac's
    /// manager learnt (1.10), since normalize reads the positions.
    static func finishOutlineMutation(_ outline: inout [CollectionEntryExport]) {
        renumber(&outline)
        normalize(&outline)
    }

    // MARK: - What a collection takes (`SmartCollectionRule`)

    /// `SmartCollectionRule.takesHandAddedEntries(savedSearchId:)`: only a collection with no link.
    static func takesHandAddedEntries(_ collection: CollectionExport) -> Bool {
        collection.savedSearchId == nil
    }

    /// `SmartCollectionRule.leavesOut(_:savedSearchId:)`: a smart collection's documents, headings,
    /// note blocks and passages, which everything it produces leaves out.
    static func leavesOut(_ kind: CollectionEntryKind, savedSearchId: UUID?) -> Bool {
        guard savedSearchId != nil else { return false }
        switch kind {
        case .document, .heading, .prose, .excerpt: return true
        case .generated, .unrecognized: return false
        }
    }

    /// `Collection.documentCount`: its `.document` entries, a document added twice counting twice.
    static func documentCount(_ entries: [CollectionEntryExport]) -> Int {
        entries.count { $0.entryKind == .document }
    }

    /// `CollectionDocumentDiscovery.duplicateDocumentKeys(in:)`: the keys more than one document entry
    /// holds, which the rows badge "Also in collection".
    static func duplicateDocumentKeys(in entries: [CollectionEntryExport]) -> Set<String> {
        var counts: [String: Int] = [:]
        for entry in entries where entry.entryKind == .document {
            counts["\(entry.volumeId)/\(entry.documentId)", default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    // MARK: - New entries

    /// `CollectionEntry.init(collectionId:documentId:volumeId:sortOrder:researchNoteId:selectedNoteIds:)`
    /// with every other stored property at its initial value: a document entry, level 1, no overrides.
    static func newEntry(documentId: String, volumeId: String, sortOrder: Int, at time: Date) -> CollectionEntryExport {
        CollectionEntryExport(id: UUID(), documentId: documentId, volumeId: volumeId, sortOrder: sortOrder,
                              researchNoteId: nil, selectedNoteIds: [], createdAt: time, lastModified: time,
                              kind: CollectionEntryKind.document.rawValue, level: 1, selectedHighlightIds: [])
    }

    /// `CollectionEntryOrdering.appendBlock(kind:to:outline:modelContext:)` and the editor's
    /// `addStructuralEntry(kind:)`: an empty section heading or note block at the end, its text "", then
    /// the outline renumbered. Nothing for a smart collection, which takes neither, and nothing is
    /// renumbered for it.
    @discardableResult
    static func appendBlock(_ kind: CollectionEntryKind, to collection: inout CollectionExport, at time: Date) -> CollectionEntryExport? {
        guard takesHandAddedEntries(collection) else { return nil }
        var entry = newEntry(documentId: "", volumeId: "", sortOrder: appendOrder(making: 1, in: &collection), at: time)
        entry.kind = kind.rawValue
        entry.text = ""
        collection.entries.append(entry)
        renumber(&collection.entries)
        return collection.entries.last
    }

    /// The editor's `addGeneratedEntry(type:)`: an apparatus block, which a smart collection takes too,
    /// before the first entry for a front-matter type and after the last for a back-matter one, then
    /// the outline renumbered.
    @discardableResult
    static func addGeneratedEntry(_ type: CollectionGeneratedBlockType, to collection: inout CollectionExport,
                                  at time: Date) -> CollectionEntryExport {
        var entry = newEntry(documentId: "", volumeId: "", sortOrder: 0, at: time)
        entry.kind = CollectionEntryKind.generated.rawValue
        entry.generatedBlockType = type.rawValue
        switch type.defaultPosition {
        case .frontMatter: collection.entries.insert(entry, at: 0)
        case .backMatter: collection.entries.append(entry)
        }
        renumber(&collection.entries)
        return entry
    }

    /// `CollectionDocumentDiscovery.appendEntries(_:collection:sortedEntries:modelContext:)`, Add
    /// Documents' add: each document at the end in the order given, the first at `nextSortOrder` and
    /// each after it one more, a document the collection holds added again (decision A4). Nothing for a
    /// smart collection: whether it took them.
    @discardableResult
    static func appendEntries(_ documents: [DocumentKey], to collection: inout CollectionExport, at time: Date) -> Bool {
        guard takesHandAddedEntries(collection) else { return false }
        var next = appendOrder(making: documents.count, in: &collection)
        for document in documents {
            collection.entries.append(newEntry(documentId: document.documentId, volumeId: document.volumeId,
                                               sortOrder: next, at: time))
            next += 1
        }
        return true
    }

    /// The Add to Collection picker's add of one document (`CollectionPickerSheet.addDocument(to:)`):
    /// nothing when a `.document` entry holds it already, an excerpt of it not counting, else
    /// `CollectionDocumentDiscovery.appendToCollection` at `nextSortOrder`, renumbering nothing.
    /// Whether it added it.
    static func appendToCollection(_ document: DocumentKey, to collection: inout CollectionExport, at time: Date) -> Bool {
        guard !collection.entries.contains(where: {
            $0.entryKind == .document && $0.documentId == document.documentId && $0.volumeId == document.volumeId
        }) else { return false }
        let order = appendOrder(making: 1, in: &collection)
        collection.entries.append(newEntry(documentId: document.documentId, volumeId: document.volumeId, sortOrder: order, at: time))
        return true
    }

    // MARK: - Excerpts (`CollectionExcerpts`)

    /// `CollectionExcerptCapture`: the frozen passage, its document, and the anchors its source had.
    struct ExcerptCapture: Equatable, Sendable {
        let text: String
        let volumeId: String
        let documentId: String
        let start: Int?
        let end: Int?
        let renderingVersion: String?
        let colorTag: String?
    }

    /// `CollectionExcerpts.capture(from:)`: a highlight's passage, offsets, version and colour, its
    /// version nil when it stored none; nil for one with no passage.
    static func capture(from highlight: DocumentHighlightExport) -> ExcerptCapture? {
        guard !highlight.selectedText.isEmpty else { return nil }
        return ExcerptCapture(text: highlight.selectedText, volumeId: highlight.volumeId, documentId: highlight.documentId,
                              start: highlight.startOffset, end: highlight.endOffset,
                              renderingVersion: highlight.renderingVersion.isEmpty ? nil : highlight.renderingVersion,
                              colorTag: highlight.colorTag)
    }

    /// `CollectionExcerpts.makeEntry(from:collectionId:sortOrder:)`: an `.excerpt` entry with the
    /// passage as its text, the document as its provenance and the anchors copied as they are.
    static func makeEntry(from capture: ExcerptCapture, sortOrder: Int, at time: Date) -> CollectionEntryExport {
        var entry = newEntry(documentId: capture.documentId, volumeId: capture.volumeId, sortOrder: sortOrder, at: time)
        entry.kind = CollectionEntryKind.excerpt.rawValue
        entry.text = capture.text
        entry.excerptStart = capture.start
        entry.excerptEnd = capture.end
        entry.excerptRenderingVersion = capture.renderingVersion
        entry.excerptColorTag = capture.colorTag
        return entry
    }

    /// `CollectionExcerpts.append(_:to:sortedEntries:modelContext:)`: each capture an excerpt at the end,
    /// in order, from `nextSortOrder`; nothing for a smart collection. Whether it took them.
    @discardableResult
    static func appendExcerpts(_ captures: [ExcerptCapture], to collection: inout CollectionExport, at time: Date) -> Bool {
        guard takesHandAddedEntries(collection) else { return false }
        var next = appendOrder(making: captures.count, in: &collection)
        for capture in captures {
            collection.entries.append(makeEntry(from: capture, sortOrder: next, at: time))
            next += 1
        }
        return true
    }

    // MARK: - Deletes and moves (`CollectionEditorView`)

    /// The editor's `deleteHeadingOnly(at:)`, and `deleteVisibleRow(_:)` for any other row: the one
    /// entry, a heading's contents left where they are and its sub-headings lifted by normalize, then
    /// `finishOutlineMutation()`. The store deletes its headnote draft with it.
    static func deleteEntry(at index: Int, in collection: inout CollectionExport) {
        guard collection.entries.indices.contains(index) else { return }
        collection.entries.remove(at: index)
        finishOutlineMutation(&collection.entries)
    }

    /// The editor's `deleteSection(at:)`: the heading and every entry of its section, then
    /// `finishOutlineMutation()`.
    static func deleteSection(at index: Int, in collection: inout CollectionExport) {
        let range = sectionRange(of: index, in: collection.entries)
        guard range.upperBound <= collection.entries.count else { return }
        collection.entries.removeSubrange(range)
        finishOutlineMutation(&collection.entries)
    }

    /// The editor's `moveVisibleRows(_:to:visible:)` once a row and its drop are full-outline
    /// positions: the kit's move, then `finishOutlineMutation()`. Whether it moved anything.
    @discardableResult
    static func move(from index: Int, to offset: Int, in collection: inout CollectionExport) -> Bool {
        guard let reordered = applyingMove(collection.entries, fromIndex: index, toOffset: offset) else { return false }
        collection.entries = reordered
        finishOutlineMutation(&collection.entries)
        return true
    }

    // MARK: - Sort by Date (`CollectionEntryData.sortedByDate`)

    /// The two scopes of Sort by Date (`CollectionDateSortScope`).
    enum DateSortScope: String, CaseIterable, Sendable {
        case wholeCollection
        case withinSections
    }

    /// `CollectionEntryData.sortedByDate(_:documentDates:manifest:withinSections:)` and the editor's
    /// `sortByDate(withinSections:)`: the documents reordered by their dates into the places documents
    /// hold, every other entry staying put, across the collection or within each heading's run, then
    /// renumbered.
    static func sortByDate(_ scope: DateSortScope, in collection: inout CollectionExport,
                           documentDates: [String: String], manifest: [VolumeManifestEntry]) {
        // Built with a loop, so that a duplicate manifest row cannot crash the sort.
        var volumeDateMap: [String: String] = [:]
        for entry in manifest {
            if let date = entry.dateRange.earliest { volumeDateMap[entry.volumeId] = date }
        }
        let entries = collection.entries
        guard scope == .withinSections else {
            collection.entries = globalSortedByDate(entries, documentDates: documentDates, volumeDateMap: volumeDateMap)
            renumber(&collection.entries)
            return
        }
        var result: [CollectionEntryExport] = []
        result.reserveCapacity(entries.count)
        var run: [CollectionEntryExport] = []
        for entry in entries {
            if entry.entryKind == .heading, !run.isEmpty {
                result.append(contentsOf: globalSortedByDate(run, documentDates: documentDates, volumeDateMap: volumeDateMap))
                run = []
            }
            run.append(entry)
        }
        if !run.isEmpty {
            result.append(contentsOf: globalSortedByDate(run, documentDates: documentDates, volumeDateMap: volumeDateMap))
        }
        collection.entries = result
        renumber(&collection.entries)
    }

    /// `CollectionEntryData.globalSortedByDate`: the document entries by their day, else their volume's
    /// earliest, else "9999", into the slots documents hold.
    private static func globalSortedByDate(_ entries: [CollectionEntryExport], documentDates: [String: String],
                                           volumeDateMap: [String: String]) -> [CollectionEntryExport] {
        let sortedDocs = entries
            .filter { $0.entryKind == .document }
            .sorted { a, b in
                let aDate = documentDates["\(a.volumeId)/\(a.documentId)"] ?? volumeDateMap[a.volumeId] ?? "9999"
                let bDate = documentDates["\(b.volumeId)/\(b.documentId)"] ?? volumeDateMap[b.volumeId] ?? "9999"
                return aDate < bDate
            }
        var docs = sortedDocs.makeIterator()
        return entries.map { $0.entryKind == .document ? (docs.next() ?? $0) : $0 }
    }

    // MARK: - Composition (`Models/Collection.swift`, `CollectionExporter+App.swift`)

    /// `Collection.effectiveIncludeFootnotes`: the stored flag, else what the legacy style meant.
    static func effectiveIncludeFootnotes(_ collection: CollectionExport) -> Bool {
        collection.includeFootnotes
            ?? CollectionFootnoteStyle.derivedFlags(fromStyleRawValue: collection.footnoteStyle ?? "all").footnotes
    }

    /// `Collection.effectiveIncludeSourceNote`.
    static func effectiveIncludeSourceNote(_ collection: CollectionExport) -> Bool {
        collection.includeSourceNote
            ?? CollectionFootnoteStyle.derivedFlags(fromStyleRawValue: collection.footnoteStyle ?? "all").sourceNote
    }

    /// `Collection.writeFootnoteFlags(footnotes:sourceNote:)`, both effective setters' one write: the
    /// two flags and the legacy style that best fits them, for old readers.
    static func writeFootnoteFlags(footnotes: Bool, sourceNote: Bool, to collection: inout CollectionExport) {
        collection.includeFootnotes = footnotes
        collection.includeSourceNote = sourceNote
        collection.footnoteStyle = CollectionFootnoteStyle.bestFitRawValue(footnotes: footnotes, sourceNote: sourceNote)
    }

    /// `CollectionPreset.applyFields(to:)`: the preset's recipe over the composition's fields.
    static func applyFields(_ preset: CollectionPreset, to collection: inout CollectionExport) {
        let r = preset.recipe
        collection.defaultBodyDepth = r.bodyDepth.rawValue
        writeFootnoteFlags(footnotes: r.footnotes, sourceNote: effectiveIncludeSourceNote(collection), to: &collection)
        writeFootnoteFlags(footnotes: effectiveIncludeFootnotes(collection), sourceNote: r.sourceNote, to: &collection)
        collection.includeNotes = r.notes
        collection.defaultIncludeHeadnote = r.headnotes
        collection.applyHighlights = r.highlights
        collection.includeWordCloud = r.wordCloud
        collection.tocStyle = r.toc.rawValue
    }

    /// `CollectionPreset.matches(_:)`: whether every composition field is the recipe's, the apparatus
    /// not compared.
    static func matches(_ preset: CollectionPreset, _ collection: CollectionExport) -> Bool {
        let r = preset.recipe
        return collection.defaultBodyDepth == r.bodyDepth.rawValue
            && effectiveIncludeFootnotes(collection) == r.footnotes
            && effectiveIncludeSourceNote(collection) == r.sourceNote
            && collection.includeNotes == r.notes
            && collection.defaultIncludeHeadnote == r.headnotes
            && collection.applyHighlights == r.highlights
            && collection.includeWordCloud == r.wordCloud
            && collection.tocStyle == r.toc.rawValue
    }

    /// The editor's `applyPreset(_:)`: the fields, then each of the preset's apparatus blocks the
    /// collection does not carry, added at its type's place.
    static func applyPreset(_ preset: CollectionPreset, to collection: inout CollectionExport, at time: Date) {
        applyFields(preset, to: &collection)
        let present = Set(collection.entries.compactMap {
            $0.entryKind == .generated ? $0.generatedBlockType : nil
        })
        for block in preset.apparatusBlocks(notAlreadyIn: present) {
            addGeneratedEntry(block, to: &collection, at: time)
        }
    }

    // MARK: - Duplicate (`Collection.duplicate(in:)`)

    /// `Collection.duplicate(in:)`: "%@ copy" of the name, or of "Untitled Collection" for none; the
    /// description, the projects, the front matter, the colophon, the smart link and the composition
    /// copied, but not the two export stamps the app's copy leaves at their defaults; and a copy of every
    /// entry in order, each field as it was, under new ids, each entry's own headnote draft copied for
    /// it (`GeneratedSummary.duplicateHeadnoteDraft(from:to:in:)`), a document's own summary it chose
    /// left shared. A draft the store holds but the server cannot read, among `unreadable`, the copy
    /// leaves out, the web's own: shared, a delete of either entry would take the other's.
    static func duplicate(_ source: CollectionExport, drafts: [UUID: GeneratedSummaryExport], unreadable: Set<UUID> = [],
                          at time: Date) -> (collection: CollectionExport, drafts: [GeneratedSummaryExport]) {
        // The kit's "Untitled Collection" for an empty name, which the app's copy does not trim.
        let base = source.name.isEmpty ? CollectionEditorNaming.listName(savedName: "") : source.name
        var copy = CollectionExport(
            id: UUID(), name: duplicateName(base),
            note: source.note, projectIds: source.projectIds, savedSearchId: source.savedSearchId, entries: [],
            createdAt: time, lastModified: time,
            subtitle: source.subtitle, authorLine: source.authorLine,
            introductionText: source.introductionText, introductionRichText: source.introductionRichText,
            includeColophon: source.includeColophon, includeProjectProvenance: false, includeMethodAppendix: false,
            defaultBodyDepth: source.defaultBodyDepth, footnoteStyle: source.footnoteStyle,
            includeFootnotes: source.includeFootnotes, includeSourceNote: source.includeSourceNote,
            tocStyle: source.tocStyle, applyHighlights: source.applyHighlights, includeNotes: source.includeNotes,
            includeWordCloud: source.includeWordCloud, defaultIncludeHeadnote: source.defaultIncludeHeadnote,
            summaryPromptId: source.summaryPromptId)
        var copiedDrafts: [GeneratedSummaryExport] = []
        for entry in modelOrder(source.entries) {
            var e = entry
            e.id = UUID()
            e.createdAt = time
            e.lastModified = time
            if let draftId = entry.headnoteSummaryId, var draft = drafts[draftId] {
                draft.id = UUID()
                draft.authorship = draft.authorship ?? .aiGenerated
                draft.isHeadnoteDraft = true
                draft.createdAt = time
                draft.lastModified = time
                copiedDrafts.append(draft)
                e.headnoteSummaryId = draft.id
            } else if let draftId = entry.headnoteSummaryId, unreadable.contains(draftId) {
                e.headnoteSummaryId = nil
            }
            copy.entries.append(e)
        }
        return (copy, copiedDrafts)
    }

    /// The copy's name, the app's `collection.duplicate.name %@`, "%@ copy".
    static func duplicateName(_ base: String) -> String { "\(base) copy" }

    // MARK: - The inspector (`CollectionEntryInspector`)

    /// `setHighlightIncluded(_:_:)`: one highlight's inclusion, among `all`, the document's: every one
    /// selected is the empty set, all; none selected is the empty set with highlights turned off, since
    /// the empty set cannot mean none.
    static func setHighlightIncluded(_ id: UUID, _ include: Bool, all: [UUID], in entry: inout CollectionEntryExport) {
        let held = entry.selectedHighlightIds ?? []
        var selected = held.isEmpty ? all : held
        if include {
            if !selected.contains(id) { selected.append(id) }
        } else {
            selected.removeAll { $0 == id }
        }
        if Set(selected).isSuperset(of: all) {
            entry.selectedHighlightIds = []
        } else if selected.isEmpty {
            entry.selectedHighlightIds = []
            entry.applyHighlightsOverride = false
        } else {
            entry.selectedHighlightIds = selected
        }
    }

    /// `highlightIncluded(_:)`: an empty selection is all.
    static func highlightIncluded(_ id: UUID, in entry: CollectionEntryExport) -> Bool {
        let held = entry.selectedHighlightIds ?? []
        return held.isEmpty || held.contains(id)
    }

    /// `setNoteIncluded(_:_:)`: as for a highlight, seeded from the effective set, the legacy single-note
    /// link moved into the selection and cleared at the first edit.
    static func setNoteIncluded(_ id: UUID, _ include: Bool, all: [UUID], in entry: inout CollectionEntryExport) {
        var selected: [UUID]
        if !entry.selectedNoteIds.isEmpty {
            selected = entry.selectedNoteIds
        } else if let legacy = entry.researchNoteId {
            selected = [legacy]
        } else {
            selected = all
        }
        entry.researchNoteId = nil
        if include {
            if !selected.contains(id) { selected.append(id) }
        } else {
            selected.removeAll { $0 == id }
        }
        if Set(selected).isSuperset(of: all) {
            entry.selectedNoteIds = []
        } else if selected.isEmpty {
            entry.selectedNoteIds = []
            entry.includeNotesOverride = false
        } else {
            entry.selectedNoteIds = selected
        }
    }

    /// `noteIncluded(_:)`: the selection, else the legacy link's one note, else all.
    static func noteIncluded(_ id: UUID, in entry: CollectionEntryExport) -> Bool {
        if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.contains(id) }
        if let legacy = entry.researchNoteId { return legacy == id }
        return true
    }

    /// `ResolvedEntryDefaults`: what a document entry's overrides resolve to at Default.
    struct ResolvedDefaults: Equatable, Sendable {
        let bodyDepth: CollectionBodyDepth
        let highlights: Bool
        let notes: Bool
        let sourceNote: Bool
        let footnotes: Bool
        let related: Bool
        let summaryPromptId: UUID?
        let headnote: Bool
    }

    /// `resolvedEntryDefaults`: each override's nearest ancestor heading's value, by the kit's cascade
    /// (`sectionOverrideValues`), else the collection's; the body depth by `CollectionBodyDepth.resolve`;
    /// the headnote the collection's, with no section default. Nil for a heading, whose own values are
    /// the section's.
    static func resolvedDefaults(of index: Int, in collection: CollectionExport) -> ResolvedDefaults? {
        let ordered = collection.entries
        guard ordered.indices.contains(index), ordered[index].entryKind != .heading else { return nil }
        let refs = ordered.map(ref)
        func section<Value>(_ field: (CollectionEntryExport) -> Value?) -> Value? {
            CollectionOutline.sectionOverrideValues(
                refs, headingValues: ordered.map { $0.entryKind == .heading ? field($0) : nil })[index]
        }
        return ResolvedDefaults(
            bodyDepth: CollectionBodyDepth.resolve(entryOverride: nil, sectionOverride: section { $0.bodyDepthOverride },
                                                   collectionDefault: collection.defaultBodyDepth ?? "full"),
            highlights: section { $0.applyHighlightsOverride } ?? collection.applyHighlights ?? false,
            notes: section { $0.includeNotesOverride } ?? collection.includeNotes ?? true,
            sourceNote: section { $0.includeSourceNoteOverride } ?? effectiveIncludeSourceNote(collection),
            footnotes: section { $0.includeFootnotesOverride } ?? effectiveIncludeFootnotes(collection),
            related: section { $0.includeRelatedDocuments } ?? false,
            summaryPromptId: section { $0.summaryPromptIdOverride } ?? collection.summaryPromptId,
            headnote: collection.defaultIncludeHeadnote ?? false)
    }

    // MARK: - The headnote card (`CollectionEntryInspector`, PLAN's S18f)

    /// `headnoteDraftPromptId`: the prompt every headnote draft carries, which no prompt holds.
    static let headnoteDraftPromptId = UUID(uuidString: "0EAD0000-0000-4000-8000-000000000001")!

    /// `currentHeadnoteSummary`: the entry's own pick, a draft among them, when it holds text; else the
    /// document's stored summaries but drafts and those with no text, the one under the entry's prompt,
    /// its override else what Default resolves to, else the first, here the newest by `ranksAbove`, the
    /// store's order, where the app's fetch sets none.
    static func currentHeadnoteSummary(chosen: SummaryRecord?, stored: [SummaryRecord], promptId: UUID?) -> SummaryRecord? {
        if let chosen, !chosen.responseText.isEmpty { return chosen }
        let candidates = stored.filter { !$0.isHeadnoteDraft && !$0.responseText.isEmpty }
        return promptId.flatMap { pid in candidates.first { UUID(uuidString: $0.promptId) == pid } } ?? candidates.first
    }

    /// What `commitHeadnote(seed:)` saves, nil for nothing: the text trimmed, nothing when that is empty or
    /// the seed's own text trimmed; AI · edited when the seed is the model's, generated or edited, and holds
    /// text, else Yours. A seed with no authorship is the model's, as every reader takes one.
    static func headnoteCommit(_ text: String, seed: SummaryRecord?) -> (text: String, authorship: SummaryAuthorship)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, seed?.responseText.trimmingCharacters(in: .whitespacesAndNewlines) != trimmed else { return nil }
        let seedAuthorship = seed.map { $0.authorship.flatMap(SummaryAuthorship.init(rawValue:)) ?? .aiGenerated }
        let seedIsAIDerived = seedAuthorship == .aiGenerated || seedAuthorship == .aiEdited
        let authorship: SummaryAuthorship = (seedIsAIDerived && !(seed?.responseText.isEmpty ?? true)) ? .aiEdited : .userWritten
        return (trimmed, authorship)
    }

    /// `swapHeadnoteDraft(text:authorship:)`'s new draft on the entry's document:
    /// `GeneratedSummary(documentId:volumeId:promptId:responseText:authorship:isHeadnoteDraft:)` under the
    /// drafts' prompt, made now, every other field at its initial value. The draft the entry named before
    /// is deleted with the write that makes this one, if it is a draft.
    static func headnoteDraft(_ text: String, authorship: SummaryAuthorship, of entry: CollectionEntryExport,
                              at time: Date) -> GeneratedSummaryExport {
        GeneratedSummaryExport(id: UUID(), documentId: entry.documentId, volumeId: entry.volumeId, promptId: headnoteDraftPromptId,
                               responseText: text, responseFormat: .general, wasChunked: false, projectId: nil, createdAt: time,
                               lastModified: time, authorship: authorship, isHeadnoteDraft: true)
    }
}
