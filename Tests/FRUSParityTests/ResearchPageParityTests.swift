// The Research page (PLAN's S19b), held to the kit and to the app's source at the pin. Over the import's
// file of every type, imported as the route's job imports one: the documents the page gathers, a
// collection's count and a row's summaries are what the kit's `ResearchDocumentAggregation` answers
// for the file's own records. Then the app's words the page takes, under their keys and in copy.ts's
// block; the lines of the app's `ResearchView` the server mirrors (Research.swift) and those the
// browser app mirrors (researchRules.ts), each where the app's source writes it; and a category's key,
// as the app's row identifier spells it, read the same way by both. A pin move that changes one fails
// here until the web follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
@testable import FRUSParity
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct ResearchPageParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func web(_ path: String) throws -> String { try SearchSetParityTests.web(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    static func key(_ volumeId: String, _ documentId: String) -> String { "\(volumeId)/\(documentId)" }

    /// The done-when, as the kit answers it: the page's groups over a store the import filled are the
    /// kit's over the file's own records, the headnote draft, the heading, the prose block and the
    /// apparatus block counting for nothing, and the excerpt for its document.
    @Test func theGroupsAreTheKits() async throws {
        let directory = try TemporaryDirectory()
        let envelope = ImportFixtures.everyType(formatVersion: 7)
        let (store, _) = try await ExportParityTests.imported(try ImportFixtures.file(envelope), directory, "store")
        let groups = ResearchGroups(sources: try await ResearchSources.read(for: "owner", in: store))
        let entries = { (collection: CollectionExport) in
            collection.entries.map { ResearchDocumentAggregation.Entry(kind: $0.kind ?? "document", volumeId: $0.volumeId,
                                                                       documentId: $0.documentId) }
        }
        let summaries = envelope.summaries.map {
            ResearchDocumentAggregation.Summary(volumeId: $0.volumeId, documentId: $0.documentId, isHeadnoteDraft: $0.isHeadnoteDraft ?? false)
        }
        let kit = ResearchDocumentAggregation.annotatedKeys(among: ResearchDocumentAggregation.Sources(
            notes: envelope.notes.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) },
            tagAssignments: envelope.tagAssignments.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) },
            collections: envelope.collections.map(entries),
            highlights: envelope.highlights.map { .init(volumeId: $0.volumeId, documentId: $0.documentId) },
            summaries: summaries,
            visitDocumentKeys: envelope.archiveVisits.flatMap { $0.documents.map(\.documentKey) }))
        #expect(kit == [Self.key("frus1961-63v06", "d3"), Self.key("frus1961-63v06", "d4"), Self.key("frus1894Nicaragua", "d2")])
        #expect(groups.allAnnotatedKeys == kit, "All Research Documents' count, the kit's union")
        #expect(Set(groups.documents(for: .allAnnotated).map(\.id)) == kit, "and its list")

        // By Collection: the curated collection, its document counted once though an excerpt names it
        // too; the smart ones left out.
        let counted = groups.sortedCollectionsWithCounts
        #expect(counted.map(\.collection.name) == ["Briefing book"])
        let briefing = try #require(envelope.collections.first { $0.name == "Briefing book" })
        #expect(counted.first?.count == ResearchDocumentAggregation.distinctDocumentKeys(among: entries(briefing)).count)
        #expect(counted.first?.count == 1)
        #expect(Set(groups.documents(for: .collection(briefing.id)).map(\.id)) == ResearchDocumentAggregation.distinctDocumentKeys(among: entries(briefing)))

        // A row's summaries, drafts left out.
        let summaryCounts = ResearchDocumentAggregation.summaryCounts(among: summaries)
        #expect(summaryCounts == [Self.key("frus1961-63v06", "d3"): 2, Self.key("frus1961-63v06", "d4"): 1])
        for row in groups.documents(for: .allAnnotated) {
            #expect(row.summaryCount == summaryCounts[row.id] ?? 0, "\(row.id)'s summaries")
        }

        // The view's own lines over the same store: the tags on documents, the most used first, a tag
        // the user does not have left out; the colours in the kit's order; the documents a note is on.
        #expect(groups.sortedTagsWithCounts.map { "\($0.tag.name) \($0.count)" } == ["Cuba 2", "Primary source 1"])
        #expect(groups.sortedHighlightColorsWithCounts.map { "\($0.color.rawValue) \($0.count)" } == ["yellow 1", "green 1", "pink 1"])
        #expect(groups.documentsWithNotesCount == 2)
        #expect(groups.sources.notes.count == 3)
    }

    /// Each word the page takes, where the app's source writes it under its key, and in copy.ts's
    /// `researchPage` block.
    @Test func theAppsWordsAreTheWebs() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let block = try NoteViewParityTests.block("researchPage", of: raw)
        let view = try Self.app("Research/ResearchView.swift")
        let words: [(key: String, value: String, web: String)] = [
            ("research.title", "Research", "title: 'Research'"),
            ("research.sidebar.allNotes", "All Research Documents", "allAnnotated: 'All Research Documents'"),
            ("research.sidebar.hasNotes", "Contains Notes", "hasNotes: 'Contains Notes'"),
            ("research.sidebar.notes", "All Notes", "notes: 'All Notes'"),
            ("research.sidebar.updated", "Changed by an update", "updated: 'Changed by an update'"),
            ("research.list.updated", "Changed by an update", "updated: 'Changed by an update'"),
            ("research.sidebar.history", "History", "history: 'History'"),
            ("research.sidebar.history.detail", "Documents opened and searches run", "historyDetail: 'Documents opened and searches run'"),
            ("research.sidebar.collections", "By Collection", "collections: 'By Collection'"),
            ("research.sidebar.tags", "By Tag", "tags: 'By Tag'"),
            ("research.sidebar.highlights", "By Highlight", "highlights: 'By Highlight'"),
            ("research.list.unknownTag", "Tag", "unknownTag: 'Tag'"),
            ("research.empty.noDocs", "No Documents", "noDocs: 'No Documents'"),
            ("research.empty.noDocs.allNotes",
             "Research notes, tags, highlights, and collections you add from the document view will appear here.",
             "emptyAllAnnotated: 'Research notes, tags, highlights, and collections you add from the document view will appear here.'"),
            ("research.empty.noDocs.hasNotes",
             "Notes you write on a document will appear here. A document you have only tagged, highlighted, or collected appears under All Research Documents instead.",
             "emptyHasNotes: 'Notes you write on a document will appear here. A document you have only tagged, highlighted, or collected appears under All Research Documents instead.'"),
            ("research.empty.noDocs.tag", "No documents have notes or tags matching this tag.",
             "emptyTag: 'No documents have notes or tags matching this tag.'"),
            ("research.empty.noDocs.collection", "This collection has no documents.", "emptyCollection: 'This collection has no documents.'"),
            ("research.empty.noDocs.highlight", "No documents have highlights in this color.",
             "emptyHighlight: 'No documents have highlights in this color.'"),
            ("research.row.inVisitPlan", "In a visit plan", "inVisitPlan: 'In a visit plan'"),
            ("research.highlight.noText", "Highlighted passage", "noText: 'Highlighted passage'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(view, word.key, word.value), "ResearchView writes \(word.key) as \(word.value)")
            #expect(block.contains(word.web), "copy.ts's researchPage block holds \(word.web)")
        }
        // The words with a count or a colour, printed as `String(format:)` prints a number, ungrouped, and
        // the sidebar's counts, which SwiftUI's `Text` groups for the locale.
        let sentences: [(source: String, web: String)] = [
            (#"String(localized: "research.row.summaries %lld", defaultValue: "%lld summaries")"#, "summaries: (count: number) => `${count} summaries`"),
            (#"String(localized: "research.row.moreHighlights %lld", defaultValue: "and %lld more")"#,
             "moreHighlights: (count: number) => `and ${count} more`"),
            (#"String(localized: "research.row.noteCount %lld", defaultValue: "%lld notes")"#, "noteCount: (count: number) => `${count} notes`"),
            (#"color.displayName + " " + String(localized: "research.list.highlights", defaultValue: "Highlights")"#,
             "highlightList: (color: string) => `${color} Highlights`"),
            (#"Text("\(allAnnotatedDocumentCount)")"#, "count: (count: number) => count.toLocaleString('en-US')"),
            (#"Text("\(documentsWithNotesCount)")"#, "count: (count: number) => count.toLocaleString('en-US')"),
            (#"Text("\(notesSnapshot.total)")"#, "count: (count: number) => count.toLocaleString('en-US')"),
            (#"Text("\(item.count)")"#, "count: (count: number) => count.toLocaleString('en-US')"),
        ]
        for sentence in sentences {
            #expect(view.contains(NoteViewParityTests.flattened(sentence.source)), "ResearchView holds \(sentence.source)")
            #expect(block.contains(sentence.web), "copy.ts's researchPage block holds \(sentence.web)")
        }
    }

    /// A category's key, as the app's row identifier spells it, read by the server and the browser app.
    @Test func theCategoriesAreTheAppsRows() throws {
        NoteViewParityTests.expect(try Self.app("Research/ResearchView.swift"), holds: [
            #"case .allAnnotated: key = "allAnnotated""#, #"case .hasNotes: key = "hasNotes""#, #"case .notes: key = "notes""#,
            #"case .history: key = "history""#, #"case .updated: key = "updated""#, #"case .tag(let id): key = "tag.\(id.uuidString)""#,
            #"case .collection(let id): key = "collection.\(id.uuidString)""#,
            #"case .highlightColor(let color): key = "highlightColor.\(color.rawValue)""#,
        ], file: "ResearchView.swift")
        let id = UUID(uuidString: "5E19B000-0000-4000-8000-000000000001")!
        #expect(ResearchGroup("allAnnotated") == .allAnnotated && ResearchGroup("hasNotes") == .hasNotes && ResearchGroup("updated") == .updated)
        #expect(ResearchGroup("tag.\(id.uuidString)") == .tag(id) && ResearchGroup("tag.\(id.uuidString.lowercased())") == .tag(id))
        #expect(ResearchGroup("collection.\(id.uuidString)") == .collection(id))
        for color in HighlightColor.allCases { #expect(ResearchGroup("highlightColor.\(color.rawValue)") == .highlightColor(color)) }
        // All Notes and History open screens of their own, and are no list.
        for other in ["notes", "history", "tag.", "tag.d1", "highlightColor.red", "collection", "Tag.\(id.uuidString)"] {
            #expect(ResearchGroup(other) == nil, "\(other)")
        }
        NoteViewParityTests.expect(try Self.web("research/researchRules.ts"), holds: [
            "if (key === 'allAnnotated' || key === 'hasNotes' || key === 'updated') return { kind: key };",
            "if ((kind === 'tag' || kind === 'collection') && uuid.test(rest)) return { kind, id: rest };",
            "return `${group.kind}.${group.id}`;", "return `highlightColor.${group.color}`;",
        ], file: "researchRules.ts")
    }

    /// The lines of the app's view the server mirrors: the badges, the three sections, which documents
    /// a category lists with each row's facts, and the order of the rows, a row's tags and its
    /// collections.
    @Test func theServersMirrorsAreTheApps() throws {
        NoteViewParityTests.expect(try Self.app("Research/ResearchView.swift"), holds: [
            // The badges.
            #"Set(allNotes.map { "\($0.volumeId)/\($0.documentId)" }).count"#,
            """
            ResearchDocumentAggregation.annotatedKeys(
                notes: allNotes, tagAssignments: allTagAssignments, collections: allCollections,
                highlights: allHighlights, summaries: allSummaries, visitDocuments: allVisitDocuments)
            """,
            "allAnnotatedKeys.intersection(unreviewedRevisions.keys).count", "if updatedDocumentCount > 0 {",
            // Each document's direct tags and collections.
            #"let key = "\(a.volumeId)/\(a.documentId)" result[key, default: []].append(a.tagId)"#,
            "guard ResearchDocumentAggregation.countsAsAnnotation(entry.kind) else { continue }",
            "guard !entry.volumeId.isEmpty, !entry.documentId.isEmpty else { continue }",
            #"result["\(entry.volumeId)/\(entry.documentId)", default: []].insert(entry.collectionId)"#,
            // By Collection.
            "guard collection.savedSearchId == nil else { return nil }",
            "let count = ResearchDocumentAggregation.distinctDocumentKeys(in: collection.documentEntries ?? []).count",
            "guard count > 0 else { return nil }",
            "let names = CollectionEditorNaming.listOrder($0.collection.name, $1.collection.name)",
            "return names != .orderedSame ? names == .orderedAscending : $0.collection.id.uuidString < $1.collection.id.uuidString",
            "Text(CollectionEditorNaming.listName(savedName: item.collection.name))",
            // By Tag.
            ".filter { $0.userTagIds.contains(tag.id) }", #"directlyTaggedDocs .filter { $0.value.contains(tag.id) } .map(\.key)"#,
            "let count = fromNotes.union(fromDirect).count", "if $0.count != $1.count { return $0.count > $1.count }",
            "let names = $0.tag.name.localizedCaseInsensitiveCompare($1.tag.name)",
            "return names != .orderedSame ? names == .orderedAscending : $0.tag.id.uuidString < $1.tag.id.uuidString",
            // By Highlight, and a colour's reading.
            "DocumentHighlight.Color.allCases.compactMap { color in", ".filter { $0.color == color }",
            "return docs.isEmpty ? nil : (color: color, count: docs.count)",
            // The kit's summaries and the visit plans' documents.
            "ResearchDocumentAggregation.summaryCounts(allSummaries)", #"Set(allVisitDocuments.map(\.documentKey).filter { !$0.isEmpty })"#,
            // Which documents a category lists.
            "case .allAnnotated: matchingKeys = allAnnotatedKeys",
            #"case .hasNotes: matchingKeys = Set(allNotes.map { "\($0.volumeId)/\($0.documentId)" })"#,
            #"let fromDirect = Set(directlyTaggedDocs.filter { $0.value.contains(id) }.map(\.key))"#, "matchingKeys = fromNotes.union(fromDirect)",
            #"matchingKeys = Set(collectionMemberships.filter { $0.value.contains(collId) }.map(\.key))"#,
            "matchingKeys = allAnnotatedKeys.intersection(unreviewedRevisions.keys)",
            // Each row's facts.
            "for key in matchingKeys { grouped[key] = [] }", "for note in ResearchNote.oneCopyEach(allNotes) {",
            #"let parts = key.split(separator: "/", maxSplits: 1).map(String.init)"#, "guard parts.count == 2 else { return nil }",
            "let l = $0.lastModified ?? .distantPast, r = $1.lastModified ?? .distantPast",
            "return l != r ? l > r : $0.id.uuidString < $1.id.uuidString",
            "let directTagIds = Set(directlyTaggedDocs[key] ?? [])", "let noteTagIds = Set(notes.flatMap { $0.userTagIds })",
            "let colIds = collectionMemberships[key] ?? []", "let l = $0.createdAt ?? .distantPast, r = $1.createdAt ?? .distantPast",
            "latestNote: sortedNotes.first, noteCount: notes.count, summaryCount: summarizedDocs[key] ?? 0, isInVisitPlan: visitPlanDocs.contains(key),",
            "allTagIds: noteTagIds.union(directTagIds), collectionIds: colIds, highlights: docHighlights",
            // The rows' order.
            "let lhsDate = [lhs.latestNote?.lastModified, lhs.highlights.first?.createdAt].compactMap { $0 }.max() ?? .distantPast",
            "if lhsDate != rhsDate { return lhsDate > rhsDate }", "return lhs.id < rhs.id",
            // A row: its title, volume and date, its note, its highlights, and its tags' and collections' order.
            "Text(DocumentDisplayTitle.text(facts, documentId: entry.documentId))", "Text(volumeTitle ?? entry.volumeId)",
            "let annotationDate = [ entry.latestNote?.lastModified, entry.highlights.first?.createdAt ].compactMap { $0 }.max()",
            "if let note = entry.latestNote, !note.bodyText.isEmpty {", "ForEach(entry.highlights.prefix(3)) { hl in",
            "let names = $0.name.localizedCaseInsensitiveCompare($1.name)",
            "return names != .orderedSame ? names == .orderedAscending : $0.id.uuidString < $1.id.uuidString",
            "let names = CollectionEditorNaming.listOrder($0.name, $1.name)", "Text(CollectionEditorNaming.listName(savedName: row.name))",
            // A list's name.
            #"return allTags.first(where: { $0.id == id })?.name ?? String(localized: "research.list.unknownTag", defaultValue: "Tag")"#,
            #"let name = allCollections.first(where: { $0.id == id })?.name ?? """#, "return CollectionEditorNaming.listName(savedName: name)",
        ], file: "ResearchView.swift")
        // `DocumentHighlight.color`, the reading of a colour the server takes.
        NoteViewParityTests.expect(try Self.app("Models/DocumentHighlight.swift"), holds: [
            "var color: Color { Color(rawValue: colorTag) ?? .yellow }",
        ], file: "DocumentHighlight.swift")
        #expect(ResearchRoutes.shownHighlights == 3)
        // And the server's own copy of each line, so that neither side moves alone.
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/Research.swift"), holds: [
            #"Set(sources.notes.map { "\($0.volumeId)/\($0.documentId)" }).count"#,
            #"let key = "\(a.volumeId)/\(a.documentId)" result[key, default: []].append(a.tagId)"#,
            "guard ResearchDocumentAggregation.countsAsAnnotation(entry.kind) else { continue }",
            "guard !entry.volumeId.isEmpty, !entry.documentId.isEmpty else { continue }",
            "guard collection.savedSearchId == nil else { return nil }",
            "let count = ResearchDocumentAggregation.distinctDocumentKeys(among: collection.entries).count",
            "guard count > 0 else { return nil }",
            "let names = CollectionEditorNaming.listOrder($0.collection.name, $1.collection.name)",
            "return names != .orderedSame ? names == .orderedAscending : $0.collection.id.uuidString < $1.collection.id.uuidString",
            ".filter { $0.userTagIds.contains(tag.id) }", #"directlyTaggedDocs .filter { $0.value.contains(tag.id) } .map(\.key)"#,
            "let count = fromNotes.union(fromDirect).count", "if $0.count != $1.count { return $0.count > $1.count }",
            "let names = $0.tag.name.localizedCaseInsensitiveCompare($1.tag.name)",
            "return names != .orderedSame ? names == .orderedAscending : $0.tag.id.uuidString < $1.tag.id.uuidString",
            "HighlightColor.allCases.compactMap { color in", ".filter { Self.color(of: $0) == color }",
            "return docs.isEmpty ? nil : (color: color, count: docs.count)", "HighlightColor(rawValue: highlight.colorTag) ?? .yellow",
            "ResearchDocumentAggregation.summaryCounts(among: sources.summaries)",
            #"Set(sources.visitDocumentKeys.filter { !$0.isEmpty })"#,
            "case .allAnnotated: matchingKeys = allAnnotatedKeys",
            #"case .hasNotes: matchingKeys = Set(sources.notes.map { "\($0.volumeId)/\($0.documentId)" })"#,
            #"let fromDirect = Set(directlyTaggedDocs.filter { $0.value.contains(id) }.map(\.key))"#, "matchingKeys = fromNotes.union(fromDirect)",
            #"matchingKeys = Set(collectionMemberships.filter { $0.value.contains(collId) }.map(\.key))"#,
            "for key in matchingKeys { grouped[key] = [] }",
            #"let parts = key.split(separator: "/", maxSplits: 1).map(String.init)"#, "guard parts.count == 2 else { return nil }",
            "let l = $0.lastModified ?? .distantPast, r = $1.lastModified ?? .distantPast",
            "return l != r ? l > r : $0.id.uuidString < $1.id.uuidString",
            "let directTagIds = Set(directlyTaggedDocs[key] ?? [])", "let noteTagIds = Set(notes.flatMap { $0.userTagIds })",
            "let colIds = collectionMemberships[key] ?? []", "let l = $0.createdAt ?? .distantPast, r = $1.createdAt ?? .distantPast",
            "latestNote: sortedNotes.first, noteCount: notes.count, summaryCount: summarizedDocs[key] ?? 0, isInVisitPlan: visitPlanDocs.contains(key),",
            "allTagIds: noteTagIds.union(directTagIds), collectionIds: colIds, highlights: docHighlights",
            "let lhsDate = [lhs.latestNote?.lastModified, lhs.highlights.first?.createdAt].compactMap { $0 }.max() ?? .distantPast",
            "if lhsDate != rhsDate { return lhsDate > rhsDate }", "return lhs.id < rhs.id",
            "[latestNote?.lastModified, highlights.first?.createdAt].compactMap { $0 }.max()",
            "highlights: entry.highlights.prefix(shownHighlights).map {",
            "latestNote: entry.latestNote.flatMap { $0.bodyText.isEmpty ? nil : $0.bodyText },",
            "let names = $0.name.localizedCaseInsensitiveCompare($1.name)",
            "return names != .orderedSame ? names == .orderedAscending : $0.id.uuidString < $1.id.uuidString",
            "let names = CollectionEditorNaming.listOrder($0.name, $1.name)",
            #"let name = sources.collections.first(where: { $0.id == id })?.name ?? """#, "return CollectionEditorNaming.listName(savedName: name)",
        ], file: "Research.swift")
    }

    /// A row's title, as the app's `CrossReferenceStore.documentTitleFacts(for:)` reads it from the
    /// index: its query, a head or a number that is empty none, and its ids by volume, each once, 400
    /// to a query.
    @Test func aRowsTitleIsTheAppsQuery() throws {
        let store = try Self.app("CrossReference/CrossReferenceStore.swift")
        let server = try Self.server("Sources/FRUSLightAPI/Research.swift")
        let shared = [
            "SELECT document_id, header, document_number, is_editorial_note FROM document_cache WHERE volume_id = ? AND document_id IN (",
            #"for (vol, doc) in keys where seen.insert("\(vol)/\(doc)").inserted {"#, "if byVolume[vol] == nil { order.append(vol) }",
            "for start in stride(from: 0, to: ids.count, by: documentChunkSize) {",
            "out.append((volumeId, Array(ids[start..<min(start + documentChunkSize, ids.count)])))",
        ]
        NoteViewParityTests.expect(store, holds: shared + [
            "let head = columnString(stmt, 1).flatMap { $0.isEmpty ? nil : $0 }",
            "let number = columnString(stmt, 2).flatMap { $0.isEmpty ? nil : $0 }",
            #"result["\(volumeId)/\(doc)"] = DocumentTitleFacts("#, "isEditorialNote: sqlite3_column_int(stmt, 3) != 0)",
            "private static let documentChunkSize = 400",
        ], file: "CrossReferenceStore.swift")
        NoteViewParityTests.expect(server, holds: shared + [
            "let head = row[1].text.flatMap { $0.isEmpty ? nil : $0 }", "let number = row[2].text.flatMap { $0.isEmpty ? nil : $0 }",
            #"result["\(volumeId)/\(doc)"] = DocumentDisplayTitle.Facts("#, "isEditorialNote: (row[3].integer ?? 0) != 0)",
        ], file: "Research.swift")
        #expect(ServedIndex.documentChunkSize == 400)
        // The partition: by volume in the order each first comes, each key once, 400 ids at a time.
        let keys = (0..<401).map { (volumeId: "v1", documentId: "d\($0)") }
            + [(volumeId: "v2", documentId: "d1"), (volumeId: "v1", documentId: "d0"), (volumeId: "v2", documentId: "d1")]
        let chunks = ServedIndex.documentChunks(keys)
        #expect(chunks.map(\.volumeId) == ["v1", "v1", "v2"])
        #expect(chunks.map(\.documentIds.count) == [400, 1, 1])
        #expect(chunks[1].documentIds == ["d400"] && chunks[2].documentIds == ["d1"])
        #expect(ServedIndex.documentChunks([]).isEmpty)
    }

    /// The lines the browser app mirrors: a row's highlights and the line for the rest, its footer,
    /// and a list's title and what it says of none.
    @Test func theBrowsersMirrorsAreTheApps() throws {
        NoteViewParityTests.expect(try Self.app("Research/ResearchView.swift"), holds: [
            "if entry.highlights.count > 3 {", "Int64(entry.highlights.count - 3)", "if highlight.selectedText.isEmpty {",
            "if entry.summaryCount > 0 || entry.isInVisitPlan {",
            "let hasFooter = !tagRows.isEmpty || entry.noteCount > 1 || !collectionRows.isEmpty", "if entry.noteCount > 1 {",
            #"case .highlightColor: return String(localized: "research.empty.noDocs.highlight","#,
            #"case .collection: return String(localized: "research.empty.noDocs.collection","#,
        ], file: "ResearchView.swift")
        NoteViewParityTests.expect(try Self.web("research/researchRules.ts"), holds: [
            "export const shownHighlights = 3;",
            "return count > shownHighlights ? copy.researchPage.moreHighlights(count - shownHighlights) : undefined;",
            "return row.tags.length > 0 || row.noteCount > 1 || row.collections.length > 0;",
            "case 'tag': return name ?? copy.researchPage.unknownTag;",
            "case 'highlightColor': return copy.researchPage.highlightList(copy.highlights.colors[group.color]);",
            "case 'highlightColor': return copy.researchPage.emptyHighlight;", "case 'collection': return copy.researchPage.emptyCollection;",
        ], file: "researchRules.ts")
        NoteViewParityTests.expect(try Self.web("research/ResearchScreen.tsx"), holds: [
            "{row.summaryCount > 0 && <span>{copy.researchPage.summaries(row.summaryCount)}</span>}",
            "{highlight.selectedText === '' ? <em>{copy.researchPage.noText}</em> : highlight.selectedText}",
            "{row.latestNote && <p className=\"research-note\">{row.latestNote}</p>}",
            "{row.noteCount > 1 && <span className=\"research-notes\">{copy.researchPage.noteCount(row.noteCount)}</span>}",
        ], file: "ResearchScreen.tsx")
    }
}
