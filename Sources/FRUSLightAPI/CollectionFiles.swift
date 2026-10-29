// A collection's `.fruscollection` file, both ways, and a smart collection's static snapshot (PLAN's
// S18f), each the kit's: the file written by `NativeCollectionSerializer.makeFile(from:includeNotes:
// resolveNoteTexts:)` and `encode` from the collection's values as the store holds them, its prose as
// the RTF it keeps, S15d's codec's for a note block written here; read by `decode` and
// `importedValues(from:)` into a new collection with the notes the file carries; and a snapshot made by
// `SmartCollectionSnapshot.snapshot(of:results:)` of its saved search's results, which
// `CollectionSmartSearch` runs.
// - `POST /api/v1/me/collections/{id}/export` with `{"format": "fruscollection", "includeNotes"}` answers
//   the file (CollectionExports.swift's route), named as the app's `writeTemporaryFile(_:)` names it,
//   and keeps it in the history as the app's sheet keeps it, counting its document entries.
// - `POST /api/v1/me/collections/import` takes a file's bytes, as JSON, and answers the collection it
//   becomes, made as the app's Import Collection… makes it.
// - `POST /api/v1/me/collections/{id}/snapshot` answers the static collection a smart one's results make,
//   as the app's Create Static Snapshot makes it, leaving the smart one as it is.
//
// App code mirrored here, held to its source by CollectionFileParityTests:
// - `ExportSheetView.runNativeExport()`: the smart collection's refusal, the notes each document entry
//   carries when they are included (`resolveNoteTexts`), and the history's count of document entries;
// - `NativeCollectionSerializer.makeFile(from:includeNotes:resolveNoteTexts:)` over a `Collection`, which
//   heals a pre-RTF prose blob to RTF first;
// - `CollectionListView.importCollection(from:)` and `apply(_:into:)`: the collection filed under the
//   project the user works in, its notes made on their documents with no project, and each field the
//   values leave out at the model's initial value; a headnote draft of the user's an entry names copied
//   for it, the web's own, as `Collection.duplicate(in:)` copies one, where the app's import shares it;
// - `CollectionListView.snapshotSmartCollection(_:)` and `SmartCollectionSnapshot.create(from:results:into:)`:
//   the snapshot filed under the project the user works in too, its fields at the model's initial values
//   where the kit's values leave them out.

import FRUSCoreKit
import FRUSLightCore
import FRUSRichText
import Foundation
import Hummingbird
import NIOCore

enum CollectionFileRoutes {
    /// The largest file an import takes: room for a collection of a thousand documents, each with notes.
    static let fileLimit = 16 * 1_024 * 1_024
    /// The most entries, and the most notes, one file brings: five times a smart collection's 1,000 results,
    /// which the app's snapshot makes a collection of, so that no file holds the store, which every user
    /// shares, for long.
    static let entryLimit = 5_000

    /// `export.native.smartUnsupported`: a smart collection's documents are its search's, which no file carries.
    static let smartUnsupported = "Smart collections can’t be shared as a file yet."

    static func add(to me: RouterGroup<APIRequestContext>, imports: RouterGroup<APIRequestContext>, services: UserDataServices,
                    resources: ServerResources, provider: ServedIndexProvider) {
        let store = services.store
        let now = services.now

        // Import Collection…: the file a reader chooses, as it is, the new collection opened in its editor.
        imports.post("collections/import") { request, context -> EditedResponse<CollectionDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let data: Data
            do {
                data = Data(buffer: try await request.body.collect(upTo: fileLimit))
            } catch is NIOTooManyBytesError {
                throw JSONBody.tooLarge(fileLimit)
            } catch let error as HTTPError where error.status == .contentTooLarge {
                throw JSONBody.tooLarge(fileLimit)
            }
            let active = try await Blocking.run { try store.activeProjectId(of: user.id) }.flatMap(UUID.init(uuidString:))
            let time = UserStoreDate.rounded(now())
            // Read off the cooperative pool, as a Mac JSON export's import reads its file.
            var made = try await Blocking.run { try imported(data, projectId: active, at: time) }
            let (drafts, unreadable) = try await CollectionRoutes.headnoteDrafts(of: user.id, in: store)
            let copies = copyingDrafts(&made.collection, drafts: drafts, unreadable: unreadable, at: time)
            let rows: CollectionRows
            do {
                rows = try await Blocking.run { [made] in
                    try store.addCollection(CollectionRoutes.change(made.collection, addedSummaries: copies, notes: made.notes), for: user.id)
                }
            } catch let error as ResearchRowStoreError {
                throw APIProblem(.internalServerError, code: "STORE_REFUSED", detail: error.description)
            }
            let location = context.basePath.prefixing("/api/v1/me/collections/\(made.collection.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: try await CollectionRoutes.detail(CollectionRoutes.values(rows), for: user.id, in: store,
                                                                              resources: resources, provider: provider))
        }

        // Create Static Snapshot: the smart collection's results now, as a collection of their documents.
        me.post("collections/:collectionId/snapshot") { request, context -> EditedResponse<CollectionDetail> in
            try FormQuery(request.uri.query).refuseUnknown([])
            let user = try context.requireUser()
            let smart = try await CollectionRoutes.collection(try context.parameters.require("collectionId"), of: user.id, in: store)
            guard smart.savedSearchId != nil else {
                throw APIProblem(.conflict, code: "COLLECTION_NOT_SMART",
                                 detail: "This collection is not linked to a saved search, so there is nothing to snapshot.")
            }
            let refs = try await context.whileClientConnected {
                try await CollectionExportRoutes.smartRefs(of: smart, for: user.id, in: store, provider: provider)
            }
            let active = try await Blocking.run { try store.activeProjectId(of: user.id) }.flatMap(UUID.init(uuidString:))
            let made = snapshot(of: smart, results: refs, projectId: active, at: UserStoreDate.rounded(now()))
            let rows = try await Blocking.run { try store.addCollection(CollectionRoutes.change(made), for: user.id) }
            let location = context.basePath.prefixing("/api/v1/me/collections/\(made.id.uuidString)")
            return EditedResponse(status: .created, headers: [.location: location],
                                  response: try await CollectionRoutes.detail(CollectionRoutes.values(rows), for: user.id, in: store,
                                                                              resources: resources, provider: provider))
        }
    }

    // MARK: - The file a collection writes

    /// `runNativeExport()`'s file: refused for a smart collection, in the app's words; else the kit's file
    /// of the collection's values, its prose healed, and with "Include my research notes" each document
    /// entry's notes as the sheet resolves them, from the user's notes the last changed first, as the
    /// editor's `allNotes` lists them; with the document entries the history counts, and the file's name.
    static func nativeFile(_ collection: CollectionExport, includeNotes: Bool, for user: String,
                           in store: any UserDataStore) async throws -> (data: Data, documents: Int, name: String) {
        guard collection.savedSearchId == nil else {
            throw APIProblem(.conflict, code: "SMART_COLLECTION_NOT_SHAREABLE", detail: smartUnsupported)
        }
        let notes = includeNotes ? try await Blocking.run { try store.notes(for: user) } : []
        var values = collection
        values.entries = values.entries.map(healed)
        let file = NativeCollectionSerializer.makeFile(from: values, includeNotes: includeNotes) { entry in
            noteTexts(for: entry, among: notes)
        }
        let data: Data
        do {
            data = try NativeCollectionSerializer.encode(file)
        } catch {
            throw APIProblem(.internalServerError, code: "EXPORT_NOT_RENDERED", detail: "The collection's file could not be written: \(error)")
        }
        let documents = collection.entries.filter { $0.entryKind == .document }.count
        return (data, documents, CollectionExportNaming.fileName(savedName: file.name, suffix: CollectionExportFormat.fruscollection.suffix))
    }

    /// The sheet's `resolveNoteTexts`: the entry's explicit selection, else its legacy single-note link,
    /// else every note on its document, each note's text, none empty, in `allNotes`' order.
    static func noteTexts(for entry: CollectionEntryExport, among allNotes: [NoteRecord]) -> [String] {
        if !entry.selectedNoteIds.isEmpty {
            return entry.selectedNoteIds.compactMap { id in
                allNotes.first { UUID(uuidString: $0.id) == id }?.bodyText
            }.filter { !$0.isEmpty }
        }
        if let legacyId = entry.researchNoteId, let legacy = allNotes.first(where: { UUID(uuidString: $0.id) == legacyId }) {
            return legacy.bodyText.isEmpty ? [] : [legacy.bodyText]
        }
        return allNotes
            .filter { $0.documentId == entry.documentId && $0.volumeId == entry.volumeId }
            .map(\.bodyText)
            .filter { !$0.isEmpty }
    }

    /// A prose entry as the file carries it, `ProseRichText.migrateLegacyJSONIfNeeded`'s: RTF as it is
    /// kept, and a pre-RTF blob, July 2026's `AttributedString` JSON, as RTF, the codec's of the blob's own
    /// text, where the app writes its bold and italic too, which the web reads as its text alone; anything
    /// else as it is, as the app leaves what it cannot read.
    static func healed(_ entry: CollectionEntryExport) -> CollectionEntryExport {
        guard entry.entryKind == .prose, let stored = entry.richText, !stored.isEmpty, RTFReader.read([UInt8](stored)) == nil,
              let text = legacyText(stored), RichTextRuns.textProblem(text) == nil else { return entry }
        var healed = entry
        healed.richText = Data(RTFWriter.write([RichTextRun(text: text)]))
        return healed
    }

    /// The text of a legacy blob, an `AttributedString`'s `Codable` JSON: an array of its runs' strings, each
    /// followed by its attributes, an object; nil for any other JSON or none.
    static func legacyText(_ data: Data) -> String? {
        guard let runs = try? JSONSerialization.jsonObject(with: data) as? [Any], !runs.isEmpty, runs.count.isMultiple(of: 2) else {
            return nil
        }
        var text = ""
        for (index, element) in runs.enumerated() {
            if index.isMultiple(of: 2) {
                guard let run = element as? String else { return nil }
                text += run
            } else if !(element is [String: Any]) {
                return nil
            }
        }
        return text
    }

    // MARK: - The collection a file makes

    /// `importCollection(from:into:)`: the file decoded and checked by the kit, refused in its words, a
    /// file that is no JSON as one that is no collection; then `apply(_:into:)` over the kit's values: a
    /// new collection, made now, in the project the user works in, its entries each made now, and the
    /// notes the file carries made on their documents with no project, each linked to its entry. Each
    /// text is refused as an editor's would be, with U+0000 or past a note's length.
    static func imported(_ data: Data, projectId: UUID?, at time: Date) throws -> (collection: CollectionExport, notes: [NoteRecord]) {
        let file: FRUSCollectionFile
        do {
            file = try NativeCollectionSerializer.decode(data)
        } catch let error as NativeCollectionError {
            let code = if case .unsupportedVersion = error { "COLLECTION_FILE_TOO_NEW" } else { "NOT_A_COLLECTION_FILE" }
            throw APIProblem(.unprocessableContent, code: code, detail: error.errorDescription ?? "\(error)")
        } catch {
            throw APIProblem(.unprocessableContent, code: "NOT_A_COLLECTION_FILE",
                             detail: NativeCollectionError.notACollectionFile.errorDescription ?? "\(error)")
        }
        let values = NativeCollectionSerializer.importedValues(from: file)
        guard values.collection.entries.count <= entryLimit, values.notes.count <= entryLimit else {
            throw APIProblem(.unprocessableContent, code: "COLLECTION_FILE_TOO_LARGE",
                             detail: "A collection file may bring at most \(entryLimit) entries and \(entryLimit) notes; this one brings \(values.collection.entries.count) entries and \(values.notes.count) notes.")
        }
        var collection = values.collection
        try checkTexts(of: collection)
        collection.projectIds = projectId.map { [$0] } ?? []
        collection.createdAt = time
        collection.lastModified = time
        for index in collection.entries.indices {
            collection.entries[index].createdAt = time
            collection.entries[index].lastModified = time
        }
        let notes = try values.notes.enumerated().map { index, note in
            _ = try CollectionRoutes.checked(note.bodyText, "entries' notes[\(index)]")
            return NoteRecord(id: note.id.uuidString, volumeId: note.volumeId, documentId: note.documentId, bodyText: note.bodyText,
                              richText: nil, projectIds: [], userTagIds: [], selectedSummaryIds: [], createdAt: time, lastModified: time)
        }
        return (collection, notes)
    }

    /// Every text a file gives its collection and entries, each held to what an editor's field keeps.
    static func checkTexts(of collection: CollectionExport) throws {
        for (text, field) in [(collection.name, "name"), (collection.note, "note"), (collection.subtitle, "subtitle"),
                              (collection.authorLine, "authorLine"), (collection.introductionText, "introductionText"),
                              (collection.defaultBodyDepth, "composition.defaultBodyDepth"),
                              (collection.footnoteStyle, "composition.footnoteStyle"), (collection.tocStyle, "composition.tocStyle")] {
            if let text { _ = try CollectionRoutes.checked(text, field) }
        }
        for (index, entry) in collection.entries.enumerated() {
            for (text, field) in [(entry.documentId, "documentId"), (entry.volumeId, "volumeId"), (entry.text, "text"),
                                  (entry.titleOverride, "titleOverride"), (entry.bodyDepthOverride, "bodyDepthOverride"),
                                  (entry.excerptRenderingVersion, "excerptRenderingVersion"), (entry.excerptColorTag, "excerptColorTag"),
                                  (entry.generatedBlockType, "generatedBlockType")] {
                if let text { _ = try CollectionRoutes.checked(text, "entries[\(index)].\(field)") }
            }
            // A document's and a volume's ids as the routes that add one take them, a volume's any FRUS id.
            for (id, field) in [(entry.documentId, "documentId"), (entry.volumeId, "volumeId")] where !id.isEmpty {
                guard id.utf8.count <= 256, FRUSURLScheme.isSafeComponent(id) else {
                    throw CollectionRoutes.invalidField("entries[\(index)].\(field)", "\(id.prefix(60)) is not a document's or a volume's id.")
                }
            }
        }
    }

    /// The web's own: each headnote draft of the user's an imported entry names, copied for it, as
    /// `Collection.duplicate(in:)` copies one, so that a file brought back into the account it came from
    /// shares no draft with the collection it was written from, whose headnote a save or a delete of either
    /// would take. The app's import keeps the id, which on another person's device names nothing. A draft
    /// the server cannot read the entry names no longer, as a duplicate's names none.
    static func copyingDrafts(_ collection: inout CollectionExport, drafts: [UUID: GeneratedSummaryExport], unreadable: Set<UUID>,
                              at time: Date) -> [GeneratedSummaryExport] {
        var copies: [GeneratedSummaryExport] = []
        for index in collection.entries.indices {
            guard let draftId = collection.entries[index].headnoteSummaryId else { continue }
            if var draft = drafts[draftId] {
                draft.id = UUID()
                draft.authorship = draft.authorship ?? .aiGenerated
                draft.isHeadnoteDraft = true
                draft.createdAt = time
                draft.lastModified = time
                copies.append(draft)
                collection.entries[index].headnoteSummaryId = draft.id
            } else if unreadable.contains(draftId) {
                collection.entries[index].headnoteSummaryId = nil
            }
        }
        return copies
    }

    // MARK: - The snapshot

    /// `snapshotSmartCollection(_:)`: the kit's snapshot of the smart collection's results, made now, each
    /// field its values leave out at the model's initial value, filed under the project the user works in
    /// when the source was not.
    static func snapshot(of smart: CollectionExport, results: [SmartCollectionDocumentRef], projectId: UUID?,
                         at time: Date) -> CollectionExport {
        var source = smart
        source.entries = []
        var made = SmartCollectionSnapshot.snapshot(of: source, results: results.map { (documentId: $0.documentId, volumeId: $0.volumeId) })
        let initial = CollectionRoutes.newCollection(name: made.name, projectIds: [], at: time)
        made.createdAt = time
        made.lastModified = time
        made.includeColophon = initial.includeColophon
        made.includeProjectProvenance = initial.includeProjectProvenance
        made.includeMethodAppendix = initial.includeMethodAppendix
        made.defaultIncludeHeadnote = initial.defaultIncludeHeadnote
        made.defaultBodyDepth = made.defaultBodyDepth ?? initial.defaultBodyDepth
        made.footnoteStyle = made.footnoteStyle ?? initial.footnoteStyle
        made.tocStyle = made.tocStyle ?? initial.tocStyle
        made.applyHighlights = made.applyHighlights ?? initial.applyHighlights
        made.includeNotes = made.includeNotes ?? initial.includeNotes
        made.includeWordCloud = made.includeWordCloud ?? initial.includeWordCloud
        if let projectId, !made.projectIds.contains(projectId) { made.projectIds.append(projectId) }
        for index in made.entries.indices {
            made.entries[index].createdAt = time
            made.entries[index].lastModified = time
            made.entries[index].level = 1
            made.entries[index].selectedHighlightIds = []
        }
        return made
    }
}
