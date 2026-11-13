// The update review (PLAN's S21f), held to the app's source and the kit at the pin. The banner's sentence and the
// review sheet's lines are the app's views' static functions, mirrored in `DocumentChangeWords` (Reviews.swift):
// each sentence where the app writes it under its key, "this device" the web's "this server" where it says it, and
// the truth table's cases. The ledger's id is the app's `AnnotationReview.derivedId`, mirrored in
// `AnnotationReviewLedger` (UserReviews.swift), and its rule for a change is the kit's `applyAnnotationReviews`'
// match, run here over a scratch index of the kit's. The sheet, Research, Administration and the corrections check
// call the kit's rules rather than restating them. A pin move that changes one fails here until the web follows it.

import FRUSCoreKit
import FRUSLightCore
import FRUSLightTestSupport
import FTS5Store
import Foundation
import Testing

@testable import FRUSLightAPI

@Suite struct UpdateReviewParityTests {
    static func app(_ path: String) throws -> String { try SearchSetParityTests.app(path) }
    static func server(_ path: String) throws -> String { try SearchSetParityTests.server(path) }

    /// The banner's sentences, as `DocumentChangeBanner.line(revision:highlightsStale:)` writes them, and its cases,
    /// the web's change kind the user's own review leaves in place of the device's row.
    @Test func theBannerIsTheApps() throws {
        let banner = try Self.app("DocumentView/DocumentChangeBanner.swift")
        let words: [(key: String, value: String, kind: String?, stale: Bool)] = [
            ("highlight.stale.warning", "Some highlights may be misaligned — the document has been updated since they were created.", nil, true),
            ("document.changed.body", "The text of this document changed in a volume update. Highlight positions may have moved.", "body", false),
            ("document.changed.body.stale", "The text of this document changed in a volume update. Some highlights may be misaligned.", "body", true),
            ("document.changed.apparatus", "Footnotes, the source note, or the heading changed in a volume update. The text did not.", "apparatus", false),
            ("document.changed.apparatus.stale",
             "Footnotes, the source note, or the heading changed in a volume update, and some highlights may be misaligned.", "apparatus", true),
            ("document.changed.vanished", "This document is no longer in the volume.", "vanished", false),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(banner, word.key, word.value), "DocumentChangeBanner writes \(word.key)")
            #expect(DocumentChangeWords.bannerLine(kind: word.kind, highlightsStale: word.stale) == word.value, "\(word.key)")
        }
        #expect(DocumentChangeWords.bannerLine(kind: "vanished", highlightsStale: true) == "This document is no longer in the volume.")
        #expect(DocumentChangeWords.bannerLine(kind: nil, highlightsStale: false) == nil)
        #expect(DocumentChangeWords.bannerLine(kind: "renumbered", highlightsStale: false) == nil)
        #expect(DocumentChangeWords.bannerLine(kind: "renumbered", highlightsStale: true) == words[0].value)
        NoteViewParityTests.expect(banner, holds: [
            "guard let revision, revision.changedAt != nil, revision.reviewedAt == nil else { return nil }",
            "return revision.changeKind",
            "switch (kind, highlightsStale) {", #"case ("vanished", _):"#, "case (_, true):", "case (_, false): return nil",
        ], file: "DocumentChangeBanner.swift")
    }

    /// The sheet's lines for a highlight and for the search for its passage, as `DocumentChangeReviewSheet` writes
    /// them; the change section's two sentences; the move it offers; and a note's row.
    @Test func theSheetsLinesAreTheApps() throws {
        let sheet = try Self.app("DocumentView/DocumentChangeReviewSheet.swift")
        // The app's, word for word.
        let same: [(key: String, value: String, web: String)] = [
            ("document.review.highlight.orphaned", "The document it was made on is no longer in the volume.",
             DocumentChangeWords.statusLine(.aligned, vanished: true)),
            ("document.review.highlight.aligned", "Matches the current text.", DocumentChangeWords.statusLine(.aligned, vanished: false)),
            ("document.review.highlight.stale", "Made against an earlier version of the text — its position may have moved.",
             DocumentChangeWords.statusLine(.stale(hasPassage: true), vanished: false)),
            ("document.review.highlight.stale.noPassage",
             "Made against an earlier version of the text, and the words it covered were not stored — it can only be checked by eye.",
             DocumentChangeWords.statusLine(.stale(hasPassage: false), vanished: false)),
            ("document.review.search.here", "Found once, still in this position.",
             DocumentChangeWords.searchLine(.here(.init(start: 0, end: 1, shift: 0))) ?? ""),
            ("document.review.search.moved", "Found once, at a new position in the corrected text.",
             DocumentChangeWords.searchLine(.moved(.init(start: 2, end: 3, shift: 2))) ?? ""),
            ("document.review.search.far",
             "Found once, but far from where it was. This can mean the document was renumbered and this one is not the same document — check it before moving anything by hand.",
             DocumentChangeWords.searchLine(.foundFar(.init(start: 900, end: 901, shift: 900))) ?? ""),
            ("document.review.search.notFound",
             "Not found in the current text. The passage may have been edited, or this document may have been renumbered.",
             DocumentChangeWords.searchLine(.notFound) ?? ""),
            ("document.review.search.tooShort.v2",
             "Too short to look for: a passage this brief can repeat, so finding it once would not prove anything.",
             DocumentChangeWords.searchLine(.refused(.tooShort)) ?? ""),
            ("document.review.vanished",
             "This document is no longer in the volume — either a volume update removed it, or a change to how the app reads the volume no longer finds it. Everything you attached to it is kept until you remove it.",
             DocumentChangeWords.vanished),
        ]
        for word in same {
            #expect(NoteViewParityTests.writes(sheet, word.key, word.value), "DocumentChangeReviewSheet writes \(word.key)")
            #expect(word.web == word.value, "\(word.key)")
        }
        // "This device" is the web's "this server".
        let ofTheServer: [(key: String, value: String, web: String)] = [
            ("document.review.highlight.unverifiable", "This device has no record to compare it against.",
             DocumentChangeWords.statusLine(.unverifiable, vanished: false)),
            ("document.review.noChange", "No change to this document is recorded on this device.", DocumentChangeWords.noChange),
        ]
        for word in ofTheServer {
            #expect(NoteViewParityTests.writes(sheet, word.key, word.value), "DocumentChangeReviewSheet writes \(word.key)")
            #expect(word.web == word.value.replacingOccurrences(of: "This device", with: "This server")
                .replacingOccurrences(of: "this device", with: "this server"), "\(word.key)")
        }
        // The count, as the app formats it, and the outcomes it says nothing for.
        NoteViewParityTests.expect(sheet, holds: [
            #"String(format: String(localized: "document.review.search.ambiguous %lld", defaultValue: "Found %lld times, so the app cannot tell which one is yours."), Int64(count))"#,
            "case .noPassage, .refused: return nil",
            "guard case .moved(let match)? = search else { return nil }",
            "let radius = 100",
            "guard HighlightReview.status(of: highlight, currentVersion: effectiveVersion) != .aligned else { continue }",
            ".split(whereSeparator: \\.isNewline)", ".map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }",
            "return revision.changedAt != nil && revision.reviewedAt == nil",
        ], file: "DocumentChangeReviewSheet.swift")
        #expect(DocumentChangeWords.searchLine(.ambiguous(count: 3)) == "Found 3 times, so the app cannot tell which one is yours.")
        #expect(DocumentChangeWords.searchLine(.noPassage) == nil && DocumentChangeWords.searchLine(.refused(.malformed)) == nil)
        #expect(DocumentChangeWords.offeredMove(.foundFar(.init(start: 900, end: 901, shift: 900))) == nil)
        #expect(DocumentChangeWords.offeredMove(.moved(.init(start: 2, end: 3, shift: 2))) == .init(start: 2, end: 3, shift: 2))
        #expect(DocumentChangeWords.noteRowTitle("\r\n  \n  First line \r\nSecond") == "First line")
        #expect(DocumentChangeWords.noteRowTitle(" \n\t") == nil)
    }

    /// The ledger's id, the app's `AnnotationReview.derivedId`, as its source writes it.
    @Test func theLedgersIdIsTheApps() throws {
        let model = try Self.app("Models/AnnotationReview.swift")
        NoteViewParityTests.expect(model, holds: [
            #"let key = "AnnotationReview|\(kind.rawValue)|\(annotationId?.uuidString ?? "-")|\(volumeId)/\(documentId)|\(contentHash)|\(changeKind ?? "-")""#,
            "let digest = SHA256.hash(data: Data(key.utf8))", "var bytes = Array(digest.prefix(16))",
            "bytes[6] = (bytes[6] & 0x0F) | 0x80", "bytes[8] = (bytes[8] & 0x3F) | 0x80",
            "case document", "guard !volumeId.isEmpty, !documentId.isEmpty, !contentHash.isEmpty else { return nil }",
            "if let existing { return existing }",
        ], file: "AnnotationReview.swift")
        let ours = try Self.server("Sources/FRUSLightCore/UserReviews.swift")
        NoteViewParityTests.expect(ours, holds: [
            #"let key = "AnnotationReview|\(kind)|\(annotationId ?? "-")|\(volumeId)/\(documentId)|\(contentHash)|\(changeKind ?? "-")""#,
            "let digest = SHA256.hash(data: Data(key.utf8))", "var bytes = Array(digest.prefix(16))",
            "bytes[6] = (bytes[6] & 0x0F) | 0x80", "bytes[8] = (bytes[8] & 0x3F) | 0x80",
        ], file: "UserReviews.swift")
        // A version-8 UUID of the variant RFC 4122 names, stable for what it records.
        let id = AnnotationReviewLedger.derivedId(kind: "document", annotationId: nil, volumeId: "frus1894Nicaragua", documentId: "d2",
                                                  contentHash: "c1", changeKind: "body")
        #expect(id == AnnotationReviewLedger.derivedId(kind: "document", annotationId: nil, volumeId: "frus1894Nicaragua", documentId: "d2",
                                                       contentHash: "c1", changeKind: "body"))
        let bytes = try #require(UUID(uuidString: id)).uuid
        #expect(bytes.6 >> 4 == 8 && bytes.8 >> 6 == 2)
        #expect(id != AnnotationReviewLedger.derivedId(kind: "document", annotationId: nil, volumeId: "frus1894Nicaragua", documentId: "d2",
                                                       contentHash: "c1", changeKind: nil))
    }

    /// The ledger's rule for a change is the kit's: over a scratch index of the kit's, each ledger row stamps by the
    /// kit's `applyAnnotationReviews` exactly the changes `AnnotationReviewLedger.reviews` says it reviews.
    @Test func theLedgersMatchIsTheKits() async throws {
        let directory = try TemporaryDirectory()
        let url = directory.url.appendingPathComponent("scratch.db")
        let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: url), databaseURL: url, volumesDirectory: directory.url,
                                            resources: try IndexingResources.loading(fromDirectory: RepositoryFiles.resources),
                                            defaults: InMemoryIndexingStampStore())
        let rows: [(document: String, hash: String, kind: String?, stamped: Bool)] = [
            ("d1", "c1", "body", true), ("d2", "c2", "apparatus", true), ("d3", "c3", "vanished", true), ("d4", "c4", nil, true),
            ("d5", "c5", "body", false), ("d6", "c1", "body", true),
        ]
        let db = try SQLiteConnection(url.path, readOnly: false)
        defer { db.close() }
        func reset() throws {
            _ = try db.query("DELETE FROM document_revisions")
            for row in rows {
                _ = try db.query("""
                    INSERT INTO document_revisions (volume_id, document_id, content_hash, body_hash, changed_at, change_kind, reviewed_at, index_version)
                    VALUES ('v1', ?, ?, '0000000000000001', ?, ?, NULL, ?)
                    """, [.text(row.document), .text(row.hash), row.stamped ? .text("2026-11-13T00:00:00Z") : .null,
                          row.kind.map { SQLiteValue.text($0) } ?? .null, .integer(Int64(IndexingPipeline.currentDateIndexVersion))])
            }
        }
        let ledgers: [AnnotationReviewRecord] = [
            ("d1", "c1", "body"), ("d1", "c1", "apparatus"), ("d1", "c9", "body"), ("d2", "c2", "apparatus"), ("d3", "c3", "vanished"),
            ("d4", "c4", nil), ("d4", "c4", "body"), ("d5", "c5", "body"), ("d6", "c1", "body"), ("d7", "c1", "body"),
        ].map { AnnotationReviewRecord(id: "x", annotationType: "document", annotationId: nil, volumeId: "v1", documentId: $0.0,
                                       contentHash: $0.1, changeKind: $0.2, reviewedAt: nil) }
        for ledger in ledgers {
            try reset()
            let revisions = try await pipeline.documentRevisions(forVolumeId: "v1")
            let ours = Set(revisions.filter { AnnotationReviewLedger.reviews([ledger], $0) }.map(\.documentId))
            _ = try await pipeline.applyAnnotationReviews([ledger.data])
            let kits = Set(try await pipeline.documentRevisions(forVolumeId: "v1").filter { $0.reviewedAt != nil }.map(\.documentId))
            #expect(ours == kits, "\(ledger.documentId) \(ledger.contentHash) \(ledger.changeKind ?? "nil"): ours \(ours), the kit's \(kits)")
        }
        withExtendedLifetime(directory) {}
    }

    /// The words the browser app takes, where the app's source writes each under its key, and in copy.ts's block;
    /// "this device" the web's "this server", and "your research" an admin's "research on this server".
    @Test func theWebsWordsAreTheApps() throws {
        let raw = try NoteViewParityTests.read(NoteViewParityTests.web, "copy.ts")
        let review = try NoteViewParityTests.block("review", of: raw)
        let research = try NoteViewParityTests.block("researchPage", of: raw)
        let library = try #require(raw.range(of: "\n    library: {")).lowerBound
        let admin = NoteViewParityTests.flattened(String(raw[library...].prefix(40_000)))
        let banner = try Self.app("DocumentView/DocumentChangeBanner.swift")
        let sheet = try Self.app("DocumentView/DocumentChangeReviewSheet.swift")
        let keeping = try Self.app("Settings/KeepingCurrentSection.swift")
        let model = try Self.app("Settings/KeepingCurrentModel.swift")
        let section = try Self.app("Settings/VolumeUpdateReviewSection.swift")
        let view = try Self.app("Research/ResearchView.swift")
        let kit = SearchSetParityTests.self
        let aggregation = try kit.kit("FRUSCoreKit/Research/ResearchDocumentAggregation.swift")
        let words: [(source: String, file: String, key: String, value: String, block: String, web: String)] = [
            (banner, "DocumentChangeBanner", "document.changed.review", "Review…", review, "review: 'Review…'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.done", "Done", review, "done: 'Done'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.loading", "Reading the change record…", review, "loading: 'Reading the change record…'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.change.header", "What Changed", review, "changeHeader: 'What Changed'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.markReviewed", "Mark Reviewed", review, "markReviewed: 'Mark Reviewed'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.highlights.header", "Highlights", review, "highlightsHeader: 'Highlights'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.highlights.footer.v2",
             "Confirm keeps a highlight exactly where it is and clears its warning everywhere you are signed in. Where the app can find the passage again it offers to move the highlight, showing you the words and what surrounds them — it never moves one on its own, and it never guesses when the words appear more than once.",
             review, "highlightsFooter: 'Confirm keeps a highlight exactly where it is and clears its warning everywhere you are signed in. Where the app can find the passage again it offers to move the highlight, showing you the words and what surrounds them — it never moves one on its own, and it never guesses when the words appear more than once.'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.highlight.noPassage", "Highlighted passage", review, "noPassage: 'Highlighted passage'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.highlight.move", "Move Here", review, "move: 'Move Here'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.highlight.confirm", "Confirm", review, "confirm: 'Confirm'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.highlight.remove", "Remove…", review, "remove: 'Remove…'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.excerpts.header", "Quotations", review, "excerptsHeader: 'Quotations'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.other.header", "Other Annotations", review, "othersHeader: 'Other Annotations'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.other.none", "No other annotations on this document.", review,
             "othersNone: 'No other annotations on this document.'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.other.visit", "in an archive-visit plan", review, "inVisitPlan: 'in an archive-visit plan'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.other.editTags", "Edit Tags…", review, "editTags: 'Edit Tags…'"),
            (sheet, "DocumentChangeReviewSheet", "document.review.other.note.untitled", "Open note", review, "openNote: 'Open note'"),
            (view, "ResearchView", "research.action.reviewChanges", "Review Changes…", research, "reviewChanges: 'Review Changes…'"),
            (aggregation, "ResearchDocumentAggregation", "research.row.changed.vanished", "No longer in the volume", research, "vanished: 'No longer in the volume'"),
            (keeping, "KeepingCurrentSection", "settings.hub.keepingCurrent.header", "Keeping Current", admin, "keepingCurrent: 'Keeping Current'"),
            (keeping, "KeepingCurrentSection", "settings.hub.keepingCurrent.footer",
             "Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved.", admin,
             "keepingCurrentFooter: 'Updating re-downloads and re-indexes a volume. Your notes, highlights, tags, and summaries are preserved.'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.button", "Check for Corrections", admin, "checkCorrections: 'Check for Corrections'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.checking", "Checking…", admin, "checkingCorrections: 'Checking…'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.help",
             "Compares each downloaded volume against the FRUS repository and lists any that changed since you downloaded them", admin,
             "'Compares each downloaded volume against the FRUS repository and lists any that changed since you downloaded them'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.upToDate", "All downloaded volumes are up to date", admin,
             "upToDate: 'All downloaded volumes are up to date'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.upToDate.detail", "Nothing has changed upstream since you downloaded them.",
             admin, "upToDateDetail: 'Nothing has changed upstream since you downloaded them.'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.update", "Update", admin, "update: 'Update'"),
            (keeping, "KeepingCurrentSection", "settings.hub.corrections.updateAll", "Update All", admin, "updateAll: 'Update All'"),
            (model, "KeepingCurrentModel", "settings.hub.corrections.sideloaded", "Your side-loaded copy. Update replaces it with the published volume.",
             admin, "sideloadedCopy: 'Your side-loaded copy. Update replaces it with the published volume.'"),
            (section, "VolumeUpdateReviewSection", "settings.updateReview.header", "After an Update", admin, "afterUpdate: 'After an Update'"),
            (section, "VolumeUpdateReviewSection", "settings.updateReview.none.label", "No changes waiting", admin, "noChanges: 'No changes waiting'"),
            (section, "VolumeUpdateReviewSection", "settings.updateReview.summary.label", "Updates changed documents", admin,
             "changesWaiting: 'Updates changed documents'"),
        ]
        for word in words {
            #expect(NoteViewParityTests.writes(word.source, word.key, word.value), "\(word.file) writes \(word.key) as \(word.value)")
            #expect(word.block.contains(NoteViewParityTests.flattened(word.web)), "copy.ts holds \(word.web)")
        }
        // A long footer, flattened as the source splits it: its text in the app's file and in copy.ts.
        let footers: [(source: String, value: String, block: String)] = [
            (sheet, "A quotation is a copy, so a correction cannot change what it prints — what it can change is whether those words are still in the record it cites. This is the same check that runs when a collection is exported, and it reads the whole document, footnotes included. So a quotation can be affected by a correction described above as touching only the notes, and a quotation can fail this check for reasons older than any correction. Nothing here edits or removes a quotation: it belongs to its collection, and the collection editor is where you change it.", review),
            (sheet, "These carry no position in the text, so the app cannot judge them against the change — it can only take you to them. Review them by eye; a summary describes the text as it was when it was written, and the app cannot tell you which of these predate the correction.", review),
        ]
        for footer in footers {
            #expect(footer.source.contains(footer.value), "the app's file holds \(footer.value.prefix(40))")
            #expect(footer.block.contains(footer.value), "copy.ts holds \(footer.value.prefix(40))")
        }
        // "This device" is the web's "this server"; "your research", an admin's, everyone's on this server.
        #expect(NoteViewParityTests.writes(view, "research.empty.noDocs.updated", "No document you have annotated has changed since it was indexed on this device."))
        #expect(research.contains("emptyUpdated: 'No document you have annotated has changed since it was indexed on this server.'"))
        #expect(NoteViewParityTests.writes(section, "settings.updateReview.none.detail", "No volume update on this device has changed a document since it was last indexed."))
        #expect(admin.contains("noChangesDetail: 'No volume update on this server has changed a document since it was last indexed.'"))
        // The words with a count, as the app formats them and copy.ts's functions say them.
        let formats: [(source: String, line: String, block: String, web: String)] = [
            (sheet, #"String(localized: "document.review.other.notes %lld", defaultValue: "\(notes.count) notes")"#, review, "notesCount: (count: number) => `${count} notes`"),
            (sheet, #"String(localized: "document.review.other.tags %lld", defaultValue: "\(tagAssignments.count) tags")"#, review, "tagsCount: (count: number) => `${count} tags`"),
            (sheet, #"String(localized: "document.review.other.collections %lld", defaultValue: "in \(documentEntries) collections")"#, review,
             "collectionsCount: (count: number) => `in ${count} collections`"),
            (sheet, #"String(localized: "document.review.other.summaries %lld", defaultValue: "\(liveSummaries) summaries")"#, review,
             "summariesCount: (count: number) => `${count} summaries`"),
            (section, #"String(localized: "settings.updateReview.part.body %lld", defaultValue: "\(v.body) with changed text")"#, admin,
             "changedBody: (count: number) => `${count} with changed text`"),
            (section, #"String(localized: "settings.updateReview.part.apparatus %lld", defaultValue: "\(v.apparatus) with changed footnotes, source note, or heading")"#,
             admin, "changedApparatus: (count: number) => `${count} with changed footnotes, source note, or heading`"),
            (section, #"String(localized: "settings.updateReview.part.vanished %lld", defaultValue: "\(v.vanished) no longer in the volume")"#, admin,
             "changedVanished: (count: number) => `${count} no longer in the volume`"),
        ]
        for format in formats {
            #expect(format.source.contains(NoteViewParityTests.flattened(format.line)), "the app holds \(format.line)")
            #expect(format.block.contains(NoteViewParityTests.flattened(format.web)), "copy.ts holds \(format.web)")
        }
    }

    /// The synthetic export, which the Compose smoke test's Import server serves over fixtures/tei and fixtures/own-text,
    /// records its documents' texts as a Mac's export of those files does: each document's content and body hashes the
    /// kit's indexer's at the pin (`Fixtures/export-revisions.sql`), so that the server's comparison of its export with
    /// the TEI folder finds no change in them. A pin move that changes one fails here, printing the file's lines.
    @Test func theSyntheticExportRecordsTheFixturesAsTheKitIndexesThem() async throws {
        let wanted: [(volume: String, document: String, folder: URL)] = SyntheticExport.documents.map {
            ($0.volume, $0.id, RepositoryFiles.tei)
        } + SyntheticExport.ownTextRows.map { (SyntheticExport.ownTextVolume, $0.id, RepositoryFiles.ownText) }
        let resources = try IndexingResources.loading(fromDirectory: RepositoryFiles.resources)
        var kits: [String: IndexingPipeline.DocumentRevision] = [:]
        for (volume, folder) in Set(wanted.map { "\($0.volume)|\($0.folder.path)" }).sorted().map({ pair -> (String, URL) in
            let parts = pair.split(separator: "|", maxSplits: 1).map(String.init)
            return (parts[0], URL(fileURLWithPath: parts[1]))
        }) {
            let directory = try TemporaryDirectory()
            let url = directory.url.appendingPathComponent("scratch.db")
            let pipeline = try IndexingPipeline(fts5Store: try FTS5Store(databaseURL: url), databaseURL: url, volumesDirectory: folder,
                                                resources: resources, defaults: InMemoryIndexingStampStore())
            try await pipeline.indexVolume(volume)
            for row in try await pipeline.documentRevisions(forVolumeId: volume) { kits["\(volume)/\(row.documentId)"] = row }
            withExtendedLifetime(directory) {}
        }
        let lines = try wanted.map { document -> String in
            let row = try #require(kits["\(document.volume)/\(document.document)"], "the kit indexes \(document.volume)/\(document.document)")
            return "UPDATE document_revisions SET content_hash = '\(row.contentHash)', body_hash = '\(row.bodyHash)' WHERE volume_id = '\(document.volume)' AND document_id = '\(document.document)';"
        }
        let fixture = try String(contentsOf: RepositoryFiles.root.appendingPathComponent("Tests/FRUSLightTestSupport/Fixtures/export-revisions.sql"),
                                 encoding: .utf8)
        let held = fixture.split(separator: "\n").filter { $0.hasPrefix("UPDATE") }.map(String.init)
        #expect(held == lines, "Fixtures/export-revisions.sql's lines, as the kit gives them at the pin:\n\(lines.joined(separator: "\n"))")
    }

    /// What the review reads is the kit's: the corrections check, the indexer's pass of a corrected volume, the
    /// sheet's rules, Research's row and Administration's tallies, each a call to the kit's code.
    @Test func theRulesAreTheKits() throws {
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightCore/Library.swift"), holds: [
            "await VolumeUpdateChecker.updatableVolumes(known: diff.known, liveInfoByVolumeId: diff.liveInfoByVolumeId, downloadManager: self)",
            "return ManifestDiffResult.diff(bundled: catalogue, live: live)",
        ], file: "Library.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightCore/LibraryIndexing.swift"), holds: [
            "try await pipeline.indexVolume(volumeId)", "let owed = stamps.reindexOwed()",
        ], file: "LibraryIndexing.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightCore/TEIChanges.swift"), holds: [
            "try await pipeline.indexVolume(volumeId)",
            "let moved = try await pipeline.documentRevisions(forVolumeId: volumeId).filter { $0.changedAt != nil }",
        ], file: "TEIChanges.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightCore/ReviewStamps.swift"), holds: [
            "try await writer.pipeline.applyAnnotationReviews(rows)",
        ], file: "ReviewStamps.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/Reviews.swift"), holds: [
            "HighlightReanchor.locate(passage: highlight.selectedText, storedStart: highlight.startOffset, storedEnd: highlight.endOffset, in: blocks)",
            "HighlightReview.status(renderingVersion: highlight.renderingVersion, selectedText: highlight.selectedText, currentVersion: version)",
            "ExcerptVerifier.verify(requests, bodyTexts: bodies)", "ExcerptVerifier.upgradingVanished(",
            "let lines = ExcerptReview.lines(outcome: outcome, storedVersion: quotation.version, currentVersion: version)",
            "warning: ExcerptReview.isWarning(outcome)",
            "open = unstamped.filter { !AnnotationReviewLedger.reviews(settled, $0) }",
            "let summaries = VolumeUpdateReview.summaries(revisions: open, annotatedKeys: Set(annotators.keys))",
            "let totals = VolumeUpdateReview.totals(of: summaries)",
        ], file: "Reviews.swift")
        NoteViewParityTests.expect(try Self.server("Sources/FRUSLightAPI/Research.swift"), holds: [
            "ResearchDocumentAggregation.changeLine(for: revision)",
            "ResearchDocumentAggregation.rowDestination(revision: changes.unreviewed[entry.id], isVanished: changes.vanished.contains(entry.id))",
            "matchingKeys = allAnnotatedKeys.intersection(unreviewedKeys)",
        ], file: "Research.swift")
        // The app's sheet's own reading of the same rules, which the web's follows.
        NoteViewParityTests.expect(try Self.app("DocumentView/DocumentChangeReviewSheet.swift"), holds: [
            "found[highlight.id] = HighlightReview.locate(passage: highlight.selectedText, storedStart: highlight.startOffset, storedEnd: highlight.endOffset, in: partition)",
            "let outcomes = ExcerptVerifier.verify(pairs.map(\\.1), bodyTexts: bodies)",
            "ExcerptReview.lines(outcome: $0, storedVersion: entry.excerptRenderingVersion, currentVersion: effectiveVersion)",
            "_ = try? await pipeline.markDocumentRevisionReviewed(volumeId: volumeId, documentId: documentId)",
            "AnnotationReviewStore.record(kind: .document, volumeId: volumeId, documentId: documentId, contentHash: hash, changeKind: revision?.changeKind, context: modelContext)",
        ], file: "DocumentChangeReviewSheet.swift")
        NoteViewParityTests.expect(try Self.app("Research/ResearchView.swift"), holds: [
            "matchingKeys = allAnnotatedKeys.intersection(unreviewedRevisions.keys)",
            "ResearchDocumentAggregation.changeLine(for: revision)",
        ], file: "ResearchView.swift")
    }
}
