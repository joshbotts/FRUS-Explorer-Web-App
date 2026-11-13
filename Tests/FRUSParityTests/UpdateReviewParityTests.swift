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
            "let summaries = VolumeUpdateReview.summaries(revisions: open, annotatedKeys: annotated)",
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
