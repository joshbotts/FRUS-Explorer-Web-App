// The app's words and the few lines of its view code that the browser app's notes and summaries
// take (PLAN's S15d, and PLAN's rule for view code: "mirrored with a parity test that reads the
// app's source at the pin"), read from the app's source and from web/src at once: the words of the
// selection bar's Note, the rail's Notes and Summary, the note editor, its formatting bar and link
// popover, All Notes and the Markdown export, each in the copy.ts block the browser app reads it
// from, and its format strings as functions; All Notes' rows, filters and count, which
// web/src/research/notesRules.ts mirrors until S17b moves them into the kit; the rail's note rows,
// its summary preview and history control, and its sections' open states; and the editor's rules
// for a summary inserted, a tag made, the formatting bar's toggles and its link. A pin move that
// changes one fails here until the web follows it. The server's mirrors of the app's model code are
// NotesAndSummariesParityTests'.

@testable import FRUSCoreKit
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct NoteViewParityTests {
    static let app = RepositoryFiles.root.appendingPathComponent("upstream/FRUS-Explorer/FRUSExplorer")
    static let web = RepositoryFiles.root.appendingPathComponent("web/src")

    static func read(_ base: URL, _ path: String) throws -> String {
        try String(contentsOf: base.appendingPathComponent(path), encoding: .utf8)
    }

    /// Text with each run of white space read as one space, and none just inside a parenthesis, for
    /// source split across lines.
    static func flattened(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: "( ", with: "(")
            .replacingOccurrences(of: " )", with: ")")
    }

    /// copy.ts's block `name`, flattened: where each word is the web's under the key the UI reads.
    static func block(_ name: String, of copy: String) throws -> String {
        let start = try #require(copy.range(of: "\n  \(name): {"), "copy.ts has a \(name) block")
        let end = try #require(copy.range(of: "\n  },", range: start.upperBound..<copy.endIndex))
        return flattened(String(copy[start.lowerBound..<end.upperBound]))
    }

    /// Whether the app's source writes `key` with `value` as its default.
    static func writes(_ source: String, _ key: String, _ value: String) -> Bool {
        source.contains("String(localized: \"\(key)\", defaultValue: \"\(value)\")")
    }

    /// The flattened sources, read once each.
    final class Sources {
        private var read: [String: String] = [:]

        func app(_ path: String) throws -> String { try source(NoteViewParityTests.app, path) }
        func web(_ path: String) throws -> String { try source(NoteViewParityTests.web, path) }

        private func source(_ base: URL, _ path: String) throws -> String {
            let key = "\(base.path)/\(path)"
            if let source = read[key] { return source }
            let source = NoteViewParityTests.flattened(try NoteViewParityTests.read(base, path))
            read[key] = source
            return source
        }
    }

    /// Expects `source` to hold each of `lines`, each flattened.
    static func expect(_ source: String, holds lines: [String], file: String) {
        for line in lines {
            #expect(source.contains(flattened(line)), "\(file) holds \(line)")
        }
    }

    /// The app's words the browser app takes, each where the app's source writes it, under its key,
    /// and in copy.ts's block under the key the UI reads.
    @Test func theAppsWordsAreTheWebs() throws {
        let copy = try Self.read(Self.web, "copy.ts")
        let words: [(file: String, key: String, value: String, block: String, web: String)] = [
            ("DocumentView/FloatingSelectionBar.swift", "selectionBar.note", "Note", "notes", "note"),
            ("DocumentView/ResearchRailView.swift", "panel.notes.title", "Notes", "notes", "title"),
            ("DocumentView/ResearchRailView.swift", "panel.notes.emptyNote", "Empty note", "notes", "emptyNote"),
            ("DocumentView/ResearchRailView.swift", "panel.notes.addToHighlight", "Add Note to Highlight", "notes", "addToHighlight"),
            ("DocumentView/ResearchRailView.swift", "panel.notes.add", "Add Note", "notes", "add"),
            ("App/MainTabView.swift", "tab.research", "Research", "app", "research"),
            ("DocumentView/ResearchRailView.swift", "panel.summary.title", "Summary", "summary", "title"),
            ("App/SupportingViews.swift", "summary.block.label", "AI summary", "summary", "label"),
            // The app's source spells the middle dot as an escape, and copy.ts spells it the same way.
            ("Collections/CollectionEntryInspector.swift", "collection.inspector.headnote.chip.aiEdited", #"AI \u{00B7} edited"#, "summary", "aiEdited"),
            ("Collections/CollectionEntryInspector.swift", "collection.inspector.headnote.chip.user", "Yours", "summary", "userWritten"),
            ("App/SupportingViews.swift", "summary.history.older.help", "Show older summary", "summary", "olderHelp"),
            ("App/SupportingViews.swift", "summary.history.older.a11y", "Older summary", "summary", "older"),
            ("App/SupportingViews.swift", "summary.history.newer.help", "Show newer summary", "summary", "newerHelp"),
            ("App/SupportingViews.swift", "summary.history.newer.a11y", "Newer summary", "summary", "newer"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.title.new", "New Research Note", "noteEditor", "titleNew"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.title.edit", "Edit Note", "noteEditor", "titleEdit"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.toolbar.delete", "Delete", "noteEditor", "delete"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.toolbar.discard", "Discard", "noteEditor", "discard"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.toolbar.save", "Save", "noteEditor", "save"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.body.header", "Note", "noteEditor", "body"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.body.a11y", "Research note body", "noteEditor", "bodyLabel"),
            // The switch's visible word; its hidden "Formatted text" (note.editor.body.rich.a11y) would not match what it shows.
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.body.rich", "Formatting", "noteEditor", "formatting"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.userTags.header", "Tags", "noteEditor", "tags"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.userTags.empty", "No tags yet — add one below.", "noteEditor", "tagsEmpty"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.newTag.placeholder", "New tag name", "noteEditor", "newTag"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.newTag.add", "Add", "noteEditor", "addTag"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.projects.header", "Projects", "noteEditor", "projects"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.projects.empty", "No projects yet.", "noteEditor", "projectsEmpty"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.summaries.header", "Generated Summaries", "noteEditor", "summaries"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.summary.insert", "Insert into note", "noteEditor", "insert"),
            ("ResearchNoteEditor/ResearchNoteEditorView.swift", "note.editor.summary.remove", "Remove from note", "noteEditor", "remove"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.bold.help", "Bold", "richText", "bold"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.italic.help", "Italic", "richText", "italic"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.underline.help", "Underline", "richText", "underline"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.color.help", "Text Color", "richText", "color"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.link.help", "Link selected text to a URL", "richText", "link"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.link.title", "Link selection to URL", "richText", "linkTitle"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.link.placeholder", "https://…", "richText", "linkPlaceholder"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.link.remove", "Remove Link", "richText", "linkRemove"),
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.link.apply", "Apply", "richText", "linkApply"),
            // The iPhone's link alert's.
            ("Collections/CollectionRichTextEditor.swift", "collection.richtext.link.cancel", "Cancel", "richText", "linkCancel"),
            ("Research/AllNotesScreen.swift", "settings.notes.all.title", "All Notes", "allNotes", "title"),
            ("Research/AllNotesScreen.swift", "settings.notes.filter.project", "Project", "allNotes", "project"),
            ("Research/AllNotesScreen.swift", "settings.notes.filter.project.all", "All projects", "allNotes", "allProjects"),
            ("Research/AllNotesScreen.swift", "settings.notes.filter.project.unfiled", "Not in a project", "allNotes", "unfiled"),
            ("Research/AllNotesScreen.swift", "settings.notes.filter.tag", "Tag", "allNotes", "tag"),
            ("Research/AllNotesScreen.swift", "settings.notes.filter.tag.all", "All tags", "allNotes", "allTags"),
            ("Research/AllNotesScreen.swift", "settings.notes.filter.search", "Search notes…", "allNotes", "search"),
            ("Models/NotesPaneSnapshot.swift", "settings.notes.emptyNote", "Empty note", "allNotes", "emptyNote"),
            ("Research/AllNotesScreen.swift", "settings.notes.none.title", "No Notes", "allNotes", "noneTitle"),
            ("Research/AllNotesScreen.swift", "settings.notes.empty", "No notes yet. Notes you write from a document appear here.", "allNotes", "empty"),
            ("Research/AllNotesScreen.swift", "settings.notes.none.filtered", "No notes match the selected filters.", "allNotes", "noneFiltered"),
            ("Research/AllNotesScreen.swift", "settings.notes.delete.title", "Delete Note?", "allNotes", "deleteTitle"),
            ("Research/AllNotesScreen.swift", "settings.notes.delete.message", "This note will be permanently deleted.", "allNotes", "deleteMessage"),
            ("Research/AllNotesScreen.swift", "settings.notes.delete.confirm", "Delete", "allNotes", "deleteConfirm"),
            ("Research/AllNotesScreen.swift", "settings.notes.delete.cancel", "Cancel", "allNotes", "deleteCancel"),
            ("Export/ResearchDataExportView.swift", "settings.export.preparing", "Preparing export…", "dataSettings", "preparing"),
            ("Export/ResearchDataExportView.swift", "settings.export.markdown.empty", "No research notes to export.", "dataSettings", "empty"),
            ("Export/ResearchDataExportView.swift", "settings.export.markdown.footer",
             "One Markdown file per research note, with a citation and link back to the source document. Compatible with Obsidian and similar note-taking tools.",
             "dataSettings", "footer"),
        ]
        let sources = Sources()
        for word in words {
            #expect(Self.writes(try sources.app(word.file), word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(try Self.block(word.block, of: copy).contains("\(word.web): '\(word.value)'"), "copy.\(word.block).\(word.web) is \(word.value)")
        }
    }

    /// The app's format strings, each a function in copy.ts that writes what the format writes: a
    /// `%lld` ungrouped, as `String(format:)` prints it, and a count's `%@` grouped where the app's
    /// `CountCopy` groups it, in web/src/research/notesRules.ts; and `CountCopy`'s rule itself, the
    /// one form at exactly one and the number grouped, which the kit's code is run for.
    @Test func theAppsFormatsAreTheWebs() throws {
        let copy = try Self.read(Self.web, "copy.ts")
        let formats: [(file: String, key: String, value: String, block: String, web: String)] = [
            ("App/SupportingViews.swift", "summary.block.prompt %@", "· %@", "summary", "prompt: (name: string) => `· ${name}`,"),
            ("App/SupportingViews.swift", "summary.history.position %lld %lld", "%lld/%lld", "summary",
             "position: (index: number, count: number) => `${index}/${count}`,"),
            ("App/SupportingViews.swift", "summary.history.position.a11y %lld %lld", "Summary %lld of %lld", "summary",
             "positionLabel: (index: number, count: number) => `Summary ${index} of ${count}`,"),
            ("Models/NotesPaneSnapshot.swift", "settings.notes.showing %lld %@", "Showing %lld of %@", "allNotes",
             "showing: (shown: number, total: string) => `Showing ${shown} of ${total}`,"),
            ("Models/ResearchItemCounts.swift", "settings.list.count.note.one", "%@ note", "allNotes", "noteOne: (count: string) => `${count} note`,"),
            ("Models/ResearchItemCounts.swift", "settings.list.count.note.many", "%@ notes", "allNotes", "noteMany: (count: string) => `${count} notes`,"),
            // The app interpolates the count, which a localized string groups.
            ("Export/ResearchDataExportView.swift", "settings.export.markdown.action", #"Export Notes as Markdown (\(markdownExportURLs.count))"#, "dataSettings",
             "exportMarkdown: (count: number) => `Export Notes as Markdown (${count.toLocaleString('en-US')})`,"),
        ]
        let sources = Sources()
        for format in formats {
            #expect(Self.writes(try sources.app(format.file), format.key, format.value), "\(format.file) writes \(format.key) as \(format.value)")
            #expect(try Self.block(format.block, of: copy).contains(Self.flattened(format.web)), "copy.\(format.block) holds \(format.web)")
        }
        #expect(try sources.app("Models/ResearchItemCounts.swift").contains("CountCopy.phrase(count,"))
        // The values web/src/research/notesRules.test.ts expects of noteCount.
        let english = Locale(identifier: "en_US")
        #expect([1, 0, 1_204].map { CountCopy.phrase($0, one: "%@ note", many: "%@ notes", locale: english) }
                == ["1 note", "0 notes", "1,204 notes"])
        Self.expect(try sources.web("research/notesRules.ts"), holds: [
            "const grouped = count.toLocaleString('en-US');",
            "return count === 1 ? copy.allNotes.noteOne(grouped) : copy.allNotes.noteMany(grouped);",
        ], file: "notesRules.ts")
    }

    /// All Notes' rows, as `NotesPaneSnapshot` builds them, and its filters and count, as it and
    /// `AllNotesScreen` apply them, in web/src/research/notesRules.ts: the first line with anything
    /// in it by Foundation's newlines, trimmed of its whitespaces, cut at 90 characters; where the
    /// note is, then its projects' names and its tags' in its order, the gone ones left out; the day
    /// it changed; Not in a project as no project at all; the search's text trimmed of its whitespaces
    /// only, in the note, its volume's id or its document's; and the count of every note.
    @Test func allNotesRowsAndFiltersAreTheApps() throws {
        let sources = Sources()
        Self.expect(try sources.app("Models/NotesPaneSnapshot.swift"), holds: [
            "static let titleLimit = 90",
            #".components(separatedBy: .newlines) .lazy .map { $0.trimmingCharacters(in: .whitespaces) } .first { !$0.isEmpty } ?? """#,
            "guard firstLine.count > Self.titleLimit else { return firstLine }",
            #"return firstLine.prefix(Self.titleLimit).trimmingCharacters(in: .whitespaces) + "…""#,
            #"var parts = ["\(volumeId) / \(documentId)"] parts.append(contentsOf: projectNames) parts.append(contentsOf: tagNames) return parts.joined(separator: " · ")"#,
            "projectNames: note.projectIds.compactMap { projectNamesById[$0] }, tagNames: note.userTagIds.compactMap { tagNamesById[$0] },",
            "case .any: matchesProject = true case .unfiled: matchesProject = row.projectIds.isEmpty case .id(let projectId): matchesProject = row.projectIds.contains(projectId)",
            "let matchesTag = tagId.map { row.userTagIds.contains($0) } ?? true",
            #"FetchDescriptor<ResearchNote>(sortBy: [SortDescriptor(\.lastModified, order: .reverse)])"#,
            "guard shown < total else { return noteCount(total) }",
        ], file: "NotesPaneSnapshot.swift")
        Self.expect(try sources.app("Research/AllNotesScreen.swift"), holds: [
            "let trimmed = query.trimmingCharacters(in: .whitespaces)",
            "$0.bodyText.localizedCaseInsensitiveContains(trimmed) || $0.volumeId.localizedCaseInsensitiveContains(trimmed) || $0.documentId.localizedCaseInsensitiveContains(trimmed)",
            "$0.formatted(date: .abbreviated, time: .omitted)",
            "NotesPaneSnapshot.showingCount(shown: filtered.count, of: current.total)",
        ], file: "AllNotesScreen.swift")
        Self.expect(try sources.web("research/notesRules.ts"), holds: [
            "export const titleLimit = 90;",
            #"const newlines = /\r\n|[\n\v\f\r\u{0085}\u{2028}\u{2029}]/u;"#,
            #"const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;"#,
            ".split(newlines) .map((line) => line.replace(whitespaces, '')) .find((line) => line !== '') ?? '';",
            "if (characters.length <= titleLimit) return firstLine;",
            "return characters.slice(0, titleLimit).join('').replace(whitespaces, '') + '…';",
            "return [`${note.volumeId} / ${note.documentId}`, ...named(note.projectIds, projectNames), ...named(note.userTagIds, tagNames)].join(' · ');",
            "(project === 'UNFILED' ? note.projectIds.length === 0 : note.projectIds.some((id) => id.toUpperCase() === project));",
            "const tagged = tag === undefined || note.userTagIds.some((id) => id.toUpperCase() === tag);",
            // `localizedCaseInsensitiveContains` is a search without `.literal`, which takes a composed
            // character and its decomposed sequence alike.
            "const fold = (text: string) => text.normalize('NFC').toLocaleLowerCase('en-US');",
            "const query = fold((filter.query ?? '').replace(whitespaces, ''));",
            "const holds = (text: string) => fold(text).includes(query);",
            "const found = query === '' || holds(note.bodyText) || holds(note.volumeId) || holds(note.documentId);",
            "new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })",
            "return shown < total ? copy.allNotes.showing(shown, noteCount(total)) : noteCount(total);",
        ], file: "notesRules.ts")
        #expect(try sources.web("research/AllNotesScreen.tsx").contains("{countLine(shown.length, all.length)}"))
    }

    /// The rail's Summary and Notes, as `ResearchRailView` and the Mac's `SummaryBlockView` draw them:
    /// both open until closed; a closed Summary previews its summary, trimmed, at 80 characters; at
    /// most the 20 newest, drafts left out, the newest first, the history control only for more than
    /// one, older first and disabled at the oldest; a note's text untrimmed, or Empty note, with the
    /// time since it changed, now when it has none; Add Note to Highlight while a highlight is
    /// pending, which choosing it, or another document, ends; and the order of the sections, Summary,
    /// Notes then Tags, and of the Notes section's actions, Add Note to Highlight above Add Note.
    @Test func theRailsSummaryAndNotesAreTheApps() throws {
        let sources = Sources()
        // The web's own order is NotesSection.test.tsx's and ReaderScreen.test.tsx's to check.
        let rail = try sources.app("DocumentView/ResearchRailView.swift")
        #expect(rail.contains("summaryAccordion Divider() notesAccordion Divider() tagsAccordion"),
                "ResearchRailView.swift orders its sections Summary, Notes, Tags")
        let pending = try #require(rail.range(of: "if let link = pendingHighlightLink {"))
        let add = try #require(rail.range(of: #"String(localized: "panel.notes.add", defaultValue: "Add Note")"#))
        #expect(pending.lowerBound < add.lowerBound, "ResearchRailView.swift offers Add Note to Highlight above Add Note")
        Self.expect(try sources.app("DocumentView/ResearchRailView.swift"), holds: [
            #"@AppStorage("frus.document.researchPanel.summary") private var summaryExpanded = true"#,
            #"@AppStorage("frus.document.researchPanel.notes") private var notesExpanded = true"#,
            "String($0.responseText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))",
            #"Text(preview + "…")"#,
            #"Text(note.bodyText.isEmpty ? String(localized: "panel.notes.emptyNote", defaultValue: "Empty note") : note.bodyText)"#,
            "Text(note.lastModified ?? .now, style: .relative)",
            #"sort: \.lastModified, order: .reverse)"#,
            "if let link = pendingHighlightLink {",
        ], file: "ResearchRailView.swift")
        Self.expect(try sources.app("DocumentView/DocumentViewModel.swift"), holds: [
            "s.documentId == docId && s.volumeId == volId && !s.isHeadnoteDraft",
            "descriptor.fetchLimit = 20",
        ], file: "DocumentViewModel.swift")
        Self.expect(try sources.app("App/SupportingViews.swift"), holds: [
            "if vm.activeSummaryIndex < vm.summaries.count - 1 { vm.activeSummaryIndex += 1 }",
            ".disabled(vm.activeSummaryIndex >= vm.summaries.count - 1)",
            ".disabled(vm.activeSummaryIndex <= 0)",
            "if vm.summaries.count > 1 { summaryHistoryNav }",
            "Int64(vm.activeSummaryIndex + 1), Int64(vm.summaries.count)",
            "pendingHighlightLink = nil",
        ], file: "SupportingViews.swift")
        Self.expect(try sources.app("App/MacDocumentView.swift"), holds: [
            "highlightCoordinator.pendingHighlightLink = highlight.id",
            "openNoteComposer(linkedHighlightId: highlightId) highlightCoordinator.pendingHighlightLink = nil",
        ], file: "MacDocumentView.swift")
        Self.expect(try sources.web("settings/preferences.ts"), holds: [
            "usePreference<'open' | 'closed'>('frus.research.summary', ['open', 'closed'], 'open')",
            "usePreference<'open' | 'closed'>('frus.research.notes', ['open', 'closed'], 'open')",
        ], file: "preferences.ts")
        Self.expect(try sources.web("research/notesRules.ts"), holds: [
            #"const whitespacesAndNewlines = /^[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+|[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+$/gu;"#,
            "return graphemes(responseText.replace(whitespacesAndNewlines, '')).slice(0, 80).join('') + '…';",
            "return bodyText === '' ? copy.notes.emptyNote : bodyText;",
            "const then = lastModified ? new Date(lastModified).getTime() : now;",
        ], file: "notesRules.ts")
        Self.expect(try sources.web("research/SummarySection.tsx"), holds: [
            "export const shownSummaries = 20;",
            "{summaries.length > 1 && (",
            "aria-disabled={position >= summaries.length - 1}",
            "onClick={() => position < summaries.length - 1 && onIndex(position + 1)}",
            "aria-disabled={position <= 0}",
            "copy.summary.position(position + 1, summaries.length)",
        ], file: "SummarySection.tsx")
        Self.expect(try sources.web("research/NotesSection.tsx"), holds: [
            "{pendingHighlightId && (",
            "setComposing({ linkedHighlightId: pendingHighlightId }); onPendingUsed?.();",
        ], file: "NotesSection.tsx")
        Self.expect(try sources.web("reader/ReaderScreen.tsx"), holds: [
            "setPendingHighlight(null);",
            "onHighlightMade: (made) => setPendingHighlight({ documentKey: `${made.volumeId}/${made.documentId}`, id: made.id }),",
            "pendingHighlightId={pendingHighlight?.documentKey === documentKey ? pendingHighlight.id : null}",
        ], file: "ReaderScreen.tsx")
    }

    /// The editor's rules, as the app's view model and formatting bar have them: the Formatting
    /// switch on until it is turned off, under the app's key; a summary inserted once, after a blank
    /// line unless the note is empty, and Remove from note unticking it alone; a tag made from its
    /// trimmed name at once; Bold, Italic and Underline by the selection's start; Link offered over a
    /// selection, its field the link at the start, trimmed, an empty one removing it; and the bar's
    /// Note a new note on the document, the selection let go.
    @Test func theEditorsRulesAreTheApps() throws {
        let sources = Sources()
        #expect(try sources.app("Settings/SettingsView.swift").contains(#"static let noteEditorRichText = "frus.notes.editor.richText""#))
        #expect(try sources.app("ResearchNoteEditor/ResearchNoteEditorView.swift").contains("@AppStorage(SettingsKeys.noteEditorRichText) private var richTextEnabled = true"))
        #expect(try sources.web("settings/preferences.ts").contains("usePreference<'true' | 'false'>('frus.notes.editor.richText', ['true', 'false'], 'true')"))
        Self.expect(try sources.app("ResearchNoteEditor/ResearchNoteEditorViewModel.swift"), holds: [
            "guard !selectedSummaryIds.contains(summary.id) else { return }",
            #"replaceBody(with: bodyText.isEmpty ? summary.responseText : bodyText + "\n\n" + summary.responseText)"#,
            "selectedSummaryIds.removeAll { $0 == summaryId }",
            "let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines) guard !trimmed.isEmpty else { return } let tag = UserTag(name: trimmed) context.insert(tag)",
        ], file: "ResearchNoteEditorViewModel.swift")
        Self.expect(try sources.web("research/NoteEditor.tsx"), holds: [
            "if (!draft || draft.selectedSummaryIds.some((id) => upper(id) === upper(summary.id))) return;",
            #"setBody({ text: text === '' ? summary.responseText : `${text}\n\n${summary.responseText}`, runs: null, edited: true });"#,
            "selectedSummaryIds: draft.selectedSummaryIds.filter((id) => upper(id) !== upper(summary.id))",
            "const name = newTag.trim(); if (!name || making) return;",
            "const tag = await createTag(client, name);",
        ], file: "NoteEditor.tsx")
        Self.expect(try sources.app("Collections/CollectionRichTextEditor.swift"), holds: [
            "attrs = storage.attributes(at: range.location, effectiveRange: nil)",
            "let currentlyOn = (trait == .boldFontMask) ? isBold : isItalic",
            "let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines) if trimmed.isEmpty { storage.removeAttribute(.link, range: range) }",
            ".disabled(!controller.hasSelection)",
            "linkURLText = controller.selectionLink",
            "if !controller.selectionLink.isEmpty {",
            #"formatButton("link", active: !controller.selectionLink.isEmpty,"#,
        ], file: "CollectionRichTextEditor.swift")
        Self.expect(try sources.web("editor/noteExtensions.ts"), holds: [
            "if (selection.empty) return state.storedMarks ?? selection.$from.marks();",
            "return activeAtStart(editor.state, name) ? chain.unsetMark(name).run() : chain.setMark(name).run();",
        ], file: "noteExtensions.ts")
        Self.expect(try sources.web("editor/FormattingToolbar.tsx"), holds: [
            "aria-pressed={state.link !== null}",
            "aria-disabled={!state.hasSelection}",
        ], file: "FormattingToolbar.tsx")
        Self.expect(try sources.web("editor/LinkDialog.tsx"), holds: [
            "const [existing] = useState(() => linkAtStart(editor));",
            "const trimmed = url.trim(); if (trimmed === '') { remove(); return; }",
            "{existing !== null && (",
        ], file: "LinkDialog.tsx")
        #expect(try sources.app("App/MacDocumentView.swift").contains("onNote: { openNoteComposer() selectionBar.hideNow() }"))
        Self.expect(try sources.web("reader/useReaderHighlights.tsx"), holds: [
            "forget(); post({ kind: 'collapseSelection' }); onNote?.();",
            "target.closest('dialog[open]') !== null",
        ], file: "useReaderHighlights.tsx")
    }
}
