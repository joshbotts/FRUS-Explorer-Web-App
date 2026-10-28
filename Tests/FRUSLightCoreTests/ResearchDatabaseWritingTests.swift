// An export's writing as Import mode reads it (PLAN's S16e), the marks of what it becomes, and the
// words of the import's report. ResearchDatabaseImportTests, in FRUSLightServerTests, imports it with
// the kit's strip and the store.

@testable import FRUSLightCore
import FRUSLightTestSupport
import Foundation
import Testing

@Suite struct ResearchDatabaseWritingTests {
    /// RFC 9562's own example of a version-5 UUID: www.example.com in the DNS namespace.
    @Test func idsAreNameBasedUUIDsOfVersion5() throws {
        let dns = try #require(UUID(uuidString: "6BA7B810-9DAD-11D1-80B4-00C04FD430C8"))
        #expect(ResearchDatabaseMark.nameBased("www.example.com", in: dns) == "2ED6657D-E927-568B-95E1-2665A8AEA6A2")
    }

    @Test func eachRecordHasItsOwnStableId() {
        let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
        let d2 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d2")
        let ids = [ResearchDatabaseMark.noteId(for: d1), ResearchDatabaseMark.noteId(for: d2), ResearchDatabaseMark.summaryId(for: d1),
                   ResearchDatabaseMark.assignmentId(of: "5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F", on: d1)]
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { TagReferences.normalized($0) == $0 }, "uppercase uuidStrings, as the store keeps ids")
        #expect(ResearchDatabaseMark.noteId(for: d1) == ResearchDatabaseMark.noteId(for: DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")))
        #expect(ResearchDatabaseMark.promptId != OwnSummary.promptId)
    }

    @Test func aNoteBlockAndASummaryAreKnownByTheirMarks() {
        let d1 = DocumentKey(volumeId: "frus1961-63v06", documentId: "d1")
        func note(_ id: String, documentId: String = "d1") -> NoteRecord {
            NoteRecord(id: id, volumeId: "frus1961-63v06", documentId: documentId, bodyText: "A note.", richText: nil, projectIds: [],
                       userTagIds: [], selectedSummaryIds: [], createdAt: nil, lastModified: nil)
        }
        #expect(ResearchDatabaseMark.isNoteBlock(note(ResearchDatabaseMark.noteId(for: d1))))
        #expect(ResearchDatabaseMark.isNoteBlock(note(ResearchDatabaseMark.noteId(for: d1).lowercased())))
        #expect(!ResearchDatabaseMark.isNoteBlock(note(ResearchDatabaseMark.noteId(for: d1), documentId: "d2")), "another document's block id")
        #expect(!ResearchDatabaseMark.isNoteBlock(note(UUID().uuidString)))
        func summary(_ promptId: String) -> SummaryRecord {
            SummaryRecord(id: UUID().uuidString, volumeId: "frus1961-63v06", documentId: "d1", promptId: promptId, responseText: "A summary.",
                          responseFormat: #"{"general":{}}"#, wasChunked: false, authorship: nil, isHeadnoteDraft: false,
                          sourceContentHash: nil, projectId: nil, createdAt: nil, lastModified: nil)
        }
        #expect(ResearchDatabaseMark.isFromResearchDatabase(summary(ResearchDatabaseMark.promptId.lowercased())))
        #expect(!ResearchDatabaseMark.isFromResearchDatabase(summary(OwnSummary.promptId)))
    }

    /// Read from the copy: each document with writing, in key order, and the tag names in the order
    /// the Mac wrote them; a blank text is none, and an id that is no UUID gets one named for it, the
    /// same in both columns.
    @Test func theWritingIsReadAsTheIndexKeepsIt() throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent("export.sqlite")
        var export = SyntheticExport()
        export.includesWriting = true
        try export.write(to: url)
        let db = try SQLiteConnection(url.path, readOnly: false)
        defer { db.close() }
        try db.execute("""
            UPDATE document_cache SET note_text = '  ' || char(10), user_tag_ids = 'not-a-uuid 5c1e0001-7e4a-4b9c-9d2e-0a1b2c3d4e5f'
                WHERE volume_id = 'frus1961-63v06' AND document_id = 'd2';
            INSERT INTO user_tags (tag_id, name) VALUES ('not-a-uuid', 'A tag from an older writer');
            """)
        let exportedAt = try #require(UserStoreDate.date("2026-10-03T15:14:19Z"))

        let writing = try ResearchDatabaseWriting(reading: db, exportedAt: exportedAt)

        #expect(writing.documents.map(\.key.documentId) == ["d1", "d1", "d2"])
        #expect(writing.documents.map(\.key.volumeId) == ["frus1894Nicaragua", "frus1961-63v06", "frus1961-63v06"])
        #expect(writing.summaries == 2 && writing.noteBlocks == 1 && writing.tagAssignments == 5)
        let d2 = try #require(writing.documents.last)
        let derived = ResearchDatabaseMark.tagId("not-a-uuid")
        #expect(d2.noteText == nil && d2.summaryText == nil)
        #expect(d2.tagIds == [derived, "5C1E0001-7E4A-4B9C-9D2E-0A1B2C3D4E5F"])
        #expect(writing.tags.map(\.name) == ["Berlin crisis chapter", "Vienna summit follow-up", "Unassigned research thread",
                                             "A tag from an older writer"])
        #expect(writing.tags.last?.id == derived && TagReferences.normalized(derived) == derived)
        #expect(writing.documents[1].noteText?.contains("\n\n") == true, "the block's notes joined by a blank line")
        #expect(writing.exportedAt == exportedAt)
    }

    /// In the words of the app's export sheet, Research Notes and Tags & Assignments, counted together
    /// as the sheet counts them, and its switch's generated summaries.
    @Test func theReportSaysWhatMovedInTheAppsWords() {
        let first = MovedWriting(notes: ImportCount(added: 1), summaries: ImportCount(added: 2), tags: ImportCount(added: 3),
                                 tagAssignments: ImportCount(added: 4), searchableDocuments: 3)
        #expect(first.report.hasPrefix("Your notes, summaries and tags in the export were moved into your research data, and the server's copy of the index holds none of them: 1 Research Note, a document's note block; 2 generated summaries, each a document's newest; and 7 in Tags & Assignments, 3 tags and 4 assignments. The note blocks and summaries are marked as from a research database. A research database keeps only one note block and the newest summary for each document"))
        #expect(first.report.hasSuffix("export with Settings ▸ Data & Recovery ▸ Export as JSON in FRUS Explorer, with Include AI-Generated Summaries on, and import the file in Settings ▸ Data."))

        let mixed = MovedWriting(notes: ImportCount(added: 1, replaced: 1, kept: 1), summaries: ImportCount(), tags: ImportCount(kept: 1),
                                 tagAssignments: ImportCount(added: 1), searchableDocuments: 3)
        #expect(mixed.report.contains(": 3 Research Notes, each a document's note block (1 new here, 1 replacing an older copy, 1 kept as you have it here); and 2 in Tags & Assignments, 1 tag and 1 assignment (1 new here, 1 kept as you have it here)."))

        let unchanged = MovedWriting(notes: ImportCount(kept: 2), summaries: ImportCount(), tags: ImportCount(kept: 1),
                                     tagAssignments: ImportCount(), searchableDocuments: 2)
        #expect(unchanged.report.hasPrefix("Your research data held the notes, summaries and tags in the export already, so none of them changed, and the server's copy of the index holds none of them: 2 Research Notes, each a document's note block; and 1 in Tags & Assignments, 1 tag and no assignments."))

        let none = MovedWriting(notes: ImportCount(), summaries: ImportCount(), tags: ImportCount(), tagAssignments: ImportCount(),
                                searchableDocuments: 0)
        #expect(none.report == "The export was made with Include My Notes, Summaries, and Tags, but held no notes, summaries or tags.")
    }
}
