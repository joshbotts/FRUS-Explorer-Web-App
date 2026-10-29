// PLAN's S18f done-when, over the kit's own index of the three fixture volumes with their TEI mounted:
// each `.fruscollection` file the server writes is the kit's to the byte, `NativeCollectionSerializer`'s
// of the collection as the user's JSON export records it, with and without the notes, which the app's
// sheet resolves; each file imports as the kit reads it, and its export again is the same file; a smart
// collection's exports and previews, capped and whole, are the kit's for its saved search's results over
// the same index; and a snapshot is the kit's of them. The second and third tests hold the app code the
// server and the browser app mirror, and the app's words they take, to the app's source.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FRUSParity
import FRUSRichText
import Foundation
import Hummingbird
import HummingbirdTesting
import Testing

@testable import FRUSLightAPI

@Suite struct CollectionFileParityTests {
    typealias Session = CollectionExportParityTests.Session
    static let kennedy = CollectionExportParityTests.kennedy
    static let sahara = CollectionExportParityTests.sahara

    static func json(_ object: [String: Any?]) throws -> String { try CollectionExportParityTests.json(object) }

    @Test func eachFileAndEachSmartExportAreTheKitsByteForByte() async throws {
        try await ServedFixture.run { client, files in
            let session = try await Session.open(client)
            let base = "/api/v1/me/collections"
            let project = try await session.json(Project.self, .post, "/api/v1/me/projects", ["name": "Vienna"])

            // A collection with every kind of entry and every part of a file: sections two deep, documents of two
            // volumes with overrides, a title override and a headnote, a note block in rich text, an excerpt, two
            // apparatus blocks, the title page, the introduction and the colophon; and notes, one document's all,
            // another's chosen.
            let rich = try await session.json(CollectionDetail.self, .post, base, ["name": "Letters, shared"])
            let path = "\(base)/\(rich.id)"
            _ = try await session.send(.patch, path, try Self.json([
                "subtitle": "A reader", "authorLine": "A. Historian", "includeColophon": true, "applyHighlights": true,
                "includeSourceNote": true, "tocStyle": "headerAndDateline", "defaultIncludeHeadnote": true,
                "introductionText": "An introduction, in part bold.",
                "introductionRuns": [CollectionExportParityTests.run("An introduction, "), CollectionExportParityTests.run("in part bold.", bold: true)],
            ]))
            let heading = try await session.json(CollectionEdit.self, .post, "\(path)/blocks", ["kind": "heading"])
            _ = try await session.send(.patch, "\(path)/entries/\(heading.entryIds[0])", try Self.json(["text": "The first letters"]))
            let letters = try await session.json(CollectionEdit.self, .post, "\(path)/documents",
                                                 CollectionExportParityTests.documents(Self.kennedy, ["d1", "d2", "d3"]))
            let prose = try await session.json(CollectionEdit.self, .post, "\(path)/blocks", ["kind": "prose"])
            _ = try await session.send(.patch, "\(path)/entries/\(prose.entryIds[0])", try Self.json([
                "text": "Read these together.",
                "runs": [CollectionExportParityTests.run("Read these "), CollectionExportParityTests.run("together", italic: true),
                         CollectionExportParityTests.run(".")],
            ]))
            let v2 = try await session.version(Self.kennedy, "d2")
            _ = try await session.send(.post, "\(path)/excerpts", try Self.json([
                "volumeId": Self.kennedy, "documentId": "d2", "startOffset": 200, "endOffset": 340, "renderingVersion": v2,
            ]))
            let later = try await session.json(CollectionEdit.self, .post, "\(path)/blocks", ["kind": "heading"])
            _ = try await session.send(.patch, "\(path)/entries/\(later.entryIds[0])", try Self.json(["text": "Elsewhere", "bodyDepthOverride": "index"]))
            _ = try await session.send(.post, "\(path)/entries/\(later.entryIds[0])/indent")
            _ = try await session.send(.post, "\(path)/documents", try Self.json(CollectionExportParityTests.documents(Self.sahara, ["d87"])))
            for type in ["chronology", "bibliography"] {
                _ = try await session.send(.post, "\(path)/blocks", try Self.json(["generatedBlockType": type]))
            }
            _ = try await session.send(.patch, "\(path)/entries/\(letters.entryIds[0])", try Self.json([
                "titleOverride": "The first letter", "includeRelatedDocuments": true, "includeFootnotesOverride": false,
            ]))
            func note(_ document: String, _ text: String) async throws -> Note {
                try await session.json(Note.self, .post, "/api/v1/me/volumes/\(Self.kennedy)/documents/\(document)/notes",
                                       ["bodyText": text, "runs": nil, "userTagIds": [], "projectIds": [], "selectedSummaryIds": []])
            }
            _ = try await note("d1", "Read beside the second letter.")
            // A second apart, as the JSON export the reference reads writes its times to the second, and a
            // document's every note is the app's `allNotes` order, the last changed first.
            _ = try await note("d2", "The second letter's first note.")
            try await Task.sleep(for: .milliseconds(1_100))
            let leftOut = try await note("d2", "A note left out.")
            try await Task.sleep(for: .milliseconds(1_100))
            _ = try await note("d2", "The second letter's second note.")
            _ = try await session.send(.patch, "\(path)/entries/\(letters.entryIds[1])", try Self.json(["note": ["id": leftOut.id, "included": false]]))

            // A smart collection of a saved search past the preview's cap, with two apparatus blocks, one of whose
            // results only a note of the user's finds; and a plain one.
            _ = try await session.json(Note.self, .post, "/api/v1/me/volumes/frus1894Nicaragua/documents/d1/notes",
                                       ["bodyText": "Compare the Vienna talks.", "runs": nil, "userTagIds": [], "projectIds": [], "selectedSummaryIds": []])
            let saved = try await session.json(SavedSearch.self, .post, "/api/v1/me/saved-searches",
                                               ["name": "Vienna", "search": "keywords=vienna&includeNotes=true"])
            let smart = try await session.json(CollectionDetail.self, .post, base, ["name": "Vienna, as searched"])
            for type in ["chronology", "personsIndex"] {
                _ = try await session.send(.post, "\(base)/\(smart.id)/blocks", try Self.json(["generatedBlockType": type]))
            }
            _ = try await session.send(.patch, "\(base)/\(smart.id)", try Self.json(["savedSearchId": saved.id, "includeNotes": false]))
            let plain = try await session.json(CollectionDetail.self, .post, base, ["name": "Two letters"])
            _ = try await session.send(.post, "\(base)/\(plain.id)/documents", try Self.json(CollectionExportParityTests.documents(Self.kennedy, ["d1", "d2"])))

            let active = try ServedFixture.decode(ProjectList.self, try await session.get("/api/v1/me/projects")).activeProjectId
            #expect(active == project.id)
            var kit = try await KitReference(files: files, session: session, activeProject: active)

            // The native file, the kit's to the byte, with and without the notes.
            var written: [String: Data] = [:]
            for collection in [rich.id, plain.id] {
                for includeNotes in [false, true] {
                    let served = Data(buffer: try await session.send(.post, "\(base)/\(collection)/export",
                                                                     try Self.json(["format": "fruscollection", "includeNotes": includeNotes])).body)
                    let theirs = try kit.nativeFile(collection, includeNotes: includeNotes)
                    #expect(served == theirs, "\(collection)'s file, notes \(includeNotes): \(served.count) bytes, the kit's \(theirs.count)")
                    if includeNotes { written[collection] = served }
                }
            }
            let shared = try NativeCollectionSerializer.decode(try #require(written[rich.id]))
            // The chronology at the front, as the kit places it.
            #expect(shared.formatVersion == 2 && shared.entries.map(\.kind)
                == ["generated", "heading", "document", "document", "document", "prose", "excerpt", "heading", "document", "generated"],
                "\(shared.entries.map(\.kind))")
            let d2 = try #require(shared.entries.first { $0.documentId == "d2" && $0.kind == "document" })
            #expect(d2.notes == ["The second letter's second note.", "The second letter's first note."], "the selection, newest first")
            #expect(RTFReader.read([UInt8](try #require(shared.entries.first { $0.kind == "prose" }?.richText)))?.text == "Read these together.")

            // Each file imports as the kit reads it, into a collection whose file is the same file again.
            for (collection, file) in written {
                let response = try await session.send(.post, "\(base)/import", String(decoding: file, as: UTF8.self))
                let imported = try ServedFixture.decode(CollectionDetail.self, response)
                let again = Data(buffer: try await session.send(.post, "\(base)/\(imported.id)/export",
                                                               try Self.json(["format": "fruscollection", "includeNotes": true])).body)
                #expect(again == file, "\(collection)'s file, imported and written again")
                kit = try await KitReference(files: files, session: session, activeProject: active)
                let record = try kit.collection(imported.id)
                let values = NativeCollectionSerializer.importedValues(from: try NativeCollectionSerializer.decode(file)).collection
                #expect(Self.normalized(record) == Self.normalized(values), "\(collection)'s import is the kit's reading of its file")
                #expect(record.projectIds == [try #require(UUID(uuidString: project.id))])
            }

            // A smart collection's exports and previews, the kit's for its saved search's results.
            let results = try ServedFixture.decode(CollectionExportRoutes.Results.self, try await session.get("\(base)/\(smart.id)/results"))
            #expect(results.total > 20 && results.total < 40, "past the preview's cap: \(results.total)")
            #expect(results.items.contains { $0.volumeId == "frus1894Nicaragua" && $0.documentId == "d1" }, "a result the user's note finds")
            for format in CollectionExportFormat.allCases where format != .fruscollection {
                try await CollectionExportParityTests.sameDay { day in
                    let served = Data(buffer: try await session.send(.post, "\(base)/\(smart.id)/export",
                                                                     try Self.json(["format": format.rawValue, "timeZone": "UTC"])).body)
                    let theirs = try await kit.export(smart.id, format, on: day)
                    #expect(served == theirs, "the smart collection as \(format.rawValue): \(served.count) bytes, the kit's \(theirs.count)")
                }
            }
            for renderAll in [false, true] {
                try await CollectionExportParityTests.sameDay { day in
                    let served = String(buffer: try await session.get("\(base)/\(smart.id)/preview?renderAll=\(renderAll)&timeZone=UTC").body)
                    let theirs = try await kit.preview(smart.id, renderAll: renderAll, on: day)
                    #expect(served == theirs, "the smart collection's preview, renderAll \(renderAll)")
                    #expect(served.components(separatedBy: "<section id=\"doc-").count - 1 == (renderAll ? results.total : 20))
                }
            }

            // A snapshot is the kit's of the results, as its values make it.
            let snapshot = try await session.json(CollectionDetail.self, .post, "\(base)/\(smart.id)/snapshot")
            kit = try await KitReference(files: files, session: session, activeProject: active)
            let made = try kit.collection(snapshot.id)
            let refs = results.items.map { (documentId: $0.documentId, volumeId: $0.volumeId) }
            let theirs = SmartCollectionSnapshot.snapshot(of: try kit.collection(smart.id), results: refs)
            #expect(made.name == theirs.name && made.savedSearchId == nil && made.note == theirs.note)
            #expect(made.entries.map { [$0.documentId, $0.volumeId, $0.kind ?? ""] } == theirs.entries.map { [$0.documentId, $0.volumeId, $0.kind ?? ""] })
            #expect(made.entries.map(\.sortOrder) == theirs.entries.map(\.sortOrder))
            #expect(made.defaultBodyDepth == theirs.defaultBodyDepth && made.includeNotes == theirs.includeNotes && made.tocStyle == theirs.tocStyle)
            #expect(made.projectIds == [try #require(UUID(uuidString: project.id))], "the source's projects and the one worked in")
        }
    }

    /// A collection's values with what an import or a write mints left out: the ids, the times and the
    /// projects, and the notes each entry is pinned to, which are new.
    static func normalized(_ collection: CollectionExport) -> CollectionExport {
        let none = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        var values = collection
        values.id = none
        values.createdAt = nil
        values.lastModified = nil
        values.projectIds = []
        values.entries = values.entries.sorted { $0.sortOrder < $1.sortOrder }.map { entry in
            var entry = entry
            entry.id = none
            entry.createdAt = nil
            entry.lastModified = nil
            entry.selectedNoteIds = entry.selectedNoteIds.map { _ in none }
            return entry
        }
        return values
    }

    /// The app code the server mirrors for the file, the smart collection and the headnote card, each
    /// held by the lines the app's source writes it in and the server's own.
    @Test func theServersMirrorsAreTheApps() throws {
        let sheet = try CollectionParityTests.app("Collections/CollectionExportSheet.swift")
        NoteViewParityTests.expect(sheet, holds: [
            // runNativeExport()
            #"guard collection.savedSearchId == nil else { exportError = String(localized: "export.native.smartUnsupported", defaultValue: "Smart collections can’t be shared as a file yet.") return }"#,
            "if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.compactMap { id in allNotes.first { $0.id == id }?.bodyText }.filter { !$0.isEmpty } }",
            "if let legacyId = entry.researchNoteId, let legacy = allNotes.first(where: { $0.id == legacyId }) { return legacy.bodyText.isEmpty ? [] : [legacy.bodyText] }",
            "return allNotes .filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId } .map(\\.bodyText) .filter { !$0.isEmpty }",
            "let file = NativeCollectionSerializer.makeFile( from: collection, includeNotes: includeNotesInSharedFile, resolveNoteTexts: resolveNoteTexts)",
            "recordExport(format: selectedFormat.rawValue, documentCount: entries.filter { $0.entryKind == .document }.count)",
            // the notes' switch is off until turned on
            "@State private var includeNotesInSharedFile = false",
            // the smart path: one resolve for a smart collection's exports and RIS
            "if selectedFormat == .fruscollection { runNativeExport() return }",
        ], file: "CollectionExportSheet.swift")
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/NativeCollectionFormat+App.swift"), holds: [
            "for entry in entries where entry.entryKind == .prose { ProseRichText.migrateLegacyJSONIfNeeded(entry) }",
            "let data = try encode(file) let url = CollectionExportNaming.temporaryFileURL(savedName: file.name, suffix: \".\" + fileExtension)",
            "let data = try Data(contentsOf: url) let file = try decode(data) return apply(file, into: context)",
            "collection.includeColophon = values.includeColophon ?? collection.includeColophon",
            "let note = ResearchNote( documentId: noteValues.documentId, volumeId: noteValues.volumeId, bodyText: noteValues.bodyText )",
        ], file: "NativeCollectionFormat+App.swift")
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/CollectionRichTextEditor.swift"), holds: [
            "guard let stored = entry.richText, decodedRTF(stored) == nil, let legacy = legacyNSAttributedString(fromJSON: stored), let rtf = rtfData(from: legacy) else { return }",
            "return try? JSONDecoder().decode(AttributedString.self, from: data)",
        ], file: "CollectionRichTextEditor.swift")
        let list = try CollectionParityTests.app("Collections/CollectionListView.swift")
        NoteViewParityTests.expect(list, holds: [
            // importCollection(from:)
            "let imported = try NativeCollectionSerializer.importCollection(from: url, into: modelContext)",
            "if let pid = appState.activeProjectId { imported.projectIds = [pid] }",
            "collectionToEdit = imported",
            // snapshotSmartCollection(_:)
            #"guard let searchService = appState.searchService else { snapshotError = String(localized: "export.smart.noSearchService.v2", defaultValue: "Search is not ready yet. Try again in a moment.") return }"#,
            "let refs = try await SmartCollectionSnapshot.documentRefs( parameters: savedSearch.searchParameters, searchService: searchService, limit: SearchViewModel.searchHardLimit)",
            "let snapshot = SmartCollectionSnapshot.create(from: collection, results: refs, into: modelContext)",
            "if let pid = appState.activeProjectId, !snapshot.projectIds.contains(pid) { snapshot.projectIds.append(pid) }",
            "collectionToEdit = snapshot",
            // Create Static Snapshot is on a smart collection's row alone
            "if collection.savedSearchId != nil { Divider() Button { Task { await snapshotSmartCollection(collection) } }",
            ".fileImporter(isPresented: $isImporting, allowedContentTypes: [.fruscollection], allowsMultipleSelection: false)",
        ], file: "CollectionListView.swift")
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/SmartCollectionSnapshot+App.swift"), holds: [
            "let value = snapshot(of: CollectionExport(smart, entries: []), results: results)",
            "let snapshot = Collection(name: value.name, note: value.note, projectIds: value.projectIds)",
            "snapshot.summaryPromptId = value.summaryPromptId",
        ], file: "SmartCollectionSnapshot+App.swift")
        // The ceiling a smart collection's search runs at, the app's, which is the kit's own limit.
        #expect(try CollectionParityTests.app("Search/SearchViewModel.swift").contains("static let searchHardLimit: Int = 1_000"))
        #expect(SmartCollectionSnapshot.resultLimit == 1_000)
        let resolver = try CollectionParityTests.app("Collections/CollectionContentResolver.swift")
        NoteViewParityTests.expect(resolver, holds: [
            "guard let searchId = collection.savedSearchId else { return [] } guard let searchService = appState.searchService else { throw CollectionResolveError.searchServiceUnavailable }",
            "guard let savedSearch = try? modelContext.fetch(descriptor).first else { throw CollectionResolveError.savedSearchMissing }",
            "return try await SmartCollectionSnapshot.documentRefs( parameters: savedSearch.searchParameters, searchService: searchService, limit: SearchViewModel.searchHardLimit)",
        ], file: "CollectionContentResolver.swift")
        let preview = try CollectionParityTests.app("Collections/CollectionPreviewView.swift")
        NoteViewParityTests.expect(preview, holds: [
            "let isSmart = collection.savedSearchId != nil var missing: Set<String> = [] if !isSmart, let dm = appState.downloadManager {",
            "let refs = try await resolver.smartRefs(for: collection) let docCount = refs.count",
            "let cappedRefs = (renderAll || docCount <= Self.initialDocumentCap) ? refs : Array(refs.prefix(Self.initialDocumentCap))",
            "let resolved = try await resolver.resolve( smartRefs: cappedRefs, collection: collection, allNotes: allNotes, purpose: .preview, fullRefs: refs)",
            "totalDocumentCount = docCount",
        ], file: "CollectionPreviewView.swift")
        let formats = try CollectionParityTests.app("Collections/CollectionExporter+App.swift")
        NoteViewParityTests.expect(formats, holds: [
            "case .fruscollection: return NativeCollectionSerializer.fileExtension",
            #"case .fruscollection: return String(localized: "export.format.native", defaultValue: "FRUS Collection (shareable)")"#,
            "let ordered: [ExportFormat] = [.pdf, .html, .docx, .bibtex, .zoteroJSON, .fruscollection] return smartCollection ? ordered.filter { $0 != .fruscollection } : ordered",
        ], file: "CollectionExporter+App.swift")
        let inspector = try CollectionParityTests.app("Collections/CollectionEntryInspector.swift")
        NoteViewParityTests.expect(inspector, holds: [
            // headnoteDraftPromptId
            #"private static let headnoteDraftPromptId = UUID(uuidString: "0EAD0000-0000-4000-8000-000000000001")!"#,
            // currentHeadnoteSummary
            "if let sid = entry.headnoteSummaryId, let chosen = try? modelContext.fetch( FetchDescriptor<GeneratedSummary>(predicate: #Predicate { $0.id == sid })).first, !chosen.responseText.isEmpty { return chosen }",
            "predicate: #Predicate { $0.volumeId == vid && $0.documentId == did && !$0.isHeadnoteDraft }))) ?? []) .filter { !$0.responseText.isEmpty }",
            "let promptId = entry.summaryPromptIdOverride ?? resolvedEntryDefaults?.summaryPromptId return promptId.flatMap { pid in stored.first { $0.promptId == pid } } ?? stored.first",
            // commitHeadnote(seed:)
            "let trimmed = headnoteDraft.trimmingCharacters(in: .whitespacesAndNewlines)",
            "guard !trimmed.isEmpty, seed?.responseText.trimmingCharacters(in: .whitespacesAndNewlines) != trimmed else { return }",
            "let seedAuthorship = seed.map { $0.authorship ?? .aiGenerated } let seedIsAIDerived = seedAuthorship == .aiGenerated || seedAuthorship == .aiEdited",
            "(seedIsAIDerived && !(seed?.responseText.isEmpty ?? true)) ? .aiEdited : .userWritten",
            // swapHeadnoteDraft(text:authorship:)
            "existing.isHeadnoteDraft { modelContext.delete(existing) }",
            "let draft = GeneratedSummary(documentId: entry.documentId, volumeId: entry.volumeId, promptId: Self.headnoteDraftPromptId, responseText: text, authorship: authorship, isHeadnoteDraft: true)",
            "entry.headnoteSummaryId = draft.id",
            // the card shows where the headnote is on, and its Save is dimmed for no text
            "if entry.includeHeadnote ?? rd?.headnote ?? false { headnoteCard }",
            ".disabled(headnoteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)",
            "headnoteProvenanceChip(summary.map { $0.authorship ?? .aiGenerated })",
            // Generate is offered only where the summarizer is
            "if aiSummarizationAvailable {",
        ], file: "CollectionEntryInspector.swift")
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/CollectionEditorView.swift"), holds: [
            // New Note…: a partial selection takes the new note
            "if let entry = sortedEntries.first(where: { $0.id == ctx.entryId }), !entry.selectedNoteIds.isEmpty { entry.selectedNoteIds.append(newNote.id) }",
            // Link to Saved Search…, and its record of the edit
            "static func savedSearch(_ id: UUID?, to collection: Collection) -> Bool { guard collection.savedSearchId != id else { return false } collection.savedSearchId = id return true }",
            "if CollectionEditorCommit.savedSearch(id, to: collection) { recordEdit() }",
            "if let projectId = appState.activeProjectId, !collection.projectIds.contains(projectId) { collection.projectIds.append(projectId) }",
            "SmartCollectionLinkButton(hasSavedSearches: !allSavedSearches.isEmpty) {",
            "savedSearchName: allSavedSearches.first(where: { $0.id == searchId })?.name,",
            "nameSection noteSection frontMatterSection compositionSection smartCollectionSection",
        ], file: "CollectionEditorView.swift")
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/CollectionEntryRows.swift"), holds: [
            "let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines) let note = ResearchNote( documentId: documentId, volumeId: volumeId, bodyText: trimmed, projectIds: activeProjectId.map { [$0] } ?? [] )",
            ".disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)",
        ], file: "CollectionEntryRows.swift")
        // The kit's sentences the server answers with.
        #expect(CollectionResolveError.savedSearchMissing.errorDescription == "The linked saved search could not be found. It may have been deleted.")
        #expect(CollectionResolveError.searchServiceUnavailable.errorDescription == "Search is not ready yet. Try again in a moment.")
        #expect(NativeCollectionError.notACollectionFile.errorDescription == "This file isn’t a FRUS Explorer collection.")

        // And the server's own lines for each.
        NoteViewParityTests.expect(try CollectionParityTests.server("Sources/FRUSLightAPI/CollectionFiles.swift"), holds: [
            #"static let smartUnsupported = "Smart collections can’t be shared as a file yet.""#,
            "if !entry.selectedNoteIds.isEmpty { return entry.selectedNoteIds.compactMap { id in allNotes.first { UUID(uuidString: $0.id) == id }?.bodyText }.filter { !$0.isEmpty } }",
            "if let legacyId = entry.researchNoteId, let legacy = allNotes.first(where: { UUID(uuidString: $0.id) == legacyId }) { return legacy.bodyText.isEmpty ? [] : [legacy.bodyText] }",
            "return allNotes .filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId } .map(\\.bodyText) .filter { !$0.isEmpty }",
            "let documents = collection.entries.filter { $0.entryKind == .document }.count",
            "collection.projectIds = projectId.map { [$0] } ?? []",
            "if let projectId, !made.projectIds.contains(projectId) { made.projectIds.append(projectId) }",
        ], file: "CollectionFiles.swift")
        NoteViewParityTests.expect(try CollectionParityTests.server("Sources/FRUSLightAPI/CollectionContent.swift"), holds: [
            "guard let served = try await provider.servedIfReady() else { throw CollectionResolveError.searchServiceUnavailable }",
            "throw CollectionResolveError.savedSearchMissing",
            "return try await SmartCollectionSnapshot.documentRefs(parameters: saved.parameters, searchService: search.service)",
        ], file: "CollectionContent.swift")
        NoteViewParityTests.expect(try CollectionParityTests.server("Sources/FRUSLightAPI/CollectionExports.swift"), holds: [
            "let shown = renderAll || refs.count <= initialDocumentCap ? refs : Array(refs.prefix(initialDocumentCap))",
            "return try await resolve(collection, smartRefs: shown, fullRefs: refs,",
            "guard !collection.entries.isEmpty || collection.savedSearchId != nil else {",
        ], file: "CollectionExports.swift")
        NoteViewParityTests.expect(try CollectionParityTests.server("Sources/FRUSLightAPI/CollectionEditing.swift"), holds: [
            #"static let headnoteDraftPromptId = UUID(uuidString: "0EAD0000-0000-4000-8000-000000000001")!"#,
            "if let chosen, !chosen.responseText.isEmpty { return chosen }",
            "let candidates = stored.filter { !$0.isHeadnoteDraft && !$0.responseText.isEmpty } return promptId.flatMap { pid in candidates.first { UUID(uuidString: $0.promptId) == pid } } ?? candidates.first",
            "guard !trimmed.isEmpty, seed?.responseText.trimmingCharacters(in: .whitespacesAndNewlines) != trimmed else { return nil }",
            "let seedIsAIDerived = seedAuthorship == .aiGenerated || seedAuthorship == .aiEdited",
            "(seedIsAIDerived && !(seed?.responseText.isEmpty ?? true)) ? .aiEdited : .userWritten",
        ], file: "CollectionEditing.swift")
        #expect(try CollectionParityTests.server("Sources/FRUSLightAPI/CollectionEntries.swift")
            .contains("collection.entries[index].summaryPromptIdOverride ?? CollectionEditing.resolvedDefaults(of: index, in: collection)?.summaryPromptId"))
        #expect(try CollectionParityTests.server("Sources/FRUSLightAPI/Collections.swift")
            .contains("if let link, collection.savedSearchId != link { collection.savedSearchId = link committed = true }"))
    }

    /// The app's words S18f's screens take, each where the app's source writes it under its key and in
    /// copy.ts's block; and the browser app's mirrors, held to the app's source and the web's.
    @Test func theAppsWordsAndTheBrowsersMirrorsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let blocks = try Dictionary(uniqueKeysWithValues: ["collections", "collectionEditor", "collectionExport", "collectionSettings",
                                                           "collectionInspector"].map {
            ($0, try NoteViewParityTests.block($0, of: raw))
        })
        let list = try CollectionParityTests.app("Collections/CollectionListView.swift")
        let sheet = try CollectionParityTests.app("Collections/CollectionExportSheet.swift")
        let formats = try CollectionParityTests.app("Collections/CollectionExporter+App.swift")
        let editor = try CollectionParityTests.app("Collections/CollectionEditorView.swift")
        let rows = try CollectionParityTests.app("Collections/CollectionCompositionRows.swift")
        let inspector = try CollectionParityTests.app("Collections/CollectionEntryInspector.swift")
        let entryRows = try CollectionParityTests.app("Collections/CollectionEntryRows.swift")
        let model = try CollectionParityTests.app("Models/Collection.swift")
        let naming = try CollectionParityTests.kit("FRUSCoreKit/Collections/CollectionEditorNaming.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (list, "CollectionListView", "collections.toolbar.import", "Import Collection…", "collections", "importCollection: 'Import Collection…'"),
            (list, "CollectionListView", "collections.import.error.title", "Couldn’t Import Collection", "collections",
             "importFailedTitle: 'Couldn’t Import Collection'"),
            (list, "CollectionListView", "collection.snapshot.action", "Create Static Snapshot", "collections", "snapshot: 'Create Static Snapshot'"),
            (list, "CollectionListView", "collection.snapshot.error.title", "Couldn’t Create Snapshot", "collections",
             "snapshotFailedTitle: 'Couldn’t Create Snapshot'"),
            (list, "CollectionListView", "collections.import.error.ok", "OK", "collections", "alertOK: 'OK'"),
            (formats, "CollectionExporter+App", "export.grid.native.title", ".fruscollection", "collectionExport",
             "fruscollection: { label: '.fruscollection', caption: 'Editable copy for a colleague' }"),
            (formats, "CollectionExporter+App", "export.grid.native.caption", "Editable copy for a colleague", "collectionExport",
             "fruscollection: { label: '.fruscollection', caption: 'Editable copy for a colleague' }"),
            (sheet, "CollectionExportSheet", "export.native.includeNotes", "Include my research notes", "collectionExport",
             "includeNotes: 'Include my research notes'"),
            (sheet, "CollectionExportSheet", "export.native.hint",
             "Shares an editable copy of this collection: its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above.",
             "collectionExport",
             "nativeHint: 'Shares an editable copy of this collection: its documents, composition, sections, and prose. Recipients open it in FRUS Explorer and download any volumes they don’t have. Your research notes stay private unless you include them above.'"),
            (rows, "CollectionCompositionRows", "composition.summaryPrompt.hint", SummariesNotStored.appsReason, "collectionSettings",
             "summaryOnlyReason: '\(SummariesNotStored.appsReason)'"),
            (editor, "CollectionEditorView", "collection.editor.smart.header", "Smart Collection", "collectionSettings", "smartHeader: 'Smart Collection'"),
            (editor, "CollectionEditorView", "collection.editor.smart.link", #"Link to Saved Search\u{2026}"#, "collectionSettings",
             "smartLink: 'Link to Saved Search…'"),
            (editor, "CollectionEditorView", "collection.editor.smart.unlink", "Unlink", "collectionSettings", "smartUnlink: 'Unlink'"),
            (editor, "CollectionEditorView", "collection.editor.smart.missing", "Saved search not found", "collectionSettings",
             "smartMissing: 'Saved search not found'"),
            (editor, "CollectionEditorView", "collection.editor.smart.missing.explanation",
             "The linked saved search could not be found. It may have been deleted. Unlink it to add to this collection by hand.", "collectionSettings",
             "smartMissingExplanation: 'The linked saved search could not be found. It may have been deleted. Unlink it to add to this collection by hand.'"),
            (editor, "CollectionEditorView", "collection.editor.smart.explanation",
             "Documents are resolved from this saved search at export time. Static entries are ignored.", "collectionSettings",
             "smartExplanation: 'Documents are resolved from this saved search at export time. Static entries are ignored.'"),
            (editor, "CollectionEditorView", "collection.editor.smart.noSearches", "Save a search from the Search tab to enable smart collections.",
             "collectionSettings", "smartNoSearches: 'Save a search from the Search tab to enable smart collections.'"),
            (editor, "CollectionEditorView", "collection.editor.smart.picker.title", "Link to Saved Search", "collectionSettings",
             "smartPickerTitle: 'Link to Saved Search'"),
            (editor, "CollectionEditorView", "collection.editor.smart.picker.cancel", "Cancel", "collectionSettings", "smartPickerCancel: 'Cancel'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.keyTakeaway", #"Key takeaway \u{00B7} headnote"#,
             "collectionInspector", "headnoteKeyTakeaway: 'Key takeaway · headnote'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.chip.ai", "AI draft", "collectionInspector",
             "headnoteChips: { aiGenerated: 'AI draft', aiEdited: 'AI · edited', userWritten: 'Yours' }"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.chip.aiEdited", #"AI \u{00B7} edited"#, "collectionInspector",
             "headnoteChips: { aiGenerated: 'AI draft', aiEdited: 'AI · edited', userWritten: 'Yours' }"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.chip.user", "Yours", "collectionInspector",
             "headnoteChips: { aiGenerated: 'AI draft', aiEdited: 'AI · edited', userWritten: 'Yours' }"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.empty",
             "No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one.", "collectionInspector",
             "headnoteEmpty: 'No headnote yet. Edit to write a key takeaway, or generate a document summary to seed one.'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.edit", "Edit", "collectionInspector", "headnoteEdit: 'Edit'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.headnote.save", "Save", "collectionInspector", "headnoteSave: 'Save'"),
            (inspector, "CollectionEntryInspector", "common.cancel", "Cancel", "collectionInspector", "headnoteCancel: 'Cancel'"),
            (inspector, "CollectionEntryInspector", "collection.inspector.note.new", #"New Note\u{2026}"#, "collectionInspector", "newNote: 'New Note…'"),
            (entryRows, "CollectionEntryRows", "collection.entry.newNote.title", "New Research Note", "collectionInspector",
             "newNoteTitle: 'New Research Note'"),
            (entryRows, "CollectionEntryRows", "collection.entry.newNote.save", "Save Note", "collectionInspector", "newNoteSave: 'Save Note'"),
            (entryRows, "CollectionEntryRows", "common.cancel", "Cancel", "collectionInspector", "newNoteCancel: 'Cancel'"),
            (model, "Collection", "collection.smart.earlier.heading",
             "Not part of the smart collection: added before it was linked to its saved search.", "collectionEditor",
             "earlierHeading: 'Not part of the smart collection: added before it was linked to its saved search.'"),
            (model, "Collection", "collection.smart.earlier.remove", "Remove These Entries", "collectionEditor",
             "earlierRemove: 'Remove These Entries'"),
            (model, "Collection", "collection.smart.earlier.remove.confirm.title", "Remove These Entries?", "collectionEditor",
             "earlierRemoveTitle: 'Remove These Entries?'"),
            (model, "Collection", "collection.smart.earlier.remove.confirm.message.one",
             "Removes the entry added before this collection was linked to its saved search.", "collectionEditor",
             "? 'Removes the entry added before this collection was linked to its saved search.'"),
            (model, "Collection", "collection.smart.earlier.emptyNote", "Empty note block", "collectionEditor", "earlierEmptyNote: 'Empty note block'"),
            (naming, "CollectionEditorNaming", "collection.inspector.section.untitled", "Untitled section", "collectionEditor",
             "untitledSection: 'Untitled section'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(blocks[word.block]?.contains(word.web) == true, "copy.ts's \(word.block) block holds \(word.web)")
        }
        // The browser app's mirrors: the grid's order, the notes' switch off until turned on, the preview's count of
        // a smart collection's results, the Export a smart collection offers with no entry, and New Note…'s rule.
        NoteViewParityTests.expect(try CollectionParityTests.web("api/collections.ts"), holds: [
            "export const exportFormats = ['html', 'docx', 'bibtex', 'zoteroJSON', 'fruscollection'] as const;",
        ], file: "api/collections.ts")
        NoteViewParityTests.expect(try CollectionParityTests.web("collections/exportRules.ts"), holds: [
            "return smartCollection ? exportFormats.filter((format) => format !== 'fruscollection') : exportFormats;",
        ], file: "collections/exportRules.ts")
        NoteViewParityTests.expect(try CollectionParityTests.web("collections/CollectionExportSheet.tsx"), holds: [
            "const [includeNotes, setIncludeNotes] = useState(false);",
            "const unavailable = detail.entries.length === 0 && !smart;",
        ], file: "collections/CollectionExportSheet.tsx")
        NoteViewParityTests.expect(try CollectionParityTests.web("collections/CollectionPreview.tsx"), holds: [
            "const documentCount = smart ? (results.data?.total ?? 0) : detail.documentCount;",
            "const missing = smart ? 0 : detail.volumesNotHeld.length;",
        ], file: "collections/CollectionPreview.tsx")
        // The many message, `CountCopy.phrase` with its count grouped, and the group's rules.
        #expect(model.contains(NoteViewParityTests.flattened(
            #"many: String(localized: "collection.smart.earlier.remove.confirm.message.many", defaultValue: "Removes the %@ entries added before this collection was linked to its saved search."),"#)))
        #expect(blocks["collectionEditor"]?.contains(
            ": `Removes the ${count.toLocaleString('en-US')} entries added before this collection was linked to its saved search.`") == true)
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/CollectionEditorView.swift"), holds: [
            "case .document: return documentHeader(for: entry) ?? entry.documentId case .heading: return text.isEmpty ? CollectionEditorNaming.untitledSection : text case .prose: return text.isEmpty ? SmartCollectionRule.emptyNoteBlock : text case .excerpt: return text",
            "case .document: parts = [documentHeader != nil ? entry.documentId : nil, entry.volumeId] case .excerpt: parts = [entry.documentId, entry.volumeId]",
            #"return named.isEmpty ? nil : named.joined(separator: " · ")"#,
        ], file: "CollectionEditorView.swift")
        NoteViewParityTests.expect(model, holds: ["outline.filter { leavesOut($0.entryKind, savedSearchId: savedSearchId) }"], file: "Collection.swift")
        NoteViewParityTests.expect(try CollectionParityTests.app("Collections/CollectionEntryData.swift"), holds: [
            "for entry in removed { GeneratedSummary.deleteHeadnoteDraft(for: entry, in: modelContext) modelContext.delete(entry) }",
        ], file: "CollectionEntryData.swift")
        NoteViewParityTests.expect(try CollectionParityTests.web("collections/collectionRules.ts"), holds: [
            "return collection.savedSearchId ? collection.entries.filter((entry) => entry.leftOut) : [];",
            "case 'document': return entry.header ?? entry.documentId; case 'heading': return text === '' ? copy.collectionEditor.untitledSection : text; case 'prose': return text === '' ? copy.collectionEditor.earlierEmptyNote : text; case 'excerpt': return text;",
            "entry.kind === 'document' ? [entry.header !== undefined ? entry.documentId : undefined, entry.volumeId] : entry.kind === 'excerpt' ? [entry.documentId, entry.volumeId] : [];",
            "return named.length === 0 ? undefined : named.join(' · ');",
        ], file: "collections/collectionRules.ts")
        NoteViewParityTests.expect(try CollectionParityTests.server("Sources/FRUSLightAPI/CollectionEntries.swift"), holds: [
            "let kept = collection.entries.filter { !CollectionEditing.leavesOut($0.entryKind, savedSearchId: savedSearchId) }",
            "CollectionEditing.finishOutlineMutation(&collection.entries)",
        ], file: "CollectionEntries.swift")
        NoteViewParityTests.expect(try CollectionParityTests.web("collections/EntryInspector.tsx"), holds: [
            "if (entry.selectedNoteIds.length > 0) await change({ note: { id: noteId, included: true } });",
            "{(entry.includeHeadnote ?? data.resolved?.headnote ?? false) && (",
            "projectIds: active ? [active] : [],",
            "const trimmed = text.trim();",
        ], file: "collections/EntryInspector.tsx")
    }
}

extension KitReference {
    /// The export sheet's native file, `runNativeExport()`: the kit's writer over the collection as the
    /// user's JSON export records it, each document entry's notes as the sheet's `resolveNoteTexts` gives
    /// them from the editor's notes, the last changed first, and the kit's encoder.
    func nativeFile(_ id: String, includeNotes: Bool) throws -> Data {
        let collection = try collection(id)
        let notes = envelope.notes.sorted {
            ($0.lastModified ?? .distantPast, $1.id.uuidString) > ($1.lastModified ?? .distantPast, $0.id.uuidString)
        }
        let file = NativeCollectionSerializer.makeFile(from: collection, includeNotes: includeNotes) { entry in
            if !entry.selectedNoteIds.isEmpty {
                return entry.selectedNoteIds.compactMap { id in notes.first { $0.id == id }?.bodyText }.filter { !$0.isEmpty }
            }
            if let legacyId = entry.researchNoteId, let legacy = notes.first(where: { $0.id == legacyId }) {
                return legacy.bodyText.isEmpty ? [] : [legacy.bodyText]
            }
            return notes.filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }.map(\.bodyText).filter { !$0.isEmpty }
        }
        return try NativeCollectionSerializer.encode(file)
    }
}
