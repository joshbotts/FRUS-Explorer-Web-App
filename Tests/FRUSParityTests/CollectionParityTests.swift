// The app's words and the lines of its code the web takes for collections and their editor (PLAN's
// S18d, and PLAN's rule for view code: "mirrored with a parity test that reads the app's source at the
// pin"), read from the app's source, the kit's and the web's at once: the Collections tab, the New
// Collection sheet, the Add to Collection picker, the Research rail's Collections section and the
// selection bar's Excerpt; the editor's Contents, Add menu, Sort by Date, rows and chips; Collection
// settings with the presets and the composition; the entry inspector; Add Documents and Add
// Highlighted Passages; and the rules mirrored, the server's over the export's values
// (CollectionEditing.swift, Collections.swift, CollectionEntries.swift) and the browser app's over the
// server's answers (web/src/collections/collectionRules.ts). A pin move that changes one fails here
// until the web follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct CollectionParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func kit(_ path: String) throws -> String { try SearchSetParityTests.kit(path) }
    static func web(_ path: String) throws -> String { try SearchSetParityTests.web(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    /// Each word the web takes, where the app's or the kit's source writes it under its key, and in
    /// copy.ts's block where the screen reads it.
    @Test func theAppsWordsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let blocks = try Dictionary(uniqueKeysWithValues: ["app", "collections", "collectionEditor", "collectionSettings", "collectionInspector",
                                                           "addHighlights", "addDocuments"].map {
            ($0, try NoteViewParityTests.block($0, of: raw))
        })
        let tabs = try Self.app("App/MainTabView.swift")
        let list = try Self.app("Collections/CollectionListView.swift")
        let model = try Self.app("Models/Collection.swift")
        let picker = try Self.app("Collections/CollectionPickerSheet.swift")
        let rail = try Self.app("DocumentView/ResearchRailView.swift")
        let bar = try Self.app("DocumentView/FloatingSelectionBar.swift")
        let editor = try Self.app("Collections/CollectionEditorView.swift")
        let data = try Self.app("Collections/CollectionEntryData.swift")
        let rows = try Self.app("Collections/CollectionEntryRows.swift")
        let composition = try Self.app("Collections/CollectionCompositionRows.swift")
        let inspector = try Self.app("Collections/CollectionEntryInspector.swift")
        let excerpts = try Self.app("Collections/CollectionExcerpts.swift")
        let addDocuments = try Self.app("Collections/CollectionAddDocumentsSheet.swift")
        let exporter = try Self.kit("FRUSCoreKit/Collections/CollectionExporter.swift")
        let blocksKit = try Self.kit("FRUSCoreKit/Collections/CollectionGeneratedBlockType.swift")
        let naming = try Self.kit("FRUSCoreKit/Collections/CollectionEditorNaming.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (tabs, "MainTabView", "tab.collections", "Collections", "app", "collections: 'Collections'"),
            (list, "CollectionListView", "collections.nav.title", "Collections", "collections", "title: 'Collections'"),
            (list, "CollectionListView", "collections.toolbar.new", "New Collection", "collections", "new: 'New Collection'"),
            (list, "CollectionListView", "collections.toolbar.new.accessibility", "Create new collection", "collections",
             "newLabel: 'Create new collection'"),
            (list, "CollectionListView", "collections.empty.title", "No Collections", "collections", "emptyTitle: 'No Collections'"),
            (list, "CollectionListView", "collections.empty.description", "Create a collection to group documents for export.", "collections",
             "emptyDetail: 'Create a collection to group documents for export.'"),
            (list, "CollectionListView", "collections.empty.action", "New Collection", "collections", "emptyAction: 'New Collection'"),
            (list, "CollectionListView", "collections.filterBanner.showAll", "Show All", "collections", "showAll: 'Show All'"),
            (list, "CollectionListView", "collections.filterBanner.untitledProject", "Untitled Project", "collections",
             "untitledProject: 'Untitled Project'"),
            (list, "CollectionListView", "collection.duplicate.action", "Duplicate", "collections", "duplicate: 'Duplicate'"),
            (model, "Collection", "collection.smart.listLabel", "Smart collection", "collections", "smartLabel: 'Smart collection'"),
            (model, "Collection", "collection.picker.smart", "Smart collection. Its documents come from its saved search.", "collections",
             "smartSentence: 'Smart collection. Its documents come from its saved search.'"),
            (picker, "CollectionPickerSheet", "collection.picker.nav.title", "Add to Collection", "collections", "pickerTitle: 'Add to Collection'"),
            (picker, "CollectionPickerSheet", "collection.picker.title.excerpt", "Add Excerpt to Collection", "collections",
             "pickerTitleExcerpt: 'Add Excerpt to Collection'"),
            (picker, "CollectionPickerSheet", "collection.picker.newCollection", "New Collection", "collections", "pickerNew: 'New Collection'"),
            (picker, "CollectionPickerSheet", "collection.picker.newCollection.help", "Create a new collection", "collections",
             "pickerNewHelp: 'Create a new collection'"),
            (picker, "CollectionPickerSheet", "collection.picker.search.placeholder", "Search collections…", "collections",
             "pickerSearch: 'Search collections…'"),
            (picker, "CollectionPickerSheet", "collection.picker.empty", "No Collections", "collections", "pickerEmpty: 'No Collections'"),
            (picker, "CollectionPickerSheet", "collection.picker.empty.hint", "Use the button above to create one.", "collections",
             "pickerEmptyHint: 'Use the button above to create one.'"),
            (picker, "CollectionPickerSheet", "collection.picker.cancel", "Cancel", "collections", "pickerCancel: 'Cancel'"),
            (picker, "CollectionPickerSheet", "collection.picker.added.a11y", "Added", "collections", "pickerAdded: 'Added'"),
            (picker, "CollectionPickerSheet", "collection.picker.addFailed.title", "Not Added", "collections", "addFailedTitle: 'Not Added'"),
            (rail, "ResearchRailView", "panel.collections.title", "Collections", "collections", "railTitle: 'Collections'"),
            (rail, "ResearchRailView", "panel.collections.empty", "Not in any collection yet.", "collections",
             "railEmpty: 'Not in any collection yet.'"),
            (rail, "ResearchRailView", "panel.collections.add", "Add to Collection", "collections", "railAdd: 'Add to Collection'"),
            (bar, "FloatingSelectionBar", "selectionBar.excerpt", "Excerpt", "collections", "excerpt: 'Excerpt'"),
            (naming, "CollectionEditorNaming", "collection.untitled.name", "Untitled Collection", "collectionEditor", "untitled: 'Untitled Collection'"),
            (editor, "CollectionEditorView", "collection.editor.docs.header", "Contents", "collectionEditor", "contents: 'Contents'"),
            (editor, "CollectionEditorView", "collection.editor.docs.empty",
             "No content yet. Add documents, headings, notes, and apparatus from the toolbar above.", "collectionEditor",
             "empty: 'No content yet. Add documents, headings, notes, and apparatus from the toolbar above.'"),
            (editor, "CollectionEditorView", "collection.add.menu.label", "Add", "collectionEditor", "add: 'Add'"),
            (editor, "CollectionEditorView", "collection.add.menu",
             "Add documents, a section heading, a note block, highlighted passages, or an apparatus block", "collectionEditor",
             "addLabel: 'Add documents, a section heading, a note block, highlighted passages, or an apparatus block'"),
            (editor, "CollectionEditorView", "collection.editor.addDocuments.button", "Add Documents…", "collectionEditor",
             "addDocuments: 'Add Documents…'"),
            (editor, "CollectionEditorView", "collection.add.heading", "Add Section Heading", "collectionEditor", "addHeading: 'Add Section Heading'"),
            (editor, "CollectionEditorView", "collection.add.prose", "Add Note Block", "collectionEditor", "addProse: 'Add Note Block'"),
            (editor, "CollectionEditorView", "collection.add.highlights", "Add Highlighted Passages…", "collectionEditor",
             "addHighlights: 'Add Highlighted Passages…'"),
            (editor, "CollectionEditorView", "collection.add.apparatus", "Apparatus", "collectionEditor", "apparatus: 'Apparatus'"),
            (editor, "CollectionEditorView", "collection.sort.date", "Sort by Date", "collectionEditor", "sortByDate: 'Sort by Date'"),
            (editor, "CollectionEditorView", "collection.editor.settings.title", "Collection settings", "collectionEditor",
             "settings: 'Collection settings'"),
            (data, "CollectionEntryData", "collection.sort.date.scope.whole", "Across the Whole Collection", "collectionEditor",
             "sortWhole: 'Across the Whole Collection'"),
            (data, "CollectionEntryData", "collection.sort.date.scope.whole.help",
             "Order every document into one chronology — a document may move past a section heading", "collectionEditor",
             "sortWholeHelp: 'Order every document into one chronology — a document may move past a section heading'"),
            (data, "CollectionEntryData", "collection.sort.date.scope.sections", "Within Each Section", "collectionEditor",
             "sortSections: 'Within Each Section'"),
            (data, "CollectionEntryData", "collection.sort.date.scope.sections.help",
             "Order documents chronologically within each section — documents stay under their heading", "collectionEditor",
             "sortSectionsHelp: 'Order documents chronologically within each section — documents stay under their heading'"),
            (rows, "CollectionEntryRows", "collection.section.expand", "Expand section", "collectionEditor", "expandSection: 'Expand section'"),
            (rows, "CollectionEntryRows", "collection.section.collapse", "Collapse section", "collectionEditor", "collapseSection: 'Collapse section'"),
            (rows, "CollectionEntryRows", "collection.heading.placeholder", "Section heading", "collectionEditor",
             "headingPlaceholder: 'Section heading'"),
            (rows, "CollectionEntryRows", "collection.section.configure", "Section defaults", "collectionEditor", "sectionDefaults: 'Section defaults'"),
            (rows, "CollectionEntryRows", "collection.section.inspect.help", "Set export defaults for every document in this section",
             "collectionEditor", "sectionDefaultsHelp: 'Set export defaults for every document in this section'"),
            (rows, "CollectionEntryRows", "collection.section.bodyDepth.default", "Default", "collectionEditor", "sectionBodyDefault: 'Default'"),
            (rows, "CollectionEntryRows", "collection.section.bodyDepth.label", "Section body", "collectionEditor", "sectionBody: 'Section body'"),
            (rows, "CollectionEntryRows", "collection.section.delete.confirm.title", "Delete Section?", "collectionEditor",
             "deleteSectionTitle: 'Delete Section?'"),
            (rows, "CollectionEntryRows", "collection.section.delete.confirm.action", "Delete Section", "collectionEditor",
             "deleteSectionAction: 'Delete Section'"),
            (rows, "CollectionEntryRows", "collection.section.rename", "Rename", "collectionEditor", "rename: 'Rename'"),
            (rows, "CollectionEntryRows", "collection.section.defaults", "Section Defaults…", "collectionEditor",
             "sectionDefaultsMenu: 'Section Defaults…'"),
            (rows, "CollectionEntryRows", "collection.section.indent", "Indent", "collectionEditor", "indent: 'Indent'"),
            (rows, "CollectionEntryRows", "collection.section.outdent", "Outdent", "collectionEditor", "outdent: 'Outdent'"),
            (rows, "CollectionEntryRows", "collection.section.deleteHeadingOnly", "Delete Heading Only", "collectionEditor",
             "deleteHeadingOnly: 'Delete Heading Only'"),
            (rows, "CollectionEntryRows", "collection.section.deleteSection", "Delete Section", "collectionEditor", "deleteSection: 'Delete Section'"),
            (rows, "CollectionEntryRows", "collection.entry.delete.a11y", "Remove entry", "collectionEditor", "remove: 'Remove entry'"),
            (rows, "CollectionEntryRows", "collection.entry.delete.help", "Remove this document from the collection", "collectionEditor",
             "removeHelp: 'Remove this document from the collection'"),
            (rows, "CollectionEntryRows", "collection.entry.configure", "Configure", "collectionEditor", "configure: 'Configure'"),
            (rows, "CollectionEntryRows", "collection.entry.configure.hint", "Opens this document’s settings", "collectionEditor",
             "configureHint: 'Opens this document’s settings'"),
            (rows, "CollectionEntryRows", "collection.entry.moveUp", "Move Up", "collectionEditor", "moveUp: 'Move Up'"),
            (rows, "CollectionEntryRows", "collection.entry.moveDown", "Move Down", "collectionEditor", "moveDown: 'Move Down'"),
            (rows, "CollectionEntryRows", "collection.entry.openDocument", "Open Document", "collectionEditor", "openDocument: 'Open Document'"),
            (rows, "CollectionEntryRows", "collection.entry.duplicate", "Also in collection", "collectionEditor", "duplicate: 'Also in collection'"),
            (rows, "CollectionEntryRows", "collection.entry.generated.unsupported", "Unsupported block", "collectionEditor",
             "generatedUnsupported: 'Unsupported block'"),
            (rows, "CollectionEntryRows", "collection.entry.generated.unsupported.detail", "Update FRUS Explorer to resolve this block.",
             "collectionEditor", "generatedUnsupportedDetail: 'Update FRUS Explorer to resolve this block.'"),
            (rows, "CollectionEntryRows", "collection.entry.generated.caption",
             "Generated from this collection’s documents at export and in the preview.", "collectionEditor",
             "generatedCaption: 'Generated from this collection’s documents at export and in the preview.'"),
            (rows, "CollectionEntryRows", "collection.entry.unrecognized.title", "Unsupported entry", "collectionEditor",
             "unrecognizedTitle: 'Unsupported entry'"),
            (rows, "CollectionEntryRows", "collection.entry.unrecognized.detail", "Update FRUS Explorer to view this entry.", "collectionEditor",
             "unrecognizedDetail: 'Update FRUS Explorer to view this entry.'"),
            (rows, "CollectionEntryRows", "collection.entry.chip.notesOff", "Notes off", "collectionEditor", "notesOff: 'Notes off'"),
            (rows, "CollectionEntryRows", "collection.entry.chip.notes.one", "1 note", "collectionEditor", "count === 1 ? '1 note'"),
            (rows, "CollectionEntryRows", "collection.entry.chip.highlightsOff", "Highlights off", "collectionEditor",
             "highlightsOff: 'Highlights off'"),
            (rows, "CollectionEntryRows", "collection.entry.chip.headnote", "Headnote", "collectionEditor", "headnote: 'Headnote'"),
            (rows, "CollectionEntryRows", "collection.entry.chip.seeAlso", "See also", "collectionEditor", "seeAlso: 'See also'"),
            (exporter, "CollectionExporter", "collection.entry.chip.bodyDepth.full", "Full", "collectionEditor", "full: 'Full'"),
            (exporter, "CollectionExporter", "collection.entry.chip.bodyDepth.summary", "Summary", "collectionEditor", "summaryOnly: 'Summary'"),
            (exporter, "CollectionExporter", "collection.entry.chip.bodyDepth.index", "Index", "collectionEditor", "index: 'Index'"),
            (blocksKit, "CollectionGeneratedBlockType", "collection.generated.bibliography", "Bibliography", "collectionEditor",
             "bibliography: 'Bibliography'"),
            (blocksKit, "CollectionGeneratedBlockType", "collection.generated.chronology", "Chronology", "collectionEditor",
             "chronology: 'Chronology'"),
            (blocksKit, "CollectionGeneratedBlockType", "collection.generated.archivalSources", "Sources & Archives", "collectionEditor",
             "archivalSources: 'Sources & Archives'"),
            (blocksKit, "CollectionGeneratedBlockType", "collection.generated.personsIndex", "Persons Index", "collectionEditor",
             "personsIndex: 'Persons Index'"),
            (blocksKit, "CollectionGeneratedBlockType", "collection.generated.thematicIndex", "Thematic Index", "collectionEditor",
             "thematicIndex: 'Thematic Index'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.addedToast.one", "Added 1 document", "collectionEditor",
             "addedOne: 'Added 1 document'"),
            (editor, "CollectionEditorView", "collection.editor.name.header", "Name", "collectionSettings", "nameHeader: 'Name'"),
            (editor, "CollectionEditorView", "collection.editor.name.placeholder", "Collection Name", "collectionSettings",
             "namePlaceholder: 'Collection Name'"),
            (editor, "CollectionEditorView", "collection.editor.name.accessibility", "Collection name", "collectionSettings",
             "nameLabel: 'Collection name'"),
            (editor, "CollectionEditorView", "collection.editor.note.header", "Note", "collectionSettings", "noteHeader: 'Note'"),
            (editor, "CollectionEditorView", "collection.editor.note.placeholder", "Optional note about this collection…", "collectionSettings",
             "notePlaceholder: 'Optional note about this collection…'"),
            (editor, "CollectionEditorView", "collection.editor.note.accessibility", "Collection note", "collectionSettings",
             "noteLabel: 'Collection note'"),
            (editor, "CollectionEditorView", "collection.editor.note.add", "Add a note", "collectionSettings", "addNote: 'Add a note'"),
            (editor, "CollectionEditorView", "collection.editor.note.add.accessibility", "Add a collection note", "collectionSettings",
             "addNoteLabel: 'Add a collection note'"),
            (editor, "CollectionEditorView", "collection.frontmatter.header", "Title Page & Introduction", "collectionSettings",
             "frontMatterHeader: 'Title Page & Introduction'"),
            (editor, "CollectionEditorView", "collection.frontmatter.footer",
             "Rendered on the exported title page; the introduction opens the body, after the table of contents and before the first document. Leave blank to keep the plain document layout.",
             "collectionSettings",
             "frontMatterFooter: 'Rendered on the exported title page; the introduction opens the body, after the table of contents and before the first document. Leave blank to keep the plain document layout.'"),
            (editor, "CollectionEditorView", "collection.frontmatter.subtitle.placeholder", "Subtitle (title page)", "collectionSettings",
             "subtitlePlaceholder: 'Subtitle (title page)'"),
            (editor, "CollectionEditorView", "collection.frontmatter.subtitle.accessibility", "Collection subtitle", "collectionSettings",
             "subtitleLabel: 'Collection subtitle'"),
            (editor, "CollectionEditorView", "collection.frontmatter.author.placeholder", "Author", "collectionSettings",
             "authorPlaceholder: 'Author'"),
            (editor, "CollectionEditorView", "collection.frontmatter.author.accessibility", "Author line", "collectionSettings",
             "authorLabel: 'Author line'"),
            (editor, "CollectionEditorView", "collection.frontmatter.introduction.label", "Introduction", "collectionSettings",
             "introduction: 'Introduction'"),
            (editor, "CollectionEditorView", "collection.frontmatter.colophon.toggle", "Include colophon", "collectionSettings",
             "colophon: 'Include colophon'"),
            (editor, "CollectionEditorView", "collection.frontmatter.projectProvenance.toggle", "Stamp active project on export",
             "collectionSettings", "projectProvenance: 'Stamp active project on export'"),
            (editor, "CollectionEditorView", "collection.frontmatter.methodAppendix.toggle", "Append the query log", "collectionSettings",
             "methodAppendix: 'Append the query log'"),
            (editor, "CollectionEditorView", "collection.frontmatter.methodAppendix.subtitle",
             "Every search you ran under the active project, with its scope and result count.", "collectionSettings",
             "methodAppendixDetail: 'Every search you ran under the active project, with its scope and result count.'"),
            (composition, "CollectionCompositionRows", "composition.presets.header", "Start from a template — optional", "collectionSettings",
             "presetsHeader: 'Start from a template — optional'"),
            (composition, "CollectionCompositionRows", "composition.presets.active", "Active", "collectionSettings", "presetActive: 'Active'"),
            (composition, "CollectionCompositionRows", "composition.presets.applyHint",
             "Applies this composition. Everything stays editable afterward.", "collectionSettings",
             "presetHint: 'Applies this composition. Everything stays editable afterward.'"),
            (exporter, "CollectionExporter", "collection.preset.teachingReader", "Teaching reader", "collectionSettings", "name: 'Teaching reader'"),
            (exporter, "CollectionExporter", "collection.preset.teachingReader.subtitle", "Full text · notes · chronology", "collectionSettings",
             "subtitle: 'Full text · notes · chronology'"),
            (exporter, "CollectionExporter", "collection.preset.briefingPacket", "Briefing packet", "collectionSettings", "name: 'Briefing packet'"),
            (exporter, "CollectionExporter", "collection.preset.briefingPacket.subtitle", "Summaries · headnotes · word cloud",
             "collectionSettings", "subtitle: 'Summaries · headnotes · word cloud'"),
            (exporter, "CollectionExporter", "collection.preset.sourceDossier", "Source dossier", "collectionSettings", "name: 'Source dossier'"),
            (exporter, "CollectionExporter", "collection.preset.sourceDossier.subtitle", "Outline · source notes · sources", "collectionSettings",
             "subtitle: 'Outline · source notes · sources'"),
            (exporter, "CollectionExporter", "collection.preset.scholarlyEdition", "Scholarly edition", "collectionSettings",
             "name: 'Scholarly edition'"),
            (exporter, "CollectionExporter", "collection.preset.scholarlyEdition.subtitle", "Everything · full apparatus", "collectionSettings",
             "subtitle: 'Everything · full apparatus'"),
            (composition, "CollectionCompositionRows", "composition.group.documentContent", "Document content", "collectionSettings",
             "documentContent: 'Document content'"),
            (composition, "CollectionCompositionRows", "composition.group.documentContent.help", "How much of each source to include.",
             "collectionSettings", "documentContentHelp: 'How much of each source to include.'"),
            (composition, "CollectionCompositionRows", "composition.bodyDepth", "Body depth", "collectionSettings", "bodyDepth: 'Body depth'"),
            (exporter, "CollectionExporter", "export.bodyDepth.full", "Full document", "collectionSettings", "full: 'Full document'"),
            (exporter, "CollectionExporter", "export.bodyDepth.summaryOnly", "Summary only", "collectionSettings", "summaryOnly: 'Summary only'"),
            (exporter, "CollectionExporter", "export.bodyDepth.index", "Index / outline", "collectionSettings", "index: 'Index / outline'"),
            (composition, "CollectionCompositionRows", "composition.summaryPrompt", "Summary prompt", "collectionSettings",
             "summaryPrompt: 'Summary prompt'"),
            (composition, "CollectionCompositionRows", "composition.summaryPrompt.none", "Select…", "collectionSettings",
             "summaryPromptNone: 'Select…'"),
            (composition, "CollectionCompositionRows", "composition.includeFootnotes", "Footnotes", "collectionSettings", "footnotes: 'Footnotes'"),
            (composition, "CollectionCompositionRows", "composition.includeSourceNote", "Archival source note", "collectionSettings",
             "sourceNote: 'Archival source note'"),
            (composition, "CollectionCompositionRows", "composition.group.annotations", "Your annotations", "collectionSettings",
             "annotations: 'Your annotations'"),
            (composition, "CollectionCompositionRows", "composition.group.annotations.help",
             "Notes, highlights & headnotes — linked to each source.", "collectionSettings",
             "annotationsHelp: 'Notes, highlights & headnotes — linked to each source.'"),
            (composition, "CollectionCompositionRows", "composition.includeNotes", "Research notes", "collectionSettings", "notes: 'Research notes'"),
            (composition, "CollectionCompositionRows", "composition.applyHighlights", "Highlights in body", "collectionSettings",
             "highlights: 'Highlights in body'"),
            (composition, "CollectionCompositionRows", "composition.defaultHeadnote", "Headnotes", "collectionSettings", "headnotes: 'Headnotes'"),
            (composition, "CollectionCompositionRows", "composition.group.analysis", "Analysis & apparatus", "collectionSettings",
             "analysis: 'Analysis & apparatus'"),
            (composition, "CollectionCompositionRows", "composition.group.analysis.help", "Generated overviews and the contents-list style.",
             "collectionSettings", "analysisHelp: 'Generated overviews and the contents-list style.'"),
            (composition, "CollectionCompositionRows", "composition.includeWordCloud", "Word-cloud overview", "collectionSettings",
             "wordCloud: 'Word-cloud overview'"),
            (composition, "CollectionCompositionRows", "composition.tocStyle", "Contents list", "collectionSettings", "tocStyle: 'Contents list'"),
            (exporter, "CollectionExporter", "export.tocStyle.citation", "Citation", "collectionSettings", "citation: 'Citation'"),
            (exporter, "CollectionExporter", "export.tocStyle.headerAndDateline", "Header & Dateline", "collectionSettings",
             "headerAndDateline: 'Header & Dateline'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.section.title", "Section Details", "collectionInspector",
             "sectionTitle: 'Section Details'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.title", "Document Details", "collectionInspector",
             "documentTitle: 'Document Details'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.loading", "Loading document details…", "collectionInspector",
             "loading: 'Loading document details…'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.document", "Document", "collectionInspector", "document: 'Document'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.volume", "Volume", "collectionInspector", "volume: 'Volume'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.titleOverride", "Title override", "collectionInspector",
             "titleOverride: 'Title override'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.titleOverride.caption",
             "Overrides the document title in the table of contents and the export heading. Leave blank to use the derived title.",
             "collectionInspector",
             "titleOverrideCaption: 'Overrides the document title in the table of contents and the export heading. Leave blank to use the derived title.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.section.heading", "Section", "collectionInspector", "section: 'Section'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.yourData", "Your Annotations", "collectionInspector",
             "yourAnnotations: 'Your Annotations'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.noNotes", "No research notes", "collectionInspector",
             "noNotes: 'No research notes'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.note.include", "Include this research note when notes apply",
             "collectionInspector", "noteInclude: 'Include this research note when notes apply'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.note.selectionCaption",
             "Checked notes are included when research notes apply to this document. Unselecting every note turns notes off for it.",
             "collectionInspector",
             "noteCaption: 'Checked notes are included when research notes apply to this document. Unselecting every note turns notes off for it.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.highlight.one", "1 highlight", "collectionInspector",
             "count === 1 ? '1 highlight'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.highlight.include", "Include this passage when highlights apply",
             "collectionInspector", "highlightInclude: 'Include this passage when highlights apply'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.excerpt.inserted", "Inserted", "collectionInspector",
             "inserted: 'Inserted'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.excerpt.insert", "Insert as Excerpt", "collectionInspector",
             "insertExcerpt: 'Insert as Excerpt'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.excerpt.noText",
             "No stored passage text — open the document and re-create this highlight to excerpt it.", "collectionInspector",
             "noText: 'No stored passage text — open the document and re-create this highlight to excerpt it.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.highlight.selectionCaption",
             "Checked passages are included when highlights apply to this document. Unselecting every passage turns highlights off for it.",
             "collectionInspector",
             "highlightCaption: 'Checked passages are included when highlights apply to this document. Unselecting every passage turns highlights off for it.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.summary", "AI summary", "collectionInspector", "summary: 'AI summary'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.resolvesOn", "Default → On", "collectionInspector",
             "resolvesOn: 'Default → On'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.resolvesOff", "Default → Off", "collectionInspector",
             "resolvesOff: 'Default → Off'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.prompt.none", "None", "collectionInspector", "promptNone: 'None'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.default", "Default", "collectionInspector", "default: 'Default'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.on", "On", "collectionInspector", "on: 'On'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.off", "Off", "collectionInspector", "off: 'Off'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.highlights", "Highlights", "collectionInspector",
             "highlights: 'Highlights'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.notes", "Research notes", "collectionInspector",
             "notes: 'Research notes'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.sourceNote", "Source note", "collectionInspector",
             "sourceNote: 'Source note'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.footnotes", "Footnotes", "collectionInspector",
             "footnotes: 'Footnotes'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.prompt", "Summary prompt", "collectionInspector",
             "prompt: 'Summary prompt'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.override.related", "Related documents", "collectionInspector",
             "related: 'Related documents'"),
            (inspector, "CollectionEntryInspector", "collection.entry.bodyDepth.default", "Default", "collectionInspector",
             "bodyDepthDefault: 'Default'"),
            (inspector, "CollectionEntryInspector", "collection.entry.bodyDepth.label", "Body depth", "collectionInspector",
             "bodyDepth: 'Body depth'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.overrides", "Export Overrides", "collectionInspector",
             "overrides: 'Export Overrides'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.overrides.caption",
             "Default follows the section’s setting when its heading sets one, else the collection’s composition.", "collectionInspector",
             "overridesCaption: 'Default follows the section’s setting when its heading sets one, else the collection’s composition.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.sectionDefaults", "Section Defaults", "collectionInspector",
             "sectionDefaults: 'Section Defaults'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.sectionDefaults.caption",
             "Documents in this section use these settings unless they set their own. Default falls through to the collection’s composition.",
             "collectionInspector",
             "sectionDefaultsCaption: 'Documents in this section use these settings unless they set their own. Default falls through to the collection’s composition.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.excerpts", "Excerpts in This Collection", "collectionInspector",
             "excerpts: 'Excerpts in This Collection'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.excerpts.caption",
             "Reorder or delete excerpts in the collection list. Insert new ones from the highlight rows above.", "collectionInspector",
             "excerptsCaption: 'Reorder or delete excerpts in the collection list. Insert new ones from the highlight rows above.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote", "Headnote", "collectionInspector", "headnote: 'Headnote'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.toggle", "Show a summary above the document",
             "collectionInspector", "headnoteToggle: 'Show a summary above the document'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.provenance", "Provenance", "collectionInspector",
             "provenance: 'Provenance'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.noSource", "No archival source note indexed", "collectionInspector",
             "noSource: 'No archival source note indexed'"),
            (excerpts, "CollectionExcerpts", "collection.addHighlights.title", "Add Highlighted Passages", "addHighlights",
             "title: 'Add Highlighted Passages'"),
            (excerpts, "CollectionExcerpts", "collection.addHighlights.empty.title", "No Highlighted Passages", "addHighlights",
             "emptyTitle: 'No Highlighted Passages'"),
            (excerpts, "CollectionExcerpts", "collection.addHighlights.empty.detail",
             "Highlight passages in this collection’s documents to insert them here as excerpts.", "addHighlights",
             "emptyDetail: 'Highlight passages in this collection’s documents to insert them here as excerpts.'"),
            (excerpts, "CollectionExcerpts", "common.cancel", "Cancel", "addHighlights", "cancel: 'Cancel'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.title", "Add Documents", "addDocuments", "title: 'Add Documents'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.cancel", "Cancel", "addDocuments", "cancel: 'Cancel'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.tab.picker", "Find documents", "addDocuments",
             "tabs: 'Find documents'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.tab.search", "Search", "addDocuments", "search: 'Search'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.tab.browse", "Browse", "addDocuments", "browse: 'Browse'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.search.placeholder", "Search indexed documents", "addDocuments",
             "searchPlaceholder: 'Search indexed documents'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.badge.editorial", "Editorial note", "addDocuments",
             "editorialNote: 'Editorial note'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.browse.filter", "Filter volumes by title or ID", "addDocuments",
             "filter: 'Filter volumes by title or ID'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.browse.back", "Volumes", "addDocuments", "back: 'Volumes'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.browse.selectAll", "Select All", "addDocuments",
             "selectAll: 'Select All'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.browse.deselectAll", "Deselect All", "addDocuments",
             "deselectAll: 'Deselect All'"),
            (addDocuments, "CollectionAddDocumentsSheet", "collection.addDocs.inCollection", "In collection", "addDocuments",
             "inCollection: 'In collection'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(blocks[word.block]?.contains(word.web) == true, "copy.ts's \(word.block) block holds \(word.web)")
        }
        // The words with a count or a name in them, as the app formats them and copy.ts's functions say them.
        let mac = try Self.app("Collections/MacCollectionManagerView.swift")
        let formats: [(source: String, file: String, line: String, block: String, web: String)] = [
            (list, "CollectionListView", #"String(localized: "collections.row.count", defaultValue: "\(count) document\(count == 1 ? "" : "s")")"#,
             "collections", "documentCount: (count: number) => `${count} document${count === 1 ? '' : 's'}`"),
            (picker, "CollectionPickerSheet", #"String(localized: "collection.picker.docCount", defaultValue: "\(documentCount) document\(documentCount == 1 ? "" : "s")")"#,
             "collections", "documentCount: (count: number) => `${count} document${count === 1 ? '' : 's'}`"),
            (list, "CollectionListView", #"defaultValue: "Showing collections from every project, including ones outside “\(activeProjectDisplayName)”.")"#,
             "collections", "showingAll: (project: string) => `Showing collections from every project, including ones outside “${project}”.`"),
            (list, "CollectionListView", #"defaultValue: "Scope to “\(activeProjectDisplayName)”")"#,
             "collections", "scopeToProject: (project: string) => `Scope to “${project}”`"),
            (list, "CollectionListView", #"defaultValue: "Showing collections for “\(activeProjectDisplayName)” — \(hidden) other collection\(hidden == 1 ? "" : "s") hidden.")"#,
             "collections", "`Showing collections for “${project}” — ${hidden} other collection${hidden === 1 ? '' : 's'} hidden.`"),
            (list, "CollectionListView", #"defaultValue: "Showing collections for “\(activeProjectDisplayName)”.")"#,
             "collections", "filteredNoHidden: (project: string) => `Showing collections for “${project}”.`"),
            (picker, "CollectionPickerSheet", #"defaultValue: "No collections match “\(searchText)”.")"#,
             "collections", "pickerNoResults: (text: string) => `No collections match “${text}”.`"),
            (mac, "MacCollectionManagerView", #"Text("New Collection").font(.headline)"#, "collections", "newTitle: 'New Collection'"),
            (mac, "MacCollectionManagerView", #"Section("Name") { TextField("Collection Name", text: $name)"#, "collections",
             "newNamePlaceholder: 'Collection Name'"),
            (mac, "MacCollectionManagerView", #"Button("Cancel") { dismiss() }"#, "collections", "newCancel: 'Cancel'"),
            (mac, "MacCollectionManagerView", #"Button("Create") { createAndDismiss() }"#, "collections", "newCreate: 'Create'"),
            (rows, "CollectionEntryRows", #"String(localized: "collection.section.collapsedCount %lld", defaultValue: "%lld hidden"), Int64(sectionEntryCount))"#,
             "collectionEditor", "hidden: (count: number) => `${count} hidden`"),
            (rows, "CollectionEntryRows", #"String(localized: "collection.section.delete.confirm.message %lld", defaultValue: "Deletes this heading and the %lld entries it contains."), Int64(sectionEntryCount))"#,
             "collectionEditor", "deleteSectionMessage: (count: number) => `Deletes this heading and the ${count} entries it contains.`"),
            (rows, "CollectionEntryRows", #"defaultValue: "Document \(documentHeader ?? entry.documentId)")"#,
             "collectionEditor", "documentLabel: (header: string) => `Document ${header}`"),
            (rows, "CollectionEntryRows", #"defaultValue: "Excerpt from \(entry.documentId): \(entry.text ?? "")")"#,
             "collectionEditor", "excerptLabel: (documentId: string, text: string) => `Excerpt from ${documentId}: ${text}`"),
            (rows, "CollectionEntryRows", #"defaultValue: "Lists \(count) document\(count == 1 ? "" : "s").")"#,
             "collectionEditor", "generatedCount: (count: number) => `Lists ${count} document${count === 1 ? '' : 's'}.`"),
            (rows, "CollectionEntryRows", #"defaultValue: "Generated block: \(title)")"#,
             "collectionEditor", "generatedLabel: (title: string) => `Generated block: ${title}`"),
            (rows, "CollectionEntryRows", #"String(localized: "collection.entry.chip.notes.other %lld", defaultValue: "%lld notes"), Int64(noteCount))"#,
             "collectionEditor", "notes: (count: number) => (count === 1 ? '1 note' : `${count} notes`)"),
            (addDocuments, "CollectionAddDocumentsSheet", #"String(localized: "collection.addDocs.addedToast %lld", defaultValue: "Added %lld documents"), Int64(count))"#,
             "collectionEditor", "addedMany: (count: number) => `Added ${count} documents`"),
            (inspector, "CollectionEntryInspector", #"defaultValue: "\(highlightCount) highlights")"#,
             "collectionInspector", "highlightCount: (count: number) => (count === 1 ? '1 highlight' : `${count} highlights`)"),
            (inspector, "CollectionEntryInspector", #"defaultValue: "AI summary — \(name)")"#,
             "collectionInspector", "summaryFromPrompt: (name: string) => `AI summary — ${name}`"),
            (inspector, "CollectionEntryInspector", #"defaultValue: "Default → \(text)")"#,
             "collectionInspector", "resolvesTo: (text: string) => `Default → ${text}`"),
            (inspector, "CollectionEntryInspector", #"defaultValue: "Adds a \u{201C}See also\u{201D} line listing cross-referenced documents that are also in this collection. Off unless turned on here or on the section.")"#,
             "collectionInspector",
             "'Adds a \\u{201C}See also\\u{201D} line listing cross-referenced documents that are also in this collection. Off unless turned on here or on the section.'"),
            (excerpts, "CollectionExcerpts", #"defaultValue: "Insert \(selectedIds.count) Excerpt\(selectedIds.count == 1 ? "" : "s")")"#,
             "addHighlights", "insert: (count: number) => `Insert ${count} Excerpt${count === 1 ? '' : 's'}`"),
            (addDocuments, "CollectionAddDocumentsSheet", #"String(localized: "collection.addDocs.add %lld", defaultValue: "Add %lld Document(s)")"#,
             "addDocuments", "add: (count: number) => `Add ${count} Document(s)`"),
        ]
        for format in formats {
            #expect(format.source.contains(format.line), "\(format.file) holds \(format.line)")
            #expect(blocks[format.block]?.contains(format.web) == true, "copy.ts's \(format.block) block holds \(format.web)")
        }
        // The server's own words, the app's: an untitled section, a note's untitled row, a copy's name.
        #expect(CollectionEditorNaming.untitledSection == "Untitled section")
        NoteViewParityTests.expect(inspector, holds: [#"String(localized: "collection.entry.note.emptyPreview", defaultValue: "Untitled Note")"#],
                                   file: "CollectionEntryInspector.swift")
        #expect(CollectionEntryRoutes.notePreview("  ") == "Untitled Note")
        NoteViewParityTests.expect(model, holds: [#"String(localized: "collection.duplicate.name %@", defaultValue: "%@ copy"), base)"#],
                                   file: "Collection.swift")
        #expect(CollectionEditing.duplicateName("Berlin") == "Berlin copy")
        NoteViewParityTests.expect(picker, holds: [
            #"defaultValue: "This is a smart collection. Its documents come from its saved search, so nothing can be added to it by hand.")"#,
        ], file: "CollectionPickerSheet.swift")
        #expect(CollectionRoutes.smart().detail == "This is a smart collection. Its documents come from its saved search, so nothing can be added to it by hand.")
    }

    /// The server's mirrors of the app's editor rules over its models, each held by the lines the app's
    /// source writes them in.
    @Test func theServersMirrorsAreTheApps() throws {
        NoteViewParityTests.expect(try Self.app("Collections/CollectionOutline+App.swift"), holds: [
            // normalize
            "for item in linearize(entries) where item.entry.entryKind == .heading { if item.entry.level != item.depth { item.entry.level = item.depth } }",
            // canIndent and canOutdent
            "guard level < maxLevel else { return false }",
            "for i in stride(from: headingIndex - 1, through: 0, by: -1) where items[i].entry.entryKind == .heading { return items[i].depth >= level }",
            "return false // first heading: indenting would orphan it above level 1", "return items[headingIndex].depth > 1",
            // indent, outdent and their shift
            "guard canIndent(headingIndex, in: items) else { return } shiftSection(at: headingIndex, by: +1, items: items) normalize(entries)",
            "guard canOutdent(headingIndex, in: items) else { return } shiftSection(at: headingIndex, by: -1, items: items) normalize(entries)",
            "items[i].entry.level = min(max(items[i].depth + delta, 1), maxLevel)",
            // the move
            "guard let order = movedOrder(sorted.map(StructuralRef.init), fromIndex: fromIndex, toOffset: toOffset) else { return nil }",
            "init(isHeading: entry.entryKind == .heading, level: entry.level, bodyDepthOverride: entry.bodyDepthOverride)",
        ], file: "CollectionOutline+App.swift")
        let data = try Self.app("Collections/CollectionEntryData.swift")
        NoteViewParityTests.expect(data, holds: [
            // ordering
            "let highest = ((collection.documentEntries ?? []) + outline).map(\\.sortOrder).max() return (highest ?? -1) + 1",
            "if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }", "case (nil, nil): return a.id.uuidString < b.id.uuidString",
            "for (index, entry) in outline.enumerated() { entry.sortOrder = index }",
            // appendBlock
            "guard SmartCollectionRule.takesHandAddedEntries(savedSearchId: collection.savedSearchId) else { return nil }",
            #"let entry = CollectionEntry(collectionId: collection.id, documentId: "", volumeId: "", sortOrder: nextSortOrder(in: collection, outline: outline)) entry.entryKind = kind entry.text = """#,
            // Sort by Date
            "if let d = entry.dateRange.earliest { volumeDateMap[entry.volumeId] = d }",
            "if entry.entryKind == .heading, !run.isEmpty {",
            #"let aDate = documentDates["\(a.volumeId)/\(a.documentId)"] ?? volumeDateMap[a.volumeId] ?? "9999""#,
            "return entries.map { $0.entryKind == .document ? (docs.next() ?? $0) : $0 }",
        ], file: "CollectionEntryData.swift")
        let editor = try Self.app("Collections/CollectionEditorView.swift")
        NoteViewParityTests.expect(editor, holds: [
            // finishOutlineMutation: renumbered, then normalized
            "private func finishOutlineMutation() { reindexEntries() CollectionOutline.normalize(sortedEntries) try? modelContext.save() }",
            // the deletes
            "let range = CollectionOutline.sectionRange(of: index, in: items) guard range.upperBound <= sortedEntries.count else { return }",
            "GeneratedSummary.deleteHeadnoteDraft(for: sortedEntries[index], in: modelContext) modelContext.delete(sortedEntries[index]) sortedEntries.remove(at: index) finishOutlineMutation()",
            // the move
            "let to = newOffset >= visible.count ? sortedEntries.count : visible[newOffset]",
            "guard let reordered = CollectionOutline.applyingMove( sortedEntries, fromIndex: from, toOffset: to) else { return } sortedEntries = reordered finishOutlineMutation()",
            // the apparatus and the presets
            "entry.entryKind = .generated entry.generatedBlockType = type.rawValue",
            "case .frontMatter: sortedEntries.insert(entry, at: 0) case .backMatter: sortedEntries.append(entry) } reindexEntries()",
            "preset.applyFields(to: collection) let present = Set(sortedEntries.compactMap { $0.entryKind == .generated ? $0.generatedBlockType : nil })",
            "for block in preset.apparatusBlocks(notAlreadyIn: present) { addGeneratedEntry(type: block) }",
            // Sort by Date's tail
            "withinSections: withinSections) reindexEntries()",
            // the commits and recordEdit
            "collection.name = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)",
            "let trimmed = fieldText.trimmingCharacters(in: .whitespacesAndNewlines) collection[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed",
            "guard collection[keyPath: keyPath] != isOn else { return false }",
            "if let projectId = appState.activeProjectId, !collection.projectIds.contains(projectId) { collection.projectIds.append(projectId) }",
            "let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines) if trimmed.isEmpty { collection.introductionText = nil collection.introductionRichText = nil",
        ], file: "CollectionEditorView.swift")
        let discovery = try Self.app("Collections/CollectionAddDocumentsSheet.swift")
        NoteViewParityTests.expect(discovery, holds: [
            "var next = CollectionEntryOrdering.nextSortOrder(in: collection, outline: sortedEntries) for ref in refs {",
            "let nextOrder = CollectionEntryOrdering.nextSortOrder(in: collection)",
            "for entry in entries where entry.entryKind == .document { counts[documentKey(volumeId: entry.volumeId, documentId: entry.documentId), default: 0] += 1 } return Set(counts.filter { $0.value > 1 }.keys)",
        ], file: "CollectionAddDocumentsSheet.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionPickerSheet.swift"), holds: [
            "guard !existing.contains(where: { $0.entryKind == .document && $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }) else {",
            "CollectionExcerpts.appendToCollection(excerpt, collection: collection, modelContext: modelContext)",
        ], file: "CollectionPickerSheet.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionExcerpts.swift"), holds: [
            "guard !highlight.selectedText.isEmpty else { return nil }",
            "renderingVersion: highlight.renderingVersion.isEmpty ? nil : highlight.renderingVersion, colorTag: highlight.colorTag)",
            "entry.entryKind = .excerpt entry.text = capture.text entry.excerptStart = capture.start entry.excerptEnd = capture.end entry.excerptRenderingVersion = capture.renderingVersion entry.excerptColorTag = capture.colorTag",
            "var next = CollectionEntryOrdering.nextSortOrder(in: collection, outline: sortedEntries) for capture in captures {",
        ], file: "CollectionExcerpts.swift")
        let model = try Self.app("Models/Collection.swift")
        NoteViewParityTests.expect(model, holds: [
            // the footnote flags
            "includeFootnotes = footnotes includeSourceNote = sourceNote footnoteStyle = Self.bestFitFootnoteStyleRawValue(footnotes: footnotes, sourceNote: sourceNote)",
            // the document count and SmartCollectionRule
            "(documentEntries ?? []).count { $0.entryKind == .document }", "savedSearchId == nil",
            "case .document, .heading, .prose, .excerpt: return true case .generated, .unrecognized: return false",
            // the duplicate: what it copies, the two stamps among what it does not
            #"let base = name.isEmpty ? String(localized: "collection.untitled.name", defaultValue: "Untitled Collection") : name"#,
            "copy.subtitle = subtitle copy.authorLine = authorLine copy.introductionText = introductionText copy.introductionRichText = introductionRichText copy.includeColophon = includeColophon",
            "copy.savedSearchId = savedSearchId",
            "copy.summaryPromptId = summaryPromptId context.insert(copy)",
            "for entry in (documentEntries ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {",
            "GeneratedSummary.duplicateHeadnoteDraft(from: entry, to: e, in: context)",
        ], file: "Collection.swift")
        #expect(!model.contains("copy.includeProjectProvenance") && !model.contains("copy.includeMethodAppendix"),
                "the app's copy leaves the two export stamps at their defaults")
        NoteViewParityTests.expect(try Self.app("Models/GeneratedSummary.swift"), holds: [
            "predicate: #Predicate { $0.id == sid && $0.isHeadnoteDraft }))) ?? [] for draft in drafts { context.delete(draft) }",
            "authorship: draft.authorship ?? .aiGenerated, isHeadnoteDraft: true) context.insert(copyDraft) copyEntry.headnoteSummaryId = copyDraft.id",
        ], file: "GeneratedSummary.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionExporter+App.swift"), holds: [
            "collection.defaultBodyDepth = r.bodyDepth.rawValue collection.effectiveIncludeFootnotes = r.footnotes collection.effectiveIncludeSourceNote = r.sourceNote collection.includeNotes = r.notes collection.defaultIncludeHeadnote = r.headnotes collection.applyHighlights = r.highlights collection.includeWordCloud = r.wordCloud collection.tocStyle = r.toc.rawValue",
            "return collection.defaultBodyDepth == r.bodyDepth.rawValue && collection.effectiveIncludeFootnotes == r.footnotes",
        ], file: "CollectionExporter+App.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionEntryInspector.swift"), holds: [
            // the selections
            "var selected = entry.selectedHighlightIds.isEmpty ? allIds : entry.selectedHighlightIds",
            "if Set(selected).isSuperset(of: allIds) { entry.selectedHighlightIds = [] } else if selected.isEmpty { entry.selectedHighlightIds = [] entry.applyHighlightsOverride = false } else { entry.selectedHighlightIds = selected }",
            "entry.selectedHighlightIds.isEmpty || entry.selectedHighlightIds.contains(id)",
            "} else if let legacy = entry.researchNoteId { selected = [legacy] } else { selected = allIds } // Clear the legacy link once we start writing the array (single source of truth). entry.researchNoteId = nil",
            "if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.contains(id) } if let legacy = entry.researchNoteId { return legacy == id } return true",
            // the resolved defaults
            "highlights: section { $0.applyHighlightsOverride } ?? collection.applyHighlights,",
            "sourceNote: section { $0.includeSourceNoteOverride } ?? collection.effectiveIncludeSourceNote,",
            "related: section { $0.includeRelatedDocuments } ?? false,", "headnote: collection.defaultIncludeHeadnote",
            // the title override, the notes' rows, the highlights' order and the summary shown
            "set: { entry.titleOverride = $0.isEmpty ? nil : $0 }),",
            "let trimmed = note.bodyText.prefix(60).trimmingCharacters(in: .whitespacesAndNewlines)",
            ".sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }",
            ".sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }",
            ".filter { !$0.responseText.isEmpty && !$0.isHeadnoteDraft }",
            "let shown = collectionPromptId.flatMap { pid in summaries.first { $0.promptId == pid } } ?? summaries.first",
            #"return "\(vol) — \(entry.documentId)""#,
        ], file: "CollectionEntryInspector.swift")
        NoteViewParityTests.expect(try Self.app("Citation/ZoteroJSONExporter+App.swift"), holds: ["return (tags: tagNames.sorted(), notes: noteBodies)"],
                                   file: "ZoteroJSONExporter+App.swift")
        NoteViewParityTests.expect(try Self.app("DocumentView/ResearchRailView.swift"), holds: [
            #"$0.volumeId == volumeId && $0.documentId == documentId && $0.kind == "document""#,
            "return CollectionEditorNaming.sortedByListName(result)",
        ], file: "ResearchRailView.swift")
        NoteViewParityTests.expect(try Self.app("Models/Collection.swift"), holds: [
            "let order = listOrder($0.name, $1.name) return order != .orderedSame ? order == .orderedAscending : $0.id.uuidString < $1.id.uuidString",
        ], file: "Collection.swift")
        // The kit's rules the server calls, which a pin move could change under it.
        let kit = try Self.kit("FRUSCoreKit/Collections/CollectionExporter.swift")
        NoteViewParityTests.expect(kit, holds: [
            "summariesAvailable ? allCases : allCases.filter { $0 != .summaryOnly }",
        ], file: "CollectionExporter.swift")
        #expect(CollectionPreset.allCases.filter { $0.recipe.bodyDepth == .summaryOnly } == [.briefingPacket],
                "Briefing packet is the one preset that composes summaries, which the server offers only where some are stored")
        #expect(CollectionRoutes.offeredPresets(summariesAvailable: false) == [.teachingReader, .sourceDossier, .scholarlyEdition])
        #expect(CollectionRoutes.offeredPresets(summariesAvailable: true) == CollectionPreset.allCases)
    }

    /// The browser app's mirrors of the app's view rules, each held by the lines the app's source
    /// writes them in and the lines of collectionRules.ts that mirror them.
    @Test func theWebsMirrorsAreTheApps() throws {
        let rules = try Self.web("collections/collectionRules.ts")
        let model = try Self.app("Models/Collection.swift")
        NoteViewParityTests.expect(model, holds: [
            "static let managerDefaultShowAllCollections = true",
            "guard let projectId = activeProjectId, !showAll else { return all } return all.filter { $0.projectIds.contains(projectId) }",
        ], file: "Collection.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionListView.swift"), holds: [
            "return allCollections.filter { !$0.projectIds.contains(projectId) }.count",
            "@Query(sort: \\Collection.lastModified, order: .reverse) private var allCollections: [Collection]",
        ], file: "CollectionListView.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionOutline+App.swift"), holds: [
            "guard savedSearchId != nil else { return visibleRows(in: items, collapsedHeadingIds: collapsedHeadingIds) }",
            "return SmartCollectionRule.leavesOut(entry.entryKind, savedSearchId: savedSearchId) ? nil : VisibleRow(index: index, depth: 0, id: entry.id)",
        ], file: "CollectionOutline+App.swift")
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/Collections/CollectionOutline.swift"), holds: [
            "let range = sectionRange(of: index, refs: refs) hidden.formUnion((range.lowerBound + 1) ..< range.upperBound)",
        ], file: "CollectionOutline.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionEditorView.swift"), holds: [
            "let steps = sortedEntries[row.index].entryKind == .heading ? max(0, row.depth - 1) : row.depth",
            "guard pos > 0 else { return } moveVisibleRows(IndexSet(integer: pos), to: pos - 1, visible: rows.map(\\.index))",
            "let blockEnd = movedBlockEnd(of: rows[pos].index) return rows[(pos + 1)...].contains { $0.index >= blockEnd }",
            "guard let nextPos = visible.indices.first(where: { visible[$0] >= blockEnd }) else { return } moveVisibleRows(IndexSet(integer: pos), to: nextPos + 1, visible: visible)",
            "return CollectionOutline.sectionRange(of: fullIndex, in: items).upperBound } return fullIndex + 1",
        ], file: "CollectionEditorView.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionEntryRows.swift"), holds: [
            "if let raw = entry.bodyDepthOverride, let depth = CollectionBodyDepth(rawValue: raw) {",
            "if entry.includeNotesOverride == false {",
            "if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.count } if entry.researchNoteId != nil { return 1 } return availableNoteCount",
            "if entry.applyHighlightsOverride == false {", "entry.includeHeadnote ?? entry.collection?.defaultIncludeHeadnote ?? false",
            "if entry.includeRelatedDocuments == true {",
        ], file: "CollectionEntryRows.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionCompositionRows.swift"), holds: [
            "return available.contains(current) ? available : available + [current]",
            ".disabled(bodyDepth.wrappedValue != .full)", "if bodyDepth.wrappedValue == .summaryOnly {",
        ], file: "CollectionCompositionRows.swift")
        NoteViewParityTests.expect(try Self.app("Collections/CollectionPickerSheet.swift"), holds: [
            "if let at = place[id(item)] { known.append((at, item)) } else { new.append(item) }",
            "return new + known.sorted { $0.place < $1.place }.map(\\.item)", "takesEntries = !isSmart",
            "let pause = outcome.insertedCount == 0 ? 0.8 : 0.6", "DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }",
        ], file: "CollectionPickerSheet.swift")
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/Collections/CollectionEditorNaming.swift"), holds: [
            "listName(savedName: savedName).localizedCaseInsensitiveContains(searchText)",
        ], file: "CollectionEditorNaming.swift")
        NoteViewParityTests.expect(rules, holds: [
            "export const managerDefaultShowAllCollections = true;",
            "if (!activeProjectId || showAll) return [...all];",
            "if (collection.savedSearchId) { return entries.flatMap((entry, index) => (entry.leftOut ? [] : [{ index, depth: 0, entry }])); }",
            "for (let i = index + 1; i < (entry.sectionEnd ?? index + 1); i += 1) hidden.add(i);",
            "return row.entry.kind === 'heading' ? Math.max(0, row.depth - 1) : row.depth;",
            "return entry.kind === 'heading' ? (entry.sectionEnd ?? index + 1) : index + 1;",
            "return { from: row.index, to: newOffset >= rows.length ? count : rows[newOffset]!.index };",
            "return pos > 0 ? visibleMove(rows, pos, pos - 1, count) : null;",
            "return rows.slice(pos + 1).some((later) => later.index >= blockEnd);",
            "return nextPos < 0 ? null : visibleMove(rows, pos, nextPos + 1, entries.length);",
            "if (entry.includeNotesOverride === false) {",
            "const count = entry.selectedNoteIds.length > 0 ? entry.selectedNoteIds.length : entry.researchNoteId ? 1 : (entry.noteCount ?? 0);",
            "return entry.includeHeadnote ?? collection.defaultIncludeHeadnote;",
            "return current && !offered.includes(current) ? [...offered, current] : [...offered];",
            "return [...made, ...known.sort((a, b) => a.at - b.at).map((entry) => entry.item)];",
        ], file: "collectionRules.ts")
        let picker = try Self.web("collections/CollectionPicker.tsx")
        NoteViewParityTests.expect(picker, holds: ["export const addedPause = 600;", "export const heldPause = 800;"], file: "CollectionPicker.tsx")
    }
}
