// The app's words and the lines of its code the web takes for projects, the history, the method
// appendix and the synced preferences (PLAN's S17f, and PLAN's rule for view code: "mirrored with a
// parity test that reads the app's source at the pin"), read from the app's source, the kit's and the
// web's at once: the project picker and "Working on:", Settings ▸ Projects with the editor and Merge
// Project, the Move commands, Project Home with its focus subjects and their editor (S25c), the History
// screen, Research Sessions and the Session Log, Data's method appendix, Settings ▸ Reading and the
// checklist's line; and the rules mirrored, the reader's own order (web/src/research/listOrder.ts), the
// History screen's filter and count (historyRules.ts), Project Home's summary, leads and lines
// (ProjectHome.swift, projectRules.ts), its focus subjects' filter, their editor's sections, search and
// rows (focusSubjectRules.ts) and the engaged volumes their suggestions start from (ProjectFocus.swift),
// a lead's line, a visit's title (`ReadingHistoryTitle`, and the parsed head since S25c), an export's
// format's name, the search trail's re-run, the trail's loaders and the appendix's coverage, the
// project editor's save and the admin's merge, and the synced preferences' initial values and list
// order. A pin move that changes one fails here until the web follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct ProjectHistoryParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func kit(_ path: String) throws -> String { try SearchSetParityTests.kit(path) }
    static func web(_ path: String) throws -> String { try SearchSetParityTests.web(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    /// Each word the web takes, where the app's source writes it under its key, and in copy.ts's block
    /// where the screen reads it.
    @Test func theAppsWordsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let blocks = try Dictionary(uniqueKeysWithValues: ["projectPicker", "projects", "listOrder", "projectHome", "history", "sessions",
                                                           "reading", "dataSettings", "checklist", "settings"].map {
            ($0, try NoteViewParityTests.block($0, of: raw))
        })
        let picker = try Self.app("ProjectContext/ProjectPickerMenu.swift")
        let settings = try Self.app("Settings/SettingsView.swift")
        let editor = try Self.app("ProjectContext/ProjectEditorView.swift")
        let merge = try Self.app("ProjectContext/ProjectContextView.swift")
        let components = try Self.app("Settings/SettingsComponents.swift")
        let home = try Self.app("ProjectContext/ProjectHomeView.swift")
        let focus = try Self.app("ProjectContext/ProjectFocusSubjectsEditor.swift")
        let history = try Self.app("History/HistoryView.swift")
        let snapshot = try Self.app("Models/HistoryPaneSnapshot.swift")
        let sessions = try Self.app("Settings/ResearchSessionsView.swift")
        let summary = try Self.app("Models/ResearchSessionsSummary.swift")
        let log = try Self.app("ProjectContext/SessionLogView.swift")
        let export = try Self.app("Export/ResearchDataExportView.swift")
        let models = try Self.app("Search/SearchModels.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (picker, "ProjectPickerMenu", "project.picker.global", "Global Context", "projectPicker", "global: 'Global Context'"),
            (picker, "ProjectPickerMenu", "project.picker.global.short", "Global", "projectPicker", "globalShort: 'Global'"),
            (picker, "ProjectPickerMenu", "project.picker.manage", "Manage Projects", "projectPicker", "manage: 'Manage Projects'"),
            (picker, "ProjectPickerMenu", "project.picker.a11y", "Switch project context", "projectPicker", "a11y: 'Switch project context'"),
            (picker, "ProjectPickerMenu", "project.workingOn.prefix", "Working on:", "projectPicker", "workingOn: 'Working on:'"),
            (settings, "SettingsView", "settings.projects.home", "Project Home", "projectPicker", "home: 'Project Home'"),
            (settings, "SettingsView", "settings.projects.title", "Projects", "projects", "title: 'Projects'"),
            (settings, "SettingsView", "settings.projects.active.label", "Active Project", "projects", "activeLabel: 'Active Project'"),
            (settings, "SettingsView", "settings.projects.active.global", "Global Context", "projects", "global: 'Global Context'"),
            (settings, "SettingsView", "settings.projects.active.footer",
             "The active project scopes the notes, collections, history, and searches you see. Global Context shows everything.", "projects",
             "activeFooter: 'The active project scopes the notes, collections, history, and searches you see. Global Context shows everything.'"),
            (settings, "SettingsView", "settings.projects.empty.where",
             "No projects yet. A project keeps one line of research — its notes, collections, history and searches — separate from the rest.",
             "projects",
             "empty: 'No projects yet. A project keeps one line of research — its notes, collections, history and searches — separate from the rest.'"),
            (settings, "SettingsView", "settings.projects.list.header", "All Projects", "projects", "listHeader: 'All Projects'"),
            (settings, "SettingsView", "settings.projects.new", "New Project…", "projects", "new: 'New Project…'"),
            (settings, "SettingsView", "settings.projects.list.footer.order",
             "This order is also the order of the Active Project picker, the project switcher and the note editor's project list.", "projects",
             #"listFooter: "This order is also the order of the Active Project picker, the project switcher and the note editor's project list.""#),
            (settings, "SettingsView", "settings.projects.row.active", "active", "projects", "active: 'active'"),
            (settings, "SettingsView", "settings.projects.related.header", "Related", "projects", "relatedHeader: 'Related'"),
            (settings, "SettingsView", "settings.pane.tags", "Tags", "projects", "tags: 'Tags'"),
            (settings, "SettingsView", "settings.pane.scopes", "Volume Scopes", "projects", "scopes: 'Volume Scopes'"),
            (settings, "SettingsView", "settings.projects.related.footer",
             "Open Tags to rename, merge or delete a tag. Open Volume Scopes to edit or delete a scope — scopes cannot be merged.", "projects",
             "relatedFooter: 'Open Tags to rename, merge or delete a tag. Open Volume Scopes to edit or delete a scope — scopes cannot be merged.'"),
            (settings, "SettingsView", "settings.projects.related.tags.none", "None yet", "projects", "noneYet: 'None yet'"),
            (editor, "ProjectEditorView", "project.editor.title.new", "New Project", "projects", "editorNew: 'New Project'"),
            (editor, "ProjectEditorView", "project.editor.title.edit", "Edit Project", "projects", "editorEdit: 'Edit Project'"),
            (editor, "ProjectEditorView", "project.editor.cancel", "Cancel", "projects", "cancel: 'Cancel'"),
            (editor, "ProjectEditorView", "project.editor.save", "Save", "projects", "save: 'Save'"),
            (editor, "ProjectEditorView", "project.editor.name.header", "Name", "projects", "nameHeader: 'Name'"),
            (editor, "ProjectEditorView", "project.editor.name.placeholder", "Project name", "projects", "namePlaceholder: 'Project name'"),
            (editor, "ProjectEditorView", "project.editor.name.a11y", "Project name", "projects", "nameField: 'Project name'"),
            (editor, "ProjectEditorView", "project.editor.question.header", "Research Question", "projects", "questionHeader: 'Research Question'"),
            (editor, "ProjectEditorView", "project.editor.question.a11y", "Research question", "projects", "questionField: 'Research question'"),
            (editor, "ProjectEditorView", "project.editor.manage.header", "Manage", "projects", "manage: 'Manage'"),
            (editor, "ProjectEditorView", "project.editor.merge", "Merge into Another Project…", "projects", "merge: 'Merge into Another Project…'"),
            (editor, "ProjectEditorView", "project.editor.delete", "Delete Project", "projects", "delete: 'Delete Project'"),
            (editor, "ProjectEditorView", "project.editor.manage.footer.only",
             "Merging needs a second project to merge into. Deleting keeps your notes, collections, and history — it only unlinks them from this project.",
             "projects",
             "manageFooterOnly: 'Merging needs a second project to merge into. Deleting keeps your notes, collections, and history — it only unlinks them from this project.'"),
            (editor, "ProjectEditorView", "project.editor.manage.footer",
             "Merging moves everything filed here into the project you choose. Deleting keeps your notes, collections, and history — it only unlinks them from this project.",
             "projects",
             "manageFooter: 'Merging moves everything filed here into the project you choose. Deleting keeps your notes, collections, and history — it only unlinks them from this project.'"),
            (editor, "ProjectEditorView", "settings.projects.delete.title", "Delete Project?", "projects", "deleteTitle: 'Delete Project?'"),
            (editor, "ProjectEditorView", "settings.projects.delete.message", "Activity records are kept but unlinked from this project.", "projects",
             "deleteMessage: 'Activity records are kept but unlinked from this project.'"),
            (editor, "ProjectEditorView", "settings.projects.delete.confirm", "Delete", "projects", "deleteConfirm: 'Delete'"),
            (editor, "ProjectEditorView", "settings.projects.delete.cancel", "Cancel", "projects", "deleteCancel: 'Cancel'"),
            (merge, "ProjectContextView", "project.merge.title", "Merge Project", "projects", "mergeTitle: 'Merge Project'"),
            (merge, "ProjectContextView", "project.merge.cancel", "Cancel", "projects", "mergeCancel: 'Cancel'"),
            (merge, "ProjectContextView", "project.merge.confirm", "Merge", "projects", "mergeConfirm: 'Merge'"),
            (components, "SettingsComponents", "settings.listOrder.moveToTop", "Move to Top", "listOrder", "moveToTop: 'Move to Top'"),
            (components, "SettingsComponents", "settings.listOrder.moveUp", "Move Up", "listOrder", "moveUp: 'Move Up'"),
            (components, "SettingsComponents", "settings.listOrder.moveDown", "Move Down", "listOrder", "moveDown: 'Move Down'"),
            (settings, "SettingsView", "settings.tags.list.footer.order",
             "This order is also the order of your tags in the note editor, the document tag picker and Search.", "settings",
             "tagsOrderFooter: 'This order is also the order of your tags in the note editor, the document tag picker and Search.'"),
            (home, "ProjectHomeView", "project.home.title", "Project Home", "projectHome", "title: 'Project Home'"),
            (home, "ProjectHomeView", "project.home.missing.title", "No Project Selected", "projectHome", "missingTitle: 'No Project Selected'"),
            (home, "ProjectHomeView", "project.home.missing.detail", "Choose a project from the project picker to see its workspace.",
             "projectHome", "missingDetail: 'Choose a project from the project picker to see its workspace.'"),
            (home, "ProjectHomeView", "project.home.question.placeholder", "What is this project’s research question?", "projectHome",
             "questionPlaceholder: 'What is this project’s research question?'"),
            (home, "ProjectHomeView", "project.home.stat.collections", "Collections", "projectHome", "statCollections: 'Collections'"),
            (home, "ProjectHomeView", "project.home.stat.notes", "Notes", "projectHome", "statNotes: 'Notes'"),
            (home, "ProjectHomeView", "project.home.stat.visited", "Documents Visited", "projectHome", "statVisited: 'Documents Visited'"),
            (home, "ProjectHomeView", "project.home.stat.searches", "Searches Run", "projectHome", "statSearches: 'Searches Run'"),
            (home, "ProjectHomeView", "project.home.focus.title", "Focus subjects", "projectHome", "focusSubjects: 'Focus subjects'"),
            (home, "ProjectHomeView", "project.home.focus.add", "Add", "projectHome", "focusSubjectsAdd: 'Add'"),
            (home, "ProjectHomeView", "project.home.focus.edit", "Edit", "projectHome", "focusSubjectsEdit: 'Edit'"),
            (home, "ProjectHomeView", "project.home.focus.empty", "Choose subjects to focus discovery on the volumes they define.",
             "projectHome", "focusSubjectsEmpty: 'Choose subjects to focus discovery on the volumes they define.'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.title", "Focus Subjects", "projectHome", "focusSubjectsTitle: 'Focus Subjects'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.done", "Done", "projectHome", "focusSubjectsDone: 'Done'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.unavailable.title", "Subjects Unavailable", "projectHome",
             "focusSubjectsUnavailableTitle: 'Subjects Unavailable'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.unavailable.detail", "The subject index could not be loaded.", "projectHome",
             "focusSubjectsUnavailable: 'The subject index could not be loaded.'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.search", "Search subjects", "projectHome", "focusSubjectsSearch: 'Search subjects'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.selected", "Focus subjects", "projectHome", "focusSubjectsSelected: 'Focus subjects'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.suggested", "Suggested from your volumes", "projectHome",
             "focusSubjectsSuggested: 'Suggested from your volumes'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.suggested.detail",
             "Subjects that recur across the volumes you’ve already collected, annotated, or opened in this project.", "projectHome",
             "focusSubjectsSuggestedDetail: 'Subjects that recur across the volumes you’ve already collected, annotated, or opened in this project.'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.all", "All subjects", "projectHome", "focusSubjectsAll: 'All subjects'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.noMatches", "No subjects match.", "projectHome",
             "focusSubjectsNoMatches: 'No subjects match.'"),
            (focus, "ProjectFocusSubjectsEditor", "project.focus.volumeCount.one", "1 volume", "projectHome", "volumeCountOne: '1 volume'"),
            (home, "ProjectHomeView", "project.home.focusTags.title", "Focus tags", "projectHome", "focusTags: 'Focus tags'"),
            (home, "ProjectHomeView", "project.home.focusTags.add", "Add", "projectHome", "focusAdd: 'Add'"),
            (home, "ProjectHomeView", "project.home.focusTags.edit", "Edit", "projectHome", "focusEdit: 'Edit'"),
            (home, "ProjectHomeView", "project.home.focusTags.empty", "Choose tags whose documents should anchor this project’s suggestions.",
             "projectHome", "focusEmpty: 'Choose tags whose documents should anchor this project’s suggestions.'"),
            (home, "ProjectHomeView", "project.focusTags.title", "Focus Tags", "projectHome", "focusTagsTitle: 'Focus Tags'"),
            (home, "ProjectHomeView", "project.focusTags.empty.title", "No Tags", "projectHome", "focusTagsNoneTitle: 'No Tags'"),
            (home, "ProjectHomeView", "project.focusTags.footer", "Documents you’ve tagged with the chosen tags anchor this project’s Suggested Next.",
             "projectHome", "focusTagsFooter: 'Documents you’ve tagged with the chosen tags anchor this project’s Suggested Next.'"),
            (home, "ProjectHomeView", "project.focusTags.done", "Done", "projectHome", "focusTagsDone: 'Done'"),
            (home, "ProjectHomeView", "project.home.leads.title", "Suggested Next", "projectHome", "leadsTitle: 'Suggested Next'"),
            (home, "ProjectHomeView", "project.home.leads.placeholder",
             "As you add documents to this project’s collections, related documents you haven’t gathered yet will surface here.", "projectHome",
             "leadsPlaceholder: 'As you add documents to this project’s collections, related documents you haven’t gathered yet will surface here.'"),
            (home, "ProjectHomeView", "project.home.leads.new", "NEW", "projectHome", "leadNew: 'NEW'"),
            (home, "ProjectHomeView", "project.home.leads.related.one", "Related to 1 of your documents", "projectHome",
             "relatedOne: 'Related to 1 of your documents'"),
            (home, "ProjectHomeView", "project.home.leads.editorial", "Editorial note", "projectHome", "editorialNote: 'Editorial note'"),
            (home, "ProjectHomeView", "project.home.leads.dismiss.help", "Dismiss this lead", "projectHome", "dismiss: 'Dismiss this lead'"),
            (home, "ProjectHomeView", "project.home.recent.title", "Recent Activity", "projectHome", "recentTitle: 'Recent Activity'"),
            (home, "ProjectHomeView", "project.home.recent.documents", "Recently Read", "projectHome", "recentDocuments: 'Recently Read'"),
            (home, "ProjectHomeView", "project.home.recent.notes", "Recent Notes", "projectHome", "recentNotes: 'Recent Notes'"),
            (home, "ProjectHomeView", "project.home.recent.searches", "Recent Searches", "projectHome", "recentSearches: 'Recent Searches'"),
            (home, "ProjectHomeView", "project.home.search.untitled", "(no query text)", "projectHome", "untitledSearch: '(no query text)'"),
            (home, "ProjectHomeView", "project.home.action.research", "Research", "projectHome", "actionResearch: 'Research'"),
            (home, "ProjectHomeView", "project.home.action.search", "Search", "projectHome", "actionSearch: 'Search'"),
            (history, "HistoryView", "history.window.title", "History", "history", "title: 'History'"),
            (history, "HistoryView", "history.scope.label", "Project", "history", "scopeLabel: 'Project'"),
            (history, "HistoryView", "history.scope.all", "All Projects", "history", "scopeAll: 'All Projects'"),
            (history, "HistoryView", "history.scope.unfiled", "Not in a Project", "history", "scopeUnfiled: 'Not in a Project'"),
            (history, "HistoryView", "history.scope.help", "Show only history recorded while a specific project was active", "history",
             "scopeHelp: 'Show only history recorded while a specific project was active'"),
            (history, "HistoryView", "history.search.field", "Search history…", "history", "search: 'Search history…'"),
            (history, "HistoryView", "history.search.a11y", "Search history", "history", "searchA11y: 'Search history'"),
            (history, "HistoryView", "history.filtered.empty.title", "No Matches", "history", "filteredTitle: 'No Matches'"),
            (history, "HistoryView", "history.filtered.empty.detail", "No history matches the current filters.", "history",
             "filteredDetail: 'No history matches the current filters.'"),
            (history, "HistoryView", "history.section.documents", "Documents Visited", "history", "documents: 'Documents Visited'"),
            (history, "HistoryView", "history.documents.empty.title", "No Documents Visited", "history", "documentsEmptyTitle: 'No Documents Visited'"),
            (history, "HistoryView", "history.documents.empty.detail", "Documents you open will appear here.", "history",
             "documentsEmpty: 'Documents you open will appear here.'"),
            (history, "HistoryView", "history.section.searches", "Searches Executed", "history", "searches: 'Searches Executed'"),
            (history, "HistoryView", "history.searches.empty.title", "No Searches Executed", "history", "searchesEmptyTitle: 'No Searches Executed'"),
            (history, "HistoryView", "history.searches.empty.detail", "Searches you run will appear here.", "history",
             "searchesEmpty: 'Searches you run will appear here.'"),
            (history, "HistoryView", "history.section.exports", "Collections Exported", "history", "exports: 'Collections Exported'"),
            (history, "HistoryView", "history.exports.empty.title", "No Collections Exported", "history", "exportsEmptyTitle: 'No Collections Exported'"),
            (history, "HistoryView", "history.exports.empty.detail", "Collections you export will appear here.", "history",
             "exportsEmpty: 'Collections you export will appear here.'"),
            (history, "HistoryView", "history.logging.off",
             "Research logging is off, so new activity is not being recorded. Turn it back on in Settings under Research Sessions.", "history",
             "loggingOff: 'Research logging is off, so new activity is not being recorded. Turn it back on in Settings under Research Sessions.'"),
            (history, "HistoryView", "history.showMore", "Show More", "history", "showMore: 'Show More'"),
            (history, "HistoryView", "history.delete", "Delete", "history", "delete: 'Delete'"),
            (sessions, "ResearchSessionsView", "settings.pane.researchSessions", "Research Sessions", "sessions", "title: 'Research Sessions'"),
            (sessions, "ResearchSessionsView", "settings.sessions.recording.header", "Recording", "sessions", "recording: 'Recording'"),
            (sessions, "ResearchSessionsView", "settings.notes.logging", "Log Research Sessions", "sessions", "logging: 'Log Research Sessions'"),
            (sessions, "ResearchSessionsView", "settings.sessions.log", "Session Log", "sessions", "log: 'Session Log'"),
            (sessions, "ResearchSessionsView", "settings.sessions.activity.header", "Recorded Activity", "sessions", "activity: 'Recorded Activity'"),
            (sessions, "ResearchSessionsView", "settings.sessions.activity.footer.empty",
             "Nothing has been recorded yet. Open a document or run a search and it will appear here.", "sessions",
             "activityEmpty: 'Nothing has been recorded yet. Open a document or run a search and it will appear here.'"),
            (sessions, "ResearchSessionsView", "settings.sessions.manage.header", "Manage", "sessions", "manage: 'Manage'"),
            (sessions, "ResearchSessionsView", "settings.sessions.deleteAll", "Delete Recorded Sessions…", "sessions",
             "deleteAll: 'Delete Recorded Sessions…'"),
            (sessions, "ResearchSessionsView", "settings.sessions.delete.title", "Delete Recorded Sessions?", "sessions",
             "deleteTitle: 'Delete Recorded Sessions?'"),
            (summary, "ResearchSessionsSummary", "settings.sessions.log.empty", "Nothing recorded yet", "sessions", "nothingRecorded: 'Nothing recorded yet'"),
            (log, "SessionLogView", "sessionLog.empty.title", "No Sessions Yet", "sessions", "emptyTitle: 'No Sessions Yet'"),
            (log, "SessionLogView", "sessionLog.empty.detail.trail",
             "Your research activity will appear here as you open documents, run searches, and export collections.", "sessions",
             "emptyDetail: 'Your research activity will appear here as you open documents, run searches, and export collections.'"),
            (log, "SessionLogView", "sessionLog.showMore", "Show More", "sessions", "showMore: 'Show More'"),
            (log, "SessionLogView", "sessionLog.oldestPartial", "The oldest session listed may reach further back than the activity loaded.",
             "sessions", "oldestPartial: 'The oldest session listed may reach further back than the activity loaded.'"),
            (log, "SessionLogView", "sessionLog.ongoing", "Ongoing", "sessions", "ongoing: 'Ongoing'"),
            (export, "ResearchDataExportView", "settings.export.appendix.action", "Export Query Log as a Method Appendix", "dataSettings",
             "appendixAction: 'Export Query Log as a Method Appendix'"),
            (export, "ResearchDataExportView", "settings.export.appendix.empty", "No searches recorded yet.", "dataSettings",
             "appendixEmpty: 'No searches recorded yet.'"),
            (settings, "SettingsView", "settings.display.defaultMode.label", "Open Documents In", "reading", "openIn: 'Open Documents In'"),
            (settings, "SettingsView", "settings.display.defaultMode.a11y", "Default document mode", "reading", "openInA11y: 'Default document mode'"),
            (settings, "SettingsView", "settings.display.reading.header", "Reading", "reading", "title: 'Reading'"),
            (settings, "SettingsView", "settings.display.citationStyle.header", "Citations", "reading", "citations: 'Citations'"),
            (settings, "SettingsView", "settings.display.citationStyle.label", "Citation Style", "reading", "citationStyle: 'Citation Style'"),
            (settings, "SettingsView", "settings.display.citationStyle.footer", "Used when copying or sharing a citation.", "reading",
             "citationFooter: 'Used when copying or sharing a citation.'"),
            (models, "SearchModels", "search.checklist.loggingOff",
             "Opening a result does not hide it while Log Research Sessions is off in Settings. Mark Reviewed still hides a result.", "checklist",
             "loggingOff: 'Opening a result does not hide it while Log Research Sessions is off in Settings. Mark Reviewed still hides a result.'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(blocks[word.block]?.contains(word.web) == true, "copy.ts's \(word.block) block holds \(word.web)")
        }
        // The long sentences whose source spans its own lines, and the words with a count or a name.
        let sentences: [(source: String, file: String, text: String, block: String, web: String)] = [
            (sessions, "ResearchSessionsView", "Despite the name, this switch covers everything the app can track about your work.", "sessions",
             "loggingFooter: 'Despite the name, this switch covers everything the app can track about your work."),
            (sessions, "ResearchSessionsView", "The History screen, a project’s Recently Read and Recent Searches cards, its Documents Visited and Searches Run counts, and the Session Log all read those same records.",
             "sessions", "The History screen, a project’s Recently Read and Recent Searches cards, its Documents Visited and Searches Run counts, and the Session Log all read those same records."),
            (sessions, "ResearchSessionsView", "The app infers sessions from the times you opened documents, ran searches, and exported collections.",
             "sessions", "activityFooter: 'The app infers sessions from the times you opened documents, ran searches, and exported collections."),
            (sessions, "ResearchSessionsView", "This deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported.",
             "sessions", "manageFooter: 'This deletes the whole record of your work: every document you opened, every search you ran, and every collection you exported."),
            (sessions, "ResearchSessionsView", "%@ will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too.",
             "sessions", "`${events} will be permanently deleted from this device. If iCloud sync is on, the same records go from iCloud too."),
            (export, "ResearchDataExportView", "Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time.",
             "dataSettings", "appendixFooter: 'Every search you ran, in a Markdown table and a CSV. Each row gives the scope the search ran under and how many volumes were indexed at the time."),
            (settings, "SettingsView", "“Remember Last” reopens documents in the mode you used last, Read or Research.", "reading",
             "footer: '“Remember Last” reopens documents in the mode you used last, Read or Research."),
            (home, "ProjectHomeView", #"defaultValue: "From \(start, format: plain)")"#, "projectHome", "dateFrom: (year: number) => `From ${year}`"),
            (home, "ProjectHomeView", #"defaultValue: "Through \(end, format: plain)")"#, "projectHome", "dateTo: (year: number) => `Through ${year}`"),
            (home, "ProjectHomeView", #"defaultValue: "Related to \(n) of your documents")"#, "projectHome",
             "relatedMany: (count: number) => `Related to ${count.toLocaleString('en-US')} of your documents`"),
            (home, "ProjectHomeView", #"defaultValue: "\(search.resultCount) results")"#, "projectHome",
             "results: (count: number) => `${count.toLocaleString('en-US')} results`"),
            (focus, "ProjectFocusSubjectsEditor", #"String(localized: "project.focus.volumeCount.other", defaultValue: "\(subject.volumeCount) volumes")"#,
             "projectHome", "volumeCountOther: (count: number) => `${count.toLocaleString('en-US')} volumes`"),
            (merge, "ProjectContextView", #"defaultValue: "Merge “\(sourceProject.name)” into:")"#, "projects",
             "mergeInto: (name: string) => `Merge “${name}” into:`"),
            (merge, "ProjectContextView", #"defaultValue: "All notes, collections, summaries, and reading history assigned to “\(sourceProject.name)” will be re-assigned to the selected project. “\(sourceProject.name)” will be deleted.")"#,
             "projects", "`All notes, collections, summaries, and reading history assigned to “${name}” will be re-assigned to the selected project. “${name}” will be deleted.`"),
            (snapshot, "HistoryPaneSnapshot", #"String(localized: "history.showing %lld %lld", defaultValue: "Showing %lld of %lld")"#, "history",
             "showing: (shown: number, total: number) => `Showing ${shown} of ${total}`"),
            (history, "HistoryView", #"defaultValue: "\(row.resultCount) results")"#, "history",
             "resultCount: (count: number) => `${count.toLocaleString('en-US')} results`"),
            (history, "HistoryView", #"defaultValue: "\(row.documentCount) documents")"#, "history",
             "documentCount: (count: number) => `${count.toLocaleString('en-US')} documents`"),
            (summary, "ResearchSessionsSummary", #"defaultValue: "at least %lld sessions")"#, "sessions", "`at least ${count} sessions`"),
            (summary, "ResearchSessionsSummary", #"String(localized: "settings.sessions.count.many %lld", defaultValue: "%lld sessions")"#, "sessions", "`${count} sessions`"),
            (summary, "ResearchSessionsSummary", #"String(localized: "settings.sessions.events.many %lld", defaultValue: "%lld events")"#, "sessions",
             "eventCount: (count: number) => (count === 1 ? '1 event' : `${count} events`)"),
            (summary, "ResearchSessionsSummary", #"defaultValue: "last today \(last.formatted(date: .omitted, time: .shortened))")"#, "sessions",
             "lastToday: (time: string) => `last today ${time}`"),
            (summary, "ResearchSessionsSummary", #"defaultValue: "last \(last.formatted(date: .abbreviated, time: .omitted))")"#, "sessions",
             "lastOlder: (date: string) => `last ${date}`"),
            (log, "SessionLogView", #"defaultValue: "Showing the most recent %lld of %lld recorded activities.")"#, "sessions",
             "showingRecent: (shown: number, total: number) => `Showing the most recent ${shown} of ${total} recorded activities.`"),
            (log, "SessionLogView", #"String(localized: "sessionLog.search %@ %@", defaultValue: "“%1$@” — %2$@")"#, "sessions",
             "searchLine: (query: string, results: string) => `“${query}” — ${results}`"),
            (log, "SessionLogView", #"defaultValue: "%lld results")"#, "sessions", "(count === 1 ? '1 result' : `${count} results`)"),
            (log, "SessionLogView", #"defaultValue: "%lld documents")"#, "sessions", "(count === 1 ? '1 document' : `${count} documents`)"),
        ]
        for sentence in sentences {
            #expect(sentence.source.contains(sentence.text), "\(sentence.file) holds \(sentence.text)")
            #expect(blocks[sentence.block]?.contains(sentence.web) == true, "copy.ts's \(sentence.block) block holds \(sentence.web)")
        }
        // The kit's names for the citation styles, and the app's for the document modes.
        let styles = try Self.kit("FRUSCoreKit/Citation/CitationFormatter.swift")
        for (key, value) in [("historyAtState", "History at State (Recommended)"), ("chicago", "Chicago"), ("turabian", "Turabian")] {
            #expect(NoteViewParityTests.writes(styles, "citation.style.\(key)", value), "CitationFormatter names \(key) \(value)")
            #expect(blocks["reading"]?.contains("\(key): '\(value)'") == true)
        }
        let modes = try Self.app("Models/SupportingTypes.swift")
        NoteViewParityTests.expect(modes, holds: [#"case .read: return "Read""#, #"case .research: return "Research""#,
                                                  #"case .rememberLast: return "Remember Last""#], file: "SupportingTypes.swift")
        #expect(blocks["reading"]?.contains("modes: { read: 'Read', research: 'Research', rememberLast: 'Remember Last' }") == true)
    }

    /// The reader's own order, the History screen's filter, Project Home's and "Working on:"'s lines and
    /// the checklist's, as the app's source writes them and the web's mirrors say them, with the kit's
    /// quotation marks.
    @Test func theListsRulesAreTheApps() throws {
        NoteViewParityTests.expect(try Self.app("Models/ListOrderPreferences.swift"), holds: [
            "let rank = Dictionary(order.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })",
            "let named = items.filter { rank[id($0)] != nil } .sorted { (rank[id($0)] ?? 0) < (rank[id($1)] ?? 0) }",
            "let rest = items.filter { rank[id($0)] == nil }", "return named + rest",
            "case .toTop: guard index > 0 else { return nil } ids.remove(at: index) ids.insert(id, at: 0)",
            "case .up: guard index > 0 else { return nil } ids.swapAt(index, index - 1)",
            "case .down: guard index < ids.count - 1 else { return nil } ids.swapAt(index, index + 1)",
            "var tags: [UUID] = []", "var projects: [UUID] = []",
        ], file: "ListOrderPreferences.swift")
        NoteViewParityTests.expect(try Self.web("research/listOrder.ts"), holds: [
            "if (!rank.has(upper)) rank.set(upper, place);", "return [...named, ...items.filter((item) => !rank.has(id(item).toUpperCase()))];",
            "case 'toTop': if (index === 0) return undefined;", "case 'down': if (index === ids.length - 1) return undefined;",
        ], file: "listOrder.ts")
        NoteViewParityTests.expect(try Self.app("Models/HistoryPaneSnapshot.swift"), holds: [
            "return title.localizedStandardContains(term) || volumeId.localizedStandardContains(term) || documentId.localizedStandardContains(term)",
            "return FTS5InlineQueryParser.normalizingQuotationMarks(queryText) .localizedStandardContains(FTS5InlineQueryParser.normalizingQuotationMarks(term))",
            "return title.localizedStandardContains(term) || format.localizedStandardContains(term) || formatDisplayName.localizedStandardContains(term)",
            "let trimmed = term.trimmingCharacters(in: .whitespaces)", "static let defaultPageLimit = 500", "static let pageIncrement = 500",
            "guard shown < total else { return nil }",
        ], file: "HistoryPaneSnapshot.swift")
        NoteViewParityTests.expect(try Self.web("research/historyRules.ts"), holds: [
            "return term === '' || holds(row.title, term) || holds(row.volumeId, term) || holds(row.documentId, term);",
            "return term === '' || holds(normalizingQuotationMarks(row.queryText), normalizingQuotationMarks(term));",
            "return term === '' || holds(row.title, term) || holds(row.format, term) || holds(row.formatName, term);",
            "return shown < total ? copy.history.showing(shown, total) : undefined;",
            #"const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;"#, "return scope !== 'all' || trimmed(query) !== '';",
        ], file: "historyRules.ts")
        NoteViewParityTests.expect(try Self.app("History/HistoryView.swift"), holds: [
            "scope != .all || !query.trimmingCharacters(in: .whitespaces).isEmpty",
        ], file: "HistoryView.swift")
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectHomeView.swift"), holds: [
            "let cal = Calendar.current func year(_ date: Date?) -> Int? { date.map { cal.component(.year, from: $0) } }",
            #"case let (start?, end?): return "\(start)–\(end)""#,
            #"case let (start?, nil): return String(localized: "project.home.dateFrom", defaultValue: "From \(start, format: plain)")"#,
            #"case let (nil, end?): return String(localized: "project.home.dateTo", defaultValue: "Through \(end, format: plain)")"#,
            "case (nil, nil): return nil",
            "guard effectiveIsEditorialNote(for: lead) else { return related }",
            #"return related + " · " + String(localized: "project.home.leads.editorial", defaultValue: "Editorial note")"#,
        ], file: "ProjectHomeView.swift")
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectPickerMenu.swift"), holds: [
            "guard let pid = activeProjectId, let project = projects.first(where: { $0.id == pid }),",
            "let question = project.researchQuestion?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty else { return nil }",
        ], file: "ProjectPickerMenu.swift")
        NoteViewParityTests.expect(try Self.web("research/projectRules.ts"), holds: [
            "return Number.isNaN(time.getTime()) ? undefined : time.getFullYear();",
            "if (start !== undefined && end !== undefined) return `${start}–${end}`;",
            "if (start !== undefined) return copy.projectHome.dateFrom(start);", "if (end !== undefined) return copy.projectHome.dateTo(end);",
            #"const whitespacesAndNewlines = /^[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+|[\t\n\v\f\r\u{0085}\u{2028}\u{2029}\p{Zs}]+$/gu;"#,
            "const project = projects.find((item) => item.id.toUpperCase() === activeProjectId.toUpperCase());",
            "const question = trimmedQuestion(project?.researchQuestion ?? ''); return question === '' ? undefined : question;",
            "const related = lead.relatedCount === 1 ? copy.projectHome.relatedOne : copy.projectHome.relatedMany(lead.relatedCount);",
            "return lead.isEditorialNote ? `${related} · ${copy.projectHome.editorialNote}` : related;",
        ], file: "projectRules.ts")
        NoteViewParityTests.expect(try Self.web("research/ProjectHomeScreen.tsx"), holds: [
            "const trimmed = trimmedQuestion(text); if (trimmed === saved.current) return;",
        ], file: "ProjectHomeScreen.tsx")
        NoteViewParityTests.expect(try Self.app("Search/SearchModels.swift"), holds: [
            "guard checklistMode, !loggingEnabled else { return nil }",
        ], file: "SearchModels.swift")
        NoteViewParityTests.expect(try Self.web("search/SearchScreen.tsx"), holds: [
            "loggingNotice: logging ? undefined : copy.checklist.loggingOff,",
        ], file: "SearchScreen.tsx")
        NoteViewParityTests.expect(try Self.web("api/research.ts"), holds: [
            "export const historyPageLimit = 500;", "export const historyPageIncrement = 500;",
            "export const sessionLogLimit = 1000;", "export const sessionLogIncrement = 1000;",
        ], file: "research.ts")
        #expect(SessionLogSnapshot.defaultPageLimit == 1_000 && SessionLogSnapshot.pageIncrement == 1_000)
        #expect(HistoryRoutes.defaultPageLimit == 500 && HistoryRoutes.pageIncrement == 500)
        // The marks the kit folds, the web's list of them.
        let parser = try Self.kit("FTS5Store/FTS5InlineQueryParser.swift")
        #expect(parser.contains(#"private static let typographicDoubleQuotationMarks: Set<Character> = [ "\u{201C}", "\u{201D}", "\u{201E}", "\u{201F}", "\u{FF02}", "\u{00AB}", "\u{00BB}", ]"#))
        #expect(try Self.web("research/historyRules.ts").contains(
            #"export const typographicDoubleQuotationMarks = ['\u201C', '\u201D', '\u201E', '\u201F', '\uFF02', '\u00AB', '\u00BB'];"#))
    }

    /// Project Home's focus subjects (S25c), as the app's source writes them and the web's mirrors say
    /// them: the section's filter of the vocabulary and its Add or Edit; the editor's three sections,
    /// when each shows, its search, its rows and its toggle; the volumes its suggestions start from, the
    /// app's `ProjectEngagedDocuments` and not the coverage tiles' gatherer; the kit's suggestions, with
    /// the dictionary by ref that a repeated ref would trap on, which the server refuses to load; a
    /// lead's line; and the head a visit to a document the index does not hold is titled by.
    @Test func theFocusSubjectsRulesAreTheApps() throws {
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectHomeView.swift"), holds: [
            "if let profiles = VolumeSubjectProfilesStore.shared {", "let chosen = project.defaultSubjectTagIds",
            "let subjects = profiles.allSubjects.filter { chosen.contains($0.ref) }",
            #"Label(subjects.isEmpty ? String(localized: "project.home.focus.add", defaultValue: "Add") : String(localized: "project.home.focus.edit", defaultValue: "Edit"),"#,
            "if subjects.isEmpty {", "ForEach(subjects) { subject in Text(subject.name)",
            "focusSubjectsSection(project) focusTagsSection(project) leadsSection",
            "guard !keys.isEmpty, let pipeline = appState.indexingPipeline else { leadSnippets = [:] return }",
            "leadSnippets = (try? await pipeline.documentSnippets(forKeys: keys)) ?? [:]",
            "if let snippet = leadSnippets[lead.documentKey], !snippet.isEmpty { Text(snippet) .font(.caption) .foregroundStyle(.tertiary) .lineLimit(3)",
        ], file: "ProjectHomeView.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/ProjectFocus.swift"), holds: [
            "profiles.allSubjects.filter { chosen.contains($0.ref) }.map(FocusSubject.init)",
            "ProjectFocusSuggestions.suggestions(engagedVolumeIds: engagedVolumeIds, profiles: profiles, excluding: Set(chosen))",
        ], file: "ProjectFocus.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/ProjectHome.swift"), holds: [
            "if let profiles = resources.subjectProfiles.profiles {",
            "let lines = (try? await served.pipeline.documentSnippets(forKeys: keys)) ?? [:]",
            "if let line = lines[ProjectFocusRoutes.key(lead.volumeId, lead.documentId)], !line.isEmpty { lead.snippet = line }",
        ], file: "ProjectHome.swift")
        NoteViewParityTests.expect(try Self.web("research/ProjectHomeScreen.tsx"), holds: [
            "{home.focusSubjects && <FocusSubjects home={home} />} {home.hasTags && <FocusTags home={home} />}",
            "{lead.snippet && <span className=\"lead-snippet\">{lead.snippet}</span>}",
        ], file: "ProjectHomeScreen.tsx")
        NoteViewParityTests.expect(try Self.web("research/FocusSubjects.tsx"), holds: [
            "{subjects.length === 0 ? copy.projectHome.focusSubjectsAdd : copy.projectHome.focusSubjectsEdit}",
            "{refs.length > 0 && (", "subjects={chosenSubjects(all, refs)}", "{showsSuggestions(search, suggested) && (",
            "subjects={filteredSubjects(all, search)}", "empty={copy.projectHome.focusSubjectsNoMatches}",
            "const next = toggledSubjects(latest.current ?? cachedRefs(client, projectId) ?? stored, ref);",
            "await updateProject(client, projectId, { defaultSubjectTagIds: [...sent] });",
            "const subjects = vocabulary.data ? chosenSubjects(vocabulary.data.items, chosen.refs) : (home.focusSubjects ?? []);",
        ], file: "FocusSubjects.tsx")
        // The editor's sections, search, rows and toggle.
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectFocusSubjectsEditor.swift"), holds: [
            "let chosen = Set(project.defaultSubjectTagIds)",
            "let suggestions = ProjectFocusSuggestions.suggestions(engagedVolumeIds: engagedVolumeIds, profiles: profiles, excluding: chosen)",
            "if !chosen.isEmpty {", "ForEach(profiles.allSubjects.filter { chosen.contains($0.ref) }) { subject in subjectRow(subject, isSelected: true, project: project)",
            "if searchText.isEmpty && !suggestions.isEmpty {", "ForEach(suggestions) { subject in subjectRow(subject, isSelected: false, project: project)",
            "let matches = filteredSubjects(profiles) if matches.isEmpty {",
            "subjectRow(subject, isSelected: chosen.contains(subject.ref), project: project)",
            "let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()",
            "guard !query.isEmpty else { return Array(profiles.allSubjects.prefix(50)) }",
            "$0.name.lowercased().contains(query) || $0.category.lowercased().contains(query) || $0.subcategory.lowercased().contains(query)",
            #"Text("\(subject.category) · \(subject.subcategory)")"#, "Text(subject.volumeCount == 1",
            "var ids = project.defaultSubjectTagIds if let index = ids.firstIndex(of: ref) { ids.remove(at: index) } else { ids.append(ref) } project.defaultSubjectTagIds = ids",
            "engagedVolumeIds = await ProjectEngagedDocuments.engagedVolumeIds( forProject: projectId, container: modelContext.container)",
        ], file: "ProjectFocusSubjectsEditor.swift")
        NoteViewParityTests.expect(try Self.web("research/focusSubjectRules.ts"), holds: [
            "export const unsearchedSubjectLimit = 50;", #"const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;"#,
            "return subjects.filter((subject) => chosen.includes(subject.ref));", "return search === '' && suggestions.length > 0;",
            "const query = search.replace(whitespaces, '').toLowerCase();", "if (query === '') return subjects.slice(0, unsearchedSubjectLimit);",
            "subject.name.toLowerCase().includes(query) || subject.category.toLowerCase().includes(query) || subject.subcategory.toLowerCase().includes(query),",
            "return `${subject.category} · ${subject.subcategory}`;",
            "return subject.volumeCount === 1 ? copy.projectHome.volumeCountOne : copy.projectHome.volumeCountOther(subject.volumeCount);",
            "return index >= 0 ? [...refs.slice(0, index), ...refs.slice(index + 1)] : [...refs, ref];",
        ], file: "focusSubjectRules.ts")
        // The same trim as the History screen's filter, `.whitespaces`.
        #expect(try Self.web("research/historyRules.ts").contains(#"const whitespaces = /^[\t\p{Zs}]+|[\t\p{Zs}]+$/gu;"#))
        // The volumes the suggestions start from.
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectEngagedDocuments.swift"), holds: [
            #""\(volumeId)/\(documentId)""#,
            "for note in notes where !note.volumeId.isEmpty && !note.documentId.isEmpty { result.insert(key(note.volumeId, note.documentId)) }",
            "for visit in visits where !visit.volumeId.isEmpty && !visit.documentId.isEmpty { result.insert(key(visit.volumeId, visit.documentId)) }",
            "for entry in collection.documentEntries ?? [] where entry.kind == CollectionEntryKind.document.rawValue && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {",
            ".filter { $0.projectIds.contains(pid) } let collections = ((try? context.fetch(FetchDescriptor<Collection>())) ?? []) .filter { $0.projectIds.contains(pid) }",
            "predicate: #Predicate { $0.projectId == pid }",
            #"return Set(keys.compactMap { $0.split(separator: "/", maxSplits: 1).first.map(String.init) })"#,
        ], file: "ProjectEngagedDocuments.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/ProjectFocus.swift"), holds: [
            #""\(volumeId)/\(documentId)""#,
            "for note in notes where !note.volumeId.isEmpty && !note.documentId.isEmpty { result.insert(key(note.volumeId, note.documentId)) }",
            "for visit in visits where !visit.volumeId.isEmpty && !visit.documentId.isEmpty { result.insert(key(visit.volumeId, visit.documentId)) }",
            "where (entry.kind ?? CollectionEntryKind.document.rawValue) == CollectionEntryKind.document.rawValue && !entry.volumeId.isEmpty && !entry.documentId.isEmpty {",
            #"Set(keys.compactMap { $0.split(separator: "/", maxSplits: 1).first.map(String.init) })"#,
        ], file: "ProjectFocus.swift")
        // Over the project's own records, as the app's fetches filter them: Project Home's summary's.
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/ProjectHome.swift"), holds: [
            "notes: newestFirst(notes.filter { $0.projectIds.contains(id) }) { $0.lastModified },",
            "collections: newestFirst(collections.filter { $0.projectIds.contains(id) }) { $0.lastModified },",
            "visits: newestFirst(visits.filter { $0.projectId == id }) { $0.accessedAt },",
            "let engaged = ProjectFocusRoutes.engagedKeys(collections: summary.collections, notes: summary.notes, visits: summary.visits)",
        ], file: "ProjectHome.swift")
        // The kit's suggestions: eight at most, and the dictionary by ref that traps on a repeated one.
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/ProjectContext/ProjectFocusSuggestions.swift"), holds: [
            "excluding chosen: Set<String>, limit: Int = 8) -> [VolumeSubjectProfiles.SubjectOption] {",
            "let byRef = Dictionary(uniqueKeysWithValues: profiles.allSubjects.map { ($0.ref, $0) })",
        ], file: "ProjectFocusSuggestions.swift")
        // The app's loader: none for a file missing or malformed.
        NoteViewParityTests.expect(try Self.app("Browser/VolumeSubjectProfilesStore.swift"), holds: [
            #"guard let url = Bundle.main.url(forResource: "volume-subject-profiles-index", withExtension: "json") else {"#,
            "return try JSONDecoder().decode(VolumeSubjectProfiles.self, from: data)",
        ], file: "VolumeSubjectProfilesStore.swift")
        // A visit's head, from the parsed TEI, as the app's reader titles a document it loaded.
        NoteViewParityTests.expect(try Self.app("DocumentView/DocumentViewModel.swift"), holds: [
            "let extracted = IndexingPipeline.extractHeader(from: ast.nodes)",
            "let isEditorialNote: Bool = { if case .editorialNote? = ast.nodes.first { return true } return false }()",
            "if !extracted.isEmpty || isEditorialNote { documentTitle = DocumentDisplayTitle.text( .init(header: extracted.isEmpty ? nil : extracted, documentNumber: resolvedDocumentNumber, isEditorialNote: isEditorialNote), documentId: entry.documentId)",
            "resolvedDocumentNumber = ast.printedNumber ?? IndexingPipeline.extractDocumentNumber(from: ast.nodes)",
            // A document the parse gives no title keeps the one it was opened with, through the display rule.
            "if let documentTitle, !documentTitle.isEmpty { return documentTitle } return ReadingHistoryTitle.documentTitle(stored: entry.header,",
        ], file: "DocumentViewModel.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/History.swift"), holds: [
            "let extracted = IndexingPipeline.extractHeader(from: ast.nodes) let isEditorialNote = ast.isShapedAsEditorialNote",
            "guard !extracted.isEmpty || isEditorialNote else { return nil }",
            "if let title = parsedTitle(of: ast) { return title }",
            "return ReadingHistoryTitle.documentTitle(stored: label == documentId ? nil : label,",
            "return displayTitle(header: extracted, documentNumber: ast.printedNumber, isEditorialNote: isEditorialNote, documentId: ast.documentId)",
        ], file: "History.swift")
        NoteViewParityTests.expect(try Self.kit("FRUSCoreKit/TEI/FRUSASTNode.swift"), holds: [
            "public var isShapedAsEditorialNote: Bool { guard let first = nodes.first, case .editorialNote = first else { return false } return true }",
        ], file: "FRUSASTNode.swift")
    }

    /// What the server mirrors of the app's views and services: Project Home's summary, leads and
    /// coverage, a visit's title, an export's format, the search trail's writer, the trail's loaders,
    /// the appendix's coverage, the editor's save, the admin's merge and the preferences' initial values.
    @Test func theServersMirrorsAreTheApps() throws {
        let home = try Self.app("ProjectContext/ProjectHomeView.swift")
        NoteViewParityTests.expect(home, holds: [
            #"@Query(sort: \ProjectLeadEntry.aggregateScore, order: .reverse) private var allLeads: [ProjectLeadEntry]"#,
            "allLeads.filter { $0.projectId == projectId && !$0.dismissed }",
            "lead.firstSurfacedAt > Date.now.addingTimeInterval(-7 * 24 * 3600)",
            ".foregroundStyle(entry.isMeaningCapture ? Color.secondary : Color.orange)",
            "Text(lead.header.isEmpty ? lead.documentKey : lead.header)",
            "let searched = Set(summary.searches.compactMap(\\.appliedCorpusId))",
            "let isOpenedComplete = AppState.isResearchLoggingEnabled",
            "let trimmed = questionDraft.trimmingCharacters(in: .whitespacesAndNewlines) let newValue = trimmed.isEmpty ? nil : trimmed",
            "if !allTags.isEmpty {", #"@Query(sort: \UserTag.name) private var allTags: [UserTag]"#,
            #"@Query(sort: \ResearchNote.lastModified, order: .reverse) private var allNotes: [ResearchNote]"#,
            #"@Query(sort: \ReadingHistoryEntry.accessedAt, order: .reverse) private var allVisits: [ReadingHistoryEntry]"#,
        ], file: "ProjectHomeView.swift")
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectHomeSummary.swift"), holds: [
            "static let recentLimit = 5", "Set(visits.map { Self.key($0.volumeId, $0.documentId) }).count",
            "notes.isEmpty && collections.isEmpty && visits.isEmpty && searches.isEmpty",
        ], file: "ProjectHomeSummary.swift")
        #expect(ProjectHomeRoutes.Summary.recentLimit == 5)
        NoteViewParityTests.expect(try Self.app("Models/HistoryPaneSnapshot.swift"), holds: [
            "guard let stored, !stored.isEmpty else { return nil }", "if let volumeTitle, stored == volumeTitle { return nil }",
            "if stored == identifier(volumeId: volumeId, documentId: documentId) { return nil }", #""\(volumeId) · \(documentId)""#,
            #"return String(localized: "history.exports.format.zoteroAPI", defaultValue: "Zotero (web)")"#,
        ], file: "HistoryPaneSnapshot.swift")
        let formats = try Self.app("Collections/CollectionExporter+App.swift")
        for (raw, name) in ExportFormatName.names {
            #expect(formats.contains("case \(raw)"), "ExportFormat has \(raw)")
            #expect(formats.contains(#"case .\#(raw): return "\#(name)""#) || formats.contains(#"defaultValue: "\#(name)")"#),
                    "ExportFormat names \(raw) \(name)")
        }
        #expect(ExportFormatName.displayName("zotero-api") == "Zotero (web)" && ExportFormatName.displayName("later") == "later")
        NoteViewParityTests.expect(try Self.app("DocumentView/DocumentViewModel.swift"), holds: [
            "guard AppState.isResearchLoggingEnabled(in: defaults) else {", "if let documentTitle, !documentTitle.isEmpty { return documentTitle }",
            "if !extracted.isEmpty || isEditorialNote { documentTitle = DocumentDisplayTitle.text(",
        ], file: "DocumentViewModel.swift")
        NoteViewParityTests.expect(try Self.app("Search/SearchHistoryWriter.swift"), holds: [
            "return FTS5InlineQueryParser.normalizingQuotationMarks(anchored) == FTS5InlineQueryParser.normalizingQuotationMarks(query)",
            "guard !reading.queryText.isEmpty, !reading.hasError else { return .skipped }",
            "row.queryText = reading.queryText", "row.executedAt = .now", "?? SearchScopeSignature.signature(for: reading.parameters)",
        ], file: "SearchHistoryWriter.swift")
        NoteViewParityTests.expect(try Self.app("App/MacSearchViewModel.swift"), holds: [
            "loadedCount: results.count,", "fetchLimit: lastFetchLimit,", "renderedExpression: lastRenderedExpression,",
            "async let expressionTask = try? service.matchExpressions(for: frozenParams).corpus",
            "queryText: submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines),",
        ], file: "MacSearchViewModel.swift")
        #expect(HistoryRoutes.isSameQuery("\u{201C}cold war\u{201D}", "\"cold war\"") && !HistoryRoutes.isSameQuery("'cold war'", "\"cold war\""))
        #expect(!HistoryRoutes.isSameQuery(nil, "x"))
        NoteViewParityTests.expect(try Self.app("Models/ResearchTrailSessions+App.swift"), holds: [
            "guard let at = visit.accessedAt else { continue }", "guard let at = query.executedAt else { continue }",
            "guard let at = export.exportedAt else { continue }", "return newestFirst(merged, limit: limit)",
        ], file: "ResearchTrailSessions+App.swift")
        NoteViewParityTests.expect(try Self.app("Models/ResearchSessionsSummary.swift"), holds: [
            "isSessionCountExact: activities.count < activityScanLimit)", "eventCount: ResearchTrailSessions.totalActivityCount(in: context),",
            "static let activityScanLimit = SessionLogSnapshot.defaultPageLimit",
        ], file: "ResearchSessionsSummary.swift")
        NoteViewParityTests.expect(try Self.app("ProjectContext/SessionLogView.swift"), holds: [
            #"if interval < 60 { return "\(Int(interval))s" }"#, #"} else if interval < 3_600 { return "\(Int(interval / 60))m" }"#,
            "let what = collectionName ?? format",
        ], file: "SessionLogView.swift")
        NoteViewParityTests.expect(try Self.app("Export/ResearchDataExporter.swift"), holds: [
            ".filter { projectId == nil || $0.projectId == projectId }",
            "let isOpenedComplete = AppState.isResearchLoggingEnabled",
        ], file: "ResearchDataExporter.swift")
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectEditorView.swift"), holds: [
            "let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)",
            "project.researchQuestion = trimmedQ.isEmpty ? nil : trimmedQ", "appState.activeProjectId = project.id",
        ], file: "ProjectEditorView.swift")
        NoteViewParityTests.expect(try Self.app("ProjectContext/ProjectAdminService.swift"), holds: [
            "var ids = note.projectIds.filter { $0 != sourceId } if !ids.contains(targetId) { ids.append(targetId) }",
            "for id in plan.projectIds.map({ $0 == sourceId ? targetId : $0 }) where !ids.contains(id) {",
            "summary.projectId = targetId", "if appState.activeProjectId == sourceId { appState.activeProjectId = targetId }",
            "if appState.activeProjectId == project.id { appState.activeProjectId = nil }",
        ], file: "ProjectAdminService.swift")
        // The record a user who has set nothing reads, `SyncedPreferences()`.
        NoteViewParityTests.expect(try Self.app("Models/SyncedPreferences.swift"), holds: [
            "var wcMinLength: Int = 3", "var wcMinCount: Int = 1", "var wcFoldPlurals: Bool = true", "var wcFilterMarkings: Bool = true",
            "var wcExcludeBoilerplate: Bool = true", #"var wcGlobalStopwordsJSON: String = """#, #"var wcLensStopwordsJSON: String = """#,
            #"var citationStyleRaw: String = """#, #"var defaultDocumentModeRaw: String = """#, "var researchLoggingEnabled: Bool = true",
            #"var listOrderJSON: String = """#,
        ], file: "SyncedPreferences.swift")
        let initial = PreferenceRoutes.initial(at: Date(timeIntervalSince1970: 0))
        #expect(initial.wcMinLength == 3 && initial.wcMinCount == 1 && initial.wcFoldPlurals && initial.wcFilterMarkings
                && initial.wcExcludeBoilerplate && initial.wcGlobalStopwordsJSON.isEmpty && initial.wcLensStopwordsJSON.isEmpty
                && initial.citationStyleRaw.isEmpty && initial.defaultDocumentModeRaw.isEmpty && initial.researchLoggingEnabled
                && initial.listOrderJSON.isEmpty)
        NoteViewParityTests.expect(try Self.app("Models/SupportingTypes.swift"), holds: [
            "case read", "case research", "case rememberLast",
        ], file: "SupportingTypes.swift")
        #expect(PreferenceRoutes.documentModes == ["read", "research", "rememberLast"])
        let order = ListOrder(tags: [UUID(uuidString: "5E17F000-0000-4000-8000-0000000000A1")!], projects: [])
        #expect(order.encoded == #"{"tags":["5E17F000-0000-4000-8000-0000000000A1"],"projects":[]}"#)
        #expect(ListOrder.decode(order.encoded) == order && ListOrder.decode(#"{"tags":[]}"#) == nil && ListOrder.decode("") == nil)
    }
}
