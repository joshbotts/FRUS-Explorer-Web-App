// The app's words and the lines of its code that the web takes for saved searches, working corpora,
// volume scopes and Checklist Mode (PLAN's S17e, and PLAN's rule for view code: "mirrored with a
// parity test that reads the app's source at the pin"), read from the app's source and from the web's
// at once: the Save Search and Saved Searches sheets and the window's bookmark buttons; the Save
// Working Corpus sheet, the window's banner and the filter's corpora and scopes; Browse's Working
// Corpora and My Scopes and the scope editor; the checklist's strip and toggle; and the rules mirrored,
// the lists' orders, the checklist's marks and anchor (web/src/search/checklist.ts), and the capture's
// account of what it saved (`CorpusCapture`, from `ResultSetScope`). A pin move that changes one fails
// here until the web follows it.

import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct SearchSetParityTests {
    static func app(_ path: String) throws -> String {
        NoteViewParityTests.flattened(try NoteViewParityTests.read(NoteViewParityTests.app, path))
    }

    static func kit(_ path: String) throws -> String {
        NoteViewParityTests.flattened(try NoteViewParityTests.read(NoteViewParityTests.upstream, path))
    }

    static func web(_ path: String) throws -> String {
        NoteViewParityTests.flattened(try NoteViewParityTests.read(NoteViewParityTests.web, path))
    }

    static func server(_ path: String) throws -> String {
        NoteViewParityTests.flattened(try String(contentsOf: RepositoryFiles.root.appendingPathComponent(path), encoding: .utf8))
    }

    /// Each word the web takes, where the app's source writes it under its key, and in copy.ts's block
    /// where the screen reads it.
    @Test func theAppsWordsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let blocks = try Dictionary(uniqueKeysWithValues: ["savedSearches", "corpora", "scopes", "checklist", "axes"].map {
            ($0, try NoteViewParityTests.block($0, of: raw))
        })
        let sheet = try Self.app("App/SearchSheet.swift")
        let save = try Self.app("Search/SaveSearchSheet.swift")
        let saved = try Self.app("Search/SavedSearchesView.swift")
        let capture = try Self.app("Search/SaveWorkingCorpusSheet.swift")
        let filter = try Self.app("Search/SearchFilterView.swift")
        let corpora = try Self.app("Browser/CorpusBrowseView.swift")
        let scopes = try Self.app("Browser/ScopeBrowseView.swift")
        let editor = try Self.app("Browser/ScopeEditorView.swift")
        let strip = try Self.app("Search/ChecklistStrip.swift")
        let browser = try Self.app("App/MacCorpusBrowserWindow.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (sheet, "SearchSheet", "search.saveSearch.a11y", "Save this search", "savedSearches", "save: 'Save this search'"),
            (sheet, "SearchSheet", "search.saveSearch.help", "Save this search so you can quickly run it again", "savedSearches",
             "saveHelp: 'Save this search so you can quickly run it again'"),
            (sheet, "SearchSheet", "search.savedSearches.a11y", "Saved searches", "savedSearches", "open: 'Saved searches'"),
            (sheet, "SearchSheet", "search.savedSearches.help", "Browse and re-run your saved searches", "savedSearches",
             "openHelp: 'Browse and re-run your saved searches'"),
            (save, "SaveSearchSheet", "search.saveSearch.title", "Save Search", "savedSearches", "saveTitle: 'Save Search'"),
            (save, "SaveSearchSheet", "search.saveSearch.section", "Name", "savedSearches", "nameLabel: 'Name'"),
            (save, "SaveSearchSheet", "search.saveSearch.placeholder", "Name this search", "savedSearches", "namePlaceholder: 'Name this search'"),
            (save, "SaveSearchSheet", "search.saveSearch.query", "Query", "savedSearches", "queryLabel: 'Query'"),
            (save, "SaveSearchSheet", "search.saveSearch.save", "Save", "savedSearches", "saveButton: 'Save'"),
            (save, "SaveSearchSheet", "search.saveSearch.cancel", "Cancel", "savedSearches", "cancel: 'Cancel'"),
            (saved, "SavedSearchesView", "savedSearches.title", "Saved Searches", "savedSearches", "title: 'Saved Searches'"),
            (saved, "SavedSearchesView", "savedSearches.empty.title", "No Saved Searches", "savedSearches", "emptyTitle: 'No Saved Searches'"),
            (saved, "SavedSearchesView", "savedSearches.done", "Done", "savedSearches", "done: 'Done'"),
            (saved, "SavedSearchesView", "savedSearches.rename.title", "Rename", "savedSearches", "renameTitle: 'Rename'"),
            (saved, "SavedSearchesView", "savedSearches.rename.placeholder", "Name", "savedSearches", "renamePlaceholder: 'Name'"),
            (saved, "SavedSearchesView", "savedSearches.rename.save", "Save", "savedSearches", "renameSave: 'Save'"),
            (saved, "SavedSearchesView", "savedSearches.rename.cancel", "Cancel", "savedSearches", "renameCancel: 'Cancel'"),
            (saved, "SavedSearchesView", "savedSearches.row.rename", "Rename", "savedSearches", "rename: 'Rename'"),
            (saved, "SavedSearchesView", "savedSearches.row.delete", "Delete", "savedSearches", "delete: 'Delete'"),
            (saved, "SavedSearchesView", "savedSearches.row.new", "NEW", "savedSearches", "newBadge: 'NEW'"),
            (sheet, "SearchSheet", "search.corpus.save", "Save as Working Corpus…", "corpora", "save: 'Save as Working Corpus…'"),
            (sheet, "SearchSheet", "search.corpus.save.help", "Save these results as a named working corpus you can search inside later",
             "corpora", "saveHelp: 'Save these results as a named working corpus you can search inside later'"),
            (sheet, "SearchSheet", "search.corpusScope.clear.help", "Leave this working corpus and search the full scope again", "corpora",
             "leaveHelp: 'Leave this working corpus and search the full scope again'"),
            (sheet, "SearchSheet", "search.corpusScope.clear.a11y", "Leave this working corpus", "corpora", "leave: 'Leave this working corpus'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.title", "Save Working Corpus", "corpora", "saveTitle: 'Save Working Corpus'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.name.header", "Name", "corpora", "nameHeader: 'Name'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.name.placeholder", "Corpus name", "corpora", "namePlaceholder: 'Corpus name'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.duplicate", "You already have a corpus with this name. Both will be kept.", "corpora",
             "duplicate: 'You already have a corpus with this name. Both will be kept.'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.provenance.header", "Captured", "corpora", "captured: 'Captured'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.documents", "Documents", "corpora", "documents: 'Documents'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.query", "From", "corpora", "from: 'From'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.narrowedBy", "Narrowed by", "corpora", "narrowedBy: 'Narrowed by'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.indexed", "Volumes indexed now", "corpora", "indexedNow: 'Volumes indexed now'"),
            (capture, "SaveWorkingCorpusSheet", "corpus.save.footer",
             "The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible.",
             "corpora",
             "footer: 'The set is fixed at capture. Re-running the query later may find different documents; this corpus will not change, which is what makes counts taken inside it reproducible.'"),
            (filter, "SearchFilterView", "search.section.workingCorpora", "My Working Corpora", "corpora", "filterTitle: 'My Working Corpora'"),
            (filter, "SearchFilterView", "search.corpus.clear", "Clear working corpus", "corpora", "clear: 'Clear working corpus'"),
            (corpora, "CorpusBrowseView", "browser.corpora.title", "Working Corpora", "corpora", "title: 'Working Corpora'"),
            (corpora, "CorpusBrowseView", "browser.corpora.empty.title", "No Working Corpora", "corpora", "emptyTitle: 'No Working Corpora'"),
            (corpora, "CorpusBrowseView", "browser.corpora.untitled", "Untitled Corpus", "corpora", "untitled: 'Untitled Corpus'"),
            (corpora, "CorpusBrowseView", "browser.corpora.row.help", "Browse this corpus’s documents, grouped by volume", "corpora",
             "rowHelp: 'Browse this corpus’s documents, grouped by volume'"),
            (corpora, "CorpusBrowseView", "browser.corpora.unavailable.title", "Corpus Unavailable", "corpora",
             "unavailableTitle: 'Corpus Unavailable'"),
            (filter, "SearchFilterView", "search.section.customScopes", "My Volume Scopes", "scopes", "filterTitle: 'My Volume Scopes'"),
            (filter, "SearchFilterView", "search.scope.custom.none", "No indexed volumes", "scopes", "noneIndexedRow: 'No indexed volumes'"),
            (filter, "SearchFilterView", "search.scope.custom.hint", "Fills the volume picker with this scope’s indexed volumes", "scopes",
             "applyHint: 'Fills the volume picker with this scope’s indexed volumes'"),
            (scopes, "ScopeBrowseView", "browser.scopes.title", "My Scopes", "scopes", "title: 'My Scopes'"),
            (scopes, "ScopeBrowseView", "browser.scopes.empty.title", "No Scopes Yet", "scopes", "emptyTitle: 'No Scopes Yet'"),
            (scopes, "ScopeBrowseView", "browser.scopes.new", "New Scope", "scopes", "new: 'New Scope'"),
            (scopes, "ScopeBrowseView", "browser.scopes.new.help", "Create an empty scope and choose its volumes", "scopes",
             "newHelp: 'Create an empty scope and choose its volumes'"),
            (scopes, "ScopeBrowseView", "browser.scopes.untitled", "Untitled Scope", "scopes", "untitled: 'Untitled Scope'"),
            (scopes, "ScopeBrowseView", "browser.scopes.row.empty", "No volumes yet", "scopes", "rowEmpty: 'No volumes yet'"),
            (scopes, "ScopeBrowseView", "browser.scopes.edit.help", "Rename this scope or change its volumes", "scopes",
             "editHelp: 'Rename this scope or change its volumes'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.title", "Edit Scope", "scopes", "editTitle: 'Edit Scope'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.name.header", "Name", "scopes", "nameHeader: 'Name'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.name.prompt", "Scope name", "scopes", "namePrompt: 'Scope name'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.clearName.a11y", "Clear the scope name", "scopes", "clearName: 'Clear the scope name'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.addVolumes", "Add Volumes…", "scopes", "addVolumes: 'Add Volumes…'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.addVolumes.help", "Choose volumes from the All Volumes catalogue", "scopes",
             "addVolumesHelp: 'Choose volumes from the All Volumes catalogue'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.picker.done", "Done", "scopes", "pickerDone: 'Done'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.picker.cancel", "Cancel", "scopes", "pickerCancel: 'Cancel'"),
            (editor, "ScopeEditorView", "browser.scopeEditor.unavailable.title", "Scope Unavailable", "scopes",
             "unavailableTitle: 'Scope Unavailable'"),
            (sheet, "SearchSheet", "search.checklist.short", "Checklist", "checklist", "toggle: 'Checklist'"),
            (sheet, "SearchSheet", "search.checklist.toggle", "Checklist Mode", "checklist", "toggleName: 'Checklist Mode'"),
            (sheet, "SearchSheet", "search.checklist.on.help", "Checklist review mode — hide results as you review them", "checklist",
             "onHelp: 'Checklist review mode — hide results as you review them'"),
            (sheet, "SearchSheet", "search.checklist.off.help", "Turn off Checklist Mode and show every result", "checklist",
             "offHelp: 'Turn off Checklist Mode and show every result'"),
            (sheet, "SearchSheet", "search.checklist.markReviewed", "Mark Reviewed", "checklist", "markReviewed: 'Mark Reviewed'"),
            (sheet, "SearchSheet", "search.checklist.allReviewed.title", "All Results Reviewed", "checklist",
             "allReviewedTitle: 'All Results Reviewed'"),
            (sheet, "SearchSheet", "search.checklist.allReviewed.detail", "You’ve reviewed every result. Turn off Checklist Mode to see them again.",
             "checklist", "allReviewedDetail: 'You’ve reviewed every result. Turn off Checklist Mode to see them again.'"),
            (strip, "ChecklistStrip", "search.checklist.nothingHidden", "Nothing hidden", "checklist", "nothingHidden: 'Nothing hidden'"),
            (strip, "ChecklistStrip", "search.checklist.markPage", "Mark Page Reviewed", "checklist", "markPage: 'Mark Page Reviewed'"),
            (strip, "ChecklistStrip", "search.checklist.markPage.help", "Hide every result on this page as reviewed", "checklist",
             "markPageHelp: 'Hide every result on this page as reviewed'"),
            (strip, "ChecklistStrip", "search.checklist.undo", "Undo", "checklist", "undo: 'Undo'"),
            (strip, "ChecklistStrip", "search.checklist.undo.help", "Bring back the results the last Mark Page Reviewed hid", "checklist",
             "undoHelp: 'Bring back the results the last Mark Page Reviewed hid'"),
            (browser, "MacCorpusBrowserWindow", "browser.scopes.title", "My Scopes", "axes", "scopes: 'My Scopes'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(blocks[word.block]?.contains(word.web) == true, "copy.ts's \(word.block) block holds \(word.web)")
        }
        // The words with a count or a name in them, as the app formats them and copy.ts's functions say them.
        let formats: [(source: String, file: String, line: String, block: String, web: String)] = [
            (saved, "SavedSearchesView", #"String(localized: "savedSearches.row.fresh %@", defaultValue: "+%@ since last run"), fresh.formatted())"#,
             "savedSearches", "fresh: (count: number) => `+${count.toLocaleString('en-US')} since last run`"),
            (sheet, "SearchSheet", #"String(localized: "search.corpusScope.label %@", defaultValue: "Inside “%@”"), name)"#,
             "corpora", "inside: (name: string) => `Inside “${name}”`"),
            (filter, "SearchFilterView", #"String(localized: "search.scope.custom.indexed %lld %lld", defaultValue: "%lld of %lld volumes indexed"), Int64(ids.count), Int64(scope.volumeIds.count))"#,
             "scopes", "`${indexed.toLocaleString('en-US')} of ${total.toLocaleString('en-US')} volumes indexed`"),
            (corpora, "CorpusBrowseView", #"defaultValue: "\(corpus.documentCount) documents")"#,
             "corpora", "rowCount: (count: number) => `${count.toLocaleString('en-US')} documents`"),
            (corpora, "CorpusBrowseView", #"defaultValue: "captured from “\(PinnedResultBase.quotable(query))”")"#,
             "corpora", "capturedFrom: (query: string) => `captured from “${query}”`"),
            (corpora, "CorpusBrowseView", #"defaultValue: "\(CorporaAxis.displayName(corpus)), \(corpus.documentCount) documents")"#,
             "corpora", "rowLabel: (name: string, count: number) => `${name}, ${count.toLocaleString('en-US')} documents`"),
            (scopes, "ScopeBrowseView", #"defaultValue: "\(ScopeAxis.displayName(scope)), \(scope.volumeIds.count) volumes")"#,
             "scopes", "rowLabel: (name: string, count: number) => `${name}, ${count.toLocaleString('en-US')} volumes`"),
            (scopes, "ScopeBrowseView", #"defaultValue: "\(scope.volumeIds.count) volumes · edited \(modified.formatted(date: .abbreviated, time: .omitted))")"#,
             "scopes", "`${count.toLocaleString('en-US')} volumes${edited ? ` · edited ${edited}` : ''}`"),
            (scopes, "ScopeBrowseView", #"defaultValue: "Edit \(ScopeAxis.displayName(scope))")"#, "scopes", "edit: (name: string) => `Edit ${name}`"),
            (scopes, "ScopeBrowseView", #"defaultValue: "\(resolved.count) volumes in this scope, by volume number.")"#,
             "scopes", "drillCaption: (count: number) => `${count.toLocaleString('en-US')} volumes in this scope, by volume number.`"),
            (editor, "ScopeEditorView", #"defaultValue: "Volumes (\(scope.volumeIds.count))")"#,
             "scopes", "volumesHeader: (count: number) => `Volumes (${count.toLocaleString('en-US')})`"),
            (editor, "ScopeEditorView", #"defaultValue: "Remove \(volumeId) from this scope")"#,
             "scopes", "remove: (volumeId: string) => `Remove ${volumeId} from this scope`"),
            (strip, "ChecklistStrip", #"String(localized: "search.checklist.hiddenBanner.v2 %@", defaultValue: "%@ reviewed hidden"), count.formatted(.number.locale(locale)))"#,
             "checklist", "hidden: (count: number) => `${count.toLocaleString('en-US')} reviewed hidden`"),
            (strip, "ChecklistStrip", #"one: String(localized: "search.checklist.marked.one", defaultValue: "%@ result marked reviewed"), many: String(localized: "search.checklist.marked.many", defaultValue: "%@ results marked reviewed")"#,
             "checklist", "marked: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'result' : 'results'} marked reviewed`"),
            (strip, "ChecklistStrip", #"one: String(localized: "search.checklist.undone.one", defaultValue: "%@ result is back in the list"), many: String(localized: "search.checklist.undone.many", defaultValue: "%@ results are back in the list")"#,
             "checklist", "undone: (count: number) => `${count.toLocaleString('en-US')} ${count === 1 ? 'result is' : 'results are'} back in the list`"),
        ]
        for format in formats {
            #expect(format.source.contains(format.line), "\(format.file) holds \(format.line)")
            #expect(blocks[format.block]?.contains(format.web) == true, "copy.ts's \(format.block) block holds \(format.web)")
        }
    }

    /// The lists' orders, as the app's queries sort them and the server's routes sort them: saved
    /// searches newest first, corpora by their capture, scopes by their last edit, and in the filter's
    /// sections both by name.
    @Test func theListsAreInTheAppsOrders() throws {
        NoteViewParityTests.expect(try Self.app("Search/SavedSearchesView.swift"), holds: [
            #"@Query(sort: \SavedSearch.createdAt, order: .reverse) private var savedSearchCopies: [SavedSearch]"#,
        ], file: "SavedSearchesView.swift")
        NoteViewParityTests.expect(try Self.app("Browser/CorpusBrowseView.swift"), holds: [
            #"@Query(sort: \WorkingCorpus.capturedAt, order: .reverse) private var corpora: [WorkingCorpus]"#,
        ], file: "CorpusBrowseView.swift")
        NoteViewParityTests.expect(try Self.app("Browser/ScopeBrowseView.swift"), holds: [
            #"@Query(sort: \CustomVolumeScope.lastModified, order: .reverse) private var scopes: [CustomVolumeScope]"#,
        ], file: "ScopeBrowseView.swift")
        NoteViewParityTests.expect(try Self.app("Search/SearchFilterView.swift"), holds: [
            #"@Query(sort: \CustomVolumeScope.name) private var customScopes: [CustomVolumeScope]"#,
        ], file: "SearchFilterView.swift")
        let server = try Self.server("Sources/FRUSLightAPI/SavedSearches.swift")
            + (try Self.server("Sources/FRUSLightAPI/WorkingCorpora.swift")) + (try Self.server("Sources/FRUSLightAPI/VolumeScopes.swift"))
        NoteViewParityTests.expect(server, holds: [
            "let (x, y) = (a.element.createdAt ?? .distantPast, b.element.createdAt ?? .distantPast) return x != y ? x > y : a.offset < b.offset",
            "let (x, y) = (a.element.capturedAt ?? .distantPast, b.element.capturedAt ?? .distantPast) return x != y ? x > y : a.offset < b.offset",
            "let (x, y) = (a.element.lastModified ?? .distantPast, b.element.lastModified ?? .distantPast) return x != y ? x > y : a.offset < b.offset",
        ], file: "the server's routes")
        let filters = try Self.web("search/WorkingCorpora.tsx")
        NoteViewParityTests.expect(filters, holds: [
            "const items = [...(corpora.data?.items ?? [])].sort((a, b) => a.name.localeCompare(b.name, 'en-US'));",
            "const items = [...(scopes.data?.items ?? [])].sort((a, b) => a.name.localeCompare(b.name, 'en-US'));",
        ], file: "WorkingCorpora.tsx")
    }

    /// The checklist's rules, as the app's `ReviewedMarks` and `ChecklistAnchor` keep them and
    /// checklist.ts mirrors them, with the kit's quotation marks the history writer compares by.
    @Test func theChecklistsRulesAreTheMirrors() throws {
        NoteViewParityTests.expect(try Self.app("Search/ReviewedMarks.swift"), holds: [
            "mutating func mark(_ key: String) { keys.insert(key) lastBulkBatch.remove(key) }",
            "let fresh = Set(newKeys).subtracting(keys) guard !fresh.isEmpty else { return [] } keys.formUnion(fresh) lastBulkBatch = fresh",
            "let batch = lastBulkBatch keys.subtract(batch) lastBulkBatch = []",
            "if lastBulkBatch.contains(key), !otherwiseHidden.contains(key) { count += 1 }",
            "structuredTerms = [ran.phrase ?? \"\", ran.prefixWildcard ?? \"\"] + ran.excludedTerms guard ran.runsAsFilterOnly else {",
            "subjectBucket: ran.subjectBucketKey ?? ran.subjectBucket.map(String.init))",
            "guard SearchHistoryWriter.isSameQuery(query, next.query), structuredTerms == next.structuredTerms else { return false }",
            "if let subjectRef, subjectRef != next.subjectRef { return false } if let subjectBucket, subjectBucket != next.subjectBucket { return false }",
        ], file: "ReviewedMarks.swift")
        NoteViewParityTests.expect(try Self.app("App/MacSearchViewModel.swift"), holds: [
            "checklistMode ? readSinceEnabledKeys.union(markedReviewedKeys) : []",
            "}).subtracting(readSinceEnabledKeys).count",
        ], file: "MacSearchViewModel.swift")
        NoteViewParityTests.expect(try Self.kit("FTS5Store/FTS5InlineQueryParser.swift"), holds: [
            #"private static let typographicDoubleQuotationMarks: Set<Character> = [ "\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}", "\u{FF02}", "\u{00AB}", "\u{00BB}", ]"#,
        ], file: "FTS5InlineQueryParser.swift")
        NoteViewParityTests.expect(try Self.web("search/checklist.ts"), holds: [
            "const keys = new Set(marks.keys).add(key); const lastBulkBatch = new Set(marks.lastBulkBatch); lastBulkBatch.delete(key);",
            "const fresh = new Set([...newKeys].filter((key) => !marks.keys.has(key))); if (fresh.size === 0) return { marks, fresh };",
            "if (marks.lastBulkBatch.has(key) && !otherwiseHidden.has(key)) count += 1;",
            "const structuredTerms = [state.phrase ?? '', state.prefixWildcard ?? '', ...(state.excludedTerms ?? [])];",
            "browse: { personRollupId: state.personRollupId, subjectBucket: state.subjectBucketKey ?? state.subjectBucket },",
            "if (normalizingQuotationMarks(anchor.query) !== normalizingQuotationMarks(next.query)) return false;",
            "if (mine.subjectBucket !== undefined && mine.subjectBucket !== next.subjectBucket) return false;",
            "return checklist.on ? new Set([...checklist.readSinceEnabled, ...checklist.marks.keys]) : new Set();",
            "const typographicDoubleQuotationMarks = new Set(['\\u201C', '\\u201D', '\\u201E', '\\u201F', '\\uFF02', '\\u00AB', '\\u00BB']);",
        ], file: "checklist.ts")
    }

    /// What a capture says of the rows it saved, as `ResultSetScope` says it for a keyword search and
    /// the server's `CorpusCapture` mirrors it: the sentence the corpus records, the sheet's two
    /// warnings, what narrowed the search, and when the capture is partial.
    @Test func theCapturesAccountIsTheMirror() throws {
        NoteViewParityTests.expect(try Self.app("Search/ResultSetScope.swift"), holds: [
            #"description = String(localized: "corpus.save.source.search", defaultValue: "Search results")"#,
            #"description = String(format: String(localized: "corpus.save.source.narrowed %@ %@", defaultValue: "%1$@ (%2$@)"), description, narrowing.joined(separator: "; "))"#,
            #"defaultValue: " — the highest-scoring %1$@ of %2$@ matches"), grouped(loaded), grouped(total))"#,
            #"one: String(localized: "corpus.save.source.checklist.one", defaultValue: "; %@ reviewed document excluded"), many: String(localized: "corpus.save.source.checklist %@", defaultValue: "; %@ reviewed documents excluded"))"#,
            #"defaultValue: "These %1$@ documents are the highest-scoring of %2$@ matching documents. Counts taken inside this corpus are counts inside that subset."), grouped(loaded), grouped(total))"#,
            #"one: String(localized: "corpus.save.checklistHiding.one", defaultValue: "Checklist mode is hiding %@ reviewed document. It will not be in this corpus."), many: String(localized: "corpus.save.checklistHiding %@", defaultValue: "Checklist mode is hiding %@ reviewed documents. They will not be in this corpus."))"#,
            "if loaded >= fetchLimit { return true } if let totalMatchCount { return totalMatchCount > loaded }",
            "if didHitFetchLimit { return true } if case .truncated = appliedCorpusTruncation { return true }",
            "var hiddenByChecklist: Int { max(0, loaded - shown) }",
            #"if ["text", "summ", "notes", "front"].allSatisfy({ parts[$0] == "1" }) { phrases.removeFirst() }"#,
            #"one: String(localized: "corpus.save.narrowing.volumes.one", defaultValue: "within %@ volume"), many: String(localized: "corpus.save.narrowing.volumes %@", defaultValue: "within %@ volumes")))"#,
            #"one: String(localized: "corpus.save.narrowing.documents.one", defaultValue: "within a set of %@ document"), many: String(localized: "corpus.save.narrowing.documents %@", defaultValue: "within a set of %@ documents")))"#,
        ], file: "ResultSetScope.swift")
        NoteViewParityTests.expect(try Self.app("Search/SaveWorkingCorpusSheet.swift"), holds: [
            #"Array(Set(results.map { "\($0.volumeId)/\($0.documentId)" })).sorted()"#,
            "sourceQuery: queryText.isEmpty ? nil : queryText,",
            "sourceDescription: scope.captureProvenanceDescription,",
            "indexedVolumeCountAtCapture: indexedVolumeCount,",
            "wasTruncatedAtCapture: scope.isCapturePartial, totalMatchCountAtCapture: scope.totalMatchCount)",
        ], file: "SaveWorkingCorpusSheet.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/WorkingCorpora.swift"), holds: [
            #"keys = Array(Set(shown.map { "\($0.volumeId)/\($0.documentId)" })).sorted()"#,
            #"var description = "Search results""#,
            #"if !narrowing.isEmpty { description = "\(description) (\(narrowing.joined(separator: "; ")))" }"#,
            #"if didHitFetchLimit { description += " — the highest-scoring \(Self.grouped(loaded)) of \(Self.grouped(total)) matches" }"#,
            #"? "; 1 reviewed document excluded" : "; \(Self.grouped(hiddenByChecklist)) reviewed documents excluded""#,
            #"return "These \(Self.grouped(loaded)) documents are the highest-scoring of \(Self.grouped(total)) matching documents. Counts taken inside this corpus are counts inside that subset.""#,
            #"? "Checklist mode is hiding 1 reviewed document. It will not be in this corpus." : "Checklist mode is hiding \(Self.grouped(hiddenByChecklist)) reviewed documents. They will not be in this corpus.""#,
            "var didHitFetchLimit: Bool { loaded >= Self.fetchLimit || total > loaded }",
            "var isCapturePartial: Bool { didHitFetchLimit || insideTruncatedCorpus }",
            #"if ["text", "summ", "notes", "front"].allSatisfy({ parts[$0] == "1" }) { phrases.removeFirst() }"#,
            #"phrases.append(volumes == 1 ? "within 1 volume" : "within \(grouped(volumes)) volumes")"#,
            #"phrases.append(documents == 1 ? "within a set of 1 document" : "within a set of \(grouped(documents)) documents")"#,
        ], file: "WorkingCorpora.swift")
        // The ceiling the app fetched under, which the server keeps of a search.
        NoteViewParityTests.expect(try Self.app("App/MacSearchViewModel.swift"), holds: [
            "static let searchHardLimit: Int = 7_500",
        ], file: "MacSearchViewModel.swift")
    }

    /// A recall, as the Mac's window runs one and stamps it: the saved parameters inside the window's
    /// corpus and under no gate of their own, and the stamp counted from the saved search's own search;
    /// and the Save Search sheet's name, its words trimmed of spaces and never empty.
    @Test func aRecallIsTheMacs() throws {
        NoteViewParityTests.expect(try Self.app("App/MacSearchViewModel.swift"), holds: [
            "parameters = params.runningInside(workingCorpus: filterVM?.appliedWorkingCorpusKeys)",
        ], file: "MacSearchViewModel.swift")
        NoteViewParityTests.expect(try Self.app("Search/SavedSearchFreshnessEvaluator.swift"), holds: [
            "count = try? await service.searchCount(parameters: saved.searchParameters)",
            "saved.recordRun(matchCount: count, indexedVolumeCount: indexedVolumeCount)",
            "let current = try? await service.searchCount(parameters: saved.searchParameters)",
        ], file: "SavedSearchFreshnessEvaluator.swift")
        NoteViewParityTests.expect(try Self.app("Search/SaveSearchSheet.swift"), holds: [
            "var offeredName: String { words.trimmingCharacters(in: .whitespaces) }",
            "let trimmed = text.trimmingCharacters(in: .whitespaces) return trimmed.isEmpty ? nil : trimmed",
        ], file: "SaveSearchSheet.swift")
        NoteViewParityTests.expect(try Self.web("search/searchState.ts"), holds: [
            "...validateSearch(search), workingCorpusId: current.workingCorpusId,",
        ], file: "searchState.ts")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/SavedSearches.swift"), holds: [
            "self.search = SearchRequest.formFields(search.parameters.runningInside(workingCorpus: nil))",
            "let trimmed = name.trimmingCharacters(in: .whitespaces)",
        ], file: "SavedSearches.swift")
    }
}
